// Check email count per user group
for (String ug : new List<String>{'CC', 'SP'}) {
    Set<Id> userIds = new Set<Id>();
    for (User u : [SELECT Id FROM User WHERE FEC_User_Group__c = :ug AND IsActive = true]) {
        userIds.add(u.Id);
    }
    Set<Id> queueIds = new Set<Id>();
    for (GroupMember gm : [SELECT GroupId FROM GroupMember WHERE UserOrGroupId IN :userIds]) {
        queueIds.add(gm.GroupId);
    }
    Set<String> queueNames = new Set<String>();
    for (Group q : [SELECT Name FROM Group WHERE Id IN :queueIds AND Type = 'Queue']) {
        queueNames.add(q.Name);
    }
    List<SObject> routings = [SELECT Address, PersonalName FROM EmailRoutingAddress WHERE PersonalName IN :queueNames];
    System.debug('UserGroup=' + ug + ' | Queues=' + queueNames + ' | Emails=' + routings.size());
    for (SObject r : routings) {
        System.debug('  -> ' + r.get('PersonalName') + ' : ' + r.get('Address'));
    }
}
