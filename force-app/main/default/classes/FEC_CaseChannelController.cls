/**
 * @description Controller cho FEC_Case_Channel__c CRUD operations
 * @date 2025-01-10
 * @author DAT NGO
 */
public with sharing class FEC_CaseChannelController {
    
    @AuraEnabled(cacheable=true)
    public static List<FEC_Case_Channel__c> getCaseChannels() {
        try {
            List<FEC_Case_Channel__c> channels = [
                SELECT Id, Name, FEC_Code__c, FEC_Channel_Status__c, FEC_Self_Service_Flag__c,
                       FEC_Status__c, FEC_Name_VN__c, FEC_Alias__c, Process_Change_Status__c
                FROM FEC_Case_Channel__c
                ORDER BY Name ASC
            ];
            // Enforce FLS
            List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, channels).getRecords();
            return (List<FEC_Case_Channel__c>) safe;
        } catch (Exception e) {
            System.debug('Error in getCaseChannels: ' + e.getMessage());
            throw new AuraHandledException('Error loading Case Channels: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Id saveCaseChannel(Map<String, Object> mappingReq) {
        try {
            String recordId = (String)mappingReq.get('Id');
            FEC_Case_Channel__c channel = String.isNotBlank(recordId)
                ? new FEC_Case_Channel__c(Id = recordId)
                : new FEC_Case_Channel__c();
            
            // Set Process_Change_Status
            if (String.isBlank(recordId)) {
                channel.Process_Change_Status__c = 'New';
            } else {
                channel.Process_Change_Status__c = 'Update';
            }
            
            // Map fields
            if (mappingReq.containsKey('Name')) {
                channel.Name = (String)mappingReq.get('Name');
            }
            if (mappingReq.containsKey('FEC_Code__c')) {
                channel.FEC_Code__c = (String)mappingReq.get('FEC_Code__c');
            }
            if (mappingReq.containsKey('FEC_Channel_Status__c')) {
                channel.FEC_Channel_Status__c = (Boolean)mappingReq.get('FEC_Channel_Status__c');
            }
            if (mappingReq.containsKey('FEC_Self_Service_Flag__c')) {
                channel.FEC_Self_Service_Flag__c = (Boolean)mappingReq.get('FEC_Self_Service_Flag__c');
            }
            if (mappingReq.containsKey('FEC_Status__c')) {
                channel.FEC_Status__c = (Boolean)mappingReq.get('FEC_Status__c');
            }
            if (mappingReq.containsKey('FEC_Name_VN__c')) {
                channel.FEC_Name_VN__c = (String)mappingReq.get('FEC_Name_VN__c');
            }
            if (mappingReq.containsKey('FEC_Alias__c')) {
                channel.FEC_Alias__c = (String)mappingReq.get('FEC_Alias__c');
            }
            
            upsert channel;
            return channel.Id;
        } catch (DmlException dml) {
            System.debug('DML Error: ' + dml.getMessage());
            throw new AuraHandledException('Error saving Case Channel: ' + dml.getDmlMessage(0));
        } catch (Exception e) {
            System.debug('Error in saveCaseChannel: ' + e.getMessage());
            throw new AuraHandledException('Error saving Case Channel: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void deleteCaseChannel(Id recordId) {
        try {
            if (recordId == null) {
                throw new AuraHandledException('Invalid record ID');
            }
            delete new FEC_Case_Channel__c(Id = recordId);
        } catch (Exception e) {
            System.debug('Error in deleteCaseChannel: ' + e.getMessage());
            throw new AuraHandledException('Error deleting Case Channel: ' + e.getMessage());
        }
    }
}