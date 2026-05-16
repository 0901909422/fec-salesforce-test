// Check FEC_Applicable_For_Mailbox__c values on templates
List<FEC_Template__c> templates = [
    SELECT Id, Name, FEC_Applicable_For_Mailbox__c
    FROM FEC_Template__c
    WHERE FEC_Active__c = true
    LIMIT 10
];
for (FEC_Template__c t : templates) {
    System.debug('Template: ' + t.Name + ' | Mailbox: ' + t.FEC_Applicable_For_Mailbox__c);
}

// Check what emails CC user group has in Outbound Email Config
Id userId = UserInfo.getUserId();
User u = [SELECT FEC_User_Group__c FROM User WHERE Id = :userId];
System.debug('User group: ' + u.FEC_User_Group__c);

List<SObject> cfgs = Database.query('SELECT FEC_Email__c FROM FEC_Outbound_Email_Config__c WHERE FEC_User_Group__c = :u.FEC_User_Group__c');
System.debug('Outbound emails for group: ' + cfgs.size());
for (SObject cfg : cfgs) System.debug('  ' + cfg.get('FEC_Email__c'));
