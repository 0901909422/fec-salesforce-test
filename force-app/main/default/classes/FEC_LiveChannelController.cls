/**
 * @description Live mirror of FEC_ChannelController + FEC_CaseChannelController.
 *              Provides CRUD on Live FEC_Channel__c and FEC_Case_Channel__c.
 * @date   2026
 */
public with sharing class FEC_LiveChannelController {

    // ─────────────────────────────────────────────────────────────────────
    //  FEC_Channel__c
    // ─────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<FEC_Channel__c> getChannels() {
        List<FEC_Channel__c> results = [
            SELECT Id, Name, FEC_Channel_ID__c, FEC_Channel_Vietnamese_name__c,
                   FEC_Channel_Status__c, FEC_Self_Service_Flag__c
            FROM FEC_Channel__c
            ORDER BY CreatedDate DESC
        ];
        return (List<FEC_Channel__c>) Security.stripInaccessible(AccessType.READABLE, results).getRecords();
    }

    @AuraEnabled
    public static String deleteChannel(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_DELETE_RECORD_PREFIX + ' Invalid Id');
        }
        try {
            if (!FEC_Channel__c.SObjectType.getDescribe().isDeletable()) {
                throw new AuraHandledException(System.Label.FEC_Error_No_Delete_Permission);
            }
            Database.DeleteResult dr = Database.delete(new FEC_Channel__c(Id = recordId), false);
            if (!dr.isSuccess()) {
                String msg = (dr.getErrors().size() > 0) ? dr.getErrors()[0].getMessage() : 'Unknown delete error';
                throw new AuraHandledException(FEC_UIConstants.ERROR_DELETE_RECORD_PREFIX + ' ' + msg);
            }
            return FEC_UIConstants.OPERATION_SUCCESS;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_DELETE_RECORD_PREFIX + ' ' + e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    //  FEC_Case_Channel__c
    // ─────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<FEC_Case_Channel__c> getCaseChannels() {
        try {
            List<FEC_Case_Channel__c> channels = [
                SELECT Id, Name, FEC_Code__c, FEC_Channel_Status__c, FEC_Self_Service_Flag__c,
                       FEC_Status__c, FEC_Name_VN__c, FEC_Alias__c
                FROM FEC_Case_Channel__c
                ORDER BY Name ASC
            ];
            return (List<FEC_Case_Channel__c>) Security.stripInaccessible(AccessType.READABLE, channels).getRecords();
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Id saveCaseChannel(Map<String, Object> mappingReq) {
        try {
            String recordId = (String) mappingReq.get('Id');
            FEC_Case_Channel__c channel = String.isNotBlank(recordId)
                ? new FEC_Case_Channel__c(Id = recordId)
                : new FEC_Case_Channel__c();

            if (mappingReq.containsKey('Name'))                  channel.Name                  = (String) mappingReq.get('Name');
            if (mappingReq.containsKey('FEC_Code__c'))           channel.FEC_Code__c           = (String) mappingReq.get('FEC_Code__c');
            if (mappingReq.containsKey('FEC_Channel_Status__c')) channel.FEC_Channel_Status__c = (Boolean) mappingReq.get('FEC_Channel_Status__c');
            if (mappingReq.containsKey('FEC_Self_Service_Flag__c')) channel.FEC_Self_Service_Flag__c = (Boolean) mappingReq.get('FEC_Self_Service_Flag__c');
            if (mappingReq.containsKey('FEC_Status__c'))         channel.FEC_Status__c         = (Boolean) mappingReq.get('FEC_Status__c');
            if (mappingReq.containsKey('FEC_Name_VN__c'))        channel.FEC_Name_VN__c        = (String) mappingReq.get('FEC_Name_VN__c');
            if (mappingReq.containsKey('FEC_Alias__c'))          channel.FEC_Alias__c          = (String) mappingReq.get('FEC_Alias__c');

            // Auto-populate FEC_Code__c on create if blank
            if (String.isBlank(recordId) && String.isBlank(channel.FEC_Code__c)) {
                channel.FEC_Code__c = channel.Name;
            }

            upsert channel;
            return channel.Id;
        } catch (DmlException dml) {
            throw new AuraHandledException('Error saving Case Channel: ' + dml.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException('Error saving Case Channel: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteCaseChannel(Id recordId) {
        try {
            if (recordId == null) {
                throw new AuraHandledException('Invalid record ID');
            }
            if (!FEC_Case_Channel__c.SObjectType.getDescribe().isDeletable()) {
                throw new AuraHandledException(System.Label.FEC_Error_No_Delete_Permission);
            }
            delete new FEC_Case_Channel__c(Id = recordId);
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting Case Channel: ' + e.getMessage());
        }
    }
}