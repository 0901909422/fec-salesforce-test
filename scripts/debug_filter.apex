Id queueId = [SELECT Id FROM Group WHERE Name = 'CSM Mailbox' AND Type = 'Queue' LIMIT 1].Id;
Id myUserId = UserInfo.getUserId();

System.debug('queueId type: ' + queueId.getSObjectType());
System.debug('myUserId type: ' + myUserId.getSObjectType());
System.debug('Group.SObjectType: ' + Group.SObjectType);
System.debug('Is queue Group? ' + (queueId.getSObjectType() == Group.SObjectType));
