Id userId = UserInfo.getUserId();
User u = [SELECT Id, Name, Email, FEC_User_Group__c FROM User WHERE Id = :userId];
System.debug('User: ' + u.Name + ' | Email: ' + u.Email + ' | UserGroup: ' + u.FEC_User_Group__c);

// Check Queue membership
List<GroupMember> gms = [SELECT GroupId, Group.Name, Group.Type FROM GroupMember WHERE UserOrGroupId = :userId];
System.debug('Direct Queue memberships: ' + gms.size());
for (GroupMember gm : gms) {
    System.debug('  Queue: ' + gm.Group.Name + ' Type: ' + gm.Group.Type);
}

// Check same group users
if (String.isNotBlank(u.FEC_User_Group__c)) {
    List<User> sameGroup = [SELECT Id, Name FROM User WHERE FEC_User_Group__c = :u.FEC_User_Group__c AND IsActive = true LIMIT 10];
    System.debug('Same group users: ' + sameGroup.size());
    Set<Id> sameIds = new Set<Id>();
    for (User su : sameGroup) sameIds.add(su.Id);
    List<GroupMember> groupGms = [SELECT GroupId, Group.Name FROM GroupMember WHERE UserOrGroupId IN :sameIds AND Group.Type = 'Queue'];
    System.debug('Queue memberships from group: ' + groupGms.size());
    for (GroupMember gm : groupGms) System.debug('  ' + gm.Group.Name);
}
