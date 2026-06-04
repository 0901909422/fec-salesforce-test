@IsTest
private class FEC_GetCSMasterDataRestService_Test {
    private static final String VALID_CHANNEL = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;

    private static final String SAMPLE_MASTER_DATA_REQUEST =
        '<?xml version="1.0" encoding="utf-8"?>' +
        '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
        '<soap:Body>' +
        '<GetCSMasterDataRequest xmlns="urn:PegaRULES:SOAP:MyCase:Services">' +
        '<Sys>' +
        '<Channel>' + VALID_CHANNEL + '</Channel>' +
        '<TransactionID>TXN-MASTER-2026-99999999999</TransactionID>' +
        '<DateTime>2026-05-25T06:52:33.617Z</DateTime>' +
        '</Sys>' +
        '</GetCSMasterDataRequest>' +
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

        String suffix = String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 1000));

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Loan REST',
            FEC_Code__c = 'PR' + suffix,
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        insert prod;

        FEC_Business_Process__c proc = new FEC_Business_Process__c(
            Name = 'Fraud REST',
            FEC_Code__c = 'BP' + suffix,
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        insert proc;

        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Category REST',
            FEC_Code__c = 'CT' + suffix,
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        insert cat;

        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'SubCat REST',
            FEC_Code__c = 'SC' + suffix,
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        insert subCat;

        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'SubCode REST',
            FEC_Code__c = 'SB' + suffix,
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        insert subCode;

        insert new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Business_Process__c = proc.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Customer_Type__c = 'Existing',
            FEC_Active__c = true
        );
    }

    @IsTest
    static void testParseGetCSMasterDataRequest_mapsFields() {
        FEC_GetCSMasterDataService.SysRequestType parsed =
            FEC_MyCaseSoapXml.parseGetCSMasterDataRequest(SAMPLE_MASTER_DATA_REQUEST);

        System.assertNotEquals(null, parsed);
        System.assertEquals(VALID_CHANNEL, parsed.Channel);
        System.assertEquals('TXN-MASTER-2026-99999999999', parsed.TransactionID);
        System.assertNotEquals(null, parsed.DateTime_x);
    }

    @IsTest
    static void testBuildGetCSMasterDataSoapResponse_structure() {
        FEC_GetCSMasterDataService.GetCSMasterDataResponse resp =
            new FEC_GetCSMasterDataService.GetCSMasterDataResponse();
        resp.Sys = new FEC_GetCSMasterDataService.SysResponseType();
        resp.Sys.TransactionID = 'TXN1';
        resp.Sys.DateTime_x = System.now();
        resp.Sys.Code = '1';
        resp.Sys.Description = 'Success';

        FEC_GetCSMasterDataService.MasterDataItemType item =
            new FEC_GetCSMasterDataService.MasterDataItemType();
        item.ID = 'CARD';
        item.Name = 'Card';
        item.NameVN = 'The';
        item.PosOrder = 1;
        item.Type = 'Product';

        FEC_GetCSMasterDataService.ChildItemType child =
            new FEC_GetCSMasterDataService.ChildItemType();
        child.ID = 'Complaint';
        child.Name = 'Complaint';
        child.PosOrder = 2;
        child.Type = 'CaseType';
        item.Children = new List<FEC_GetCSMasterDataService.ChildItemType>{ child };

        FEC_GetCSMasterDataService.AdditionalPropertyType prop =
            new FEC_GetCSMasterDataService.AdditionalPropertyType();
        prop.ID = 'Field1';
        prop.Name = 'Field 1';
        prop.Mandatory = true;
        prop.Type = 'string';
        item.AdditionalProperties =
            new List<FEC_GetCSMasterDataService.AdditionalPropertyType>{ prop };

        resp.MasterDataItems =
            new List<FEC_GetCSMasterDataService.MasterDataItemType>{ item };

        String xml = FEC_MyCaseSoapXml.buildGetCSMasterDataSoapResponse(resp);

        System.assert(xml.contains('GetCSMasterDataResponse'));
        System.assert(xml.contains('<MasterDataItems>'));
        System.assert(xml.contains('<Children>'));
        System.assert(xml.contains('<AdditionalProperties>'));
        System.assert(xml.contains('<Mandatory>true</Mandatory>'));
    }

    @IsTest
    static void testRestPost_getMasterDataSuccess() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/MyCase/v1/GetCSMasterData';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(SAMPLE_MASTER_DATA_REQUEST);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_GetCSMasterDataRestService.doPost();
        Test.stopTest();

        String body = res.responseBody.toString();
        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_OK, res.statusCode);
        System.assert(body.contains('GetCSMasterDataResponse'));
        System.assert(body.contains('<MasterDataItems>'));
    }

    @IsTest
    static void testBuildGetCSMasterDataErrorSoapResponse() {
        String xml = FEC_MyCaseSoapXml.buildGetCSMasterDataErrorSoapResponse(
            'TXN-ERR',
            '102',
            'Invalid channel'
        );

        System.assert(xml.contains('GetCSMasterDataResponse'));
        System.assert(xml.contains('<Code>102</Code>'));
        System.assert(xml.contains('Invalid channel'));
    }

    @IsTest
    static void testRestPost_emptyBody_returnsBadRequest() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/MyCase/v1/GetCSMasterData';
        req.httpMethod = 'POST';
        req.requestBody = null;
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_GetCSMasterDataRestService.doPost();
        Test.stopTest();

        System.assertEquals(
            FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST,
            res.statusCode
        );
        System.assert(
            res.responseBody.toString().contains('GetCSMasterDataResponse')
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
        req.requestUri = '/services/apexrest/MyCase/v1/GetCSMasterData';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(invalidEnvelope);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_GetCSMasterDataRestService.doPost();
        Test.stopTest();

        System.assertEquals(
            FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST,
            res.statusCode
        );
        System.assert(
            res.responseBody.toString().contains('GetCSMasterDataResponse')
        );
    }
}