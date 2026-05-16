// Tìm Routing Assignment active để lấy NOC ID test
List<FEC_Routing_Assignment__c> ras = [
    SELECT Id, FEC_Nature_of_Cases__c, FEC_Team__c, FEC_Queue__c
    FROM FEC_Routing_Assignment__c
    WHERE FEC_Active__c = true
      AND FEC_Team__c != null AND FEC_Queue__c != null
    LIMIT 5
];
System.debug('Active Routing Assignments: ' + ras.size());
for (FEC_Routing_Assignment__c ra : ras) {
    System.debug('  NOC: ' + ra.FEC_Nature_of_Cases__c
        + ' | Team: ' + ra.FEC_Team__c + ' | Queue: ' + ra.FEC_Queue__c);
}

// Tìm case COF/GSR đang open
List<Case> cases = [
    SELECT Id, CaseNumber, Status, OwnerId,
           FEC_Current_Case_Stage__r.Name, FEC_Current_Case_Stage__r.FEC_Code__c
    FROM Case
    WHERE Status NOT IN ('Resolved-Completed','Resolved-Cancelled','Resolved-AutoCancelled')
      AND FEC_SubCode__c != null
    ORDER BY LastModifiedDate DESC
    LIMIT 5
];
System.debug('Cases: ' + cases.size());
for (Case c : cases) {
    System.debug('  ' + c.CaseNumber + ' | ' + c.Status + ' | Stage: ' + c.FEC_Current_Case_Stage__r?.Name);
}
