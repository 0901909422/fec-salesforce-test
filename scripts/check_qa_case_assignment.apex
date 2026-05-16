// Check Case 5008500000HvjJbAAJ trên QA
String caseId = '5008500000HvjJbAAJ';

// 1. Case info
List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Stage_Name__c,
           FEC_Current_Case_Stage__r.Name
    FROM Case WHERE Id = :caseId LIMIT 1
];
if (!cases.isEmpty()) {
    System.debug('Case: ' + cases[0].FEC_ID_Search__c + ' | Stage: ' + cases[0].FEC_Stage_Name__c);
}

// 2. Assignments
List<FEC_Assignment__c> assignments = [
    SELECT Id, Name, FEC_Assignment_Type__c, FEC_OwnerID__c, FEC_Team__c,
           FEC_User_Role__c, CreatedDate
    FROM FEC_Assignment__c
    WHERE FEC_Case__c = :caseId
    ORDER BY CreatedDate DESC LIMIT 10
];
System.debug('=== ASSIGNMENTS (' + assignments.size() + ') ===');
for (FEC_Assignment__c a : assignments) {
    System.debug('  ' + a.Name + ' | Team=' + a.FEC_Team__c + ' | OwnerID=' + a.FEC_OwnerID__c + ' | UserRole=' + a.FEC_User_Role__c);
}

// 3. Assignment Remarks
if (!assignments.isEmpty()) {
    Set<Id> aIds = new Map<Id, FEC_Assignment__c>(assignments).keySet();
    List<FEC_Case_Remarks__c> aRemarks = [
        SELECT Id, FEC_Case_Remarks__c, FEC_Stage_Name__c, FEC_User__c,
               FEC_User_Role__c, FEC_Remark_Type__c, FEC_Assignment__r.Name
        FROM FEC_Case_Remarks__c
        WHERE FEC_Assignment__c IN :aIds
        ORDER BY CreatedDate DESC LIMIT 10
    ];
    System.debug('=== ASSIGNMENT REMARKS (' + aRemarks.size() + ') ===');
    for (FEC_Case_Remarks__c r : aRemarks) {
        System.debug('  Assignment=' + r.FEC_Assignment__r?.Name + ' | User=' + r.FEC_User__c + ' | UserRole=' + r.FEC_User_Role__c + ' | Stage=' + r.FEC_Stage_Name__c);
    }
}

// 4. Case Remarks (type=null)
List<FEC_Case_Remarks__c> cRemarks = [
    SELECT Id, FEC_Case_Remarks__c, FEC_Stage_Name__c, FEC_User__c,
           FEC_User_Role__c, FEC_Remark_Type__c
    FROM FEC_Case_Remarks__c
    WHERE FEC_Case__c = :caseId AND FEC_Remark_Type__c = null
    ORDER BY CreatedDate DESC LIMIT 5
];
System.debug('=== CASE REMARKS (type=null) (' + cRemarks.size() + ') ===');
for (FEC_Case_Remarks__c r : cRemarks) {
    System.debug('  User=' + r.FEC_User__c + ' | UserRole=' + r.FEC_User_Role__c + ' | Stage=' + r.FEC_Stage_Name__c);
}
