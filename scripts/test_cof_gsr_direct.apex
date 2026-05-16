// tungnm37: Test trực tiếp FEC_CofGsrAssignmentService cho Loan

// 1. Lấy NOC Loan có RA
FEC_Routing_Assignment__c loanRA = [
    SELECT FEC_Nature_of_Cases__c, FEC_Team__c, FEC_Queue__c,
           FEC_Nature_of_Cases__r.FEC_Product_Type__r.Name,
           FEC_Nature_of_Cases__r.FEC_Business_Process__r.FEC_Code__c
    FROM FEC_Routing_Assignment__c
    WHERE FEC_Nature_of_Cases__r.FEC_Product_Type__r.Name = 'Loan'
      AND FEC_Team__c != null AND FEC_Queue__c != null
    LIMIT 1
];
System.debug('Loan RA: NOC=' + loanRA.FEC_Nature_of_Cases__c
    + ' | PT=' + loanRA.FEC_Nature_of_Cases__r?.FEC_Product_Type__r?.Name
    + ' | BP=' + loanRA.FEC_Nature_of_Cases__r?.FEC_Business_Process__r?.FEC_Code__c
    + ' | Team=' + loanRA.FEC_Team__c + ' | Queue=' + loanRA.FEC_Queue__c);

String nocId = loanRA.FEC_Nature_of_Cases__c;

// 2. Tìm Case Loan chưa đóng
List<Case> cases = [
    SELECT Id, FEC_Product_Type__r.Name, Status, OwnerId
    FROM Case
    WHERE FEC_Product_Type__r.Name = 'Loan'
      AND IsClosed = false
    LIMIT 1
];
if (cases.isEmpty()) {
    System.debug('ERROR: Không có Case Loan nào');
    return;
}
Case c = cases[0];
System.debug('Test Case: ' + c.Id + ' | PT=' + c.FEC_Product_Type__r?.Name + ' | Status=' + c.Status);

// 3. Đếm trước
Integer before = [SELECT COUNT() FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id];
System.debug('Assignments BEFORE: ' + before);

// 4. Gọi trực tiếp handleRouteToCofGsr
Map<String, String> params = new Map<String, String>{
    'natureOfCaseId' => nocId,
    'remarkContent'  => 'Test Loan COF/GSR - tungnm37'
};
try {
    FEC_CofGsrAssignmentService.handleRouteToCofGsr(c.Id, params, 'Stage 1');
    System.debug('handleRouteToCofGsr OK');
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage() + ' | ' + e.getStackTraceString());
}

// 5. Verify
Integer after = [SELECT COUNT() FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id];
System.debug('Assignments AFTER: ' + after + ' (created: ' + (after - before) + ')');

List<FEC_Assignment__c> created = [
    SELECT Id, FEC_Assignment_Name__c, FEC_Team__c, FEC_OwnerID__c,
           FEC_Assignment_Status__c, FEC_Assignment_Remark__c
    FROM FEC_Assignment__c
    WHERE FEC_Case__c = :c.Id
    ORDER BY CreatedDate DESC LIMIT 5
];
for (FEC_Assignment__c a : created) {
    System.debug('Assignment: ' + a.Id + ' | Name=' + a.FEC_Assignment_Name__c
        + ' | Team=' + a.FEC_Team__c + ' | Status=' + a.FEC_Assignment_Status__c
        + ' | OwnerId=' + a.FEC_OwnerID__c + ' | Remark=' + a.FEC_Assignment_Remark__c);
}
