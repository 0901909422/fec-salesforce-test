Id userId = UserInfo.getUserId();
Group q = [SELECT Id FROM Group WHERE Name = 'CSM Mailbox' AND Type = 'Queue' LIMIT 1];
List<GroupMember> members = [SELECT Id FROM GroupMember WHERE GroupId = :q.Id AND UserOrGroupId = :userId];
if (!members.isEmpty()) {
    delete members;
    System.debug('Removed from CSM Mailbox');
} else {
    System.debug('Not a member');
}
