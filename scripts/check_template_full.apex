// Check tất cả fields của FEC_Template__c
Map<String, Schema.SObjectField> fields = Schema.SObjectType.FEC_Template__c.fields.getMap();
System.debug('=== FEC_Template__c fields ===');
for (String f : fields.keySet()) {
    Schema.DescribeFieldResult d = fields.get(f).getDescribe();
    System.debug(d.getName() + ' | ' + d.getType() + ' | ' + d.getLabel());
}

// Lấy tất cả template active
List<FEC_Template__c> templates = [
    SELECT Id, Name, FEC_Template_Name__c, FEC_Subject_Line__c, FEC_Body__c,
           FEC_Active__c, FEC_Enhanced_Letterhead__c, FEC_Folder__c
    FROM FEC_Template__c
    WHERE FEC_Active__c = true
    LIMIT 5
];
System.debug('=== Active Templates ===');
for (FEC_Template__c t : templates) {
    System.debug('Template: ' + t.Name + ' | Letterhead: ' + t.FEC_Enhanced_Letterhead__c + ' | Folder: ' + t.FEC_Folder__c);
    System.debug('  Body length: ' + (t.FEC_Body__c != null ? t.FEC_Body__c.length() : 0));
    System.debug('  Body preview: ' + (t.FEC_Body__c != null ? t.FEC_Body__c.substring(0, Math.min(200, t.FEC_Body__c.length())) : 'null'));
}

// Check ContentDocumentLink liên kết với FEC_Template__c
List<ContentDocumentLink> cdls = [
    SELECT ContentDocumentId, LinkedEntityId, ContentDocument.Title, ContentDocument.FileType
    FROM ContentDocumentLink
    WHERE LinkedEntityId IN (SELECT Id FROM FEC_Template__c WHERE FEC_Active__c = true)
    LIMIT 10
];
System.debug('=== Files linked to Templates ===');
System.debug('Total: ' + cdls.size());
for (ContentDocumentLink cdl : cdls) {
    System.debug('File: ' + cdl.ContentDocument.Title + ' | Type: ' + cdl.ContentDocument.FileType + ' | LinkedTo: ' + cdl.LinkedEntityId);
}
