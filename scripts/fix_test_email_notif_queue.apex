// Fix TEST_EMAIL_NOTIF: đổi FEC_Assigned_to_Queue__c sang FEC_Ubank_Email
FEC_Notification__c n = [
    SELECT Id, Name, FEC_Assigned_to_Queue__c
    FROM FEC_Notification__c
    WHERE Name = 'TEST_EMAIL_NOTIF'
    LIMIT 1
];
System.debug('Before: ' + n.FEC_Assigned_to_Queue__c);
n.FEC_Assigned_to_Queue__c = 'FEC_Ubank_Email';
update n;
System.debug('After: ' + [SELECT FEC_Assigned_to_Queue__c FROM FEC_Notification__c WHERE Id = :n.Id].FEC_Assigned_to_Queue__c);
