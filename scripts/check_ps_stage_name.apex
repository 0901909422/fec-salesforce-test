List<FieldPermissions> fps = [
    SELECT Parent.Name
    FROM FieldPermissions
    WHERE Field = 'FEC_Relevant_Ticket__c.FEC_Stage_Name__c'
    ORDER BY Parent.Name
];
System.debug('Total PS: ' + fps.size());
for (FieldPermissions fp : fps) {
    System.debug(fp.Parent.Name);
}
