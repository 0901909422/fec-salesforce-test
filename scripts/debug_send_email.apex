// Debug: thử gửi email trực tiếp qua Apex không qua UI
// Thay caseId bằng Id thực tế của case bạn đang test
String caseId = '500Az00000MwdfTIAR';

// 1. Kiểm tra case tồn tại và status
Case c = [SELECT Id, Status, Subject FROM Case WHERE Id = :caseId LIMIT 1];
System.debug('Case: ' + c.Subject + ' | Status: ' + c.Status);

// 2. Lấy OrgWideEmailAddress
List<OrgWideEmailAddress> owas = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress LIMIT 5];
System.debug('OrgWide count: ' + owas.size());
for (OrgWideEmailAddress o : owas) {
    System.debug('  OrgWide: ' + o.DisplayName + ' <' + o.Address + '> | Id: ' + o.Id);
}

// 3. Thử gửi email
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new List<String>{ 'minhtung2108@gmail.com' });
mail.setSubject('Test FEC Email - ' + DateTime.now().format());
mail.setHtmlBody('<p>Test email từ Salesforce sandbox.</p><p>Case: ' + c.Subject + '</p>');
mail.setWhatId(caseId);
mail.setSaveAsActivity(true);

if (!owas.isEmpty()) {
    mail.setOrgWideEmailAddressId(owas[0].Id);
    System.debug('Sending from OrgWide: ' + owas[0].Address);
} else {
    System.debug('No OrgWide - sending from current user');
}

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
    System.debug('Stack: ' + e.getStackTraceString());
}
