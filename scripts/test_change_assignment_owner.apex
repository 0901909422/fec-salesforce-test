// Test: Change assignment owner và check FEC_Assignment_Users__c

// Tìm case có assignment
List<Case> cases = [
    SELECT Id, CaseNumber, FEC_Assignment_Users__c
    FROM Case
    WHERE Id IN (
        SELECT FEC_Case__c 
        FROM FEC_Assignment__c 
        WHERE FEC_Assignment_Type__c = 'Routing' 
        AND FEC_Manual__c != true
        AND FEC_Assignment_Status__c = 'Open'
    )
    LIMIT 1
];

if (cases.isEmpty()) {
    System.debug('No case with routing assignment found');
} else {
    Case c = cases[0];
    System.debug('=== CASE INFO ===');
    System.debug('Case: ' + c.CaseNumber + ' (' + c.Id + ')');
    System.debug('FEC_Assignment_Users__c BEFORE: ' + c.FEC_Assignment_Users__c);
    
    // Query assignment
    List<FEC_Assignment__c> assignments = [
        SELECT Id, Name, FEC_Assignment_Type__c, FEC_Manual__c,
               FEC_Assignment_Owner__c, FEC_OwnerID__c, FEC_Assignment_Status__c
        FROM FEC_Assignment__c
        WHERE FEC_Case__c = :c.Id
        AND FEC_Assignment_Type__c = 'Routing'
        AND FEC_Manual__c != true
        AND FEC_Assignment_Status__c = 'Open'
        LIMIT 1
    ];
    
    if (assignments.isEmpty()) {
        System.debug('No routing assignment found');
    } else {
        FEC_Assignment__c assignment = assignments[0];
        System.debug('');
        System.debug('=== ASSIGNMENT INFO ===');
        System.debug('Assignment: ' + assignment.Name);
        System.debug('Type: ' + assignment.FEC_Assignment_Type__c);
        System.debug('Manual: ' + assignment.FEC_Manual__c);
        System.debug('Owner BEFORE: ' + assignment.FEC_Assignment_Owner__c);
        System.debug('OwnerID: ' + assignment.FEC_OwnerID__c);
        
        // Change owner
        System.debug('');
        System.debug('=== CHANGE OWNER ===');
        Id oldOwner = assignment.FEC_Assignment_Owner__c;
        assignment.FEC_Assignment_Owner__c = UserInfo.getUserId();
        
        System.debug('Changing owner from ' + oldOwner + ' to ' + UserInfo.getUserId());
        
        try {
            update assignment;
            System.debug('Assignment updated successfully');
        } catch (Exception e) {
            System.debug('ERROR updating assignment: ' + e.getMessage());
        }
        
        // Check result
        System.debug('');
        System.debug('=== RESULT ===');
        
        Case cAfter = [SELECT Id, FEC_Assignment_Users__c FROM Case WHERE Id = :c.Id];
        System.debug('FEC_Assignment_Users__c AFTER: ' + cAfter.FEC_Assignment_Users__c);
        
        FEC_Assignment__c assignmentAfter = [
            SELECT Id, FEC_Assignment_Owner__c 
            FROM FEC_Assignment__c 
            WHERE Id = :assignment.Id
        ];
        System.debug('Assignment Owner AFTER: ' + assignmentAfter.FEC_Assignment_Owner__c);
        
        // Get user name
        User u = [SELECT Id, Name FROM User WHERE Id = :UserInfo.getUserId()];
        System.debug('Expected FEC_Assignment_Users__c: ' + u.Name);
        
        if (cAfter.FEC_Assignment_Users__c == u.Name) {
            System.debug('✓ SUCCESS: FEC_Assignment_Users__c updated correctly');
        } else {
            System.debug('✗ FAILED: FEC_Assignment_Users__c not updated');
            System.debug('  Expected: ' + u.Name);
            System.debug('  Actual: ' + cAfter.FEC_Assignment_Users__c);
        }
    }
}
