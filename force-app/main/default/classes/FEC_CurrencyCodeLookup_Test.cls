@IsTest
private class FEC_CurrencyCodeLookup_Test {

    @TestSetup
    static void setupData() {
        // Tạo dữ liệu mồi cho Custom Object FEC_Currency_Code__c
        List<FEC_Currency_Code__c> testCurrencies = new List<FEC_Currency_Code__c>{
            new FEC_Currency_Code__c(Name = 'AFN', FEC_Currency_Code__c = '971'),
            new FEC_Currency_Code__c(Name = 'EUR', FEC_Currency_Code__c = '978'),
            new FEC_Currency_Code__c(Name = 'VND', FEC_Currency_Code__c = '704')
        };
        insert testCurrencies;
    }

    @IsTest
    static void testBuildNumericCodeToDisplayMap_Success() {
        Set<String> codesToSearch = new Set<String>{'971', '704', '999'}; // 999 là mã không tồn tại

        Test.startTest();
        Map<String, String> resultMap = FEC_CurrencyCodeLookup.buildNumericCodeToDisplayMap(codesToSearch);
        Test.stopTest();

        // Xác thực kết quả
        System.assertEquals(2, resultMap.size(), 'Chỉ nên tìm thấy 2 mã khớp trong database.');
        System.assertEquals('971-AFN', resultMap.get('971'), 'Kết quả mapping phải có định dạng Code-Name.');
        System.assertEquals('704-VND', resultMap.get('704'), 'Kết quả mapping phải có định dạng Code-Name.');
        System.assertEquals(null, resultMap.get('999'), 'Mã không tồn tại không nên có trong Map.');
    }

    @IsTest
    static void testBuildNumericCodeToDisplayMap_EmptyInput() {
        Test.startTest();
        Map<String, String> emptyMap = FEC_CurrencyCodeLookup.buildNumericCodeToDisplayMap(new Set<String>());
        Map<String, String> nullMap = FEC_CurrencyCodeLookup.buildNumericCodeToDisplayMap(null);
        Test.stopTest();

        System.assertEquals(0, emptyMap.size(), 'Input rỗng phải trả về Map rỗng.');
        System.assertEquals(0, nullMap.size(), 'Input null phải trả về Map rỗng.');
    }

    @IsTest
    static void testBuildNumericCodeToDisplayMap_Normalization() {
        // Kiểm tra logic trim() mã code
        Set<String> codesWithSpaces = new Set<String>{' 971 ', '  704'};

        Test.startTest();
        Map<String, String> resultMap = FEC_CurrencyCodeLookup.buildNumericCodeToDisplayMap(codesWithSpaces);
        Test.stopTest();

        System.assert(resultMap.containsKey('971'), 'Mã code cần được trim() để khớp.');
        System.assert(resultMap.containsKey('704'), 'Mã code cần được trim() để khớp.');
    }
}