// tungnm37: check Routing Action History của case S-2712
String caseNumber = '00005987';

List<Case> cases = [SELECT Id, CaseNumber, OwnerId, Owner.Name FROM Case WHERE CaseNumber = :caseNumber LIMIT 1];
if (cases.isEmpty()) { System.debug('Case not found'); return; }
System.debug('Case: ' + cases[0].CaseNumber + ' | Owner: ' + cases[0].Owner.Name);

List<FEC_Routing_Action_History__c> histories = [
    SELECT Id, FEC_Routing_Action__c, FEC_Original_User_Queue__c, FEC_Updated_User_Queue__c,
           FEC_Stage_Name__c, FEC_User__c, FEC_Assignment__c, CreatedDate
    FROM FEC_Routing_Action_History__c
    WHERE FEC_Case__c = :cases[0].Id
    ORDER BY CreatedDate ASC
];
System.debug('Total histories: ' + histories.size());
for (Integer i = 0; i < histories.size(); i++) {
    FEC_Routing_Action_History__c h = histories[i];
    System.debug('Row ' + (i+1) + ': Action=' + h.FEC_Routing_Action__c
        + ' | Original=' + h.FEC_Original_User_Queue__c
        + ' | Updated=' + h.FEC_Updated_User_Queue__c
        + ' | Stage=' + h.FEC_Stage_Name__c
        + ' | User=' + h.FEC_User__c
        + ' | Assignment=' + h.FEC_Assignment__c);
}

// Check manual/auto cho các assignment
Set<Id> assignmentIds = new Set<Id>();
for (FEC_Routing_Action_History__c h : histories) {
    if (h.FEC_Assignment__c != null) assignmentIds.add(h.FEC_Assignment__c);
}
if (!assignmentIds.isEmpty()) {
    for (FEC_Assignment__c a : [
        SELECT Id, FEC_Manual__c, FEC_Assignment_Type__c, FEC_OwnerID__c, FEC_Assignment_Routing_Action__c
        FROM FEC_Assignment__c WHERE Id IN :assignmentIds
    ]) {
        System.debug('Assignment=' + a.Id + ' | Manual=' + a.FEC_Manual__c 
            + ' | Type=' + a.FEC_Assignment_Type__c 
            + ' | Owner=' + a.FEC_OwnerID__c
            + ' | Stage=' + a.FEC_Assignment_Routing_Action__c);
    }
}
