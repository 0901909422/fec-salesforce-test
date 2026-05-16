// tungnm37: test getRoutingAssignments với NOC ID từ console
String natureOfCaseId = 'a06Az00000KeIu83EIA';
String customerType = 'Existing';

// Step 1: check trực tiếp
List<FEC_Routing_Assignment__c> direct = [
    SELECT FEC_Team__c, FEC_Queue__c, FEC_Customer_Type__c, FEC_Nature_of_Cases__c
    FROM FEC_Routing_Assignment__c
    WHERE FEC_Nature_of_Cases__c = :natureOfCaseId
    LIMIT 10
];
System.debug('Direct query result: ' + direct.size());

// Step 2: check FEC_Actual_Nature_of_Case__c
List<FEC_Actual_Nature_of_Case__c> actualNocs = [
    SELECT Id, FEC_Business_Process__c, FEC_Category__c, FEC_Sub_Category__c,
           FEC_Sub_Code__c, FEC_Customer_Type__c, FEC_Product_Type__c
    FROM FEC_Actual_Nature_of_Case__c
    WHERE Id = :natureOfCaseId
    LIMIT 1
];
System.debug('ActualNOC found: ' + actualNocs.size());
if (!actualNocs.isEmpty()) {
    FEC_Actual_Nature_of_Case__c an = actualNocs[0];
    System.debug('BP: ' + an.FEC_Business_Process__c + ' | Cat: ' + an.FEC_Category__c
        + ' | SubCat: ' + an.FEC_Sub_Category__c + ' | SubCode: ' + an.FEC_Sub_Code__c
        + ' | CustomerType: ' + an.FEC_Customer_Type__c);

    // Step 3: tìm FEC_Nature_of_Case__c match
    List<FEC_Nature_of_Case__c> matchNocs = [
        SELECT Id, Name
        FROM FEC_Nature_of_Case__c
        WHERE FEC_Business_Process__c = :an.FEC_Business_Process__c
          AND FEC_Category__c = :an.FEC_Category__c
          AND FEC_Sub_Category__c = :an.FEC_Sub_Category__c
          AND FEC_Sub_Code__c = :an.FEC_Sub_Code__c
          AND FEC_Active__c = true
        LIMIT 10
    ];
    System.debug('Matching NOCs: ' + matchNocs.size());
    for (FEC_Nature_of_Case__c n : matchNocs) {
        System.debug('NOC: ' + n.Id + ' | ' + n.Name);
    }

    // Step 4: query Routing Assignment
    if (!matchNocs.isEmpty()) {
        Set<Id> nocIds = new Set<Id>();
        for (FEC_Nature_of_Case__c n : matchNocs) nocIds.add(n.Id);
        List<FEC_Routing_Assignment__c> ras = [
            SELECT FEC_Team__c, FEC_Queue__c, FEC_Customer_Type__c
            FROM FEC_Routing_Assignment__c
            WHERE FEC_Nature_of_Cases__c IN :nocIds
              AND FEC_Active__c = true
            LIMIT 10
        ];
        System.debug('Routing Assignments found: ' + ras.size());
        for (FEC_Routing_Assignment__c r : ras) {
            System.debug('Team: ' + r.FEC_Team__c + ' | Queue: ' + r.FEC_Queue__c + ' | CustomerType: ' + r.FEC_Customer_Type__c);
        }
    }
}
