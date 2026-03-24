List<EmailTemplate> templates = [
    SELECT Id, Name, IsActive, HtmlValue, Body
    FROM EmailTemplate
    WHERE IsActive = true
    ORDER BY Name ASC
    LIMIT 20
];

System.debug('=== Active Email Templates ===');
for (EmailTemplate t : templates) {
    System.debug('Name: ' + t.Name + ' | Id: ' + t.Id);
    System.debug('HtmlValue (first 200): ' + (t.HtmlValue != null ? t.HtmlValue.left(200) : 'NULL'));
    System.debug('Body (first 200): ' + (t.Body != null ? t.Body.left(200) : 'NULL'));
    System.debug('---');
}
System.debug('Total: ' + templates.size());
