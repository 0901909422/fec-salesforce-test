// Debug getFromAddresses
// 1. Check EmailRoutingAddress
List<SObject> routingAddrs = Database.query(
    'SELECT Id, Address, PersonalName FROM EmailRoutingAddress ORDER BY PersonalName ASC LIMIT 50'
);
System.debug('=== EmailRoutingAddress count: ' + routingAddrs.size());
for (SObject r : routingAddrs) {
    System.debug('  Routing: ' + r.get('Address') + ' | ' + r.get('PersonalName'));
}

// 2. Check OrgWideEmailAddress
List<OrgWideEmailAddress> owas = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress];
System.debug('=== OrgWideEmailAddress count: ' + owas.size());
for (OrgWideEmailAddress o : owas) {
    System.debug('  OWA: ' + o.Address + ' | ' + o.DisplayName);
}

// 3. Check Case owner (dùng case ID thực tế)
List<Case> cases = [SELECT Id, CaseNumber, OwnerId, Owner.Type, Owner.Name FROM Case ORDER BY CreatedDate DESC LIMIT 5];
for (Case c : cases) {
    System.debug('Case ' + c.CaseNumber + ' OwnerId=' + c.OwnerId + ' OwnerType=' + c.Owner.Type + ' OwnerName=' + c.Owner.Name);
}
