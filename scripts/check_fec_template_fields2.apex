// Check tất cả fields của FEC_Template__c
Map<String, Schema.SObjectField> fields = Schema.SObjectType.FEC_Template__c.fields.getMap();
for (String f : fields.keySet()) {
    Schema.DescribeFieldResult d = fields.get(f).getDescribe();
    System.debug(d.getName() + ' | ' + d.getType() + ' | ' + d.getLabel());
}

// Lấy record template đang dùng
FEC_Template__c t = [SELECT Id, Name, FEC_Subject_Line__c, FEC_Body__c, FEC_Active__c FROM FEC_Template__c WHERE Id = 'a10Az00000GDO05IAH' LIMIT 1];
System.debug('Template: ' + t.Name + ' | Subject: ' + t.FEC_Subject_Line__c);
System.debug('Body length: ' + (t.FEC_Body__c != null ? t.FEC_Body__c.length() : 0));
