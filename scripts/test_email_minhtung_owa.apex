// Dùng OWA minhtung2108@gmail.com làm From
OrgWideEmailAddress owa = [SELECT Id, Address FROM OrgWideEmailAddress WHERE Address = 'minhtung2108@gmail.com' LIMIT 1];
System.debug('Using OWA: ' + owa.Address);

Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new List<String>{ 'minhtung2108@gmail.com' });
mail.setOrgWideEmailAddressId(owa.Id);
mail.setSubject('Test OWA - ' + Datetime.now().format('HH:mm:ss'));
mail.setPlainTextBody('Test email dùng OWA minhtung2108@gmail.com làm From');
mail.setSaveAsActivity(false);

List<Messaging.SendEmailResult> results = Messaging.sendEmail(
    new List<Messaging.SingleEmailMessage>{ mail }, false
);
for (Messaging.SendEmailResult r : results) {
    if (r.isSuccess()) {
        System.debug('SUCCESS - check Gmail!');
    } else {
        for (Messaging.SendEmailError e : r.getErrors()) {
            System.debug('ERROR: ' + e.getStatusCode() + ' - ' + e.getMessage());
        }
    }
}
