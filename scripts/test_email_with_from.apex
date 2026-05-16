// Test với OrgWideEmailAddress
List<OrgWideEmailAddress> owas = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress LIMIT 10];
System.debug('OrgWide addresses: ' + owas.size());
for (OrgWideEmailAddress o : owas) {
    System.debug('OWA: ' + o.DisplayName + ' <' + o.Address + '> id=' + o.Id);
}

Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new List<String>{ 'minhtung2108@gmail.com' });
mail.setSubject('Test With OWA - ' + Datetime.now().format('HH:mm:ss'));
mail.setPlainTextBody('Test email with OrgWideEmailAddress');
mail.setSaveAsActivity(false);

// Set OWA nếu có
if (!owas.isEmpty()) {
    mail.setOrgWideEmailAddressId(owas[0].Id);
    System.debug('Using OWA: ' + owas[0].Address);
}

List<Messaging.SendEmailResult> results = Messaging.sendEmail(
    new List<Messaging.SingleEmailMessage>{ mail }, false
);
for (Messaging.SendEmailResult r : results) {
    if (r.isSuccess()) {
        System.debug('SUCCESS');
    } else {
        for (Messaging.SendEmailError e : r.getErrors()) {
            System.debug('ERROR: ' + e.getStatusCode() + ' - ' + e.getMessage());
        }
    }
}
