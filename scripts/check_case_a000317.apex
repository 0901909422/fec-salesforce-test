// Check case của assignment A-000317

List<FEC_Assignment__c> assignments = [
    SELECT Id, Name, FEC_Case__c, FEC_Assignment_Type__c, FEC_Manual__c,
           FEC_Assignment_Owner__c, FEC_Assignment_Owner_Text__c, FEC_OwnerID__c,
           FEC_Assignment_Status__c
    FROM FEC_Assignment__c
    WHERE Name = 'A-000317'
    LIMIT 1
];

if (assignments.isEmpty()) {
    System.debug('Assignment not found');
} else {
    FEC_Assignment__c assignment = assignments[0];
    System.debug('=== ASSIGNMENT INFO ===');
    System.debug('Assignment: ' + assignment.Name);
    System.debug('Case: ' + assignment.FEC_Case__c);
    System.debug('Type: ' + assignment.FEC_Assignment_Type__c);
    System.debug('Manual: ' + assignment.FEC_Manual__c);
    System.debug('Status: ' + assignment.FEC_Assignment_Status__c);
    System.debug('Owner: ' + assignment.FEC_Assignment_Owner__c);
    System.debug('Owner Text: ' + assignment.FEC_Assignment_Owner_Text__c);
    System.debug('OwnerID: ' + assignment.FEC_OwnerID__c);
    
    // Query case
    Case c = [SELECT Id, CaseNumber, FEC_Assignment_Users__c FROM Case WHERE Id = :assignment.FEC_Case__c];
    System.debug('');
    System.debug('=== CASE INFO ===');
    System.debug('Case: ' + c.CaseNumber);
    System.debug('FEC_Assignment_Users__c: ' + c.FEC_Assignment_Users__c);
    
    // Query all assignments
    System.debug('');
    System.debug('=== ALL ASSIGNMENTS ===');
    List<FEC_Assignment__c> allAssignments = [
        SELECT Id, Name, FEC_Assignment_Type__c, FEC_Manual__c,
               FEC_Assignment_Owner_Text__c, FEC_Assignment_Status__c
        FROM FEC_Assignment__c
        WHERE FEC_Case__c = :assignment.FEC_Case__c
        ORDER BY CreatedDate
    ];
    
    System.debug('Total: ' + allAssignments.size());
    for (FEC_Assignment__c a : allAssignments) {
        System.debug('---');
        System.debug('Name: ' + a.Name);
        System.debug('Type: ' + a.FEC_Assignment_Type__c);
        System.debug('Manual: ' + a.FEC_Manual__c);
        System.debug('Status: ' + a.FEC_Assignment_Status__c);
        System.debug('Owner Text: ' + a.FEC_Assignment_Owner_Text__c);
    }
    
    // Expected value
    System.debug('');
    System.debug('=== EXPECTED ===');
    Set<String> expectedSet = new Set<String>();
    for (FEC_Assignment__c a : allAssignments) {
        // tungnm37: bao gồm tất cả Routing assignment (cả auto và manual)
        if (a.FEC_Assignment_Type__c == 'Routing'
            && String.isNotBlank(a.FEC_Assignment_Owner_Text__c)) {
            expectedSet.add(a.FEC_Assignment_Owner_Text__c);
        }
    }
    String expected = String.join(new List<String>(expectedSet), ';');
    System.debug('Expected FEC_Assignment_Users__c: ' + expected);
    System.debug('Actual FEC_Assignment_Users__c: ' + c.FEC_Assignment_Users__c);
    System.debug('Match: ' + (expected == c.FEC_Assignment_Users__c));
}
