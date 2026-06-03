@IsTest
private class FEC_MarkNFU_Test {

    private static final String CONTRACT_DISPLAY = 'CNT123';

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        Case c = new Case(
            Subject = 'FEC_MarkNFU_Test',
            Status = 'New',
            FEC_ID_Search__c = 'NFU-' + suffix
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c cust = new FEC_Customer_History__c(
            Name = CONTRACT_DISPLAY,
            FEC_Case__c = c.Id,
            FEC_Contract_Number__c = CONTRACT_DISPLAY
        );
        insert cust;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Account_or_Contract__c = cust.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_Hold_Case_Config__c(FEC_NFU_Code__c = 'REASON01');

        insert new FEC_API_Setting__c(
            FEC_Call_Mock__c = false,
            FEC_Endpoint__c = 'https://test-api.fecredit.com.vn'
        );
    }

    private static User adminUser() {
        List<User> admins = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        return admins.isEmpty() ? new User(Id = UserInfo.getUserId()) : admins[0];
    }

    @IsTest
    static void testMarkNFUByRecordIds_Success() {
        if (Type.forName('FEC_MarkNFU') == null) {
            System.assert(true, 'Skipped: FEC_MarkNFU not on org.');
            return;
        }

        System.runAs(adminUser()) {
            Case c = [
                SELECT Id, FEC_Account_Contract_Number_Text__c
                FROM Case
                LIMIT 1
            ];
            FEC_Hold_Case_Config__c config = [SELECT Id FROM FEC_Hold_Case_Config__c LIMIT 1];

            System.assertEquals(
                CONTRACT_DISPLAY,
                c.FEC_Account_Contract_Number_Text__c,
                'Formula must resolve Customer History Name.'
            );

            Test.setMock(
                HttpCalloutMock.class,
                new MarkNFUHttpCalloutMock(
                    200,
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><MarkNFUResponse>' +
                    '<Code>0</Code><Description>Success</Description>' +
                    '</MarkNFUResponse></soapenv:Body></soapenv:Envelope>'
                )
            );

            Test.startTest();
            FEC_MarkNFU.MarkNFUResult result =
                FEC_MarkNFU.markNFUByRecordIds(c.Id, config.Id);
            Test.stopTest();

            System.assertEquals(true, result.success);
            System.assertEquals('Success', result.description);
        }
    }

    @IsTest
    static void testBuildEnvelope_Validation() {
        if (Type.forName('FEC_MarkNFU') == null) {
            System.assert(true, 'Skipped: FEC_MarkNFU not on org.');
            return;
        }

        FEC_MarkNFU.MarkNFURequest req = new FEC_MarkNFU.MarkNFURequest();

        Test.startTest();
        try {
            FEC_MarkNFU.buildEnvelope(req);
            System.assert(false, 'Expected exception when ContractNumber is missing.');
        } catch (Exception e) {
            System.assert(e instanceof FEC_APIServiceException);
        }
        Test.stopTest();
    }

    private class MarkNFUHttpCalloutMock implements HttpCalloutMock {
        Integer code;
        String body;

        MarkNFUHttpCalloutMock(Integer code, String body) {
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
}
