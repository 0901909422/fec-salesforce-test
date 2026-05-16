// Script test đơn giản - nhập Case ID để test

// HƯỚNG DẪN: Thay YOUR_CASE_ID bằng ID của Service Case cần test
String testCaseId = 'YOUR_CASE_ID'; // VD: '500Az000001AbcD'

System.debug('========== KIỂM TRA ASSIGNMENT NULL OWNER ==========');

// Query case hiện tại
List<Case> cases = [
    SELECT Id, CaseNumber, OwnerId, FEC_Assignment_Users__c, 
           FEC_Actual_Nature_of_Case__c, RecordType.DeveloperName
    FROM Case 
    WHERE Id = :testCaseId
];

if (cases.isEmpty()) {
    System.debug('❌ ERROR: Không tìm thấy case với ID: ' + testCaseId);
    System.debug('Vui lòng thay YOUR_CASE_ID bằng ID thực tế của Service Case');
} else {
    Case c = cases[0];
    System.debug('✅ Tìm thấy Case: ' + c.CaseNumber);
    System.debug('Record Type: ' + c.RecordType.DeveloperName);
    System.debug('Owner hiện tại: ' + c.OwnerId);
    System.debug('FEC_Assignment_Users__c: ' + c.FEC_Assignment_Users__c);
    System.debug('Actual NOC: ' + c.FEC_Actual_Nature_of_Case__c);
    
    // Kiểm tra assignments hiện có
    List<FEC_Assignment__c> existingAssignments = [
        SELECT Id, FEC_Assignment_Status__c, FEC_Team__c, FEC_OwnerID__c, 
               FEC_Assignment_Owner__c, FEC_Manual__c
        FROM FEC_Assignment__c
        WHERE FEC_Case__c = :testCaseId
        ORDER BY CreatedDate DESC
    ];
    
    System.debug('\n--- ASSIGNMENTS HIỆN CÓ ---');
    System.debug('Số lượng: ' + existingAssignments.size());
    for (FEC_Assignment__c a : existingAssignments) {
        System.debug('  Assignment: ' + a.Id);
        System.debug('    Status: ' + a.FEC_Assignment_Status__c);
        System.debug('    Team: ' + a.FEC_Team__c);
        System.debug('    OwnerID: ' + a.FEC_OwnerID__c);
        System.debug('    Assignment Owner: ' + a.FEC_Assignment_Owner__c);
        System.debug('    Manual: ' + a.FEC_Manual__c);
    }
    
    // Kiểm tra logic
    System.debug('\n--- PHÂN TÍCH ---');
    if (existingAssignments.isEmpty()) {
        System.debug('⚠️  Case chưa có assignment nào');
        System.debug('   → OwnerId nên có giá trị (chưa route)');
        if (c.OwnerId != null) {
            System.debug('   ✅ ĐÚNG: OwnerId = ' + c.OwnerId);
        } else {
            System.debug('   ❌ SAI: OwnerId = null nhưng chưa có assignment');
        }
    } else {
        System.debug('✅ Case đã có ' + existingAssignments.size() + ' assignment(s)');
        System.debug('   → OwnerId phải = null');
        if (c.OwnerId == null) {
            System.debug('   ✅ ĐÚNG: OwnerId = null');
        } else {
            System.debug('   ❌ SAI: OwnerId vẫn còn = ' + c.OwnerId);
            System.debug('   ❌ LỖI: Khi có assignment, Service case owner phải null!');
        }
        
        if (String.isNotBlank(c.FEC_Assignment_Users__c)) {
            System.debug('   ✅ FEC_Assignment_Users__c đã được set: ' + c.FEC_Assignment_Users__c);
        } else {
            System.debug('   ⚠️  FEC_Assignment_Users__c chưa được set');
        }
    }
}

System.debug('\n========== KẾT THÚC ==========');
System.debug('\nĐể test tạo assignment mới:');
System.debug('1. Xóa assignments cũ: delete [SELECT Id FROM FEC_Assignment__c WHERE FEC_Case__c = :testCaseId];');
System.debug('2. Gọi FEC_CofGsrAssignmentService.createAssignmentsOnRoute() hoặc createAssignmentsFromManualItems()');
System.debug('3. Chạy lại script này để kiểm tra');
