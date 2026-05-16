// Test resolveToNatureOfCaseId với case có FEC_Actual_Nature_of_Case__c
// Case 00004818 có ActualNOC=a0SAz000002Cgn7MAC (GSR, SubCode=IC01.01)
// Expected: resolve về a06Az00000Kuw3EIAR (NOC có RA)

Id actualNocId = 'a0SAz000002Cgn7MAC';
String objName = actualNocId.getSObjectType().getDescribe().getName();
System.debug('Object type = ' + objName);

FEC_Actual_Nature_of_Case__c an = [
    SELECT FEC_Business_Process__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c
    FROM FEC_Actual_Nature_of_Case__c WHERE Id = :actualNocId LIMIT 1
];

List<FEC_Nature_of_Case__c> matchNocs = [
    SELECT Id FROM FEC_Nature_of_Case__c
    WHERE FEC_Business_Process__c = :an.FEC_Business_Process__c
      AND FEC_Category__c = :an.FEC_Category__c
      AND FEC_Sub_Category__c = :an.FEC_Sub_Category__c
      AND FEC_Sub_Code__c = :an.FEC_Sub_Code__c
];
System.debug('Matching NOCs = ' + matchNocs.size());

Set<Id> nocIds = new Set<Id>();
for (FEC_Nature_of_Case__c n : matchNocs) nocIds.add(n.Id);

List<FEC_Routing_Assignment__c> ras = [
    SELECT FEC_Nature_of_Cases__c, FEC_Team__c, FEC_Queue__c
    FROM FEC_Routing_Assignment__c
    WHERE FEC_Nature_of_Cases__c IN :nocIds LIMIT 1
];
System.debug('RA found = ' + ras.size());
if (!ras.isEmpty()) {
    System.debug('Resolved NOC = ' + ras[0].FEC_Nature_of_Cases__c + ' Team=' + ras[0].FEC_Team__c + ' Queue=' + ras[0].FEC_Queue__c);
}
