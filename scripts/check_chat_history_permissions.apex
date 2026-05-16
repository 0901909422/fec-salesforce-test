// Check which PermissionSets have FEC_Chat_History__c field permission
List<FieldPermissions> fps = [
    SELECT Id, Field, PermissionsEdit, PermissionsRead, Parent.Name, Parent.IsCustom
    FROM FieldPermissions
    WHERE Field = 'Case.FEC_Chat_History__c'
    ORDER BY Parent.Name
];
System.debug('Total: ' + fps.size());
for (FieldPermissions fp : fps) {
    System.debug('PS: ' + fp.Parent.Name + ' | Read: ' + fp.PermissionsRead + ' | Edit: ' + fp.PermissionsEdit);
}
