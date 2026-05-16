// tungnm37: Insert FEC_Routing_Assignment__c cho Loan COF/GSR để test
// Dùng cùng Team/Queue pattern với Card

// Lấy 1 NOC Loan COF và 1 NOC Loan GSR (dùng NOC đầu tiên để test)
FEC_Nature_of_Case__c loanCof = [
    SELECT Id FROM FEC_Nature_of_Case__c
    WHERE FEC_Product_Type__r.Name = 'Loan'
      AND FEC_Business_Process__r.FEC_Code__c LIKE 'COF%'
      AND FEC_Active__c = true
    LIMIT 1
];

FEC_Nature_of_Case__c loanGsr = [
    SELECT Id FROM FEC_Nature_of_Case__c
    WHERE FEC_Product_Type__r.Name = 'Loan'
      AND FEC_Business_Process__r.FEC_Code__c LIKE 'GSR%'
      AND FEC_Active__c = true
    LIMIT 1
];

List<FEC_Routing_Assignment__c> toInsert = new List<FEC_Routing_Assignment__c>{
    // Loan COF - Team CC
    new FEC_Routing_Assignment__c(
        FEC_Nature_of_Cases__c = loanCof.Id,
        FEC_Team__c = 'CC',
        FEC_Queue__c = 'DQ - CS Customer Care'
    ),
    // Loan GSR - Team CO
    new FEC_Routing_Assignment__c(
        FEC_Nature_of_Cases__c = loanGsr.Id,
        FEC_Team__c = 'CO',
        FEC_Queue__c = 'DQ - Card Operations'
    ),
    // Loan GSR - Team SP
    new FEC_Routing_Assignment__c(
        FEC_Nature_of_Cases__c = loanGsr.Id,
        FEC_Team__c = 'SP',
        FEC_Queue__c = 'DQ - CS Support'
    )
};

insert toInsert;
System.debug('Inserted ' + toInsert.size() + ' Routing Assignments for Loan COF/GSR');
for (FEC_Routing_Assignment__c ra : toInsert) {
    System.debug('Inserted RA: ' + ra.Id + ' | NOC: ' + ra.FEC_Nature_of_Cases__c + ' | Team: ' + ra.FEC_Team__c + ' | Queue: ' + ra.FEC_Queue__c);
}
