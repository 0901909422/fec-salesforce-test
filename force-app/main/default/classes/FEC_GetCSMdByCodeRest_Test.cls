@IsTest
private class FEC_GetCSMdByCodeRest_Test {
    private static final String VALID_CHANNEL = FEC_ConstantCommon.KEY_VALID_CHANNELS_API;

    private static final String SAMPLE_BY_CODE_REQUEST =
        '<?xml version="1.0" encoding="utf-8"?>' +
        '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
        '<soap:Body>' +
        '<GetCSMasterDataByCodeRequest xmlns="urn:PegaRULES:SOAP:MyCase:Services">' +
        '<Sys>' +
        '<Channel>API</Channel>' +
        '<TransactionID>TXN-BYCODE-2026-99999999999</TransactionID>' +
        '<DateTime>2026-05-25T06:52:33.618Z</DateTime>' +
        '</Sys>' +
        '<MasterDataCode>' +
        '<CaseType>Complaint</CaseType>' +
        '<Category>Request</Category>' +
        '<SubCategory>SC01</SubCategory>' +
        '<ProductType>CARD</ProductType>' +
        '<SubCode>SUB01</SubCode>' +
        '</MasterDataCode>' +
        '<CustomerType>' +
        '<UserType>EXISTING</UserType>' +
        '<Language>EN</Language>' +
        '</CustomerType>' +
        '</GetCSMasterDataByCodeRequest>' +
        '</soap:Body>' +
        '</soap:Envelope>';

    @TestSetup
    static void setupData() {
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'Test SubCat REST',
            FEC_Code__c = 'SC01',
            FEC_Name_VN__c = 'Danh muc phu REST',
            FEC_Active__c = true
        );
        insert subCat;

        insert new FEC_Nature_of_Case__c(
            FEC_Sub_Category__c = subCat.Id,
            FEC_Active__c = true
        );
    }

    @IsTest
    static void testParseGetCSMasterDataByCodeRequest_mapsFields() {
        FEC_MyCaseSoapXml.GetCSMasterDataByCodeParsedRequest parsed =
            FEC_MyCaseSoapXml.parseGetCSMasterDataByCodeRequest(SAMPLE_BY_CODE_REQUEST);

        System.assertNotEquals(null, parsed.Sys);
        System.assertEquals(VALID_CHANNEL, parsed.Sys.Channel);
        System.assertEquals('TXN-BYCODE-2026-99999999999', parsed.Sys.TransactionID);
        System.assertNotEquals(null, parsed.Sys.DateTime_x);

        System.assertNotEquals(null, parsed.MasterDataCode);
        System.assertEquals('Complaint', parsed.MasterDataCode.CaseType);
        System.assertEquals('Request', parsed.MasterDataCode.Category);
        System.assertEquals('SC01', parsed.MasterDataCode.SubCategory);
        System.assertEquals('CARD', parsed.MasterDataCode.ProductType);
        System.assertEquals('SUB01', parsed.MasterDataCode.SubCode);

        System.assertNotEquals(null, parsed.CustomerType);
        System.assertEquals('EXISTING', parsed.CustomerType.UserType);
        System.assertEquals('EN', parsed.CustomerType.Language);
    }

    @IsTest
    static void testBuildGetCSMasterDataByCodeSoapResponse_structure() {
        FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeResponse resp =
            new FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeResponse();
        resp.Sys = new FEC_GetCSMasterDataByCodeService.SysResponseType();
        resp.Sys.TransactionID = 'TXN1';
        resp.Sys.DateTime_x = System.now();
        resp.Sys.Code = '1';
        resp.Sys.Description = 'Success';

        resp.RequestInfo = new FEC_GetCSMasterDataByCodeService.RequestInfoType();
        resp.RequestInfo.Category = 'Request';
        resp.RequestInfo.CaseType = 'Complaint';
        resp.RequestInfo.ProductLineId = 'CARD';

        resp.CustomerInfo = new FEC_GetCSMasterDataByCodeService.CustomerTypeRequest();
        resp.CustomerInfo.UserType = 'EXISTING';
        resp.CustomerInfo.Language = 'EN';

        FEC_GetCSMasterDataByCodeService.DataItemType item =
            new FEC_GetCSMasterDataByCodeService.DataItemType();
        item.ID = 'SC01';
        item.Name = 'Sub Category';
        item.Type = 'SubCategory';
        resp.DataItems = new List<FEC_GetCSMasterDataByCodeService.DataItemType>{ item };

        resp.AdditionalInfo = new FEC_GetCSMasterDataByCodeService.AdditionalInfoRequest();
        resp.AdditionalInfo.ID = 'Field1';
        resp.AdditionalInfo.Value = 'Value1';

        String xml = FEC_MyCaseSoapXml.buildGetCSMasterDataByCodeSoapResponse(resp);

        System.assert(xml.contains('GetCSMasterDataByCodeResponse'));
        System.assert(xml.contains('<DataItems>'));
        System.assert(xml.contains('<CustomerInfo>'));
        System.assert(xml.contains('<AdditionalProperties>'));
        System.assert(xml.contains('<Code>1</Code>'));
    }

    @IsTest
    static void testRestPost_getMasterDataByCodeSuccess() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/MyCase/v1/GetCSMasterDataByCode';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(SAMPLE_BY_CODE_REQUEST);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_GetCSMasterDataByCodeRestService.doPost();
        Test.stopTest();

        String body = res.responseBody.toString();
        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_OK, res.statusCode);
        System.assert(body.contains('GetCSMasterDataByCodeResponse'));
        System.assert(body.contains('<Code>1</Code>'), body);
        System.assert(body.contains('<DataItems>'));
    }

    @IsTest
    static void testBuildGetCSMasterDataByCodeErrorSoapResponse() {
        String xml = FEC_MyCaseSoapXml.buildGetCSMasterDataByCodeErrorSoapResponse(
            'TXN-ERR',
            '0',
            'Invalid channel'
        );

        System.assert(xml.contains('GetCSMasterDataByCodeResponse'));
        System.assert(xml.contains('<Code>0</Code>'));
        System.assert(xml.contains('Invalid channel'));
    }

    @IsTest
    static void testRestPost_emptyBody_returnsBadRequest() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/MyCase/v1/GetCSMasterDataByCode';
        req.httpMethod = 'POST';
        req.requestBody = null;
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_GetCSMasterDataByCodeRestService.doPost();
        Test.stopTest();

        System.assertEquals(
            FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST,
            res.statusCode
        );
        System.assert(
            res.responseBody.toString().contains('GetCSMasterDataByCodeResponse')
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
        req.requestUri = '/services/apexrest/MyCase/v1/GetCSMasterDataByCode';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(invalidEnvelope);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_GetCSMasterDataByCodeRestService.doPost();
        Test.stopTest();

        System.assertEquals(
            FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST,
            res.statusCode
        );
        System.assert(
            res.responseBody.toString().contains('GetCSMasterDataByCodeResponse')
        );
    }
}