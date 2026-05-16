// Script kiểm tra Case Remarks được tạo từ assignments
System.debug('========== KIỂM TRA CASE REMARKS ==========\n');

// Lấy case vừa test
List<Case> cases = [
    SELECT Id, CaseNumber, FEC_Assignment_Users__c
    FROM Case 
    WHERE FEC_Assignment_Users__c != null
    ORDER BY LastModifiedDate DESC
    LIMIT 1
];

if (cases.isEmpty()) {
    System.debug('❌ Không tìm thấy case có assignment');
    return;
}

Case testCase = cases[0];
System.debug('Case: ' + testCase.CaseNumber + ' (ID: ' + testCase.Id + ')');
System.debug('FEC_Assignment_Users__c: ' + testCase.FEC_Assignment_Users__c);

// Lấy assignments của case này
List<FEC_Assignment__c> assignments = [
    SELECT Id, Name, FEC_Manual__c, FEC_Team__c, FEC_OwnerID__c,
           FEC_Assignment_Remark__c, CreatedDate
    FROM FEC_Assignment__c
    WHERE FEC_Case__c = :testCase.Id
    ORDER BY CreatedDate DESC
];

System.debug('\n--- ASSIGNMENTS ---');
System.debug('Số assignment: ' + assignments.size());
for (FEC_Assignment__c a : assignments) {
    System.debug('  Assignment: ' + a.Name);
    System.debug('    Manual: ' + a.FEC_Manual__c);
    System.debug('    Team: ' + a.FEC_Team__c);
    System.debug('    Queue: ' + a.FEC_OwnerID__c);
    System.debug('    Remark: ' + a.FEC_Assignment_Remark__c);
}

// Lấy Case Remarks của case này
List<FEC_Case_Remarks__c> remarks = [
    SELECT Id, FEC_Case_Remarks__c, FEC_User__c, FEC_Remark_Type__c,
           FEC_Assignment__c, FEC_Stage_Name__c, CreatedDate
    FROM FEC_Case_Remarks__c
    WHERE FEC_Case__c = :testCase.Id
      AND FEC_Remark_Type__c = 'Assignment'
    ORDER BY CreatedDate DESC
];

System.debug('\n--- CASE REMARKS (Type = Assignment) ---');
System.debug('Số remark: ' + remarks.size());

if (remarks.isEmpty()) {
    System.debug('❌ KHÔNG CÓ CASE REMARK NÀO!');
    System.debug('❌ LỖI: Assignments đã được tạo nhưng Case Remarks không được tạo');
} else {
    System.debug('✅ Có ' + remarks.size() + ' Case Remark(s)');
    
    for (FEC_Case_Remarks__c r : remarks) {
        System.debug('\nRemark ID: ' + r.Id);
        System.debug('  Content: ' + r.FEC_Case_Remarks__c);
        System.debug('  User: ' + r.FEC_User__c);
        System.debug('  Type: ' + r.FEC_Remark_Type__c);
        System.debug('  Assignment: ' + r.FEC_Assignment__c);
        System.debug('  Stage: ' + r.FEC_Stage_Name__c);
        System.debug('  Created: ' + r.CreatedDate);
    }
    
    // Kiểm tra số lượng
    if (remarks.size() == assignments.size()) {
        System.debug('\n✅ ✅ ✅ PASS: Số remark = số assignment (' + assignments.size() + ')');
    } else {
        System.debug('\n❌ FAIL: Số remark (' + remarks.size() + ') ≠ số assignment (' + assignments.size() + ')');
    }
}

System.debug('\n========== KẾT THÚC ==========');
