Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new String[]{ 'tungnm.mpc@gmail.com', 'minhtung2108@gmail.com' });
mail.setSubject('Test multi-to - ' + DateTime.now().format());
mail.setHtmlBody('<p>Test gửi đồng thời 2 email</p>');
Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail }, false);
System.debug('success=' + results[0].isSuccess());
if (!results[0].isSuccess()) {
    for (Messaging.SendEmailError e : results[0].getErrors()) {
        System.debug('Error: ' + e.getMessage());
    }
}
