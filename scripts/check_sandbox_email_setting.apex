// Check org email deliverability
Organization org = [SELECT Id, Name, IsSandbox FROM Organization LIMIT 1];
System.debug('IsSandbox: ' + org.IsSandbox);

// Thử gửi trực tiếp đến gmail để test
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new List<String>{'minhtung2108@gmail.com'});
mail.setSubject('[DIRECT TEST] ' + Datetime.now());
mail.setPlainTextBody('Direct test to gmail from sandbox');
mail.setSaveAsActivity(false);

Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail}, false);
for (Messaging.SendEmailResult r : results) {
    System.debug('success=' + r.isSuccess());
    if (!r.isSuccess()) {
        for (Messaging.SendEmailError e : r.getErrors()) {
            System.debug('Error: ' + e.getMessage() + ' | code: ' + e.getStatusCode());
        }
    }
}
