// Test gửi email đơn giản nhất - không qua trigger
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new List<String>{ 'minhtung2108@gmail.com' });
mail.setSubject('Test from Salesforce Sandbox');
mail.setPlainTextBody('This is a test email from Salesforce sandbox.');
mail.setSaveAsActivity(false);

List<Messaging.SendEmailResult> results = Messaging.sendEmail(
    new List<Messaging.SingleEmailMessage>{ mail }, false
);

for (Messaging.SendEmailResult r : results) {
    if (r.isSuccess()) {
        System.debug('SUCCESS: Email sent!');
    } else {
        for (Messaging.SendEmailError e : r.getErrors()) {
            System.debug('ERROR: ' + e.getStatusCode() + ' - ' + e.getMessage());
        }
    }
}
