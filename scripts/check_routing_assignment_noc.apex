// tungnm37: Check FEC_Routing_Assignment__c có data cho cả Card và Loan không
// Chạy trong Developer Console > Execute Anonymous

// 1. Đếm tổng Routing Assignment
Integer total = [SELECT COUNT() FROM FEC_Routing_Assignment__c WHERE FEC_Team__c != null AND FEC_Queue__c != null];
System.debug('Total Routing Assignments (with team+queue): ' + total);

// 2. Lấy danh sách NOC có Routing Assignment, kèm Product Type
List<AggregateResult> nocWithRA = [
    SELECT FEC_Nature_of_Cases__c nocId, COUNT(Id) cnt
    FROM FEC_Routing_Assignment__c
    WHERE FEC_Team__c != null AND FEC_Queue__c != null
    GROUP BY FEC_Nature_of_Cases__c
    LIMIT 20
];
System.debug('NOCs with Routing Assignment: ' + nocWithRA.size());

Set<Id> nocIds = new Set<Id>();
for (AggregateResult ar : nocWithRA) {
    nocIds.add((Id) ar.get('nocId'));
}

// 3. Lấy Product Type của các NOC đó
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, FEC_Product_Type__c, FEC_Product_Type__r.Name, FEC_Business_Process__c, FEC_Business_Process__r.FEC_Code__c
    FROM FEC_Nature_of_Case__c
    WHERE Id IN :nocIds
    LIMIT 20
];
for (FEC_Nature_of_Case__c n : nocs) {
    System.debug('NOC: ' + n.Id + ' | ProductType: ' + n.FEC_Product_Type__r?.Name + ' | BP: ' + n.FEC_Business_Process__r?.FEC_Code__c);
}
