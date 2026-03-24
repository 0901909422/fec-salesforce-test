Case c = [SELECT Id, FEC_Interaction_Email__c, Subject FROM Case WHERE FEC_Channel__c = 'Email' ORDER BY CreatedDate DESC LIMIT 1];
System.debug('FEC_Interaction_Email__c: ' + c.FEC_Interaction_Email__c);
System.debug('Subject: ' + c.Subject);

List<EmailMessage> msgs = [SELECT Id, FromAddress, ToAddress, Subject FROM EmailMessage WHERE ParentId = :c.Id ORDER BY MessageDate DESC LIMIT 1];
if (!msgs.isEmpty()) {
    System.debug('EmailMsg FromAddress: ' + msgs[0].FromAddress);
    System.debug('EmailMsg ToAddress: ' + msgs[0].ToAddress);
}
