// Check case S-0451 owner hiện tại
List<Case> cases = [
    SELECT Id, CaseNumber, OwnerId, Owner.Name, Owner.Type,
           FEC_Current_Case_Stage__r.Name, Status
    FROM Case
    WHERE CaseNumber = 'S-0451'
       OR FEC_ID_Search__c = 'S-0451'
    LIMIT 1
];
if (cases.isEmpty()) {
    System.debug('Case not found');
    return;
}
Case c = cases[0];
System.debug('Case: ' + c.CaseNumber + ' | Owner: ' + c.Owner.Name + ' | Type: ' + c.Owner.Type + ' | Status: ' + c.Status);

// Check routing action history
List<FEC_Routing_Action_History__c> histories = [
    SELECT FEC_Routing_Action__c, FEC_Original_User_Queue__c, FEC_Updated_User_Queue__c,
           FEC_User__c, CreatedDate
    FROM FEC_Routing_Action_History__c
    WHERE FEC_Case__c = :c.Id
    ORDER BY CreatedDate DESC LIMIT 5
];
for (FEC_Routing_Action_History__c h : histories) {
    System.debug(h.FEC_Routing_Action__c + ' | ' + h.FEC_Original_User_Queue__c + ' → ' + h.FEC_Updated_User_Queue__c + ' | by: ' + h.FEC_User__c + ' | ' + h.CreatedDate);
}
