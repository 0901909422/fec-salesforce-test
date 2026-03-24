// Check EmailRoutingAddress data
List<SObject> rows = Database.query(
    'SELECT Id, Address, PersonalName FROM EmailRoutingAddress ORDER BY PersonalName ASC LIMIT 20'
);
System.debug('EmailRoutingAddress count: ' + rows.size());
for (SObject r : rows) {
    System.debug('  PersonalName: ' + r.get('PersonalName') + ' | Address: ' + r.get('Address'));
}

// Check OrgWideEmailAddress
List<OrgWideEmailAddress> owas = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress ORDER BY DisplayName ASC];
System.debug('OrgWideEmailAddress count: ' + owas.size());
for (OrgWideEmailAddress o : owas) {
    System.debug('  DisplayName: ' + o.DisplayName + ' | Address: ' + o.Address);
}
