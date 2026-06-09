@IsTest
private class FEC_GetCSAttachedFileRestService_Test {
    private static final String CASE_SEARCH_ID = 'CSA-REST-2026';
    private static final String VALID_CHANNEL =
        FEC_ConstantCommon.CANCEL_CS_VALID_CHANNELS_ORDERED[0];

    private static String buildSampleRequest(String caseId, String fileId) {
        return '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<GetCSAttachedFileRequest xmlns="urn:PegaRULES:SOAP:MyCase:Services">' +
            '<Sys>' +
            '<Channel>' + VALID_CHANNEL + '</Channel>' +
            '<TransactionID>TXN-GET-FILE-2026-99999999999</TransactionID>' +
            '<DateTime>2026-05-25T06:52:33.615Z</DateTime>' +
            '</Sys>' +
            '<RequestInfo>' +
            '<ContractOrAccountInfos>' +
            '<ContractOrAccountNumber>CTR123</ContractOrAccountNumber>' +
            '<ProductType>CARD</ProductType>' +
            '</ContractOrAccountInfos>' +
            '<PhoneNumber>0912345678</PhoneNumber>' +
            '<UserType>EXISTING</UserType>' +
            '<CaseID>' + caseId + '</CaseID>' +
            '<FileID>' + fileId + '</FileID>' +
            '</RequestInfo>' +
            '</GetCSAttachedFileRequest>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }

    @TestSetup
    static void setupData() {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                Subject = 'REST Attached File Test',
                Status = 'New',
                FEC_ID_Search__c = CASE_SEARCH_ID,
                FEC_Customer_Type__c = FEC_ConstantCommon.CASE_EXISTING_CUSTOMER,
                FEC_Contract_Number__c = 'CTR123'
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        ContentVersion cv = new ContentVersion(
            Title = 'RestTestFile',
            PathOnClient = 'rest-test.pdf',
            VersionData = Blob.valueOf('REST file content'),
            IsMajorVersion = true
        );
        insert cv;

        Id docId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ].ContentDocumentId;
        Case c = [SELECT Id FROM Case WHERE FEC_ID_Search__c = :CASE_SEARCH_ID LIMIT 1];

        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = c.Id,
            ShareType = 'V'
        );
    }

    @IsTest
    static void testParseGetCSAttachedFileRequest_mapsFields() {
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;
        FEC_MyCaseSoapXml.GetCSAttachedFileParsedRequest parsed =
            FEC_MyCaseSoapXml.parseGetCSAttachedFileRequest(
                buildSampleRequest(CASE_SEARCH_ID, String.valueOf(docId))
            );

        System.assertNotEquals(null, parsed.Sys);
        System.assertEquals(VALID_CHANNEL, parsed.Sys.Channel);
        System.assertEquals('TXN-GET-FILE-2026-99999999999', parsed.Sys.TransactionID);
        System.assertNotEquals(null, parsed.Sys.DateTime_x);

        System.assertNotEquals(null, parsed.RequestInfo);
        System.assertEquals(CASE_SEARCH_ID, parsed.RequestInfo.CaseID);
        System.assertEquals(
            FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE,
            parsed.RequestInfo.UserType
        );
        System.assertEquals(String.valueOf(docId), parsed.RequestInfo.FileID);
        System.assertEquals('CTR123', parsed.RequestInfo.ContractOrAccountInfos.ContractOrAccountNumber);
        System.assertEquals('CARD', parsed.RequestInfo.ContractOrAccountInfos.ProductType);
    }

    @IsTest
    static void testBuildGetCSAttachedFileSoapResponse_structure() {
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType resp =
            new FEC_GetCSAttachedFile.GetCSAttachedFileResponseType();
        resp.Sys = new FEC_GetCSAttachedFile.SysType2();
        resp.Sys.TransactionID = 'TXN1';
        resp.Sys.DateTime_x = System.now();
        resp.Sys.Code = FEC_ConstantCommon.CODE_SUCCESS;
        resp.Sys.Description = FEC_ConstantCommon.SUCCESS_MESSAGE;
        resp.FileName = 'sample.pdf';
        resp.FileType = 'pdf';
        resp.FileContent = EncodingUtil.base64Encode(Blob.valueOf('data'));

        String xml = FEC_MyCaseSoapXml.buildGetCSAttachedFileSoapResponse(resp);

        System.assert(xml.contains('GetCSAttachedFileResponse'));
        System.assert(xml.contains('<Code>1</Code>'));
        System.assert(xml.contains('<FileName>sample.pdf</FileName>'));
        System.assert(xml.contains('<FileType>pdf</FileType>'));
    }

    @IsTest
    static void testRestPost_getAttachedFileSuccess() {
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/MyCase/v1/GetCSAttachedFile';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(
            buildSampleRequest(CASE_SEARCH_ID, String.valueOf(docId))
        );
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_GetCSAttachedFileRestService.doPost();
        Test.stopTest();

        String body = res.responseBody.toString();
        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_OK, res.statusCode);
        System.assert(body.contains('GetCSAttachedFileResponse'));
        System.assert(body.contains('<Code>1</Code>'), body);
        System.assert(body.contains('<FileName>RestTestFile</FileName>'));
        System.assert(body.contains('<FileType>pdf</FileType>'));
    }

    @IsTest
    static void testBuildGetCSAttachedFileErrorSoapResponse() {
        String xml = FEC_MyCaseSoapXml.buildGetCSAttachedFileErrorSoapResponse(
            'TXN-ERR',
            FEC_ConstantCommon.CODE_SYS_ERROR,
            'File not found'
        );

        System.assert(xml.contains('GetCSAttachedFileResponse'));
        System.assert(xml.contains('<Code>0</Code>'));
        System.assert(xml.contains('File not found'));
    }

    @IsTest
    static void testRestPost_emptyBody_returnsBadRequest() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/MyCase/v1/GetCSAttachedFile';
        req.httpMethod = 'POST';
        req.requestBody = null;
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_GetCSAttachedFileRestService.doPost();
        Test.stopTest();

        System.assertEquals(
            FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST,
            res.statusCode
        );
        System.assert(
            res.responseBody.toString().contains('GetCSAttachedFileResponse')
        );
    }

    @IsTest
    static void testRestPost_missingRequestElement_returnsErrorEnvelope() {
        String invalidEnvelope =
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body><UnknownRequest /></soap:Body></soap:Envelope>';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/MyCase/v1/GetCSAttachedFile';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(invalidEnvelope);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_GetCSAttachedFileRestService.doPost();
        Test.stopTest();

        System.assertEquals(
            FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST,
            res.statusCode
        );
        System.assert(
            res.responseBody.toString().contains('GetCSAttachedFileResponse')
        );
    }
}