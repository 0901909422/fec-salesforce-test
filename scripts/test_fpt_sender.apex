OrgWideEmailAddress sender = [SELECT Id, Address, IsVerified FROM OrgWideEmailAddress WHERE Address = 'tungnm37@fpt.com' LIMIT 1];
System.debug('Sender: ' + sender.Address + ' | IsVerified: ' + sender.IsVerified);

FEC_Enhanced_Letterhead__c lh = [SELECT Id, FEC_Header__c, FEC_Footer__c FROM FEC_Enhanced_Letterhead__c WHERE Id = 'a0xAz000000jS4zIAE' LIMIT 1];
String body = (lh.FEC_Header__c != null ? lh.FEC_Header__c : '') + '<p>Test notification body</p>' + (lh.FEC_Footer__c != null ? lh.FEC_Footer__c : '');

Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new String[]{ 'tungnm.mpc@gmail.com' });
mail.setSubject('Test from FPT sender - ' + DateTime.now().format());
mail.setHtmlBody(body);
Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail }, false);
System.debug('success=' + results[0].isSuccess());
if (!results[0].isSuccess()) {
    for (Messaging.SendEmailError e : results[0].getErrors()) {
        System.debug('Error: ' + e.getMessage());
    }
}
