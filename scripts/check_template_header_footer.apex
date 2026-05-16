// Check template có header/footer không
List<FEC_Template__c> templates = [
    SELECT Id, Name, FEC_Subject_Line__c, FEC_Enhanced_Letterhead__c,
           FEC_Enhanced_Letterhead__r.FEC_Header__c, FEC_Enhanced_Letterhead__r.FEC_Footer__c
    FROM FEC_Template__c
    WHERE FEC_Active__c = true
    LIMIT 10
];
for (FEC_Template__c t : templates) {
    System.debug('Template: ' + t.Name
        + ' | HasLetterhead: ' + (t.FEC_Enhanced_Letterhead__c != null)
        + ' | HeaderLen: ' + (t.FEC_Enhanced_Letterhead__r?.FEC_Header__c != null ? t.FEC_Enhanced_Letterhead__r.FEC_Header__c.length() : 0)
        + ' | FooterLen: ' + (t.FEC_Enhanced_Letterhead__r?.FEC_Footer__c != null ? t.FEC_Enhanced_Letterhead__r.FEC_Footer__c.length() : 0));
}
