// tungnm37: test submit manual assignment với TẤT CẢ team queue cho S-2675
// Simulate luồng createAssignmentsFromManualItems với toàn bộ FEC_Team_Queue__c

String caseId = '500Az00000NNE9uIAH'; // S-2675 trên sb03

// 1. Lấy tất cả team queue từ FEC_Team_Queue__c (giống UI)
List<FEC_Team_Queue__c> teamQueues = [
    SELECT FEC_Select_Team__r.Name, FEC_Queue_Name__c
    FROM FEC_Team_Queue__c
    WHERE FEC_Queue_Name__c != null
    ORDER BY FEC_Select_Team__r.Name, FEC_Queue_Name__c
];
System.debug('Total team queues: ' + teamQueues.size());

if (teamQueues.isEmpty()) {
    System.debug('No team queues found');
    return;
}

// 2. Build manualItemsJson với TẤT CẢ items
List<Map<String, Object>> items = new List<Map<String, Object>>();
for (FEC_Team_Queue__c tq : teamQueues) {
    Map<String, Object> item = new Map<String, Object>();
    item.put('teamName', tq.FEC_Select_Team__r?.Name);
    item.put('queueName', tq.FEC_Queue_Name__c);
    item.put('remark', 'Test remark - ' + tq.FEC_Select_Team__r?.Name);
    items.add(item);
}

String manualItemsJson = JSON.serialize(items);
System.debug('Total items to submit: ' + items.size());

// 3. Current user
User currentUser = [SELECT Id, Email, UserRole.Name, FEC_User_Group__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
System.debug('Current user: ' + currentUser.Email);

// 4. SOQL/DML trước khi gọi
System.debug('BEFORE - SOQL: ' + Limits.getQueries() + '/' + Limits.getLimitQueries()
    + ' | DML: ' + Limits.getDmlStatements() + '/' + Limits.getLimitDmlStatements()
    + ' | DML rows: ' + Limits.getDmlRows() + '/' + Limits.getLimitDmlRows());

try {
    FEC_CofGsrAssignmentService.createAssignmentsFromManualItems(
        caseId,
        manualItemsJson,
        currentUser,
        'Test Stage - Stage 2'
    );
    System.debug('=== SUCCESS ===');
} catch (Exception e) {
    System.debug('=== ERROR: ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}

// 5. SOQL/DML sau khi gọi
System.debug('AFTER - SOQL: ' + Limits.getQueries() + '/' + Limits.getLimitQueries()
    + ' | DML: ' + Limits.getDmlStatements() + '/' + Limits.getLimitDmlStatements()
    + ' | DML rows: ' + Limits.getDmlRows() + '/' + Limits.getLimitDmlRows());

// 6. Check kết quả
List<FEC_Assignment__c> assignments = [
    SELECT Id, FEC_Team__c, FEC_OwnerID__c, FEC_Assignment_Status__c, FEC_Manual__c
    FROM FEC_Assignment__c
    WHERE FEC_Case__c = :caseId
    ORDER BY CreatedDate DESC LIMIT 100
];
System.debug('=== ASSIGNMENTS CREATED: ' + assignments.size());
for (FEC_Assignment__c a : assignments) {
    System.debug('Team: ' + a.FEC_Team__c + ' | Queue: ' + a.FEC_OwnerID__c + ' | Status: ' + a.FEC_Assignment_Status__c);
}
