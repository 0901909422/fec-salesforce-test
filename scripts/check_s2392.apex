List<Case> cases = [SELECT Id, FEC_ID_Search__c, FEC_Assignment_Users__c, OwnerId, Owner.Name
    FROM Case WHERE FEC_ID_Search__c = 'S-2392' LIMIT 1];
if (cases.isEmpty()) { System.debug('Not found'); return; }
Case c = cases[0];
System.debug('AssignmentUsers=[' + c.FEC_Assignment_Users__c + '] Owner=' + c.Owner?.Name);

List<FEC_Assignment__c> assignments = [
    SELECT Id, Name, FEC_OwnerID__c, FEC_Team__c, FEC_Assignment_Routing_Action__c
    FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id ORDER BY CreatedDate DESC LIMIT 5
];
System.debug('Assignments: ' + assignments.size());
for (FEC_Assignment__c a : assignments) {
    System.debug('  Name=' + a.Name + ' OwnerID=[' + a.FEC_OwnerID__c + '] Stage=' + a.FEC_Assignment_Routing_Action__c);
    List<Group> g = [SELECT Id FROM Group WHERE Name = :a.FEC_OwnerID__c AND Type = 'Queue' LIMIT 1];
    System.debug('  QueueId=' + (g.isEmpty() ? 'NOT FOUND' : String.valueOf(g[0].Id)));
}

// Check if AssignmentUsers matches any queue
if (String.isNotBlank(c.FEC_Assignment_Users__c)) {
    for (String uid : c.FEC_Assignment_Users__c.split(',')) {
        String trimmed = uid.trim();
        try {
            Id recordId = trimmed;
            System.debug('  AssignmentUser ID type: ' + recordId.getSObjectType().getDescribe().getName());
        } catch (Exception e) {
            System.debug('  Invalid ID: ' + trimmed);
        }
    }
}
