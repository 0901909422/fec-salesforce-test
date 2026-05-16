// Bước 2: Đổi sang queue → trigger notification
Id queueId = [SELECT Id FROM Group WHERE Name = 'CSM Mailbox' AND Type = 'Queue' LIMIT 1].Id;
Case c = [SELECT Id, OwnerId FROM Case WHERE Id = '500Az00000M8FmqIAF'];
c.OwnerId = queueId;
update c;
System.debug('Done - owner now CSM Mailbox. Check email minhtung2108@gmail.com');
