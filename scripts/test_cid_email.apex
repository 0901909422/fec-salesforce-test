// Test CID approach trực tiếp
FEC_Enhanced_Letterhead__c lh = [SELECT Id, FEC_Header__c, FEC_Footer__c FROM FEC_Enhanced_Letterhead__c WHERE Id = 'a0xAz000000jS4zIAE' LIMIT 1];
String html = lh.FEC_Header__c + '<p>testing body</p>' + (lh.FEC_Footer__c != null ? lh.FEC_Footer__c : '');

FEC_InlineImageUtil.InlineImageResult prepared = FEC_InlineImageUtil.convertRtaImagesToCid(html);

System.debug('htmlBody contains cid: ' + prepared.htmlBody.contains('cid:'));
System.debug('attachments count: ' + prepared.attachments.size());
System.debug('htmlBody snippet: ' + prepared.htmlBody.left(300));

if (prepared.attachments.size() > 0) {
    // Gửi test email
    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setToAddresses(new String[]{ 'tungnm.mpc@gmail.com' });
    mail.setSubject('Test CID inline image');
    mail.setHtmlBody(prepared.htmlBody);
    mail.setFileAttachments(prepared.attachments);
    Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
    System.debug('Email sent with ' + prepared.attachments.size() + ' CID attachments');
} else {
    System.debug('No attachments - fetch failed, check logs above');
}
