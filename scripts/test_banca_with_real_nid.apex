// Test Banca Insurance với NID thực từ Customer History
List<String> testNIDs = new List<String>{
    'D088796877',
    'D114089516',
    'D109701085',
    'D088020942'
};

try {
    List<FEC_GetBancaInsurance.InsuranceResult> results = FEC_GetBancaInsurance.searchByNIDs(testNIDs);
    System.debug('Banca results count: ' + results.size());
    for (FEC_GetBancaInsurance.InsuranceResult r : results) {
        System.debug('userId=' + r.userId + ' | name=' + r.buyerName + ' | NID=' + r.buyerNID + ' | product=' + r.productNameEn + ' | status=' + r.statusDisplay);
    }
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
}
