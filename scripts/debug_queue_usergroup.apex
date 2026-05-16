// Xem tất cả Queue có EmailRoutingAddress và User Group của members
// Xem tất cả EmailRoutingAddress
System.debug('=== EmailRoutingAddress ===');
for (SObject r : [SELECT Id, Address, PersonalName FROM EmailRoutingAddress ORDER BY PersonalName ASC]) {
    System.debug('Routing: ' + r.get('PersonalName') + ' => ' + r.get('Address'));
}

// Xem Queue nào có members là User, lấy User Group của họ
System.debug('=== Queue Members User Group ===');
for (Group q : [SELECT Id, Name FROM Group WHERE Type = 'Queue' AND Name LIKE '%Mailbox%' LIMIT 10]) {
    System.debug('Queue: ' + q.Name);
    for (GroupMember gm : [SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :q.Id LIMIT 5]) {
        List<User> users = [SELECT Name, FEC_User_Group__c FROM User WHERE Id = :gm.UserOrGroupId LIMIT 1];
        if (!users.isEmpty()) {
            System.debug('  -> User: ' + users[0].Name + ' | UserGroup: ' + users[0].FEC_User_Group__c);
        }
    }
}

// Xem picklist values của User_Group
System.debug('=== User Group Picklist Values ===');
Schema.DescribeFieldResult f = User.FEC_User_Group__c.getDescribe();
for (Schema.PicklistEntry e : f.getPicklistValues()) {
    System.debug('Value: ' + e.getValue() + ' | Label: ' + e.getLabel());
}
