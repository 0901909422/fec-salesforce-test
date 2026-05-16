// Debug: xem Queue membership và EmailRoutingAddress của current user
Id userId = UserInfo.getUserId();
System.debug('Current User: ' + userId + ' - ' + UserInfo.getName());

// Queue mà user là member
Set<Id> queueIds = new Set<Id>();
for (GroupMember gm : [SELECT GroupId, Group.Name, Group.Type FROM GroupMember WHERE UserOrGroupId = :userId]) {
    if (gm.Group.Type == 'Queue') {
        queueIds.add(gm.GroupId);
        System.debug('Queue member: ' + gm.GroupId + ' - ' + gm.Group.Name);
    }
}

// Email của các Queue đó
for (Group q : [SELECT Id, Name, Email FROM Group WHERE Id IN :queueIds AND Email != null]) {
    System.debug('Queue email: ' + q.Name + ' => ' + q.Email);
}

// Tất cả EmailRoutingAddress
for (SObject r : Database.query('SELECT Id, Address, PersonalName FROM EmailRoutingAddress ORDER BY PersonalName ASC LIMIT 50')) {
    System.debug('EmailRoutingAddress: ' + r.get('PersonalName') + ' => ' + r.get('Address'));
}

// OrgWideEmailAddress
for (OrgWideEmailAddress owa : [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress]) {
    System.debug('OrgWide: ' + owa.DisplayName + ' => ' + owa.Address);
}
