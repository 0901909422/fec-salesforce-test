List<OrgWideEmailAddress> addrs = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress LIMIT 10];
for (OrgWideEmailAddress a : addrs) {
    System.debug('OrgWide: ' + a.DisplayName + ' <' + a.Address + '> Id=' + a.Id);
}
