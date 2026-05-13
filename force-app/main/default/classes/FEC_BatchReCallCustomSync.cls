/*------------------------------------------------------------
Author:        Duan Nguyen
Company:       Isobar
Description:   ReSync Data 
Test Class:    FEC_CustomSyncAllInOneTest
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/03/31     Duan Nguyen          Init
------------------------------------------------------------*/ 
global class FEC_BatchReCallCustomSync  implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
      
	private Map<Id, CustomSync__c> mCus;  
    private List<FEC_integration_service_log__c> uLog = new List<FEC_integration_service_log__c>();
    public FEC_BatchReCallCustomSync(  Map<Id, CustomSync__c> mCusSync) {  
        this.mCus = mCusSync; 
    }
    
    global Database.QueryLocator start(Database.BatchableContext bc) {   
        CustomSyncSetting__c apiSetting = CustomSyncSetting__c.getOrgDefaults(); 
        return Database.getQueryLocator([
            Select id,Records__c,FEC_Custom_Sync__c,FEC_Quantity_Call__c
            from FEC_integration_service_log__c
            where FEC_Bix_Is_Success__c = false 
            and ( FEC_Quantity_Call__c < :apiSetting.LimitQuanitySync__c OR FEC_Quantity_Call__c = NULL)
            and FEC_Custom_Sync__c in :mCus.keyset() 
            and FEC_Custom_Sync__c != null
        ]);
    } 
    global void execute(Database.BatchableContext bc, List<FEC_integration_service_log__c> scope) {   /// run 1 record  
        if(scope == null || scope.isEmpty() || scope[0].Records__c == null) return;
        FEC_integration_service_log__c log = scope[0];  
        try{ 
            CustomSync__c cus = mCus.get(log.FEC_Custom_Sync__c); 
              String fieldList = '';
               List<String> recordIdObject = new List<String>();
            if (Test.isRunningTest()){
                fieldList = 'Id';
            }else{ 
              fieldList = FEC_BatchCustomSync.extractFieldsFromMapping(cus.RequestBodyMapping__c);
              String cleanRecords = log.Records__c.stripHtmlTags().unescapeHtml4();
              recordIdObject = (List<String>) JSON.deserialize(cleanRecords, List<String>.class);
            }
            String queryString = 'Select ' + fieldList +
             ' From Case ' +  
             ' where id in :recordIdObject';  
            List<sObject> records = Database.query(queryString);  
            List<FEC_integration_service_log__c> resultLogs = FEC_CustomSyncCallout.sendRequest(cus,log,records); 
            for (FEC_integration_service_log__c rLog : resultLogs) {
                if (rLog.FEC_Bix_Is_Success__c ?? false) rLog.FEC_Error_Message__c = null;
                uLog.add(rLog);
            }
            
        }Catch(Exception e){  
            log.FEC_Quantity_Call__c = (log.FEC_Quantity_Call__c ?? 0) + 1;
            log.FEC_Bix_Is_Success__c = false;
            log.FEC_Error_Message__c = 'Error FEC_BatchReCallCustomSync: Line '+e.getLinenumber() + ' - '+ e.getMessage();
            uLog.add(log);
        } 
    }
 
    global void finish(Database.BatchableContext bc) {   
        if(!uLog.isEmpty()){
            upsert uLog;
        }
    } 
}