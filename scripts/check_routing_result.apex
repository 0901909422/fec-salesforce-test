String caseId = '500Az00000NvWHFIA3';
List<FEC_Routing_Action_History__c> histories = [
    SELECT FEC_Updated_User_Queue__c, FEC_Updated_User_Queue_ID__c,
           FEC_Original_User_Queue__c, FEC_Stage_Name__c, FEC_Routing_Action__c
    FROM FEC_Routing_Action_History__c
    WHERE FEC_Case__c = :caseId
    ORDER BY CreatedDate DESC LIMIT 5
];
System.debug('=== Routing Action History ===');
for (FEC_Routing_Action_History__c h : histories) {
    System.debug('Action: ' + h.FEC_Routing_Action__c
        + ' | Updated Queue: ' + h.FEC_Updated_User_Queue__c
        + ' | ID: ' + h.FEC_Updated_User_Queue_ID__c);
}
