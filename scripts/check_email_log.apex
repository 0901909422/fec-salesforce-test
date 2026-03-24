// Check EmailMessage vừa gửi từ UI
List<EmailMessage> recent = [
    SELECT Id, Subject, ToAddress, FromAddress, FromName, Status, 
           MessageDate, IsExternallyVisible, BccAddress
    FROM EmailMessage
    ORDER BY CreatedDate DESC LIMIT 3
];
for (EmailMessage em : recent) {
    System.debug('Subject: ' + em.Subject);
    System.debug('  From: ' + em.FromAddress + ' (' + em.FromName + ')');
    System.debug('  To: ' + em.ToAddress);
    System.debug('  Status: ' + em.Status + ' | ExternallyVisible: ' + em.IsExternallyVisible);
}

// Check OrgWideEmailAddress đã verify chưa
List<OrgWideEmailAddress> orgEmails = [
    SELECT Id, Address, DisplayName, IsAllowAllProfiles 
    FROM OrgWideEmailAddress
];
System.debug('OrgWideEmailAddress count: ' + orgEmails.size());
for (OrgWideEmailAddress o : orgEmails) {
    System.debug('  OrgWide: ' + o.Address + ' | AllProfiles: ' + o.IsAllowAllProfiles);
}
