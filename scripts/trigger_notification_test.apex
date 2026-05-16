Id queueId = [SELECT Id FROM Group WHERE Name = 'CSM Mailbox' AND Type = 'Queue' LIMIT 1].Id;
Id myUserId = UserInfo.getUserId();

// Bước 1: Đổi về user trước
Case c = [SELECT Id, OwnerId FROM Case WHERE Id = '500Az00000M8FmqIAF'];
c.OwnerId = myUserId;
update c;
System.debug('Step 1: Owner set to user ' + myUserId);

// Bước 2: Đổi sang queue → trigger notification
c = [SELECT Id, OwnerId FROM Case WHERE Id = '500Az00000M8FmqIAF'];
c.OwnerId = queueId;
update c;
System.debug('Step 2: Owner set to CSM Mailbox → check email minhtung2108@gmail.com');
