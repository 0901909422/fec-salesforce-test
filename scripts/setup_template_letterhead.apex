// Gán letterhead "Testing" cho template Email_Template_2 và Test Notification Template
EnhancedLetterhead lh = [SELECT Id, Name FROM EnhancedLetterhead WHERE Name = 'Testing' LIMIT 1];
System.debug('Using letterhead: ' + lh.Id + ' | ' + lh.Name);

// Update tất cả template active đang dùng cho notification
List<FEC_Template__c> templates = [
    SELECT Id, Name, FEC_Enhanced_Letterhead__c
    FROM FEC_Template__c
    WHERE Name IN ('Email_Template_2', 'Test Notification Template', 'Testing')
];
System.debug('Templates to update: ' + templates.size());
for (FEC_Template__c t : templates) {
    System.debug('Before: ' + t.Name + ' | Letterhead: ' + t.FEC_Enhanced_Letterhead__c);
    t.FEC_Enhanced_Letterhead__c = lh.Id;
}
update templates;
System.debug('Updated ' + templates.size() + ' templates with letterhead: ' + lh.Id);

// Verify
for (FEC_Template__c t : [SELECT Id, Name, FEC_Enhanced_Letterhead__c FROM FEC_Template__c WHERE Id IN :templates]) {
    System.debug('After: ' + t.Name + ' | Letterhead: ' + t.FEC_Enhanced_Letterhead__c);
}
