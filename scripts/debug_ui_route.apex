// Chạy ngay sau khi route Case từ UI
// Lấy Case vừa được route đến Queue gần nhất
List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, OwnerId, Owner.Name, Owner.Type,
           FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c
    FROM Case
    WHERE Owner.Type = 'Queue'
    ORDER BY LastModifiedDate DESC
    LIMIT 1
];
if (cases.isEmpty()) { System.debug('No case owned by Queue'); return; }
Case c = cases[0];
System.debug('Case: ' + c.FEC_ID_Search__c + ' | Queue: ' + c.Owner.Name);
System.debug('NOC: PT=' + c.FEC_Product_Type__c + ' Cat=' + c.FEC_Category__c + ' SubCat=' + c.FEC_SubCategory__c + ' SubCode=' + c.FEC_SubCode__c);

// Lấy Queue DeveloperName
Group q = [SELECT DeveloperName FROM Group WHERE Id = :c.OwnerId LIMIT 1];
System.debug('Queue DeveloperName: ' + q.DeveloperName);

// Tìm Notification record match
List<FEC_Notification__c> notifs = [
    SELECT Id, FEC_Assigned_to_Queue__c, FEC_Product_Type__c, FEC_Category__c,
           FEC_SubCategory__c, FEC_SubCode__c, FEC_Receivers__c,
           FEC_Notification_Template__r.FEC_Active__c,
           FEC_Notification_Template__r.FEC_Subject_Line__c
    FROM FEC_Notification__c
    WHERE FEC_Notification_Status__c = true
      AND FEC_Assigned_to_Queue__c = :q.DeveloperName
      AND FEC_Notification_Channel__r.Name = 'Email'
];
System.debug('Matching notifications: ' + notifs.size());
for (FEC_Notification__c n : notifs) {
    Boolean ptMatch = (n.FEC_Product_Type__c == null || n.FEC_Product_Type__c == c.FEC_Product_Type__c);
    Boolean catMatch = (n.FEC_Category__c == null || n.FEC_Category__c == c.FEC_Category__c);
    Boolean subCatMatch = (n.FEC_SubCategory__c == null || n.FEC_SubCategory__c == c.FEC_SubCategory__c);
    Boolean subCodeMatch = (n.FEC_SubCode__c == null || n.FEC_SubCode__c == c.FEC_SubCode__c);
    System.debug('Notif ' + n.Id + ': ptMatch=' + ptMatch + ' catMatch=' + catMatch + ' subCatMatch=' + subCatMatch + ' subCodeMatch=' + subCodeMatch);
    System.debug('  Template active=' + n.FEC_Notification_Template__r?.FEC_Active__c + ' subject=' + n.FEC_Notification_Template__r?.FEC_Subject_Line__c);
    System.debug('  Receivers=' + n.FEC_Receivers__c);
}
