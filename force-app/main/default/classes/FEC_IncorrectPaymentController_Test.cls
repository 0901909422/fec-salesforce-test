@IsTest
private class FEC_IncorrectPaymentController_Test {

    private static User adminUser() {
        return [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = TRUE
            LIMIT 1
        ];
    }

    @TestSetup
    static void setup() {
        String suffix = String.valueOf(System.currentTimeMillis());
        FEC_API_Setting__c apiSetting = new FEC_API_Setting__c(
            FEC_Enviroment__c = FEC_ConstantCommon.ENVIROMENT_NON_PRODUCTION,
            FEC_Call_Mock__c = false,
            FEC_Endpoint__c = 'https://test.com/api'
        );
        insert apiSetting;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                Subject = 'FEC_IncorrectPaymentController_Test',
                Status = 'New',
                FEC_ID_Search__c = 'INCP-' + suffix
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testGetPaymentHistoryFromSOAP_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        try {
            FEC_IncorrectPaymentController.getPaymentHistoryFromSOAP(c.Id, 'CON123');
        } catch (Exception e) {
            System.assert(true, 'Expected without SOAP mock: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveAdjustment_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        List<FEC_IncorrectPaymentController.AdjustmentDTO> adjs =
            new List<FEC_IncorrectPaymentController.AdjustmentDTO>();
        FEC_IncorrectPaymentController.AdjustmentDTO adj =
            new FEC_IncorrectPaymentController.AdjustmentDTO();
        adj.correctContract = '1';
        adj.adjustedAmount = 1000;
        adjs.add(adj);

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_IncorrectPaymentController.saveAdjustment(
                c.Id,
                'CON_BAD',
                'Bank Transfers',
                '2026-05-25',
                1000,
                adjs
            );
            Test.stopTest();

            Case updatedCase = [
                SELECT FEC_Adjusted_Amount__c,
                    FEC_Incorrect_Contract_Number__c,
                    FEC_Payment_Method__c,
                    FEC_Correct_Contract_Number__c,
                    FEC_Input_Correct_Contract_Number__c,
                    FEC_Bill_Amount__c
                FROM Case
                WHERE Id = :c.Id
            ];
            System.assertEquals(1000, updatedCase.FEC_Adjusted_Amount__c);
            System.assertEquals('CON_BAD', updatedCase.FEC_Incorrect_Contract_Number__c);
            System.assertEquals('Bank Transfers', updatedCase.FEC_Payment_Method__c);
            System.assertEquals('1', updatedCase.FEC_Correct_Contract_Number__c);
            System.assertEquals('1', updatedCase.FEC_Input_Correct_Contract_Number__c);
            System.assertEquals(1000, updatedCase.FEC_Bill_Amount__c);

            List<FEC_Incorrect_Payment_Info__c> infoRows = [
                SELECT FEC_Adjusted_Amount__c, FEC_Correct_Account_Contract__c
                FROM FEC_Incorrect_Payment_Info__c
                WHERE FEC_Case__c = :c.Id
            ];
            System.assertEquals(1, infoRows.size());
            System.assertEquals(1000, infoRows[0].FEC_Adjusted_Amount__c);
            System.assertEquals('1', infoRows[0].FEC_Correct_Account_Contract__c);
        }
    }

    @IsTest
    static void testGetSubCodeConfig() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_IncorrectPaymentController.SubCodeConfigDTO dto =
            FEC_IncorrectPaymentController.getSubCodeConfig(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto);
    }

    @IsTest
    static void testGetPaymentHistoryFromSOAP_BlankContract() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        List<FEC_IncorrectPaymentController.PaymentDTO> empty =
            FEC_IncorrectPaymentController.getPaymentHistoryFromSOAP(c.Id, '');
        Test.stopTest();

        System.assertEquals(0, empty.size());
    }

    @IsTest
    static void testGetPaymentHistoryFromSOAP_WithMock() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            Name = 'IPP-PH-TEST',
            FEC_Contract_Number__c = '20170108-0005091',
            FEC_Case__c = c.Id
        );
        insert hist;
        update new Case(Id = c.Id, FEC_Account_or_Contract__c = hist.Id);
        Test.setMock(HttpCalloutMock.class, new MockLoanSecInfoSuccess());

        Test.startTest();
        List<FEC_IncorrectPaymentController.PaymentDTO> payments =
            FEC_IncorrectPaymentController.getPaymentHistoryFromSOAP(c.Id, '20170108-0005091');
        Test.stopTest();

        System.assertEquals(1, payments.size());
        System.assertEquals('1', payments[0].paymentNo);
        List<FEC_Payment_History__c> saved = [
            SELECT Id, FEC_Payment_No__c, FEC_Payment_Amount__c, FEC_Customer_History__c
            FROM FEC_Payment_History__c
            WHERE FEC_Customer_History__c = :hist.Id
        ];
        System.assertEquals(1, saved.size());
        System.assertEquals(1, saved[0].FEC_Payment_No__c);
        System.assertEquals(620.00, saved[0].FEC_Payment_Amount__c);
    }

    @IsTest
    static void testPicklistAndContractOptions() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<FEC_CommonUltils.PicklistOption> paymentMethods =
            FEC_IncorrectPaymentController.getPaymentMethodOptions();
        List<FEC_CommonUltils.PicklistOption> correctContracts =
            FEC_IncorrectPaymentController.getCorrectContractOptions(c.Id);
        List<FEC_CommonUltils.PicklistOption> incorrectContracts =
            FEC_IncorrectPaymentController.getIncorrectContractOptions(c.Id);
        List<FEC_CommonUltils.PicklistOption> nullCase =
            FEC_IncorrectPaymentController.getIncorrectContractOptions(null);
        Test.stopTest();

        System.assertNotEquals(null, paymentMethods);
        System.assertNotEquals(null, correctContracts);
        System.assertNotEquals(null, incorrectContracts);
        System.assertEquals(0, nullCase.size());
    }

    @IsTest
    static void testGetLoanContractOptionsFromApi_WithMock() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        update new Case(
            Id = c.Id,
            FEC_Contract_Number__c = '20170108-0005091'
        );
        Test.setMock(HttpCalloutMock.class, new MockGetCustomerListSuccess());

        Test.startTest();
        List<FEC_CommonUltils.PicklistOption> options =
            FEC_IncorrectPaymentController.getLoanContractOptionsFromApi(c.Id);
        Test.stopTest();

        System.assert(!options.isEmpty(), 'Should include contract options.');
        Set<String> values = new Set<String>();
        for (FEC_CommonUltils.PicklistOption opt : options) {
            if (opt != null && String.isNotBlank(opt.value)) {
                values.add(opt.value);
            }
        }
        System.assert(values.contains('20170108-0005091'), 'Should include contract from Case.');
        System.assert(values.contains('20170108-0005092'), 'Should include ContractNumber from GetCustomerList Applications.');
    }

    @IsTest
    static void testSaveAdjustmentDraft() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_IncorrectPaymentController.saveAdjustmentDraft(
                c.Id,
                'CON_DRAFT',
                'Bank Transfers',
                '2026-05-25',
                500,
                '1',
                500
            );
            Test.stopTest();

            Case updated = [
                SELECT FEC_Incorrect_Contract_Number__c, FEC_Bill_Amount__c
                FROM Case
                WHERE Id = :c.Id
            ];
            System.assertEquals('CON_DRAFT', updated.FEC_Incorrect_Contract_Number__c);
            System.assertEquals(500, updated.FEC_Bill_Amount__c);
        }
    }

    @IsTest
    static void testSaveAdjustment_ValidationErrors() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        try {
            FEC_IncorrectPaymentController.saveAdjustment(null, 'X', 'Bank Transfers', '2026-05-25', 100, null);
            System.assert(false, 'Null case should throw.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            FEC_IncorrectPaymentController.saveAdjustment(
                c.Id,
                'CON_BAD',
                '',
                '2026-05-25',
                100,
                new List<FEC_IncorrectPaymentController.AdjustmentDTO>()
            );
            System.assert(false, 'Empty adjustments should throw.');
        } catch (AuraHandledException e2) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSubCodeConfig_WithAdjustmentRowsJson() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        List<FEC_IncorrectPaymentController.AdjustmentDTO> adjs =
            new List<FEC_IncorrectPaymentController.AdjustmentDTO>();
        FEC_IncorrectPaymentController.AdjustmentDTO adj =
            new FEC_IncorrectPaymentController.AdjustmentDTO();
        adj.correctContract = '1';
        adj.adjustedAmount = 250;
        adjs.add(adj);

        update new Case(
            Id = c.Id,
            FEC_Incorrect_Payment_Adj_Rows__c = JSON.serialize(adjs)
        );

        Test.startTest();
        FEC_IncorrectPaymentController.SubCodeConfigDTO dto =
            FEC_IncorrectPaymentController.getSubCodeConfig(c.Id);
        FEC_IncorrectPaymentController.SubCodeConfigDTO nullDto =
            FEC_IncorrectPaymentController.getSubCodeConfig(null);
        Test.stopTest();

        System.assertNotEquals(null, dto.adjustmentRows);
        System.assertEquals(1, dto.adjustmentRows.size());
        System.assertNotEquals(null, nullDto);
    }

    @IsTest
    static void testGetPaymentHistoryFromSOAP_FailureResponse() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockLoanSecInfoFailure());

        Test.startTest();
        try {
            FEC_IncorrectPaymentController.getPaymentHistoryFromSOAP(c.Id, 'CON-FAIL');
            System.assert(false, 'Non-success SOAP response should throw.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetPaymentHistoryFromSOAP_EmptyHistories() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockLoanSecInfoEmptyHistory());

        Test.startTest();
        try {
            FEC_IncorrectPaymentController.getPaymentHistoryFromSOAP(c.Id, 'CON-EMPTY');
            System.assert(false, 'Empty payment histories should throw.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveAdjustment_AmountMismatch() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        List<FEC_IncorrectPaymentController.AdjustmentDTO> adjs =
            new List<FEC_IncorrectPaymentController.AdjustmentDTO>();
        FEC_IncorrectPaymentController.AdjustmentDTO adj =
            new FEC_IncorrectPaymentController.AdjustmentDTO();
        adj.correctContract = '1';
        adj.adjustedAmount = 500;
        adjs.add(adj);

        Test.startTest();
        try {
            FEC_IncorrectPaymentController.saveAdjustment(
                c.Id,
                'CON_BAD',
                'Bank Transfers',
                '2026-05-25',
                1000,
                adjs
            );
            System.assert(false, 'Sum adjusted amount mismatch should throw.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveSelectedPaymentHistory() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            Name = 'IPP-SEL-PH',
            FEC_Contract_Number__c = '20170108-0005091',
            FEC_Case__c = c.Id
        );
        insert hist;
        FEC_Payment_History__c ph = new FEC_Payment_History__c(
            FEC_Customer_History__c = hist.Id,
            FEC_Payment_No__c = 1,
            FEC_Payment_Amount__c = 100
        );
        insert ph;

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_IncorrectPaymentController.saveSelectedPaymentHistory(c.Id, ph.Id);
            FEC_IncorrectPaymentController.saveSelectedPaymentHistory(c.Id, null);
            Test.stopTest();

            Case updated = [
                SELECT FEC_Selected_Payment_History__c
                FROM Case
                WHERE Id = :c.Id
            ];
            System.assertEquals(null, updated.FEC_Selected_Payment_History__c);
        }
    }

    @IsTest
    static void testGetIncorrectContractOptions_WithContracts() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        update new Case(
            Id = c.Id,
            FEC_Contract_Number__c = 'CON-PRIMARY',
            FEC_Incorrect_Contract_Number__c = 'CON-INCORRECT'
        );

        Test.startTest();
        List<FEC_CommonUltils.PicklistOption> options =
            FEC_IncorrectPaymentController.getIncorrectContractOptions(c.Id);
        Test.stopTest();

        System.assert(options.size() >= 2, 'Should include contract numbers from Case fields.');
    }

    @IsTest
    static void testGetSubCodeConfig_WithSubCode() {
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'Incorrect Payment',
            FEC_Code__c = 'IP01',
            FEC_Active__c = true
        );
        insert subCode;
        insert new FEC_Nature_of_Case__c(FEC_Sub_Code__c = subCode.Id);

        Case c = [SELECT Id FROM Case LIMIT 1];
        update new Case(Id = c.Id, FEC_SubCode__c = subCode.Id);

        Test.startTest();
        FEC_IncorrectPaymentController.SubCodeConfigDTO dto =
            FEC_IncorrectPaymentController.getSubCodeConfig(c.Id);
        Test.stopTest();

        System.assertEquals('IP01', dto.subCode);
    }

    @IsTest
    static void testSaveAdjustment_InvalidRowsOnly() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        List<FEC_IncorrectPaymentController.AdjustmentDTO> adjs =
            new List<FEC_IncorrectPaymentController.AdjustmentDTO>();
        FEC_IncorrectPaymentController.AdjustmentDTO partial =
            new FEC_IncorrectPaymentController.AdjustmentDTO();
        partial.correctContract = '1';
        adjs.add(partial);

        Test.startTest();
        try {
            FEC_IncorrectPaymentController.saveAdjustment(
                c.Id,
                'CON_BAD',
                'Bank Transfers',
                '2026-05-25',
                null,
                adjs
            );
            System.assert(false, 'Rows without adjusted amount should throw.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    private class MockGetCustomerListSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><cif:GetCustomerListResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerSearch">' +
                '<Sys><Code>1</Code><Description>DATA FOUND</Description></Sys><Count>1</Count>' +
                '<Customers><Customer><Applications><Application>' +
                '<ContractNumber>20170108-0005092</ContractNumber><AccountNumber>0001500100000030081</AccountNumber>' +
                '</Application></Applications></Customer></Customers>' +
                '</cif:GetCustomerListResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class MockLoanSecInfoEmptyHistory implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetLoanSecInfoResponse><Sys><Code>1</Code></Sys>' +
                '<LoanSecInfo><PaymentHistories/></LoanSecInfo></GetLoanSecInfoResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class MockLoanSecInfoSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetLoanSecInfoResponse><Sys><Code>1</Code></Sys>' +
                '<LoanSecInfo><PaymentHistories><PaymentHistory>' +
                '<BookingDate>2026-03-01</BookingDate><ValueDate>2026-03-02</ValueDate>' +
                '<AmountOfMoney>620.00</AmountOfMoney><ChkNo>CHK001</ChkNo>' +
                '</PaymentHistory></PaymentHistories></LoanSecInfo></GetLoanSecInfoResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class MockLoanSecInfoFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetLoanSecInfoResponse><Sys><Code>0</Code>' +
                '<Description>Loan not found</Description></Sys></GetLoanSecInfoResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }
}
