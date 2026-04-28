// Execute Anonymous script: Search By List Phones
// Usage:
// 1) Open Developer Console -> Debug -> Open Execute Anonymous Window
// 2) Paste this file content and run

List<String> phones = new List<String>{
    '034675XXXXXX'
    // Add more phones here if needed
};

try {
    FEC_SearchByListPhonesServiceCallout.PhonesResponse res =
        FEC_SearchByListPhonesServiceCallout.searchByListPhones(phones);

    System.debug('=== SearchByListPhones Result ===');
    System.debug('sys2.code2: ' + (res != null && res.sys2 != null ? res.sys2.code2 : null));
    System.debug('sys2.description2: ' + (res != null && res.sys2 != null ? res.sys2.description2 : null));
    System.debug('result size: ' + (res != null && res.result != null ? res.result.size() : 0));
    System.debug('full response: ' + JSON.serializePretty(res));
} catch (Exception e) {
    System.debug('=== SearchByListPhones Error ===');
    System.debug('message: ' + e.getMessage());
    System.debug('stack: ' + e.getStackTraceString());
}
