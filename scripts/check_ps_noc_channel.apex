List<FieldPermissions> fps = [
    SELECT Parent.Name
    FROM FieldPermissions
    WHERE Field = 'FEC_Nature_of_Case__c.FEC_Channel__c'
    ORDER BY Parent.Name
];
System.debug('Total: ' + fps.size());
for (FieldPermissions fp : fps) System.debug(fp.Parent.Name);
