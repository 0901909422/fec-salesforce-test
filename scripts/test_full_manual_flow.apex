// ========================================
// TEST FULL LUỒNG THỦ CÔNG (MANUAL ASSIGNMENT)
// ========================================
// Script này test toàn bộ luồng assignment thủ công và kiểm tra:
// 1. Tạo assignments từ manual items JSON
// 2. Case.OwnerId phải = null sau khi có assignment
// 3. Case.FEC_Assignment_Users__c phải được set
// 4. Tạo Case Remarks
// 5. Tạo Routing Action History

System.debug('========== TEST FULL LUỒNG THỦ CÔNG ==========\n');

// BƯỚC 1: Tìm hoặc tạo test case
// ========================================
List<Case> cases = [
    SELECT Id, CaseNumber, OwnerId, FEC_Assignment_Users__c, 
           FEC_Actual_Nature_of_Case__c, RecordType.DeveloperName
    FROM Case 
    WHERE IsClosed = false
    LIMIT 1
];

if (cases.isEmpty()) {
    System.debug('❌ Không tìm thấy case để test');
    System.debug('Vui lòng tạo case trước hoặc thay đổi query');
    return;
}

Case testCase = cases[0];
System.debug('✅ Tìm thấy Case: ' + testCase.CaseNumber + ' (ID: ' + testCase.Id + ')');
System.debug('Record Type: ' + testCase.RecordType.DeveloperName);
System.debug('Owner trước test: ' + testCase.OwnerId);
System.debug('FEC_Assignment_Users__c trước: ' + testCase.FEC_Assignment_Users__c);

// BƯỚC 2: Xóa assignments cũ để test clean
// ========================================
List<FEC_Assignment__c> oldAssignments = [
    SELECT Id FROM FEC_Assignment__c WHERE FEC_Case__c = :testCase.Id
];
if (!oldAssignments.isEmpty()) {
    System.debug('\n⚠️  Xóa ' + oldAssignments.size() + ' assignment(s) cũ để test clean');
    delete oldAssignments;
}

// Xóa remarks cũ
List<FEC_Case_Remarks__c> oldRemarks = [
    SELECT Id FROM FEC_Case_Remarks__c 
    WHERE FEC_Case__c = :testCase.Id 
      AND FEC_Remark_Type__c = 'Assignment'
];
if (!oldRemarks.isEmpty()) {
    System.debug('⚠️  Xóa ' + oldRemarks.size() + ' remark(s) cũ');
    delete oldRemarks;
}

// Xóa routing history cũ
List<FEC_Routing_Action_History__c> oldHistories = [
    SELECT Id FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :testCase.Id
];
if (!oldHistories.isEmpty()) {
    System.debug('⚠️  Xóa ' + oldHistories.size() + ' routing history cũ');
    delete oldHistories;
}

// BƯỚC 3: Tìm queues để test
// ========================================
System.debug('\n--- Tìm Queues để test ---');
List<Group> queues = [
    SELECT Id, Name, DeveloperName 
    FROM Group 
    WHERE Type = 'Queue' 
      AND (DeveloperName LIKE 'FEC_%')
    LIMIT 2
];

if (queues.isEmpty()) {
    System.debug('❌ Không tìm thấy queue để test');
    System.debug('Cần có ít nhất 1 queue với prefix FEC_');
    return;
}

System.debug('✅ Tìm thấy ' + queues.size() + ' queue(s):');
for (Group q : queues) {
    System.debug('  - ' + q.Name + ' (DeveloperName: ' + q.DeveloperName + ', ID: ' + q.Id + ')');
}

// BƯỚC 4: Tạo manual items JSON
// ========================================
System.debug('\n--- Tạo Manual Items JSON ---');
List<String> jsonItems = new List<String>();
Integer counter = 1;
for (Group q : queues) {
    String item = '{"teamName":"Test Team ' + counter + '",' +
                  '"queueName":"' + q.DeveloperName + '",' +
                  '"remark":"Manual test remark ' + counter + ' - Queue: ' + q.Name + '"}';
    jsonItems.add(item);
    System.debug('Item ' + counter + ': Team=Test Team ' + counter + ', Queue=' + q.DeveloperName);
    counter++;
}
String manualItemsJson = '[' + String.join(jsonItems, ',') + ']';
System.debug('Manual Items JSON: ' + manualItemsJson);

// BƯỚC 5: Gọi method createAssignmentsFromManualItems
// ========================================
System.debug('\n--- Gọi FEC_CofGsrAssignmentService.createAssignmentsFromManualItems ---');
try {
    User currentUser = [SELECT Id, Email, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId()];
    System.debug('Current User: ' + currentUser.Email);
    System.debug('User Role: ' + currentUser.UserRole?.Name);
    
    FEC_CofGsrAssignmentService.createAssignmentsFromManualItems(
        testCase.Id,
        manualItemsJson,
        currentUser,
        'Test Manual Stage'
    );
    
    System.debug('✅ Method executed successfully');
    
} catch (Exception e) {
    System.debug('❌ ERROR: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
    return;
}

// BƯỚC 6: Kiểm tra kết quả - Case Owner
// ========================================
System.debug('\n========== KIỂM TRA KẾT QUẢ ==========');
Case updatedCase = [
    SELECT Id, CaseNumber, OwnerId, FEC_Assignment_Users__c
    FROM Case
    WHERE Id = :testCase.Id
];

System.debug('\n--- 1. CASE OWNER ---');
System.debug('OwnerId sau khi tạo assignment: ' + updatedCase.OwnerId);
System.debug('FEC_Assignment_Users__c: ' + updatedCase.FEC_Assignment_Users__c);

// tungnm37: OwnerId KHÔNG được set = null vì Salesforce không cho phép
// Thay vào đó, FEC_Assignment_Users__c được set và formula field FEC_Service_Case_Owner__c sẽ ẩn giá trị
System.debug('NOTE: OwnerId không thay đổi (Salesforce không cho phép set = null)');
System.debug('      FEC_Service_Case_Owner__c (formula field) sẽ ẩn giá trị khi có assignment');

if (String.isNotBlank(updatedCase.FEC_Assignment_Users__c)) {
    System.debug('✅ PASS: FEC_Assignment_Users__c đã được set');
    System.debug('   Giá trị: ' + updatedCase.FEC_Assignment_Users__c);
    System.debug('   → FEC_Service_Case_Owner__c sẽ hiển thị rỗng trên UI');
} else {
    System.debug('❌ FAIL: FEC_Assignment_Users__c chưa được set');
}

// BƯỚC 7: Kiểm tra Assignments được tạo
// ========================================
System.debug('\n--- 2. ASSIGNMENTS ---');
List<FEC_Assignment__c> newAssignments = [
    SELECT Id, FEC_Team__c, FEC_OwnerID__c, FEC_Assignment_Owner__c, 
           FEC_Assignment_Status__c, FEC_Manual__c, FEC_Assignment_Remark__c,
           FEC_Assignment_Type__c, FEC_Assignment_Name__c
    FROM FEC_Assignment__c
    WHERE FEC_Case__c = :testCase.Id
    ORDER BY CreatedDate DESC
];

System.debug('Số assignment được tạo: ' + newAssignments.size());
if (newAssignments.size() == queues.size()) {
    System.debug('✅ PASS: Số assignment = số queue (' + queues.size() + ')');
} else {
    System.debug('❌ FAIL: Số assignment (' + newAssignments.size() + ') ≠ số queue (' + queues.size() + ')');
}

for (FEC_Assignment__c a : newAssignments) {
    System.debug('\nAssignment: ' + a.Id);
    System.debug('  Team: ' + a.FEC_Team__c);
    System.debug('  OwnerID (Queue Name): ' + a.FEC_OwnerID__c);
    System.debug('  Assignment Owner: ' + a.FEC_Assignment_Owner__c);
    System.debug('  Status: ' + a.FEC_Assignment_Status__c);
    System.debug('  Manual: ' + a.FEC_Manual__c);
    System.debug('  Type: ' + a.FEC_Assignment_Type__c);
    System.debug('  Name: ' + a.FEC_Assignment_Name__c);
    System.debug('  Remark: ' + a.FEC_Assignment_Remark__c);
    
    // Validate
    if (a.FEC_Manual__c == true) {
        System.debug('  ✅ Manual = true');
    } else {
        System.debug('  ❌ Manual should be true');
    }
    
    if (a.FEC_Assignment_Status__c == 'Open') {
        System.debug('  ✅ Status = Open');
    } else {
        System.debug('  ❌ Status should be Open');
    }
}

// BƯỚC 8: Kiểm tra Case Remarks
// ========================================
System.debug('\n--- 3. CASE REMARKS ---');
List<FEC_Case_Remarks__c> newRemarks = [
    SELECT Id, FEC_Case_Remarks__c, FEC_User__c, FEC_Remark_Type__c, 
           FEC_Assignment__c, FEC_Stage_Name__c
    FROM FEC_Case_Remarks__c
    WHERE FEC_Case__c = :testCase.Id
      AND FEC_Remark_Type__c = 'Assignment'
    ORDER BY CreatedDate DESC
];

System.debug('Số remark được tạo: ' + newRemarks.size());
if (newRemarks.size() == queues.size()) {
    System.debug('✅ PASS: Số remark = số assignment (' + queues.size() + ')');
} else {
    System.debug('❌ FAIL: Số remark (' + newRemarks.size() + ') ≠ số assignment (' + queues.size() + ')');
}

for (FEC_Case_Remarks__c r : newRemarks) {
    System.debug('\nRemark: ' + r.Id);
    System.debug('  Content: ' + r.FEC_Case_Remarks__c);
    System.debug('  User: ' + r.FEC_User__c);
    System.debug('  Type: ' + r.FEC_Remark_Type__c);
    System.debug('  Assignment: ' + r.FEC_Assignment__c);
    System.debug('  Stage: ' + r.FEC_Stage_Name__c);
}

// BƯỚC 9: Kiểm tra Routing Action History
// ========================================
System.debug('\n--- 4. ROUTING ACTION HISTORY ---');
List<FEC_Routing_Action_History__c> newHistories = [
    SELECT Id, FEC_Routing_Action__c, FEC_Original_User_Queue__c, 
           FEC_Original_User_Queue_ID__c, FEC_Updated_User_Queue__c,
           FEC_Updated_User_Queue_ID__c, FEC_User__c, FEC_User_Role__c,
           FEC_Stage_Name__c, FEC_Assignment__c
    FROM FEC_Routing_Action_History__c
    WHERE FEC_Case__c = :testCase.Id
    ORDER BY CreatedDate DESC
];

System.debug('Số routing history được tạo: ' + newHistories.size());
if (newHistories.size() == queues.size()) {
    System.debug('✅ PASS: Số history = số assignment (' + queues.size() + ')');
} else {
    System.debug('❌ FAIL: Số history (' + newHistories.size() + ') ≠ số assignment (' + queues.size() + ')');
}

for (FEC_Routing_Action_History__c h : newHistories) {
    System.debug('\nHistory: ' + h.Id);
    System.debug('  Action: ' + h.FEC_Routing_Action__c);
    System.debug('  Original Queue: ' + h.FEC_Original_User_Queue__c + ' (ID: ' + h.FEC_Original_User_Queue_ID__c + ')');
    System.debug('  Updated Queue: ' + h.FEC_Updated_User_Queue__c + ' (ID: ' + h.FEC_Updated_User_Queue_ID__c + ')');
    System.debug('  User: ' + h.FEC_User__c);
    System.debug('  User Role: ' + h.FEC_User_Role__c);
    System.debug('  Stage: ' + h.FEC_Stage_Name__c);
    System.debug('  Assignment: ' + h.FEC_Assignment__c);
}

// BƯỚC 10: Tổng kết
// ========================================
System.debug('\n========== TỔNG KẾT ==========');
Integer passCount = 0;
Integer totalChecks = 3; // tungnm37: giảm từ 4 xuống 3 vì không check OwnerId = null nữa

if (String.isNotBlank(updatedCase.FEC_Assignment_Users__c)) passCount++;
if (newAssignments.size() == queues.size()) passCount++;
if (newRemarks.size() == queues.size()) passCount++;

System.debug('Kết quả: ' + passCount + '/' + totalChecks + ' checks PASS');
if (passCount == totalChecks) {
    System.debug('✅ ✅ ✅ LUỒNG THỦ CÔNG HOẠT ĐỘNG ĐÚNG! ✅ ✅ ✅');
    System.debug('NOTE: FEC_Service_Case_Owner__c sẽ tự động ẩn giá trị trên UI khi có assignment');
} else {
    System.debug('❌ CÓ LỖI - Cần kiểm tra lại');
}

System.debug('\n========== KẾT THÚC TEST ==========');
