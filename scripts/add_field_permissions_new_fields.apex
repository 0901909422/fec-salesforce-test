// tungnm37: Add field permissions cho 3 field mới vào tất cả Permission Sets
// FEC_Manual__c (FEC_Assignment__c), FEC_Submitted_On__c (FEC_Routing_Action_History__c), FEC_Select_Team__c (FEC_Team_Queue__c)

// 1. Lấy tất cả PS có access vào FEC_Assignment__c -> add FEC_Manual__c
Set<Id> assignmentPSIds = new Set<Id>();
for (FieldPermissions fp : [
    SELECT ParentId FROM FieldPermissions
    WHERE SobjectType = 'FEC_Assignment__c' AND Parent.IsOwnedByProfile = false
]) { assignmentPSIds.add(fp.ParentId); }

// 2. Lấy tất cả PS có access vào FEC_Routing_Action_History__c -> add FEC_Submitted_On__c
Set<Id> rahPSIds = new Set<Id>();
for (FieldPermissions fp : [
    SELECT ParentId FROM FieldPermissions
    WHERE SobjectType = 'FEC_Routing_Action_History__c' AND Parent.IsOwnedByProfile = false
]) { rahPSIds.add(fp.ParentId); }

// 3. Lấy tất cả PS có access vào FEC_Team_Queue__c -> add FEC_Select_Team__c
Set<Id> tqPSIds = new Set<Id>();
for (FieldPermissions fp : [
    SELECT ParentId FROM FieldPermissions
    WHERE SobjectType = 'FEC_Team_Queue__c' AND Parent.IsOwnedByProfile = false
]) { tqPSIds.add(fp.ParentId); }

// Check existing để tránh duplicate
Set<String> existingKeys = new Set<String>();
for (FieldPermissions fp : [
    SELECT ParentId, SobjectType, Field FROM FieldPermissions
    WHERE (SobjectType = 'FEC_Assignment__c' AND Field = 'FEC_Assignment__c.FEC_Manual__c')
       OR (SobjectType = 'FEC_Routing_Action_History__c' AND Field = 'FEC_Routing_Action_History__c.FEC_Submitted_On__c')
       OR (SobjectType = 'FEC_Team_Queue__c' AND Field = 'FEC_Team_Queue__c.FEC_Select_Team__c')
]) {
    existingKeys.add(fp.ParentId + '_' + fp.Field);
}

List<FieldPermissions> toInsert = new List<FieldPermissions>();

// FEC_Manual__c
for (Id psId : assignmentPSIds) {
    String key = psId + '_FEC_Assignment__c.FEC_Manual__c';
    if (!existingKeys.contains(key)) {
        toInsert.add(new FieldPermissions(
            ParentId = psId,
            SobjectType = 'FEC_Assignment__c',
            Field = 'FEC_Assignment__c.FEC_Manual__c',
            PermissionsRead = true,
            PermissionsEdit = true
        ));
    }
}

// FEC_Submitted_On__c
for (Id psId : rahPSIds) {
    String key = psId + '_FEC_Routing_Action_History__c.FEC_Submitted_On__c';
    if (!existingKeys.contains(key)) {
        toInsert.add(new FieldPermissions(
            ParentId = psId,
            SobjectType = 'FEC_Routing_Action_History__c',
            Field = 'FEC_Routing_Action_History__c.FEC_Submitted_On__c',
            PermissionsRead = true,
            PermissionsEdit = true
        ));
    }
}

// FEC_Select_Team__c
for (Id psId : tqPSIds) {
    String key = psId + '_FEC_Team_Queue__c.FEC_Select_Team__c';
    if (!existingKeys.contains(key)) {
        toInsert.add(new FieldPermissions(
            ParentId = psId,
            SobjectType = 'FEC_Team_Queue__c',
            Field = 'FEC_Team_Queue__c.FEC_Select_Team__c',
            PermissionsRead = true,
            PermissionsEdit = true
        ));
    }
}

System.debug('Total FieldPermissions to insert: ' + toInsert.size());
if (!toInsert.isEmpty()) {
    Database.insert(toInsert, false); // allOrNone=false để bỏ qua lỗi duplicate
    System.debug('Inserted successfully');
}
