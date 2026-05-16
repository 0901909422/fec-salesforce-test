// Tìm NID có data trong FEC_Customer_History__c
List<FEC_Customer_History__c> histories = [
    SELECT Id, FEC_National_ID_Passport_ID__c, FEC_Buyer_NID__c, FEC_Primary_Phone__c, FEC_Customer_Name__c
    FROM FEC_Customer_History__c
    WHERE FEC_National_ID_Passport_ID__c != null
    ORDER BY LastModifiedDate DESC
    LIMIT 5
];
for (FEC_Customer_History__c h : histories) {
    System.debug('NID: ' + h.FEC_National_ID_Passport_ID__c + ' | BuyerNID: ' + h.FEC_Buyer_NID__c + ' | Phone: ' + h.FEC_Primary_Phone__c + ' | Name: ' + h.FEC_Customer_Name__c);
}

// Test Banca với NID từ ảnh kịch bản
List<String> testNIDs = new List<String>{ '230123789' };
try {
    List<FEC_GetBancaInsurance.InsuranceResult> results = FEC_GetBancaInsurance.searchByNIDs(testNIDs);
    System.debug('Banca results: ' + results.size());
    for (FEC_GetBancaInsurance.InsuranceResult r : results) {
        System.debug('userId=' + r.userId + ' | name=' + r.buyerName + ' | product=' + r.productNameEn + ' | status=' + r.statusDisplay);
    }
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
}
