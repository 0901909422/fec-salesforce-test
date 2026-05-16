// Check Notification record "Test auto di" đang lưu gì trong FEC_Assigned_to_Queue__c
List<FEC_Notification__c> notifs = [
    SELECT Id, Name, FEC_Assigned_to_Queue__c,
           FEC_Target_Group__c, FEC_Notification_Status__c,
           FEC_Notification_Channel__r.Name,
           FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c,
           FEC_Receivers__c, FEC_Schedule_Start_Time__c, FEC_Schedule_End_Time__c,
           FEC_Notification_Template__r.FEC_Subject_Line__c,
           FEC_Notification_Template__r.FEC_Active__c
    FROM FEC_Notification__c
    WHERE FEC_Assigned_to_Queue__c = 'FEC_DQ_CS_Support'
       OR Name = 'Test auto di'
];

System.debug('Found: ' + notifs.size());
for (FEC_Notification__c n : notifs) {
    System.debug('Name: ' + n.Name);
    System.debug('  FEC_Assigned_to_Queue__c: [' + n.FEC_Assigned_to_Queue__c + ']');
    System.debug('  Channel: ' + n.FEC_Notification_Channel__r?.Name);
    System.debug('  Status: ' + n.FEC_Notification_Status__c);
    System.debug('  Receivers: ' + n.FEC_Receivers__c);
    System.debug('  Template active: ' + n.FEC_Notification_Template__r?.FEC_Active__c);
}

// Check DeveloperName của Queue "DQ - CS Support"
List<Group> q = [SELECT Id, Name, DeveloperName FROM Group WHERE Name = 'DQ - CS Support' AND Type = 'Queue'];
System.debug('Queue DQ - CS Support DeveloperName: ' + (q.isEmpty() ? 'NOT FOUND' : q[0].DeveloperName));

// Check Case S-0906
List<Case> cases = [SELECT Id, CaseNumber, OwnerId, Owner.Name, FEC_ID_Search__c,
                           FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c
                    FROM Case WHERE FEC_ID_Search__c = 'S-0906' LIMIT 1];
if (!cases.isEmpty()) {
    Case c = cases[0];
    System.debug('Case S-0906 OwnerId: ' + c.OwnerId + ' | Owner: ' + c.Owner.Name);
    System.debug('  ProductType: ' + c.FEC_Product_Type__c);
    System.debug('  Category: ' + c.FEC_Category__c);
    System.debug('  SubCategory: ' + c.FEC_SubCategory__c);
    System.debug('  SubCode: ' + c.FEC_SubCode__c);
}
