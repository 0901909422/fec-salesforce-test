// Trigger update for assignment A-000317 to test the fix

List<FEC_Assignment__c> assignments = [
    SELECT Id, Name, FEC_Assignment_Owner__c, FEC_Case__c
    FROM FEC_Assignment__c
    WHERE Name = 'A-000317'
    LIMIT 1
];

if (assignments.isEmpty()) {
    System.debug('Assignment not found');
} else {
    FEC_Assignment__c assignment = assignments[0];
    System.debug('Found assignment: ' + assignment.Name);
    System.debug('Current owner: ' + assignment.FEC_Assignment_Owner__c);
    
    // Trigger update by touching the owner field (set to same value)
    Id currentOwner = assignment.FEC_Assignment_Owner__c;
    assignment.FEC_Assignment_Owner__c = currentOwner;
    
    update assignment;
    
    System.debug('Updated assignment to trigger handler');
    
    // Check result
    Case c = [SELECT Id, CaseNumber, FEC_Assignment_Users__c 
              FROM Case 
              WHERE Id = :assignment.FEC_Case__c];
    
    System.debug('Case: ' + c.CaseNumber);
    System.debug('FEC_Assignment_Users__c: ' + c.FEC_Assignment_Users__c);
}
