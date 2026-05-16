// Check field type của FEC_Assigned_to_Queue__c
Schema.DescribeFieldResult f = FEC_Notification__c.FEC_Assigned_to_Queue__c.getDescribe();
System.debug('Field type: ' + f.getType());
System.debug('Reference to: ' + f.getReferenceTo());
System.debug('Field label: ' + f.getLabel());

// Lấy record để xem giá trị thực tế
List<FEC_Notification__c> notifs = [
    SELECT Id, Name, FEC_Assigned_to_Queue__c
    FROM FEC_Notification__c
    LIMIT 5
];
for (FEC_Notification__c r : notifs) {
    System.debug('Record: ' + r.Name + ' | FEC_Assigned_to_Queue__c = [' + r.FEC_Assigned_to_Queue__c + ']');
}
