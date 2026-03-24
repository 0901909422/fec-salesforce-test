// Test gửi đến minhtung2108@gmail.com
String caseId = [SELECT Id FROM Case ORDER BY CreatedDate DESC LIMIT 1].Id;
System.debug('Testing with caseId: ' + caseId);

try {
    FEC_CustomEmailService.sendEmail(
        caseId,
        'tungnm37@fpt.com',
        'minhtung2108@gmail.com',
        null,
        'Test FEC Email ' + DateTime.now(),
        '<p>Xin chào,</p><p>Đây là email test từ FEC Custom Email Service.</p><p>Trân trọng.</p>',
        null
    );
    System.debug('✅ Email sent successfully to minhtung2108@gmail.com!');
} catch (Exception e) {
    System.debug('❌ Error: ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}
