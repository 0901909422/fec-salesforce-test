@IsTest
private class FEC_FetchWelcomeCallDetailsRest_Test {

    private static final String CONTRACT_FOUND = 'WC-CONTRACT-001';
    private static final String CONTRACT_NOT_FOUND = 'WC-CONTRACT-MISSING';
    private static final String REQUESTOR_ID = 'PegaCollection';

    @TestSetup
    static void setupData() {
        FEC_Business_Process__c welcomeProcess = new FEC_Business_Process__c(
            Name = 'Welcome Call',
            FEC_Code__c = 'WELCOMECALL',
            FEC_Active__c = true
        );
        FEC_Category__c category = new FEC_Category__c(
            Name = FEC_ConstantCommon.FEC_CATEGORY_REQUEST,
            FEC_Code__c = 'Request',
            FEC_Active__c = true
        );
        insert new List<SObject>{ welcomeProcess, category };

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            List<Case> caseRecords = new List<Case>{
                new Case(
                    Subject = 'Welcome Call REST Test 1',
                    Status = 'New',
                    FEC_Contract_Number__c = CONTRACT_FOUND,
                    FEC_Customer_Name__c = 'Welcome Customer',
                    FEC_Phone_Number__c = '0901234567',
                    FEC_Business_Process__c = welcomeProcess.Id,
                    FEC_Category__c = category.Id,
                    FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME
                ),
                new Case(
                    Subject = 'Welcome Call REST Test 2',
                    Status = 'Working',
                    FEC_Contract_Number__c = CONTRACT_FOUND,
                    FEC_Customer_Name__c = 'Welcome Customer 2',
                    FEC_Phone_Number__c = '0909999999',
                    FEC_Business_Process__c = welcomeProcess.Id,
                    FEC_Category__c = category.Id,
                    FEC_Channel__c = FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME
                )
            };
            insert caseRecords;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testPost_dataFound_code0_returnsAllMatchedCases() {
        String body = JSON.serialize(new Map<String, Object>{
            'RequestorID' => REQUESTOR_ID,
            'TransID' => 'TXN-WC-001',
            'DateTime' => '20260525T120000.000 GMT',
            'ContractNumber' => CONTRACT_FOUND
        });

        RestResponse res = invokePost(body);

        System.assertEquals(200, res.statusCode);
        FEC_FetchWelcomeCallDetailsRestService.FetchWelcomeCallDetailsResponse parsed =
            parseResponse(res);

        System.assertEquals('0', parsed.Sys.Code);
        System.assertEquals('Data-Found', parsed.Sys.Description);
        System.assertNotEquals(null, parsed.WelcomeCallCaseDetails);
        System.assertEquals(2, parsed.WelcomeCallCaseDetails.size());
        System.assertEquals(CONTRACT_FOUND, parsed.WelcomeCallCaseDetails[0].ContractNumber);
        System.assertEquals(CONTRACT_FOUND, parsed.WelcomeCallCaseDetails[1].ContractNumber);
        System.assertEquals(null, parsed.WelcomeCallCaseDetails[0].SubCategory);
        System.assertEquals(null, parsed.WelcomeCallCaseDetails[1].SubCategory);

        Map<String, Object> envelope = (Map<String, Object>) JSON.deserializeUntyped(
            res.responseBody.toString()
        );
        List<Object> detailMaps = (List<Object>) envelope.get('WelcomeCallCaseDetails');
        Set<String> categories = new Set<String>();
        Set<String> channels = new Set<String>();
        for (Object detailObj : detailMaps) {
            Map<String, Object> detailMap = (Map<String, Object>) detailObj;
            categories.add((String) detailMap.get('SCCategory'));
            channels.add((String) detailMap.get('ChannelID'));
        }
        System.assertEquals(
            new Set<String>{ FEC_ConstantCommon.FEC_CATEGORY_REQUEST },
            categories
        );
        System.assertEquals(
            new Set<String>{
                FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
                FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME
            },
            channels
        );
    }

    @IsTest
    static void testPost_dataNotFound_code1() {
        String body = JSON.serialize(new Map<String, Object>{
            'RequestorID' => REQUESTOR_ID,
            'TransID' => 'TXN-WC-002',
            'ContractNumber' => CONTRACT_NOT_FOUND
        });

        RestResponse res = invokePost(body);

        System.assertEquals(200, res.statusCode);
        FEC_FetchWelcomeCallDetailsRestService.FetchWelcomeCallDetailsResponse parsed =
            parseResponse(res);

        System.assertEquals('1', parsed.Sys.Code);
        System.assertEquals('Data not found', parsed.Sys.Description);
        System.assertEquals(null, parsed.WelcomeCallCaseDetails);
    }

    @IsTest
    static void testPost_blankContract_codeMinus1_http400() {
        String body = JSON.serialize(new Map<String, Object>{
            'RequestorID' => REQUESTOR_ID,
            'TransID' => 'TXN-WC-003',
            'ContractNumber' => ''
        });

        RestResponse res = invokePost(body);

        System.assertEquals(400, res.statusCode);
        FEC_FetchWelcomeCallDetailsRestService.FetchWelcomeCallDetailsResponse parsed =
            parseResponse(res);

        System.assertEquals('-1', parsed.Sys.Code);
        System.assertEquals('Contract number is blank', parsed.Sys.Description);
    }

    @IsTest
    static void testPost_cannotOpenCase_codeMinus2_http200() {
        FEC_FetchWelcomeCallDetailsRestService.simulateCannotOpenCase = true;
        try {
            String body = JSON.serialize(new Map<String, Object>{
                'RequestorID' => REQUESTOR_ID,
                'TransID' => 'TXN-WC-004',
                'ContractNumber' => CONTRACT_FOUND
            });

            RestResponse res = invokePost(body);

            System.assertEquals(200, res.statusCode);
            FEC_FetchWelcomeCallDetailsRestService.FetchWelcomeCallDetailsResponse parsed =
                parseResponse(res);

            System.assertEquals('-2', parsed.Sys.Code);
            System.assertEquals('Cannot open Case details', parsed.Sys.Description);
            System.assertEquals(null, parsed.WelcomeCallCaseDetails);
        } finally {
            FEC_FetchWelcomeCallDetailsRestService.simulateCannotOpenCase = false;
        }
    }

    @IsTest
    static void testFormatResponseDateTime() {
        String requestDateTime = '20260525T120000.000 GMT';
        String formatted = FEC_FetchWelcomeCallDetailsRestService.formatResponseDateTime(
            requestDateTime
        );
        System.assertEquals(requestDateTime, formatted);
    }

    private static RestResponse invokePost(String body) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/collections/v1/welcome-call-details';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_FetchWelcomeCallDetailsRestService.doPost();
        Test.stopTest();

        return res;
    }

    private static FEC_FetchWelcomeCallDetailsRestService.FetchWelcomeCallDetailsResponse parseResponse(
        RestResponse res
    ) {
        return (FEC_FetchWelcomeCallDetailsRestService.FetchWelcomeCallDetailsResponse) JSON.deserialize(
            res.responseBody.toString(),
            FEC_FetchWelcomeCallDetailsRestService.FetchWelcomeCallDetailsResponse.class
        );
    }
}