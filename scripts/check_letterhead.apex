// Check EnhancedLetterhead fields
Map<String, Schema.SObjectField> fields = Schema.SObjectType.EnhancedLetterhead.fields.getMap();
for (String f : fields.keySet()) {
    Schema.DescribeFieldResult d = fields.get(f).getDescribe();
    System.debug(d.getName() + ' | ' + d.getType());
}

// Lấy letterhead của template
FEC_Template__c t = [SELECT Id, FEC_Enhanced_Letterhead__c FROM FEC_Template__c WHERE Id = 'a10Az00000GDO05IAH' LIMIT 1];
System.debug('Letterhead Id: ' + t.FEC_Enhanced_Letterhead__c);

if (t.FEC_Enhanced_Letterhead__c != null) {
    EnhancedLetterhead lh = [SELECT Id, Name, Header, Footer FROM EnhancedLetterhead WHERE Id = :t.FEC_Enhanced_Letterhead__c LIMIT 1];
    System.debug('Letterhead: ' + lh.Name);
    System.debug('Header length: ' + (lh.Header != null ? lh.Header.length() : 0));
    System.debug('Footer length: ' + (lh.Footer != null ? lh.Footer.length() : 0));
}
