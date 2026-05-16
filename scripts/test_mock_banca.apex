// Bật mock và test
FEC_API_Setting__c setting = FEC_API_Setting__c.getOrgDefaults();
System.debug('FEC_Call_Mock__c: ' + setting.FEC_Call_Mock__c);

// Test mock trực tiếp
List<String> nids = new List<String>{ 'TEST123' };
List<FEC_SearchByListNIDs.InsuranceResult> results = FEC_SearchByListNIDs.searchByNIDs(nids);
System.debug('Mock results: ' + results.size());
for (FEC_SearchByListNIDs.InsuranceResult r : results) {
    System.debug('userId=' + r.userId + ' | product=' + r.productNameEn + ' | status=' + r.statusDisplay);
}
