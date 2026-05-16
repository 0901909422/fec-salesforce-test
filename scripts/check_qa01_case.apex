// Check case trực tiếp bằng Id từ URL
String caseId = '5008500000HY1JHAA1';
List<Case> cases = [
    SELECT Id, CaseNumber, Status, OwnerId, Owner.Name, Owner.Type,
           FEC_Product_Type__r.Name, FEC_Actual_Nature_of_Case__c,
           FEC_Current_Case_Stage__c, FEC_Business_Process__r.FEC_Code__c
    FROM Case WHERE Id = :caseId LIMIT 1
];
if (!cases.isEmpty()) {
    Case c = cases[0];
    System.debug('Case: ' + c.CaseNumber + ' | Status=' + c.Status
        + ' | Owner=' + c.Owner?.Name + ' | OwnerType=' + c.Owner?.Type
        + ' | PT=' + c.FEC_Product_Type__r?.Name
        + ' | BP=' + c.FEC_Business_Process__r?.FEC_Code__c
        + ' | NOC=' + c.FEC_Actual_Nature_of_Case__c);

    Integer aCount = [SELECT COUNT() FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id];
    Integer hCount = [SELECT COUNT() FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :c.Id];
    System.debug('Assignments: ' + aCount + ' | Routing Histories: ' + hCount);

    // Check NOC có RA không
    if (c.FEC_Actual_Nature_of_Case__c != null) {
        Set<Id> nocIds = FEC_CofGsrAssignmentService.resolveToNocIds(c.FEC_Actual_Nature_of_Case__c);
        System.debug('Resolved NOC IDs: ' + nocIds.size() + ' -> ' + nocIds);
        
        List<FEC_Routing_Assignment__c> ras = [
            SELECT FEC_Team__c, FEC_Queue__c
            FROM FEC_Routing_Assignment__c
            WHERE FEC_Nature_of_Cases__c IN :nocIds
              AND FEC_Team__c != null AND FEC_Queue__c != null
        ];
        System.debug('RAs for this case NOC: ' + ras.size());
        for (FEC_Routing_Assignment__c ra : ras) {
            System.debug('  -> Team=' + ra.FEC_Team__c + ' | Queue=' + ra.FEC_Queue__c);
        }
    }
} else {
    System.debug('Case not found: ' + caseId);
    // Tìm case Loan gần nhất
    List<Case> recent = [
        SELECT Id, CaseNumber, Status, FEC_Product_Type__r.Name
        FROM Case WHERE FEC_Product_Type__r.Name = 'Loan' AND IsClosed = false
        ORDER BY CreatedDate DESC LIMIT 3
    ];
    for (Case rc : recent) {
        System.debug('Recent Loan case: ' + rc.CaseNumber + ' | ' + rc.Id + ' | ' + rc.Status);
    }
}
