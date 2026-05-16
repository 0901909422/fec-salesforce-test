// Check permission sets có field permissions cho FEC_Assignment__c và FEC_Routing_Action_History__c

// 1. Permission sets có FEC_Assignment__c field permissions
List<FieldPermissions> assignmentFPs = [
    SELECT Id, SobjectType, Field, PermissionsRead, PermissionsEdit,
           Parent.Name, Parent.Label
    FROM FieldPermissions
    WHERE SobjectType = 'FEC_Assignment__c'
      AND Parent.IsOwnedByProfile = false
    ORDER BY Parent.Name
    LIMIT 20
];
Set<String> assignmentPS = new Set<String>();
for (FieldPermissions fp : assignmentFPs) {
    assignmentPS.add(fp.Parent.Name + ' | ' + fp.Parent.Label);
}
System.debug('=== Permission Sets with FEC_Assignment__c access ===');
for (String ps : assignmentPS) { System.debug(ps); }

// 2. Permission sets có FEC_Routing_Action_History__c field permissions
List<FieldPermissions> rahFPs = [
    SELECT Id, SobjectType, Field, PermissionsRead, PermissionsEdit,
           Parent.Name, Parent.Label
    FROM FieldPermissions
    WHERE SobjectType = 'FEC_Routing_Action_History__c'
      AND Parent.IsOwnedByProfile = false
    ORDER BY Parent.Name
    LIMIT 20
];
Set<String> rahPS = new Set<String>();
for (FieldPermissions fp : rahFPs) {
    rahPS.add(fp.Parent.Name + ' | ' + fp.Parent.Label);
}
System.debug('=== Permission Sets with FEC_Routing_Action_History__c access ===');
for (String ps : rahPS) { System.debug(ps); }

// 3. Permission sets có FEC_Team_Queue__c field permissions
List<FieldPermissions> tqFPs = [
    SELECT Id, SobjectType, Field, PermissionsRead, PermissionsEdit,
           Parent.Name, Parent.Label
    FROM FieldPermissions
    WHERE SobjectType = 'FEC_Team_Queue__c'
      AND Parent.IsOwnedByProfile = false
    ORDER BY Parent.Name
    LIMIT 20
];
Set<String> tqPS = new Set<String>();
for (FieldPermissions fp : tqFPs) {
    tqPS.add(fp.Parent.Name + ' | ' + fp.Parent.Label);
}
System.debug('=== Permission Sets with FEC_Team_Queue__c access ===');
for (String ps : tqPS) { System.debug(ps); }
