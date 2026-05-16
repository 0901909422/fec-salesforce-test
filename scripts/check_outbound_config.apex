// Check FEC_Outbound_Email_Config__c records
List<SObject> configs = Database.query('SELECT Id, FEC_Email__c, FEC_User_Group__c FROM FEC_Outbound_Email_Config__c ORDER BY FEC_Email__c');
System.debug('Total configs: ' + configs.size());
for (SObject c : configs) {
    System.debug('Email: ' + c.get('FEC_Email__c') + ' | UserGroup: ' + c.get('FEC_User_Group__c'));
}
