// Test script: Kiểm tra luồng assignment thủ công không cập nhật FEC_Assignment_Users__c
// Case S-2660 hoặc case tương tự

String caseNumber = 'S-2660'; // Thay bằng case number của bạn

// Query case
List<Case> cases = [
    SELECT Id, CaseNumber, FEC_Assignment_Users__c, OwnerId
    FROM Case 
    WHERE CaseNumber = :caseNumber
    LIMIT 1
];

if (cases.isEmpty()) {
    System.debug('ERROR: Case not found: ' + caseNumber);
} else {
    Case c = cases[0];
    System.debug('=== CASE INFO ===');
    System.debug('Case Id: ' + c.Id);
    System.debug('Case Number: ' + c.CaseNumber);
    System.debug('FEC_Assignment_Users__c BEFORE: ' + c.FEC_Assignment_Users__c);
    System.debug('OwnerId: ' + c.OwnerId);
    
    // Query all assignments
    List<FEC_Assignment__c> assignments = [
        SELECT Id, Name, FEC_Assignment_Name__c, FEC_Assignment_Type__c, 
               FEC_Assignment_Status__c, FEC_Assignment_Owner__c, FEC_OwnerID__c
        FROM FEC_Assignment__c
        WHERE FEC_Case__c = :c.Id
        ORDER BY CreatedDate DESC
    ];
    
    System.debug('=== ASSIGNMENTS ===');
    System.debug('Total assignments: ' + assignments.size());
    for (FEC_Assignment__c a : assignments) {
        System.debug('---');
        System.debug('Assignment: ' + a.Name);
        System.debug('Type: ' + a.FEC_Assignment_Type__c);
        System.debug('Status: ' + a.FEC_Assignment_Status__c);
        System.debug('Owner: ' + a.FEC_Assignment_Owner__c);
        System.debug('OwnerID: ' + a.FEC_OwnerID__c);
    }
    
    // Test 1: Tạo General assignment mới
    System.debug('');
    System.debug('=== TEST 1: CREATE GENERAL ASSIGNMENT ===');
    FEC_Assignment__c newAssignment = new FEC_Assignment__c(
        FEC_Case__c = c.Id,
        FEC_Assignment_Name__c = 'Test Manual Assignment',
        FEC_Assignment_Type__c = 'General',
        FEC_Assignment_Status__c = 'Open'
    );
    insert newAssignment;
    System.debug('Created assignment: ' + newAssignment.Id);
    
    // Check FEC_Assignment_Users__c
    Case cAfterCreate = [SELECT Id, FEC_Assignment_Users__c FROM Case WHERE Id = :c.Id];
    System.debug('FEC_Assignment_Users__c AFTER CREATE: ' + cAfterCreate.FEC_Assignment_Users__c);
    System.debug('Expected: Should NOT change (remain same as BEFORE)');
    
    // Test 2: Update owner của General assignment
    System.debug('');
    System.debug('=== TEST 2: UPDATE GENERAL ASSIGNMENT OWNER ===');
    newAssignment.FEC_Assignment_Owner__c = UserInfo.getUserId();
    update newAssignment;
    System.debug('Updated assignment owner to: ' + UserInfo.getUserId());
    
    // Check FEC_Assignment_Users__c
    Case cAfterUpdate = [SELECT Id, FEC_Assignment_Users__c FROM Case WHERE Id = :c.Id];
    System.debug('FEC_Assignment_Users__c AFTER UPDATE: ' + cAfterUpdate.FEC_Assignment_Users__c);
    System.debug('Expected: Should NOT change (remain same as BEFORE)');
    
    // Test 3: Check trigger execution
    System.debug('');
    System.debug('=== TEST 3: VERIFY TRIGGER LOGIC ===');
    List<FEC_Assignment__c> allAssignments = [
        SELECT Id, FEC_Assignment_Type__c, FEC_Assignment_Owner__c
        FROM FEC_Assignment__c
        WHERE FEC_Case__c = :c.Id
    ];
    
    Integer routingCount = 0;
    Integer generalCount = 0;
    for (FEC_Assignment__c a : allAssignments) {
        if (a.FEC_Assignment_Type__c == 'Routing') {
            routingCount++;
        } else if (a.FEC_Assignment_Type__c == 'General') {
            generalCount++;
        }
    }
    
    System.debug('Routing assignments: ' + routingCount);
    System.debug('General assignments: ' + generalCount);
    System.debug('');
    System.debug('CONCLUSION:');
    if (cAfterUpdate.FEC_Assignment_Users__c == c.FEC_Assignment_Users__c) {
        System.debug('✓ PASS: FEC_Assignment_Users__c NOT changed by General assignment');
    } else {
        System.debug('✗ FAIL: FEC_Assignment_Users__c WAS changed');
        System.debug('  Before: ' + c.FEC_Assignment_Users__c);
        System.debug('  After: ' + cAfterUpdate.FEC_Assignment_Users__c);
    }
    
    // Cleanup
    System.debug('');
    System.debug('=== CLEANUP ===');
    delete newAssignment;
    System.debug('Deleted test assignment');
}
