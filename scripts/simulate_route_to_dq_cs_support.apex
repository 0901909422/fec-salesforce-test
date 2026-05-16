// Simulate: route Case S-0906 đến Queue DQ - CS Support với đúng NOC
// để test trigger notification

// Lấy Queue Id
Group dqQueue = [SELECT Id, DeveloperName FROM Group WHERE DeveloperName = 'FEC_DQ_CS_Support' AND Type = 'Queue' LIMIT 1];
System.debug('Queue Id: ' + dqQueue.Id + ' | DeveloperName: ' + dqQueue.DeveloperName);

// Lấy Notification để biết cần set NOC gì
FEC_Notification__c n = [
    SELECT FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c
    FROM FEC_Notification__c
    WHERE FEC_Assigned_to_Queue__c = 'FEC_DQ_CS_Support'
    LIMIT 1
];
System.debug('Required NOC - ProductType: ' + n.FEC_Product_Type__c);
System.debug('Required NOC - Category: ' + n.FEC_Category__c);
System.debug('Required NOC - SubCategory: ' + n.FEC_SubCategory__c);
System.debug('Required NOC - SubCode: ' + n.FEC_SubCode__c);

// Update Case S-0906: set đúng NOC + route đến Queue
Case c = [SELECT Id, OwnerId, FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c 
          FROM Case WHERE FEC_ID_Search__c = 'S-0906' LIMIT 1];

c.OwnerId = dqQueue.Id;
c.FEC_Product_Type__c = n.FEC_Product_Type__c;
c.FEC_Category__c = n.FEC_Category__c;
c.FEC_SubCategory__c = n.FEC_SubCategory__c;
c.FEC_SubCode__c = n.FEC_SubCode__c;

update c;
System.debug('Updated Case S-0906 → OwnerId: ' + dqQueue.Id + ' with matching NOC');
