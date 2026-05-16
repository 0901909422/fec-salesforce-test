// Reset về User trước, rồi route lại về Queue để trigger fire
Group dqQueue = [SELECT Id FROM Group WHERE DeveloperName = 'FEC_DQ_CS_Support' AND Type = 'Queue' LIMIT 1];
User me = [SELECT Id FROM User WHERE Username = 'tungnm37.fe@fpt.com.fptsb03' LIMIT 1];

Case c = [SELECT Id, OwnerId, FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c
          FROM Case WHERE FEC_ID_Search__c = 'S-0906' LIMIT 1];

FEC_Notification__c n = [SELECT FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c
                          FROM FEC_Notification__c WHERE FEC_Assigned_to_Queue__c = 'FEC_DQ_CS_Support' LIMIT 1];

// Step 1: đổi về User
c.OwnerId = me.Id;
update c;
System.debug('Step1: reset to User');

// Step 2: route về Queue với đúng NOC
c.OwnerId = dqQueue.Id;
c.FEC_Product_Type__c = n.FEC_Product_Type__c;
c.FEC_Category__c = n.FEC_Category__c;
c.FEC_SubCategory__c = n.FEC_SubCategory__c;
c.FEC_SubCode__c = n.FEC_SubCode__c;
update c;
System.debug('Step2: routed to Queue DQ-CS-Support with NOC');
