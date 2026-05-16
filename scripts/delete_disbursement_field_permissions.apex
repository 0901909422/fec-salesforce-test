// Xóa các FieldPermissions vừa insert cho FEC_Disbursement_Date__c và FEC_Disbursement_Status__c
List<FieldPermissions> toDelete = [
    SELECT Id FROM FieldPermissions
    WHERE SobjectType = 'Case'
      AND Field IN ('Case.FEC_Disbursement_Date__c', 'Case.FEC_Disbursement_Status__c')
      AND Parent.IsOwnedByProfile = false
];
System.debug('Deleting: ' + toDelete.size());
if (!toDelete.isEmpty()) delete toDelete;
System.debug('Done');
