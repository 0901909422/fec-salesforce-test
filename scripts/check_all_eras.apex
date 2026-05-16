// List all EmailRoutingAddress in org
List<SObject> eras = Database.query('SELECT Id, Address, PersonalName FROM EmailRoutingAddress ORDER BY PersonalName ASC');
System.debug('Total ERAs: ' + eras.size());
for (SObject r : eras) {
    System.debug('  PersonalName=[' + r.get('PersonalName') + '] Address=[' + r.get('Address') + ']');
}

// Also check what FEC_User_Group__c values exist on EmailRoutingAddress (if any custom field)
// Check queue names for CC group users
Id userId = UserInfo.getUserId();
User u = [SELECT FEC_User_Group__c FROM User WHERE Id = :userId];
System.debug('Current user group: ' + u.FEC_User_Group__c);

Set<Id> sameGroupIds = new Set<Id>();
for (User su : [SELECT Id FROM User WHERE FEC_User_Group__c = :u.FEC_User_Group__c AND IsActive = true LIMIT 500]) {
    sameGroupIds.add(su.Id);
}
sameGroupIds.add(userId);

Set<Id> queueIds = new Set<Id>();
for (GroupMember gm : [SELECT GroupId FROM GroupMember WHERE UserOrGroupId IN :sameGroupIds]) {
    queueIds.add(gm.GroupId);
}

System.debug('Queue IDs for CC group:');
for (Group q : [SELECT Id, Name, Email FROM Group WHERE Id IN :queueIds AND Type = 'Queue']) {
    System.debug('  Queue=[' + q.Name + '] Email=[' + q.Email + ']');
}
