// Check NOC có Routing Assignment
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, FEC_Active__c, FEC_Business_Process__r.FEC_Code__c,
           FEC_Sub_Code__c, FEC_Sub_Code__r.FEC_Code__c
    FROM FEC_Nature_of_Case__c
    WHERE Id IN ('a06Az00000LG9BKIA1', 'a06Az00000Kuw3EIAR')
];
for (FEC_Nature_of_Case__c n : nocs) {
    System.debug('NOC Id=' + n.Id + ' Active=' + n.FEC_Active__c + ' BP=' + n.FEC_Business_Process__r?.FEC_Code__c + ' SubCode=' + n.FEC_Sub_Code__r?.FEC_Code__c);
}

// Check FEC_Actual_Nature_of_Case__c tương ứng với case đang test
// Case 00004818 có ActualNOC=a0SAz000002Cgn7MAC
Id actualNocId = 'a0SAz000002Cgn7MAC';
String objName = actualNocId.getSObjectType().getDescribe().getName();
System.debug('ActualNOC object type = ' + objName);

FEC_Actual_Nature_of_Case__c an = [
    SELECT FEC_Business_Process__c, FEC_Business_Process__r.FEC_Code__c,
           FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c, FEC_Sub_Code__r.FEC_Code__c
    FROM FEC_Actual_Nature_of_Case__c WHERE Id = :actualNocId LIMIT 1
];
System.debug('ActualNOC BP=' + an.FEC_Business_Process__r?.FEC_Code__c + ' SubCode=' + an.FEC_Sub_Code__r?.FEC_Code__c);

// Tìm FEC_Nature_of_Case__c match
List<FEC_Nature_of_Case__c> matchNocs = [
    SELECT Id, FEC_Active__c, FEC_Business_Process__r.FEC_Code__c
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Business_Process__c = :an.FEC_Business_Process__c
      AND FEC_Category__c = :an.FEC_Category__c
      AND FEC_Sub_Category__c = :an.FEC_Sub_Category__c
      AND FEC_Sub_Code__c = :an.FEC_Sub_Code__c
];
System.debug('Matching NOC count = ' + matchNocs.size());
for (FEC_Nature_of_Case__c n : matchNocs) {
    System.debug('  Match NOC Id=' + n.Id + ' Active=' + n.FEC_Active__c + ' BP=' + n.FEC_Business_Process__r?.FEC_Code__c);
    List<FEC_Routing_Assignment__c> ras = [SELECT Id, FEC_Team__c, FEC_Queue__c FROM FEC_Routing_Assignment__c WHERE FEC_Nature_of_Cases__c = :n.Id];
    System.debug('  RAs count=' + ras.size());
}
