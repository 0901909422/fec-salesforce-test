// Test gọi Banca Insurance API với NID từ ảnh sample
List<String> testNIDs = new List<String>{ '0812345678' };
try {
    List<FEC_GetBancaInsurance.InsuranceResult> results = FEC_GetBancaInsurance.searchByNIDs(testNIDs);
    System.debug('Results count: ' + results.size());
    for (FEC_GetBancaInsurance.InsuranceResult r : results) {
        System.debug('userId=' + r.userId + ' | buyerName=' + r.buyerName + ' | product=' + r.productNameEn + ' | status=' + r.statusDisplay);
    }
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
    System.debug('Type: ' + e.getTypeName());
}
