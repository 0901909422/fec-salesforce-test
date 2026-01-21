public with sharing class FecCampaignController {

    @AuraEnabled(cacheable=true)
    public static List<FEC_CS_Campaign__c> getCampaignMappings() {
        return [
            SELECT Id, Name, FEC_IsActive__c, 
                   FEC_Campaign__c, FEC_Campaign__r.Name, FEC_Campaign__r.FEC_CampaignId__c
            FROM FEC_CS_Campaign__c
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<FEC_Campaign__c> getCampaignConfigs() {
        return [
            SELECT Id, FEC_CampaignId__c
            FROM FEC_Campaign__c
        ];
    }

    @AuraEnabled
    public static Map<String, Object> getInProgressSummary(String mappingId) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            FEC_CS_Campaign__c mapping = [SELECT FEC_Campaign__c, FEC_Campaign__r.FEC_CampaignId__c 
                                          FROM FEC_CS_Campaign__c 
                                          WHERE Id = :mappingId LIMIT 1];
            
            // Query đầy đủ các field theo template
            List<FEC_DataCampaign__c> records = [
                SELECT FEC_ProductLine__c, FEC_AppID__c, FEC_AccountOrContractNumber__c,
                       FEC_DateTime1__c, FEC_DateTime2__c, FEC_DateTime3__c,
                       FEC_Number1__c, FEC_Number2__c, FEC_Number3__c, FEC_Number4__c, FEC_Number5__c,
                       FEC_String1__c, FEC_String2__c, FEC_String3__c, FEC_String4__c, FEC_String5__c
                FROM FEC_DataCampaign__c 
                WHERE FEC_Campaign__c = :mapping.FEC_Campaign__c 
                AND FEC_RecordStatus__c != 'Resolved'
                LIMIT 40000
            ];

            result.put('count', records.size());
            result.put('data', records);
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static String saveMapping(Map<String, Object> mappingData) {
        try {
            String name = (String) mappingData.get('Name');
            Id genesysCampaignId = (Id) mappingData.get('FEC_Campaign__c');
            Boolean isActive = (Boolean) mappingData.get('FEC_IsActive__c');
            Id recordId = mappingData.containsKey('Id') ? (Id) mappingData.get('Id') : null;

            if (isActive == true) {
                List<FEC_CS_Campaign__c> existingActiveMappings = [
                    SELECT Id, FEC_IsActive__c 
                    FROM FEC_CS_Campaign__c 
                    WHERE FEC_Campaign__c = :genesysCampaignId 
                    AND FEC_IsActive__c = true
                    AND Id != :recordId
                ];

                if (!existingActiveMappings.isEmpty()) {
                    for (FEC_CS_Campaign__c m : existingActiveMappings) {
                        m.FEC_IsActive__c = false;
                    }
                    update existingActiveMappings;
                }
            }

            FEC_CS_Campaign__c currentRecord = new FEC_CS_Campaign__c();
            if (recordId != null) currentRecord.Id = recordId;
            
            currentRecord.Name = name;
            currentRecord.FEC_Campaign__c = genesysCampaignId;
            currentRecord.FEC_IsActive__c = isActive;

            upsert currentRecord;
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException('Error saving mapping: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteMapping(String recordId) {
        try {
            delete [SELECT Id FROM FEC_CS_Campaign__c WHERE Id = :recordId];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @param jsonString: Chuỗi JSON được parse từ Excel ở phía LWC (Client-side)
     * @param campaignId: ID của chiến dịch user đang chọn
     */
    @AuraEnabled
    public static String uploadCampaignData(String jsonString, String campaignId) {
        if (String.isBlank(campaignId)) FecUtils.throwCreateException(FecUtils.MSG_FILE_ERR);

        Savepoint sp = Database.setSavepoint();
        try {
            List<Object> dataList = (List<Object>) JSON.deserializeUntyped(jsonString);
            if (dataList.isEmpty()) FecUtils.throwCreateException(FecUtils.MSG_FILE_ERR);

            // 1. Lấy thông tin Campaign gốc
            FEC_CS_Campaign__c cmp = [SELECT Id, Name, FEC_Campaign__c, FEC_Campaign__r.Id, FEC_Campaign__r.Name, FEC_Campaign__r.FEC_CampaignId__c FROM FEC_CS_Campaign__c WHERE Id = :campaignId LIMIT 1];
            String actualCode = cmp.Name;
            String genesysCampaignId = cmp.FEC_Campaign__r.Id;
            String genesysCampaignCode = cmp.FEC_Campaign__r.FEC_CampaignId__c;

            List<FEC_DataCampaign__c> recordsToInsert = new List<FEC_DataCampaign__c>();
            Set<String> compositeKeys = new Set<String>();

            // 2. Xử lý dữ liệu
            for (Object obj : dataList) {
                Map<String, Object> row = (Map<String, Object>) obj;
                
                // Validate toàn bộ dòng
                validateRow(row, actualCode);

                // Kiểm tra trùng lặp (Composite Key)
                String key = generateKey(row);
                if (compositeKeys.contains(key)) FecUtils.throwCreateException(FecUtils.MSG_DUP_ERR);
                compositeKeys.add(key);

                // Map sang SObject
                recordsToInsert.add(mapToSObject(row, genesysCampaignId, genesysCampaignCode));
            }

            if (!recordsToInsert.isEmpty()) insert recordsToInsert;
            return FecUtils.MSG_SUCCESS;

        } catch (Exception e) {
            Database.rollback(sp);
            handleUploadException(e);
            return null;
        }
    }

    private static void validateRow(Map<String, Object> row, String actualCode) {
        String excelCmpId = FecUtils.toString(row.get('Campaign ID'));
        String productLine = FecUtils.toString(row.get('ProductLine'));
        String appId = FecUtils.toString(row.get('App ID'));
        String accNum = FecUtils.toString(row.get('Account or Contract number'));

        // Kiểm tra logic validation gom cụm
        Boolean isInvalid = 
            (excelCmpId == null || !excelCmpId.equals(actualCode)) ||
            (String.isBlank(productLine) || productLine.length() > 12) ||
            (!productLine.equalsIgnoreCase('Loan') && !productLine.equalsIgnoreCase('Card')) ||
            (String.isBlank(appId) || appId.length() > 32) ||
            (String.isBlank(accNum) || accNum.length() > 32) ||
            (!FecUtils.checkIsNumber(row.get('Number 1'))) ||
            (!FecUtils.checkIsNumber(row.get('Number 2'))) ||
            (!FecUtils.checkIsNumber(row.get('Number 3')));

        if (isInvalid) FecUtils.throwCreateException(FecUtils.MSG_FILE_ERR);
    }

    private static String generateKey(Map<String, Object> row) {
        return FecUtils.toString(row.get('ProductLine')) + '_' + 
               FecUtils.toString(row.get('App ID')) + '_' + 
               FecUtils.toString(row.get('Account or Contract number'));
    }

    private static FEC_DataCampaign__c mapToSObject(Map<String, Object> row, String genesysCampaignId, String genesysCampaignCode) {
        return new FEC_DataCampaign__c(
            FEC_Campaign__c = genesysCampaignId,
            FEC_GenesysId__c = genesysCampaignCode,
            FEC_RecordStatus__c = 'New',
            FEC_ProductLine__c = FecUtils.toString(row.get('ProductLine')),
            FEC_AppID__c = FecUtils.toString(row.get('App ID')),
            FEC_AccountOrContractNumber__c = FecUtils.toString(row.get('Account or Contract number')),
            FEC_Number1__c = FecUtils.toDecimal(row.get('Number 1')),
            FEC_Number2__c = FecUtils.toDecimal(row.get('Number 2')),
            FEC_Number3__c = FecUtils.toDecimal(row.get('Number 3')),
            FEC_Number4__c = FecUtils.toDecimal(row.get('Number 4')),
            FEC_Number5__c = FecUtils.toDecimal(row.get('Number 5')),
            FEC_String1__c = FecUtils.toString(row.get('String 1')),
            FEC_String2__c = FecUtils.toString(row.get('String 2')),
            FEC_String3__c = FecUtils.toString(row.get('String 3')),
            FEC_String4__c = FecUtils.toString(row.get('String 4')),
            FEC_String5__c = FecUtils.toString(row.get('String 5')),
            FEC_DateTime1__c = FecUtils.toDateTime(row.get('DateTime 1')),
            FEC_DateTime2__c = FecUtils.toDateTime(row.get('DateTime 2')),
            FEC_DateTime3__c = FecUtils.toDateTime(row.get('DateTime 3'))
        );
    }

    private static void handleUploadException(Exception e) {
        String msg = e.getMessage();
        if (msg.contains(FecUtils.MSG_DUP_ERR)) {
            FecUtils.throwCreateException(FecUtils.MSG_DUP_ERR);
        } else {
            System.debug('ERROR: ' + e.getStackTraceString());
            FecUtils.throwCreateException(FecUtils.MSG_FILE_ERR);
        }
    }
}