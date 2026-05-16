// Test trực tiếp logic createAssignmentsOnRoute với case COF/GSR
// Tìm case chưa submit có ActualNOC thuộc GSR hoặc COF

System.debug('=== Tìm case COF/GSR chưa submit ===');
List<FEC_Actual_Nature_of_Case__c> cofGsrNocs = [
    SELECT Id, FEC_Business_Process__r.FEC_Code__c, FEC_Sub_Code__r.FEC_Code__c
    FROM FEC_Actual_Nature_of_Case__c
    WHERE FEC_Business_Process__r.FEC_Code__c LIKE 'COF%'
       OR FEC_Business_Process__r.FEC_Code__c LIKE 'GSR%'
];
System.debug('COF/GSR ActualNOC count = ' + cofGsrNocs.size());
Set<Id> cofGsrNocIds = new Set<Id>();
for (FEC_Actual_Nature_of_Case__c n : cofGsrNocs) {
    cofGsrNocIds.add(n.Id);
    System.debug('  ActualNOC Id=' + n.Id + ' BP=' + n.FEC_Business_Process__r?.FEC_Code__c);
}

List<Case> testCases = [
    SELECT Id, CaseNumber, FEC_Actual_Nature_of_Case__c, FEC_Is_Submited__c, FEC_Stage_Name__c
    FROM Case
    WHERE FEC_Actual_Nature_of_Case__c IN :cofGsrNocIds
      AND FEC_Is_Submited__c = false
    ORDER BY CreatedDate DESC LIMIT 3
];
System.debug('Unsubmitted COF/GSR cases = ' + testCases.size());
for (Case c : testCases) {
    System.debug('  Case=' + c.CaseNumber + ' Id=' + c.Id + ' ActualNOC=' + c.FEC_Actual_Nature_of_Case__c);
}

if (testCases.isEmpty()) {
    System.debug('Không có case COF/GSR chưa submit. Dùng case đã submit để test insert logic.');
    // Dùng case đã submit nhưng chưa có Assignment
    List<Case> submittedCases = [
        SELECT Id, CaseNumber, FEC_Actual_Nature_of_Case__c
        FROM Case
        WHERE FEC_Actual_Nature_of_Case__c IN :cofGsrNocIds
        ORDER BY CreatedDate DESC LIMIT 1
    ];
    if (!submittedCases.isEmpty()) {
        testCases = submittedCases;
        System.debug('Using submitted case: ' + testCases[0].CaseNumber);
    }
}

if (!testCases.isEmpty()) {
    String caseId = testCases[0].Id;
    String inputNocId = testCases[0].FEC_Actual_Nature_of_Case__c;
    System.debug('Testing with caseId=' + caseId + ' inputNocId=' + inputNocId);

    // Resolve NOC IDs
    Id recordId = inputNocId;
    FEC_Actual_Nature_of_Case__c an = [
        SELECT FEC_Business_Process__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c,
               FEC_Business_Process__r.FEC_Code__c, FEC_Sub_Code__r.FEC_Code__c
        FROM FEC_Actual_Nature_of_Case__c WHERE Id = :inputNocId LIMIT 1
    ];
    System.debug('ActualNOC BP=' + an.FEC_Business_Process__r?.FEC_Code__c + ' SubCode=' + an.FEC_Sub_Code__r?.FEC_Code__c);

    List<FEC_Nature_of_Case__c> matchNocs = [
        SELECT Id FROM FEC_Nature_of_Case__c
        WHERE FEC_Business_Process__c = :an.FEC_Business_Process__c
          AND FEC_Category__c = :an.FEC_Category__c
          AND FEC_Sub_Category__c = :an.FEC_Sub_Category__c
          AND FEC_Sub_Code__c = :an.FEC_Sub_Code__c
    ];
    System.debug('Matching NOCs = ' + matchNocs.size());

    Set<Id> allNocIds = new Set<Id>();
    for (FEC_Nature_of_Case__c n : matchNocs) allNocIds.add(n.Id);

    List<AggregateResult> nocWithRa = [
        SELECT FEC_Nature_of_Cases__c nocId
        FROM FEC_Routing_Assignment__c
        WHERE FEC_Nature_of_Cases__c IN :allNocIds
          AND FEC_Team__c != null AND FEC_Queue__c != null
        GROUP BY FEC_Nature_of_Cases__c
    ];
    Set<Id> resolvedNocIds = new Set<Id>();
    for (AggregateResult ar : nocWithRa) resolvedNocIds.add((Id) ar.get('nocId'));
    System.debug('Resolved NOC IDs with RA = ' + resolvedNocIds);

    List<FEC_Routing_Assignment__c> ras = [
        SELECT FEC_Team__c, FEC_Queue__c
        FROM FEC_Routing_Assignment__c
        WHERE FEC_Nature_of_Cases__c IN :resolvedNocIds
          AND FEC_Team__c != null AND FEC_Queue__c != null
        ORDER BY FEC_Team__c ASC
    ];
    System.debug('RA count = ' + ras.size());
    for (FEC_Routing_Assignment__c ra : ras) {
        System.debug('  Team=' + ra.FEC_Team__c + ' Queue=' + ra.FEC_Queue__c);
    }

    if (!ras.isEmpty()) {
        Set<String> queueNames = new Set<String>();
        for (FEC_Routing_Assignment__c ra : ras) {
            if (String.isNotBlank(ra.FEC_Queue__c)) queueNames.add(ra.FEC_Queue__c);
        }
        Map<String, Id> queueNameToId = new Map<String, Id>();
        for (Group g : [SELECT Id, Name FROM Group WHERE Name IN :queueNames AND Type = 'Queue']) {
            queueNameToId.put(g.Name, g.Id);
        }
        System.debug('Queue map = ' + queueNameToId);

        User currentUser = [SELECT Email, UserRole.Name, Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        List<FEC_Assignment__c> assignments = new List<FEC_Assignment__c>();
        for (FEC_Routing_Assignment__c ra : ras) {
            String queueId = queueNameToId.containsKey(ra.FEC_Queue__c) ? String.valueOf(queueNameToId.get(ra.FEC_Queue__c)) : null;
            assignments.add(new FEC_Assignment__c(
                FEC_Case__c = caseId,
                FEC_Assignment_Name__c = 'Call',
                FEC_Assignment_Type__c = 'Routing',
                FEC_Assignment_Status__c = 'Open',
                FEC_OwnerID__c = queueId,
                FEC_Team__c = ra.FEC_Team__c,
                FEC_User_Role__c = currentUser.UserRole?.Name,
                Assignment_Routing_Action__c = 'Test Stage'
            ));
        }
        System.debug('Inserting ' + assignments.size() + ' assignments');
        try {
            insert assignments;
            System.debug('=== Insert SUCCESS ===');
            for (FEC_Assignment__c a : assignments) {
                System.debug('  Created Assignment Id=' + a.Id + ' Team=' + a.FEC_Team__c + ' Queue=' + a.FEC_OwnerID__c);
            }
            // Cleanup
            delete assignments;
            System.debug('Cleanup done');
        } catch (Exception e) {
            System.debug('Insert ERROR: ' + e.getMessage());
        }
    } else {
        System.debug('Không có RA nào → cần thêm data FEC_Routing_Assignment__c cho bộ NOC này');
    }
}
