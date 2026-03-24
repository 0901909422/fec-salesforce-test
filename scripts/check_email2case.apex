// Check Email-to-Case routing addresses
List<EmailServicesAddress> esa = [
    SELECT Id, LocalPart, EmailDomainName, IsActive
    FROM EmailServicesAddress
    WHERE IsActive = true
    LIMIT 20
];
System.debug('EmailServicesAddress: ' + esa.size());
for (EmailServicesAddress e : esa) {
    System.debug('  ' + e.LocalPart + '@' + e.EmailDomainName);
}

// Check EmailRoutingAddress (Email-to-Case)
List<SObject> routing = Database.query(
    'SELECT Id, Name, EmailAddress, IsVerified FROM EmailRoutingAddress ORDER BY Name ASC LIMIT 20'
);
System.debug('EmailRoutingAddress: ' + routing.size());
for (SObject r : routing) {
    System.debug('  Name: ' + r.get('Name') + ' | Email: ' + r.get('EmailAddress') + ' | Verified: ' + r.get('IsVerified'));
}
