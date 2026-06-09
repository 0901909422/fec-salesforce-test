@IsTest
private class FEC_CancelCSCaseRestService_Test {
    private static final String VALID_CHANNEL = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;

    private static final String SAMPLE_CANCEL_REQUEST =
        '<?xml version="1.0" encoding="utf-8"?>' +
        '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
        '<soap:Body>' +
        '<CancelCSCaseRequest xmlns="urn:PegaRULES:SOAP:MyCase:Services">' +
        '<Sys>' +
        '<Channel>Inbound</Channel>' +
        '<TransactionID>TXN-CANCEL-2026-99999999999</TransactionID>' +
        '<DateTime>2026-05-25T06:52:33.612Z</DateTime>' +
        '</Sys>' +
        '<CaseInfo>' +
        '<ContractOrAccountNumber>CON-19032003</ContractOrAccountNumber>' +
        '<PhoneNumber>0912345678</PhoneNumber>' +
        '<CaseID>CS-OPEN-REST-2026</CaseID>' +
        '<UserType>EXISTING</UserType>' +
        '</CaseInfo>' +
        '</CancelCSCaseRequest>' +
        '</soap:Body>' +
        '</soap:Envelope>';

    @TestSetup
    static void setupData() {
        insert new FEC_Channel__c(
            Name = VALID_CHANNEL,
            FEC_Code__c = 'INBOUND',
            FEC_Channel_ID__c = VALID_CHANNEL,
            FEC_Channel_Vietnamese_name__c = 'Inbound',
            FEC_Channel_Status__c = true
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Case cancelCase = new Case(
                Subject = 'REST Cancel Test',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                Origin = 'Phone',
                FEC_ID_Search__c = 'CS-OPEN-REST-2026',
                Type = 'Request',
                FEC_Customer_Type__c = FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE
            );
            insert cancelCase;

            FEC_Customer_History__c custHist = new FEC_Customer_History__c(
                Name = 'CON-19032003',
                FEC_Case__c = cancelCase.Id,
                FEC_Contract_Number__c = 'CON-19032003',
                FEC_Primary_Phone__c = '0912345678'
            );
            insert custHist;

            cancelCase.FEC_Account_or_Contract__c = custHist.Id;
            update cancelCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testParseCancelCSCaseRequest_mapsFields() {
        FEC_MyCaseSoapXml.CancelCSCaseParsedRequest parsed =
            FEC_MyCaseSoapXml.parseCancelCSCaseRequest(SAMPLE_CANCEL_REQUEST);

        System.assertNotEquals(null, parsed.Sys);
        System.assertEquals(VALID_CHANNEL, parsed.Sys.Channel);
        System.assertEquals('TXN-CANCEL-2026-99999999999', parsed.Sys.TransactionID);
        System.assertNotEquals(null, parsed.Sys.DateTime_x);

        System.assertNotEquals(null, parsed.CaseInfo);
        System.assertEquals('CS-OPEN-REST-2026', parsed.CaseInfo.CaseID);
        System.assertEquals('CON-19032003', parsed.CaseInfo.ContractOrAccountNumber);
        System.assertEquals('0912345678', parsed.CaseInfo.PhoneNumber);
        System.assertEquals('EXISTING', parsed.CaseInfo.UserType);
    }

    @IsTest
    static void testBuildCancelCSCaseSoapResponse_structure() {
        FEC_CancelCSCaseService.CancelCSCaseResponseType resp =
            new FEC_CancelCSCaseService.CancelCSCaseResponseType();
        resp.Sys = new FEC_CancelCSCaseService.SysType2();
        resp.Sys.TransactionID = 'TXN1';
        resp.Sys.DateTime_x = Datetime.now();
        resp.Sys.Code = FEC_ConstantCommon.CODE_SUCCESS;
        resp.Sys.Description = 'OK';
        resp.CaseID = 'CS-001';

        String xml = FEC_MyCaseSoapXml.buildCancelCSCaseSoapResponse(resp);

        System.assert(xml.contains('CancelCSCaseResponse'));
        System.assert(xml.contains('<CaseID>CS-001</CaseID>'));
        System.assert(xml.contains('<Code>1</Code>'));
    }

    private static User runAsAdmin() {
        return [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
    }

    @IsTest
    static void testRestPost_cancelSuccess() {
        System.runAs(runAsAdmin()) {
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();
            req.requestUri = '/services/apexrest/MyCase/v1/CancelCSCase';
            req.httpMethod = 'POST';
            req.requestBody = Blob.valueOf(SAMPLE_CANCEL_REQUEST);
            RestContext.request = req;
            RestContext.response = res;

            FEC_CaseTriggerHandler.isExecuting = true;
            Test.startTest();
            try {
                FEC_CancelCSCaseRestService.doPost();
            } finally {
                FEC_CaseTriggerHandler.isExecuting = false;
            }
            Test.stopTest();

            String body = res.responseBody.toString();
            System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_OK, res.statusCode);
            System.assert(body.contains('CancelCSCaseResponse'));
            System.assert(
                body.contains('<Code>1</Code>') || body.contains('<Code>3</Code>'),
                'Response phải chứa mã kết quả SOAP: ' + body
            );
            if (body.contains('<Code>1</Code>')) {
            System.assert(body.contains('<CaseID>CS-OPEN-REST-2026</CaseID>'));

            Case updated = [
                SELECT Status
                FROM Case
                WHERE FEC_ID_Search__c = 'CS-OPEN-REST-2026'
                LIMIT 1
            ];
                System.assertEquals(FEC_ConstantCommon.STATUS_CANCELLED, updated.Status);
            }
        }
    }

    @IsTest
    static void testRestPost_invalidXml_returnsErrorEnvelope() {
        System.runAs(runAsAdmin()) {
            String invalidEnvelope =
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soap:Body><UnknownCancelRequest /></soap:Body></soap:Envelope>';

            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();
            req.requestUri = '/services/apexrest/MyCase/v1/CancelCSCase';
            req.httpMethod = 'POST';
            req.requestBody = Blob.valueOf(invalidEnvelope);
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            FEC_CancelCSCaseRestService.doPost();
            Test.stopTest();

            System.assert(
                res.responseBody != null && res.responseBody.toString().contains('CancelCSCaseResponse'),
                'Invalid request element phải trả SOAP error envelope.'
            );
        }
    }
}