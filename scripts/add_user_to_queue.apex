// Add current user vào Queue CSM Mailbox
Id userId = UserInfo.getUserId();
System.debug('User: ' + userId + ' - ' + UserInfo.getName());

// Tìm Queue CSM Mailbox
List<Group> queues = [SELECT Id, Name, Email FROM Group WHERE Type = 'Queue' AND Name LIKE '%CSM%' LIMIT 5];
for (Group q : queues) {
    System.debug('Found queue: ' + q.Id + ' - ' + q.Name + ' - ' + q.Email);
}

if (!queues.isEmpty()) {
    Group targetQueue = queues[0];
    // Check xem đã là member chưa
    List<GroupMember> existing = [SELECT Id FROM GroupMember WHERE GroupId = :targetQueue.Id AND UserOrGroupId = :userId LIMIT 1];
    if (existing.isEmpty()) {
        GroupMember gm = new GroupMember();
        gm.GroupId = targetQueue.Id;
        gm.UserOrGroupId = userId;
        insert gm;
        System.debug('Added user to queue: ' + targetQueue.Name);
    } else {
        System.debug('User already in queue: ' + targetQueue.Name);
    }
}
