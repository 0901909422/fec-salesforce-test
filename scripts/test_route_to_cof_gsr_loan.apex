// tungnm37: Test luồng ROUTE_TO_COF_GSR cho Loan
// Tìm Case Loan có BP COF hoặc GSR, gọi run(), verify Assignment tạo ra

// 1. Tìm Case Loan COF/GSR phù hợp
List<Case> cases = [
    SELECT Id, FEC_Product_Type__c, FEC_Product_Type__r.Name,
           FEC_Current_Case_Stage__c, FEC_Is_Submited__c,
           FEC_Actual_Nature_of_Case__c,
           FEC_Category__r.Name, FEC_SubCategory__r.Name,
           FEC_Draft_Remarks__c, Status
    FROM Case
    WHERE FEC_Product_Type__r.Name = 'Loan'
      AND (FEC_Business_Process__r.FEC_Code__c LIKE 'COF%' OR FEC_Business_Process__r.FEC_Code__c LIKE 'GSR%')
      AND IsClosed = false
    LIMIT 1
];

if (cases.isEmpty()) {
    // Fallback: tìm bất kỳ Case Loan nào chưa đóng
    cases = [
        SELECT Id, FEC_Product_Type__c, FEC_Product_Type__r.Name,
               FEC_Current_Case_Stage__c, FEC_Is_Submited__c,
               FEC_Actual_Nature_of_Case__c,
               FEC_Category__r.Name, FEC_SubCategory__r.Name,
               FEC_Draft_Remarks__c, Status
        FROM Case
        WHERE FEC_Product_Type__r.Name = 'Loan'
          AND IsClosed = false
        LIMIT 1
    ];
}

if (cases.isEmpty()) {
    System.debug('ERROR: Không tìm thấy Case Loan nào để test');
    return;
}

Case testCase = cases[0];
System.debug('=== Test Case ===');
System.debug('CaseId: ' + testCase.Id);
System.debug('ProductType: ' + testCase.FEC_Product_Type__r?.Name);
System.debug('Category: ' + testCase.FEC_Category__r?.Name);
System.debug('Status: ' + testCase.Status);
System.debug('IsSubmited: ' + testCase.FEC_Is_Submited__c);

// 2. Lấy natureOfCaseId
String natureOfCaseId = testCase.FEC_Actual_Nature_of_Case__c;

if (String.isBlank(natureOfCaseId)) {
    // Tìm NOC Loan COF có RA
    List<FEC_Routing_Assignment__c> loanRAs = [
        SELECT FEC_Nature_of_Cases__c
        FROM FEC_Routing_Assignment__c
        WHERE FEC_Nature_of_Cases__r.FEC_Product_Type__r.Name = 'Loan'
          AND FEC_Team__c != null AND FEC_Queue__c != null
        LIMIT 1
    ];
    if (!loanRAs.isEmpty()) {
        natureOfCaseId = loanRAs[0].FEC_Nature_of_Cases__c;
        System.debug('Using NOC from RA: ' + natureOfCaseId);
    }
}
System.debug('NatureOfCaseId: ' + natureOfCaseId);

// 3. Đếm Assignment trước khi test
Integer assignmentsBefore = [SELECT COUNT() FROM FEC_Assignment__c WHERE FEC_Case__c = :testCase.Id];
System.debug('Assignments BEFORE: ' + assignmentsBefore);

// 4. Gọi FEC_CaseBusinessService.run()
Map<String, String> params = new Map<String, String>{
    'caseId'          => testCase.Id,
    'natureOfCaseId'  => natureOfCaseId,
    'remarkContent'   => 'Test COF/GSR Loan - tungnm37',
    'stageName'       => 'Stage 1'
};

try {
    Object result = FEC_CaseBusinessService.run('Route to COF/GSR', params);
    System.debug('run() returned: ' + result);
} catch (Exception e) {
    System.debug('ERROR calling run(): ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}

// 5. Verify kết quả
Integer assignmentsAfter = [SELECT COUNT() FROM FEC_Assignment__c WHERE FEC_Case__c = :testCase.Id];
System.debug('Assignments AFTER: ' + assignmentsAfter);
System.debug('New assignments created: ' + (assignmentsAfter - assignmentsBefore));

List<FEC_Assignment__c> newAssignments = [
    SELECT Id, FEC_Assignment_Name__c, FEC_Assignment_Type__c,
           FEC_Assignment_Status__c, FEC_Team__c, FEC_OwnerID__c,
           FEC_Assignment_Remark__c, FEC_Assignment_Routing_Action__c
    FROM FEC_Assignment__c
    WHERE FEC_Case__c = :testCase.Id
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('=== New Assignments ===');
for (FEC_Assignment__c a : newAssignments) {
    System.debug('Assignment: ' + a.Id
        + ' | Name: ' + a.FEC_Assignment_Name__c
        + ' | Type: ' + a.FEC_Assignment_Type__c
        + ' | Status: ' + a.FEC_Assignment_Status__c
        + ' | Team: ' + a.FEC_Team__c
        + ' | OwnerId: ' + a.FEC_OwnerID__c
        + ' | Remark: ' + a.FEC_Assignment_Remark__c);
}

// 6. Verify Routing Action History
List<FEC_Routing_Action_History__c> histories = [
    SELECT Id, FEC_Routing_Action__c, FEC_Updated_User_Queue__c, FEC_Stage_Name__c
    FROM FEC_Routing_Action_History__c
    WHERE FEC_Case__c = :testCase.Id
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('=== Routing Action Histories ===');
for (FEC_Routing_Action_History__c h : histories) {
    System.debug('History: ' + h.Id + ' | Action: ' + h.FEC_Routing_Action__c + ' | Queue: ' + h.FEC_Updated_User_Queue__c + ' | Stage: ' + h.FEC_Stage_Name__c);
}
