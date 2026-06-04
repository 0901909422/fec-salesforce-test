@IsTest
private class FEC_MyCaseSoapXml_Test {

    private static final String SAMPLE_CREATE_REQUEST =
        '<?xml version="1.0" encoding="utf-8"?>' +
        '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
        '<soap:Body>' +
        '<CreateCSCaseRequest xmlns="urn:PegaRULES:SOAP:MyCase:Services">' +
        '<Sys><Channel>Inbound</Channel>' +
        '<TransactionID>TXN-CREATE-XML</TransactionID>' +
        '<DateTime>2026-05-25T06:52:33Z</DateTime></Sys>' +
        '<CustomerInfo><Name>Test User</Name><PhoneNumber>0901234567</PhoneNumber>' +
        '<UserType>Existing</UserType><NationalID>123456789</NationalID>' +
        '<ContractOrAccountNumber>1234567890123456</ContractOrAccountNumber>' +
        '<EmailAddress>test@fecredit.com.vn</EmailAddress></CustomerInfo>' +
        '<RequestInfo><CaseType>Complaint</CaseType><RequestType>REQ</RequestType>' +
        '<ProductType>CARD</ProductType><Category>Request</Category>' +
        '<SubCategory>SubCat</SubCategory><SubCode>SubCode</SubCode>' +
        '<Remarks>Remarks</Remarks></RequestInfo>' +
        '<CreatorInfo><CreatorEmail>creator@fecredit.com.vn</CreatorEmail></CreatorInfo>' +
        '</CreateCSCaseRequest></soap:Body></soap:Envelope>';

    @IsTest
    static void testParseCreateCSCaseRequest_andBuildResponses() {
        FEC_CreateCSCaseService.CaseRequestType req =
            FEC_MyCaseSoapXml.parseCreateCSCaseRequest(SAMPLE_CREATE_REQUEST);
        System.assertNotEquals(null, req.Sys);
        System.assertEquals('Inbound', req.Sys.Channel);

        FEC_CreateCSCaseService.CreateCSCaseResponse okResp =
            new FEC_CreateCSCaseService.CreateCSCaseResponse();
        okResp.Sys = new FEC_CreateCSCaseService.SysType2();
        okResp.Sys.TransactionID = 'TXN-CREATE-XML';
        okResp.Sys.Code = FEC_ConstantCommon.CODE_SUCCESS;
        okResp.Sys.Description = 'OK';
        okResp.CaseID = 'CASE-NEW';

        String okXml = FEC_MyCaseSoapXml.buildCreateCSCaseSoapResponse(okResp);
        String errXml = FEC_MyCaseSoapXml.buildErrorSoapResponse(
            'TXN-ERR',
            '99',
            'Validation failed'
        );

        FEC_CreateCaseHandler.FEC_InteractionCaseDTO dto =
            FEC_MyCaseSoapXml.buildInteractionCaseDto(req);
        FEC_CreateCaseHandler.FEC_InteractionCaseDTO emptyDto =
            FEC_MyCaseSoapXml.buildInteractionCaseDto(null);

        System.assert(okXml.contains('CreateCSCaseResponse'));
        System.assert(errXml.contains('CreateCSCaseResponse'));
        System.assertEquals('Inbound', dto.channel);
        System.assertEquals(null, emptyDto.phoneNumber);
    }

    @IsTest
    static void testParseCreateCSCaseRequest_nullThrows() {
        Boolean threw = false;
        try {
            FEC_MyCaseSoapXml.parseCreateCSCaseRequest(null);
        } catch (FEC_MyCaseSoapXml.SoapParseException e) {
            threw = true;
        }
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testMasterDataXmlBuilders() {
        List<FEC_GetCSMasterDataService.AdditionalPropertyType> props =
            new List<FEC_GetCSMasterDataService.AdditionalPropertyType>();
        FEC_GetCSMasterDataService.AdditionalPropertyType p =
            new FEC_GetCSMasterDataService.AdditionalPropertyType();
        p.ID = 'F1';
        p.Name = 'Field';
        p.NameVN = 'Truong';
        p.PosOrder = 1;
        p.ApplyTo = 'Case';
        p.Mandatory = true;
        p.Type = 'Text';
        props.add(p);

        String batchXml = FEC_MyCaseSoapXml.buildMasterDataAdditionalPropertiesXml(props);
        String singleXml = FEC_MyCaseSoapXml.buildMasterDataAdditionalPropertyXml(
            'F2',
            'Name2',
            'VN2',
            2,
            'Case',
            false,
            'Picklist',
            new List<Schema.PicklistEntry>()
        );

        System.assert(batchXml.contains('AdditionalProperties'));
        System.assert(singleXml.contains('AdditionalProperties'));
        System.assertEquals('', FEC_MyCaseSoapXml.buildMasterDataAdditionalPropertiesXml(null));
    }
}
