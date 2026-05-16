// tungnm37: debug từng bước SOQL trong createAssignmentsFromManualItems
String caseId = '500Az00000NNE9uIAH'; // S-2675

// Lấy tất cả team queues
List<FEC_Team_Queue__c> teamQueues = [
    SELECT FEC_Select_Team__r.Name, FEC_Queue_Name__c
    FROM FEC_Team_Queue__c WHERE FEC_Queue_Name__c != null
    ORDER BY FEC_Select_Team__r.Name
];
System.debug('Step 1 - TeamQueues: ' + teamQueues.size() + ' | SOQL: ' + Limits.getQueries());

// Build items
List<Map<String, Object>> items = new List<Map<String, Object>>();
for (FEC_Team_Queue__c tq : teamQueues) {
    Map<String, Object> item = new Map<String, Object>();
    item.put('teamName', tq.FEC_Select_Team__r?.Name);
    item.put('queueName', tq.FEC_Queue_Name__c);
    item.put('remark', 'Test');
    items.add(item);
}

User currentUser = [SELECT Id, Email, UserRole.Name, FEC_User_Group__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
System.debug('Step 2 - User query | SOQL: ' + Limits.getQueries());

// Query Group
Set<String> queueNames = new Set<String>();
for (Map<String, Object> item : items) {
    String qn = (String) item.get('queueName');
    if (String.isNotBlank(qn)) queueNames.add(qn);
}
Map<String, Id> queueNameToId = new Map<String, Id>();
Map<String, String> queueDevNameToDisplayName = new Map<String, String>();
for (Group g : [SELECT Id, Name, DeveloperName FROM Group WHERE DeveloperName IN :queueNames AND Type = 'Queue']) {
    queueNameToId.put(g.DeveloperName, g.Id);
    queueNameToId.put(g.Name, g.Id);
    queueDevNameToDisplayName.put(g.DeveloperName, g.Name);
}
System.debug('Step 3 - Group query | SOQL: ' + Limits.getQueries());

// Query Case
Case currentCase = [SELECT Id, OwnerId, Owner.Name, Owner.Type, FEC_Final_Status__c FROM Case WHERE Id = :caseId LIMIT 1];
System.debug('Step 4 - Case query | SOQL: ' + Limits.getQueries());

// Build assignments
Datetime ts = System.now();
List<FEC_Assignment__c> assignments = new List<FEC_Assignment__c>();
List<String> remarkList = new List<String>();
List<String> queueNameList = new List<String>();
for (Map<String, Object> item : items) {
    String teamName = (String) item.get('teamName');
    String queueName = (String) item.get('queueName');
    String remark = (String) item.get('remark');
    assignments.add(new FEC_Assignment__c(
        FEC_Case__c = caseId,
        FEC_Assignment_Name__c = 'Routing',
        FEC_Assignment_Type__c = 'Routing',
        FEC_Assignment_Status__c = 'Open',
        FEC_OwnerID__c = queueDevNameToDisplayName.containsKey(queueName) ? queueDevNameToDisplayName.get(queueName) : queueName,
        FEC_Team__c = teamName,
        FEC_Assignment_Remark__c = remark,
        FEC_Manual__c = true
    ));
    remarkList.add(remark);
    queueNameList.add(queueDevNameToDisplayName.containsKey(queueName) ? queueDevNameToDisplayName.get(queueName) : queueName);
}
System.debug('Step 5 - Before insert assignments (' + assignments.size() + ') | SOQL: ' + Limits.getQueries());

insert assignments;
System.debug('Step 6 - After insert assignments | SOQL: ' + Limits.getQueries() + ' | DML: ' + Limits.getDmlStatements());

// Insert remarks
List<FEC_Case_Remarks__c> remarks = new List<FEC_Case_Remarks__c>();
for (Integer i = 0; i < assignments.size(); i++) {
    remarks.add(new FEC_Case_Remarks__c(
        FEC_Case__c = caseId,
        FEC_Remark_Type__c = 'Assignment',
        FEC_Case_Remarks__c = remarkList[i],
        FEC_User__c = 'test',
        FEC_Assignment__c = assignments[i].Id,
        FEC_Stage_Name__c = 'Test Stage'
    ));
}
insert remarks;
System.debug('Step 7 - After insert remarks | SOQL: ' + Limits.getQueries() + ' | DML: ' + Limits.getDmlStatements());

// Insert histories
List<FEC_Routing_Action_History__c> histories = new List<FEC_Routing_Action_History__c>();
for (Integer i = 0; i < assignments.size(); i++) {
    histories.add(new FEC_Routing_Action_History__c(
        FEC_Routing_Action__c = 'Route to',
        FEC_Case__c = caseId,
        FEC_Assignment__c = assignments[i].Id,
        FEC_Perform_User__c = currentUser.Id,
        FEC_User__c = 'test',
        FEC_Stage_Name__c = 'Test Stage',
        FEC_Submitted_On__c = DateTime.now()
    ));
}
insert histories;
System.debug('Step 8 - After insert histories | SOQL: ' + Limits.getQueries() + ' | DML: ' + Limits.getDmlStatements());

// Update Case
FEC_CaseTriggerHandler.isSystemUpdate = true;
try {
    update new Case(Id = caseId, FEC_Assignment_Users__c = 'test');
    System.debug('Step 9 - After update Case | SOQL: ' + Limits.getQueries() + ' | DML: ' + Limits.getDmlStatements());
} finally {
    FEC_CaseTriggerHandler.isSystemUpdate = false;
}
