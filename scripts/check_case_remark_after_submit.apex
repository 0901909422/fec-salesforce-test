// ============================================================
// Script verify Case Remark History sau khi submit action từ UI
// Chạy sau khi bạn test thủ công: submit Escalate/Reject/Resolve
// trên Case COF/GSR Stage 2 hoặc bất kỳ NOC nào
// ============================================================

// Thay bằng Case ID bạn vừa test
String caseId = ''; // VD: '500Az00000Pv8IbIAJ'

if (String.isBlank(caseId)) {
    // Tự động lấy case mới nhất có remark
    List<FEC_Case_Remarks__c> latest = [
        SELECT FEC_Case__c, FEC_Case__r.FEC_ID_Search__c, CreatedDate
        FROM FEC_Case_Remarks__c
        WHERE FEC_Remark_Type__c = null
        ORDER BY CreatedDate DESC
        LIMIT 1
    ];
    if (!latest.isEmpty()) {
        caseId = latest[0].FEC_Case__c;
        System.debug('Auto-selected Case: ' + latest[0].FEC_Case__r.FEC_ID_Search__c);
    } else {
        System.debug('No case found. Set caseId manually.');
        return;
    }
}

// 1. Case info
List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Stage_Name__c,
           FEC_Current_Case_Stage__r.Name,
           FEC_Current_Case_Stage__r.FEC_Default_Stage__c
    FROM Case WHERE Id = :caseId LIMIT 1
];
if (cases.isEmpty()) { System.debug('Case not found'); return; }
Case c = cases[0];
System.debug('=== CASE: ' + c.FEC_ID_Search__c + ' | Stage: ' + c.FEC_Current_Case_Stage__r?.Name + ' | IsStage1: ' + c.FEC_Current_Case_Stage__r?.FEC_Default_Stage__c + ' ===');

// 2. Case Remarks History (type = null) - hiển thị trong Case Remarks History section
List<FEC_Case_Remarks__c> caseRemarks = [
    SELECT Id, FEC_Case_Remarks__c, FEC_Stage_Name__c, FEC_User__c, FEC_User_Role__c, CreatedDate
    FROM FEC_Case_Remarks__c
    WHERE FEC_Case__c = :caseId
      AND FEC_Remark_Type__c = null
    ORDER BY CreatedDate DESC
    LIMIT 10
];
System.debug('=== CASE REMARKS HISTORY (type=null): ' + caseRemarks.size() + ' records ===');
for (FEC_Case_Remarks__c r : caseRemarks) {
    System.debug('  [' + r.CreatedDate.format('dd/MM HH:mm:ss') + '] ' + r.FEC_Case_Remarks__c + ' | Stage: ' + r.FEC_Stage_Name__c + ' | User: ' + r.FEC_User__c);
}

// 3. Assignment Remarks (type = Assignment) - hiển thị trong Assignment Remarks History
List<FEC_Case_Remarks__c> assignmentRemarks = [
    SELECT Id, FEC_Case_Remarks__c, FEC_Stage_Name__c, FEC_User__c, FEC_Assignment__r.Name, CreatedDate
    FROM FEC_Case_Remarks__c
    WHERE FEC_Case__c = :caseId
      AND FEC_Remark_Type__c = 'Assignment'
    ORDER BY CreatedDate DESC
    LIMIT 10
];
System.debug('=== ASSIGNMENT REMARKS (type=Assignment): ' + assignmentRemarks.size() + ' records ===');
for (FEC_Case_Remarks__c r : assignmentRemarks) {
    System.debug('  [' + r.CreatedDate.format('dd/MM HH:mm:ss') + '] ' + r.FEC_Case_Remarks__c + ' | Stage: ' + r.FEC_Stage_Name__c + ' | Assignment: ' + r.FEC_Assignment__r?.Name);
}

// 4. Routing Action History
List<FEC_Routing_Action_History__c> histories = [
    SELECT Id, FEC_Routing_Action__c, FEC_Stage_Name__c, CreatedDate
    FROM FEC_Routing_Action_History__c
    WHERE FEC_Case__c = :caseId
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('=== ROUTING ACTION HISTORY: ' + histories.size() + ' records ===');
for (FEC_Routing_Action_History__c h : histories) {
    System.debug('  [' + h.CreatedDate.format('dd/MM HH:mm:ss') + '] Action: ' + h.FEC_Routing_Action__c + ' | Stage: ' + h.FEC_Stage_Name__c);
}
