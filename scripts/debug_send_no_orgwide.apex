// Test gửi email từ current user (không dùng OrgWide)
String caseId = '500Az00000MwdfTIAR';

Case c = [SELECT Id, Status, Subject FROM Case WHERE Id = :caseId LIMIT 1];
System.debug('Case: ' + c.Subject + ' | Status: ' + c.Status);

User me = [SELECT Id, Name, Email FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
System.debug('Current user: ' + me.Name + ' <' + me.Email + '>');

Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new List<String>{ 'minhtung2108@gmail.com' });
mail.setSubject('Test FEC - from current user - ' + DateTime.now().format());
mail.setHtmlBody('<p>Test email gửi từ current user (không OrgWide).</p><p>From: ' + me.Email + '</p>');
mail.setWhatId(caseId);
mail.setSaveAsActivity(true);
// Không set OrgWideEmailAddressId → gửi từ current user

try {
    List<Messaging.SendEmailResult> results = Messaging.sendEmail(
        new List<Messaging.SingleEmailMessage>{ mail }
    );
    for (Messaging.SendEmailResult r : results) {
        System.debug('Success: ' + r.isSuccess());
        if (!r.isSuccess()) {
            for (Messaging.SendEmailError e : r.getErrors()) {
                System.debug('Error: ' + e.getStatusCode() + ' - ' + e.getMessage());
            }
        }
    }
} catch (Exception e) {
    System.debug('EXCEPTION: ' + e.getTypeName() + ': ' + e.getMessage());
}
