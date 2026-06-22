@IsTest
private class FEC_CmsVmxIntegrationService_Test {

    @TestSetup
    static void setup() {
        insert new FEC_API_Setting__c(
            FEC_Endpoint__c = 'https://api.test.com',
            FEC_Enviroment__c = 'Production'
        );
    }

    private class ChainedCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String body = req.getBody();
            if (body != null && body.contains('M_CMS_CARD_TO_CARD_INQ_EMEA')) {
                res.setBody(
                    '<?xml version="1.0" encoding="UTF-8"?>' +
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><WSResponse>' +
                    '<Sys><TransID>T-CARD</TransID><Code>1</Code><Description>Success</Description></Sys>' +
                    '<M_CMS_CARD_TO_CARD_INQ_EMEA><VMX_ROOT><VMX_MSGOUT>' +
                    '<SVC_RETURN>S</SVC_RETURN><OUTPUT_AREA><OUTPUT_DATA>' +
                    '<CARD_NBR>4111111111111111</CARD_NBR><BLK_CD>O</BLK_CD>' +
                    '</OUTPUT_DATA></OUTPUT_AREA>' +
                    '</VMX_MSGOUT></VMX_ROOT></M_CMS_CARD_TO_CARD_INQ_EMEA>' +
                    '</WSResponse></soapenv:Body></soapenv:Envelope>'
                );
            } else {
                res.setBody(
                    '<?xml version="1.0" encoding="UTF-8"?>' +
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><WSResponse>' +
                    '<Sys><TransID>T1</TransID><Code>1</Code><Description>Success</Description></Sys>' +
                    '<VMX_NONMON_UPD><VMX_ROOT><VMX_MSGOUT><SVC_RETURN>P</SVC_RETURN></VMX_MSGOUT></VMX_ROOT></VMX_NONMON_UPD>' +
                    '</WSResponse></soapenv:Body></soapenv:Envelope>'
                );
            }
            return res;
        }
    }

    private class VmxNonmonOnlyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<?xml version="1.0" encoding="UTF-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><WSResponse>' +
                '<Sys><TransID>T1</TransID><Code>1</Code><Description>Success</Description></Sys>' +
                '<VMX_NONMON_UPD><VMX_ROOT><VMX_MSGOUT><SVC_RETURN>P</SVC_RETURN></VMX_MSGOUT></VMX_ROOT></VMX_NONMON_UPD>' +
                '</WSResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    @IsTest
    static void testOnCmsOperationSuccess_BlockCard_ReturnsResult() {
        Case c = new Case(
            Subject = 'Test',
            FEC_Account_Number__c = '0001500080001514285',
            FEC_New_Block_Code__c = 'S',
            FEC_ID_Search__c = 'S-73028115',
            FEC_Customer_Name__c = 'Test Customer'
        );
        insert c;

        Test.setMock(HttpCalloutMock.class, new ChainedCalloutMock());

        Test.startTest();
        FEC_VmxNonmonUpdCallout.NonmonUpdResult result = FEC_CmsVmxIntegrationService.onCmsOperationSuccess(
            c.Id,
            FEC_CmsVmxIntegrationService.OP_BLOCK_CARD
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('1', result.responseCode);
    }

    @IsTest
    static void testOnCmsOperationSuccess_PinReset_SingleCallout() {
        Case c = new Case(
            Subject = 'Test',
            FEC_Account_Number__c = '0001500080001514285',
            FEC_ID_Search__c = 'S-73028115'
        );
        insert c;

        Test.setMock(HttpCalloutMock.class, new VmxNonmonOnlyMock());

        Test.startTest();
        FEC_VmxNonmonUpdCallout.NonmonUpdResult result = FEC_CmsVmxIntegrationService.onCmsOperationSuccess(
            c.Id,
            FEC_CmsVmxIntegrationService.OP_PIN_RESET
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('1', result.responseCode);
    }

    @IsTest
    static void testOnCmsOperationSuccess_NullCaseId() {
        Test.startTest();
        Object result = FEC_CmsVmxIntegrationService.onCmsOperationSuccess(null, FEC_CmsVmxIntegrationService.OP_BLOCK_CARD);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @IsTest
    static void testOnCmsOperationSuccess_BlankOperationType() {
        Case c = new Case(Subject = 'Test', FEC_Account_Number__c = '0001500080001514285');
        insert c;

        Test.startTest();
        Object result = FEC_CmsVmxIntegrationService.onCmsOperationSuccess(c.Id, '');
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @IsTest
    static void testOnCmsOperationSuccess_CaseNotFound() {
        Case c = new Case(Subject = 'Test', FEC_Account_Number__c = '0001500080001514285');
        insert c;
        Id deletedCaseId = c.Id;
        delete c;

        Test.startTest();
        Object result = FEC_CmsVmxIntegrationService.onCmsOperationSuccess(deletedCaseId, FEC_CmsVmxIntegrationService.OP_UNBLOCK_CARD);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @IsTest
    static void testBuildMemoFormatting() {
        String idSearch = 'S-73028115';

        System.assert(
            FEC_CmsVmxIntegrationService.buildMemo1(idSearch, FEC_CmsVmxIntegrationService.OP_BLOCK_CARD)
                .endsWith('-Action Block Card-' + idSearch)
        );
        System.assert(
            FEC_CmsVmxIntegrationService.buildMemo1(idSearch, FEC_CmsVmxIntegrationService.OP_UNBLOCK_CARD)
                .endsWith('-Action Unblock Card-' + idSearch)
        );
        System.assert(
            FEC_CmsVmxIntegrationService.buildMemo1(idSearch, FEC_CmsVmxIntegrationService.OP_PIN_RESET)
                .endsWith('-Action Reset PIN-' + idSearch)
        );
        System.assert(
            FEC_CmsVmxIntegrationService.buildMemo1(idSearch, FEC_CmsVmxIntegrationService.OP_PIN_REPLACEMENT)
                .endsWith('-Action Reissue PIN-' + idSearch)
        );
        System.assert(
            FEC_CmsVmxIntegrationService.buildMemo1(idSearch, FEC_CmsVmxIntegrationService.OP_CARD_REPLACEMENT)
                .endsWith('-Action Replace Card-' + idSearch)
        );

        System.assertEquals(
            'Old Block Code = O New Block Code =S',
            FEC_CmsVmxIntegrationService.buildMemo2(
                FEC_CmsVmxIntegrationService.OP_BLOCK_CARD,
                'S',
                'O'
            )
        );
        System.assertEquals(
            'Old Block Code =(null)  New Block Code = (null)',
            FEC_CmsVmxIntegrationService.buildMemo2(
                FEC_CmsVmxIntegrationService.OP_PIN_RESET,
                'S',
                'O'
            )
        );
        System.assertEquals(
            'Old Block Code =O New Block Code =(null)',
            FEC_CmsVmxIntegrationService.buildMemo2(
                FEC_CmsVmxIntegrationService.OP_CARD_REPLACEMENT,
                'S',
                'O'
            )
        );
    }

    @IsTest
    static void testExtractCurrentBlockCode_MatchesLast4() {
        FEC_MCMSCARDTOCARDINQEMEA.ResponseWrapper response = new FEC_MCMSCARDTOCARDINQEMEA.ResponseWrapper();
        response.VMXMsgOut = new FEC_MCMSCARDTOCARDINQEMEA.VMXMsgOut();
        response.VMXMsgOut.OUTPUT_AREA = new FEC_MCMSCARDTOCARDINQEMEA.OutputArea();
        FEC_MCMSCARDTOCARDINQEMEA.OutputData match = new FEC_MCMSCARDTOCARDINQEMEA.OutputData();
        match.CARD_NBR = '4111111111111111';
        match.BLK_CD = 'C';
        FEC_MCMSCARDTOCARDINQEMEA.OutputData other = new FEC_MCMSCARDTOCARDINQEMEA.OutputData();
        other.CARD_NBR = '4222222222222222';
        other.BLK_CD = 'O';
        response.VMXMsgOut.OUTPUT_AREA.OUTPUT_DATA = new List<FEC_MCMSCARDTOCARDINQEMEA.OutputData>{ other, match };

        System.assertEquals(
            'C',
            FEC_CmsVmxIntegrationService.extractCurrentBlockCode(response, '1111')
        );
    }

    @IsTest
    static void testBuildMemo1_InvalidOperationType() {
        Test.startTest();
        try {
            FEC_CmsVmxIntegrationService.buildMemo1('S-73028115', 'INVALID');
            System.assert(false, 'Expected invalid operation type exception');
        } catch (CalloutException e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}
