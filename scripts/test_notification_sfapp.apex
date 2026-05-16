// Test Loại 4 - SF App Notification
Id queueId = [SELECT Id FROM Group WHERE Name = 'CSM Mailbox' AND Type = 'Queue' LIMIT 1].Id;
Id channelId = [SELECT Id FROM FEC_Notification_Channel__c WHERE Name = 'Salesforce App' LIMIT 1].Id;

delete [SELECT Id FROM FEC_Notification__c WHERE Name = 'TEST_SFAPP_NOTIF'];

FEC_Notification__c n = new FEC_Notification__c();
n.Name = 'TEST_SFAPP_NOTIF';
n.FEC_Target_Group__c = 'Internal User';
n.FEC_Notification_Status__c = true;
n.FEC_Notification_Channel__c = channelId;
n.FEC_Assigned_to_Queue__c = String.valueOf(queueId);
n.FEC_Receivers__c = 'tungnm37.fe@fpt.com'; // email SF login của bạn
insert n;
System.debug('SF App Notification created: ' + n.Id);

// Reset owner về user trước để trigger detect "changed"
Case c = [SELECT Id, OwnerId FROM Case WHERE Id = '500Az00000M8FmqIAF'];
if (c.OwnerId == queueId) {
    c.OwnerId = UserInfo.getUserId();
    update c;
}
c = [SELECT Id, OwnerId FROM Case WHERE Id = '500Az00000M8FmqIAF'];
c.OwnerId = queueId;
update c;
System.debug('Done - check chuong SF App!');
