// Test Loại 4 - SF App Notification (dùng Case thật, không hardcode)
Id queueId = [SELECT Id FROM Group WHERE Name = 'CSM Mailbox' AND Type = 'Queue' LIMIT 1].Id;
Id myUserId = UserInfo.getUserId();

// Lấy Case thật
Case realCase = [
    SELECT Id, OwnerId, CaseNumber, FEC_Product_Type__c, FEC_Category__c,
           FEC_SubCategory__c, FEC_SubCode__c
    FROM Case WHERE Id = '500Az00000M8FmqIAF'
];

// Fake oldMap: owner cũ là user
Case oldCase = new Case(Id = realCase.Id, OwnerId = myUserId);
Map<Id, Case> oldMap = new Map<Id, Case>{ realCase.Id => oldCase };

// New: owner mới là queue
realCase.OwnerId = queueId;

System.debug('CaseNumber: ' + realCase.CaseNumber);
FEC_NotificationService.sendSFAppNotifications(new List<Case>{ realCase }, oldMap);
System.debug('Done - check chuong SF App!');
