// Test Loại 3 - Email Notification
Id queueId = [SELECT Id FROM Group WHERE Name = 'CSM Mailbox' AND Type = 'Queue' LIMIT 1].Id;
Id channelId = [SELECT Id FROM FEC_Notification_Channel__c WHERE Name = 'Email' LIMIT 1].Id;

delete [SELECT Id FROM FEC_Notification__c WHERE Name = 'TEST_EMAIL_NOTIF'];

FEC_Notification__c n = new FEC_Notification__c();
n.Name = 'TEST_EMAIL_NOTIF';
n.FEC_Target_Group__c = 'Internal User';
n.FEC_Notification_Status__c = true;
n.FEC_Notification_Channel__c = channelId;
n.FEC_Assigned_to_Queue__c = String.valueOf(queueId);
n.FEC_Receivers__c = 'minhtung2108@gmail.com';
insert n;
System.debug('Notification created: ' + n.Id + ' | Queue: ' + queueId);

Case c = [SELECT Id, OwnerId FROM Case WHERE Id = '500Az00000M8FmqIAF'];
Id oldOwner = c.OwnerId;
if (oldOwner == queueId) {
    c.OwnerId = UserInfo.getUserId();
    update c;
}
c = [SELECT Id, OwnerId FROM Case WHERE Id = '500Az00000M8FmqIAF'];
c.OwnerId = queueId;
update c;
System.debug('Case owner changed to CSM Mailbox. Check email minhtung2108@gmail.com');
