// tungnm37: Insert FEC_Routing_Assignment__c cho Loan COF trên qa01

// 1. Lấy NOC Loan COF active
List<FEC_Nature_of_Case__c> loanCofNocs = [
    SELECT Id, FEC_Product_Type__r.Name, FEC_Business_Process__r.FEC_Code__c,
           FEC_Category__r.Name, FEC_Customer_Type__c
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Product_Type__r.Name = 'Loan'
      AND FEC_Business_Process__r.FEC_Code__c LIKE 'COF%'
      AND FEC_Active__c = true
    LIMIT 3
];
System.debug('Loan COF NOCs found: ' + loanCofNocs.size());
for (FEC_Nature_of_Case__c n : loanCofNocs) {
    System.debug('NOC: ' + n.Id + ' | Cat=' + n.FEC_Category__r?.Name + ' | CustomerType=' + n.FEC_Customer_Type__c);
}

if (loanCofNocs.isEmpty()) {
    System.debug('ERROR: Không có NOC Loan COF nào');
    return;
}

// 2. Check queues CC và SP có tồn tại không
List<Group> queues = [
    SELECT Id, Name FROM Group
    WHERE Name IN ('DQ - CS Customer Care', 'DQ - CS Support')
      AND Type = 'Queue'
];
System.debug('Queues found: ' + queues.size());
for (Group g : queues) {
    System.debug('Queue: ' + g.Name + ' | ' + g.Id);
}

// 3. Insert RA cho NOC đầu tiên
FEC_Nature_of_Case__c noc = loanCofNocs[0];
List<FEC_Routing_Assignment__c> toInsert = new List<FEC_Routing_Assignment__c>{
    new FEC_Routing_Assignment__c(
        FEC_Nature_of_Cases__c = noc.Id,
        FEC_Team__c = 'CC',
        FEC_Queue__c = 'DQ - CS Customer Care'
    ),
    new FEC_Routing_Assignment__c(
        FEC_Nature_of_Cases__c = noc.Id,
        FEC_Team__c = 'SP',
        FEC_Queue__c = 'DQ - CS Support'
    )
};

insert toInsert;
System.debug('Inserted ' + toInsert.size() + ' RAs for Loan COF NOC: ' + noc.Id);
for (FEC_Routing_Assignment__c ra : toInsert) {
    System.debug('RA: ' + ra.Id + ' | Team=' + ra.FEC_Team__c + ' | Queue=' + ra.FEC_Queue__c);
}
