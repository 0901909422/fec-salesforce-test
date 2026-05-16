// Check FEC_Assignment_Users__c của case mới nhất
List<Case> cases = [SELECT Id, FEC_ID_Search__c, FEC_Assignment_Users__c, OwnerId, Owner.Name
    FROM Case ORDER BY LastModifiedDate DESC LIMIT 3];
for (Case c : cases) {
    System.debug('Case=' + c.FEC_ID_Search__c + ' AssignmentUsers=[' + c.FEC_Assignment_Users__c + '] Owner=' + c.Owner?.Name);
    // Check assignments
    List<FEC_Assignment__c> assignments = [
        SELECT Id, Name, FEC_OwnerID__c, FEC_Team__c, FEC_Assignment_Routing_Action__c
        FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id ORDER BY CreatedDate DESC LIMIT 5
    ];
    for (FEC_Assignment__c a : assignments) {
        System.debug('  Assignment=' + a.Name + ' OwnerID=[' + a.FEC_OwnerID__c + '] Team=' + a.FEC_Team__c + ' Stage=' + a.FEC_Assignment_Routing_Action__c);
        // Check if OwnerID is a queue name
        List<Group> g = [SELECT Id, Name FROM Group WHERE Name = :a.FEC_OwnerID__c AND Type = 'Queue' LIMIT 1];
        System.debug('  Queue lookup: ' + (g.isEmpty() ? 'NOT FOUND' : g[0].Id + ' = ' + g[0].Name));
    }
}
