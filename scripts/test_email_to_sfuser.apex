// Lấy email của current user và gửi test
String myEmail = UserInfo.getUserEmail();
String myName = UserInfo.getName();
System.debug('Sending to: ' + myEmail + ' (' + myName + ')');

Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new List<String>{ myEmail });
mail.setSubject('Test Notification Email - ' + Datetime.now().format('dd/MM/yyyy HH:mm:ss'));
mail.setPlainTextBody('Test email gửi từ FEC_NotificationService. Nếu nhận được email này thì email delivery hoạt động bình thường.');
mail.setSaveAsActivity(false);

List<Messaging.SendEmailResult> results = Messaging.sendEmail(
    new List<Messaging.SingleEmailMessage>{ mail }, false
);

for (Messaging.SendEmailResult r : results) {
    if (r.isSuccess()) {
        System.debug('SUCCESS - check hom thu: ' + myEmail);
    } else {
        for (Messaging.SendEmailError e : r.getErrors()) {
            System.debug('ERROR: ' + e.getStatusCode() + ' - ' + e.getMessage());
        }
    }
}
