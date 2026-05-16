// Auto test: query Notification config → tìm/tạo Case phù hợp → route đến Queue

// 1. Lấy Notification record active có Email channel
FEC_Notification__c notif = [
    SELECT FEC_Assigned_to_Queue__c, FEC_Product_Type__c, FEC_Category__c,
           FEC_SubCategory__c, FEC_SubCode__c, FEC_Receivers__c,
           FEC_Notification_Channel__r.Name
    FROM FEC_Notification__c
    WHERE FEC_Notification_Status__c = true
      AND FEC_Assigned_to_Queue__c = 'FEC_DQ_CS_Support'
      AND FEC_Notification_Channel__r.Name = 'Email'
    LIMIT 1
];
System.debug('Using Notification → Queue: ' + notif.FEC_Assigned_to_Queue__c + ' | Receivers: ' + notif.FEC_Receivers__c);

// 2. Lấy Queue Id từ DeveloperName
Group targetQueue = [SELECT Id, Name FROM Group WHERE DeveloperName = :notif.FEC_Assigned_to_Queue__c AND Type = 'Queue' LIMIT 1];
System.debug('Target Queue: ' + targetQueue.Name + ' | Id: ' + targetQueue.Id);

// 3. Lấy current user để reset owner
User me = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

// 4. Tìm Case đang owned bởi Queue đó hoặc bất kỳ Case nào để test
List<Case> cases = [
    SELECT Id, OwnerId, FEC_ID_Search__c, FEC_Product_Type__c, FEC_Category__c,
           FEC_SubCategory__c, FEC_SubCode__c
    FROM Case
    WHERE OwnerId != :targetQueue.Id
    ORDER BY LastModifiedDate DESC
    LIMIT 1
];

if (cases.isEmpty()) { System.debug('Không tìm thấy Case nào'); return; }
Case c = cases[0];
System.debug('Test Case: ' + c.FEC_ID_Search__c + ' | Current Owner: ' + c.OwnerId);

// 5. Reset về User trước
c.OwnerId = me.Id;
c.FEC_Product_Type__c = notif.FEC_Product_Type__c;
c.FEC_Category__c = notif.FEC_Category__c;
c.FEC_SubCategory__c = notif.FEC_SubCategory__c;
c.FEC_SubCode__c = notif.FEC_SubCode__c;
update c;
System.debug('Step 1: reset to User + set NOC');

// 6. Route đến Queue → trigger notification
c.OwnerId = targetQueue.Id;
update c;
System.debug('Step 2: routed to Queue ' + targetQueue.Name + ' → email should be sent to: ' + notif.FEC_Receivers__c);
