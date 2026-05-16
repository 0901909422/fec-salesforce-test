// tungnm37: check NOC ID của Routing Assignment vs NOC ID từ getByCase
// 1. NOC ID trong Routing Assignment
List<FEC_Routing_Assignment__c> ras = [
    SELECT Id, FEC_Team__c, FEC_Queue__c, FEC_Nature_of_Cases__c,
           FEC_Customer_Type__c, FEC_Active__c
    FROM FEC_Routing_Assignment__c
    WHERE FEC_Active__c = true
    LIMIT 10
];
System.debug('=== Routing Assignments ===');
for (FEC_Routing_Assignment__c r : ras) {
    System.debug('Team: ' + r.FEC_Team__c + ' | Queue: ' + r.FEC_Queue__c
        + ' | NOC_ID: ' + r.FEC_Nature_of_Cases__c
        + ' | CustomerType: ' + r.FEC_Customer_Type__c);
}

// 2. NOC ID từ FEC_Nature_of_Case__c với Card/Inquiry/KC01
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, Name, FEC_Business_Process__r.FEC_Code__c,
           FEC_Category__r.Name, FEC_Sub_Category__r.Name, FEC_Sub_Code__r.Name
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Business_Process__r.FEC_Code__c LIKE 'GSR%'
      AND FEC_Active__c = true
    LIMIT 5
];
System.debug('=== NOC GSR ===');
for (FEC_Nature_of_Case__c n : nocs) {
    System.debug('NOC_ID: ' + n.Id + ' | Name: ' + n.Name
        + ' | BP: ' + n.FEC_Business_Process__r?.FEC_Code__c
        + ' | Cat: ' + n.FEC_Category__r?.Name
        + ' | SubCat: ' + n.FEC_Sub_Category__r?.Name
        + ' | SubCode: ' + n.FEC_Sub_Code__r?.Name);
}

// 3. Check NOC ID của Routing Assignment có match với NOC nào không
Set<Id> raIds = new Set<Id>();
for (FEC_Routing_Assignment__c r : ras) {
    if (r.FEC_Nature_of_Cases__c != null) raIds.add(r.FEC_Nature_of_Cases__c);
}
System.debug('NOC IDs in Routing Assignment: ' + raIds);
