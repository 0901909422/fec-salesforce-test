// Check FEC_Template__c fields liên quan đến group/role/mailbox
Map<String, Schema.SObjectField> fields = Schema.SObjectType.FEC_Template__c.fields.getMap();
List<String> relevant = new List<String>();
for (String f : fields.keySet()) {
    String fl = f.toLowerCase();
    if (fl.contains('group') || fl.contains('role') || fl.contains('queue') || fl.contains('mailbox') || fl.contains('folder') || fl.contains('profile')) {
        relevant.add(f + ' (' + fields.get(f).getDescribe().getType() + ')');
    }
}
System.debug('Relevant fields: ' + relevant);

// Query 1 template để xem giá trị
List<FEC_Template__c> ts = [SELECT Id, Name, FEC_Active__c FROM FEC_Template__c LIMIT 1];
System.debug('Sample template: ' + ts);
