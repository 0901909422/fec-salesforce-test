// ========================================
// TEST FULL LUỒNG TỰ ĐỘNG (AUTO ASSIGNMENT)
// ========================================
// Script này test toàn bộ luồng assignment tự động từ Routing Assignment

System.debug('========== TEST FULL LUỒNG TỰ ĐỘNG ==========\n');

// BƯỚC 1: Tìm case có NOC và Routing Assignment
// ========================================
List<Case> cases = [
    SELECT Id, CaseNumber, OwnerId, FEC_Assignment_Users__c, 
           FEC_Actual_Nature_of_Case__c, RecordType.DeveloperName
    FROM Case 
    WHERE IsClosed = false
      AND FEC_Actual_Nature_of_Case__c != null
    LIMIT 1
];

if (cases.isEmpty()) {
    System.debug('❌ Không tìm thấy case có NOC để test');
    return;
}

Case testCase = cases[0];
System.debug('✅ Tìm thấy Case: ' + testCase.CaseNumber + ' (ID: ' + testCase.Id + ')');
System.debug('Record Type: ' + testCase.RecordType.DeveloperName);
System.debug('Owner trước test: ' + testCase.OwnerId);
System.debug('Actual NOC: ' + testCase.FEC_Actual_Nature_of_Case__c);

// BƯỚC 2: Tìm NOC và Routing Assignment
// ========================================
System.debug('\n--- Tìm NOC và Routing Assignment ---');
List<FEC_Actual_Nature_of_Case__c> actualNocs = [
    SELECT FEC_Business_Process__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c
    FROM FEC_Actual_Nature_of_Case__c 
    WHERE Id = :testCase.FEC_Actual_Nature_of_Case__c
];

if (actualNocs.isEmpty()) {
    System.debug('❌ Không tìm thấy Actual NOC');
    return;
}

FEC_Actual_Nature_of_Case__c actualNoc = actualNocs[0];
System.debug('Actual NOC: BP=' + actualNoc.FEC_Business_Process__c + 
             ', Cat=' + actualNoc.FEC_Category__c +
             ', SubCat=' + actualNoc.FEC_Sub_Category__c +
             ', SubCode=' + actualNoc.FEC_Sub_Code__c);

// Tìm matching NOC
List<FEC_Nature_of_Case__c> matchingNocs = [
    SELECT Id FROM FEC_Nature_of_Case__c
    WHERE FEC_Business_Process__c = :actualNoc.FEC_Business_Process__c
      AND FEC_Category__c = :actualNoc.FEC_Category__c
      AND FEC_Sub_Category__c = :actualNoc.FEC_Sub_Category__c
      AND FEC_Sub_Code__c = :actualNoc.FEC_Sub_Code__c
      AND FEC_Active__c = true
];

if (matchingNocs.isEmpty()) {
    System.debug('❌ Không tìm thấy matching NOC');
    return;
}

System.debug('✅ Tìm thấy ' + matchingNocs.size() + ' matching NOC(s)');
Set<Id> nocIds = new Map<Id, FEC_Nature_of_Case__c>(matchingNocs).keySet();

// Tìm Routing Assignments
List<FEC_Routing_Assignment__c> routingAssignments = [
    SELECT FEC_Team__c, FEC_Queue__c, FEC_Nature_of_Cases__c
    FROM FEC_Routing_Assignment__c
    WHERE FEC_Nature_of_Cases__c IN :nocIds
      AND FEC_Active__c = true
      AND FEC_Team__c != null
      AND FEC_Queue__c != null
];

if (routingAssignments.isEmpty()) {
    System.debug('❌ Không có Routing Assignment cho NOC này');
    System.debug('Cần tạo Routing Assignment trước khi test');
    return;
}

System.debug('✅ Tìm thấy ' + routingAssignments.size() + ' Routing Assignment(s):');
for (FEC_Routing_Assignment__c ra : routingAssignments) {
    System.debug('  - Team: ' + ra.FEC_Team__c + ', Queue: ' + ra.FEC_Queue__c);
}

// BƯỚC 3: Xóa assignments cũ
// ========================================
delete [SELECT Id FROM FEC_Assignment__c WHERE FEC_Case__c = :testCase.Id];
delete [SELECT Id FROM FEC_Case_Remarks__c WHERE FEC_Case__c = :testCase.Id AND FEC_Remark_Type__c = 'Assignment'];
delete [SELECT Id FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :testCase.Id];
System.debug('\n⚠️  Đã xóa assignments, remarks, histories cũ');

// BƯỚC 4: Gọi method createAssignmentsOnRoute
// ========================================
System.debug('\n--- Gọi FEC_CofGsrAssignmentService.createAssignmentsOnRoute ---');
try {
    User currentUser = [SELECT Id, Email, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId()];
    System.debug('Current User: ' + currentUser.Email);
    
    FEC_CofGsrAssignmentService.createAssignmentsOnRoute(
        testCase.Id,
        nocIds,
        currentUser,
        null,
        'Test Auto Stage',
        'Test remark for automatic assignment',
        false // isStage1 = false → tạo Assignment Remarks
    );
    
    System.debug('✅ Method executed successfully');
    
} catch (Exception e) {
    System.debug('❌ ERROR: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
    return;
}

// BƯỚC 5: Kiểm tra kết quả
// ========================================
System.debug('\n========== KIỂM TRA KẾT QUẢ ==========');

Case updatedCase = [
    SELECT Id, CaseNumber, OwnerId, FEC_Assignment_Users__c
    FROM Case WHERE Id = :testCase.Id
];

System.debug('\n--- 1. CASE OWNER ---');
System.debug('OwnerId: ' + updatedCase.OwnerId);
System.debug('FEC_Assignment_Users__c: ' + updatedCase.FEC_Assignment_Users__c);

if (String.isNotBlank(updatedCase.FEC_Assignment_Users__c)) {
    System.debug('✅ PASS: FEC_Assignment_Users__c đã được set');
} else {
    System.debug('❌ FAIL: FEC_Assignment_Users__c chưa được set');
}

// Kiểm tra Assignments
System.debug('\n--- 2. ASSIGNMENTS ---');
List<FEC_Assignment__c> newAssignments = [
    SELECT Id, FEC_Team__c, FEC_OwnerID__c, FEC_Manual__c, FEC_Assignment_Status__c
    FROM FEC_Assignment__c
    WHERE FEC_Case__c = :testCase.Id
];

System.debug('Số assignment: ' + newAssignments.size());
if (newAssignments.size() == routingAssignments.size()) {
    System.debug('✅ PASS: Số assignment = số routing assignment (' + routingAssignments.size() + ')');
} else {
    System.debug('❌ FAIL: Số assignment (' + newAssignments.size() + ') ≠ routing assignment (' + routingAssignments.size() + ')');
}

for (FEC_Assignment__c a : newAssignments) {
    System.debug('  Assignment: Team=' + a.FEC_Team__c + ', Queue=' + a.FEC_OwnerID__c + ', Manual=' + a.FEC_Manual__c);
    if (a.FEC_Manual__c == false) {
        System.debug('    ✅ Manual = false (auto)');
    } else {
        System.debug('    ❌ Manual should be false');
    }
}

// Kiểm tra Remarks
System.debug('\n--- 3. CASE REMARKS ---');
List<FEC_Case_Remarks__c> newRemarks = [
    SELECT Id, FEC_Case_Remarks__c, FEC_Remark_Type__c
    FROM FEC_Case_Remarks__c
    WHERE FEC_Case__c = :testCase.Id AND FEC_Remark_Type__c = 'Assignment'
];
System.debug('Số remark: ' + newRemarks.size());
if (newRemarks.size() == routingAssignments.size()) {
    System.debug('✅ PASS: Số remark = số assignment');
} else {
    System.debug('❌ FAIL: Số remark (' + newRemarks.size() + ') ≠ assignment (' + routingAssignments.size() + ')');
}

// Kiểm tra Routing History
System.debug('\n--- 4. ROUTING ACTION HISTORY ---');
List<FEC_Routing_Action_History__c> newHistories = [
    SELECT Id, FEC_Routing_Action__c, FEC_Updated_User_Queue__c
    FROM FEC_Routing_Action_History__c
    WHERE FEC_Case__c = :testCase.Id
];
System.debug('Số history: ' + newHistories.size());
if (newHistories.size() == routingAssignments.size()) {
    System.debug('✅ PASS: Số history = số assignment');
} else {
    System.debug('❌ FAIL: Số history (' + newHistories.size() + ') ≠ assignment (' + routingAssignments.size() + ')');
}

for (FEC_Routing_Action_History__c h : newHistories) {
    System.debug('  History: Action=' + h.FEC_Routing_Action__c + ', Queue=' + h.FEC_Updated_User_Queue__c);
}

// TỔNG KẾT
System.debug('\n========== TỔNG KẾT ==========');
Integer passCount = 0;
if (String.isNotBlank(updatedCase.FEC_Assignment_Users__c)) passCount++;
if (newAssignments.size() == routingAssignments.size()) passCount++;
if (newRemarks.size() == routingAssignments.size()) passCount++;
if (newHistories.size() == routingAssignments.size()) passCount++;

System.debug('Kết quả: ' + passCount + '/4 checks PASS');
if (passCount == 4) {
    System.debug('✅ ✅ ✅ LUỒNG TỰ ĐỘNG HOẠT ĐỘNG ĐÚNG! ✅ ✅ ✅');
} else {
    System.debug('❌ CÓ LỖI - Cần kiểm tra lại');
}

System.debug('\n========== KẾT THÚC TEST ==========');
