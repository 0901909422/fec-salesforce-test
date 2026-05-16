// Simulate getFromAddresses logic cho current user
Id userId = UserInfo.getUserId();
User currentUser = [SELECT FEC_User_Group__c FROM User WHERE Id = :userId LIMIT 1];
String userGroup = currentUser.FEC_User_Group__c;
System.debug('UserGroup: ' + userGroup);

Set<Id> sameGroupUserIds = new Set<Id>();
if (String.isNotBlank(userGroup)) {
    for (User u : [SELECT Id FROM User WHERE FEC_User_Group__c = :userGroup AND IsActive = true LIMIT 500]) {
        sameGroupUserIds.add(u.Id);
    }
}
sameGroupUserIds.add(userId);
System.debug('Same group users count: ' + sameGroupUserIds.size());

Set<Id> userQueueIds = new Set<Id>();
for (GroupMember gm : [SELECT GroupId FROM GroupMember WHERE UserOrGroupId IN :sameGroupUserIds]) {
    userQueueIds.add(gm.GroupId);
}
System.debug('Queue IDs count: ' + userQueueIds.size());

Set<String> queueNames = new Set<String>();
Set<String> queueEmails = new Set<String>();
for (Group q : [SELECT Name, Email FROM Group WHERE Id IN :userQueueIds AND Type = 'Queue']) {
    queueNames.add(q.Name);
    if (String.isNotBlank(q.Email)) queueEmails.add(q.Email.toLowerCase());
    System.debug('Queue: ' + q.Name + ' Email: ' + q.Email);
}

List<SObject> eras = [SELECT Id, Address, PersonalName FROM EmailRoutingAddress WHERE PersonalName IN :queueNames OR Address IN :queueEmails ORDER BY PersonalName ASC];
System.debug('EmailRoutingAddress found: ' + eras.size());
for (SObject r : eras) {
    System.debug('  ERA: ' + r.get('PersonalName') + ' <' + r.get('Address') + '>');
}
