@IsTest
private class FEC_PaymentHistoryValidationService_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);

        FEC_Sub_Code__c sc1 = new FEC_Sub_Code__c(
            Name = 'SC RL0402',
            FEC_Code__c = 'RL04.02',
            FEC_Active__c = true
        );
        FEC_Sub_Code__c sc2 = new FEC_Sub_Code__c(
            Name = 'SC RL0403',
            FEC_Code__c = 'RL04.03',
            FEC_Active__c = true
        );
        FEC_Sub_Code__c sc3 = new FEC_Sub_Code__c(
            Name = 'SC RC0404',
            FEC_Code__c = 'RC04.04',
            FEC_Active__c = true
        );
        FEC_Sub_Code__c scOther = new FEC_Sub_Code__c(
            Name = 'SC Other',
            FEC_Code__c = 'OTHER' + suffix,
            FEC_Active__c = true
        );
        insert new List<FEC_Sub_Code__c>{ sc1, sc2, sc3, scOther };

        FEC_Customer_History__c ch;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Case c = new Case(Status = 'New');
            insert c;

            ch = new FEC_Customer_History__c(
                FEC_Case__c = c.Id,
                Name = 'CUST-' + suffix,
                FEC_Account_Status__c = '1',
                FEC_Contract_Status__c = 'Active',
                FEC_OTB__c = 1000000,
                FEC_Credit_Limit__c = 500000,
                FEC_National_ID_Passport_ID__c = 'ID' + suffix,
                FEC_Customer_Name__c = 'Test Customer',
                FEC_Place_of_Issue__c = 'HCM',
                FEC_Total_Balance__c = 2000000,
                FEC_Date_of_Issue__c = Date.today().addYears(-1),
                FEC_Expiry_Date__c = Date.today().addYears(1)
            );
            insert ch;

            c.FEC_Account_or_Contract__c = ch.Id;
            update c;

            insert new FEC_Payment_History__c(
                FEC_Customer_History__c = ch.Id,
                FEC_Payment_No__c = 1,
                FEC_Payment_Date__c = Date.today(),
                FEC_Payment_Amount__c = 100000
            );

        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static Case getTestCase() {
        return [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
    }

    private static Id getSubCodeId(String code) {
        return [SELECT Id FROM FEC_Sub_Code__c WHERE FEC_Code__c = :code LIMIT 1].Id;
    }

    @IsTest
    static void testValidation_RL0402_Closed() {
        Case c = getTestCase();
        FEC_Customer_History__c ch = [
            SELECT Id FROM FEC_Customer_History__c WHERE Id = :c.FEC_Account_or_Contract__c
        ];
        ch.FEC_Contract_Status__c = 'Closed';
        update ch;

        Test.startTest();
        FEC_PaymentHistoryValidationService.PaymentHistoryRequestValidationResult res =
            FEC_PaymentHistoryValidationService.validatePaymentHistoryRequestForSubCode(
                String.valueOf(c.Id),
                String.valueOf(getSubCodeId('RL04.02'))
            );
        Test.stopTest();

        System.assertEquals(false, res.allowed);
        System.assertNotEquals(null, res.message);
    }

    @IsTest
    static void testValidation_RL0402_ActiveAllowed() {
        Case c = getTestCase();

        Test.startTest();
        FEC_PaymentHistoryValidationService.PaymentHistoryRequestValidationResult res =
            FEC_PaymentHistoryValidationService.validatePaymentHistoryRequestForSubCode(
                String.valueOf(c.Id),
                String.valueOf(getSubCodeId('RL04.02'))
            );
        Test.stopTest();

        System.assertEquals(true, res.allowed);
        System.assertEquals(null, res.message);
    }

    @IsTest
    static void testValidation_RL0403_InsufficientPayment() {
        Case c = getTestCase();

        Test.startTest();
        FEC_PaymentHistoryValidationService.PaymentHistoryRequestValidationResult res =
            FEC_PaymentHistoryValidationService.validatePaymentHistoryRequestForSubCode(
                String.valueOf(c.Id),
                String.valueOf(getSubCodeId('RL04.03'))
            );
        Test.stopTest();

        System.assertEquals(false, res.allowed);
        System.assertNotEquals(null, res.message);
    }

    @IsTest
    static void testValidation_RL0403_SufficientPaymentsAllowed() {
        Case c = getTestCase();
        List<FEC_Payment_History__c> extra = new List<FEC_Payment_History__c>();
        for (Integer i = 2; i <= 7; i++) {
            extra.add(
                new FEC_Payment_History__c(
                    FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
                    FEC_Payment_No__c = i,
                    FEC_Payment_Date__c = Date.today().addDays(-i),
                    FEC_Payment_Amount__c = 50000
                )
            );
        }
        insert extra;

        Test.startTest();
        FEC_PaymentHistoryValidationService.PaymentHistoryRequestValidationResult res =
            FEC_PaymentHistoryValidationService.validatePaymentHistoryRequestForSubCode(
                String.valueOf(c.Id),
                String.valueOf(getSubCodeId('RL04.03'))
            );
        Test.stopTest();

        System.assertEquals(true, res.allowed);
    }

    @IsTest
    static void testValidation_RL0403_ClosedContract() {
        Case c = getTestCase();
        FEC_Customer_History__c ch = [
            SELECT Id FROM FEC_Customer_History__c WHERE Id = :c.FEC_Account_or_Contract__c
        ];
        ch.FEC_Contract_Status__c = 'Closed';
        update ch;

        Test.startTest();
        FEC_PaymentHistoryValidationService.PaymentHistoryRequestValidationResult res =
            FEC_PaymentHistoryValidationService.validatePaymentHistoryRequestForSubCode(
                String.valueOf(c.Id),
                String.valueOf(getSubCodeId('RL04.03'))
            );
        Test.stopTest();

        System.assertEquals(false, res.allowed);
    }

    @IsTest
    static void testValidation_RC0404_StatusEightEligible() {
        Case c = getTestCase();
        FEC_Customer_History__c ch = [
            SELECT Id FROM FEC_Customer_History__c WHERE Id = :c.FEC_Account_or_Contract__c
        ];
        ch.FEC_Account_Status__c = '8';
        update ch;

        Test.startTest();
        FEC_PaymentHistoryValidationService.PaymentHistoryRequestValidationResult res =
            FEC_PaymentHistoryValidationService.validatePaymentHistoryRequestForSubCode(
                String.valueOf(c.Id),
                String.valueOf(getSubCodeId('RC04.04'))
            );
        Test.stopTest();

        System.assertEquals(true, res.allowed);
        System.assertEquals(null, res.infoMessage);
    }

    @IsTest
    static void testValidation_RC0404_StatusNineEligible() {
        Case c = getTestCase();
        update new FEC_Customer_History__c(
            Id = c.FEC_Account_or_Contract__c,
            FEC_Account_Status__c = '9'
        );

        Test.startTest();
        FEC_PaymentHistoryValidationService.PaymentHistoryRequestValidationResult res =
            FEC_PaymentHistoryValidationService.validatePaymentHistoryRequestForSubCode(
                String.valueOf(c.Id),
                String.valueOf(getSubCodeId('RC04.04'))
            );
        Test.stopTest();

        System.assertEquals(null, res.infoMessage);
    }

    @IsTest
    static void testValidation_RC0404_NotEligible() {
        Case c = getTestCase();
        update new FEC_Customer_History__c(
            Id = c.FEC_Account_or_Contract__c,
            FEC_Account_Status__c = '1',
            FEC_Block_Code__c = 'X'
        );

        Test.startTest();
        FEC_PaymentHistoryValidationService.PaymentHistoryRequestValidationResult res =
            FEC_PaymentHistoryValidationService.validatePaymentHistoryRequestForSubCode(
                String.valueOf(c.Id),
                String.valueOf(getSubCodeId('RC04.04'))
            );
        Test.stopTest();

        System.assertNotEquals(null, res.infoMessage);
    }

    @IsTest
    static void testValidation_RC0404_BlockCodeAndStatementEligible() {
        if (!Schema.getGlobalDescribe().containsKey('FEC_Statement__c')) {
            System.assert(true, 'Skipped: FEC_Statement__c not on org.');
            return;
        }

        Case c = getTestCase();
        update new FEC_Customer_History__c(
            Id = c.FEC_Account_or_Contract__c,
            FEC_Account_Status__c = '1',
            FEC_Block_Code__c = 'C',
            FEC_OTB__c = 600000,
            FEC_Credit_Limit__c = 500000
        );

        insert new FEC_Statement__c(
            FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
            FEC_Statement_Date__c = Date.today(),
            FEC_IPP_Principal__c = 0
        );

        Test.startTest();
        FEC_PaymentHistoryValidationService.PaymentHistoryRequestValidationResult res =
            FEC_PaymentHistoryValidationService.validatePaymentHistoryRequestForSubCode(
                String.valueOf(c.Id),
                String.valueOf(getSubCodeId('RC04.04'))
            );
        Test.stopTest();

        System.assertEquals(null, res.infoMessage);
    }

    @IsTest
    static void testValidation_BlankAndUnknownSubCode() {
        Case c = getTestCase();
        FEC_Sub_Code__c other = [
            SELECT Id, FEC_Code__c
            FROM FEC_Sub_Code__c
            WHERE FEC_Code__c LIKE 'OTHER%'
            LIMIT 1
        ];

        Test.startTest();
        FEC_PaymentHistoryValidationService.PaymentHistoryRequestValidationResult blank =
            FEC_PaymentHistoryValidationService.validatePaymentHistoryRequestForSubCode(
                '',
                String.valueOf(getSubCodeId('RL04.02'))
            );
        FEC_PaymentHistoryValidationService.PaymentHistoryRequestValidationResult unknown =
            FEC_PaymentHistoryValidationService.validatePaymentHistoryRequestForSubCode(
                String.valueOf(c.Id),
                String.valueOf(other.Id)
            );
        FEC_PaymentHistoryValidationService.PaymentHistoryRequestValidationResult badSub =
            FEC_PaymentHistoryValidationService.validatePaymentHistoryRequestForSubCode(
                String.valueOf(c.Id),
                String.valueOf(
                    Schema.SObjectType.FEC_Sub_Code__c.getKeyPrefix() + '000000000001'
                )
            );
        Test.stopTest();

        System.assertEquals(true, blank.allowed);
        System.assertEquals(true, unknown.allowed);
        System.assertEquals(true, badSub.allowed);
    }

    @IsTest
    static void testValidation_RL0403_NoAccountOnCase() {
        Case emptyCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            emptyCase = new Case(Status = 'New');
            insert emptyCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_PaymentHistoryValidationService.PaymentHistoryRequestValidationResult res =
            FEC_PaymentHistoryValidationService.validatePaymentHistoryRequestForSubCode(
                String.valueOf(emptyCase.Id),
                String.valueOf(getSubCodeId('RL04.03'))
            );
        Test.stopTest();

        System.assertEquals(false, res.allowed);
    }

    @IsTest
    static void testGetValidationMessage() {
        Case c = getTestCase();
        String subCodeId = String.valueOf(getSubCodeId('RL04.02'));

        update new FEC_Customer_History__c(
            Id = c.FEC_Account_or_Contract__c,
            FEC_Contract_Status__c = 'Closed'
        );

        Test.startTest();
        String blockedMsg = FEC_PaymentHistoryValidationService.getValidationMessage(
            String.valueOf(c.Id),
            subCodeId
        );
        String allowedMsg = FEC_PaymentHistoryValidationService.getValidationMessage('', subCodeId);
        Test.stopTest();

        System.assertNotEquals(null, blockedMsg);
        System.assertEquals(null, allowedMsg);
    }

    @IsTest
    static void testGetDocumentRequestPdfHeaderData_FullMapping() {
        Case c = getTestCase();

        Test.startTest();
        Map<String, Object> data = FEC_PaymentHistoryValidationService.getDocumentRequestPdfHeaderData(
            String.valueOf(c.Id)
        );
        Map<String, Object> empty = FEC_PaymentHistoryValidationService.getDocumentRequestPdfHeaderData(
            ''
        );
        Test.stopTest();

        System.assertNotEquals(null, data);
        System.assert(data.containsKey('ContractNumber'));
        System.assert(data.containsKey('DateOfIssue'));
        System.assert(data.containsKey('MaturityDate2'));
        System.assert(data.containsKey('CustomerAddress'));
        System.assertEquals(true, empty.isEmpty());
    }

    @IsTest
    static void testGetDocumentRequestPdfHeaderData_NoAccount() {
        Case emptyCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            emptyCase = new Case(Status = 'New');
            insert emptyCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        Map<String, Object> data = FEC_PaymentHistoryValidationService.getDocumentRequestPdfHeaderData(
            String.valueOf(emptyCase.Id)
        );
        Test.stopTest();

        System.assertEquals(true, !data.containsKey('ContractNumber'));
    }

    @IsTest
    static void testGetValidationMessage_InfoMessagePath() {
        Case c = getTestCase();
        update new FEC_Customer_History__c(
            Id = c.FEC_Account_or_Contract__c,
            FEC_Account_Status__c = '1',
            FEC_Block_Code__c = 'X'
        );

        Test.startTest();
        String infoMsg = FEC_PaymentHistoryValidationService.getValidationMessage(
            String.valueOf(c.Id),
            String.valueOf(getSubCodeId('RC04.04'))
        );
        Test.stopTest();

        System.assertNotEquals(null, infoMsg);
    }

    @IsTest
    static void testGetPaymentHistoryRows_WithData() {
        Case c = getTestCase();

        Test.startTest();
        List<Map<String, Object>> rows = FEC_PaymentHistoryValidationService.getPaymentHistoryRows(
            String.valueOf(c.Id)
        );
        List<Map<String, Object>> blank = FEC_PaymentHistoryValidationService.getPaymentHistoryRows('');
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assert(rows[0].containsKey('PaymentAmount'));
        System.assertEquals(0, blank.size());
    }

    @IsTest
    static void testValidation_RC0404_CaseWithoutAccount() {
        Case emptyCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            emptyCase = new Case(Status = 'New');
            insert emptyCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_PaymentHistoryValidationService.PaymentHistoryRequestValidationResult res =
            FEC_PaymentHistoryValidationService.validatePaymentHistoryRequestForSubCode(
                String.valueOf(emptyCase.Id),
                String.valueOf(getSubCodeId('RC04.04'))
            );
        Test.stopTest();

        System.assertEquals(true, res.allowed);
        System.assertNotEquals(null, res.infoMessage);
    }

    @IsTest
    static void testValidation_RL0402_CaseWithoutAccount() {
        Case emptyCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            emptyCase = new Case(Status = 'New');
            insert emptyCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_PaymentHistoryValidationService.PaymentHistoryRequestValidationResult res =
            FEC_PaymentHistoryValidationService.validatePaymentHistoryRequestForSubCode(
                String.valueOf(emptyCase.Id),
                String.valueOf(getSubCodeId('RL04.02'))
            );
        Test.stopTest();

        System.assertEquals(true, res.allowed);
        System.assertEquals(null, res.message);
    }

    @IsTest
    static void testValidation_RL0403_ZeroPaymentsSyncPath() {
        Case c = getTestCase();
        delete [SELECT Id FROM FEC_Payment_History__c WHERE FEC_Customer_History__c = :c.FEC_Account_or_Contract__c];

        Test.startTest();
        FEC_PaymentHistoryValidationService.PaymentHistoryRequestValidationResult res =
            FEC_PaymentHistoryValidationService.validatePaymentHistoryRequestForSubCode(
                String.valueOf(c.Id),
                String.valueOf(getSubCodeId('RL04.03'))
            );
        Test.stopTest();

        System.assertEquals(false, res.allowed);
        System.assertNotEquals(null, res.message);
    }

    @IsTest
    static void testGetDocumentRequestPdfHeaderData_WithCurrentAddress() {
        if (!Schema.getGlobalDescribe().containsKey('FEC_Address_Info__c')) {
            System.assert(true, 'Skipped: FEC_Address_Info__c not on org.');
            return;
        }

        Case c = getTestCase();
        insert new FEC_Address_Info__c(
            FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
            FEC_Address_Type__c = 'Current Address',
            FEC_Address__c = '123 Test Street, HCM'
        );

        Test.startTest();
        Map<String, Object> data = FEC_PaymentHistoryValidationService.getDocumentRequestPdfHeaderData(
            String.valueOf(c.Id)
        );
        Test.stopTest();

        System.assert(data.containsKey('CustomerAddress'), 'Phải map CustomerAddress từ FEC_Address_Info__c.');
    }

    @IsTest
    static void testGetPaymentHistoryRows_NoAccount() {
        Case emptyCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            emptyCase = new Case(Status = 'New');
            insert emptyCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        List<Map<String, Object>> rows = FEC_PaymentHistoryValidationService.getPaymentHistoryRows(
            String.valueOf(emptyCase.Id)
        );
        Test.stopTest();

        System.assertEquals(0, rows.size());
    }

    @IsTest
    static void testGetRepaymentScheduleRows_BlankCaseId() {
        Test.startTest();
        List<Map<String, Object>> rows =
            FEC_PaymentHistoryValidationService.getRepaymentScheduleRows('');
        Test.stopTest();

        System.assertEquals(0, rows.size());
    }

    @IsTest
    static void testGetRepaymentScheduleRows_WithData() {
        String scheduleApi = Schema.getGlobalDescribe().containsKey('FEC_Repayment_Schedule__c')
            ? 'FEC_Repayment_Schedule__c'
            : (Schema.getGlobalDescribe().containsKey('FEC_RePayment_Schedule__c')
                ? 'FEC_RePayment_Schedule__c'
                : null);
        if (scheduleApi == null) {
            System.assert(true, 'Skipped: repayment schedule object not on org.');
            return;
        }

        Case c = getTestCase();
        SObject schedule = Schema.getGlobalDescribe().get(scheduleApi).newSObject();
        schedule.put('FEC_Customer_History__c', c.FEC_Account_or_Contract__c);
        if (schedule.getSObjectType().getDescribe().fields.getMap().containsKey('FEC_Case__c')) {
            schedule.put('FEC_Case__c', c.Id);
        }
        schedule.put('FEC_Installment_Due_Date__c', Date.today());
        schedule.put('FEC_Principal__c', 1000);
        schedule.put('FEC_Interest__c', 100);
        schedule.put('FEC_Closing_Principal__c', 9000);
        schedule.put('FEC_Repayment_Fee__c', 10);
        schedule.put('FEC_Installment_Amount__c', 1110);
        insert schedule;

        Test.startTest();
        List<Map<String, Object>> rows = FEC_PaymentHistoryValidationService.getRepaymentScheduleRows(
            String.valueOf(c.Id)
        );
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertEquals(1000, rows[0].get('Principal'));
    }
}
