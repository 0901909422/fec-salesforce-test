// Xem tất cả FEC_Routing_Assignment__c và NOC gắn với chúng
List<FEC_Routing_Assignment__c> all = [
  SELECT Id, FEC_Team__c, FEC_Queue__c, FEC_Customer_Type__c,
         FEC_Nature_of_Cases__c, FEC_Nature_of_Cases__r.Name,
         FEC_Active__c
  FROM FEC_Routing_Assignment__c
];
System.debug('Total Routing Assignments: ' + all.size());
for (FEC_Routing_Assignment__c r : all) {
  System.debug('  id=' + r.Id + ' team=' + r.FEC_Team__c
    + ' queue=' + r.FEC_Queue__c
    + ' customerType=' + r.FEC_Customer_Type__c
    + ' noc=' + r.FEC_Nature_of_Cases__r.Name
    + ' active=' + r.FEC_Active__c);
}

// Xem NOC IC01.01 (COF)
List<FEC_Nature_of_Case__c> nocs = [
  SELECT Id, Name, FEC_Business_Process__r.FEC_Code__c, FEC_Active__c
  FROM FEC_Nature_of_Case__c
  WHERE FEC_Business_Process__r.FEC_Code__c LIKE 'COF%'
  LIMIT 10
];
System.debug('COF NOCs: ' + nocs.size());
for (FEC_Nature_of_Case__c n : nocs) {
  System.debug('  ' + n.Id + ' ' + n.Name + ' active=' + n.FEC_Active__c);
}
