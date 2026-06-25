public without sharing class FEC_SearchArchiveInteraction {

    // Enable test mode to return mock data (useful for demo/testing without External Object)
    private static Boolean USE_MOCK_DATA = false;
    
    // Prefix dùng để phân loại record archive: case_id bắt đầu bằng 'S-' là Service Case,
    // còn lại (I-, O-, ...) là Interaction.
    private static final String SERVICE_CASE_PREFIX = 'S-';

    /**
     * Lấy các bản ghi archive là INTERACTION (loại trừ Service Case 'S-').
     * Dùng cho tab All Interactions → section "Archive Interactions".
     */
    @AuraEnabled
    public static List<ArchiveInteractionRow> getArchiveInteractions(Id recordId) {
        return getArchiveRows(recordId, false);
    }

    /**
     * Lấy các bản ghi archive là SERVICE CASE (chỉ case_id bắt đầu bằng 'S-').
     * Dùng cho tab All Service Cases → section "Archive Service Cases".
     */
    @AuraEnabled
    public static List<ArchiveInteractionRow> getArchiveServiceCases(Id recordId) {
        return getArchiveRows(recordId, true);
    }

    /**
     * Truy vấn external object AthenaCases__x theo account/contract của khách hàng,
     * rồi lọc theo loại record.
     * @param serviceCasesOnly true → chỉ trả Service Case (S-); false → chỉ trả Interaction (khác S-)
     */
    private static List<ArchiveInteractionRow> getArchiveRows(Id recordId, Boolean serviceCasesOnly) {
        // Return mock data if test mode enabled or in test context
        if (USE_MOCK_DATA  ) {
            return getMockArchiveInteractions();
        }
        
        if (recordId == null)  return new List<ArchiveInteractionRow>();
        
        FEC_GetServiceCases.CustomerFilterContext filterCtx = FEC_GetServiceCases.resolveCustomerFilterContext(recordId);
        if (filterCtx == null && !Test.isRunningTest()) return new List<ArchiveInteractionRow>();

        String accContactNumber = Test.isRunningTest() ? '' : filterCtx.accountContractName;
        List<String> filterNationalIds =Test.isRunningTest() ? new List<String>() :  filterCtx.nationalIds;
        String soql = 
            'SELECT id, ExternalId, case_id__c, s3_path__c, migration_source__c, ' +
            'accountnumber__c, contractnumber__c, pycustomername__c,subcategory__c,subcode__c,pxcreatedatetime__c,pylabel__c, ' +
            'pystatuswork__c, primaryphone__c, currentinteractionid__c, nationalid__c ' +
            'FROM AthenaCases__x ' +
            'WHERE accountnumber__c = :accContactNumber OR contractnumber__c = :accContactNumber ' +
            'ORDER BY case_id__c';
        
        List<AthenaCases__x> athenaCases = new List<AthenaCases__x>();
        if (Test.isRunningTest() && mockAthenaCasesForTest != null) {
            athenaCases = mockAthenaCasesForTest;
        } else {
            try {
                athenaCases = Database.query(soql);
            } catch (Exception e) {
                throw new AuraHandledException('Error querying AthenaCases__x: ' + e.getMessage());
            }
        }
        
        // Step 3: Transform data to rows (lọc theo loại record)
        List<ArchiveInteractionRow> rows = new List<ArchiveInteractionRow>();
        String archiveBaseUrl = getArchiveSystemBaseUrl();

        // Safety cap: số lần callout S3 để enrich (tránh đụng governor limit 100 callouts)
        Integer s3EnrichCount = 0;
        final Integer MAX_S3_ENRICH = 20;

        for (AthenaCases__x ac : athenaCases) {
            Boolean isServiceCase = ac.case_id__c != null
                && ac.case_id__c.startsWithIgnoreCase(SERVICE_CASE_PREFIX);
            // Chỉ giữ lại record đúng loại đang yêu cầu
            if (serviceCasesOnly != isServiceCase) {
                continue;
            }

            ArchiveInteractionRow row = new ArchiveInteractionRow();
            row.externalId = ac.ExternalId;
            row.caseId = ac.case_id__c;
            row.s3Path = ac.s3_path__c;
            row.migrationSource = ac.migration_source__c;
            row.accountNumber = ac.accountnumber__c;
            row.contractNumber = ac.contractnumber__c;
            row.subcode = ac.subcode__c;
            row.subcategory = ac.subcategory__c;
            row.pxcreatedatetime = ac.pxcreatedatetime__c;
            row.interactionChannel = ac.pylabel__c;
            row.status = ac.pystatuswork__c;
            row.phone = ac.primaryphone__c;
            row.currentInteractionId = ac.currentinteractionid__c;
            row.nationalId = ac.nationalid__c;

            // Enrich Sub Category / Sub Code từ full S3 JSON khi External Object index thiếu data.
            // Giải pháp tạm phía SF trước khi backend populate search index.
            if ((String.isBlank(row.subcategory) || String.isBlank(row.subcode))
                    && String.isNotBlank(ac.s3_path__c)
                    && s3EnrichCount < MAX_S3_ENRICH) {
                s3EnrichCount++;
                Map<String, Object> caseObj = fetchCaseDetailFromS3(ac);
                if (caseObj != null) {
                    if (String.isBlank(row.subcategory)) {
                        row.subcategory = (String) caseObj.get('FEC_SubCategory__c');
                    }
                    if (String.isBlank(row.subcode)) {
                        row.subcode = (String) caseObj.get('FEC_SubCode__c');
                    }
                }
            }

            // Generate case URL
            row.caseUrl = URL.getOrgDomainUrl().toExternalForm()+'/lightning/r/'+ac.id+'/view';
           // row.caseUrl = generateCaseUrl(ac.case_id__c, ac.s3_path__c, archiveBaseUrl);
            
            rows.add(row);
        }
        
        return rows;
    }

    // Hook cho test: inject danh sách AthenaCases__x (external object không query được trong test)
    @TestVisible private static List<AthenaCases__x> mockAthenaCasesForTest;

    /**
     * Đọc full case detail từ S3 và trả về Map của object "Case" trong JSON.
     * Dùng để enrich Sub Category / Sub Code khi External Object index thiếu data.
     * Trả null nếu lỗi (callout fail, non-200, JSON parse error) → row giữ giá trị trống.
     */
    @TestVisible
    private static Map<String, Object> fetchCaseDetailFromS3(AthenaCases__x ac) {
        try {
            String migrationSource = ArchiveCaseController.getMigrationSource(ac.migration_source__c);
            HttpResponse resp = ArchiveCaseController.callS3ToGetCaseDetail(ac, migrationSource);
            if (resp == null) return null;
            Integer sc = resp.getStatusCode();
            if (sc != 200 && sc != 201) return null;

            Map<String, Object> json = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
            return json.containsKey('Case')
                ? (Map<String, Object>) json.get('Case')
                : json;
        } catch (Exception e) {
            System.debug('fetchCaseDetailFromS3 failed for ' + ac.case_id__c + ': ' + e.getMessage());
            return null;
        }
    }
    
    // Method to return JSON string of test data
    @AuraEnabled
    public static String getTestDataJSON() {
        List<ArchiveInteractionRow> mockData = getMockArchiveInteractions();
        return JSON.serialize(mockData);
    }
    
    // Method to return formatted JSON for display
    @AuraEnabled
    public static String getTestDataJSONPretty() {
        List<ArchiveInteractionRow> mockData = getMockArchiveInteractions();
        return JSON.serializePretty(mockData);
    }
    
    /**
     * Generate URL for opening archive service case
     * @param caseId - The archive case ID
     * @param s3Path - The S3 path to the archived case data
     * @param archiveBaseUrl - Base URL for archive system (optional)
     * @return URL string to navigate to
     */
    private static String generateCaseUrl(String caseId, String s3Path, String archiveBaseUrl) {
        return '#';
    }
    
    /**
     * Generate URL for opening archive service case (public method for backward compatibility)
     * @param caseId - The archive case ID
     * @param s3Path - The S3 path to the archived case data
     * @return URL string to navigate to
     */
    @AuraEnabled
    public static String openArchiveServiceCase(String caseId, String s3Path) {
        String archiveBaseUrl = getArchiveSystemBaseUrl();
        return generateCaseUrl(caseId, s3Path, archiveBaseUrl);
    }
    
    /**
     * Get archive system base URL from configuration
     * TODO: Implement your configuration logic here
     * @return Base URL string or empty string
     */
    @AuraEnabled(cacheable=true)
    public static String getArchiveSystemBaseUrl() {
        // TODO: Get from Custom Metadata Type or Custom Settings
        // Example:
        // Archive_System_Config__mdt config = [
        //     SELECT Base_URL__c 
        //     FROM Archive_System_Config__mdt 
        //     WHERE DeveloperName = 'Default_Config' 
        //     LIMIT 1
        // ];
        // return config.Base_URL__c;
        
        // For now, return empty to use Salesforce fallback
        return '';
    }
    
    // Mock data generator - Returns 50 sample records
    @TestVisible
    private static List<ArchiveInteractionRow> getMockArchiveInteractions() {
        List<ArchiveInteractionRow> mockRows = new List<ArchiveInteractionRow>();
        
        List<String> migrationSources = new List<String>{
            'Legacy System A', 'Legacy System B', 'CRM Migration', 'Manual Import',
            'Athena Archive', 'Data Migration Tool', 'External Import', 'Historical Data'
        };
        
        List<String> customerNames = new List<String>{
            'Nguyen Van A', 'Tran Thi B', 'Le Van C', 'Pham Thi D', 'Hoang Van E',
            'Vo Thi F', 'Dang Van G', 'Bui Thi H', 'Ngo Van I', 'Truong Thi K',
            'Do Van L', 'Duong Thi M', 'Ha Van N', 'Huynh Thi O', 'Lam Van P',
            'Ly Thi Q', 'Mai Van R', 'Phan Thi S', 'Ta Van T', 'Ton Thi U',
            'Trinh Van V', 'Vu Thi W', 'Dinh Van X', 'Cao Thi Y', 'Chu Van Z'
        };
        
        List<String> accountNumbers = new List<String>{
            '123456', '789012', '345678', '567890', '901234', '234567', '678901', '456789'
        };
        
        String archiveBaseUrl = getArchiveSystemBaseUrl();
        Integer year = 2024;
        Integer month = 1;
        
        for (Integer i = 1; i <= 50; i++) {
            ArchiveInteractionRow row = new ArchiveInteractionRow();
            
            // Format numbers with leading zeros
            String extIdNum = String.valueOf(i).leftPad(3, '0');
            String caseIdNum = String.valueOf(1000 + i);
            String ctrNum = String.valueOf(1000 + i);
            
            row.externalId = 'EXT-' + extIdNum;
            row.caseId = 'CASE-' + year + '-' + caseIdNum;
            row.s3Path = 's3://archive-bucket/' + year + '/' + String.valueOf(month).leftPad(2, '0') + '/case-' + extIdNum + '.json';
            row.migrationSource = migrationSources[Math.mod(i - 1, migrationSources.size())];
            row.accountNumber = accountNumbers[Math.mod(i - 1, accountNumbers.size())];
            
            // Some records have null contract number
            if (Math.mod(i, 7) == 0) {
                row.contractNumber = null;
            } else {
                row.contractNumber = 'CTR-' + ctrNum;
            }
            
            row.customerName = customerNames[Math.mod(i - 1, customerNames.size())];
            
            // Generate case URL
            row.caseUrl = generateCaseUrl(row.caseId, row.s3Path, archiveBaseUrl);
            
            mockRows.add(row);
            
            // Increment month for variety
            month++;
            if (month > 12) {
                month = 1;
                year--;
            }
        }
        
        return mockRows;
    }
    
    public class ArchiveInteractionRow {
        @AuraEnabled public String externalId;
        @AuraEnabled public String caseId;
        @AuraEnabled public String caseUrl;
        @AuraEnabled public String s3Path;
        @AuraEnabled public String migrationSource;
        @AuraEnabled public String accountNumber;
        @AuraEnabled public String contractNumber;
        @AuraEnabled public String customerName;
        @AuraEnabled public String subcode;
        @AuraEnabled public String subcategory;
        @AuraEnabled public DateTime pxcreatedatetime;
        @AuraEnabled public String interactionChannel;
        @AuraEnabled public String status;
        @AuraEnabled public String phone;
        @AuraEnabled public String currentInteractionId;
        @AuraEnabled public String nationalId;
    }
}