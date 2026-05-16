// tungnm37: check SOQL limit sau khi submit case với nhiều team
// Chạy sau khi reproduce lỗi để xem debug log
// Trong debug log tìm: LIMIT_USAGE_FOR_NS - SOQL queries

// Check số assignment hiện tại của case đang test
String caseId = 'YOUR_CASE_ID'; // TODO: thay

List<FEC_Assignment__c> assignments = [
    SELECT Id, FEC_Team__c, FEC_OwnerID__c, FEC_Assignment_Status__c, FEC_Submitted_On__c
    FROM FEC_Assignment__c
    WHERE FEC_Case__c = :caseId
    ORDER BY CreatedDate DESC
    LIMIT 50
];
System.debug('Total assignments: ' + assignments.size());
for (FEC_Assignment__c a : assignments) {
    System.debug('Team: ' + a.FEC_Team__c + ' | Queue: ' + a.FEC_OwnerID__c + ' | Status: ' + a.FEC_Assignment_Status__c);
}

// Check SOQL limit hiện tại
System.debug('SOQL queries used: ' + Limits.getQueries());
System.debug('SOQL queries limit: ' + Limits.getLimitQueries());
System.debug('DML statements used: ' + Limits.getDmlStatements());
System.debug('DML rows used: ' + Limits.getDmlRows());
