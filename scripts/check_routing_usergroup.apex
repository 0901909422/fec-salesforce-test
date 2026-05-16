// Map EmailRoutingAddress -> Queue -> User Group của members
for (SObject r : [SELECT Address, PersonalName FROM EmailRoutingAddress ORDER BY PersonalName ASC]) {
    String routingName = (String) r.get('PersonalName');
    String routingAddr = (String) r.get('Address');
    
    // Tìm Queue có tên = PersonalName
    List<Group> queues = [SELECT Id, Name FROM Group WHERE Name = :routingName AND Type = 'Queue' LIMIT 1];
    if (queues.isEmpty()) {
        System.debug('Routing: ' + routingName + ' (' + routingAddr + ') -> No Queue match');
        continue;
    }
    
    // Lấy User Group của members
    Set<String> userGroups = new Set<String>();
    for (GroupMember gm : [SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :queues[0].Id LIMIT 50]) {
        List<User> users = [SELECT FEC_User_Group__c FROM User WHERE Id = :gm.UserOrGroupId AND FEC_User_Group__c != null LIMIT 1];
        if (!users.isEmpty() && String.isNotBlank(users[0].FEC_User_Group__c)) {
            userGroups.add(users[0].FEC_User_Group__c);
        }
    }
    System.debug('Routing: ' + routingName + ' (' + routingAddr + ') -> UserGroups: ' + userGroups);
}
