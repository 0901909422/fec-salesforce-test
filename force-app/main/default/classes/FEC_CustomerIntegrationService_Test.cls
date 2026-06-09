@IsTest
private class FEC_CustomerIntegrationService_Test {

    private static final String ACCOUNT_NUMBER = '1234567890123456';

    private class CustomerIntegrationMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint() != null ? req.getEndpoint().toLowerCase() : '';
            String body = req.getBody() != null ? req.getBody().toLowerCase() : '';
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            if (endpoint.contains('customerlist') || body.contains('getcustomerlist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><cif:GetCustomerListResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerSearch">' +
                    '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                    '<Count>1</Count><Customers><Customer>' +
                    '<CIFNumber>CIF-SYNC-001</CIFNumber>' +
                    '<FullName>Nguyen Van Sync</FullName>' +
                    '<NationalID>079123456789</NationalID>' +
                    '<DateOfBirth>1990-05-15</DateOfBirth>' +
                    '<Phones><PhoneNode><Type>Mobile</Type><Phone>0909998877</Phone></PhoneNode></Phones>' +
                    '<Emails><Email>sync@example.com</Email></Emails>' +
                    '</Customer></Customers>' +
                    '</cif:GetCustomerListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (endpoint.contains('customerinfobasic') || body.contains('getcustomerinfobasic')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCustomerInfoBasicResponse>' +
                    '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                    '<CustomerBasicInfo>' +
                    '<FullName>Nguyen Van Basic</FullName>' +
                    '<Gender>Male</Gender>' +
                    '<Birthday>1990-05-15</Birthday>' +
                    '<PreferredContacts>' +
                    '<PreferredContact><Contact><Channel>Email</Channel><ContactString>basic@example.com</ContactString></Contact></PreferredContact>' +
                    '</PreferredContacts>' +
                    '</CustomerBasicInfo>' +
                    '</GetCustomerInfoBasicResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (endpoint.contains('documentslist') || body.contains('getdocumentslist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetDocumentsListResponse>' +
                    '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                    '<Documents><Document><DocumentID>DOC-SYNC-001</DocumentID></Document></Documents>' +
                    '</GetDocumentsListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (endpoint.contains('cardbasicinfo') || body.contains('getcardbasicinfo')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCardBasicInfoResponse>' +
                    '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                    '<CardBasicInfo><MainCard><PlasticIndicator>PLASTIC-001</PlasticIndicator></MainCard></CardBasicInfo>' +
                    '</GetCardBasicInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getcontactslist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetContactsListResponse><Sys><Code>1</Code></Sys>' +
                    '<Contacts><Contact><Channel>Email</Channel><ContactString>sync@example.com</ContactString></Contact></Contacts>' +
                    '</GetContactsListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getaddresseslist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetAddressesListResponse><Sys><Code>1</Code></Sys>' +
                    '<Addresses><Address><AddressType>OFFICE</AddressType><Street>1 Office Rd</Street></Address></Addresses>' +
                    '</GetAddressesListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('m_fas_outstanding_auth_inq')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><WSResponse><Sys><Code>1</Code><Description>Success</Description></Sys>' +
                    '<M_FAS_OUTSTANDING_AUTH_INQ><VMX_ROOT><VMX_MSGOUT>' +
                    '<SVC_RETURN>S</SVC_RETURN><RC_NBR_OCCUR>1</RC_NBR_OCCUR>' +
                    '<AUTHS_TABLE><Row><EFF_DATE>2026-01-02</EFF_DATE><AUTH_AMOUNT>250</AUTH_AMOUNT>' +
                    '<Description>Store C</Description><CreditDebitFlag>C</CreditDebitFlag>' +
                    '<AUTHORIZATION_CODE>AUTH99</AUTHORIZATION_CODE></Row></AUTHS_TABLE>' +
                    '</VMX_MSGOUT></VMX_ROOT></M_FAS_OUTSTANDING_AUTH_INQ></WSResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getcardsecinfo')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCardSecInfoResponse><Sys><Code>1</Code></Sys>' +
                    '<CardSecInfo><MainCardBalance><CurrentBalance>100</CurrentBalance></MainCardBalance>' +
                    '<IPPs><IPP><IPPPlan>P1</IPPPlan><IPPRecordNo>R1</IPPRecordNo><Term>6</Term></IPP></IPPs>' +
                    '</CardSecInfo></GetCardSecInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getcardplaninfo')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><cif:GetCardPlanInfoResponse xmlns:cif="http://fecredit.com.vn/CIF_CardInfo">' +
                    '<Sys><Code>1</Code></Sys><CardPlanInfo><CardPlans>' +
                    '<CardPlan><RecordNumber>R1</RecordNumber><PlanNumber>P1</PlanNumber>' +
                    '<PlanOpenDate>2026-01-01</PlanOpenDate><PlanCurrentBalance>1000</PlanCurrentBalance>' +
                    '</CardPlan></CardPlans></CardPlanInfo></cif:GetCardPlanInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getloanbasicinfo')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetLoanBasicInfoResponse><Sys><Code>1</Code></Sys>' +
                    '<LoanBasicInfo><Loan><ContractNumber>12345678-123456-1234</ContractNumber></Loan>' +
                    '<Product><LoanAmount>1000000</LoanAmount><Tenure>12</Tenure></Product>' +
                    '<PassDue><DPD>2</DPD></PassDue></LoanBasicInfo>' +
                    '</GetLoanBasicInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getmrcinfo')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetMRCInfoResponse><Sys><Code>1</Code></Sys>' +
                    '<MRCZone>Z1</MRCZone><Status>OK</Status></GetMRCInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            res.setBody('');
            return res;
        }
    }

    private static Case insertIntegrationCase(String subject) {
        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = subject,
                Status = 'New',
                FEC_ID_Search__c = 'CIS-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    @IsTest
    static void testQueryHistoryForSync() {
        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'Query history sync',
                Status = 'New',
                FEC_ID_Search__c = 'CIS-Q-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_CIF_Number__c = 'CIF-QUERY',
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_Customer_Name__c = 'Query User',
            FEC_National_ID_Passport_ID__c = '123456789',
            FEC_Primary_Phone__c = '0901112233',
            FEC_Email__c = 'query@example.com'
        );
        insert hist;

        Test.startTest();
        FEC_Customer_History__c loaded = FEC_CustomerIntegrationService.queryHistoryForSync(hist.Id);
        Test.stopTest();

        System.assertEquals(hist.Id, loaded.Id);
        System.assertEquals('CIF-QUERY', loaded.FEC_CIF_Number__c);
        System.assertEquals(ACCOUNT_NUMBER, loaded.FEC_Account_Number__c);
        System.assertEquals('Query User', loaded.FEC_Customer_Name__c);
    }

    @IsTest
    static void testSyncCustomer_Success() {
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE,
            FEC_Active__c = true
        );
        insert pt;

        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'Integration Sync Test',
                Status = 'New',
                FEC_Product_Type__c = pt.Id,
                FEC_ID_Search__c = 'CIS-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;

        hist = FEC_CustomerIntegrationService.queryHistoryForSync(hist.Id);

        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationMock());
        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result = FEC_CustomerIntegrationService.syncCustomer(
            hist, null, null, ACCOUNT_NUMBER
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Nguyen Van Sync', result.customerName);
        System.assertEquals('DOC-SYNC-001', result.nationalId);
        System.assertEquals('0909998877', result.primaryPhone);
        System.assertEquals('sync@example.com', result.emailAddress);
        System.assertEquals('PLASTIC-001', result.plasticID);
        System.assertEquals('CIF-SYNC-001', hist.FEC_CIF_Number__c);
        System.assertEquals('DOC-SYNC-001', hist.FEC_National_ID_Passport_ID__c);
    }

    @IsTest
    static void testSyncCustomer_WithProvidedCif() {
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE,
            FEC_Active__c = true
        );
        insert pt;

        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'Integration CIF Test',
                Status = 'New',
                FEC_Product_Type__c = pt.Id,
                FEC_ID_Search__c = 'CIS-CIF-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;

        hist = FEC_CustomerIntegrationService.queryHistoryForSync(hist.Id);

        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationMock());
        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result = FEC_CustomerIntegrationService.syncCustomer(
            hist, 'CIF123', '0901234567', null
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('DOC-SYNC-001', result.nationalId);
        if (result.plasticID != null) {
            System.assertEquals('PLASTIC-001', result.plasticID);
        }
    }

    @IsTest
    static void testSyncCustomer_NullInputs() {
        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(null, null, null, null);
        Test.stopTest();

        System.assertEquals(null, result.customerName, 'Khi hist null, kết quả nên rỗng.');
    }

    @IsTest
    static void testSyncCustomer_NoCifReturnsEmpty() {
        Case c = insertIntegrationCase('No CIF Test');
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;

        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(hist, null, null, null);
        Test.stopTest();

        System.assertEquals(null, result.customerName);
        System.assertEquals(null, result.nationalId);
    }

    @IsTest
    static void testSyncCustomer_WithContractNumber() {
        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'Integration Contract Test',
                Status = 'New',
                FEC_ID_Search__c = 'CIS-CTR-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Contract_Number__c = '12345678-123456-1234',
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;

        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationMock());
        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(hist, null, null, null);
        Test.stopTest();

        System.assertEquals('Nguyen Van Sync', result.customerName);
        System.assertEquals('DOC-SYNC-001', result.nationalId);
        System.assertEquals('CIF-SYNC-001', hist.FEC_CIF_Number__c);
        System.assertEquals('0909998877', result.primaryPhone);
    }

    @IsTest
    static void testSyncCustomer_FallbackAccountNumberParam() {
        Case c = insertIntegrationCase('Fallback Account Test');
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;

        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationMock());
        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(hist, null, null, ACCOUNT_NUMBER);
        Test.stopTest();

        System.assertEquals('Nguyen Van Sync', result.customerName);
        System.assertEquals('CIF-SYNC-001', hist.FEC_CIF_Number__c);
    }

    private class CustomerIntegrationErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('<error>Service unavailable</error>');
            return res;
        }
    }

    private class CustomerIntegrationSysErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint() != null ? req.getEndpoint().toLowerCase() : '';
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (endpoint.contains('customerlist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><cif:GetCustomerListResponse>' +
                    '<Sys><Code>99</Code><Description>Failed</Description></Sys>' +
                    '</cif:GetCustomerListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }
            res.setBody('');
            return res;
        }
    }

    @IsTest
    static void testSyncCustomer_CalloutFailuresReturnPartialResult() {
        Case c = insertIntegrationCase('Callout failure sync');
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;
        hist = FEC_CustomerIntegrationService.queryHistoryForSync(hist.Id);

        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationErrorMock());
        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(hist, 'CIF-ERR', null, ACCOUNT_NUMBER);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testSyncCustomer_CustomerListSysError() {
        Case c = insertIntegrationCase('Customer list sys error');
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;
        hist = FEC_CustomerIntegrationService.queryHistoryForSync(hist.Id);

        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationSysErrorMock());
        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(hist, null, null, ACCOUNT_NUMBER);
        Test.stopTest();

        System.assertEquals(null, result.customerName);
    }

    @IsTest
    static void testSyncCustomer_LoanProductTypePath() {
        FEC_Product_Type__c loanPt = new FEC_Product_Type__c(
            Name = 'Loan',
            FEC_Code__c = FEC_ConstantCommon.PRODUCT_TYPE_LOAN_CASE,
            FEC_Active__c = true
        );
        insert loanPt;

        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'Loan integration sync',
                Status = 'New',
                FEC_Product_Type__c = loanPt.Id,
                FEC_ID_Search__c = 'CIS-LOAN-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Contract_Number__c = '12345678-123456-1234',
            FEC_CIF_Number__c = 'CIF-LOAN-001',
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;
        hist = FEC_CustomerIntegrationService.queryHistoryForSync(hist.Id);

        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationMock());
        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(hist, hist.FEC_CIF_Number__c, null, null);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    private class CustomerIntegrationCardFullMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint() != null ? req.getEndpoint().toLowerCase() : '';
            String body = req.getBody() != null ? req.getBody().toLowerCase() : '';
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            if (endpoint.contains('customerlist') || body.contains('getcustomerlist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><cif:GetCustomerListResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerSearch">' +
                    '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                    '<Count>1</Count><Customers><Customer>' +
                    '<CIFNumber>CIF-IPP-001</CIFNumber><FullName>Nguyen Van IPP</FullName>' +
                    '<NationalID>079123456789</NationalID><DateOfBirth>1990-05-15</DateOfBirth>' +
                    '<Phones><PhoneNode><Type>Mobile</Type><Phone>0909998877</Phone></PhoneNode></Phones>' +
                    '<Emails><Email>ipp@example.com</Email></Emails>' +
                    '</Customer></Customers></cif:GetCustomerListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getcustomerinfobasic')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCustomerInfoBasicResponse>' +
                    '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                    '<CustomerBasicInfo><FullName>Nguyen Van IPP</FullName><Gender>Male</Gender>' +
                    '<Birthday>1990-05-15</Birthday><CIFNumber>CIF-IPP-001</CIFNumber>' +
                    '<PreferredContacts><PreferredContact><Contact>' +
                    '<Channel>Email</Channel><ContactString>ipp@example.com</ContactString>' +
                    '</Contact></PreferredContact></PreferredContacts></CustomerBasicInfo>' +
                    '</GetCustomerInfoBasicResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getcontactslist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetContactsListResponse><Sys><Code>1</Code></Sys>' +
                    '<Contacts>' +
                    '<Contact><ContactId>C1</ContactId><Channel>Phone</Channel>' +
                    '<CommunicationType>Mobile</CommunicationType><ContactString>0901112233</ContactString></Contact>' +
                    '<Contact><ContactId>C2</ContactId><Channel>Email</Channel>' +
                    '<CommunicationType>Personal</CommunicationType><ContactString>contact@example.com</ContactString></Contact>' +
                    '</Contacts></GetContactsListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getaddresseslist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetAddressesListResponse><Sys><Code>1</Code></Sys>' +
                    '<Addresses>' +
                    '<Address><AddressType>CURRES</AddressType><Street>10 Nguyen Hue</Street>' +
                    '<City>79</City><District>D01</District><CountryName>Vietnam</CountryName></Address>' +
                    '<Address><AddressType>PERMNENT</AddressType><Street>20 Le Loi</Street></Address>' +
                    '<Address><AddressType>PERMANENT</AddressType><Street>30 Tran Hung Dao</Street></Address>' +
                    '<Address><AddressType>OFFICE</AddressType><Street>40 Pasteur</Street></Address>' +
                    '</Addresses></GetAddressesListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getdocumentslist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetDocumentsListResponse><Sys><Code>1</Code></Sys>' +
                    '<Documents><Document><DocumentID>DOC-IPP-001</DocumentID>' +
                    '<IssueDate>2020-01-01</IssueDate><IssuePlace>HCMC</IssuePlace></Document></Documents>' +
                    '</GetDocumentsListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getcardbasicinfo')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCardBasicInfoResponse><Sys><Code>1</Code></Sys>' +
                    '<CardBasicInfo><MainCard>' +
                    '<AccountNumber>' + ACCOUNT_NUMBER + '</AccountNumber>' +
                    '<ContractNumber>CTR-IPP-001</ContractNumber><Status>Active</Status>' +
                    '<CreditLimit>10000000</CreditLimit><OTB>5000000</OTB><HoldAmount>100000</HoldAmount>' +
                    '<MaskedCardNumber>****9999</MaskedCardNumber><PlasticIndicator>PLASTIC-IPP</PlasticIndicator>' +
                    '<BlockCode>BC</BlockCode><ActivatedFlag>Y</ActivatedFlag><InsuranceFlag>1</InsuranceFlag>' +
                    '</MainCard><PassDue><DPD>3</DPD></PassDue>' +
                    '<CardHistories><CardHistory><CardActivationDate>20240101</CardActivationDate></CardHistory></CardHistories>' +
                    '</CardBasicInfo></GetCardBasicInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('m_fas_outstanding_auth_inq') || body.contains('outstanding_auth')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><WSResponse><Sys><Code>1</Code></Sys>' +
                    '<M_FAS_OUTSTANDING_AUTH_INQ><VMX_ROOT><VMX_MSGOUT>' +
                    '<SVC_RETURN>S</SVC_RETURN><AUTHS_TABLE>' +
                    '<AuthRow><EFF_DATE>20260115</EFF_DATE><AUTH_AMOUNT>150000</AUTH_AMOUNT>' +
                    '<AUTHORIZATION_CODE>AUTH001</AUTHORIZATION_CODE><Description>Merchant A</Description>' +
                    '<CreditDebitFlag>D</CreditDebitFlag></AuthRow>' +
                    '</AUTHS_TABLE></VMX_MSGOUT></VMX_ROOT></M_FAS_OUTSTANDING_AUTH_INQ>' +
                    '</WSResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getcardsecinfo') || endpoint.contains('cardsec')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCardSecInfoResponse><Sys><Code>1</Code></Sys>' +
                    '<CardSecInfo>' +
                    '<MainCardProduct><DailyRetailLimit>1000</DailyRetailLimit><DailyCashLimit>500</DailyCashLimit></MainCardProduct>' +
                    '<MainCardPlastic><EmbossingName>NGUYEN VAN IPP</EmbossingName><EcomActiveFlag>1</EcomActiveFlag></MainCardPlastic>' +
                    '<MainCardBalance><CurrentBalance>2500000</CurrentBalance><TotalBalance>3000000</TotalBalance></MainCardBalance>' +
                    '<PassDue><ResponsibleUnit>Unit A</ResponsibleUnit></PassDue>' +
                    '<IPPs>' +
                    '<IPP><IPPPlan>IPP-PLAN-A</IPPPlan><IPPRecordNo>REC-A</IPPRecordNo>' +
                    '<IPPOpenDate>2026-01-15</IPPOpenDate><IPPBalance>1000000</IPPBalance>' +
                    '<InterestRate>1.5</InterestRate><Term>12</Term><CurrentTerm>3</CurrentTerm>' +
                    '<IPPStartDate>2026-02-01</IPPStartDate><IPPMatureDate>2027-02-01</IPPMatureDate>' +
                    '<IPPCurrentBalance>900000</IPPCurrentBalance></IPP>' +
                    '<IPP><IPPPlan>IPP-PLAN-B</IPPPlan><IPPRecordNo>REC-B</IPPRecordNo>' +
                    '<OpenDate>2026-03-01</OpenDate><IPPBalance>500000</IPPBalance>' +
                    '<InterestRate>2.0</InterestRate><Term>6</Term></IPP>' +
                    '<IPP><IPPPlan>IPP-PLAN-A</IPPPlan><IPPRecordNo>REC-A</IPPRecordNo></IPP>' +
                    '</IPPs></CardSecInfo></GetCardSecInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getcardplaninfo') || endpoint.contains('plan')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><cif:GetCardPlanInfoResponse xmlns:cif="http://fecredit.com.vn/CIF_CardInfo">' +
                    '<Sys><Code>1</Code></Sys><CardPlanInfo><CardPlans>' +
                    '<CardPlan><RecordNumber>REC-A</RecordNumber><PlanNumber>PLAN-OLD</PlanNumber>' +
                    '<PlanOpenDate>2026-01-10</PlanOpenDate><PlanCurrentBalance>800000</PlanCurrentBalance>' +
                    '<BaseRate>12.5</BaseRate><CloseFeelIndicator>Y</CloseFeelIndicator>' +
                    '<CloseFeelIndicatorAmount>40000</CloseFeelIndicatorAmount>' +
                    '<PlanPaymentAmount>100000</PlanPaymentAmount>' +
                    '<AccruedInterest>5000</AccruedInterest><PerDiem>200</PerDiem>' +
                    '<DeferredInterest>1000</DeferredInterest><AccruedInt>300</AccruedInt>' +
                    '</CardPlan></CardPlans></CardPlanInfo>' +
                    '</cif:GetCardPlanInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            res.setBody('');
            return res;
        }
    }

    @IsTest
    static void testSyncCustomer_CardFullWithIppFromCardSecInfo() {
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE,
            FEC_Active__c = true
        );
        insert pt;

        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'IPP Card Sec sync',
                Status = 'New',
                FEC_Product_Type__c = pt.Id,
                FEC_ID_Search__c = 'CIS-IPP-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;

        insert new FEC_IPP__c(
            FEC_Customer_History__c = hist.Id,
            FEC_IPP_Plan__c = 'OLD-IPP',
            FEC_IPP_Balance__c = 1
        );
        insert new FEC_Card_Payment__c(
            FEC_Customer_History__c = hist.Id,
            FEC_Rec__c = 'REC-A',
            FEC_Plan__c = 'PLAN-OLD',
            FEC_Current_Balance__c = 100
        );
        insert new FEC_Transaction__c(
            FEC_Customer_History__c = hist.Id,
            FEC_Transaction_Code__c = 'AUTH001',
            FEC_Effective_Date__c = Date.newInstance(2026, 1, 15),
            FEC_Transaction_Amount__c = 150000
        );
        insert new FEC_Contact_List__c(
            FEC_Customer_History__c = hist.Id,
            FEC_Channel__c = FEC_ConstantCommon.EMAIL,
            FEC_Contact_String__c = 'old@example.com'
        );

        hist = FEC_CustomerIntegrationService.queryHistoryForSync(hist.Id);

        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationCardFullMock());
        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(hist, null, null, ACCOUNT_NUMBER);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Nguyen Van IPP', result.customerName);
        System.assertEquals('PLASTIC-IPP', result.plasticID);

        List<FEC_IPP__c> ipps = [
            SELECT FEC_IPP_Plan__c, FEC_IPP_Open_Date__c, FEC_IPP_Balance__c,
                   FEC_IPP_Interest_Rate__c, FEC_IPP_Term__c, FEC_IPP_Record_No__c
            FROM FEC_IPP__c
            WHERE FEC_Customer_History__c = :hist.Id
            ORDER BY FEC_IPP_Plan__c
        ];
        System.assertEquals(2, ipps.size(), 'Phải sync 2 IPP từ CardSecInfo.');
        System.assertEquals('IPP-PLAN-A', ipps[0].FEC_IPP_Plan__c);
        System.assertEquals(Date.newInstance(2026, 1, 15), ipps[0].FEC_IPP_Open_Date__c);
        System.assertEquals(1000000, ipps[0].FEC_IPP_Balance__c);
        System.assertEquals(1.5, ipps[0].FEC_IPP_Interest_Rate__c);
        System.assertEquals(12, ipps[0].FEC_IPP_Term__c);
        System.assertEquals('REC-A', ipps[0].FEC_IPP_Record_No__c);
        System.assertEquals('IPP-PLAN-B', ipps[1].FEC_IPP_Plan__c);
        System.assertEquals(Date.newInstance(2026, 3, 1), ipps[1].FEC_IPP_Open_Date__c);

        System.assertEquals('NGUYEN VAN IPP', hist.FEC_Embossing_Name__c);
        System.assertEquals(2500000, hist.FEC_Current_Balance__c);
    }

    private class CustomerIntegrationLoanFullMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint() != null ? req.getEndpoint().toLowerCase() : '';
            String body = req.getBody() != null ? req.getBody().toLowerCase() : '';
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            if (endpoint.contains('customerlist') || body.contains('getcustomerlist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCustomerListResponse><Sys><Code>1</Code></Sys>' +
                    '<Customers><Customer><CIFNumber>CIF-LOAN-002</CIFNumber>' +
                    '<FullName>Tran Thi Loan</FullName><NationalID>079987654321</NationalID>' +
                    '</Customer></Customers></GetCustomerListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getcustomerinfobasic')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCustomerInfoBasicResponse><Sys><Code>1</Code></Sys>' +
                    '<CustomerBasicInfo><FullName>Tran Thi Loan</FullName><CIFNumber>CIF-LOAN-002</CIFNumber>' +
                    '</CustomerBasicInfo></GetCustomerInfoBasicResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getaddresseslist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetAddressesListResponse><Sys><Code>1</Code></Sys>' +
                    '<Addresses><Address><AddressType>CURRES</AddressType><Street>99 Loan St</Street>' +
                    '<CountryCode>2</CountryCode><CountryName>Vietnam</CountryName></Address></Addresses>' +
                    '</GetAddressesListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getdocumentslist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetDocumentsListResponse><Sys><Code>1</Code></Sys>' +
                    '<Documents><Document><DocumentID>DOC-LOAN-001</DocumentID></Document></Documents>' +
                    '</GetDocumentsListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getloanbasicinfo')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetLoanBasicInfoResponse><Sys><Code>1</Code></Sys>' +
                    '<LoanBasicInfo><Loan><ContractNumber>12345678-123456-1234</ContractNumber>' +
                    '<ContractStatus>ACTIVE</ContractStatus><ContractType>Personal</ContractType>' +
                    '<AgreementDate>2025-01-01</AgreementDate>' +
                    '<ApplicationID>APP-LOAN</ApplicationID><CompanyName>FEC</CompanyName></Loan>' +
                    '<Product><LoanAmount>50000000</LoanAmount><Tenure>36</Tenure><EMI>2000000</EMI>' +
                    '<Rate>15</Rate><Product>PL</Product></Product>' +
                    '<TerminationSimulation><NextDueDate>2026-07-01</NextDueDate></TerminationSimulation>' +
                    '<PassDue><DPD>10</DPD></PassDue></LoanBasicInfo>' +
                    '</GetLoanBasicInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getmrcinfo')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetMRCInfoResponse><Sys><Code>1</Code></Sys>' +
                    '<MRCZone>Zone-B</MRCZone><Area>Area-1</Area><PlateNumber>51A-12345</PlateNumber>' +
                    '<StatusID>S1</StatusID><Status>Active</Status>' +
                    '<ModifiedDate>bad-date</ModifiedDate><ProvideNumber>not-decimal</ProvideNumber>' +
                    '<Remark>Test remark</Remark><ReceiverInformation>Receiver A</ReceiverInformation>' +
                    '<Mailcode>2026-06-01</Mailcode><ReceivedDate>2026-06-02</ReceivedDate>' +
                    '<NotaryPostedDate>2026-06-03</NotaryPostedDate><NotaryMailcode>700000</NotaryMailcode>' +
                    '<NotaryRemark>Notary note</NotaryRemark><NotaryReceiverInformation>Notary recv</NotaryReceiverInformation>' +
                    '</GetMRCInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            res.setBody('');
            return res;
        }
    }

    @IsTest
    static void testSyncCustomer_LoanWithMrcAndAddresses() {
        FEC_Country__c countryApi = new FEC_Country__c(
            Name = 'Vietnam API',
            FEC_Code__c = '2',
            FEC_Name_VN__c = 'Vietnam'
        );
        insert countryApi;

        FEC_Product_Type__c loanPt = new FEC_Product_Type__c(
            Name = 'Loan',
            FEC_Code__c = FEC_ConstantCommon.PRODUCT_TYPE_LOAN_CASE,
            FEC_Active__c = true
        );
        insert loanPt;

        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'Loan MRC sync',
                Status = 'New',
                FEC_Product_Type__c = loanPt.Id,
                FEC_ID_Search__c = 'CIS-LMRC-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Contract_Number__c = '12345678-123456-1234',
            FEC_CIF_Number__c = 'CIF-LOAN-002',
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;

        insert new FEC_Address_Info__c(
            Name = 'Current Address',
            FEC_Customer_History__c = hist.Id,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT,
            FEC_Street__c = 'Old Street'
        );

        hist = FEC_CustomerIntegrationService.queryHistoryForSync(hist.Id);

        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationLoanFullMock());
        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(hist, hist.FEC_CIF_Number__c, null, null);
        Test.stopTest();

        System.assertEquals('Tran Thi Loan', result.customerName);
        System.assertEquals(50000000, hist.FEC_Loan_Amount__c);
        System.assertEquals(36, hist.FEC_Tenure__c);
        System.assertEquals('Zone-B', hist.FEC_MRC_Zone__c);
        System.assertEquals('Area-1', hist.FEC_Area__c);
        System.assertEquals('51A-12345', hist.FEC_Plate_Number__c);
        System.assertEquals('Test remark', hist.FEC_Original_MRC_Remark__c);
        System.assertEquals(Date.newInstance(2026, 6, 1), hist.FEC_Delivery_Date__c);
        System.assertEquals('Notary note', hist.FEC_Notarized_MRC_Remark__c);
        System.assertEquals(10, hist.FEC_Days_Past_Due__c);

        List<FEC_Address_Info__c> addresses = [
            SELECT FEC_Street__c, FEC_Country__c
            FROM FEC_Address_Info__c
            WHERE FEC_Customer_History__c = :hist.Id
              AND FEC_Address_Type__c = :FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT
        ];
        System.assertEquals(1, addresses.size());
        System.assertEquals('99 Loan St', addresses[0].FEC_Street__c);
        System.assertEquals(countryApi.Id, addresses[0].FEC_Country__c);
    }

    @IsTest
    static void testSyncCustomer_AddressMasterDataAndIppDashPlan() {
        FEC_Country__c legacyCountry = new FEC_Country__c(
            Name = 'Vietnam Legacy',
            FEC_Code__c = '1',
            FEC_Name_VN__c = 'Viet Nam'
        );
        FEC_Country__c apiCountry = new FEC_Country__c(
            Name = 'Vietnam API Master',
            FEC_Code__c = '2',
            FEC_Name_VN__c = 'Viet Nam'
        );
        insert new List<FEC_Country__c>{ legacyCountry, apiCountry };

        FEC_Province__c legacyProvince = new FEC_Province__c(
            Name = 'Ha Noi Legacy',
            FEC_Code__c = 'HN01',
            FEC_Name_VN__c = 'Ha Noi',
            FEC_Country__c = legacyCountry.Id
        );
        insert legacyProvince;

        FEC_Province__c apiProvince = new FEC_Province__c(
            Name = 'Ha Noi API',
            FEC_Code__c = 'HN01-API',
            FEC_Name_VN__c = 'Ha Noi',
            FEC_Country__c = apiCountry.Id
        );
        insert apiProvince;

        FEC_District__c district = new FEC_District__c(
            Name = 'Ba Dinh',
            FEC_Code__c = 'BD01'
        );
        insert district;

        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE,
            FEC_Active__c = true
        );
        insert pt;

        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'Address IPP dash',
                Status = 'New',
                FEC_Product_Type__c = pt.Id,
                FEC_ID_Search__c = 'CIS-ADDR-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_CIF_Number__c = 'CIF-ADDR-001',
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;

        insert new FEC_Address_Info__c(
            Name = 'Office Address',
            FEC_Customer_History__c = hist.Id,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE,
            FEC_Street__c = 'Old Office'
        );

        hist = FEC_CustomerIntegrationService.queryHistoryForSync(hist.Id);

        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationAddressIppMock());
        Test.startTest();
        FEC_CustomerIntegrationService.syncCustomer(hist, hist.FEC_CIF_Number__c, null, ACCOUNT_NUMBER);
        Test.stopTest();

        List<FEC_IPP__c> dashIpps = [
            SELECT FEC_IPP_Plan__c
            FROM FEC_IPP__c
            WHERE FEC_Customer_History__c = :hist.Id
              AND FEC_IPP_Plan__c = :FEC_ConstantCommon.STR_DASH
        ];
        System.assertEquals(1, dashIpps.size());

        List<FEC_Address_Info__c> officeAddresses = [
            SELECT FEC_Street__c, FEC_District__c, FEC_Province__c, FEC_Country__c
            FROM FEC_Address_Info__c
            WHERE FEC_Customer_History__c = :hist.Id
              AND FEC_Address_Type__c = :FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE
        ];
        System.assertEquals(1, officeAddresses.size());
        System.assertEquals('88 Lang Ha', officeAddresses[0].FEC_Street__c);
        System.assertEquals(district.Id, officeAddresses[0].FEC_District__c);
        System.assertEquals(apiProvince.Id, officeAddresses[0].FEC_Province__c);
        System.assertEquals(apiCountry.Id, officeAddresses[0].FEC_Country__c);

        List<FEC_Address_Info__c> currentAddresses = [
            SELECT FEC_Street__c, FEC_Building__c, FEC_Number__c, FEC_District_Text__c, FEC_Country_Text__c
            FROM FEC_Address_Info__c
            WHERE FEC_Customer_History__c = :hist.Id
              AND FEC_Address_Type__c = :FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT
        ];
        System.assertEquals(1, currentAddresses.size());
        System.assertEquals('12 Current St', currentAddresses[0].FEC_Street__c);
        System.assertEquals('B1', currentAddresses[0].FEC_Building__c);
        System.assertEquals('UNKNOWN_DIST', currentAddresses[0].FEC_District_Text__c);
        System.assertEquals('Other Country', currentAddresses[0].FEC_Country_Text__c);
    }

    @IsTest
    static void testSyncCustomer_EnrichesCustomerListMetadata() {
        Case c = insertIntegrationCase('Customer list enrich');
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;
        hist = FEC_CustomerIntegrationService.queryHistoryForSync(hist.Id);

        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationCustomerListEnrichMock());
        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(hist, null, null, ACCOUNT_NUMBER);
        Test.stopTest();

        System.assertEquals('Nguyen Van Enrich', result.customerName);
        System.assertEquals(Date.newInstance(1985, 3, 20), result.dateOfBirth);
        System.assertEquals('enrich@example.com', result.emailAddress);
        System.assertEquals('0791112222', result.nationalId);
        System.assertEquals('0908887766', result.primaryPhone);
        System.assertEquals(Date.newInstance(1985, 3, 20), hist.FEC_Date_of_Birth__c);
        System.assertEquals('enrich@example.com', hist.FEC_Email__c);
    }

    private class CustomerIntegrationCustomerListEnrichMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String body = req.getBody() != null ? req.getBody().toLowerCase() : '';
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            if (body.contains('getcustomerlist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCustomerListResponse><Sys><Code>1</Code></Sys>' +
                    '<Customers><Customer><CIFNumber>CIF-ENRICH-001</CIFNumber>' +
                    '<FullName>Nguyen Van Enrich</FullName><NationalID>0791112222</NationalID>' +
                    '<DateOfBirth>1985-03-20</DateOfBirth>' +
                    '<Phones><PhoneNode><Type>Mobile</Type><Phone>0908887766</Phone></PhoneNode></Phones>' +
                    '<Emails><Email>enrich@example.com</Email></Emails>' +
                    '</Customer></Customers></GetCustomerListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getcustomerinfobasic')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCustomerInfoBasicResponse><Sys><Code>1</Code></Sys>' +
                    '<CustomerBasicInfo></CustomerBasicInfo></GetCustomerInfoBasicResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            res.setBody('');
            return res;
        }
    }

    @IsTest
    static void testSyncCustomer_SkipsBlankCardPlanNumber() {
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE,
            FEC_Active__c = true
        );
        insert pt;

        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'Blank plan skip',
                Status = 'New',
                FEC_Product_Type__c = pt.Id,
                FEC_ID_Search__c = 'CIS-BP-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_CIF_Number__c = 'CIF-BP-001',
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;
        hist = FEC_CustomerIntegrationService.queryHistoryForSync(hist.Id);

        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationBlankPlanMock());
        Test.startTest();
        FEC_CustomerIntegrationService.syncCustomer(hist, hist.FEC_CIF_Number__c, null, ACCOUNT_NUMBER);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM FEC_IPP__c WHERE FEC_Customer_History__c = :hist.Id]);
    }

    private class CustomerIntegrationBlankPlanMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String body = req.getBody() != null ? req.getBody().toLowerCase() : '';
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            if (body.contains('getcustomerlist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCustomerListResponse><Sys><Code>1</Code></Sys>' +
                    '<Customers><Customer><CIFNumber>CIF-BP-001</CIFNumber></Customer></Customers>' +
                    '</GetCustomerListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getcustomerinfobasic')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCustomerInfoBasicResponse><Sys><Code>1</Code></Sys>' +
                    '<CustomerBasicInfo></CustomerBasicInfo></GetCustomerInfoBasicResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getcardsecinfo')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCardSecInfoResponse><Sys><Code>1</Code></Sys>' +
                    '<CardSecInfo><IPPs></IPPs></CardSecInfo></GetCardSecInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getcardplaninfo')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><cif:GetCardPlanInfoResponse xmlns:cif="http://fecredit.com.vn/CIF_CardInfo">' +
                    '<Sys><Code>1</Code></Sys><CardPlanInfo><CardPlans>' +
                    '<CardPlan><RecordNumber>R0</RecordNumber><PlanNumber></PlanNumber></CardPlan>' +
                    '</CardPlans></CardPlanInfo></cif:GetCardPlanInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            res.setBody('');
            return res;
        }
    }

    @IsTest
    static void testSyncCustomer_BasicInfoSkipsExistingEmail() {
        Case c = insertIntegrationCase('Skip existing email');
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_CIF_Number__c = 'CIF-EMAIL-001',
            FEC_Email__c = 'keep@example.com',
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;
        hist = FEC_CustomerIntegrationService.queryHistoryForSync(hist.Id);

        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationMock());
        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(hist, hist.FEC_CIF_Number__c, null, null);
        Test.stopTest();

        System.assertEquals('keep@example.com', hist.FEC_Email__c);
        System.assertEquals(null, result.emailAddress);
    }

    private class CustomerIntegrationPhoneFallbackMock implements HttpCalloutMock {
        private Integer customerListCalls = 0;

        public HttpResponse respond(HttpRequest req) {
            String body = req.getBody() != null ? req.getBody().toLowerCase() : '';
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            if (body.contains('getcustomerlist')) {
                customerListCalls++;
                String phones = customerListCalls == 1
                    ? ''
                    : '<Phones><PhoneNode><Type>Mobile</Type><Phone>0912345678</Phone></PhoneNode></Phones>';
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCustomerListResponse><Sys><Code>1</Code></Sys>' +
                    '<Customers><Customer><CIFNumber>CIF-PH-001</CIFNumber><FullName>Phone Fallback</FullName>' +
                    phones + '</Customer></Customers></GetCustomerListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getcustomerinfobasic')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCustomerInfoBasicResponse><Sys><Code>1</Code></Sys>' +
                    '<CustomerBasicInfo><FullName>Phone Fallback</FullName></CustomerBasicInfo>' +
                    '</GetCustomerInfoBasicResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            res.setBody('');
            return res;
        }
    }

    @IsTest
    static void testSyncCustomer_InteractionCaseProductTypeCardPath() {
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE,
            FEC_Active__c = true
        );
        insert pt;

        Id interactionRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)
            .getRecordTypeId();

        Case parentCase = insertIntegrationCase('Parent no product type');
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = parentCase.Id,
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                RecordTypeId = interactionRtId,
                Subject = 'Interaction card type',
                Status = 'New',
                FEC_Product_Type__c = pt.Id,
                FEC_Account_or_Contract__c = hist.Id,
                FEC_ID_Search__c = 'CIS-INT-' + String.valueOf(System.currentTimeMillis())
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        hist = FEC_CustomerIntegrationService.queryHistoryForSync(hist.Id);

        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationMock());
        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(hist, null, null, ACCOUNT_NUMBER);
        Test.stopTest();

        System.assertNotEquals(null, result.customerName);
        List<FEC_IPP__c> ipps = [
            SELECT Id FROM FEC_IPP__c WHERE FEC_Customer_History__c = :hist.Id
        ];
        System.assertEquals(1, ipps.size());
        System.assertEquals(
            1,
            [SELECT COUNT() FROM FEC_Transaction__c WHERE FEC_Customer_History__c = :hist.Id]
        );
    }

    @IsTest
    static void testSyncCustomer_PrimaryPhoneFallbackFromCustomerList() {
        Case c = insertIntegrationCase('Phone fallback sync');
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;
        hist = FEC_CustomerIntegrationService.queryHistoryForSync(hist.Id);

        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationPhoneFallbackMock());
        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(hist, null, null, ACCOUNT_NUMBER);
        Test.stopTest();

        System.assertEquals('0912345678', result.primaryPhone);
        System.assertEquals('0912345678', hist.FEC_Primary_Phone__c);
    }

    private class CustomerIntegrationAddressIppMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String body = req.getBody() != null ? req.getBody().toLowerCase() : '';
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            if (body.contains('getcustomerinfobasic')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCustomerInfoBasicResponse><Sys><Code>1</Code></Sys>' +
                    '<CustomerBasicInfo><FullName>Addr User</FullName></CustomerBasicInfo>' +
                    '</GetCustomerInfoBasicResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getaddresseslist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetAddressesListResponse><Sys><Code>1</Code></Sys>' +
                    '<Addresses>' +
                    '<Address><AddressType>PERMNENT</AddressType><Street>Permanent A</Street></Address>' +
                    '<Address><AddressType>PERMANENT</AddressType><Street>Permanent B</Street></Address>' +
                    '<Address><AddressType>CURRES</AddressType><Street>12 Current St</Street>' +
                    '<Building>B1</Building><Number>10</Number><ZipCode>70000</ZipCode>' +
                    '<District>UNKNOWN_DIST</District><CountryName>Other Country</CountryName></Address>' +
                    '<Address><AddressType>OFFICE</AddressType><Street>88 Lang Ha</Street>' +
                    '<City>HN01</City><District>BD01</District><CountryName>Viet Nam</CountryName></Address>' +
                    '</Addresses></GetAddressesListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (body.contains('getcardsecinfo')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCardSecInfoResponse><Sys><Code>1</Code></Sys>' +
                    '<CardSecInfo><IPPs>' +
                    '<IPP><IPPRecordNo>REC-DASH</IPPRecordNo><IPPBalance>100</IPPBalance>' +
                    '<OPENING_BALANCE_1>500</OPENING_BALANCE_1></IPP>' +
                    '</IPPs></CardSecInfo></GetCardSecInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            res.setBody('');
            return res;
        }
    }
}
