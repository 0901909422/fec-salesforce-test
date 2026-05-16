// Debug script: check tại sao Assignment không được tạo
// Thay bằng Case ID cần check
String caseId = '500Az00000PvOSGIA3';

if (String.isBlank(caseId)) {
    // Lấy case mới nhất
    List<Case> latest = [
        SELECT Id, FEC_ID_Search__c FROM Case
        ORDER BY CreatedDate DESC LIMIT 1
    ];
    if (!latest.isEmpty()) caseId = latest[0].Id;
}

List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Stage_Name__c,
           FEC_Business_Process__c, FEC_Business_Process__r.FEC_Code__c,
           FEC_Current_Case_Stage__r.Name,
           FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c
    FROM Case WHERE Id = :caseId LIMIT 1
];
if (cases.isEmpty()) { System.debug('Case not found'); return; }
Case c = cases[0];
System.debug('Case: ' + c.FEC_ID_Search__c + ' | BP: ' + c.FEC_Business_Process__r?.FEC_Code__c + ' | Stage: ' + c.FEC_Current_Case_Stage__r?.Name);

// 1. Check NOC
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, FEC_Business_Process__r.FEC_Code__c
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Product_Type__c = :c.FEC_Product_Type__c
      AND FEC_Category__c = :c.FEC_Category__c
      AND FEC_Sub_Category__c = :c.FEC_SubCategory__c
      AND FEC_Sub_Code__c = :c.FEC_SubCode__c
    LIMIT 5
];
System.debug('NOCs found: ' + nocs.size());
for (FEC_Nature_of_Case__c n : nocs) {
    System.debug('  NOC: ' + n.Id + ' | BP: ' + n.FEC_Business_Process__r?.FEC_Code__c);
}

if (nocs.isEmpty()) { System.debug('NO NOC FOUND - cannot create assignments'); return; }

// 2. Check BP code COF/GSR
String bpCode = nocs[0].FEC_Business_Process__r?.FEC_Code__c;
Boolean isCofGsr = bpCode != null && (bpCode.startsWith('COF') || bpCode.startsWith('GSR'));
System.debug('BP Code: ' + bpCode + ' | isCOF/GSR: ' + isCofGsr);
if (!isCofGsr) { System.debug('NOT COF/GSR - createAssignmentsOnRoute will skip'); }

// 3. Check FEC_Routing_Assignment__c
Set<Id> nocIds = new Set<Id>();
for (FEC_Nature_of_Case__c n : nocs) nocIds.add(n.Id);

List<FEC_Routing_Assignment__c> ras = [
    SELECT Id, FEC_Team__c, FEC_Queue__c, FEC_Active__c, FEC_Nature_of_Cases__c
    FROM FEC_Routing_Assignment__c
    WHERE FEC_Nature_of_Cases__c IN :nocIds
    ORDER BY FEC_Team__c
];
System.debug('FEC_Routing_Assignment__c records: ' + ras.size());
Boolean hasNonCcSp = false;
for (FEC_Routing_Assignment__c ra : ras) {
    Boolean isActive = ra.FEC_Active__c;
    Boolean hasBoth = ra.FEC_Team__c != null && ra.FEC_Queue__c != null;
    Boolean isCcSp = 'CC'.equals(ra.FEC_Team__c) || 'SP'.equals(ra.FEC_Team__c);
    if (!isCcSp && isActive && hasBoth) hasNonCcSp = true;
    System.debug('  RA: Team=' + ra.FEC_Team__c + ' | Queue=' + ra.FEC_Queue__c + ' | Active=' + isActive + ' | HasBoth=' + hasBoth + ' | isCcSp=' + isCcSp);
}
System.debug('hasNonCcSpTeam = ' + hasNonCcSp);
if (!hasNonCcSp) System.debug('→ SKIP createAssignmentsOnRoute (chỉ có CC/SP hoặc không có routing rule)');
else System.debug('→ WILL call createAssignmentsOnRoute');

// 4. Check Assignments hiện tại
List<FEC_Assignment__c> assignments = [
    SELECT Id, Name, FEC_Assignment_Type__c, FEC_OwnerID__c, FEC_Manual__c, CreatedDate
    FROM FEC_Assignment__c
    WHERE FEC_Case__c = :caseId
    ORDER BY CreatedDate DESC LIMIT 10
];
System.debug('Current Assignments: ' + assignments.size());
for (FEC_Assignment__c a : assignments) {
    System.debug('  ' + a.Name + ' | Type=' + a.FEC_Assignment_Type__c + ' | OwnerID=' + a.FEC_OwnerID__c + ' | Manual=' + a.FEC_Manual__c);
}
