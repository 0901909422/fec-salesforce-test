// ========================================
// TEST FULL LUỒNG THỦ CÔNG COF/GSR v2
// Stage 1: submit → tạo Assignment Remark + Case Remark (từ submitRemarkDirect)
// Stage 2: submit → tạo Assignment Remark + Case Remark (từ Apex, không duplicate)
// ========================================

System.debug('========== TEST FULL LUỒNG THỦ CÔNG COF/GSR ==========');

// Tìm Case COF/GSR chưa submit
List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Stage_Name__c, FEC_Is_Submited__c,
           OwnerId, Owner.Name, FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c
    FROM Case
    WHERE FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c LIKE 'COF%'
      AND FEC_Is_Submited__c = false
      AND IsClosed = false
    LIMIT 1
];
if (cases.isEmpty()) {
    System.debug('Không tìm thấy Case COF chưa submit. Tìm case bất kỳ...');
    cases = [SELECT Id, FEC_ID_Search__c, FEC_Stage_Name__c, FEC_Is_Submited__c, OwnerId, Owner.Name
             FROM Case WHERE IsClosed = false AND FEC_Is_Submited__c = false LIMIT 1];
}
if (cases.isEmpty()) { System.debug('Không có case nào'); return; }

Case c = cases[0];
System.debug('Case: ' + c.FEC_ID_Search__c + ' Id=' + c.Id + ' Stage=[' + c.FEC_Stage_Name__c + '] Owner=' + c.Owner?.Name);

// Tìm 2 queues để test
List<Group> queues = [SELECT Id, Name, DeveloperName FROM Group WHERE Type = 'Queue' AND DeveloperName LIKE 'FEC_%' LIMIT 2];
if (queues.isEmpty()) { System.debug('Không có queue'); return; }
System.debug('Queues: ' + queues[0].Name + (queues.size() > 1 ? ', ' + queues[1].Name : ''));

User currentUser = [SELECT Id, Email, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId()];
System.debug('User: ' + currentUser.Email);

// Xóa data cũ
delete [SELECT Id FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id];
delete [SELECT Id FROM FEC_Case_Remarks__c WHERE FEC_Case__c = :c.Id];
delete [SELECT Id FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :c.Id];
Database.update(new Case(Id = c.Id, FEC_Is_Submited__c = false, FEC_Assignment_Users__c = null), false);
System.debug('Đã xóa data cũ');

// ── STAGE 1 ──────────────────────────────────────────────────────────────────
System.debug('\n===== STAGE 1 =====');
String stage1Name = (c.FEC_Stage_Name__c != null ? c.FEC_Stage_Name__c : 'Test Stage 1');
if (!stage1Name.containsIgnoreCase('Stage 1')) stage1Name = 'COF - Test - Stage 1';

// Manual items Stage 1: 1 queue
String manualJson1 = '[{"teamName":"' + queues[0].Name + '","queueName":"' + queues[0].DeveloperName + '","remark":"Remark Stage 1"}]';
String caseRemark1 = 'Case Remark Stage 1';

// Simulate: set remarkContent trên case business rồi gọi handleRouteToCofGsr
Map<String, Object> params1 = new Map<String, Object>{
    'caseId' => c.Id,
    'manualItemsJson' => manualJson1,
    'remarkContent' => caseRemark1
};
FEC_CofGsrAssignmentService.handleRouteToCofGsr(c.Id, params1, stage1Name);

// Simulate submitRemarkDirect (LWC gọi sau submit)
FEC_CaseRemarkController.submitRemarkDirect(c.Id, stage1Name, caseRemark1);

// Kiểm tra Stage 1
List<FEC_Case_Remarks__c> remarks1 = [
    SELECT FEC_Case_Remarks__c, FEC_Remark_Type__c, FEC_Stage_Name__c, CreatedDate
    FROM FEC_Case_Remarks__c WHERE FEC_Case__c = :c.Id ORDER BY CreatedDate ASC
];
System.debug('Stage 1 - Total remarks: ' + remarks1.size());
for (FEC_Case_Remarks__c r : remarks1) {
    System.debug('  Type=[' + r.FEC_Remark_Type__c + '] Content=[' + r.FEC_Case_Remarks__c + ']');
}

// Kiểm tra: Stage 1 phải có đúng 1 Assignment Remark + 1 Case Remark (không duplicate)
Integer s1Assignment = 0, s1Case = 0;
for (FEC_Case_Remarks__c r : remarks1) {
    if (r.FEC_Remark_Type__c == 'Assignment') s1Assignment++;
    else s1Case++;
}
System.debug('Stage 1 Assignment Remarks: ' + s1Assignment + ' (expected: 1 - từ Apex)');
System.debug('Stage 1 Case Remarks: ' + s1Case + ' (expected: 1 - từ submitRemarkDirect)');
System.debug(s1Assignment == 1 && s1Case == 1 ? '✅ Stage 1 PASS' : '❌ Stage 1 FAIL - sai số lượng!');

// ── STAGE 2 ──────────────────────────────────────────────────────────────────
System.debug('\n===== STAGE 2 =====');
String stage2Name = stage1Name.replace('Stage 1', 'Stage 2');

// Đổi owner về user (simulate Change Owner)
Database.update(new Case(Id = c.Id, OwnerId = currentUser.Id), false);

// Manual items Stage 2: 2 queues
String manualJson2 = '[{"teamName":"' + queues[0].Name + '","queueName":"' + queues[0].DeveloperName + '","remark":"Remark S2 Q1"}' +
    (queues.size() > 1 ? ',{"teamName":"' + queues[1].Name + '","queueName":"' + queues[1].DeveloperName + '","remark":"Remark S2 Q2"}' : '') + ']';
String caseRemark2 = 'Case Remark Stage 2';

Map<String, Object> params2 = new Map<String, Object>{
    'caseId' => c.Id,
    'manualItemsJson' => manualJson2,
    'remarkContent' => caseRemark2
};
FEC_CofGsrAssignmentService.handleRouteToCofGsr(c.Id, params2, stage2Name);

// Simulate submitRemarkDirect (LWC gọi sau submit - phải bị block bởi duplicate check)
FEC_CaseRemarkController.submitRemarkDirect(c.Id, stage2Name, caseRemark2);

// Kiểm tra Stage 2
List<FEC_Case_Remarks__c> remarks2 = [
    SELECT FEC_Case_Remarks__c, FEC_Remark_Type__c, FEC_Stage_Name__c, CreatedDate
    FROM FEC_Case_Remarks__c WHERE FEC_Case__c = :c.Id ORDER BY CreatedDate ASC
];
System.debug('Stage 2 - Total remarks: ' + remarks2.size());
for (FEC_Case_Remarks__c r : remarks2) {
    System.debug('  Type=[' + r.FEC_Remark_Type__c + '] Content=[' + r.FEC_Case_Remarks__c + '] Stage=[' + r.FEC_Stage_Name__c + ']');
}

// Kiểm tra: Stage 2 phải có đúng N Assignment Remarks + 1 Case Remark (không duplicate)
Integer s2Assignment = 0, s2Case = 0;
for (FEC_Case_Remarks__c r : remarks2) {
    if (r.FEC_Stage_Name__c != null && r.FEC_Stage_Name__c.containsIgnoreCase('Stage 2')) {
        if (r.FEC_Remark_Type__c == 'Assignment') s2Assignment++;
        else s2Case++;
    }
}
Integer expectedAssignments = queues.size();
System.debug('Stage 2 Assignment Remarks: ' + s2Assignment + ' (expected: ' + expectedAssignments + ')');
System.debug('Stage 2 Case Remarks: ' + s2Case + ' (expected: 1)');
System.debug(s2Assignment == expectedAssignments && s2Case == 1 ? '✅ Stage 2 PASS' : '❌ Stage 2 FAIL - duplicate!');

// ── ROUTING HISTORY ──────────────────────────────────────────────────────────
System.debug('\n===== ROUTING HISTORY =====');
List<FEC_Routing_Action_History__c> histories = [
    SELECT FEC_Routing_Action__c, FEC_Original_User_Queue__c, FEC_Updated_User_Queue__c, FEC_Stage_Name__c
    FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :c.Id ORDER BY CreatedDate ASC
];
System.debug('Total histories: ' + histories.size());
for (FEC_Routing_Action_History__c h : histories) {
    System.debug('  Action=' + h.FEC_Routing_Action__c + ' Original=[' + h.FEC_Original_User_Queue__c + '] Updated=[' + h.FEC_Updated_User_Queue__c + '] Stage=[' + h.FEC_Stage_Name__c + ']');
}

// Stage 1: Original phải là currentUser email
Boolean stage1HistoryOk = false;
for (FEC_Routing_Action_History__c h : histories) {
    if (h.FEC_Stage_Name__c != null && h.FEC_Stage_Name__c.containsIgnoreCase('Stage 1')) {
        String expectedOriginal = currentUser.Email.substringBefore('@');
        stage1HistoryOk = h.FEC_Original_User_Queue__c == expectedOriginal;
        System.debug('Stage 1 Original=[' + h.FEC_Original_User_Queue__c + '] expected=[' + expectedOriginal + ']');
    }
}
System.debug(stage1HistoryOk ? '✅ Stage 1 History PASS' : '❌ Stage 1 History FAIL - Original sai');

// ── TỔNG KẾT ─────────────────────────────────────────────────────────────────
System.debug('\n========== TỔNG KẾT ==========');
Boolean allPass = (s1Assignment == 1 && s1Case == 1) && (s2Assignment == expectedAssignments && s2Case == 1) && stage1HistoryOk;
System.debug(allPass ? '✅ TẤT CẢ PASS - Luồng thủ công hoạt động đúng!' : '❌ CÓ LỖI - Kiểm tra lại');
