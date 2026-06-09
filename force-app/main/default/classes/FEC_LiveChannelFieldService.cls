/**
 * @description Service layer for Live Channels + Additional Fields + BP options.
 *              Extracted from FEC_LiveDataViewController in Phase 2.4 refactor.
 * @author      DAT NGO
 * @date        2026-05-28
 * @category    MDM Refactor Phase 2.4
 */
public with sharing class FEC_LiveChannelFieldService {

    public static List<FEC_Channel__c> getLiveChannels() {
        try {
            List<FEC_Channel__c> channels = [
                SELECT Id, Name, FEC_Channel_ID__c, FEC_Channel_Vietnamese_name__c, FEC_Channel_Status__c
                FROM   FEC_Channel__c
                ORDER BY Name ASC
            ];
            return (List<FEC_Channel__c>) Security.stripInaccessible(AccessType.READABLE, channels).getRecords();
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static List<FEC_Case_Channel__c> getLiveCaseChannels() {
        try {
            List<FEC_Case_Channel__c> caseChannels = [
                SELECT Id, Name, FEC_Code__c, FEC_Channel_Status__c, FEC_Self_Service_Flag__c
                FROM   FEC_Case_Channel__c
                ORDER BY Name ASC
            ];
            return (List<FEC_Case_Channel__c>) Security.stripInaccessible(AccessType.READABLE, caseChannels).getRecords();
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static List<FEC_Additional_Field__c> getLiveAdditionalFields() {
        try {
            List<FEC_Additional_Field__c> fields = [
                SELECT Id, FEC_Unique_ID__c, Name, FEC_Type__c,
                       FEC_Field_Status__c, FEC_Field_Mandatory__c
                FROM   FEC_Additional_Field__c
                ORDER BY Name ASC
            ];
            return (List<FEC_Additional_Field__c>) Security.stripInaccessible(AccessType.READABLE, fields).getRecords();
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static List<FEC_Additional_Field_List_Value__c> getLiveFieldListValues(String fieldId) {
        if (String.isBlank(fieldId)) return new List<FEC_Additional_Field_List_Value__c>();
        try {
            List<FEC_Additional_Field_List_Value__c> listValues = [
                SELECT Id, Name, FEC_Code__c, FEC_Name_VN__c, FEC_Order__c
                FROM   FEC_Additional_Field_List_Value__c
                WHERE  FEC_Additional_Field__c = :fieldId
                ORDER BY FEC_Order__c ASC
            ];
            return (List<FEC_Additional_Field_List_Value__c>) Security.stripInaccessible(AccessType.READABLE, listValues).getRecords();
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static List<Map<String, String>> getLiveBusinessProcessOptions() {
        try {
            List<FEC_Business_Process__c> bps = [
                SELECT Id, Name, FEC_Code__c
                FROM   FEC_Business_Process__c
                ORDER BY Name ASC
            ];
            List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, bps).getRecords();
            List<Map<String, String>> result = new List<Map<String, String>>();
            for (FEC_Business_Process__c bp : (List<FEC_Business_Process__c>) safe) {
                result.add(new Map<String, String>{
                    FEC_UIConstants.MAP_LABEL => bp.Name,
                    FEC_UIConstants.MAP_VALUE => bp.Id
                });
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }
}