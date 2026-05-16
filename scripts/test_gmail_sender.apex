// Test gửi với Gmail OrgWide sender
OrgWideEmailAddress gmailSender = [SELECT Id, Address FROM OrgWideEmailAddress WHERE Address = 'tsalesforce63@gmail.com' LIMIT 1];
System.debug('Using sender: ' + gmailSender.Address);

Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new String[]{ 'tungnm.mpc@gmail.com' });
mail.setOrgWideEmailAddressId(gmailSender.Id);
mail.setSubject('Test with Gmail sender - ' + DateTime.now().format());
mail.setHtmlBody('<p>Test email dùng Gmail OrgWide sender</p>');
Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail }, false);
System.debug('success=' + results[0].isSuccess());
if (!results[0].isSuccess()) {
    for (Messaging.SendEmailError e : results[0].getErrors()) {
        System.debug('Error: ' + e.getMessage());
    }
}
