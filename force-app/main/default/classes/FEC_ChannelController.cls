public with sharing class FEC_ChannelController {
    @AuraEnabled(cacheable=true)
    public static List<FEC_MDM_Channel__c> getChannels() {
        List<FEC_MDM_Channel__c> results = [
            SELECT Id, Name, FEC_Channel_ID__c, FEC_Channel_Vietnamese_name__c, FEC_Channel_Status__c
            FROM FEC_MDM_Channel__c
            ORDER BY CreatedDate DESC
            LIMIT :FEC_Constants.QUERY_LIMIT
        ];
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, results).getRecords();
        return (List<FEC_MDM_Channel__c>) safe;
    }
    
    @AuraEnabled
    public static String deleteChannel(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException(FEC_Constants.ERROR_DELETE_RECORD_PREFIX + ' Invalid Id');
        }
        try {
            FEC_MDM_Channel__c rec = new FEC_MDM_Channel__c(Id = recordId);
            Database.DeleteResult dr = Database.delete(rec, false);
            if (!dr.isSuccess()) {
                String msg = (dr.getErrors().size() > 0) ? dr.getErrors()[0].getMessage() : 'Unknown delete error';
                System.debug('FEC_ChannelController.deleteChannel delete errors: ' + dr.getErrors());
                throw new AuraHandledException(FEC_Constants.ERROR_DELETE_RECORD_PREFIX + ' ' + msg);
            }
            return FEC_Constants.OPERATION_SUCCESS;
        } catch (Exception e) {
            System.debug('FEC_ChannelController.deleteChannel error: ' + e);
            throw new AuraHandledException(FEC_Constants.ERROR_DELETE_RECORD_PREFIX + ' ' + e.getMessage());
        }
    }
}
