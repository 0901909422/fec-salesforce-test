// Check Case S-0906 chi tiết
List<Case> cases = [
    SELECT Id, CaseNumber, OwnerId, Owner.Name, Owner.Type,
           FEC_ID_Search__c, FEC_Product_Type__c, FEC_Category__c, 
           FEC_SubCategory__c, FEC_SubCode__c, Status, LastModifiedDate
    FROM Case 
    WHERE FEC_ID_Search__c = 'S-0906' 
    LIMIT 1
];

if (cases.isEmpty()) { System.debug('Không tìm thấy S-0906'); return; }

Case c = cases[0];
System.debug('OwnerId: ' + c.OwnerId);
System.debug('Owner.Name: ' + c.Owner.Name);
System.debug('Owner.Type (Group=Queue): ' + c.Owner.Type);
System.debug('OwnerId prefix 00G=Queue, 005=User: ' + String.valueOf(c.OwnerId).substring(0,3));
System.debug('ProductType: ' + c.FEC_Product_Type__c);
System.debug('Category: ' + c.FEC_Category__c);
System.debug('SubCategory: ' + c.FEC_SubCategory__c);
System.debug('SubCode: ' + c.FEC_SubCode__c);

// Check Notification record
FEC_Notification__c n = [
    SELECT Id, FEC_Assigned_to_Queue__c, FEC_Product_Type__c, FEC_Category__c,
           FEC_SubCategory__c, FEC_SubCode__c, FEC_Receivers__c,
           FEC_Notification_Template__r.FEC_Active__c,
           FEC_Notification_Template__r.FEC_Subject_Line__c,
           FEC_Schedule_Start_Time__c, FEC_Schedule_End_Time__c
    FROM FEC_Notification__c
    WHERE FEC_Assigned_to_Queue__c = 'FEC_DQ_CS_Support'
    LIMIT 1
];

System.debug('--- Notification ---');
System.debug('Queue field: ' + n.FEC_Assigned_to_Queue__c);
System.debug('ProductType filter: ' + n.FEC_Product_Type__c);
System.debug('Category filter: ' + n.FEC_Category__c);
System.debug('SubCategory filter: ' + n.FEC_SubCategory__c);
System.debug('SubCode filter: ' + n.FEC_SubCode__c);

// Check match
Id queueId = c.OwnerId;
List<Group> queues = [SELECT Id, DeveloperName FROM Group WHERE Id = :queueId AND Type = 'Queue'];
System.debug('Queue DeveloperName: ' + (queues.isEmpty() ? 'NOT A QUEUE!' : queues[0].DeveloperName));

Boolean productMatch = (n.FEC_Product_Type__c == null || n.FEC_Product_Type__c == c.FEC_Product_Type__c);
Boolean categoryMatch = (n.FEC_Category__c == null || n.FEC_Category__c == c.FEC_Category__c);
Boolean subCatMatch = (n.FEC_SubCategory__c == null || n.FEC_SubCategory__c == c.FEC_SubCategory__c);
Boolean subCodeMatch = (n.FEC_SubCode__c == null || n.FEC_SubCode__c == c.FEC_SubCode__c);
System.debug('Nature match: product=' + productMatch + ' cat=' + categoryMatch + ' subCat=' + subCatMatch + ' subCode=' + subCodeMatch);

Time nowTime = FEC_CommonUltils.getCurrentLocalTime();
Boolean scheduleOk = FEC_CommonUltils.isWithinSchedule(nowTime, n.FEC_Schedule_Start_Time__c, n.FEC_Schedule_End_Time__c);
System.debug('Now: ' + nowTime + ' | Schedule: ' + n.FEC_Schedule_Start_Time__c + ' → ' + n.FEC_Schedule_End_Time__c + ' | OK: ' + scheduleOk);
