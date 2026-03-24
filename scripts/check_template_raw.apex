List<EmailTemplate> templates = [
    SELECT Id, Name, HtmlValue, Body
    FROM EmailTemplate
    WHERE IsActive = true
    ORDER BY Name ASC
    LIMIT 5
];

for (EmailTemplate t : templates) {
    System.debug('=== ' + t.Name + ' ===');
    // In ra từng ký tự để xem encoding
    if (t.HtmlValue != null) {
        System.debug('HTML (500 chars): ' + t.HtmlValue.left(500));
    }
    if (t.Body != null) {
        System.debug('BODY (500 chars): ' + t.Body.left(500));
    }
}
