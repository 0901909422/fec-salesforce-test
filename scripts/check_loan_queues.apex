// tungnm37: Check queues và NOC Loan COF/GSR để biết cần insert RA nào

// 1. Tất cả queues hiện có liên quan COF/GSR/Loan
List<Group> queues = [
    SELECT Id, Name FROM Group 
    WHERE Type = 'Queue' 
    AND (Name LIKE '%COF%' OR Name LIKE '%GSR%' OR Name LIKE '%Loan%' OR Name LIKE '%Card%' OR Name LIKE '%CS%' OR Name LIKE '%DQ%')
    ORDER BY Name
];
System.debug('=== Queues ===');
for (Group g : queues) {
    System.debug('Queue: ' + g.Name + ' | Id: ' + g.Id);
}

// 2. Existing Routing Assignments (Card) để biết pattern
List<FEC_Routing_Assignment__c> existingRAs = [
    SELECT Id, FEC_Team__c, FEC_Queue__c, FEC_Nature_of_Cases__c,
           FEC_Nature_of_Cases__r.FEC_Product_Type__r.Name,
           FEC_Nature_of_Cases__r.FEC_Business_Process__r.FEC_Code__c,
           FEC_Nature_of_Cases__r.FEC_Category__r.Name,
           FEC_Nature_of_Cases__r.FEC_Sub_Category__r.Name
    FROM FEC_Routing_Assignment__c
    WHERE FEC_Team__c != null AND FEC_Queue__c != null
];
System.debug('=== Existing RAs ===');
for (FEC_Routing_Assignment__c ra : existingRAs) {
    System.debug('Team: ' + ra.FEC_Team__c + ' | Queue: ' + ra.FEC_Queue__c 
        + ' | PT: ' + ra.FEC_Nature_of_Cases__r?.FEC_Product_Type__r?.Name
        + ' | BP: ' + ra.FEC_Nature_of_Cases__r?.FEC_Business_Process__r?.FEC_Code__c
        + ' | NOC: ' + ra.FEC_Nature_of_Cases__c);
}

// 3. Lấy 1 NOC Loan COF và 1 NOC Loan GSR để biết Id
List<FEC_Nature_of_Case__c> loanCofNocs = [
    SELECT Id, FEC_Product_Type__r.Name, FEC_Business_Process__r.FEC_Code__c,
           FEC_Category__r.Name, FEC_Sub_Category__r.Name, FEC_Customer_Type__c
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Product_Type__r.Name = 'Loan'
      AND FEC_Business_Process__r.FEC_Code__c LIKE 'COF%'
      AND FEC_Active__c = true
    LIMIT 3
];
System.debug('=== Loan COF NOCs (sample) ===');
for (FEC_Nature_of_Case__c n : loanCofNocs) {
    System.debug('Id: ' + n.Id + ' | CustomerType: ' + n.FEC_Customer_Type__c);
}

List<FEC_Nature_of_Case__c> loanGsrNocs = [
    SELECT Id, FEC_Product_Type__r.Name, FEC_Business_Process__r.FEC_Code__c,
           FEC_Category__r.Name, FEC_Sub_Category__r.Name, FEC_Customer_Type__c
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Product_Type__r.Name = 'Loan'
      AND FEC_Business_Process__r.FEC_Code__c LIKE 'GSR%'
      AND FEC_Active__c = true
    LIMIT 3
];
System.debug('=== Loan GSR NOCs (sample) ===');
for (FEC_Nature_of_Case__c n : loanGsrNocs) {
    System.debug('Id: ' + n.Id + ' | CustomerType: ' + n.FEC_Customer_Type__c);
}
