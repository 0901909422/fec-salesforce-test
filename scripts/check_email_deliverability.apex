// Check 1: Email deliverability setting
System.debug('Deliverability: ' + System.OrgLimits.getMap().get('SingleEmail'));

// Check 2: Xem email log gần nhất
List<EmailMessage> msgs = [
    SELECT Id, ToAddress, Subject, MessageDate, Status
    FROM EmailMessage
    WHERE Subject LIKE 'Case Notification%'
    ORDER BY MessageDate DESC
    LIMIT 5
];
System.debug('EmailMessage count: ' + msgs.size());
for (EmailMessage m : msgs) {
    System.debug('To: ' + m.ToAddress + ' | Subject: ' + m.Subject + ' | Date: ' + m.MessageDate + ' | Status: ' + m.Status);
}

// Check 3: Org email deliverability
Organization org = [SELECT Id, IsSandbox FROM Organization LIMIT 1];
System.debug('IsSandbox: ' + org.IsSandbox);
