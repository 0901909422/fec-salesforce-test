// Test luồng tự động với NOC có Routing Assignment
// tungnm37: Test kiểm tra FEC_Assignment_Users__c được set (không check OwnerId = null)
System.debug('========== TEST LUỒNG TỰ ĐỘNG ==========\n');

// NOC có Routing Assignment
String nocId = 'a06Az00000LG9BKIA1';

// Tìm case để test
List<Case> cases = [
    SELECT Id, CaseNumber, OwnerId, FEC_Assignment_Users__c
    FROM Case WHERE IsClosed = false LIMIT 1
];

if (cases.isEmpty()) {
    System.debug('❌ Không có case');
    return;
}

Case testCase = cases[0];
System.debug('Case: ' + testCase.CaseNumber + ' (ID: ' + testCase.Id + ')');
System.debug('Owner trước: ' + testCase.OwnerId);
System.debug('FEC_Assignment_Users__c trước: ' + testCase.FEC_Assignment_Users__c);

// Xóa assignments cũ
delete [SELECT Id FROM FEC_Assignment__c WHERE FEC_Case__c = :testCase.Id];
delete [SELECT Id FROM FEC_Case_Remarks__c WHERE FEC_Case__c = :testCase.Id AND FEC_Remark_Type__c = 'Assignment'];
delete [SELECT Id FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :testCase.Id];

// Kiểm tra Routing Assignment
List<FEC_Routing_Assignment__c> ras = [
    SELECT FEC_Team__c, FEC_Queue__c
    FROM FEC_Routing_Assignment__c
    WHERE FEC_Nature_of_Cases__c = :nocId
      AND FEC_Active__c = true
      AND FEC_Team__c != null
      AND FEC_Queue__c != null
];

System.debug('\nRouting Assignments: ' + ras.size());
for (FEC_Routing_Assignment__c ra : ras) {
    System.debug('  Team: ' + ra.FEC_Team__c + ', Queue: ' + ra.FEC_Queue__c);
}

// Gọi method
System.debug('\n--- Gọi createAssignmentsOnRoute ---');
User u = [SELECT Id, Email, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId()];
Set<Id> nocIds = new Set<Id>{nocId};

FEC_CofGsrAssignmentService.createAssignmentsOnRoute(
    testCase.Id, nocIds, u, null, 'Test Stage', 'Test remark auto'
);

// Kiểm tra kết quả
Case updated = [SELECT Id, OwnerId, FEC_Assignment_Users__c FROM Case WHERE Id = :testCase.Id];
System.debug('\n--- KẾT QUẢ ---');
System.debug('OwnerId sau: ' + updated.OwnerId);
System.debug('FEC_Assignment_Users__c sau: ' + updated.FEC_Assignment_Users__c);
System.debug('NOTE: OwnerId không thay đổi (Salesforce không cho phép set = null)');
System.debug('      FEC_Service_Case_Owner__c (formula field) sẽ ẩn giá trị khi có assignment');

if (String.isNotBlank(updated.FEC_Assignment_Users__c)) {
    System.debug('✅ PASS: FEC_Assignment_Users__c đã được set');
    System.debug('   → FEC_Service_Case_Owner__c sẽ hiển thị rỗng trên UI');
} else {
    System.debug('❌ FAIL: FEC_Assignment_Users__c = null');
}

List<FEC_Assignment__c> assignments = [
    SELECT FEC_Team__c, FEC_OwnerID__c, FEC_Manual__c
    FROM FEC_Assignment__c WHERE FEC_Case__c = :testCase.Id
];
System.debug('\nAssignments: ' + assignments.size());
for (FEC_Assignment__c a : assignments) {
    System.debug('  Team: ' + a.FEC_Team__c + ', Queue: ' + a.FEC_OwnerID__c + ', Manual: ' + a.FEC_Manual__c);
}

if (assignments.size() == ras.size()) {
    System.debug('✅ PASS: Số assignment đúng');
} else {
    System.debug('❌ FAIL: Số assignment không đúng');
}

System.debug('\n========== KẾT THÚC ==========');
