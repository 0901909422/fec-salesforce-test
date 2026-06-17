@IsTest
private class FEC_FetchCollectDataServiceCallout_Test {

    @IsTest
    static void testFetchCollectionData_Success() {
        // 1. Giả lập JSON trả về từ API
        String jsonResponse = '{' +
            '"Success": "true",' +
            '"AllocationHistory": [{"POS": "1", "AllocationDate": "2026-03-30"}],' +
            '"CommunicationHistory": [{"ContractNumber": "20161129-0006618"}],' +
            '"InteractionHistory": [{"InteractedCode": "C01"}],' +
            '"NFUDetailsList": [{"NFUStatus": "Active"}]' +
        '}';

        // 2. Thiết lập Mock Callout (Cần đảm bảo FEC_CommonUltils.calloutApiWithHeaders hỗ trợ Test.setMock)
        // Nếu FEC_CommonUltils dùng Http.send(), Test.setMock sẽ hoạt động.
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, jsonResponse));

        Test.startTest();
        FEC_FetchCollectionDataServiceCallout.CollectionDataResponse res = 
            FEC_FetchCollectionDataServiceCallout.fetchCollectionData('20161129', 'COLLECTION', null);
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals('true', res.Success);
        System.assertEquals(1, res.AllocationHistory.size());
        System.assertEquals('1', res.AllocationHistory[0].POS);
    }

    @IsTest
    static void testFetchCollectionData_Error() {
        // Mock lỗi server
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        Test.startTest();
        FEC_FetchCollectionDataServiceCallout.CollectionDataResponse res = 
            FEC_FetchCollectionDataServiceCallout.fetchCollectionData('20161129', 'COLLECTION', null);
        Test.stopTest();

        System.assertEquals('false', res.Success);
    }

    @IsTest
    static void testFetchCollectionData_CardUsesAccountNumberForAnyRecordType() {
        FEC_Product_Type__c cardProduct = new FEC_Product_Type__c(
            Name = FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE,
            FEC_Code__c = 'CARD',
            FEC_Active__c = true
        );
        insert cardProduct;

        Case c = new Case(
            Subject = 'Card Collection',
            FEC_Contract_Number__c = 'CONTRACT-999',
            FEC_Account_Number__c = 'ACC-123456789',
            FEC_Product_Type__c = cardProduct.Id
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.setMock(HttpCalloutMock.class, new EndpointAssertMock('ACC-123456789'));

        Test.startTest();
        FEC_FetchCollectionDataServiceCallout.CollectionDataResponse res =
            FEC_FetchCollectionDataServiceCallout.fetchCollectionData(
                'CONTRACT-999',
                System.Label.Fetch_Collection_Data_Record_Type_Allocation_History,
                c.Id
            );
        Test.stopTest();

        System.assertEquals('true', res.Success);
    }

    @IsTest
    static void testResolveContractNumberForApi_withoutCaseIdKeepsContractNumber() {
        System.assertEquals(
            'CONTRACT-001',
            FEC_FetchCollectionDataServiceCallout.resolveContractNumberForApi(
                'CONTRACT-001',
                null
            )
        );
    }

    // Helper class để Mock HTTP Response
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        Integer code;
        String body;
        MockHttpResponseGenerator(Integer code, String body) {
            this.code = code;
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.code);
            res.setBody(this.body);
            return res;
        }
    }

    private class EndpointAssertMock implements HttpCalloutMock {
        String expectedContractNumber;
        EndpointAssertMock(String expectedContractNumber) {
            this.expectedContractNumber = expectedContractNumber;
        }
        public HttpResponse respond(HttpRequest req) {
            System.assert(
                req.getEndpoint().contains('ContractNumber=' + expectedContractNumber),
                'Expected account number in endpoint: ' + req.getEndpoint()
            );
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"Success":"true","NFUDetailsList":[{"NFUStatus":"N"}]}');
            return res;
        }
    }
}