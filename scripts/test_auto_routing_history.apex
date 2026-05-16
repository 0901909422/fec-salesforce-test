// Test luồng tự động - check Routing Action History có Updated User/Queue không
// Tìm case COF/GSR có assignment tự động gần nhất
List<FEC_Routing_Action_History__c> histories = [
    SELECT Id, FEC_Case__r.CaseNumber, FEC_Routing_Action__c,
           FEC_Updated_User_Queue__c, FEC_Updated_User_Queue_ID__c,
           FEC_Original_User_Queue__c, FEC_Stage_Name__c,
           FEC_Submitted_On__c, CreatedDate
    FROM FEC_Routing_Action_History__c
    WHERE FEC_Routing_Action__c = 'Route to'
      AND CreatedDate = TODAY
    ORDER BY CreatedDate DESC
    LIMIT 10
];

System.debug('=== Routing Action History hôm nay ===');
System.debug('Total: ' + histories.size());
for (FEC_Routing_Action_History__c h : histories) {
    System.debug('Case: ' + h.FEC_Case__r?.CaseNumber
        + ' | Stage: ' + h.FEC_Stage_Name__c
        + ' | Original: ' + h.FEC_Original_User_Queue__c
        + ' | Updated: ' + h.FEC_Updated_User_Queue__c
        + ' | UpdatedID: ' + h.FEC_Updated_User_Queue_ID__c);
}
