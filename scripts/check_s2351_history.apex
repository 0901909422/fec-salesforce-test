List<Case> cases = [SELECT Id, FEC_ID_Search__c, FEC_Stage_Name__c, OwnerId, Owner.Name, Owner.Type FROM Case WHERE FEC_ID_Search__c = 'S-2351' LIMIT 1];
if (cases.isEmpty()) { System.debug('Case not found'); return; }
Case c = cases[0];
System.debug('CaseId=' + c.Id + ' StageName=[' + c.FEC_Stage_Name__c + '] OwnerId=' + c.OwnerId + ' OwnerName=' + c.Owner?.Name + ' OwnerType=' + c.Owner?.Type);

List<FEC_Routing_Action_History__c> histories = [
    SELECT FEC_Routing_Action__c, FEC_Original_User_Queue__c, FEC_Original_User_Queue_ID__c,
           FEC_Updated_User_Queue__c, FEC_Stage_Name__c, FEC_User__c, FEC_Perform_User__c, CreatedDate
    FROM FEC_Routing_Action_History__c
    WHERE FEC_Case__c = :c.Id
    ORDER BY CreatedDate ASC
];
for (FEC_Routing_Action_History__c h : histories) {
    System.debug('Original=[' + h.FEC_Original_User_Queue__c + '] OriginalId=[' + h.FEC_Original_User_Queue_ID__c + ']'
        + ' Updated=[' + h.FEC_Updated_User_Queue__c + ']'
        + ' Stage=[' + h.FEC_Stage_Name__c + ']'
        + ' User=' + h.FEC_User__c + ' PerformUser=' + h.FEC_Perform_User__c);
}
