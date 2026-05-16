// Debug script: trace tại sao email notification không được gửi
// Chạy sau khi đã route 1 Case lên Queue đúng thiết lập

// BƯỚC 1: Lấy Case vừa route (thay CaseId bên dưới)
// Tìm Case gần nhất có OwnerId là Queue
List<Case> recentCases = [
    SELECT Id, OwnerId, Owner.Name, Owner.Type,
           FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c,
           CaseNumber
    FROM Case
    WHERE Owner.Type = 'Queue'
    ORDER BY LastModifiedDate DESC
    LIMIT 5
];

System.debug('=== RECENT CASES OWNED BY QUEUE ===');
for (Case c : recentCases) {
    System.debug('Case: ' + c.CaseNumber + ' | OwnerId: ' + c.OwnerId + ' | Queue: ' + c.Owner.Name);
    System.debug('  ProductType: ' + c.FEC_Product_Type__c + ' | Category: ' + c.FEC_Category__c);
    System.debug('  SubCategory: ' + c.FEC_SubCategory__c + ' | SubCode: ' + c.FEC_SubCode__c);
}

if (recentCases.isEmpty()) {
    System.debug('KHÔNG CÓ CASE NÀO ĐANG OWNED BY QUEUE');
    return;
}

Case testCase = recentCases[0];
Id queueId = testCase.OwnerId;

// BƯỚC 2: Lấy DeveloperName của Queue
List<Group> queues = [SELECT Id, Name, DeveloperName FROM Group WHERE Id = :queueId AND Type = 'Queue'];
System.debug('=== QUEUE INFO ===');
for (Group g : queues) {
    System.debug('Queue Name: ' + g.Name + ' | DeveloperName: ' + g.DeveloperName);
}

if (queues.isEmpty()) {
    System.debug('KHÔNG TÌM THẤY QUEUE');
    return;
}
String queueDevName = queues[0].DeveloperName;

// BƯỚC 3: Kiểm tra FEC_Notification__c records
List<FEC_Notification__c> notifs = [
    SELECT Id, Name,
           FEC_Target_Group__c,
           FEC_Notification_Status__c,
           FEC_Notification_Channel__r.Name,
           FEC_Assigned_to_Queue__c,
           FEC_Receivers__c,
           FEC_Product_Type__c,
           FEC_Category__c,
           FEC_SubCategory__c,
           FEC_SubCode__c,
           FEC_Schedule_Start_Time__c,
           FEC_Schedule_End_Time__c,
           FEC_Notification_Template__r.FEC_Subject_Line__c,
           FEC_Notification_Template__r.FEC_Active__c
    FROM FEC_Notification__c
    WHERE FEC_Target_Group__c = 'Internal User'
      AND FEC_Notification_Status__c = true
      AND FEC_Notification_Channel__r.Name = 'Email'
];

System.debug('=== NOTIFICATION RECORDS (Internal User + Email + Active) ===');
System.debug('Total found: ' + notifs.size());

for (FEC_Notification__c n : notifs) {
    System.debug('--- Notification: ' + n.Name + ' ---');
    System.debug('  FEC_Assigned_to_Queue__c: [' + n.FEC_Assigned_to_Queue__c + ']');
    System.debug('  Queue DeveloperName: [' + queueDevName + ']');
    System.debug('  Queue Id: [' + queueId + ']');
    System.debug('  Match Queue? ' + (n.FEC_Assigned_to_Queue__c != null && 
        (n.FEC_Assigned_to_Queue__c.trim() == queueDevName || 
         n.FEC_Assigned_to_Queue__c.trim() == String.valueOf(queueId).substring(0,15) ||
         n.FEC_Assigned_to_Queue__c.trim() == String.valueOf(queueId))));
    System.debug('  FEC_Receivers__c: ' + n.FEC_Receivers__c);
    System.debug('  Schedule: ' + n.FEC_Schedule_Start_Time__c + ' → ' + n.FEC_Schedule_End_Time__c);
    System.debug('  Template Subject: ' + n.FEC_Notification_Template__r?.FEC_Subject_Line__c);
    System.debug('  Template Active: ' + n.FEC_Notification_Template__r?.FEC_Active__c);
    
    // Check Nature of Case match
    Boolean productMatch = (n.FEC_Product_Type__c == null || n.FEC_Product_Type__c == testCase.FEC_Product_Type__c);
    Boolean categoryMatch = (n.FEC_Category__c == null || n.FEC_Category__c == testCase.FEC_Category__c);
    Boolean subCatMatch = (n.FEC_SubCategory__c == null || n.FEC_SubCategory__c == testCase.FEC_SubCategory__c);
    Boolean subCodeMatch = (n.FEC_SubCode__c == null || n.FEC_SubCode__c == testCase.FEC_SubCode__c);
    System.debug('  Nature match: product=' + productMatch + ' cat=' + categoryMatch + ' subCat=' + subCatMatch + ' subCode=' + subCodeMatch);
    
    // Check schedule
    Time nowTime = FEC_CommonUltils.getCurrentLocalTime();
    Boolean scheduleOk = FEC_CommonUltils.isWithinSchedule(nowTime, n.FEC_Schedule_Start_Time__c, n.FEC_Schedule_End_Time__c);
    System.debug('  Current time: ' + nowTime + ' | Schedule OK: ' + scheduleOk);
}

if (notifs.isEmpty()) {
    System.debug('KHÔNG CÓ NOTIFICATION RECORD NÀO THỎA ĐIỀU KIỆN QUERY!');
    System.debug('Kiểm tra: FEC_Target_Group__c = Internal User, FEC_Notification_Status__c = true, Channel = Email');
}
