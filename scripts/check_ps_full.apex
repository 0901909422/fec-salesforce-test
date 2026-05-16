// Lấy tất cả Permission Sets có access vào 3 objects liên quan
Set<String> allPS = new Set<String>();

for (FieldPermissions fp : [
    SELECT Parent.Name, Parent.Label FROM FieldPermissions
    WHERE SobjectType IN ('FEC_Assignment__c', 'FEC_Routing_Action_History__c', 'FEC_Team_Queue__c')
      AND Parent.IsOwnedByProfile = false
    ORDER BY Parent.Name
]) {
    allPS.add(fp.Parent.Name);
}

System.debug('Total PS: ' + allPS.size());
List<String> sorted = new List<String>(allPS);
sorted.sort();
for (String ps : sorted) {
    System.debug(ps);
}
