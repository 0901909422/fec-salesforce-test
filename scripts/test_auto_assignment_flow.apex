// Test full auto assignment flow: create assignments -> update owner -> verify Case field

// Step 1: Find a case with NOC
List<Case> cases = [
    SELECT Id, FEC_Nature_of_Case__c
    FROM Case
    WHERE FEC_Nature_of_Case__c != null
    ORDER BY CreatedDate DESC
    LIMIT 1
];

if (cases.isEmpty()) {
    System.debug('=== NO CASE WITH NOC FOUND ===');
} else {
    Id caseId = cases[0].Id;
    Id nocId = cases[0].FEC_Nature_of_Case__c;
    Id targetUserId = '005Az00000FTHoNIAX';
    
    System.debug('=== TEST AUTO ASSIGNMENT FLOW ===');
    System.debug('Case ID: ' + caseId);
    System.debug('NOC ID: ' + nocId);
    System.debug('Target User ID: ' + targetUserId);
    
    // Step 2: Get current user
    User currentUser = [
        SELECT Id, Email, UserRole.Name
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
    ];
    
    // Step 3: Run auto assignment
    System.debug('=== STEP 1: RUN AUTO ASSIGNMENT ===');
    Set<Id> nocIds = new Set<Id>{ nocId };
    FEC_CofGsrAssignmentService.createAssignmentsOnRoute(
        String.valueOf(caseId),
        nocIds,
        currentUser,
        null,
        'TEST_STAGE',
        'Test auto assignment flow'
    );
    
    // Step 4: Get created assignments
    List<FEC_Assignment__c> assignments = [
        SELECT Id, FEC_Case__c, FEC_Assignment_Owner__c, FEC_OwnerID__c
        FROM FEC_Assignment__c
        WHERE FEC_Case__c = :caseId
        ORDER BY CreatedDate DESC
        LIMIT 5
    ];
    
    System.debug('Created assignments: ' + assignments.size());
    for (FEC_Assignment__c a : assignments) {
        System.debug('Assignment ' + a.Id + ' - Owner: ' + a.FEC_Assignment_Owner__c + ' - OwnerID: ' + a.FEC_OwnerID__c);
    }
    
    // Step 5: Check Case field after auto assignment
    Case caseAfterAuto = [
        SELECT Id, FEC_Assignment_Users__c
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
    ];
    System.debug('Case.FEC_Assignment_Users__c after AUTO: ' + caseAfterAuto.FEC_Assignment_Users__c);
    
    // Step 6: Update assignment owner to user
    System.debug('=== STEP 2: UPDATE TO USER ===');
    if (!assignments.isEmpty()) {
        assignments[0].FEC_Assignment_Owner__c = targetUserId;
        update assignments[0];
        
        Case caseAfterUpdate = [
            SELECT Id, FEC_Assignment_Users__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        System.debug('Case.FEC_Assignment_Users__c after UPDATE: ' + caseAfterUpdate.FEC_Assignment_Users__c);
        System.debug('EXPECTED: ' + targetUserId);
        System.debug('MATCH: ' + (caseAfterUpdate.FEC_Assignment_Users__c != null && caseAfterUpdate.FEC_Assignment_Users__c.contains(targetUserId)));
        
        if (caseAfterUpdate.FEC_Assignment_Users__c != null && caseAfterUpdate.FEC_Assignment_Users__c.contains(targetUserId)) {
            System.debug('=== SUCCESS ===');
        } else {
            System.debug('=== FAILED ===');
        }
    }
}
