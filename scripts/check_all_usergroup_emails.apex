// Check tất cả user group có những email nào
Schema.DescribeFieldResult f = User.FEC_User_Group__c.getDescribe();
List<String> allGroups = new List<String>();
for (Schema.PicklistEntry e : f.getPicklistValues()) {
    allGroups.add(e.getValue());
}

// Build map: userGroup -> Set<userId>
Map<String, Set<Id>> groupToUsers = new Map<String, Set<Id>>();
for (String ug : allGroups) groupToUsers.put(ug, new Set<Id>());
for (User u : [SELECT Id, FEC_User_Group__c FROM User WHERE FEC_User_Group__c IN :allGroups AND IsActive = true]) {
    groupToUsers.get(u.FEC_User_Group__c).add(u.Id);
}

// Build map: userId -> Set<queueId>
Set<Id> allUserIds = new Set<Id>();
for (Set<Id> ids : groupToUsers.values()) allUserIds.addAll(ids);
Map<Id, Set<Id>> userToQueues = new Map<Id, Set<Id>>();
for (GroupMember gm : [SELECT GroupId, UserOrGroupId FROM GroupMember WHERE UserOrGroupId IN :allUserIds]) {
    if (!userToQueues.containsKey(gm.UserOrGroupId)) userToQueues.put(gm.UserOrGroupId, new Set<Id>());
    userToQueues.get(gm.UserOrGroupId).add(gm.GroupId);
}

// Build map: queueId -> queueName
Map<Id, String> queueNames = new Map<Id, String>();
Set<Id> allQueueIds = new Set<Id>();
for (Set<Id> qids : userToQueues.values()) allQueueIds.addAll(qids);
for (Group q : [SELECT Id, Name FROM Group WHERE Id IN :allQueueIds AND Type = 'Queue']) {
    queueNames.put(q.Id, q.Name);
}

// Build map: queueName -> email
Map<String, String> queueNameToEmail = new Map<String, String>();
for (SObject r : [SELECT Address, PersonalName FROM EmailRoutingAddress]) {
    queueNameToEmail.put((String)r.get('PersonalName'), (String)r.get('Address'));
}

// Print result
for (String ug : allGroups) {
    Set<Id> userIds = groupToUsers.get(ug);
    Set<String> emails = new Set<String>();
    for (Id uid : userIds) {
        if (userToQueues.containsKey(uid)) {
            for (Id qid : userToQueues.get(uid)) {
                String qName = queueNames.get(qid);
                if (qName != null && queueNameToEmail.containsKey(qName)) {
                    emails.add(queueNameToEmail.get(qName));
                }
            }
        }
    }
    if (!emails.isEmpty()) {
        System.debug('UserGroup=' + ug + ' | Emails=' + emails);
    }
}
