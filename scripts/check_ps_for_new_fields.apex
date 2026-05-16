// Check permission sets có field permissions cho 5 field mới
Set<String> targetFields = new Set<String>{
    'FEC_Assignment__c.FEC_Manual__c',
    'FEC_Routing_Action_History__c.FEC_Submitted_On__c',
    'FEC_Team_Queue__c.FEC_Select_Team__c',
    'Case.FEC_Disbursement_Date__c',
    'Case.FEC_Disbursement_Status__c'
};

List<FieldPermissions> fps = [
    SELECT Id, SobjectType, Field, PermissionsRead, PermissionsEdit,
           Parent.Name, Parent.IsCustom
    FROM FieldPermissions
    WHERE Field IN :targetFields
    ORDER BY Field, Parent.Name
];

String currentField = '';
for (FieldPermissions fp : fps) {
    if (fp.Field != currentField) {
        System.debug('=== ' + fp.Field + ' ===');
        currentField = fp.Field;
    }
    System.debug('  PS: ' + fp.Parent.Name + ' | Read=' + fp.PermissionsRead + ' | Edit=' + fp.PermissionsEdit);
}
System.debug('Total: ' + fps.size() + ' records');
