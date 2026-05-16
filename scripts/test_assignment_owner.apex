// Test script: verify FEC_Assignment_Users__c sync when FEC_Assignment_Owner__c changes

// Step 1: Find a case with assignments
List<FEC_Assignment__c> existingAssignments = [
    SELECT Id, FEC_Case__c, FEC_Assignment_Owner__c, FEC_OwnerID__c
    FROM FEC_Assignment__c
    WHERE FEC_Case__c != null
    ORDER BY CreatedDate DESC
    LIMIT 1
];

if (existingAssignments.isEmpty()) {
    System.debug('=== NO ASSIGNMENT FOUND ===');
    System.debug('Please create an assignment first via auto/manual flow');
} else {
    Id caseId = existingAssignments[0].FEC_Case__c;
    Id targetUserId = '005Az00000FTHoNIAX';
    
    System.debug('=== TEST START ===');
    System.debug('Case ID: ' + caseId);
    System.debug('Target User ID: ' + targetUserId);
    
    // Step 2: Get all assignments for this case
    List<FEC_Assignment__c> assignments = [
        SELECT Id, FEC_Case__c, FEC_Assignment_Owner__c, FEC_OwnerID__c
        FROM FEC_Assignment__c
        WHERE FEC_Case__c = :caseId
    ];
    
    System.debug('=== BEFORE UPDATE ===');
    System.debug('Total assignments: ' + assignments.size());
    for (FEC_Assignment__c a : assignments) {
        System.debug('Assignment ' + a.Id + ' - Owner: ' + a.FEC_Assignment_Owner__c + ' - OwnerID: ' + a.FEC_OwnerID__c);
    }
    
    // Step 3: Get Case before update
    Case caseBefore = [
        SELECT Id, FEC_Assignment_Users__c
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
    ];
    System.debug('Case.FEC_Assignment_Users__c BEFORE: ' + caseBefore.FEC_Assignment_Users__c);
    
    // Step 4: Update first assignment owner to target user
    FEC_Assignment__c assignmentToUpdate = assignments[0];
    assignmentToUpdate.FEC_Assignment_Owner__c = targetUserId;
    update assignmentToUpdate;
    
    System.debug('=== AFTER UPDATE ===');
    System.debug('Updated Assignment ' + assignmentToUpdate.Id + ' to User: ' + targetUserId);
    
    // Step 5: Verify Case field
    Case caseAfter = [
        SELECT Id, FEC_Assignment_Users__c
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
    ];
    
    System.debug('=== RESULT ===');
    System.debug('Case.FEC_Assignment_Users__c AFTER: ' + caseAfter.FEC_Assignment_Users__c);
    System.debug('EXPECTED: ' + targetUserId);
    System.debug('MATCH: ' + (caseAfter.FEC_Assignment_Users__c != null && caseAfter.FEC_Assignment_Users__c.contains(targetUserId)));
    
    if (caseAfter.FEC_Assignment_Users__c == null || !caseAfter.FEC_Assignment_Users__c.contains(targetUserId)) {
        System.debug('=== FAILED: User ID not found in FEC_Assignment_Users__c ===');
    } else {
        System.debug('=== SUCCESS: User ID found in FEC_Assignment_Users__c ===');
    }
}
