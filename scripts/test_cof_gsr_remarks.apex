// ============================================================
// TEST COF/GSR: Đếm Case Remarks sau Stage 1 và Stage 2 submit
// Mục tiêu:
//   Stage 1 submit → chỉ 1 Case Remark (type=null/Case), 0 Assignment Remark
//   Stage 2 submit → thêm N Assignment Remarks (1 per assignment) + 1 Case Remark
// ============================================================

String caseId = null; // ← điền Case Id cần test, hoặc để null để tự tìm

// Tự tìm case COF/GSR chưa submit
if (String.isBlank(caseId)) {
    List<Case> cases = [
        SELECT Id, CaseNumber, FEC_Is_Submited__c,
               FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c
        FROM Case
        WHERE IsClosed = false
          AND FEC_Actual_Nature_of_Case__c != null
          AND FEC_Is_Submited__c = false
        LIMIT 10
    ];
    for (Case c : cases) {
        String code = c.FEC_Actual_Nature_of_Case__r?.FEC_Business_Process__r?.FEC_Code__c;
        if (code != null && (code.startsWith('COF') || code.startsWith('GSR'))) {
            caseId = c.Id;
            System.debug('✅ Tìm thấy Case COF/GSR: ' + c.CaseNumber + ' (' + caseId + ') code=' + code);
            break;
        }
    }
}

if (String.isBlank(caseId)) {
    System.debug('❌ Không tìm thấy case COF/GSR chưa submit. Điền caseId thủ công.');
    return;
}

// ---- Đếm remarks hiện tại ----
List<FEC_Case_Remarks__c> allRemarks = [
    SELECT Id, FEC_Case_Remarks__c, FEC_Remark_Type__c, FEC_Stage_Name__c, CreatedDate
    FROM FEC_Case_Remarks__c
    WHERE FEC_Case__c = :caseId
    ORDER BY CreatedDate ASC
];

System.debug('\n========== REMARKS HIỆN TẠI (' + allRemarks.size() + ' bản ghi) ==========');
Integer caseType = 0, assignType = 0, nullType = 0;
for (FEC_Case_Remarks__c r : allRemarks) {
    String t = r.FEC_Remark_Type__c;
    if (t == 'Assignment') assignType++;
    else if (t == null) nullType++;
    else caseType++;
    System.debug('  [' + t + '] "' + r.FEC_Case_Remarks__c + '" | Stage: ' + r.FEC_Stage_Name__c + ' | ' + r.CreatedDate);
}
System.debug('  → Case/null type: ' + (caseType + nullType) + ' | Assignment type: ' + assignType);

// ---- Kiểm tra FEC_Is_Submited__c ----
Case c = [SELECT Id, CaseNumber, FEC_Is_Submited__c, FEC_Stage_Name__c,
                 FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c
          FROM Case WHERE Id = :caseId LIMIT 1];
System.debug('\n--- Case: ' + c.CaseNumber + ' | FEC_Is_Submited__c=' + c.FEC_Is_Submited__c + ' | Stage=' + c.FEC_Stage_Name__c);
System.debug('--- Business Code: ' + c.FEC_Actual_Nature_of_Case__r?.FEC_Business_Process__r?.FEC_Code__c);

// ---- Kết luận ----
System.debug('\n========== KẾT LUẬN ==========');
if (c.FEC_Is_Submited__c == false) {
    System.debug('Đang ở Stage 1 (chưa submit)');
    System.debug('Mong đợi sau submit Stage 1: 1 Case Remark, 0 Assignment Remark');
    if (assignType > 0) {
        System.debug('❌ FAIL: Đang có ' + assignType + ' Assignment Remark ở Stage 1 - phải là 0');
    } else {
        System.debug('✅ OK: Không có Assignment Remark ở Stage 1');
    }
} else {
    System.debug('Đang ở Stage 2+ (đã submit ít nhất 1 lần)');
    System.debug('Mong đợi: có cả Case Remark và Assignment Remark');
    if (assignType == 0) {
        System.debug('❌ FAIL: Không có Assignment Remark ở Stage 2');
    } else {
        System.debug('✅ OK: Có ' + assignType + ' Assignment Remark ở Stage 2');
    }
}

System.debug('\n========== KẾT THÚC ==========');
