// Check FEC_Stage_Name__c trên Case đang lưu Id hay Name
// Assignment a0D86000002ZEF3 - check case liên quan
List<FEC_Assignment__c> assignments = [
    SELECT Id, Name, FEC_Assignment_Routing_Action__c, FEC_Case__c,
           FEC_Case__r.FEC_ID_Search__c, FEC_Case__r.FEC_Stage_Name__c,
           FEC_Case__r.FEC_Current_Case_Stage__r.Name
    FROM FEC_Assignment__c
    WHERE Name = 'A-000090'
    LIMIT 1
];
if (!assignments.isEmpty()) {
    FEC_Assignment__c a = assignments[0];
    System.debug('Assignment: ' + a.Name);
    System.debug('FEC_Assignment_Routing_Action__c: ' + a.FEC_Assignment_Routing_Action__c);
    System.debug('Case: ' + a.FEC_Case__r?.FEC_ID_Search__c);
    System.debug('Case.FEC_Stage_Name__c: ' + a.FEC_Case__r?.FEC_Stage_Name__c);
    System.debug('Case.CurrentStage.Name: ' + a.FEC_Case__r?.FEC_Current_Case_Stage__r?.Name);
}

// Check FEC_Case_Remarks__c Stage Name
List<FEC_Case_Remarks__c> remarks = [
    SELECT Id, FEC_Stage_Name__c, FEC_Assignment__r.Name
    FROM FEC_Case_Remarks__c
    WHERE FEC_Assignment__r.Name = 'A-000090'
    LIMIT 3
];
System.debug('=== REMARKS ===');
for (FEC_Case_Remarks__c r : remarks) {
    System.debug('StageName: ' + r.FEC_Stage_Name__c);
}

// Check recent cases - FEC_Stage_Name__c format
List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Stage_Name__c, FEC_Current_Case_Stage__r.Name
    FROM Case
    WHERE FEC_Stage_Name__c != null
    ORDER BY CreatedDate DESC LIMIT 3
];
System.debug('=== RECENT CASES FEC_Stage_Name__c ===');
for (Case c : cases) {
    System.debug(c.FEC_ID_Search__c + ' | FEC_Stage_Name__c=' + c.FEC_Stage_Name__c + ' | CurrentStage.Name=' + c.FEC_Current_Case_Stage__r?.Name);
}
