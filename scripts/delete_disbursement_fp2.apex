List<FieldPermissions> toDelete = [
    SELECT Id FROM FieldPermissions
    WHERE SobjectType = 'Case'
      AND Field IN ('Case.FEC_Disbursement_Date__c', 'Case.FEC_Disbursement_Status__c')
      AND Parent.IsOwnedByProfile = false
    LIMIT 200
];
System.debug('Deleting: ' + toDelete.size());
Database.delete(toDelete, false);
System.debug('Done');
