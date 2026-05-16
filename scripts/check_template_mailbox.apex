List<FEC_Template__c> ts = [SELECT Id, Name, FEC_Active__c, FEC_Applicable_For_Mailbox__c FROM FEC_Template__c WHERE FEC_Active__c = true LIMIT 10];
for (FEC_Template__c t : ts) {
    System.debug('Template: ' + t.Name + ' | Mailbox: ' + t.FEC_Applicable_For_Mailbox__c);
}

// Check getEmailTemplatesByMailbox method
System.debug('Current user email: ' + UserInfo.getUserEmail());
