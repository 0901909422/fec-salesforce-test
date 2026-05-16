// Check email deliverability setting của org
Organization org = [SELECT Id, Name, IsSandbox FROM Organization LIMIT 1];
System.debug('Org: ' + org.Name + ' | IsSandbox: ' + org.IsSandbox);

// Check email limit còn lại
System.debug('Email invocations used: ' + Limits.getEmailInvocations() + ' / ' + Limits.getLimitEmailInvocations());

// Thử gửi test email trực tiếp
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new List<String>{'tungnm37@fpt.com'});
mail.setSubject('[TEST] Email deliverability check - ' + Datetime.now());
mail.setPlainTextBody('Test email từ org: ' + org.Name + ' lúc ' + Datetime.now());
mail.setSaveAsActivity(false);

try {
    Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail}, false);
    for (Messaging.SendEmailResult r : results) {
        System.debug('Send result: success=' + r.isSuccess());
        if (!r.isSuccess()) {
            for (Messaging.SendEmailError e : r.getErrors()) {
                System.debug('Error: ' + e.getMessage() + ' | StatusCode: ' + e.getStatusCode());
            }
        }
    }
} catch (Exception e) {
    System.debug('Exception: ' + e.getMessage());
}
