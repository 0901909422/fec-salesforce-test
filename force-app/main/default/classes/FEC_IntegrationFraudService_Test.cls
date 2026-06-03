@IsTest
private class FEC_IntegrationFraudService_Test {

    // =========================================================================
    // MOCK: HTTP Callout Mock for Fraud Master Data
    // =========================================================================
    private class MasterDataMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(getMasterDataXml());
            return res;
        }
    }

    // =========================================================================
    // MOCK: HTTP Callout Mock for Create Fraud Case
    // =========================================================================
    private class CreateFraudCaseMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(getCreateFraudCaseResponseXml());
            return res;
        }
    }

    // =========================================================================
    // MOCK: HTTP Callout Mock for Cancel Fraud Case
    // =========================================================================
    private class CancelFraudCaseMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(getCancelFraudCaseResponseXml());
            return res;
        }
    }

    // =========================================================================
    // MOCK: HTTP Callout Mock for Process Fraud Case
    // =========================================================================
    private class ProcessFraudCaseMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(getProcessFraudCaseResponseXml());
            return res;
        }
    }

    // =========================================================================
    // MOCK: HTTP Error Mock
    // =========================================================================
    private class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setBody('<error>fail</error>');
            return res;
        }
    }

    // =========================================================================
    // MOCK: Health Check Mock
    // =========================================================================
    private class HealthCheckMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('OK');
            return res;
        }
    }

    private class HealthCheckFailMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(503);
            res.setBody('Service Unavailable');
            return res;
        }
    }

    // =========================================================================
    // TEST: IntegrationFraudField inner class
    // =========================================================================
    @IsTest
    static void test_IntegrationFraudField() {
        FEC_IntegrationFraudService.IntegrationFraudField field = 
            new FEC_IntegrationFraudService.IntegrationFraudField();
        System.assertEquals('GetFraudMasterDataResponse', field.GET_FRAUD_MASTER_DATA_RESPONSE);
        System.assertEquals('MasterDataItems', field.MASTER_DATA_ITEMS);
        System.assertEquals('ID', field.MASTER_DATA_ID);
        System.assertEquals('Name', field.MASTER_DATA_NAME);
        System.assertEquals('NameVN', field.MASTER_DATA_NAMEVN);
        System.assertEquals('Type', field.MASTER_DATA_TYPE);
        System.assertEquals('Children', field.MASTER_DATA_CHILDRENT);
    }

    // =========================================================================
    // TEST: syncMasterDataIntegration
    // =========================================================================
    @IsTest
    static void test_syncMasterDataIntegration() {
        // Create channel record
        FEC_Channel__c channel = new FEC_Channel__c(
            FEC_Code__c = FEC_FraudConstantCommon.DEFAULT_CHANNEL_INTEGRATION_CODE,
            FEC_Channel_Status__c = true
        );
        insert channel;

        Test.setMock(HttpCalloutMock.class, new MasterDataMock());

        Test.startTest();
        Integer count = FEC_IntegrationFraudService.syncMasterDataIntegration();
        Test.stopTest();

        System.assert(count > 0, 'Should have imported master data records');
    }

    // =========================================================================
    // TEST: getFraudMasterData
    // =========================================================================
    @IsTest
    static void test_getFraudMasterData() {
        Test.setMock(HttpCalloutMock.class, new MasterDataMock());

        Test.startTest();
        String result = FEC_IntegrationFraudService.getFraudMasterData();
        Test.stopTest();

        System.assert(result.contains('GetFraudMasterDataResponse'), 'Should return XML response');
    }

    // =========================================================================
    // TEST: callCreateFraudCaseService - success
    // =========================================================================
    @IsTest
    static void test_callCreateFraudCaseService_Success() {
        Test.setMock(HttpCalloutMock.class, new CreateFraudCaseMock());

        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper reqWrapper = 
            new FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper();
        reqWrapper.channelCode = 'TEST';
        reqWrapper.caseId = 'CASE001';
        reqWrapper.serviceCaseId = 'SVC001';

        FEC_IntegrationSoapFraudcaseService.SysType sys = 
            new FEC_IntegrationSoapFraudcaseService.SysType();
        sys.Channel = 'CSM';
        sys.TransactionID = 'TXN001';
        sys.DateTime_x = Datetime.now();

        FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust = 
            new FEC_IntegrationSoapFraudcaseService.CustomerInfo_element();
        cust.UserType = 'Individual';

        FEC_IntegrationSoapFraudcaseService.RequestInfo_element req = 
            new FEC_IntegrationSoapFraudcaseService.RequestInfo_element();
        req.CaseType = 'Fraud';
        req.ProductType = 'Card';
        req.Category = 'CAT01';
        req.SubCategory = 'SUB01';
        req.SubCode = 'CODE01';
        req.Remarks = 'Test remark';

        FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element ai = 
            new FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element();
        ai.ID = 'AI001';
        ai.Value = 'TestValue';
        req.AdditionalInfo = new List<FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element>{ ai };

        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = 
            new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        creator.CreatorEmail = 'test@example.com';

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType result = 
            FEC_IntegrationFraudService.callCreateFraudCaseService(reqWrapper, sys, cust, req, creator);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // =========================================================================
    // TEST: callUpdateFraudCaseService - success
    // =========================================================================
    @IsTest
    static void test_callUpdateFraudCaseService_Success() {
        Test.setMock(HttpCalloutMock.class, new CreateFraudCaseMock());

        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper reqWrapper = 
            new FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper();
        reqWrapper.channelCode = 'TEST';
        reqWrapper.caseId = 'CASE002';
        reqWrapper.serviceCaseId = 'SVC002';

        FEC_IntegrationSoapFraudcaseService.SysType sys = 
            new FEC_IntegrationSoapFraudcaseService.SysType();
        sys.Channel = 'CSM';
        sys.TransactionID = 'TXN002';
        sys.DateTime_x = Datetime.now();

        FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust = 
            new FEC_IntegrationSoapFraudcaseService.CustomerInfo_element();
        cust.UserType = 'Individual';

        FEC_IntegrationSoapFraudcaseService.RequestInfo_element req = 
            new FEC_IntegrationSoapFraudcaseService.RequestInfo_element();
        req.CaseID = 'EXISTING_CASE';
        req.CaseType = 'Fraud';
        req.ProductType = 'Loan';
        req.Category = 'CAT02';
        req.SubCategory = 'SUB02';
        req.SubCode = 'CODE02';
        req.Remarks = 'Update remark';
        req.AdditionalInfo = new List<FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element>();

        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = 
            new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        creator.CreatorEmail = 'test@example.com';

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType result = 
            FEC_IntegrationFraudService.callUpdateFraudCaseService(reqWrapper, sys, cust, req, creator);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // =========================================================================
    // TEST: callCancelFraudCaseService - success
    // =========================================================================
    @IsTest
    static void test_callCancelFraudCaseService_Success() {
        Test.setMock(HttpCalloutMock.class, new CancelFraudCaseMock());

        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper reqWrapper = 
            new FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper();
        reqWrapper.channelCode = 'TEST';
        reqWrapper.caseId = 'CASE003';
        reqWrapper.serviceCaseId = 'SVC003';

        FEC_IntegrationSoapFraudcaseService.SysType sys = 
            new FEC_IntegrationSoapFraudcaseService.SysType();
        sys.Channel = 'CSM';
        sys.TransactionID = 'TXN003';
        sys.DateTime_x = Datetime.now();

        FEC_IntegrationSoapFraudcaseService.CaseInfoType caseInfo = 
            new FEC_IntegrationSoapFraudcaseService.CaseInfoType();
        caseInfo.CaseID = 'FIMA-001';
        caseInfo.Remarks = 'Cancel reason';

        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = 
            new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        creator.CreatorEmail = 'test@example.com';

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType result = 
            FEC_IntegrationFraudService.callCancelFraudCaseService(reqWrapper, sys, caseInfo, creator);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // =========================================================================
    // TEST: callProcessFraudCaseService - success
    // =========================================================================
    @IsTest
    static void test_callProcessFraudCaseService_Success() {
        Test.setMock(HttpCalloutMock.class, new ProcessFraudCaseMock());

        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper reqWrapper = 
            new FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper();
        reqWrapper.channelCode = 'TEST';
        reqWrapper.caseId = 'CASE004';
        reqWrapper.serviceCaseId = 'SVC004';

        FEC_IntegrationSoapFraudcaseService.SysType sys = 
            new FEC_IntegrationSoapFraudcaseService.SysType();
        sys.Channel = 'CSM';
        sys.TransactionID = 'TXN004';
        sys.DateTime_x = Datetime.now();

        FEC_IntegrationSoapFraudcaseService.CaseInfoType4 caseInfo = 
            new FEC_IntegrationSoapFraudcaseService.CaseInfoType4();
        caseInfo.CaseID = 'FIMA-002';
        caseInfo.Decision = 'Approved';
        caseInfo.SubDecision = 'Full';
        caseInfo.Reason = 'Verified';
        caseInfo.Remarks = 'Process remark';

        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = 
            new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        creator.CreatorEmail = 'test@example.com';

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType result = 
            FEC_IntegrationFraudService.callProcessFraudCaseService(reqWrapper, sys, caseInfo, creator);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // =========================================================================
    // TEST: isConnectFraudSystem - success
    // =========================================================================
    @IsTest
    static void test_isConnectFraudSystem_Success() {
        Test.setMock(HttpCalloutMock.class, new HealthCheckMock());

        Test.startTest();
        Boolean result = FEC_IntegrationFraudService.isConnectFraudSystem();
        Test.stopTest();

        System.assertEquals(true, result, 'Should return true when status 200');
    }

    // =========================================================================
    // TEST: isConnectFraudSystem - failure
    // =========================================================================
    @IsTest
    static void test_isConnectFraudSystem_Failure() {
        Test.setMock(HttpCalloutMock.class, new HealthCheckFailMock());

        Test.startTest();
        Boolean result = FEC_IntegrationFraudService.isConnectFraudSystem();
        Test.stopTest();

        System.assertEquals(false, result, 'Should return false when not 200');
    }

    // =========================================================================
    // TEST: getAdminRecipients
    // =========================================================================
    @IsTest
    static void test_getAdminRecipients() {
        Test.startTest();
        List<String> emails = FEC_IntegrationFraudService.getAdminRecipients();
        Test.stopTest();

        System.assertNotEquals(null, emails, 'Should return a list');
    }

    // =========================================================================
    // TEST: callCreateFraudCaseService - with blank AdditionalInfo value
    // =========================================================================
    @IsTest
    static void test_callCreateFraudCaseService_BlankAdditionalInfo() {
        Test.setMock(HttpCalloutMock.class, new CreateFraudCaseMock());

        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper reqWrapper = 
            new FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper();
        reqWrapper.channelCode = 'TEST';
        reqWrapper.caseId = 'CASE005';
        reqWrapper.serviceCaseId = 'SVC005';

        FEC_IntegrationSoapFraudcaseService.SysType sys = 
            new FEC_IntegrationSoapFraudcaseService.SysType();
        sys.Channel = 'CSM';
        sys.TransactionID = 'TXN005';
        sys.DateTime_x = Datetime.now();

        FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust = 
            new FEC_IntegrationSoapFraudcaseService.CustomerInfo_element();
        cust.UserType = 'Corporate';

        FEC_IntegrationSoapFraudcaseService.RequestInfo_element req = 
            new FEC_IntegrationSoapFraudcaseService.RequestInfo_element();
        req.CaseType = 'Fraud';
        req.ProductType = 'Card';

        // AdditionalInfo with blank value
        FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element ai = 
            new FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element();
        ai.ID = 'AI002';
        ai.Value = '';
        req.AdditionalInfo = new List<FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element>{ ai };

        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = 
            new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        creator.CreatorEmail = 'test@example.com';

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType result = 
            FEC_IntegrationFraudService.callCreateFraudCaseService(reqWrapper, sys, cust, req, creator);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // =========================================================================
    // HELPER: Master Data XML Response
    // =========================================================================
    private static String getMasterDataXml() {
        return '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<GetFraudMasterDataResponse xmlns="urn:PegaRULES:SOAP:FraudCase:Services">' +
            '<MasterDataItems>' +
                '<ID>P001</ID>' +
                '<Name>Credit Card</Name>' +
                '<NameVN>Thẻ tín dụng</NameVN>' +
                '<Type>Product</Type>' +
                '<ApplyTo>All</ApplyTo>' +
                '<PosOrder>1</PosOrder>' +
                '<Children>' +
                    '<ID>CT001</ID>' +
                    '<Name>Fraud Type A</Name>' +
                    '<NameVN>Loại gian lận A</NameVN>' +
                    '<Type>CaseType</Type>' +
                    '<PosOrder>1</PosOrder>' +
                    '<Children>' +
                        '<ID>CAT001</ID>' +
                        '<Name>Category 1</Name>' +
                        '<NameVN>Danh mục 1</NameVN>' +
                        '<Type>Category</Type>' +
                        '<PosOrder>1</PosOrder>' +
                        '<Children>' +
                            '<ID>SUB001</ID>' +
                            '<Name>Sub Category 1</Name>' +
                            '<NameVN>Danh mục con 1</NameVN>' +
                            '<Type>SubCategory</Type>' +
                            '<PosOrder>1</PosOrder>' +
                            '<Children>' +
                                '<ID>SC001</ID>' +
                                '<Name>SubCode 1</Name>' +
                                '<NameVN>Mã phụ 1</NameVN>' +
                                '<Type>SubCode</Type>' +
                                '<PosOrder>1</PosOrder>' +
                                '<AdditionalProperties>' +
                                    '<ID>AP001</ID>' +
                                    '<Name>Field1</Name>' +
                                    '<NameVN>Trường 1</NameVN>' +
                                    '<Type>Text</Type>' +
                                    '<Mandatory>true</Mandatory>' +
                                    '<PosOrder>1</PosOrder>' +
                                    '<AvailableValues>' +
                                        '<ID>AV001</ID>' +
                                        '<Name>Value1</Name>' +
                                        '<NameVN>Giá trị 1</NameVN>' +
                                        '<PosOrder>1</PosOrder>' +
                                    '</AvailableValues>' +
                                '</AdditionalProperties>' +
                            '</Children>' +
                        '</Children>' +
                    '</Children>' +
                '</Children>' +
            '</MasterDataItems>' +
            '</GetFraudMasterDataResponse>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }

    private static String getCreateFraudCaseResponseXml() {
        return '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<ns1:CreateFraudCaseResponse xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
            '<ns1:CaseID>FIMA-12345</ns1:CaseID>' +
            '<ns1:Sys>' +
            '<ns1:Code>200</ns1:Code>' +
            '<ns1:Description>Success</ns1:Description>' +
            '</ns1:Sys>' +
            '</ns1:CreateFraudCaseResponse>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }

    private static String getCancelFraudCaseResponseXml() {
        return '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<ns1:CancelFraudCaseResponse xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
            '<ns1:CaseID>FIMA-12345</ns1:CaseID>' +
            '<ns1:Sys>' +
            '<ns1:Code>200</ns1:Code>' +
            '<ns1:Description>Cancelled</ns1:Description>' +
            '</ns1:Sys>' +
            '</ns1:CancelFraudCaseResponse>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }

    private static String getProcessFraudCaseResponseXml() {
        return '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<ns1:ProcessCaseResponse xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
            '<ns1:Sys>' +
            '<ns1:Code>200</ns1:Code>' +
            '<ns1:Description>Processed</ns1:Description>' +
            '</ns1:Sys>' +
            '</ns1:ProcessCaseResponse>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }
}
