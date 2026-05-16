// Test inlineImages với session hiện tại (anonymous context có session hợp lệ)
FEC_Enhanced_Letterhead__c lh = [SELECT Id, FEC_Header__c FROM FEC_Enhanced_Letterhead__c WHERE Id = 'a0xAz000000jS4zIAE' LIMIT 1];

String sid = UserInfo.getSessionId();
System.debug('Session null: ' + (sid == null));
System.debug('Session length: ' + (sid != null ? sid.length() : 0));

String result = FEC_NotificationService.inlineImages(lh.FEC_Header__c, sid);
System.debug('Contains base64: ' + result.contains('data:image'));
System.debug('Result snippet: ' + result.left(100));

// Nếu inline thành công thì gửi email test
if (result.contains('data:image')) {
    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setToAddresses(new String[]{ 'tungnm.mpc@gmail.com', 'tungnm37@fpt.com' });
    mail.setSubject('Test inline base64 image - ' + DateTime.now().format());
    mail.setHtmlBody(result + '<p>Body test</p>');
    Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail }, false);
    System.debug('Email sent with base64 image');
} else {
    System.debug('inlineImages FAILED - image not converted to base64');
}
