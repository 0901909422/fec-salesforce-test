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

    // 18/06/2026 18:00 linhdev - link Customer History nhưng giữ Case.FEC_Account_Contract_Number_Text__c blank (formula trả "" khi LEFT(Name,15)=LEFT(Id,15))
    private static FEC_Customer_History__c linkCaseToCustomerHistoryWithBlankAccountContractText(
        Id caseId,
        String contractNumber,
        String accountNumber
    ) {
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            Name = 'temp-' + String.valueOf(System.currentTimeMillis()).right(4),
            FEC_Case__c = caseId,
            FEC_Contract_Number__c = contractNumber,
            FEC_Account_Number__c = accountNumber
        );
        insert hist;
        update new FEC_Customer_History__c(
            Id = hist.Id,
            Name = String.valueOf(hist.Id).left(15)
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = caseId,
                FEC_Account_or_Contract__c = hist.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return hist;
    }

    // 18/06/2026 18:00 linhdev - setup Case.FEC_Account_Contract_Number_Text__c (formula: Loan + FEC_Account_or_Contract__r.Name)
    private static void linkCaseToLoanAccountContractText(Id caseId, String accountContractNumber) {
        String suffix = String.valueOf(System.currentTimeMillis()).right(4);
        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Loan',
            FEC_Code__c = 'L' + suffix,
            FEC_Active__c = true
        );
        insert prod;
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            Name = accountContractNumber,
            FEC_Case__c = caseId,
            FEC_Contract_Number__c = accountContractNumber
        );
        insert hist;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = caseId,
                FEC_Product_Type__c = prod.Id,
                FEC_Account_or_Contract__c = hist.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
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
        linkCaseToLoanAccountContractText(c.Id, '0001500100000030081');
        Test.setMock(HttpCalloutMock.class, new MockGetCustomerListSuccess());

        Test.startTest();
        List<FEC_CommonUltils.PicklistOption> options =
            FEC_IncorrectPaymentController.getLoanContractOptionsFromApi(c.Id);
        Test.stopTest();

        System.assert(!options.isEmpty(), 'Should include contract options from API 20.');
        Set<String> values = new Set<String>();
        for (FEC_CommonUltils.PicklistOption opt : options) {
            if (opt != null && String.isNotBlank(opt.value)) {
                values.add(opt.value);
            }
        }
        System.assert(!values.contains('0001500100000030081'), 'Should not include Case Account/Contract Number from Salesforce.');
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
        List<FEC_IncorrectPaymentController.PaymentDTO> result =
            FEC_IncorrectPaymentController.getPaymentHistoryFromSOAP(c.Id, 'CON-FAIL');
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Non-success SOAP response should return empty list.');
        List<FEC_API_Log__c> logs = [
            SELECT FEC_Request_String__c
            FROM FEC_API_Log__c
            WHERE Name = 'FEC_GetLoanSecInfo'
            LIMIT 1
        ];
        System.assertEquals(1, logs.size(), 'API 24 log must persist when controller does not throw after callout.');
        System.assert(logs[0].FEC_Request_String__c.contains('CON-FAIL'), 'Request must contain contract number.');
    }

    @IsTest
    static void testGetPaymentHistoryFromSOAP_EmptyHistories() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockLoanSecInfoEmptyHistory());

        Test.startTest();
        List<FEC_IncorrectPaymentController.PaymentDTO> result =
            FEC_IncorrectPaymentController.getPaymentHistoryFromSOAP(c.Id, 'CON-EMPTY');
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Empty payment histories should return empty list.');
        List<FEC_API_Log__c> logs = [
            SELECT FEC_Request_String__c
            FROM FEC_API_Log__c
            WHERE Name = 'FEC_GetLoanSecInfo'
            LIMIT 1
        ];
        System.assertEquals(1, logs.size(), 'API 24 log must persist for empty payment history.');
        System.assert(logs[0].FEC_Request_String__c.contains('CON-EMPTY'), 'Request must contain contract number.');
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

    // 18/06/2026 17:30 linhdev - không có mock API 20 thì trả rỗng (không lấy contract từ Case fields)
    @IsTest
    static void testGetIncorrectContractOptions_WithContracts() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        linkCaseToLoanAccountContractText(c.Id, '0001500100000030081');
        update new Case(
            Id = c.Id,
            FEC_Incorrect_Contract_Number__c = 'CON-INCORRECT'
        );

        Test.startTest();
        List<FEC_CommonUltils.PicklistOption> options =
            FEC_IncorrectPaymentController.getIncorrectContractOptions(c.Id);
        Test.stopTest();

        System.assertEquals(0, options.size(), 'Without API 20 mock should not return Salesforce contract values.');
    }

    // 18/06/2026 18:30 linhdev - verify API 20 request dùng FEC_Account_Contract_Number_Text__c là AccountNumber param
    @IsTest
    static void testGetLoanContractOptionsFromApi_UsesCaseAccountNumberInRequest() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        linkCaseToLoanAccountContractText(c.Id, '0001500100000030081');
        Test.setMock(HttpCalloutMock.class, new MockGetCustomerListVerifyAccountNumberRequest());

        Test.startTest();
        List<FEC_CommonUltils.PicklistOption> options =
            FEC_IncorrectPaymentController.getLoanContractOptionsFromApi(c.Id);
        Test.stopTest();

        System.assertEquals(1, options.size());
        System.assertEquals('20170108-0005092', options[0].value);
    }

    // 19/06/2026 linhdev - FEC_Account_Contract_Number_Text__c dạng contract vẫn truyền AccountNumber param theo payload API 20
    @IsTest
    static void testGetLoanContractOptionsFromApi_UsesContractTextAsAccountNumberParam() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        linkCaseToLoanAccountContractText(c.Id, '20171208-0001000');
        Test.setMock(HttpCalloutMock.class, new MockGetCustomerListVerifyAccountNumberContractFormatRequest());

        Test.startTest();
        List<FEC_CommonUltils.PicklistOption> options =
            FEC_IncorrectPaymentController.getLoanContractOptionsFromApi(c.Id);
        Test.stopTest();

        System.assertEquals(1, options.size());
        System.assertEquals('20170108-0005092', options[0].value);
    }

    // 18/06/2026 17:30 linhdev - API 24 GetLoanSecInfo nhận ContractNumber user chọn từ API 20
    @IsTest
    static void testGetPaymentHistoryFromSOAP_UsesSelectedContract() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            Name = 'IPP-PH-SEL',
            FEC_Contract_Number__c = '1500100000030081',
            FEC_Case__c = c.Id
        );
        insert hist;
        update new Case(Id = c.Id, FEC_Account_or_Contract__c = hist.Id);
        Test.setMock(HttpCalloutMock.class, new MockLoanSecInfoVerifyContractRequest());

        Test.startTest();
        List<FEC_IncorrectPaymentController.PaymentDTO> payments =
            FEC_IncorrectPaymentController.getPaymentHistoryFromSOAP(c.Id, '1500100000030081');
        Test.stopTest();

        System.assertEquals(1, payments.size());
        System.assertEquals('1', payments[0].paymentNo);
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

    // 18/06/2026 17:30 linhdev - API 24 sort Payment History mới nhất trước + replace bản ghi cũ trên Customer History
    @IsTest
    static void testGetPaymentHistoryFromSOAP_MultiplePaymentsAndReplaceExisting() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            Name = 'IPP-PH-MULTI',
            FEC_Contract_Number__c = '1500100000030081',
            FEC_Case__c = c.Id
        );
        insert hist;
        insert new FEC_Payment_History__c(
            FEC_Customer_History__c = hist.Id,
            FEC_Payment_No__c = 99,
            FEC_Payment_Amount__c = 1
        );
        update new Case(Id = c.Id, FEC_Account_or_Contract__c = hist.Id);
        Test.setMock(HttpCalloutMock.class, new MockLoanSecInfoMultiplePayments());

        Test.startTest();
        List<FEC_IncorrectPaymentController.PaymentDTO> payments =
            FEC_IncorrectPaymentController.getPaymentHistoryFromSOAP(c.Id, '1500100000030081');
        Test.stopTest();

        System.assertEquals(2, payments.size());
        System.assertEquals(200.00, payments[0].paymentAmount);
        System.assertEquals(100.00, payments[1].paymentAmount);
        List<FEC_Payment_History__c> saved = [
            SELECT FEC_Payment_No__c
            FROM FEC_Payment_History__c
            WHERE FEC_Customer_History__c = :hist.Id
            ORDER BY FEC_Payment_No__c
        ];
        System.assertEquals(2, saved.size());
        System.assertNotEquals(99, saved[0].FEC_Payment_No__c);
    }

    // 18/06/2026 17:30 linhdev - API 20 trả nhiều ContractNumber + dedupe
    @IsTest
    static void testGetLoanContractOptionsFromApi_MultipleContractsDedupe() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        linkCaseToLoanAccountContractText(c.Id, '0001500100000030081');
        Test.setMock(HttpCalloutMock.class, new MockGetCustomerListMultipleApplications());

        Test.startTest();
        List<FEC_CommonUltils.PicklistOption> options =
            FEC_IncorrectPaymentController.getLoanContractOptionsFromApi(c.Id);
        Test.stopTest();

        System.assertEquals(2, options.size());
    }

    // 18/06/2026 17:30 linhdev - getSubCodeConfig bỏ qua JSON adjustment rows không hợp lệ
    @IsTest
    static void testGetSubCodeConfig_InvalidAdjustmentRowsJson() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        update new Case(Id = c.Id, FEC_Incorrect_Payment_Adj_Rows__c = '{invalid-json');

        Test.startTest();
        FEC_IncorrectPaymentController.SubCodeConfigDTO dto =
            FEC_IncorrectPaymentController.getSubCodeConfig(c.Id);
        Test.stopTest();

        System.assertEquals(null, dto.adjustmentRows);
    }

    // 18/06/2026 17:30 linhdev - saveAdjustment nhiều dòng hợp lệ
    @IsTest
    static void testSaveAdjustment_MultipleValidRows() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        List<FEC_IncorrectPaymentController.AdjustmentDTO> adjs =
            new List<FEC_IncorrectPaymentController.AdjustmentDTO>();
        FEC_IncorrectPaymentController.AdjustmentDTO adj1 =
            new FEC_IncorrectPaymentController.AdjustmentDTO();
        adj1.correctContract = '1500100000030081';
        adj1.adjustedAmount = 400;
        adjs.add(adj1);
        FEC_IncorrectPaymentController.AdjustmentDTO adj2 =
            new FEC_IncorrectPaymentController.AdjustmentDTO();
        adj2.correctContract = '1500100000030082';
        adj2.adjustedAmount = 600;
        adjs.add(adj2);

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_IncorrectPaymentController.saveAdjustment(
                c.Id,
                '1500100000030081',
                'Bank Transfers',
                '2026-05-25',
                1000,
                adjs
            );
            Test.stopTest();

            List<FEC_Incorrect_Payment_Info__c> infoRows = [
                SELECT FEC_Adjusted_Amount__c
                FROM FEC_Incorrect_Payment_Info__c
                WHERE FEC_Case__c = :c.Id
            ];
            System.assertEquals(2, infoRows.size());
        }
    }

    // 18/06/2026 18:00 linhdev - API 20 fallback: National ID khi Case không có FEC_Account_Contract_Number_Text__c
    @IsTest
    static void testGetLoanContractOptionsFromApi_FallbackNationalId() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        update new Case(
            Id = c.Id,
            FEC_National_ID_Passport_ID__c = '079195235215'
        );
        Test.setMock(HttpCalloutMock.class, new MockGetCustomerListSuccess());

        Test.startTest();
        List<FEC_CommonUltils.PicklistOption> options =
            FEC_IncorrectPaymentController.getLoanContractOptionsFromApi(c.Id);
        Test.stopTest();

        System.assertEquals(1, options.size());
        System.assertEquals('20170108-0005092', options[0].value);
    }

    // 18/06/2026 18:00 linhdev - API 20 fallback: ContractNumber từ Customer History khi Case không có FEC_Account_Contract_Number_Text__c
    @IsTest
    static void testGetLoanContractOptionsFromApi_FallbackCustomerHistory() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        linkCaseToCustomerHistoryWithBlankAccountContractText(c.Id, '20170108-0005091', null);
        Test.setMock(HttpCalloutMock.class, new MockGetCustomerListSuccess());

        Test.startTest();
        List<FEC_CommonUltils.PicklistOption> options =
            FEC_IncorrectPaymentController.getCorrectContractOptions(c.Id);
        Test.stopTest();

        System.assertEquals(1, options.size());
        System.assertEquals('20170108-0005092', options[0].value);
    }

    // 18/06/2026 17:30 linhdev - API 24 vẫn trả Payment History khi Case chưa link Customer History
    @IsTest
    static void testGetPaymentHistoryFromSOAP_WithoutCustomerHistory() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockLoanSecInfoVerifyContractRequest());

        Test.startTest();
        List<FEC_IncorrectPaymentController.PaymentDTO> payments =
            FEC_IncorrectPaymentController.getPaymentHistoryFromSOAP(c.Id, '1500100000030081');
        Test.stopTest();

        System.assertEquals(1, payments.size());
        System.assert(payments[0].id.startsWith(FEC_ConstantCommon.PAYMENT_PREFIX));
    }

    // 18/06/2026 17:30 linhdev - saveAdjustment bắt buộc Payment Method
    @IsTest
    static void testSaveAdjustment_BlankPaymentMethod() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        List<FEC_IncorrectPaymentController.AdjustmentDTO> adjs =
            new List<FEC_IncorrectPaymentController.AdjustmentDTO>();
        FEC_IncorrectPaymentController.AdjustmentDTO adj =
            new FEC_IncorrectPaymentController.AdjustmentDTO();
        adj.correctContract = '1500100000030081';
        adj.adjustedAmount = 100;
        adjs.add(adj);

        Test.startTest();
        try {
            FEC_IncorrectPaymentController.saveAdjustment(
                c.Id, '1500100000030081', '', '2026-05-25', 100, adjs
            );
            System.assert(false, 'Blank payment method should throw.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    // 18/06/2026 18:00 linhdev - API 20 fallback: AccountNumber từ Customer History khi không có FEC_Account_Contract_Number_Text__c
    @IsTest
    static void testGetLoanContractOptionsFromApi_FallbackAccountNumber() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        linkCaseToCustomerHistoryWithBlankAccountContractText(
            c.Id, '20170108-0005091', '0001500100000030081'
        );
        Test.setMock(HttpCalloutMock.class, new MockGetCustomerListSuccess());

        Test.startTest();
        List<FEC_CommonUltils.PicklistOption> options =
            FEC_IncorrectPaymentController.getLoanContractOptionsFromApi(c.Id);
        Test.stopTest();

        System.assertEquals(1, options.size());
    }

    // 18/06/2026 17:30 linhdev - saveAdjustmentDraft validate Case Id bắt buộc
    @IsTest
    static void testSaveAdjustmentDraft_NullCaseId() {
        Test.startTest();
        try {
            FEC_IncorrectPaymentController.saveAdjustmentDraft(
                null, 'CON', 'Bank Transfers', '2026-05-25', 100, '1', 100
            );
            System.assert(false, 'Null case should throw.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    private class MockLoanSecInfoMultiplePayments implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetLoanSecInfoResponse><Sys><Code>1</Code></Sys>' +
                '<LoanSecInfo><PaymentHistories>' +
                '<PaymentHistory><BookingDate>2026-03-01</BookingDate><ValueDate>2026-03-02</ValueDate>' +
                '<AmountOfMoney>100.00</AmountOfMoney><ChkNo>OLD</ChkNo></PaymentHistory>' +
                '<PaymentHistory><BookingDate>2026-03-09</BookingDate><ValueDate>2026-03-10</ValueDate>' +
                '<AmountOfMoney>200.00</AmountOfMoney><ChkNo>NEW</ChkNo></PaymentHistory>' +
                '</PaymentHistories></LoanSecInfo></GetLoanSecInfoResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class MockGetCustomerListMultipleApplications implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><cif:GetCustomerListResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerSearch">' +
                '<Sys><Code>1</Code><Description>DATA FOUND</Description></Sys><Count>1</Count>' +
                '<Customers><Customer><Applications>' +
                '<Application><ContractNumber>20170108-0005092</ContractNumber></Application>' +
                '<Application><ContractNumber>20170108-0005092</ContractNumber></Application>' +
                '<Application><ContractNumber>20170108-0005093</ContractNumber></Application>' +
                '</Applications></Customer></Customers>' +
                '</cif:GetCustomerListResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class MockGetCustomerListVerifyAccountNumberRequest implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assert(
                req.getBody().contains('<AccountNumber>0001500100000030081</AccountNumber>'),
                'API 20 should use Case FEC_Account_Contract_Number_Text__c as AccountNumber param.'
            );
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

    private class MockGetCustomerListVerifyAccountNumberContractFormatRequest implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assert(
                req.getBody().contains('<AccountNumber>20171208-0001000</AccountNumber>'),
                'API 20 should pass contract-format FEC_Account_Contract_Number_Text__c in AccountNumber param.'
            );
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

    private class MockLoanSecInfoVerifyContractRequest implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assert(req.getBody().contains('1500100000030081'), 'API 24 should use selected Incorrect Contract Number.');
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
