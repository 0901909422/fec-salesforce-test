// Fix case 00004724: set ActualNOC đúng cho COF CC01.01
// Tìm FEC_Actual_Nature_of_Case__c có BP = COF và Sub_Code = CC01.01

List<FEC_Actual_Nature_of_Case__c> cofActualNocs = [
    SELECT Id, Name, FEC_Business_Process__r.FEC_Code__c, FEC_Sub_Code__r.FEC_Code__c
    FROM FEC_Actual_Nature_of_Case__c
    WHERE FEC_Business_Process__r.FEC_Code__c LIKE 'COF%'
      AND FEC_Sub_Code__r.FEC_Code__c = 'CC01.01'
    LIMIT 5
];
System.debug('COF CC01.01 ActualNOCs = ' + cofActualNocs.size());
for (FEC_Actual_Nature_of_Case__c an : cofActualNocs) {
    System.debug('  ActualNOC Id=' + an.Id + ' BP=' + an.FEC_Business_Process__r?.FEC_Code__c + ' SubCode=' + an.FEC_Sub_Code__r?.FEC_Code__c);
}

if (!cofActualNocs.isEmpty()) {
    // Update case với ActualNOC đúng
    update new Case(Id = '500Az00000OJ1XFIA1', FEC_Actual_Nature_of_Case__c = cofActualNocs[0].Id);
    System.debug('Updated case ActualNOC to ' + cofActualNocs[0].Id);
}
