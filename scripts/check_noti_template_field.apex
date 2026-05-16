// Check FEC_Notification_Template__c field type
Schema.DescribeFieldResult f = FEC_Notification__c.FEC_Notification_Template__c.getDescribe();
System.debug('Type: ' + f.getType());
System.debug('ReferenceTo: ' + f.getReferenceTo());

// Lấy 1 Notification record để xem template Id
FEC_Notification__c n = [
    SELECT Id, FEC_Notification_Template__c, FEC_Notification_Template__r.Id
    FROM FEC_Notification__c
    WHERE FEC_Notification_Template__c != null
    LIMIT 1
];
System.debug('Template Id: ' + n.FEC_Notification_Template__c);
System.debug('Template record Id: ' + n.FEC_Notification_Template__r?.Id);

// Check xem Id đó là EmailTemplate hay FEC_Template__c
String tId = n.FEC_Notification_Template__c;
System.debug('Id prefix: ' + (tId != null ? tId.substring(0,3) : 'null'));
// EmailTemplate prefix = '00X', FEC_Template__c = custom object prefix
