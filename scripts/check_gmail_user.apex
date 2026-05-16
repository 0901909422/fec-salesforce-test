List<User> users = [SELECT Id, Email, IsActive FROM User WHERE Email LIKE '%tungnm%' OR Email LIKE '%minhtung%'];
for (User u : users) {
    System.debug('User: ' + u.Email + ' | Active: ' + u.IsActive);
}

// Check email deliverability setting
Organization org = [SELECT Id, IsSandbox FROM Organization LIMIT 1];
System.debug('IsSandbox: ' + org.IsSandbox);

// Thử gửi trực tiếp đến tungnm.mpc@gmail.com
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new List<String>{'tungnm.mpc@gmail.com'});
mail.setSubject('[TEST DIRECT] ' + Datetime.now());
mail.setPlainTextBody('Direct test');
mail.setSaveAsActivity(false);
Messaging.SendEmailResult[] r = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail}, false);
System.debug('Direct send result: success=' + r[0].isSuccess());
if (!r[0].isSuccess()) {
    for (Messaging.SendEmailError e : r[0].getErrors()) {
        System.debug('Error: ' + e.getMessage());
    }
}
