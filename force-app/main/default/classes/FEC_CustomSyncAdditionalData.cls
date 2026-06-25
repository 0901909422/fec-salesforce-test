public with sharing class FEC_CustomSyncAdditionalData {
    // Wrapper class để map đúng format JSON output
    public class OutputWrapper {
        public List<RecordDetail> records { get; set; }
        public String tableName { get; set; }
        public OutputWrapper() {
            this.records = new List<RecordDetail>();
            this.tableName = '';
        }
    }

    public class RecordDetail {
        public String PZINSKEY { get; set; }
        public String PXEXTRACTIDENTIFIER { get; set; }
        public String PXEXTRACTDATETIME { get; set; }
        public String ID { get; set; }
        public Object Value { get; set; }
        public String Type { get; set; }
    }

    public static String getAdditionalNeedToSync(FEC_Custom_Sync__c cus, DateTime startTime, DateTime toDate) {
        String modifiedField = String.isNotBlank(cus.FEC_Modified_Date_Field__c) ? cus.FEC_Modified_Date_Field__c : 'LastModifiedDate';
        String createdField = String.isNotBlank(cus.FEC_Created_Date_Field__c) ? cus.FEC_Created_Date_Field__c : 'CreatedDate';
        String wherePart = ' WHERE ((' + modifiedField + ' > :startTime AND ' + modifiedField + ' <= :toDate) ' +
                           ' OR (' + createdField + ' > :startTime AND ' + createdField + ' <= :toDate) )';
        String query = 'SELECT Id, FEC_Case__c FROM ' + cus.FEC_Target_Object__c + wherePart;
        System.debug('Dynamic SOQL Query for Additional Properties: ' + query);
        return query;
    }
    public static String getAdditionalInfoJson(List<SObject> scope, String tableName) {
        OutputWrapper response = new OutputWrapper();
        List<Id> caseIds = new List<Id>();
        for (SObject record : scope) {
            caseIds.add((Id) record.get('FEC_Case__c'));
        }
        System.debug('Case IDs to process: ' + caseIds);
        if (caseIds == null || caseIds.isEmpty()) return JSON.serialize(response);

        // --- BƯỚC 1: Query Case và gom cụm ---
        Map<Id, Case> caseMap = new Map<Id, Case>([
            SELECT Id, FEC_ID_Search__c, FEC_Actual_Nature_of_Case__c,  FEC_Business_Process__r.Name
            FROM Case 
            WHERE Id IN :caseIds
        ]);

        Set<Id> natureOfCaseIds = new Set<Id>();
        for (Case c : caseMap.values()) {
            if (c.FEC_Actual_Nature_of_Case__c != null) {
                natureOfCaseIds.add(c.FEC_Actual_Nature_of_Case__c);
            }
        }

        if (natureOfCaseIds.isEmpty()) return JSON.serialize(response);

        // --- BƯỚC 2: Query Master Data Setting để lấy danh sách Field cấu hình ---
        Map<Id, Set<String>> natureToFieldsMap = new Map<Id, Set<String>>();
        Set<String> allFieldsToQuery = new Set<String>();

        List<FEC_Actual_Master_Data_Setting__c> settings = [
            SELECT FEC_Actual_Nature_of_Case__c, FEC_Field_API_Name__c 
            FROM FEC_Actual_Master_Data_Setting__c 
            WHERE FEC_Actual_Nature_of_Case__c IN :natureOfCaseIds 
            AND FEC_Field_Object_Name__c = 'FEC_Additional_Info__c'
            AND FEC_Field_API_Name__c != null
        ];

        for (FEC_Actual_Master_Data_Setting__c setting : settings) {
            String fieldApi = setting.FEC_Field_API_Name__c.trim();
            allFieldsToQuery.add(fieldApi.toLowerCase()); // Lowercase để tránh trùng lặp hoa thường
            System.debug('Config Setting - Nature: ' + setting.FEC_Actual_Nature_of_Case__c + ', Field: ' + fieldApi);

            if (!natureToFieldsMap.containsKey(setting.FEC_Actual_Nature_of_Case__c)) {
                natureToFieldsMap.put(setting.FEC_Actual_Nature_of_Case__c, new Set<String>());
            }
            natureToFieldsMap.get(setting.FEC_Actual_Nature_of_Case__c).add(fieldApi);
        }

        if (allFieldsToQuery.isEmpty()) return JSON.serialize(response);

        // --- BƯỚC 3: Lấy Metadata Type của Object FEC_Additional_Info__c ---
        Map<String, Schema.SObjectField> fieldMetadataMap = Schema.SObjectType.FEC_Additional_Info__c.fields.getMap();

        // --- BƯỚC 3.5: Validate và phân loại fields: tồn tại và không tồn tại ---
        Set<String> validFields = new Set<String>();
        Set<String> invalidFields = new Set<String>();
        
        for (String fieldName : allFieldsToQuery) {
            if (fieldMetadataMap.containsKey(fieldName.toLowerCase())) {
                validFields.add(fieldName);
            } else {
                invalidFields.add(fieldName);
                System.debug('Field does not exist in FEC_Additional_Info__c: ' + fieldName);
            }
        }

        // --- BƯỚC 4: Build Dynamic SOQL với chỉ những field hợp lệ ---
        List<FEC_Additional_Info__c> additionalInfoRecords = new List<FEC_Additional_Info__c>();
        
        if (!validFields.isEmpty()) {
            String fieldsString = String.join(new List<String>(validFields), ', ');
            String dynamicQuery = 'SELECT Id, FEC_Case__c, ' + fieldsString + ' FROM FEC_Additional_Info__c WHERE FEC_Case__c IN :caseIds';
            System.debug('Dynamic SOQL Query: ' + dynamicQuery);
            additionalInfoRecords = Database.query(dynamicQuery);
        } else {
            // Nếu không có field hợp lệ nào, vẫn query Id và FEC_Case__c để xử lý invalidFields
            additionalInfoRecords = [SELECT Id, FEC_Case__c FROM FEC_Additional_Info__c WHERE FEC_Case__c IN :caseIds];
        }
        System.debug('Queried Additional Info Records: ' + additionalInfoRecords);
        System.debug('Nature to Fields Map: ' + natureToFieldsMap);

        // --- BƯỚC 5: Xử lý gán Data vào JSON Format ---
        String nowStr = Datetime.now().format('yyyy-MM-dd HH:mm:ss');

        for (FEC_Additional_Info__c addInfo : additionalInfoRecords) {
            Case parentCase = caseMap.get(addInfo.FEC_Case__c);
            if (parentCase == null || parentCase.FEC_Actual_Nature_of_Case__c == null) continue;

            // Lấy ra các field được chỉ định cho Nature of Case của Case hiện tại
            Set<String> targetFields = natureToFieldsMap.get(parentCase.FEC_Actual_Nature_of_Case__c);
            System.debug('Parent Case ID: ' + parentCase.Id + ', Nature of Case: ' + parentCase.FEC_Actual_Nature_of_Case__c + ', Target Fields: ' + targetFields);
            if (targetFields == null) continue;
            System.debug('Processing Case ID: ' + parentCase.Id + ' with Nature: ' + parentCase.FEC_Actual_Nature_of_Case__c + ' and Target Fields: ' + targetFields);

            for (String fieldName : targetFields) {
                RecordDetail detail = new RecordDetail();
                detail.PZINSKEY = parentCase.FEC_ID_Search__c;
                detail.PXEXTRACTIDENTIFIER = parentCase.FEC_Business_Process__r.Name;
                detail.PXEXTRACTDATETIME = nowStr;
                detail.ID = fieldName;
                
                // Check nếu field tồn tại trong object
                if (validFields.contains(fieldName.toLowerCase())) {
                    // Lấy giá trị động từ sObject
                    detail.Value = addInfo.get(fieldName);
                    
                    // Lấy Data Type động từ Schema
                    Schema.SObjectField fieldToken = fieldMetadataMap.get(fieldName.toLowerCase());
                    if (fieldToken != null) {
                        detail.Type = String.valueOf(fieldToken.getDescribe().getType());
                    } else {
                        detail.Type = 'UNKNOWN';
                    }
                } else {
                    // Field không tồn tại trong object -> Value = null
                    detail.Value = null;
                    detail.Type = 'UNKNOWN';
                    System.debug('Field not found in object, setting Value to null: ' + fieldName);
                }
                
                System.debug('Adding Detail: ' + detail);
                response.records.add(detail);
            }
            response.tableName = tableName;
        }
        System.debug('Final JSON Response: ' + JSON.serialize(response));

        // Serialize wrapper class sang chuỗi JSON theo đúng format yêu cầu
        return JSON.serialize(response);
    }
}