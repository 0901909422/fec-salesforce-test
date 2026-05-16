List<Case> cases = [SELECT Id, FEC_ID_Search__c, FEC_Stage_Name__c FROM Case WHERE FEC_ID_Search__c = 'S-2323' LIMIT 1];
if (cases.isEmpty()) { System.debug('Case not found'); return; }
Case c = cases[0];
System.debug('CaseId=' + c.Id + ' StageName=[' + c.FEC_Stage_Name__c + ']');

List<FEC_Routing_Action_History__c> histories = [
    SELECT FEC_Routing_Action__c, FEC_Original_User_Queue__c, FEC_Updated_User_Queue__c,
           FEC_Stage_Name__c, FEC_User__c, FEC_Submitted_On__c, CreatedDate
    FROM FEC_Routing_Action_History__c
    WHERE FEC_Case__c = :c.Id
    ORDER BY CreatedDate ASC
];
System.debug('Total histories: ' + histories.size());
for (FEC_Routing_Action_History__c h : histories) {
    System.debug('Action=' + h.FEC_Routing_Action__c
        + ' Original=[' + h.FEC_Original_User_Queue__c + ']'
        + ' Updated=[' + h.FEC_Updated_User_Queue__c + ']'
        + ' Stage=[' + h.FEC_Stage_Name__c + ']'
        + ' User=' + h.FEC_User__c
        + ' Date=' + h.CreatedDate);
}
