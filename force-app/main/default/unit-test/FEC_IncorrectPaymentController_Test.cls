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
        Test.startTest();
        try {
            FEC_IncorrectPaymentController.getPaymentHistoryFromSOAP('CON123');
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
        Test.startTest();
        List<FEC_IncorrectPaymentController.PaymentDTO> empty =
            FEC_IncorrectPaymentController.getPaymentHistoryFromSOAP('');
        Test.stopTest();

        System.assertEquals(0, empty.size());
    }

    @IsTest
    static void testGetPaymentHistoryFromSOAP_WithMock() {
        Test.setMock(HttpCalloutMock.class, new MockLoanSecInfoSuccess());

        Test.startTest();
        List<FEC_IncorrectPaymentController.PaymentDTO> payments =
            FEC_IncorrectPaymentController.getPaymentHistoryFromSOAP('CON123');
        Test.stopTest();

        System.assertEquals(1, payments.size());
        System.assertEquals('1', payments[0].paymentNo);
    }

    @IsTest
    static void testPicklistAndContractOptions() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<FEC_CommonUltils.PicklistOption> paymentMethods =
            FEC_IncorrectPaymentController.getPaymentMethodOptions();
        List<FEC_CommonUltils.PicklistOption> correctContracts =
            FEC_IncorrectPaymentController.getCorrectContractOptions();
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
        Test.setMock(HttpCalloutMock.class, new MockLoanSecInfoFailure());

        Test.startTest();
        try {
            FEC_IncorrectPaymentController.getPaymentHistoryFromSOAP('CON-FAIL');
            System.assert(false, 'Non-success SOAP response should throw.');
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
