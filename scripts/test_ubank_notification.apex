// Test notification cho FEC_Ubank_Email queue
// 1. Đổi receiver sang tungnm.mpc@gmail.com
FEC_Notification__c notif = [
    SELECT Id, FEC_Receivers__c, FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c
    FROM FEC_Notification__c
    WHERE FEC_Assigned_to_Queue__c = 'FEC_Ubank_Email'
      AND FEC_Notification_Status__c = true
      AND FEC_Notification_Channel__r.Name = 'Email'
    LIMIT 1
];
System.debug('Notification receivers before: ' + notif.FEC_Receivers__c);
notif.FEC_Receivers__c = 'tungnm.mpc@gmail.com, tungnm37@fpt.com';
update notif;
System.debug('Notification receivers after: ' + notif.FEC_Receivers__c);

// 2. Lấy Queue
Group ubank = [SELECT Id FROM Group WHERE DeveloperName = 'FEC_Ubank_Email' AND Type = 'Queue' LIMIT 1];
User me = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

// 3. Tìm Case không phải đang ở Ubank Email queue
Case c = [
    SELECT Id, FEC_ID_Search__c, OwnerId, FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c
    FROM Case
    WHERE OwnerId != :ubank.Id
    ORDER BY LastModifiedDate DESC
    LIMIT 1
];
System.debug('Test Case: ' + c.FEC_ID_Search__c + ' current owner: ' + c.OwnerId);

// 4. Reset về User + set NOC
c.OwnerId = me.Id;
c.FEC_Product_Type__c = notif.FEC_Product_Type__c;
c.FEC_Category__c = notif.FEC_Category__c;
c.FEC_SubCategory__c = notif.FEC_SubCategory__c;
c.FEC_SubCode__c = notif.FEC_SubCode__c;
update c;
System.debug('Step 1: reset to User + set NOC');

// 5. Route đến Ubank Email queue → trigger notification
c.OwnerId = ubank.Id;
update c;
System.debug('Step 2: routed to Ubank Email → email should be sent to: tungnm.mpc@gmail.com, tungnm37@fpt.com');
