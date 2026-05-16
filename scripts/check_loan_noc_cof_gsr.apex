// tungnm37: Check NOC Loan cho COF/GSR
List<FEC_Nature_of_Case__c> loanNocs = [
    SELECT Id, FEC_Product_Type__r.Name, FEC_Business_Process__r.FEC_Code__c,
           FEC_Business_Process__r.Name, FEC_Category__r.Name, FEC_Active__c
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Product_Type__r.Name = 'Loan'
      AND (FEC_Business_Process__r.FEC_Code__c LIKE 'COF%' OR FEC_Business_Process__r.FEC_Code__c LIKE 'GSR%')
    LIMIT 20
];
System.debug('Loan NOCs for COF/GSR: ' + loanNocs.size());
for (FEC_Nature_of_Case__c n : loanNocs) {
    System.debug('NOC: ' + n.Id + ' | PT: ' + n.FEC_Product_Type__r?.Name + ' | BP: ' + n.FEC_Business_Process__r?.FEC_Code__c + ' | Active: ' + n.FEC_Active__c);
}

// Cũng check Card NOC để so sánh team/queue
List<FEC_Routing_Assignment__c> cardRAs = [
    SELECT FEC_Team__c, FEC_Queue__c, FEC_Nature_of_Cases__r.FEC_Business_Process__r.FEC_Code__c
    FROM FEC_Routing_Assignment__c
    WHERE FEC_Team__c != null AND FEC_Queue__c != null
    LIMIT 10
];
System.debug('Card Routing Assignments:');
for (FEC_Routing_Assignment__c ra : cardRAs) {
    System.debug('  Team: ' + ra.FEC_Team__c + ' | Queue: ' + ra.FEC_Queue__c + ' | BP: ' + ra.FEC_Nature_of_Cases__r?.FEC_Business_Process__r?.FEC_Code__c);
}
