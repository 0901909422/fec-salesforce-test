// ============================================================
// Full flow test: COF/GSR với CC + CO team (Card/Feedback/FC01/FC01.07)
// Simulate submit Route to → check Assignment được tạo đúng
// ============================================================

// 1. Lấy NOC của bộ này
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, FEC_Business_Process__r.FEC_Code__c,
           FEC_Product_Type__r.Name, FEC_Category__r.Name,
           FEC_Sub_Category__r.Name, FEC_Sub_Code__r.Name
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Sub_Code__r.FEC_Code__c = 'FC01.07'
    LIMIT 1
];
if (nocs.isEmpty()) { System.debug('NOC FC01.07 not found'); return; }
FEC_Nature_of_Case__c noc = nocs[0];
System.debug('NOC: ' + noc.Id + ' | BP: ' + noc.FEC_Business_Process__r?.FEC_Code__c);

// 2. Check FEC_Routing_Assignment__c cho NOC này
List<FEC_Routing_Assignment__c> ras = [
    SELECT FEC_Team__c, FEC_Queue__c, FEC_Active__c
    FROM FEC_Routing_Assignment__c
    WHERE FEC_Nature_of_Cases__c = :noc.Id
    ORDER BY FEC_Team__c
];
System.debug('=== ROUTING RULES ===');
for (FEC_Routing_Assignment__c ra : ras) {
    System.debug('  Team=' + ra.FEC_Team__c + ' | Queue=' + ra.FEC_Queue__c + ' | Active=' + ra.FEC_Active__c);
}

// 3. Check hasNonCcSpTeam
Boolean hasNonCcSp = FEC_CofGsrAssignmentService.hasNonCcSpTeam(new Set<Id>{ noc.Id });
System.debug('hasNonCcSpTeam = ' + hasNonCcSp);

// 4. Lấy Case S-2564 để test
List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Stage_Name__c
    FROM Case WHERE FEC_ID_Search__c = 'S-2566' LIMIT 1
];
if (cases.isEmpty()) { System.debug('S-2564 not found'); return; }
Case c = cases[0];
System.debug('Case: ' + c.FEC_ID_Search__c + ' | Stage: ' + c.FEC_Stage_Name__c);

// 5. Count assignments trước
Integer beforeCount = [SELECT COUNT() FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id];
System.debug('Assignments BEFORE: ' + beforeCount);

// 6. Gọi createAssignmentsOnRoute (simulate Route to)
User currentUser = [SELECT Email, UserRole.Name, Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
Set<Id> nocIds = new Set<Id>{ noc.Id };

if (hasNonCcSp) {
    System.debug('→ Calling createAssignmentsOnRoute...');
    FEC_CofGsrAssignmentService.createAssignmentsOnRoute(c.Id, nocIds, currentUser, null, c.FEC_Stage_Name__c, 'Test remark');
} else {
    System.debug('→ SKIP (chỉ có CC/SP - luồng thủ công)');
}

// 7. Verify kết quả
List<FEC_Assignment__c> assignments = [
    SELECT Id, Name, FEC_Assignment_Type__c, FEC_Team__c, FEC_OwnerID__c,
           FEC_Assignment_Owner__c, FEC_Manual__c, CreatedDate
    FROM FEC_Assignment__c
    WHERE FEC_Case__c = :c.Id
    ORDER BY CreatedDate DESC
    LIMIT 10
];
System.debug('=== ASSIGNMENTS AFTER (' + assignments.size() + ') ===');
for (FEC_Assignment__c a : assignments) {
    System.debug('  ' + a.Name + ' | Team=' + a.FEC_Team__c + ' | OwnerID=' + a.FEC_OwnerID__c + ' | Manual=' + a.FEC_Manual__c);
}

// 8. Check Case.FEC_Assignment_Users__c
List<Case> caseAfter = [SELECT FEC_Assignment_Users__c, FEC_Service_Case_Owner__c FROM Case WHERE Id = :c.Id LIMIT 1];
System.debug('Case.FEC_Assignment_Users__c = ' + caseAfter[0].FEC_Assignment_Users__c);
System.debug('Case.FEC_Service_Case_Owner__c = ' + caseAfter[0].FEC_Service_Case_Owner__c + ' (blank = ẩn đúng)');

Integer newCount = assignments.size() - beforeCount;
System.debug('=== RESULT: ' + newCount + ' new assignment(s) created ===');
if (newCount > 0) System.debug('✓ PASS');
else System.debug('✗ FAIL - no new assignments');
