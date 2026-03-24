// Check EmailMessage status chi tiết - 5 cái mới nhất
List<EmailMessage> recent = [
    SELECT Id, Subject, ToAddress, FromAddress, Status, MessageDate, IsExternallyVisible, Incoming
    FROM EmailMessage
    ORDER BY CreatedDate DESC LIMIT 5
];
for (EmailMessage em : recent) {
    String statusLabel = '';
    if (em.Status == '0') statusLabel = 'New/Not Sent';
    else if (em.Status == '1') statusLabel = 'Read';
    else if (em.Status == '2') statusLabel = 'Replied';
    else if (em.Status == '3') statusLabel = 'Sent';
    else statusLabel = 'Other(' + em.Status + ')';
    System.debug('Subject: ' + em.Subject);
    System.debug('  To: ' + em.ToAddress + ' | From: ' + em.FromAddress);
    System.debug('  Status: ' + statusLabel + ' | Incoming: ' + em.Incoming);
    System.debug('  ExternallyVisible: ' + em.IsExternallyVisible + ' | Date: ' + em.MessageDate);
    System.debug('---');
}
