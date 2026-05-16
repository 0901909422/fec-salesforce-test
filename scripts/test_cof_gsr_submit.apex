// Test luồng ROUTE_TO_COF_GSR với bộ NOC: Card / Inquiry / IC01 / IC01.01
// Tìm FEC_Actual_Nature_of_Case__c có Sub_Code = IC01.01

System.debug('=== STEP 1: Tìm FEC_Actual_Nature_of_Case__c với Sub_Code IC01.01 ===');
List<FEC_Actual_Nature_of_Case__c> actualNocs = [
    SELECT Id, FEC_Business_Process__c, FEC_Business_Process__r.FEC_Code__c,
           FEC_Category__c, FEC_Sub_Category__c,
           FEC_Sub_Code__c, FEC_Sub_Code__r.FEC_Code__c
    FROM FEC_Actual_Nature_of_Case__c
    WHERE FEC_Sub_Code__r.FEC_Code__c = 'IC01.01'
];
System.debug('FEC_Actual_Nature_of_Case__c count = ' + actualNocs.size());
for (FEC_Actual_Nature_of_Case__c an : actualNocs) {
    System.debug('  ActualNOC Id=' + an.Id + ' BP=' + an.FEC_Business_Process__r?.FEC_Code__c + ' SubCode=' + an.FEC_Sub_Code__r?.FEC_Code__c);
}

System.debug('=== STEP 2: Tìm FEC_Nature_of_Case__c cùng bộ ===');
if (!actualNocs.isEmpty()) {
    FEC_Actual_Nature_of_Case__c an = actualNocs[0];
    List<FEC_Nature_of_Case__c> matchNocs = [
        SELECT Id, FEC_Active__c, FEC_Business_Process__r.FEC_Code__c
        FROM FEC_Nature_of_Case__c
        WHERE FEC_Business_Process__c = :an.FEC_Business_Process__c
          AND FEC_Category__c = :an.FEC_Category__c
          AND FEC_Sub_Category__c = :an.FEC_Sub_Category__c
          AND FEC_Sub_Code__c = :an.FEC_Sub_Code__c
    ];
    System.debug('Matching FEC_Nature_of_Case__c count = ' + matchNocs.size());

    Set<Id> nocIds = new Set<Id>();
    for (FEC_Nature_of_Case__c n : matchNocs) {
        nocIds.add(n.Id);
        System.debug('  NOC Id=' + n.Id + ' Active=' + n.FEC_Active__c + ' BP=' + n.FEC_Business_Process__r?.FEC_Code__c);
    }

    System.debug('=== STEP 3: Tìm FEC_Routing_Assignment__c cho tất cả NOC ===');
    List<FEC_Routing_Assignment__c> ras = [
        SELECT Id, FEC_Nature_of_Cases__c, FEC_Team__c, FEC_Queue__c
        FROM FEC_Routing_Assignment__c
        WHERE FEC_Nature_of_Cases__c IN :nocIds
          AND FEC_Team__c != null AND FEC_Queue__c != null
        ORDER BY FEC_Team__c ASC
    ];
    System.debug('FEC_Routing_Assignment__c count = ' + ras.size());
    for (FEC_Routing_Assignment__c ra : ras) {
        System.debug('  RA Id=' + ra.Id + ' NOC=' + ra.FEC_Nature_of_Cases__c + ' Team=' + ra.FEC_Team__c + ' Queue=' + ra.FEC_Queue__c);
    }

    System.debug('=== STEP 4: Tìm Queue IDs ===');
    Set<String> queueNames = new Set<String>();
    for (FEC_Routing_Assignment__c ra : ras) {
        if (String.isNotBlank(ra.FEC_Queue__c)) queueNames.add(ra.FEC_Queue__c);
    }
    List<Group> queues = [SELECT Id, Name FROM Group WHERE Name IN :queueNames AND Type = 'Queue'];
    System.debug('Queues found = ' + queues.size());
    for (Group g : queues) {
        System.debug('  Queue Id=' + g.Id + ' Name=' + g.Name);
    }
}

System.debug('=== STEP 5: Tìm case COF/GSR chưa submit để test ===');
List<Case> testCases = [
    SELECT Id, CaseNumber, FEC_Actual_Nature_of_Case__c, FEC_Is_Submited__c,
           FEC_Stage_Name__c
    FROM Case
    WHERE FEC_Actual_Nature_of_Case__c != null
      AND FEC_Is_Submited__c = false
    ORDER BY CreatedDate DESC LIMIT 3
];
System.debug('Unsubmitted cases with ActualNOC = ' + testCases.size());
for (Case c : testCases) {
    System.debug('  Case=' + c.CaseNumber + ' Id=' + c.Id + ' ActualNOC=' + c.FEC_Actual_Nature_of_Case__c + ' Stage=' + c.FEC_Stage_Name__c);
}

System.debug('=== STEP 6: Check FEC_Assignment__c đã tạo gần đây ===');
List<FEC_Assignment__c> recentAssignments = [
    SELECT Id, FEC_Case__c, FEC_Team__c, FEC_OwnerID__c, FEC_Assignment_Status__c,
           FEC_Assignment_Type__c, CreatedDate
    FROM FEC_Assignment__c
    ORDER BY CreatedDate DESC LIMIT 5
];
System.debug('Recent FEC_Assignment__c = ' + recentAssignments.size());
for (FEC_Assignment__c a : recentAssignments) {
    System.debug('  Assignment Id=' + a.Id + ' Case=' + a.FEC_Case__c + ' Team=' + a.FEC_Team__c + ' Queue=' + a.FEC_OwnerID__c + ' Status=' + a.FEC_Assignment_Status__c + ' Created=' + a.CreatedDate);
}

System.debug('=== STEP 7: Check FEC_Log__c lỗi gần đây ===');
List<FEC_Log__c> logs = [
    SELECT Id, FEC_Function_Name__c, FEC_Error_Message__c, FEC_Stack_Trace_String__c, CreatedDate
    FROM FEC_Log__c
    WHERE FEC_Function_Name__c = 'createAssignmentsOnRoute'
    ORDER BY CreatedDate DESC LIMIT 3
];
System.debug('Error logs = ' + logs.size());
for (FEC_Log__c l : logs) {
    System.debug('  Log=' + l.FEC_Error_Message__c + ' | ' + l.FEC_Stack_Trace_String__c);
}
