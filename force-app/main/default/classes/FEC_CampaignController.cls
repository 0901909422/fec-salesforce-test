/**
 * FEC_CampaignController
 * Apex controller for fecCampaign LWC component.
 * Refactored to delegate validation to FEC_CampaignValidator.
 */
public with sharing class FEC_CampaignController {

    @AuraEnabled(cacheable=true)
    public static List<FEC_CS_Campaign__c> getCampaignMappings() {
        return [SELECT Id, Name, FEC_IsActive__c, 
                    FEC_Campaign__c, FEC_Campaign__r.Name, FEC_Campaign__r.FEC_CampaignId__c,
                    FEC_ScheduleCampaign__c, 
                    FEC_SaturdaySchedule__c, 
                    FEC_SundaySchedule__c 
                FROM FEC_CS_Campaign__c];
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
            List<FEC_DataCampaign__c> records = [
                SELECT FEC_ProductLine__c, FEC_AppID__c, FEC_AccountOrContractNumber__c,
                       FEC_DateTime1__c, FEC_DateTime2__c, FEC_DateTime3__c,
                       FEC_Number1__c, FEC_Number2__c, FEC_Number3__c, FEC_Number4__c, FEC_Number5__c,
                       FEC_String1__c, FEC_String2__c, FEC_String3__c, FEC_String4__c, FEC_String5__c,
                       CreatedDate, FEC_InsertionDate__c
                FROM FEC_DataCampaign__c 
                WHERE FEC_CS_Campaign__c = :mappingId 
                AND (NOT FEC_RecordStatus__c LIKE 'Resolved-%')
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
            return FEC_ConstantCommon.SUCCESS_MESSAGE;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Saving_Error_Message + e.getMessage());
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
     * @param jsonString: JSON string parsed from Excel on the LWC (Client-side)
     * @param csCampaignId: ID of the CS Campaign the user selected
     */
    @AuraEnabled
    public static String uploadCampaignData(String jsonString, String csCampaignId) {
        if (String.isBlank(csCampaignId)) {
            FEC_Util.throwCreateException(FEC_Constants.MSG_FILE_ERR);
        }

        Savepoint sp = Database.setSavepoint();
        try {
            List<Object> rawList = (List<Object>) JSON.deserializeUntyped(jsonString);
            if (rawList.isEmpty()) {
                FEC_Util.throwCreateException(FEC_Constants.MSG_FILE_ERR);
            }

            FEC_CS_Campaign__c cmp = [
                SELECT Id, Name, FEC_Campaign__c, FEC_Campaign__r.Id,
                    FEC_Campaign__r.Name, FEC_Campaign__r.FEC_CampaignId__c,
                    FEC_Campaign__r.FEC_CampaignCallingList__c,
                    FEC_Campaign__r.FEC_MaxCallingAttempt__c,
                    FEC_Campaign__r.FEC_RecordLifeTime__c
                FROM FEC_CS_Campaign__c
                WHERE Id = :csCampaignId LIMIT 1
            ];
            String actualCode = cmp.Name;

            List<Map<String, Object>> rows = new List<Map<String, Object>>();
            for (Object obj : rawList) {
                rows.add((Map<String, Object>) obj);
            }

            List<FEC_CampaignValidator.ValidationResult> validationErrors =
                FEC_CampaignValidator.validateUploadData(rows, actualCode);
            List<String> duplicateErrors = FEC_CampaignValidator.checkDuplicateKeys(rows);

            List<String> allErrors = new List<String>();
            for (FEC_CampaignValidator.ValidationResult vr : validationErrors) {
                allErrors.addAll(vr.errors);
            }
            allErrors.addAll(duplicateErrors);

            if (!allErrors.isEmpty()) {
                FEC_Util.throwCreateException(String.join(allErrors, '; '));
            }

            List<FEC_DataCampaign__c> recordsToInsert = new List<FEC_DataCampaign__c>();
            for (Map<String, Object> row : rows) {
                recordsToInsert.add(mapToSObject(row, cmp, csCampaignId));
            }
            if (!recordsToInsert.isEmpty()) {
                insert recordsToInsert;
            }
            return FEC_ConstantCommon.SUCCESS_MESSAGE;

        } catch (Exception e) {
            Database.rollback(sp);
            handleUploadException(e);
            return null;
        }
    }


    @AuraEnabled
    public static void saveConfigurationDetails(Id mappingId, Boolean isSchedule, Boolean isSaturday, Boolean isSunday) {
        try {
            FEC_CS_Campaign__c mapping = [SELECT Id, FEC_Campaign__c FROM FEC_CS_Campaign__c WHERE Id = :mappingId LIMIT 1];
            if (mapping != null) {
                FEC_CS_Campaign__c campaignToUpdate = new FEC_CS_Campaign__c(
                    Id = mapping.Id,
                    FEC_ScheduleCampaign__c = isSchedule,
                    FEC_SaturdaySchedule__c = isSaturday,
                    FEC_SundaySchedule__c = isSunday
                );
                update campaignToUpdate;
            } else {
                throw new AuraHandledException(System.Label.FEC_Mapping_Could_Not_Be_Found_Message);
            }
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Saving_Error_Message + e.getMessage());
        }
    }

    @AuraEnabled
    public static String pushRecords(Id mappingId) {
        if (mappingId == null) {
            throw new AuraHandledException(System.Label.FEC_Please_Select_A_Campaign_Message);
        }
        FEC_CS_Campaign__c mappingRecord = new FEC_CS_Campaign__c(
            Id = mappingId,
            FEC_PushInstant__c = true
        );
        update mappingRecord;
        FEC_PushCampaignDataBatch batch = new FEC_PushCampaignDataBatch(mappingId);
        Id jobId = Database.executeBatch(batch, 2000);
        return jobId;
    }

    // ─── Private Helpers ───────────────────────────────────────────

    private static String generateKey(Map<String, Object> row) {
        return FEC_Util.toString(row.get('ProductLine')) + '_' + 
               FEC_Util.toString(row.get('App ID')) + '_' + 
               FEC_Util.toString(row.get('Account or Contract number'));
    }

    private static FEC_DataCampaign__c mapToSObject(Map<String, Object> row, FEC_CS_Campaign__c cmp, String csCampaignId) {
        return new FEC_DataCampaign__c(
            FEC_CS_Campaign__c = csCampaignId,
            FEC_ProductLine__c = FEC_Util.toString(row.get('ProductLine')),
            FEC_AppID__c = FEC_Util.toString(row.get('App ID')),
            FEC_AccountOrContractNumber__c = FEC_Util.toString(row.get('Account or Contract number')),
            FEC_Number1__c = FEC_Util.toDecimal(row.get('Number 1')),
            FEC_Number2__c = FEC_Util.toDecimal(row.get('Number 2')),
            FEC_Number3__c = FEC_Util.toDecimal(row.get('Number 3')),
            FEC_Number4__c = FEC_Util.toDecimal(row.get('Number 4')),
            FEC_Number5__c = FEC_Util.toDecimal(row.get('Number 5')),
            FEC_String1__c = FEC_Util.toString(row.get('String 1')),
            FEC_String2__c = FEC_Util.toString(row.get('String 2')),
            FEC_String3__c = FEC_Util.toString(row.get('String 3')),
            FEC_String4__c = FEC_Util.toString(row.get('String 4')),
            FEC_String5__c = FEC_Util.toString(row.get('String 5')),
            FEC_DateTime1__c = FEC_Util.toDateTime(row.get('DateTime 1')),
            FEC_DateTime2__c = FEC_Util.toDateTime(row.get('DateTime 2')),
            FEC_DateTime3__c = FEC_Util.toDateTime(row.get('DateTime 3')),
            FEC_RecordStatus__c = FEC_Constants.CAMPAIGN_STATUS_NEW,
            FEC_CampaignCallingList__c = cmp.FEC_Campaign__r.FEC_CampaignCallingList__c,
            FEC_MaxCallAttempt__c = cmp.FEC_Campaign__r.FEC_MaxCallingAttempt__c != null ? cmp.FEC_Campaign__r.FEC_MaxCallingAttempt__c : FEC_Constants.MAX_CALL_ATTEMPTS,
            FEC_RecordLifetime__c = cmp.FEC_Campaign__r.FEC_RecordLifeTime__c != null ? cmp.FEC_Campaign__r.FEC_RecordLifeTime__c : FEC_Constants.CAMPAIGN_LIFETIME,
            FEC_CurrentCallAttempt__c = FEC_Constants.CURRENT_CALL_ATTEMPT,
            FEC_RecordCurrentLifetime__c = FEC_Constants.RECORD_CURRENT_LIFETIME
        );
    }

    private static void handleUploadException(Exception e) {
        String msg = e.getMessage();
        if (msg != null && msg.contains(FEC_Constants.MSG_DUP_ERR)) {
            FEC_Util.throwCreateException(FEC_Constants.MSG_DUP_ERR);
        } else {
            FEC_Util.throwCreateException(msg != null ? msg : FEC_Constants.MSG_FILE_ERR);
        }
    }
}
