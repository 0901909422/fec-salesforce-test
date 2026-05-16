FEC_Notification__c n = [SELECT Id FROM FEC_Notification__c WHERE Name = 'TEST_SFAPP_NOTIF' LIMIT 1];
n.FEC_Receivers__c = 'minhtung2108@gmail.com';
update n;
System.debug('Updated receivers to minhtung2108@gmail.com');
