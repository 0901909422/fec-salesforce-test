// tungnm37: debug SOQL usage step by step
String caseId = '500Az00000NNE9uIAH'; // S-2675

List<FEC_Team_Queue__c> teamQueues = [
    SELECT FEC_Select_Team__r.Name, FEC_Queue_Name__c
    FROM FEC_Team_Queue__c
    WHERE FEC_Queue_Name__c != null
    ORDER BY FEC_Select_Team__r.Name
];
System.debug('TeamQueues: ' + teamQueues.size() + ' | SOQL after query: ' + Limits.getQueries());

List<Map<String, Object>> items = new List<Map<String, Object>>();
for (FEC_Team_Queue__c tq : teamQueues) {
    Map<String, Object> item = new Map<String, Object>();
    item.put('teamName', tq.FEC_Select_Team__r?.Name);
    item.put('queueName', tq.FEC_Queue_Name__c);
    item.put('remark', 'Test');
    items.add(item);
}
System.debug('Items: ' + items.size());

User currentUser = [SELECT Id, Email, UserRole.Name, FEC_User_Group__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
System.debug('SOQL before call: ' + Limits.getQueries());

// Gọi từng bước nhỏ để xác định điểm vượt limit
// Step 1: chỉ query Group (trong createAssignmentsFromManualItems)
Set<String> queueNames = new Set<String>();
for (Map<String, Object> item : items) {
    String qn = (String) item.get('queueName');
    if (String.isNotBlank(qn)) queueNames.add(qn);
}
System.debug('Queue names count: ' + queueNames.size() + ' | SOQL: ' + Limits.getQueries());

List<Group> groups = [SELECT Id, Name, DeveloperName FROM Group WHERE DeveloperName IN :queueNames AND Type = 'Queue'];
System.debug('Groups found: ' + groups.size() + ' | SOQL after Group query: ' + Limits.getQueries());

List<Case> caseInfo = [SELECT Id, OwnerId, Owner.Name, Owner.Type, FEC_Final_Status__c FROM Case WHERE Id = :caseId LIMIT 1];
System.debug('SOQL after Case query: ' + Limits.getQueries());

// Build assignments
List<FEC_Assignment__c> assignments = new List<FEC_Assignment__c>();
Map<String, Id> queueNameToId = new Map<String, Id>();
Map<String, String> queueDevNameToDisplayName = new Map<String, String>();
for (Group g : groups) {
    queueNameToId.put(g.DeveloperName, g.Id);
    queueNameToId.put(g.Name, g.Id);
    queueDevNameToDisplayName.put(g.DeveloperName, g.Name);
}

Datetime ts = System.now();
for (Map<String, Object> item : items) {
    String teamName = (String) item.get('teamName');
    String queueName = (String) item.get('queueName');
    assignments.add(new FEC_Assignment__c(
        FEC_Case__c = caseId,
        FEC_Assignment_Name__c = 'Routing',
        FEC_Assignment_Type__c = 'Routing',
        FEC_Assignment_Status__c = 'Open',
        FEC_OwnerID__c = queueDevNameToDisplayName.containsKey(queueName) ? queueDevNameToDisplayName.get(queueName) : queueName,
        FEC_Team__c = teamName,
        FEC_Assignment_Remark__c = 'Test',
        FEC_Manual__c = true
    ));
}
System.debug('Assignments to insert: ' + assignments.size() + ' | SOQL before insert: ' + Limits.getQueries());

insert assignments;
System.debug('SOQL after insert: ' + Limits.getQueries() + ' | DML: ' + Limits.getDmlStatements());
