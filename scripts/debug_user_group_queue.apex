// Debug: xem User Group của current user và Queue/EmailRoutingAddress liên quan
Id userId = UserInfo.getUserId();
User u = [SELECT Id, Name, FEC_User_Group__c FROM User WHERE Id = :userId];
System.debug('User: ' + u.Name + ' | User Group: ' + u.FEC_User_Group__c);

// Xem tất cả Queue có tên chứa User Group value
String userGroup = u.FEC_User_Group__c;
if (String.isNotBlank(userGroup)) {
    for (Group q : [SELECT Id, Name, DeveloperName FROM Group WHERE Type = 'Queue' AND Name LIKE :('%' + userGroup + '%') LIMIT 10]) {
        System.debug('Queue match by name: ' + q.Name + ' | Dev: ' + q.DeveloperName);
    }
}

// Xem tất cả EmailRoutingAddress
for (SObject r : [SELECT Id, Address, PersonalName FROM EmailRoutingAddress ORDER BY PersonalName ASC LIMIT 20]) {
    System.debug('EmailRoutingAddress: ' + r.get('PersonalName') + ' → ' + r.get('Address'));
}

// Xem GroupMember của current user (direct)
for (GroupMember gm : [SELECT GroupId, Group.Name, Group.Type FROM GroupMember WHERE UserOrGroupId = :userId]) {
    System.debug('GroupMember: ' + gm.Group.Name + ' | Type: ' + gm.Group.Type);
}
