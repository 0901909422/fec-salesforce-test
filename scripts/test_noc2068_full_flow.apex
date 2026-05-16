// Test full flow NOC-2068: Stage 1 → Stage 2
// Bước 1: Tìm case COF NOC-2068 chưa submit hoặc tạo mới

// Lấy NOC-2068 và Stage 1
FEC_Nature_of_Case__c noc2068 = [SELECT Id, Name FROM FEC_Nature_of_Case__c WHERE Name = 'NOC-2068' LIMIT 1];
FEC_Case_Stage__c stage1 = [
    SELECT Id, Name FROM FEC_Case_Stage__c
    WHERE FEC_Nature_of_Cases__c = :noc2068.Id AND FEC_Default_Stage__c = true LIMIT 1
];
FEC_Case_Stage__c stage2 = [
    SELECT Id, Name FROM FEC_Case_Stage__c
    WHERE FEC_Nature_of_Cases__c = :noc2068.Id AND FEC_Default_Stage__c = false
    ORDER BY Name ASC LIMIT 1
];
System.debug('Stage 1 Id=' + stage1.Id + ' Name=' + stage1.Name);
System.debug('Stage 2 Id=' + stage2.Id + ' Name=' + stage2.Name);

// Lấy FEC_Actual_Nature_of_Case__c tương ứng với NOC-2068
// (không cần cho test này)

// Tìm case COF chưa submit
List<Case> testCases = [
    SELECT Id, CaseNumber, FEC_Is_Submited__c, FEC_Current_Case_Stage__c, FEC_Stage_Name__c
    FROM Case
    WHERE FEC_Is_Submited__c = false
      AND FEC_Actual_Nature_of_Case__c != null
    ORDER BY CreatedDate DESC LIMIT 3
];
System.debug('Unsubmitted cases with ActualNOC = ' + testCases.size());
for (Case c : testCases) {
    System.debug('  Case=' + c.CaseNumber + ' Stage=' + c.FEC_Stage_Name__c);
}

// Simulate: set case về Stage 1 của NOC-2068 để test
// (Chỉ dùng case đã có, không tạo mới)
if (!testCases.isEmpty()) {
    String caseId = testCases[0].Id;
    System.debug('Testing with case=' + testCases[0].CaseNumber);
    
    // Step 1: Simulate ROUTE_TO_COF_GSR - chuyển Owner sang DQ-CS Customer Care (Team CC)
    System.debug('=== Step 1: Submit Stage 1 - chuyển Owner sang DQ-CS Customer Care ===');
    
    // markCaseSubmittedAndClearDrafts
    update new Case(
        Id = caseId,
        FEC_Is_Submited__c = true,
        FEC_Draft_Routing_Action_Code__c = null,
        FEC_Draft_Remarks__c = null,
        Status = 'Pending'
    );
    
    // Chuyển Owner sang DQ-CS Customer Care
    List<Group> ccQueue = [SELECT Id FROM Group WHERE Name = 'DQ - CS Customer Care' AND Type = 'Queue' LIMIT 1];
    if (!ccQueue.isEmpty()) {
        update new Case(Id = caseId, OwnerId = ccQueue[0].Id);
        System.debug('Owner changed to DQ-CS Customer Care');
    }
    
    // Update Stage sang Stage 2
    update new Case(Id = caseId, FEC_Current_Case_Stage__c = stage2.Id);
    System.debug('Stage updated to Stage 2');
    
    // Check case sau Step 1
    Case c1 = [SELECT Id, CaseNumber, FEC_Is_Submited__c, FEC_Current_Case_Stage__r.Name, FEC_Stage_Name__c, OwnerId, Owner.Name FROM Case WHERE Id = :caseId LIMIT 1];
    System.debug('After Step 1: Submitted=' + c1.FEC_Is_Submited__c + ' Stage=' + c1.FEC_Current_Case_Stage__r?.Name + ' Owner=' + c1.Owner?.Name);
    System.debug('Case is now at Stage 2 - ready for Add Item and submit Stage 2');
}
