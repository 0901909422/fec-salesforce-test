// Test trực tiếp FEC_NotificationService không qua trigger
Id queueId = [SELECT Id FROM Group WHERE Name = 'CSM Mailbox' AND Type = 'Queue' LIMIT 1].Id;
Id myUserId = UserInfo.getUserId();

Case c = [SELECT Id, OwnerId, CaseNumber, FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c FROM Case WHERE Id = '500Az00000M8FmqIAF'];

// oldMap: owner cũ là user (khác queue)
Case oldCase = new Case(Id = c.Id, OwnerId = myUserId);
Map<Id, Case> oldMap = new Map<Id, Case>{ c.Id => oldCase };

// new: owner mới là queue
Case newCase = new Case(Id = c.Id, OwnerId = queueId,
    FEC_Product_Type__c = c.FEC_Product_Type__c,
    FEC_Category__c = c.FEC_Category__c,
    FEC_SubCategory__c = c.FEC_SubCategory__c,
    FEC_SubCode__c = c.FEC_SubCode__c
);

System.debug('newCase.OwnerId: ' + newCase.OwnerId + ' type: ' + newCase.OwnerId.getSObjectType());
System.debug('oldCase.OwnerId: ' + oldCase.OwnerId + ' type: ' + oldCase.OwnerId.getSObjectType());

FEC_NotificationService.sendEmailNotifications(new List<Case>{ newCase }, oldMap);
System.debug('Done - check email minhtung2108@gmail.com');
