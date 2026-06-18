@IsTest
private class FEC_IPPConversionController_Test {

    /** Valid 16-digit account format (FEC_ConstantCommon.PATTERN_ACCOUNT_NUMBER). */
    private static final String ACCOUNT_NUMBER = '0001500060000003';
    private static final String CARD_NUMBER = '5432123456789012';

    private static User runAsAdmin() {
        return [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator'
            AND IsActive = true
            LIMIT 1
        ];
    }

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        Case c = new Case(
            Subject = 'FEC_IPPConversionController_Test',
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            Status = 'New',
            FEC_ID_Search__c = 'IPPCV-' + suffix
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c cust = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            Name = ACCOUNT_NUMBER,
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_Card_Number__c = CARD_NUMBER
        );
        insert cust;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Account_or_Contract__c = cust.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_Transaction__c(
            FEC_Customer_History__c = cust.Id,
            FEC_Transaction_Amount__c = 1000,
            FEC_Transaction_Plan__c = 'PLAN01',
            FEC_Effective_Date__c = Date.today(),
            FEC_Post_Date__c = Date.today(),
            FEC_Transaction_Code__c = '0105',
            FEC_Reference_Number__c = 'REF-IPP-001',
            FEC_Card_Seq__c = '0',
            FEC_IPP_Key__c = 'KEY-IPP-001',
            FEC_IPPEligibilityFlag__c = 'R',
            FEC_Type__c = 'Unbilled'
        );

        insert new FEC_API_Setting__c(
            FEC_Call_Mock__c = true,
            FEC_Endpoint__c = 'https://test-api.fecredit.com.vn'
        );
    }

    @IsTest
    static void testGetEligibleTransactions() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            System.assert(true, 'Skipped: FEC_IPPConversionController not on org.');
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];

        System.runAs(runAsAdmin()) {
            FEC_IPPConversionController.unbilledApiTestMode = 1;
            FEC_IPPConversionController.unbilledApiTestResponse = new FEC_GetUnbilledTransactions.ResponseWrapper();
            FEC_IPPConversionController.unbilledApiTestResponse.Transactions = new List<FEC_GetUnbilledTransactions.TransactionRecord>();
            Test.startTest();
            List<FEC_IPPConversionController.EligibleTransactionDTO> txs =
                FEC_IPPConversionController.getEligibleTransactions(c.Id);
            Test.stopTest();
            System.assertNotEquals(0, txs.size(), 'Should load transactions from DB fallback.');
        }
    }

    @IsTest
    static void testConvertIPP_Success() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            System.assert(true, 'Skipped: FEC_IPPConversionController not on org.');
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];

        System.runAs(runAsAdmin()) {
            Test.startTest();
            FEC_IPPConversionController.ConvertResultDTO result =
                FEC_IPPConversionController.convertIPP(c.Id, tx.Id, 6);
            Test.stopTest();
            System.assertNotEquals(null, result);
        }
    }

    @IsTest
    static void testGetEligibleTransactions_LiveApi() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }

        FEC_API_Setting__c setting = FEC_API_Setting__c.getOrgDefaults();
        setting.FEC_Call_Mock__c = false;
        upsert setting;

        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new IppConversionApiMock());

        System.runAs(runAsAdmin()) {
            Test.startTest();
            List<FEC_IPPConversionController.EligibleTransactionDTO> txs =
                FEC_IPPConversionController.getEligibleTransactions(c.Id);
            Test.stopTest();
            System.assertNotEquals(null, txs);
        }
    }

    @IsTest
    static void testLoadIppTenorOptions_Success() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new IppConversionAccountDetailsMock());

        System.runAs(runAsAdmin()) {
            Test.startTest();
            FEC_IPPConversionController.AccountTenorDTO dto =
                FEC_IPPConversionController.loadIppTenorOptions(c.Id);
            Test.stopTest();

            System.assertEquals(null, dto.errorMessage);
            System.assertNotEquals(null, dto.tenorOptions);
            System.assertEquals(3, dto.tenorOptions.size());
            System.assertEquals(6, dto.tenorOptions[0]);
            System.assertEquals(12, dto.tenorOptions[2]);
            System.assertEquals('90003', dto.planNumber);
            System.assertEquals(null, dto.savedTenor);
            System.assertEquals(null, dto.savedInterestRate);
            System.assertEquals(null, dto.savedFee);
            System.assertEquals(null, dto.savedEmi);
        }
    }

    @IsTest
    static void testCheckIPPDetails_WithTenor() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        Map<String, Schema.SObjectField> caseFieldMap = Schema.SObjectType.Case.fields.getMap();
        if (caseFieldMap.containsKey('FEC_IPP_Term__c')) {
            FEC_CaseTriggerHandler.isExecuting = true;
            try {
                FEC_IPPConversionController.saveCaseIppTerm(c.Id, 9);
            } finally {
                FEC_CaseTriggerHandler.isExecuting = false;
            }
        }
        Test.setMock(HttpCalloutMock.class, new IppConversionIppDetailsMock());

        System.runAs(runAsAdmin()) {
            Test.startTest();
            FEC_IPPConversionController.IPPDetailsDTO dto =
                FEC_IPPConversionController.checkIPPDetails(c.Id, tx.Id, 9);
            Test.stopTest();

            System.assertEquals(null, dto.errorMessage);
            System.assertEquals(12, dto.interestRate);
            System.assertEquals(60000, dto.fee);
            System.assertEquals(709465, dto.emi);
            // 2026-06-16 linhdev – FEC_IPP_Term__c lưu khi user chọn Tenor (trước GetIPPDetails)
            if (caseFieldMap.containsKey('FEC_IPP_Term__c')) {
                Case updatedCase = [
                    SELECT FEC_IPP_Term__c
                    FROM Case
                    WHERE Id = :c.Id
                    LIMIT 1
                ];
                System.assertEquals(9, updatedCase.FEC_IPP_Term__c);
            }
        }
    }

    @IsTest
    static void testCheckIPPDetails_MapsAllGetIppDetailsFields() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [
            SELECT Id, FEC_Transaction_Amount__c, FEC_Effective_Date__c, FEC_Post_Date__c,
                FEC_Transaction_Plan__c, FEC_Reference_Number__c, FEC_Card_Seq__c, FEC_IPP_Key__c
            FROM FEC_Transaction__c
            LIMIT 1
        ];
        tx.FEC_Card_Seq__c = '2';
        tx.FEC_IPP_Key__c = 'KEY-IPP-001';
        tx.FEC_Reference_Number__c = 'REF-IPP-001';
        update tx;

        System.runAs(runAsAdmin()) {
            Case loadedCase = [
                SELECT Id, FEC_Account_or_Contract__c,
                    FEC_Account_or_Contract__r.Name,
                    FEC_Account_or_Contract__r.FEC_Account_Number__c,
                    FEC_Account_or_Contract__r.FEC_Card_Number__c
                FROM Case
                WHERE Id = :c.Id
                LIMIT 1
            ];
            FEC_Transaction__c loadedTx = [
                SELECT Id, FEC_Transaction_Amount__c, FEC_Effective_Date__c, FEC_Post_Date__c,
                    FEC_Transaction_Plan__c, FEC_Reference_Number__c, FEC_Card_Seq__c, FEC_IPP_Key__c
                FROM FEC_Transaction__c
                WHERE Id = :tx.Id
                LIMIT 1
            ];
            String accountNumber = FEC_IPPConversionController.getAccountNumberForGetIPPDetails(c.Id, ACCOUNT_NUMBER);
            FEC_GetIPPDetailsCallout.IPPRequest req =
                FEC_IPPConversionController.buildGetIppDetailsRequest(loadedCase, loadedTx, 9, accountNumber);

            System.assertEquals(ACCOUNT_NUMBER, req.accountNumber);
            System.assertEquals(
                FEC_CommonUltils.formatDateYYYYMMDD(loadedTx.FEC_Effective_Date__c),
                req.effectiveDate
            );
            System.assertEquals(loadedTx.FEC_Transaction_Amount__c, req.amount);
            System.assertEquals(loadedTx.FEC_Transaction_Plan__c, req.planNumber);
            System.assertEquals(loadedTx.FEC_Transaction_Plan__c, req.transactionPlan);
            System.assertEquals(9, req.ippTerm);
            System.assertEquals('REF-IPP-001', req.referenceNumber);
            Date expectedPostDate = loadedTx.FEC_Post_Date__c != null
                ? loadedTx.FEC_Post_Date__c
                : (loadedTx.FEC_Effective_Date__c != null ? loadedTx.FEC_Effective_Date__c : Date.today());
            System.assertEquals(
                FEC_CommonUltils.formatDateYYYYMMDD(expectedPostDate),
                req.postingDate
            );
            System.assertEquals(CARD_NUMBER, req.cardNumber);
            System.assertEquals(2, req.cardSeq);
            System.assertEquals('KEY-IPP-001', req.ippKey);

            Test.setMock(HttpCalloutMock.class, new IppConversionIppDetailsMock());
            Test.startTest();
            FEC_IPPConversionController.IPPDetailsDTO dto =
                FEC_IPPConversionController.checkIPPDetails(c.Id, tx.Id, 9);
            Test.stopTest();
            System.assertEquals(null, dto.errorMessage);
        }
    }

    @IsTest
    static void testLoadIppTenorOptions_WithSavedCaseFields() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        Map<String, Schema.SObjectField> caseFieldMap = Schema.SObjectType.Case.fields.getMap();
        if (!caseFieldMap.containsKey('FEC_IPP_Term__c')) {
            return;
        }

        Case caseUpdate = new Case(Id = c.Id, FEC_IPP_Term__c = 12);
        if (caseFieldMap.containsKey('FEC_IPP_Interest__c')) {
            caseUpdate.FEC_IPP_Interest__c = 10;
        }
        if (caseFieldMap.containsKey('FEC_Conversion_Fee__c')) {
            caseUpdate.FEC_Conversion_Fee__c = 50000;
        }
        if (caseFieldMap.containsKey('FEC_EMI__c')) {
            caseUpdate.FEC_EMI__c = 100000;
        }

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update caseUpdate;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.setMock(HttpCalloutMock.class, new IppConversionAccountDetailsMock());

        System.runAs(runAsAdmin()) {
            Test.startTest();
            FEC_IPPConversionController.AccountTenorDTO dto =
                FEC_IPPConversionController.loadIppTenorOptions(c.Id);
            Test.stopTest();

            System.assertEquals(null, dto.errorMessage);
            System.assertEquals(12, dto.savedTenor);
            if (caseFieldMap.containsKey('FEC_IPP_Interest__c')) {
                System.assertEquals(10, dto.savedInterestRate);
            }
            if (caseFieldMap.containsKey('FEC_Conversion_Fee__c')) {
                System.assertEquals(50000, dto.savedFee);
            }
            if (caseFieldMap.containsKey('FEC_EMI__c')) {
                System.assertEquals(100000, dto.savedEmi);
            }
        }
    }

    @IsTest
    static void testSaveCaseIppTerm() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        Map<String, Schema.SObjectField> caseFieldMap = Schema.SObjectType.Case.fields.getMap();
        if (!caseFieldMap.containsKey('FEC_IPP_Term__c')) {
            return;
        }

        System.runAs(runAsAdmin()) {
            Test.startTest();
            FEC_IPPConversionController.saveCaseIppTerm(c.Id, 6);
            Test.stopTest();

            Case updatedCase = [SELECT FEC_IPP_Term__c FROM Case WHERE Id = :c.Id LIMIT 1];
            System.assertEquals(6, updatedCase.FEC_IPP_Term__c);
        }
    }

    @IsTest
    static void testCheckIPPDetails_FailureClearsDetailFields() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        Map<String, Schema.SObjectField> caseFieldMap = Schema.SObjectType.Case.fields.getMap();
        if (!caseFieldMap.containsKey('FEC_IPP_Term__c')) {
            return;
        }

        Case caseUpdate = new Case(Id = c.Id, FEC_IPP_Term__c = 9);
        if (caseFieldMap.containsKey('FEC_IPP_Interest__c')) {
            caseUpdate.FEC_IPP_Interest__c = 10;
        }
        if (caseFieldMap.containsKey('FEC_Conversion_Fee__c')) {
            caseUpdate.FEC_Conversion_Fee__c = 50000;
        }
        if (caseFieldMap.containsKey('FEC_EMI__c')) {
            caseUpdate.FEC_EMI__c = 100000;
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update caseUpdate;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.setMock(HttpCalloutMock.class, new IppConversionIppDetailsErrorMock());

        System.runAs(runAsAdmin()) {
            Test.startTest();
            FEC_IPPConversionController.IPPDetailsDTO dto =
                FEC_IPPConversionController.checkIPPDetails(c.Id, tx.Id, 9);
            Test.stopTest();

            System.assertNotEquals(null, dto.errorMessage);
            Case updatedCase = [
                SELECT FEC_IPP_Term__c, FEC_IPP_Interest__c, FEC_Conversion_Fee__c, FEC_EMI__c
                FROM Case
                WHERE Id = :c.Id
                LIMIT 1
            ];
            System.assertEquals(9, updatedCase.FEC_IPP_Term__c);
            if (caseFieldMap.containsKey('FEC_IPP_Interest__c')) {
                System.assertEquals(null, updatedCase.FEC_IPP_Interest__c);
            }
            if (caseFieldMap.containsKey('FEC_Conversion_Fee__c')) {
                System.assertEquals(null, updatedCase.FEC_Conversion_Fee__c);
            }
            if (caseFieldMap.containsKey('FEC_EMI__c')) {
                System.assertEquals(null, updatedCase.FEC_EMI__c);
            }
        }
    }

    @IsTest
    static void testCheckIPPDetails_MissingTenor() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];

        Test.startTest();
        FEC_IPPConversionController.IPPDetailsDTO dto =
            FEC_IPPConversionController.checkIPPDetails(c.Id, tx.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, dto.errorMessage);
    }

    @IsTest
    static void testLoadIppTenorOptions_BlankCaseId() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }

        Test.startTest();
        FEC_IPPConversionController.AccountTenorDTO dto =
            FEC_IPPConversionController.loadIppTenorOptions(null);
        Test.stopTest();

        System.assertNotEquals(null, dto.errorMessage);
    }

    @IsTest
    static void testGetConvertActionStatus() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            System.assert(true, 'Skipped: FEC_IPPConversionController not on org.');
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_IPPConversionController.ActionStatusDTO status =
            FEC_IPPConversionController.getConvertActionStatus(c.Id);
        Test.stopTest();

        System.assertEquals(true, status.canConvert);
    }

    @IsTest
    static void testGetEligibleTransactions_BlankCaseId() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }

        Test.startTest();
        List<FEC_IPPConversionController.EligibleTransactionDTO> txs =
            FEC_IPPConversionController.getEligibleTransactions(null);
        Test.stopTest();

        System.assertEquals(0, txs.size());
    }

    @IsTest
    static void testConvertIPP_InvalidTerm() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];

        System.runAs(runAsAdmin()) {
            Test.startTest();
            FEC_IPPConversionController.ConvertResultDTO result =
                FEC_IPPConversionController.convertIPP(c.Id, tx.Id, 0);
            Test.stopTest();
            System.assertEquals(false, result.success);
            System.assertNotEquals(null, result.errorMessage);
        }
    }

    @IsTest
    static void testGetConvertActionStatus_NoCustomerHistory() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }

        Case orphan = new Case(
            Subject = 'IPP Conv orphan',
            Status = 'New',
            FEC_ID_Search__c = 'IPPCV-ORPHAN-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert orphan;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_IPPConversionController.ActionStatusDTO status =
            FEC_IPPConversionController.getConvertActionStatus(orphan.Id);
        Test.stopTest();

        System.assertNotEquals(null, status);
    }

    @IsTest
    static void testGetConvertActionStatus_NullCaseId() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Test.startTest();
        FEC_IPPConversionController.ActionStatusDTO status =
            FEC_IPPConversionController.getConvertActionStatus(null);
        Test.stopTest();
        System.assertEquals(true, status.canConvert);
    }

    @IsTest
    static void testGetConvertActionStatus_MaxRetryExceeded() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, FEC_Process_Action_Count__c = 3);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        Test.startTest();
        FEC_IPPConversionController.ActionStatusDTO status =
            FEC_IPPConversionController.getConvertActionStatus(c.Id);
        Test.stopTest();
        System.assertEquals(false, status.canConvert);
    }

    @IsTest
    static void testGetConvertActionStatus_AlreadyConverted() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, FEC_Process_Action_Count__c = -1);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        Test.startTest();
        FEC_IPPConversionController.ActionStatusDTO status =
            FEC_IPPConversionController.getConvertActionStatus(c.Id);
        Test.stopTest();
        System.assertEquals(false, status.canConvert);
    }

    @IsTest
    static void testLoadIppTenorOptions_NoAccountLinked() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case orphan = new Case(
            Subject = 'IPP no account',
            Status = 'New',
            FEC_ID_Search__c = 'IPPCV-NOACC-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert orphan;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        Test.startTest();
        FEC_IPPConversionController.AccountTenorDTO dto =
            FEC_IPPConversionController.loadIppTenorOptions(orphan.Id);
        Test.stopTest();
        System.assertNotEquals(null, dto.errorMessage);
    }

    @IsTest
    static void testLoadIppTenorOptions_ApiNullAccount() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new IppConversionAccountDetailsEmptyMock());
        Test.startTest();
        FEC_IPPConversionController.AccountTenorDTO dto =
            FEC_IPPConversionController.loadIppTenorOptions(c.Id);
        Test.stopTest();
        System.assertNotEquals(null, dto.errorMessage);
    }

    @IsTest
    static void testLoadIppTenorOptions_RetailPlanOnly() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new IppConversionAccountDetailsRetailOnlyMock());
        Test.startTest();
        FEC_IPPConversionController.AccountTenorDTO dto =
            FEC_IPPConversionController.loadIppTenorOptions(c.Id);
        Test.stopTest();
        System.assertEquals('80001', dto.planNumber);
        System.assertNotEquals(null, dto.errorMessage);
    }

    @IsTest
    static void testCheckIPPDetails_MissingTransactionId() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        FEC_IPPConversionController.IPPDetailsDTO dto =
            FEC_IPPConversionController.checkIPPDetails(c.Id, null, 6);
        Test.stopTest();
        System.assertNotEquals(null, dto.errorMessage);
    }

    @IsTest
    static void testCheckIPPDetails_InvalidAmount() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c ch = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];
        FEC_Transaction__c badTx = new FEC_Transaction__c(
            FEC_Customer_History__c = ch.Id,
            FEC_Transaction_Amount__c = 0,
            FEC_Transaction_Plan__c = 'PLAN01',
            FEC_Effective_Date__c = Date.today()
        );
        insert badTx;
        Test.startTest();
        FEC_IPPConversionController.IPPDetailsDTO dto =
            FEC_IPPConversionController.checkIPPDetails(c.Id, badTx.Id, 6);
        Test.stopTest();
        System.assertNotEquals(null, dto.errorMessage);
    }

    @IsTest
    static void testCheckIPPDetails_InvalidAccount() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case orphan = new Case(
            Subject = 'IPP invalid acc',
            Status = 'New',
            FEC_ID_Search__c = 'IPPCV-INV-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert orphan;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        Test.startTest();
        FEC_IPPConversionController.IPPDetailsDTO dto =
            FEC_IPPConversionController.checkIPPDetails(orphan.Id, tx.Id, 6);
        Test.stopTest();
        System.assertNotEquals(null, dto.errorMessage);
    }

    @IsTest
    static void testCheckIPPDetails_NullApiResponse() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new IppConversionIppDetailsEmptyMock());
        Test.startTest();
        FEC_IPPConversionController.IPPDetailsDTO dto =
            FEC_IPPConversionController.checkIPPDetails(c.Id, tx.Id, 6);
        Test.stopTest();
        System.assertNotEquals(null, dto.errorMessage);
    }

    @IsTest
    static void testCheckIPPDetails_InstallmentAmountFallback() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new IppConversionIppDetailsInstallmentMock());
        System.runAs(runAsAdmin()) {
            Test.startTest();
            FEC_IPPConversionController.IPPDetailsDTO dto =
                FEC_IPPConversionController.checkIPPDetails(c.Id, tx.Id, 6);
            Test.stopTest();
            System.assertEquals(null, dto.errorMessage);
            System.assertEquals(500000, dto.emi);
        }
    }

    @IsTest
    static void testCheckIPPDetails_StatusCodeSuccess() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new IppConversionIppDetailsStatusCodeMock());
        System.runAs(runAsAdmin()) {
            Test.startTest();
            FEC_IPPConversionController.IPPDetailsDTO dto =
                FEC_IPPConversionController.checkIPPDetails(c.Id, tx.Id, 6);
            Test.stopTest();
            System.assertEquals(null, dto.errorMessage);
            System.assertEquals(11, dto.interestRate);
        }
    }

    @IsTest
    static void testCheckIPPDetails_CalloutException() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new IppConversionIppDetailsThrowMock());
        Test.startTest();
        FEC_IPPConversionController.IPPDetailsDTO dto =
            FEC_IPPConversionController.checkIPPDetails(c.Id, tx.Id, 6);
        Test.stopTest();
        System.assertNotEquals(null, dto.errorMessage);
    }

    @IsTest
    static void testConvertIPP_MissingCaseId() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        Test.startTest();
        FEC_IPPConversionController.ConvertResultDTO result =
            FEC_IPPConversionController.convertIPP(null, tx.Id, 6);
        Test.stopTest();
        System.assertNotEquals(null, result.errorMessage);
    }

    @IsTest
    static void testConvertIPP_MissingTransactionId() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        FEC_IPPConversionController.ConvertResultDTO result =
            FEC_IPPConversionController.convertIPP(c.Id, null, 6);
        Test.stopTest();
        System.assertNotEquals(null, result.errorMessage);
    }

    @IsTest
    static void testConvertIPP_NoAccountLinked() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case orphan = new Case(
            Subject = 'IPP conv no acc',
            Status = 'New',
            FEC_ID_Search__c = 'IPPCV-CNV-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert orphan;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        Test.startTest();
        FEC_IPPConversionController.ConvertResultDTO result =
            FEC_IPPConversionController.convertIPP(orphan.Id, tx.Id, 6);
        Test.stopTest();
        System.assertNotEquals(null, result.errorMessage);
    }

    @IsTest
    static void testConvertIPP_InvalidAmount() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c ch = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];
        FEC_Transaction__c badTx = new FEC_Transaction__c(
            FEC_Customer_History__c = ch.Id,
            FEC_Transaction_Amount__c = -1,
            FEC_Transaction_Plan__c = 'PLAN01',
            FEC_Effective_Date__c = Date.today()
        );
        insert badTx;
        Test.startTest();
        FEC_IPPConversionController.ConvertResultDTO result =
            FEC_IPPConversionController.convertIPP(c.Id, badTx.Id, 6);
        Test.stopTest();
        System.assertNotEquals(null, result.errorMessage);
    }

    @IsTest
    static void testConvertIPP_MissingPlan() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c ch = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];
        FEC_Transaction__c noPlanTx = new FEC_Transaction__c(
            FEC_Customer_History__c = ch.Id,
            FEC_Transaction_Amount__c = 500,
            FEC_Effective_Date__c = Date.today()
        );
        insert noPlanTx;
        Test.startTest();
        FEC_IPPConversionController.ConvertResultDTO result =
            FEC_IPPConversionController.convertIPP(c.Id, noPlanTx.Id, 6);
        Test.stopTest();
        System.assertNotEquals(null, result.errorMessage);
    }

    @IsTest
    static void testConvertIPP_MissingCardNumber() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        FEC_Customer_History__c ch = [
            SELECT Id FROM FEC_Customer_History__c WHERE Id = :c.FEC_Account_or_Contract__c LIMIT 1
        ];
        update new FEC_Customer_History__c(Id = ch.Id, FEC_Card_Number__c = null);
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        Test.startTest();
        FEC_IPPConversionController.ConvertResultDTO result =
            FEC_IPPConversionController.convertIPP(c.Id, tx.Id, 6);
        Test.stopTest();
        System.assertNotEquals(null, result.errorMessage);
    }

    @IsTest
    static void testConvertIPP_SuccessWithMock() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new IppConversionAddIppSuccessMock());
        System.runAs(runAsAdmin()) {
            Test.startTest();
            FEC_IPPConversionController.ConvertResultDTO result =
                FEC_IPPConversionController.convertIPP(c.Id, tx.Id, 6);
            Test.stopTest();
            System.assertEquals(true, result.success);
            System.assertNotEquals(null, result.message);
        }
    }

    @IsTest
    static void testConvertIPP_FailureIncrementsRetry() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new IppConversionAddIppFailureMock());
        System.runAs(runAsAdmin()) {
            Test.startTest();
            FEC_IPPConversionController.ConvertResultDTO result =
                FEC_IPPConversionController.convertIPP(c.Id, tx.Id, 6);
            Test.stopTest();
            System.assertEquals(false, result.success);
            System.assertNotEquals(null, result.errorMessage);
        }
    }

    @IsTest
    static void testConvertIPP_MapsAllAddIppFields() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [
            SELECT Id, FEC_Transaction_Amount__c, FEC_Effective_Date__c, FEC_Post_Date__c,
                FEC_Transaction_Plan__c, FEC_Reference_Number__c, FEC_Card_Seq__c, FEC_IPP_Key__c
            FROM FEC_Transaction__c
            LIMIT 1
        ];
        tx.FEC_Card_Seq__c = '2';
        tx.FEC_IPP_Key__c = 'KEY-IPP-002';
        tx.FEC_Reference_Number__c = 'REF-IPP-002';
        update tx;

        System.runAs(runAsAdmin()) {
            Case loadedCase = [
                SELECT Id, FEC_Account_or_Contract__c,
                    FEC_Account_or_Contract__r.Name,
                    FEC_Account_or_Contract__r.FEC_Account_Number__c,
                    FEC_Account_or_Contract__r.FEC_Card_Number__c
                FROM Case
                WHERE Id = :c.Id
                LIMIT 1
            ];
            FEC_Transaction__c loadedTx = [
                SELECT Id, FEC_Transaction_Amount__c, FEC_Effective_Date__c, FEC_Post_Date__c,
                    FEC_Transaction_Plan__c, FEC_Reference_Number__c, FEC_Card_Seq__c, FEC_IPP_Key__c
                FROM FEC_Transaction__c
                WHERE Id = :tx.Id
                LIMIT 1
            ];
            String accountNumber = FEC_IPPConversionController.getAccountNumberForGetIPPDetails(c.Id, ACCOUNT_NUMBER);
            FEC_AddIPP.IPPRequest req =
                FEC_IPPConversionController.buildAddIppRequest(loadedCase, loadedTx, accountNumber, 9);

            System.assertEquals(ACCOUNT_NUMBER, req.accountNumber);
            Date expectedEffDate = loadedTx.FEC_Effective_Date__c != null
                ? loadedTx.FEC_Effective_Date__c
                : Date.today();
            System.assertEquals(expectedEffDate, req.effectiveDate);
            System.assertEquals(loadedTx.FEC_Transaction_Amount__c, req.amount);
            System.assertEquals(loadedTx.FEC_Transaction_Plan__c, req.planNumber);
            System.assertEquals(loadedTx.FEC_Transaction_Plan__c, req.transactionPlan);
            System.assertEquals(9, req.ippTerm);
            System.assertEquals('REF-IPP-002', req.referenceNumber);
            Date expectedPostDate = loadedTx.FEC_Post_Date__c != null
                ? loadedTx.FEC_Post_Date__c
                : expectedEffDate;
            System.assertEquals(expectedPostDate, req.postingDate);
            System.assertEquals(CARD_NUMBER, req.cardNumber);
            System.assertEquals(2, req.cardSeq);
            System.assertEquals('KEY-IPP-002', req.ippKey);
        }
    }

    @IsTest
    static void testConvertIPP_AuthCodeAsReference() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c ch = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];
        FEC_Transaction__c tx = new FEC_Transaction__c(
            FEC_Customer_History__c = ch.Id,
            FEC_Transaction_Amount__c = 800,
            FEC_Transaction_Plan__c = 'PLAN02',
            FEC_Effective_Date__c = Date.today(),
            FEC_Authorization_Code__c = 'AUTH99',
            FEC_Reference_Number__c = 'REF-AUTH99',
            FEC_Card_Seq__c = '1',
            FEC_IPP_Key__c = 'KEY-AUTH99'
        );
        insert tx;
        Test.setMock(HttpCalloutMock.class, new IppConversionAddIppSuccessMock());
        System.runAs(runAsAdmin()) {
            Test.startTest();
            FEC_IPPConversionController.ConvertResultDTO result =
                FEC_IPPConversionController.convertIPP(c.Id, tx.Id, 6);
            Test.stopTest();
            System.assertNotEquals(null, result);
        }
    }

    @IsTest
    static void testGetEligibleTransactions_FullFieldMapping() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        FEC_Customer_History__c ch = [
            SELECT Id FROM FEC_Customer_History__c WHERE Id = :c.FEC_Account_or_Contract__c LIMIT 1
        ];
        insert new FEC_Transaction__c(
            FEC_Customer_History__c = ch.Id,
            FEC_Transaction_Amount__c = 2000,
            FEC_Transaction_Plan__c = 'PLAN99',
            FEC_Effective_Date__c = Date.today(),
            FEC_Post_Date__c = Date.today(),
            FEC_Transaction_Code__c = '0106',
            FEC_Authorization_Code__c = 'AUTH01',
            FEC_Merchant_Description__c = 'Merchant X',
            FEC_IPPEligibilityFlag__c = 'R',
            FEC_Type__c = 'Unbilled'
        );
        System.runAs(runAsAdmin()) {
            FEC_IPPConversionController.unbilledApiTestMode = 1;
            FEC_IPPConversionController.unbilledApiTestResponse = new FEC_GetUnbilledTransactions.ResponseWrapper();
            FEC_IPPConversionController.unbilledApiTestResponse.Transactions = new List<FEC_GetUnbilledTransactions.TransactionRecord>();
            Test.startTest();
            List<FEC_IPPConversionController.EligibleTransactionDTO> txs =
                FEC_IPPConversionController.getEligibleTransactions(c.Id);
            Test.stopTest();
            System.assert(txs.size() >= 1);
        }
    }

    @IsTest
    static void testMapUnbilledApiTransactions() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        FEC_TransactionsController.TransactionsResponse res = new FEC_TransactionsController.TransactionsResponse();
        FEC_TransactionsController.TransactionDTO dto = new FEC_TransactionsController.TransactionDTO();
        dto.Id = tx.Id;
        dto.transactionCode = 'TXN001';
        dto.effectiveDate = Date.today();
        dto.transactionPlan = 'PLAN01';
        dto.transactionAmount = 1000;
        dto.postingDate = Date.today();
        dto.authorizationCode = 'AUTH01';
        dto.merchantDescription = 'Merchant';
        res.unbilledTransactions = new List<FEC_TransactionsController.TransactionDTO>{ dto };

        FEC_TransactionsController.TransactionDTO skipDto = new FEC_TransactionsController.TransactionDTO();
        skipDto.Id = null;
        res.unbilledTransactions.add(skipDto);

        Test.startTest();
        List<FEC_IPPConversionController.EligibleTransactionDTO> mapped =
            FEC_IPPConversionController.mapUnbilledApiTransactions(res);
        List<FEC_IPPConversionController.EligibleTransactionDTO> emptyMapped =
            FEC_IPPConversionController.mapUnbilledApiTransactions(null);
        Test.stopTest();

        System.assertEquals(1, mapped.size());
        System.assertEquals(0, emptyMapped.size());

        FEC_TransactionsController.TransactionDTO nullFields = new FEC_TransactionsController.TransactionDTO();
        nullFields.Id = tx.Id;
        FEC_TransactionsController.TransactionsResponse resNull = new FEC_TransactionsController.TransactionsResponse();
        resNull.unbilledTransactions = new List<FEC_TransactionsController.TransactionDTO>{ nullFields };
        List<FEC_IPPConversionController.EligibleTransactionDTO> nullMapped =
            FEC_IPPConversionController.mapUnbilledApiTransactions(resNull);
        System.assertEquals(1, nullMapped.size());
    }

    @IsTest
    static void testLoadEligibleTransactionsFromDb_EmptyCase() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case orphan = new Case(
            Subject = 'IPP db empty',
            Status = 'New',
            FEC_ID_Search__c = 'IPPCV-DB-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert orphan;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        Test.startTest();
        List<FEC_IPPConversionController.EligibleTransactionDTO> txs =
            FEC_IPPConversionController.loadEligibleTransactionsFromDb(orphan.Id);
        List<FEC_IPPConversionController.EligibleTransactionDTO> nullTxs =
            FEC_IPPConversionController.loadEligibleTransactionsFromDb(null);
        Test.stopTest();
        System.assertEquals(0, txs.size());
        System.assertEquals(0, nullTxs.size());
    }

    @IsTest
    static void testApplyCashIppTenorOptions_BuildTenureList() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        FEC_IPPConversionController.AccountTenorDTO dto = new FEC_IPPConversionController.AccountTenorDTO();
        FEC_GetAccountDetails.CashIPPInfo cashIpp = new FEC_GetAccountDetails.CashIPPInfo();
        cashIpp.MinTenure = 6;
        cashIpp.MaxTenure = 9;
        cashIpp.PlanNumber = '90003';
        Test.startTest();
        FEC_IPPConversionController.applyCashIppTenorOptions(dto, cashIpp);
        FEC_IPPConversionController.applyCashIppTenorOptions(null, cashIpp);
        FEC_IPPConversionController.applyCashIppTenorOptions(dto, null);
        Test.stopTest();
        System.assertEquals(2, dto.tenorOptions.size());
    }

    @IsTest
    static void testLoadIppTenorOptions_CalloutException() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new IppConversionAccountDetailsThrowMock());
        Test.startTest();
        FEC_IPPConversionController.AccountTenorDTO dto =
            FEC_IPPConversionController.loadIppTenorOptions(c.Id);
        Test.stopTest();
        System.assertNotEquals(null, dto.errorMessage);
    }

    @IsTest
    static void testCheckIPPDetails_NotFoundTransaction() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        String txPrefix = FEC_Transaction__c.SObjectType.getDescribe().getKeyPrefix();
        Id fakeTxId = (Id)(txPrefix + '000000000001');
        Test.startTest();
        FEC_IPPConversionController.IPPDetailsDTO dto =
            FEC_IPPConversionController.checkIPPDetails(c.Id, fakeTxId, 6);
        Test.stopTest();
        System.assertNotEquals(null, dto.errorMessage);
    }

    @IsTest
    static void testCheckIPPDetails_NotSuccessResponse() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new IppConversionIppDetailsNotSuccessMock());
        Test.startTest();
        FEC_IPPConversionController.IPPDetailsDTO dto =
            FEC_IPPConversionController.checkIPPDetails(c.Id, tx.Id, 6);
        Test.stopTest();
        System.assertNotEquals(null, dto.errorMessage);
    }

    @IsTest
    static void testCheckIPPDetails_SysMessageSuccess() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new IppConversionIppDetailsSysMessageMock());
        System.runAs(runAsAdmin()) {
            Test.startTest();
            FEC_IPPConversionController.IPPDetailsDTO dto =
                FEC_IPPConversionController.checkIPPDetails(c.Id, tx.Id, 6);
            Test.stopTest();
            System.assertEquals(null, dto.errorMessage);
        }
    }

    @IsTest
    static void testConvertIPP_NotFoundTransaction() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        String txPrefix = FEC_Transaction__c.SObjectType.getDescribe().getKeyPrefix();
        Id fakeTxId = (Id)(txPrefix + '000000000001');
        Test.startTest();
        FEC_IPPConversionController.ConvertResultDTO result =
            FEC_IPPConversionController.convertIPP(c.Id, fakeTxId, 6);
        Test.stopTest();
        System.assertNotEquals(null, result.errorMessage);
    }

    @IsTest
    static void testConvertIPP_MaxRetriesExceeded() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, FEC_Process_Action_Count__c = 2);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        Test.setMock(HttpCalloutMock.class, new IppConversionAddIppFailureMock());
        System.runAs(runAsAdmin()) {
            Test.startTest();
            FEC_IPPConversionController.ConvertResultDTO result =
                FEC_IPPConversionController.convertIPP(c.Id, tx.Id, 6);
            Test.stopTest();
            System.assertEquals(true, result.maxRetriesExceeded);
        }
    }

    @IsTest
    static void testConvertIPP_CalloutException() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new IppConversionAddIppThrowMock());
        System.runAs(runAsAdmin()) {
            Test.startTest();
            FEC_IPPConversionController.ConvertResultDTO result =
                FEC_IPPConversionController.convertIPP(c.Id, tx.Id, 6);
            Test.stopTest();
            System.assertNotEquals(null, result.errorMessage);
        }
    }

    @IsTest
    static void testCheckIPPDetails_NoEffectiveDate() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c ch = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];
        FEC_Transaction__c tx = new FEC_Transaction__c(
            FEC_Customer_History__c = ch.Id,
            FEC_Transaction_Amount__c = 500,
            FEC_Transaction_Plan__c = 'PLAN01',
            FEC_Transaction_Code__c = 'TXN02'
        );
        insert tx;
        Test.setMock(HttpCalloutMock.class, new IppConversionIppDetailsMock());
        System.runAs(runAsAdmin()) {
            Test.startTest();
            FEC_IPPConversionController.IPPDetailsDTO dto =
                FEC_IPPConversionController.checkIPPDetails(c.Id, tx.Id, 6);
            Test.stopTest();
            System.assertEquals(null, dto.errorMessage);
        }
    }

    @IsTest
    static void testCheckIPPDetails_InvalidAccountFromCase() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, FEC_Account_Number__c = null);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        FEC_Customer_History__c ch = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];
        update new FEC_Customer_History__c(Id = ch.Id, FEC_Account_Number__c = 'INVALID');
        FEC_Transaction__c tx = new FEC_Transaction__c(
            FEC_Customer_History__c = ch.Id,
            FEC_Transaction_Amount__c = 500,
            FEC_Transaction_Plan__c = 'PLAN01',
            FEC_Effective_Date__c = Date.today()
        );
        insert tx;
        Test.startTest();
        FEC_IPPConversionController.IPPDetailsDTO dto =
            FEC_IPPConversionController.checkIPPDetails(c.Id, tx.Id, 6);
        Test.stopTest();
        System.assertNotEquals(null, dto.errorMessage);
    }

    @IsTest
    static void testResolveEligibleTransactions_ApiMapped() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        FEC_TransactionsController.TransactionsResponse res = new FEC_TransactionsController.TransactionsResponse();
        FEC_TransactionsController.TransactionDTO txDto = new FEC_TransactionsController.TransactionDTO();
        txDto.Id = tx.Id;
        txDto.transactionAmount = 1000;
        txDto.transactionPlan = 'PLAN01';
        res.unbilledTransactions = new List<FEC_TransactionsController.TransactionDTO>{ txDto };
        Test.startTest();
        List<FEC_IPPConversionController.EligibleTransactionDTO> mapped =
            FEC_IPPConversionController.resolveEligibleTransactions(c.Id, res);
        Test.stopTest();
        System.assertEquals(1, mapped.size());
        System.assertEquals(tx.Id, mapped[0].transactionId);
    }

    @IsTest
    static void testCheckIPPDetails_NullIppDetailsStub() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        FEC_IPPConversionController.ippDetailsTestMode = 1;
        try {
            Test.startTest();
            FEC_IPPConversionController.IPPDetailsDTO dto =
                FEC_IPPConversionController.checkIPPDetails(c.Id, tx.Id, 6);
            Test.stopTest();
            System.assertNotEquals(null, dto.errorMessage);
        } finally {
            FEC_IPPConversionController.ippDetailsTestMode = 0;
        }
    }

    @IsTest
    static void testConvertIPP_MissingReferenceNumber() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c ch = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];
        FEC_Transaction__c tx = new FEC_Transaction__c(
            FEC_Customer_History__c = ch.Id,
            FEC_Transaction_Amount__c = 900,
            FEC_Transaction_Plan__c = 'PLAN03',
            FEC_Effective_Date__c = Date.today(),
            FEC_Card_Seq__c = '0',
            FEC_IPP_Key__c = 'KEY-IPP-003'
        );
        insert tx;
        Test.setMock(HttpCalloutMock.class, new IppConversionAddIppSuccessMock());
        System.runAs(runAsAdmin()) {
            Test.startTest();
            FEC_IPPConversionController.ConvertResultDTO result =
                FEC_IPPConversionController.convertIPP(c.Id, tx.Id, 6);
            Test.stopTest();
            System.assertEquals(false, result.success);
            System.assertNotEquals(null, result.errorMessage);
        }
    }

    @IsTest
    static void testSaveCaseIppTerm_InvalidTenor() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        FEC_IPPConversionController.saveCaseIppTerm(null, 6);
        FEC_IPPConversionController.saveCaseIppTerm(c.Id, 0);
        Test.stopTest();
    }

    @IsTest
    static void testGetConvertActionStatus_FakeCaseId() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Id fakeCaseId = (Id)(Case.SObjectType.getDescribe().getKeyPrefix() + '000000000099');
        Test.startTest();
        FEC_IPPConversionController.ActionStatusDTO status =
            FEC_IPPConversionController.getConvertActionStatus(fakeCaseId);
        Test.stopTest();
        System.assertEquals(true, status.canConvert);
    }

    @IsTest
    static void testGetAccountNumberForGetIPPDetails_CaseFallback() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c ch = [
            SELECT Id
            FROM FEC_Customer_History__c
            LIMIT 1
        ];
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new FEC_Customer_History__c(Id = ch.Id, FEC_Account_Number__c = 'BAD');
            update new Case(Id = c.Id, FEC_Account_Number__c = ACCOUNT_NUMBER);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        Test.startTest();
        String acc = FEC_IPPConversionController.getAccountNumberForGetIPPDetails(c.Id, 'INVALID');
        Test.stopTest();
        System.assertEquals(ACCOUNT_NUMBER, acc);
    }

    @IsTest
    static void testMapUnbilledApiTransactions_SkipNullIdOnly() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        FEC_TransactionsController.TransactionsResponse res = new FEC_TransactionsController.TransactionsResponse();
        FEC_TransactionsController.TransactionDTO skipDto = new FEC_TransactionsController.TransactionDTO();
        skipDto.Id = null;
        res.unbilledTransactions = new List<FEC_TransactionsController.TransactionDTO>{ skipDto };
        Test.startTest();
        List<FEC_IPPConversionController.EligibleTransactionDTO> mapped =
            FEC_IPPConversionController.mapUnbilledApiTransactions(res);
        Test.stopTest();
        System.assertEquals(0, mapped.size());
    }

    @IsTest
    static void testPrivateHelperCoverage() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [
            SELECT Id, FEC_Account_Number__c, FEC_Account_Contract_Number_Text__c,
                FEC_Account_or_Contract__c,
                FEC_Account_or_Contract__r.FEC_Account_Number__c,
                FEC_Account_or_Contract__r.FEC_Card_Number__c
            FROM Case
            LIMIT 1
        ];
        FEC_IPPConversionController.AccountTenorDTO tenorDto = new FEC_IPPConversionController.AccountTenorDTO();
        FEC_IPPConversionController.applySavedIppFieldsToTenorDto(null, tenorDto);
        FEC_IPPConversionController.applySavedIppFieldsToTenorDto(c, null);

        FEC_IPPConversionController.ConvertResultDTO convertDto = new FEC_IPPConversionController.ConvertResultDTO();
        FEC_IPPConversionController.applyAddIppResultToConvertResult(null, convertDto);
        System.assertEquals(false, convertDto.success);

        FEC_AddIPP.AddIPPResult addOk = new FEC_AddIPP.AddIPPResult();
        addOk.success = true;
        addOk.responseDescription = 'RESP';
        FEC_IPPConversionController.applyAddIppResultToConvertResult(addOk, convertDto);
        System.assertEquals('RESP', convertDto.message);

        FEC_AddIPP.AddIPPResult addOkDesc = new FEC_AddIPP.AddIPPResult();
        addOkDesc.success = true;
        addOkDesc.description = 'OK';
        FEC_IPPConversionController.applyAddIppResultToConvertResult(addOkDesc, convertDto);

        FEC_AddIPP.AddIPPResult addFail = new FEC_AddIPP.AddIPPResult();
        addFail.success = false;
        addFail.errorMessage = 'ERR';
        FEC_IPPConversionController.applyAddIppResultToConvertResult(addFail, convertDto);
        System.assertEquals('ERR', convertDto.errorMessage);

        FEC_AddIPP.AddIPPResult addFailDesc = new FEC_AddIPP.AddIPPResult();
        addFailDesc.success = false;
        addFailDesc.description = 'DESC';
        FEC_IPPConversionController.applyAddIppResultToConvertResult(addFailDesc, convertDto);

        FEC_AddIPP.AddIPPResult addOkDefault = new FEC_AddIPP.AddIPPResult();
        addOkDefault.success = true;
        FEC_IPPConversionController.applyAddIppResultToConvertResult(addOkDefault, convertDto);

        FEC_AddIPP.AddIPPResult addFailDefault = new FEC_AddIPP.AddIPPResult();
        addFailDefault.success = false;
        FEC_IPPConversionController.applyAddIppResultToConvertResult(addFailDefault, convertDto);

        System.assertEquals(null, FEC_IPPConversionController.accountNumberIfValidFormat(null));
        System.assertEquals(null, FEC_IPPConversionController.accountNumberIfValidFormat('BAD'));
        System.assertEquals(ACCOUNT_NUMBER, FEC_IPPConversionController.accountNumberIfValidFormat(ACCOUNT_NUMBER));

        System.assertEquals(ACCOUNT_NUMBER, FEC_IPPConversionController.getAccountNumberForGetIPPDetails(c.Id, ACCOUNT_NUMBER));
        System.assertEquals(null, FEC_IPPConversionController.getAccountNumberForGetIPPDetails(null, 'BAD'));
        System.assertEquals(ACCOUNT_NUMBER, FEC_IPPConversionController.getAccountNumberForGetIPPDetails(c.Id, 'BAD'));
        System.assertEquals(null, FEC_IPPConversionController.getAccountNumberForGetIPPDetails((Id)(Case.SObjectType.getDescribe().getKeyPrefix() + '000000000001'), 'BAD'));
        if (String.isNotBlank(c.FEC_Account_Contract_Number_Text__c)) {
            System.assertEquals(
                c.FEC_Account_Contract_Number_Text__c.trim(),
                FEC_IPPConversionController.resolveAccountNumberForAddIPP(c)
            );
        }
        System.assertEquals(null, FEC_IPPConversionController.resolveAccountNumberForAddIPP(null));

        FEC_GetIPPDetailsCallout.IPPDetailsResponse okResp = new FEC_GetIPPDetailsCallout.IPPDetailsResponse();
        okResp.status = FEC_ConstantCommon.SUCCESS_STATUS_CODE;
        System.assertEquals(true, FEC_IPPConversionController.isGetIPPDetailsResponseSuccess(okResp));

        FEC_IPPConversionController.clearCaseIppDetailFields(null);
        FEC_IPPConversionController.updateCaseIppConversionFields(null, 6, 1, 1, 1);
        Map<String, Schema.SObjectField> caseFieldMap = Schema.SObjectType.Case.fields.getMap();
        if (caseFieldMap.containsKey('FEC_IPP_Interest__c')) {
            FEC_IPPConversionController.clearCaseIppDetailFields(c.Id);
            FEC_IPPConversionController.updateCaseIppConversionFields(c.Id, 6, 10, 20, 30);
        }

        FEC_IPPConversionController.updateCaseIppTermOnly(null, 6);
        FEC_IPPConversionController.updateCaseIppTermOnly(c.Id, 0);

        FEC_Transaction__c tx = [SELECT Id, FEC_Customer_History__c, FEC_Customer_History__r.FEC_Card_Number__c FROM FEC_Transaction__c LIMIT 1];
        System.assertEquals(CARD_NUMBER, FEC_IPPConversionController.resolveCardNumberForGetIppDetails(c));
        System.assertEquals(null, FEC_IPPConversionController.resolveCardNumberForGetIppDetails(null));

        System.assertEquals(null, FEC_IPPConversionController.parseCardSeqForGetIppDetails(null));
        System.assertEquals(null, FEC_IPPConversionController.parseCardSeqForGetIppDetails(''));
        System.assertEquals(2, FEC_IPPConversionController.parseCardSeqForGetIppDetails('2'));
        System.assertEquals(null, FEC_IPPConversionController.parseCardSeqForGetIppDetails('ABC'));

        FEC_IPPConversionController.accountContractTextForTest = ACCOUNT_NUMBER;
        try {
            System.assertEquals(ACCOUNT_NUMBER, FEC_IPPConversionController.resolveAccountNumberForAddIPP(c));
            System.assertEquals(ACCOUNT_NUMBER, FEC_IPPConversionController.getAccountNumberForGetIPPDetails(c.Id, 'BAD'));
        } finally {
            FEC_IPPConversionController.accountContractTextForTest = null;
        }

        FEC_IPPConversionController.updateCaseActionCountForConvertResult(null, true);
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            FEC_IPPConversionController.updateCaseActionCountForConvertResult(c, true);
            FEC_IPPConversionController.updateCaseActionCountForConvertResult(c, false);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Transaction__c eligibleNoFlag = new FEC_Transaction__c(
            FEC_Transaction_Code__c = '0105'
        );
        System.assertEquals(true, FEC_IPPConversionController.isIppEligibleForDisplay(eligibleNoFlag));

        FEC_Transaction__c eligibleFlagR = new FEC_Transaction__c(
            FEC_Transaction_Code__c = '0105',
            FEC_IPPEligibilityFlag__c = 'R'
        );
        System.assertEquals(true, FEC_IPPConversionController.isIppEligibleForDisplay(eligibleFlagR));

        FEC_Transaction__c ineligibleFlag = new FEC_Transaction__c(
            FEC_Transaction_Code__c = '0105',
            FEC_IPPEligibilityFlag__c = 'X'
        );
        System.assertEquals(false, FEC_IPPConversionController.isIppEligibleForDisplay(ineligibleFlag));

        System.assertEquals(6, FEC_IPPConversionController.resolveIppTermForGetIppDetails(eligibleFlagR, 6));
        System.assertEquals(true, FEC_IPPConversionController.collectSyncedTransactionIds(null, null).isEmpty());
    }

    @IsTest
    static void testSchemaAndCatchCoverage() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];

        FEC_IPPConversionController.denyTransactionAccessForTest = true;
        try {
            FEC_IPPConversionController.IPPDetailsDTO deniedDetails =
                FEC_IPPConversionController.checkIPPDetails(c.Id, tx.Id, 6);
            System.assertNotEquals(null, deniedDetails.errorMessage);
            FEC_IPPConversionController.ConvertResultDTO deniedConvert =
                FEC_IPPConversionController.convertIPP(c.Id, tx.Id, 6);
            System.assertNotEquals(null, deniedConvert.errorMessage);
        } finally {
            FEC_IPPConversionController.denyTransactionAccessForTest = false;
        }

        FEC_IPPConversionController.denyCaseAccessForTest = true;
        try {
            FEC_IPPConversionController.AccountTenorDTO deniedTenor =
                FEC_IPPConversionController.loadIppTenorOptions(c.Id);
            System.assertEquals(System.Label.FEC_MSG_Not_Account_Linked, deniedTenor.errorMessage);
        } finally {
            FEC_IPPConversionController.denyCaseAccessForTest = false;
        }

        FEC_IPPConversionController.denyIppTermUpdateForTest = true;
        try {
            FEC_IPPConversionController.saveCaseIppTerm(c.Id, 6);
        } finally {
            FEC_IPPConversionController.denyIppTermUpdateForTest = false;
        }

        FEC_IPPConversionController.denyActionCountUpdateForTest = true;
        try {
            FEC_IPPConversionController.updateCaseActionCountForConvertResult(c, true);
        } finally {
            FEC_IPPConversionController.denyActionCountUpdateForTest = false;
        }

        FEC_IPPConversionController.addIppTestMode = 1;
        try {
            System.runAs(runAsAdmin()) {
                System.assertNotEquals(null, FEC_IPPConversionController.convertIPP(c.Id, tx.Id, 6).errorMessage);
            }
        } finally {
            FEC_IPPConversionController.addIppTestMode = 0;
        }
    }

    @IsTest
    static void testContractTextAccountResolution() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }
        Case c = [
            SELECT Id, FEC_Account_Contract_Number_Text__c, FEC_Account_Number__c,
                FEC_Account_or_Contract__c,
                FEC_Account_or_Contract__r.FEC_Account_Number__c
            FROM Case
            LIMIT 1
        ];
        if (String.isNotBlank(c.FEC_Account_Contract_Number_Text__c)) {
            System.assertEquals(
                c.FEC_Account_Contract_Number_Text__c.trim(),
                FEC_IPPConversionController.resolveAccountNumberForAddIPP(c)
            );
        }
        FEC_Customer_History__c ch = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new FEC_Customer_History__c(Id = ch.Id, FEC_Account_Number__c = 'BAD');
            update new Case(Id = c.Id, FEC_Account_Number__c = null);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        c = [
            SELECT Id, FEC_Account_Contract_Number_Text__c
            FROM Case
            WHERE Id = :c.Id
        ];
        if (String.isNotBlank(c.FEC_Account_Contract_Number_Text__c)) {
            String acc = FEC_IPPConversionController.getAccountNumberForGetIPPDetails(c.Id, 'BAD');
            System.assertEquals(c.FEC_Account_Contract_Number_Text__c.trim(), acc);
        }
    }

    private class IppConversionApiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><Response><Sys><Code>1</Code></Sys></Response></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class IppConversionAccountDetailsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<?xml version=\'1.0\' encoding=\'utf-8\'?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body>' +
                '<NS1:GetAccountDetailsResponse xmlns:NS1="http://esbservice.fecredit.org/EStatementService/">' +
                '<NS1:SysResponse><TransID>t1</TransID><DateTime>2026-03-26T15:11:52</DateTime>' +
                '<Status>0</Status><Description>Success</Description></NS1:SysResponse>' +
                '<NS1:AccountRecords><AccountRecord><AccountNumber>0001500060000003</AccountNumber>' +
                '<IPPEligibilityFlag>Y</IPPEligibilityFlag>' +
                '<CashIPPInfo><PlanNumber>90003</PlanNumber><InterestRate>24</InterestRate>' +
                '<MinTenure>6</MinTenure><MaxTenure>12</MaxTenure></CashIPPInfo>' +
                '</AccountRecord></NS1:AccountRecords>' +
                '</NS1:GetAccountDetailsResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class IppConversionIppDetailsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body>' +
                '<GetIPPDetailsResponse>' +
                '<SysResponse>' +
                '<Status>Success</Status>' +
                '<Description>Success</Description>' +
                '<TransID>TXN12345</TransID>' +
                '<DateTime>2026-05-25T10:00:00Z</DateTime>' +
                '</SysResponse>' +
                '<InterestRate>12</InterestRate>' +
                '<ConversionFee>60000</ConversionFee>' +
                '<EMI>709465</EMI>' +
                '</GetIPPDetailsResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class IppConversionIppDetailsErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body>' +
                '<GetIPPDetailsResponse>' +
                '<SysResponse>' +
                '<Status>ERROR</Status>' +
                '<Description>Failed</Description>' +
                '</SysResponse>' +
                '</GetIPPDetailsResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class IppConversionAccountDetailsEmptyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<?xml version="1.0"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><NS1:GetAccountDetailsResponse xmlns:NS1="http://esbservice.fecredit.org/EStatementService/">' +
                '<NS1:SysResponse><Status>0</Status></NS1:SysResponse>' +
                '<NS1:AccountRecords></NS1:AccountRecords>' +
                '</NS1:GetAccountDetailsResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class IppConversionAccountDetailsRetailOnlyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<?xml version="1.0"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><NS1:GetAccountDetailsResponse xmlns:NS1="http://esbservice.fecredit.org/EStatementService/">' +
                '<NS1:SysResponse><Status>0</Status><Description>Success</Description></NS1:SysResponse>' +
                '<NS1:AccountRecords><AccountRecord><AccountNumber>0001500060000003</AccountNumber>' +
                '<RetailIPPInfo><PlanNumber>80001</PlanNumber></RetailIPPInfo>' +
                '</AccountRecord></NS1:AccountRecords>' +
                '</NS1:GetAccountDetailsResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class IppConversionIppDetailsEmptyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('');
            return res;
        }
    }

    private class IppConversionIppDetailsInstallmentMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetIPPDetailsResponse>' +
                '<SysResponse><Status>Success</Status></SysResponse>' +
                '<InterestRate>10</InterestRate><ConversionFee>1000</ConversionFee>' +
                '<InstallmentAmount>500000</InstallmentAmount>' +
                '</GetIPPDetailsResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class IppConversionIppDetailsStatusCodeMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetIPPDetailsResponse>' +
                '<SysResponse><Status>0</Status></SysResponse>' +
                '<InterestRate>11</InterestRate><ConversionFee>2000</ConversionFee><EMI>3000</EMI>' +
                '</GetIPPDetailsResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class IppConversionIppDetailsThrowMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated callout failure');
        }
    }

    private class IppConversionAddIppSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<?xml version="1.0"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"' +
                ' xmlns:est="http://esbservice.fecredit.org/EStatementService/">' +
                '<soapenv:Body><est:AddIPPResponse><SysResponse>' +
                '<Status>1</Status><Description>Converted successfully</Description>' +
                '</SysResponse></est:AddIPPResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class IppConversionAddIppFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<?xml version="1.0"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"' +
                ' xmlns:est="http://esbservice.fecredit.org/EStatementService/">' +
                '<soapenv:Body><est:AddIPPResponse><SysResponse>' +
                '<Status>0</Status><Description>Add IPP failed</Description>' +
                '</SysResponse></est:AddIPPResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class IppConversionAccountDetailsThrowMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated account details failure');
        }
    }

    private class IppConversionIppDetailsNotSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetIPPDetailsResponse>' +
                '<SysResponse><Status>FAILED</Status></SysResponse>' +
                '</GetIPPDetailsResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class IppConversionIppDetailsSysMessageMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetIPPDetailsResponse>' +
                '<SysResponse><Description>Success</Description></SysResponse>' +
                '<InterestRate>8</InterestRate><ConversionFee>100</ConversionFee><EMI>200</EMI>' +
                '</GetIPPDetailsResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class IppConversionAddIppThrowMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated AddIPP failure');
        }
    }
}
