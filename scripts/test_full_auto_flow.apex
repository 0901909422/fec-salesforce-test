List<Case> cases = [
    SELECT Id, CaseNumber, FEC_SubCode__c, FEC_SubCategory__c,
           FEC_Category__c, FEC_Product_Type__c
    FROM Case WHERE FEC_ID_Search__c = 'S-1426' LIMIT 1
];
if (cases.isEmpty()) { System.debug('Not found'); return; }
Case c = cases[0];
System.debug('SubCode: ' + c.FEC_SubCode__c);
System.debug('SubCat: ' + c.FEC_SubCategory__c);
System.debug('Cat: ' + c.FEC_Category__c);
System.debug('ProdType: ' + c.FEC_Product_Type__c);

// Tìm NOC match
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id FROM FEC_Nature_of_Case__c
    WHERE FEC_Product_Type__c = :c.FEC_Product_Type__c
      AND FEC_Category__c = :c.FEC_Category__c
      AND FEC_Sub_Category__c = :c.FEC_SubCategory__c
      AND FEC_Sub_Code__c = :c.FEC_SubCode__c
      AND FEC_Active__c = true
    LIMIT 5
];
System.debug('Matching NOCs: ' + nocs.size());
if (!nocs.isEmpty()) {
    Set<Id> nocIds = new Map<Id, FEC_Nature_of_Case__c>(nocs).keySet();
    List<FEC_Routing_Assignment__c> ras = [
        SELECT FEC_Team__c, FEC_Queue__c
        FROM FEC_Routing_Assignment__c
        WHERE FEC_Nature_of_Cases__c IN :nocIds
          AND FEC_Active__c = true AND FEC_Team__c != null AND FEC_Queue__c != null
    ];
    System.debug('Routing Assignments: ' + ras.size());
    for (FEC_Routing_Assignment__c ra : ras) {
        System.debug('  Team: ' + ra.FEC_Team__c + ' | Queue: ' + ra.FEC_Queue__c);
    }

    // Gọi full luồng
    User u = [SELECT Id, Email, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
    FEC_CofGsrAssignmentService.createAssignmentsOnRoute(c.Id, nocIds, u, null, 'Test Stage', 'Test remark');

    // Check kết quả
    List<FEC_Assignment__c> assignments = [
        SELECT FEC_Team__c, FEC_Assignment_Owner__r.Name, FEC_OwnerID__c, FEC_Assignment_Status__c
        FROM FEC_Assignment__c
        WHERE FEC_Case__c = :c.Id AND FEC_Assignment_Type__c = 'Routing'
        ORDER BY CreatedDate DESC LIMIT 5
    ];
    System.debug('=== Assignments created: ' + assignments.size());
    for (FEC_Assignment__c a : assignments) {
        System.debug('  Team: ' + a.FEC_Team__c + ' | Owner: ' + a.FEC_Assignment_Owner__r?.Name + ' | OwnerID: ' + a.FEC_OwnerID__c);
    }

    List<FEC_Routing_Action_History__c> histories = [
        SELECT FEC_Routing_Action__c, FEC_Updated_User_Queue__c, FEC_Updated_User_Queue_ID__c
        FROM FEC_Routing_Action_History__c
        WHERE FEC_Case__c = :c.Id
        ORDER BY CreatedDate DESC LIMIT 5
    ];
    System.debug('=== Routing Action Histories: ' + histories.size());
    for (FEC_Routing_Action_History__c h : histories) {
        System.debug('  ' + h.FEC_Routing_Action__c + ' | Updated: ' + h.FEC_Updated_User_Queue__c + ' | ID: ' + h.FEC_Updated_User_Queue_ID__c);
    }
}
