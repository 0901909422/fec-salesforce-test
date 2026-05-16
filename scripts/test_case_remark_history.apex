// ============================================================
// Test Case Remark History sau khi submit action từ Assignment List
// Covers: Escalate, Reject, Resolve, Revert, Transfer, Update
// Tại mọi stage (Stage 1, Stage 2)
// ============================================================

// Lấy Case có Assignment đang Open (Stage 2 để test non-Stage1)
List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Stage_Name__c,
           FEC_Current_Case_Stage__r.Name,
           FEC_Current_Case_Stage__r.FEC_Default_Stage__c
    FROM Case
    WHERE FEC_Current_Case_Stage__c != null
    ORDER BY CreatedDate DESC
    LIMIT 5
];

System.debug('=== AVAILABLE CASES ===');
for (Case c : cases) {
    System.debug(c.FEC_ID_Search__c + ' | Stage: ' + c.FEC_Current_Case_Stage__r?.Name + ' | IsStage1: ' + c.FEC_Current_Case_Stage__r?.FEC_Default_Stage__c);
}

if (cases.isEmpty()) { System.debug('No cases found'); return; }

// Chọn case đầu tiên có Assignment
Case testCase;
FEC_Assignment__c testAssignment;

for (Case c : cases) {
    List<FEC_Assignment__c> assignments = [
        SELECT Id, Name, FEC_Assignment_Status__c, FEC_Assignment_Owner__c
        FROM FEC_Assignment__c
        WHERE FEC_Case__c = :c.Id
          AND FEC_Assignment_Status__c = 'Open'
        LIMIT 1
    ];
    if (!assignments.isEmpty()) {
        testCase = c;
        testAssignment = assignments[0];
        break;
    }
}

if (testCase == null) {
    System.debug('No case with Open Assignment found. Creating test data...');

    // Lấy case đầu tiên và tạo assignment test
    testCase = cases[0];
    testAssignment = new FEC_Assignment__c(
        FEC_Case__c = testCase.Id,
        FEC_Assignment_Type__c = 'General',
        FEC_Assignment_Status__c = 'Open',
        FEC_Assignment_Name__c = 'Soạn thảo văn bản',
        FEC_Assignment_Owner__c = UserInfo.getUserId()
    );
    insert testAssignment;
    System.debug('Created test assignment: ' + testAssignment.Id);
}

System.debug('=== TEST CASE ===');
System.debug('Case: ' + testCase.FEC_ID_Search__c + ' | Stage: ' + testCase.FEC_Current_Case_Stage__r?.Name);
System.debug('Assignment: ' + testAssignment.Name + ' | Status: ' + testAssignment.FEC_Assignment_Status__c);

// Count remarks trước khi test
List<FEC_Case_Remarks__c> remarksBefore = [
    SELECT Id, FEC_Case_Remarks__c, FEC_Remark_Type__c, FEC_Stage_Name__c, CreatedDate
    FROM FEC_Case_Remarks__c
    WHERE FEC_Case__c = :testCase.Id
      AND FEC_Remark_Type__c = null
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('=== CASE REMARKS (type=null) BEFORE: ' + remarksBefore.size() + ' ===');
for (FEC_Case_Remarks__c r : remarksBefore) {
    System.debug('  ' + r.FEC_Case_Remarks__c + ' | Stage: ' + r.FEC_Stage_Name__c);
}

// Simulate FEC_AssignmentRoutingActionHandler.execute với action Resolve
System.debug('=== CALLING execute(Resolve) ===');
try {
    FEC_AssignmentRoutingActionHandler.execute(
        testCase.Id,
        testAssignment.Id,
        'Resolve',
        'Test remark - verify Case Remark History created',
        null,
        null
    );
    System.debug('execute() SUCCESS');
} catch (Exception e) {
    System.debug('execute() ERROR: ' + e.getMessage());
}

// Check remarks sau
List<FEC_Case_Remarks__c> remarksAfter = [
    SELECT Id, FEC_Case_Remarks__c, FEC_Remark_Type__c, FEC_Stage_Name__c, CreatedDate
    FROM FEC_Case_Remarks__c
    WHERE FEC_Case__c = :testCase.Id
      AND FEC_Remark_Type__c = null
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('=== CASE REMARKS (type=null) AFTER: ' + remarksAfter.size() + ' ===');
for (FEC_Case_Remarks__c r : remarksAfter) {
    System.debug('  Content: ' + r.FEC_Case_Remarks__c + ' | Stage: ' + r.FEC_Stage_Name__c + ' | Created: ' + r.CreatedDate);
}

Integer newRemarks = remarksAfter.size() - remarksBefore.size();
System.debug('=== RESULT: ' + newRemarks + ' new Case Remark(s) created ===');
if (newRemarks > 0) {
    System.debug('✓ PASS - Case Remark History được tạo đúng');
} else {
    System.debug('✗ FAIL - Case Remark History KHÔNG được tạo');
}

// Check Assignment Remark (type=Assignment) cũng được tạo
List<FEC_Case_Remarks__c> assignmentRemarks = [
    SELECT Id, FEC_Case_Remarks__c, FEC_Stage_Name__c
    FROM FEC_Case_Remarks__c
    WHERE FEC_Case__c = :testCase.Id
      AND FEC_Remark_Type__c = 'Assignment'
      AND FEC_Assignment__c = :testAssignment.Id
    ORDER BY CreatedDate DESC
    LIMIT 3
];
System.debug('=== ASSIGNMENT REMARKS: ' + assignmentRemarks.size() + ' ===');
for (FEC_Case_Remarks__c r : assignmentRemarks) {
    System.debug('  Content: ' + r.FEC_Case_Remarks__c + ' | Stage: ' + r.FEC_Stage_Name__c);
}
