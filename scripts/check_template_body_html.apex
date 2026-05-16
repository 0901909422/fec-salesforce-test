// Check body content of template with subject "Thông báo từ FE Credit"
List<FEC_Template__c> templates = [
    SELECT Id, Name, FEC_Body__c, FEC_Subject_Line__c
    FROM FEC_Template__c
    WHERE FEC_Subject_Line__c = 'Thông báo từ FE Credit'
    LIMIT 3
];
if (templates.isEmpty()) {
    // Try all templates
    templates = [SELECT Id, Name, FEC_Body__c, FEC_Subject_Line__c FROM FEC_Template__c LIMIT 5];
}
for (FEC_Template__c t : templates) {
    System.debug('Template: ' + t.Name + ' | Subject: ' + t.FEC_Subject_Line__c);
    System.debug('Body (first 300): ' + (t.FEC_Body__c != null ? t.FEC_Body__c.left(300) : 'NULL'));
}
