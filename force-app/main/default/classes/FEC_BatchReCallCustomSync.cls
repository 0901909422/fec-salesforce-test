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
    private List<FEC_API_Log__c> uLog = new List<FEC_API_Log__c>();
    public FEC_BatchReCallCustomSync(  Map<Id, CustomSync__c> mCusSync) {  
        this.mCus = mCusSync; 
    }
    
    global Database.QueryLocator start(Database.BatchableContext bc) {   
        CustomSyncSetting__c apiSetting = CustomSyncSetting__c.getOrgDefaults(); 
        return Database.getQueryLocator([
            Select id,FEC_Request_String__c ,FEC_Custom_Sync__c,FEC_Quantity_Call__c
            from FEC_API_Log__c
            where FEC_Is_Success__c = false 
            and ( FEC_Quantity_Call__c < :apiSetting.LimitQuanitySync__c OR FEC_Quantity_Call__c = NULL)
            and FEC_Custom_Sync__c in :mCus.keyset() 
        ]);
    } 
    global void execute(Database.BatchableContext bc, List<FEC_API_Log__c> scope) {   /// run 1 record  
        if(scope == null || scope.isEmpty() || scope[0].FEC_Request_String__c == null) return;
        FEC_API_Log__c log = scope[0];  
        try{ 
            CustomSync__c cus = mCus.get(log.FEC_Custom_Sync__c); 
            List<String> recordIdObject = (List<String>) JSON.deserialize(log.FEC_Request_String__c, List<String>.class);

            String queryString = 'Select ' +  cus.Fields__c  +
             ' From ' + cus.TargetObject__c + 
             ' where id in :recordIdObject';  
            List<sObject> records = Database.query(queryString);  
            log = FEC_CustomSyncCallout.sendRequest(cus,log,records); 
            if(log.FEC_Is_Success__c) log.FEC_Error_Message__c = null; 
            
        }Catch(Exception e){  
            log.FEC_Is_Success__c = false;
            log.FEC_Error_Message__c = 'Error FEC_BatchReCallCustomSync: Line '+e.getLinenumber() + ' - '+ e.getMessage();
        } 
        uLog.add(log);
    }
 
    global void finish(Database.BatchableContext bc) {   
        if(!uLog.isEmpty()){
            update uLog;
        }
    } 
}