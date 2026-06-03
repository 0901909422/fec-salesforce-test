/**
 * Unit tests for FEC_MrcDeliveryController (MRC Return delivery form).
 */
@IsTest
private class FEC_MrcDeliveryController_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'MRC Delivery Case',
                Status = 'New',
                FEC_ID_Search__c = 'MRCD-' + suffix
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Email__c = 'mrc.customer@example.com',
            FEC_Customer_Name__c = 'MRC Customer',
            FEC_Primary_Phone__c = '0901234567'
        );
        insert hist;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, FEC_Account_or_Contract__c = hist.Id);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static Case getTestCase() {
        return [SELECT Id FROM Case WHERE Subject = 'MRC Delivery Case' LIMIT 1];
    }

    private static Id fakeCaseId() {
        return (Id) (Case.SObjectType.getDescribe().getKeyPrefix() + '0'.repeat(12) + 'AAA');
    }

    @IsTest
    static void testGetInitData_NullCaseId() {
        Test.startTest();
        FEC_ContractClosureController.InitDataDTO result =
            FEC_MrcDeliveryController.getInitData(null);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertNotEquals(null, result.errorMessage);
    }

    @IsTest
    static void testGetInitData_Success() {
        Case c = getTestCase();

        Test.startTest();
        FEC_ContractClosureController.InitDataDTO result =
            FEC_MrcDeliveryController.getInitData(c.Id);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('mrc.customer@example.com', result.demographicEmail);
        System.assertNotEquals(null, result.deliveryOptions);
    }

    @IsTest
    static void testGetInitData_CaseNotFound() {
        Test.startTest();
        FEC_ContractClosureController.InitDataDTO result =
            FEC_MrcDeliveryController.getInitData(fakeCaseId());
        Test.stopTest();

        System.assertEquals(false, result.success);
    }

    @IsTest
    static void testValidateForComplete_InvalidDelivery() {
        Case c = getTestCase();
        String payload =
            '{"deliveryEmailSelected":false,"deliveryAddressSelected":false,"deliveryOfficeSelected":false}';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_MrcDeliveryController.validateForComplete(c.Id, payload);
        Test.stopTest();

        System.assertEquals(false, result.valid);
    }

    @IsTest
    static void testValidateForComplete_InvalidEmail() {
        Case c = getTestCase();
        String payload =
            '{"deliveryEmailSelected":true,"useExistingEmail":false,"temporaryEmail":"not-an-email"}';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_MrcDeliveryController.validateForComplete(c.Id, payload);
        Test.stopTest();

        System.assertEquals(false, result.valid);
    }

    @IsTest
    static void testSaveForm_FailWhenMissingDelivery() {
        Case c = getTestCase();
        String payload =
            '{"deliveryEmailSelected":false,"deliveryAddressSelected":false,"deliveryOfficeSelected":false}';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_MrcDeliveryController.saveForm(c.Id, payload);
        Test.stopTest();

        System.assertEquals(false, result.valid);
    }

    @IsTest
    static void testSaveFormDraft_Success() {
        Case c = getTestCase();
        String payload =
            '{"deliveryEmailSelected":true,"temporaryEmail":"draft.mrc@example.com"}';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO result =
            FEC_MrcDeliveryController.saveFormDraft(c.Id, payload);
        Test.stopTest();

        System.assertEquals(true, result.valid);
    }

    @IsTest
    static void testDelegateMethods_InitFailure() {
        String payload = '{"deliveryEmailSelected":true,"temporaryEmail":"x@test.com"}';

        Test.startTest();
        FEC_ContractClosureController.ValidationResultDTO validateResult =
            FEC_MrcDeliveryController.validateForComplete(fakeCaseId(), payload);
        FEC_ContractClosureController.ValidationResultDTO saveResult =
            FEC_MrcDeliveryController.saveForm(fakeCaseId(), payload);
        FEC_ContractClosureController.ValidationResultDTO draftResult =
            FEC_MrcDeliveryController.saveFormDraft(fakeCaseId(), payload);
        Test.stopTest();

        System.assertEquals(false, validateResult.valid);
        System.assertEquals(false, saveResult.valid);
        System.assertEquals(false, draftResult.valid);
        System.assert(validateResult.messages.size() > 0);
    }
}
