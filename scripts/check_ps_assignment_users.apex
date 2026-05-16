// Check PS nào có Case.FEC_Assignment_Users__c
Integer cnt = [SELECT COUNT() FROM FieldPermissions WHERE Field = 'Case.FEC_Assignment_Users__c'];
System.debug('FEC_Assignment_Users__c PS count: ' + cnt);

// Lấy PS nào có Case fields tương tự (Interaction/Service Case)
List<FieldPermissions> fps = [
    SELECT Parent.Name FROM FieldPermissions
    WHERE Field = 'Case.FEC_Assignment_Users__c'
    ORDER BY Parent.Name LIMIT 5
];
for (FieldPermissions fp : fps) System.debug(fp.Parent.Name);

// Check PS nào có Case.FEC_Disbursement_Status__c để biết bộ PS cần add
List<FieldPermissions> disbFps = [
    SELECT Parent.Name FROM FieldPermissions
    WHERE Field = 'Case.FEC_Disbursement_Status__c'
    ORDER BY Parent.Name LIMIT 5
];
System.debug('Disbursement PS sample:');
for (FieldPermissions fp : disbFps) System.debug('  ' + fp.Parent.Name);
