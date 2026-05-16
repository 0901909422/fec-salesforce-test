// Test luồng tự động COF/GSR - kiểm tra Service Case Owner ẩn sau khi submit
System.debug('===== TEST AUTO COF/GSR - SERVICE CASE OWNER =====');

// Tìm Case COF chưa submit
List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Stage_Name__c, FEC_Is_Submited__c,
           OwnerId, Owner.Name, Owner.Type,
           FEC_Service_Case_Owner__c, FEC_Assignment_Users__c,
           FEC_Actual_Nature_of_Case__c,
           FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c
    FROM Case
    WHERE FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c LIKE 'COF%'
      AND IsClosed = false
    LIMIT 1
];
if (cases.isEmpty()) { System.debug('Không tìm thấy Case COF chưa submit'); return; }
Case c = cases[0];
System.debug('Case=' + c.FEC_ID_Search__c + ' BP=' + c.FEC_Actual_Nature_of_Case__r?.FEC_Business_Process__r?.FEC_Code__c);
System.debug('BEFORE: Owner=' + c.Owner?.Name + ' OwnerType=' + c.Owner?.Type);
System.debug('BEFORE: AssignUsers=[' + c.FEC_Assignment_Users__c + ']');
System.debug('BEFORE: ServiceCaseOwner=[' + c.FEC_Service_Case_Owner__c + ']');

// Xóa data cũ
delete [SELECT Id FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id];
delete [SELECT Id FROM FEC_Case_Remarks__c WHERE FEC_Case__c = :c.Id];
delete [SELECT Id FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :c.Id];
Database.update(new Case(Id = c.Id, FEC_Is_Submited__c = false, FEC_Assignment_Users__c = null), false);

// Tìm NOC IDs
Set<Id> nocIds = FEC_CofGsrAssignmentService.resolveToNocIds(c.FEC_Actual_Nature_of_Case__c);
System.debug('NOC IDs: ' + nocIds.size());
if (nocIds.isEmpty()) { System.debug('Không tìm thấy NOC IDs'); return; }

// Tìm routing assignments
List<FEC_Routing_Assignment__c> routingAssignments = [
    SELECT FEC_Team__c, FEC_Queue__c FROM FEC_Routing_Assignment__c
    WHERE FEC_Nature_of_Cases__c IN :nocIds AND FEC_Active__c = true LIMIT 3
];
System.debug('Routing Assignments: ' + routingAssignments.size());
if (routingAssignments.isEmpty()) { System.debug('Không có Routing Assignment'); return; }
for (FEC_Routing_Assignment__c ra : routingAssignments) {
    System.debug('  Team=' + ra.FEC_Team__c + ' Queue=' + ra.FEC_Queue__c);
}

// Simulate auto routing
User currentUser = [SELECT Id, Email, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId()];
String stageName = c.FEC_Stage_Name__c != null ? c.FEC_Stage_Name__c : 'COF - Test - Stage 1';

FEC_CofGsrAssignmentService.createAssignmentsOnRoute(
    c.Id, nocIds, currentUser, null, stageName, 'Test remark auto'
);

// Check kết quả
Case updated = [
    SELECT Id, FEC_Assignment_Users__c, FEC_Service_Case_Owner__c, OwnerId, Owner.Name, Owner.Type
    FROM Case WHERE Id = :c.Id
];
System.debug('AFTER: Owner=' + updated.Owner?.Name + ' OwnerType=' + updated.Owner?.Type);
System.debug('AFTER: AssignUsers=[' + updated.FEC_Assignment_Users__c + ']');
System.debug('AFTER: ServiceCaseOwner=[' + updated.FEC_Service_Case_Owner__c + ']');

// Kiểm tra
Boolean assignUsersSet = String.isNotBlank(updated.FEC_Assignment_Users__c);
Boolean serviceOwnerHidden = String.isBlank(updated.FEC_Service_Case_Owner__c);

System.debug('AssignmentUsers set: ' + assignUsersSet + ' (expected: true)');
System.debug('ServiceCaseOwner hidden: ' + serviceOwnerHidden + ' (expected: true for auto COF/GSR)');

if (assignUsersSet && serviceOwnerHidden) {
    System.debug('✅ PASS - Auto routing ẩn Service Case Owner đúng');
} else if (assignUsersSet && !serviceOwnerHidden) {
    System.debug('❌ FAIL - AssignmentUsers có data nhưng ServiceCaseOwner vẫn hiện: [' + updated.FEC_Service_Case_Owner__c + ']');
    System.debug('  → Formula cần check: Owner type=' + updated.Owner?.Type + ' AssignUsers=' + updated.FEC_Assignment_Users__c);
} else {
    System.debug('❌ FAIL - AssignmentUsers không được set');
}
