// Debug: gọi getCustomerList với Account Number để xem NID trả về
FEC_GetCustomerList.ResponseWrapper result = FEC_GetCustomerList.getCustomerList(
    FEC_ConstantCommon.REQUESTOR_CRM,
    null,   // phone
    false,  // isReferenceSearch
    null,   // fullName
    null,   // nationalId
    null,   // applicationId
    null,   // creditCardNumber
    '0001500020000064941', // accountNumber
    null,   // contractNumber
    null,   // email
    null    // personId
);

if (result == null) {
    System.debug('getCustomerList returned null');
} else {
    System.debug('Customers count: ' + (result.Customers != null ? result.Customers.size() : 0));
    if (result.Customers != null) {
        for (FEC_GetCustomerList.Customer c : result.Customers) {
            System.debug('Customer: ' + c.FullName + ' | NID: ' + c.NationalID + ' | CIF: ' + c.CIFNumber);
            if (c.Applications != null) {
                for (FEC_GetCustomerList.Application app : c.Applications) {
                    System.debug('  App: ' + app.ApplicationID + ' | Product: ' + app.Product + ' | AccountNum: ' + app.AccountNumber);
                }
            }
        }
        
        // Collect NIDs và test Banca
        List<String> nids = new List<String>();
        for (FEC_GetCustomerList.Customer c : result.Customers) {
            if (String.isNotBlank(c.NationalID)) nids.add(c.NationalID);
        }
        System.debug('NIDs to search Banca: ' + nids);
        
        if (!nids.isEmpty()) {
            List<FEC_GetBancaInsurance.InsuranceResult> bancaResults = FEC_GetBancaInsurance.searchByNIDs(nids);
            System.debug('Banca results: ' + bancaResults.size());
            for (FEC_GetBancaInsurance.InsuranceResult r : bancaResults) {
                System.debug('Banca: userId=' + r.userId + ' | name=' + r.buyerName + ' | product=' + r.productNameEn);
            }
        }
    }
}
