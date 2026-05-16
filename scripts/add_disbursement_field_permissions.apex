// tungnm37: Add field permissions cho FEC_Disbursement_Date__c và FEC_Disbursement_Status__c (Case)
// vào tất cả PS đang có Case field permissions

Set<Id> casePSIds = new Set<Id>();
for (FieldPermissions fp : [
    SELECT ParentId FROM FieldPermissions
    WHERE SobjectType = 'Case' AND Parent.IsOwnedByProfile = false
]) { casePSIds.add(fp.ParentId); }

System.debug('Total PS with Case access: ' + casePSIds.size());

// Check existing
Set<String> existing = new Set<String>();
for (FieldPermissions fp : [
    SELECT ParentId, Field FROM FieldPermissions
    WHERE SobjectType = 'Case'
      AND Field IN ('Case.FEC_Disbursement_Date__c', 'Case.FEC_Disbursement_Status__c')
]) { existing.add(fp.ParentId + '_' + fp.Field); }

List<FieldPermissions> toInsert = new List<FieldPermissions>();
for (Id psId : casePSIds) {
    if (!existing.contains(psId + '_Case.FEC_Disbursement_Date__c')) {
        toInsert.add(new FieldPermissions(ParentId=psId, SobjectType='Case', Field='Case.FEC_Disbursement_Date__c', PermissionsRead=true, PermissionsEdit=true));
    }
    if (!existing.contains(psId + '_Case.FEC_Disbursement_Status__c')) {
        toInsert.add(new FieldPermissions(ParentId=psId, SobjectType='Case', Field='Case.FEC_Disbursement_Status__c', PermissionsRead=true, PermissionsEdit=true));
    }
}
System.debug('Inserting: ' + toInsert.size());
if (!toInsert.isEmpty()) Database.insert(toInsert, false);
System.debug('Done');
