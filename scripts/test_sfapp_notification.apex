// Test Loại 4 - SF App notification trực tiếp
Id queueId = [SELECT Id FROM Group WHERE Name = 'CSM Mailbox' AND Type = 'Queue' LIMIT 1].Id;
Id myUserId = UserInfo.getUserId();

// Check CustomNotificationType
List<CustomNotificationType> cnts = [SELECT Id, DeveloperName FROM CustomNotificationType WHERE DeveloperName = 'Custom_Notification'];
System.debug('CustomNotificationType found: ' + cnts.size());
if (cnts.isEmpty()) {
    System.debug('ERROR: Cần tạo Custom Notification Type trong Setup → Notification Builder → Custom Notifications');
    return;
}

// Check notification record SF App
List<FEC_Notification__c> notifs = [
    SELECT Id, FEC_Assigned_to_Queue__c, FEC_Receivers__c,
           FEC_Notification_Channel__r.Name,
           FEC_Notification_Template__r.FEC_Subject_Line__c,
           FEC_Notification_Template__r.FEC_Body__c
    FROM FEC_Notification__c
    WHERE Name = 'TEST_SFAPP_NOTIF' LIMIT 1
];
if (notifs.isEmpty()) {
    System.debug('ERROR: Không tìm thấy TEST_SFAPP_NOTIF record');
    return;
}
System.debug('SF App notif: ' + notifs[0].FEC_Receivers__c);

// Fake trigger context
Case oldCase = new Case(Id = '500Az00000M8FmqIAF', OwnerId = myUserId);
Case newCase = new Case(Id = '500Az00000M8FmqIAF', OwnerId = queueId);
Map<Id, Case> oldMap = new Map<Id, Case>{ oldCase.Id => oldCase };

System.debug('Calling sendSFAppNotifications...');
FEC_NotificationService.sendSFAppNotifications(new List<Case>{ newCase }, oldMap);
System.debug('Done - check chuong SF App tren header!');
