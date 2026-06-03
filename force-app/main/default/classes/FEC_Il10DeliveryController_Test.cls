@IsTest
private class FEC_Il10DeliveryController_Test {

    @TestSetup
    static void setupData() {
        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(Subject = 'IL10 Delivery Test Case');
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c customer = new FEC_Customer_History__c(
            Name = 'IL10-CUST-001',
            FEC_Case__c = c.Id,
            FEC_Email__c = 'il10@test.example',
            FEC_Customer_Name__c = 'IL10 Customer',
            FEC_Primary_Phone__c = '0900000001'
        );
        insert customer;

        c.FEC_Account_or_Contract__c = customer.Id;
        update c;

        insert new List<FEC_Address_Info__c>{
            new FEC_Address_Info__c(
                FEC_Customer_History__c = customer.Id,
                FEC_Case__c = null,
                FEC_Address_Type__c = 'Current Address',
                FEC_Street__c = 'Unassigned Street',
                FEC_Number__c = '100',
                FEC_Mailing_Address__c = false
            ),
            new FEC_Address_Info__c(
                FEC_Customer_History__c = customer.Id,
                FEC_Case__c = c.Id,
                FEC_Address_Type__c = FEC_ConstantCommon.CONTRACT_CLOSURE_ADDRESS_TYPE_TEMPORARY,
                FEC_Street__c = 'Temporary Street',
                FEC_Number__c = '200',
                FEC_Mailing_Address__c = true
            )
        };
    }

    @IsTest
    static void testGetInitData_NullCaseId() {
        Test.startTest();
        FEC_Il10DeliveryController.InitDataDTO result = FEC_Il10DeliveryController.getInitData(null);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.initData);
        System.assertEquals(false, result.initData.success);
    }

    @IsTest
    static void testGetInitData_WithAddresses() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_Il10DeliveryController.InitDataDTO result = FEC_Il10DeliveryController.getInitData(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.initData);
        System.assertEquals(true, result.initData.success);
        System.assert(result.initData.addresses.size() >= 1, 'Should include unassigned case addresses.');
        System.assertNotEquals(null, result.caseTemporaryAddressRow);
        System.assertEquals(
            FEC_ConstantCommon.CONTRACT_CLOSURE_ADDRESS_TYPE_TEMPORARY,
            result.caseTemporaryAddressRow.addressType
        );
    }

    @IsTest
    static void testGetInitData_CaseWithoutCustomerHistory() {
        Case bareCase = new Case(Subject = 'IL10 No Customer History');
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert bareCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_Il10DeliveryController.InitDataDTO result =
            FEC_Il10DeliveryController.getInitData(bareCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.initData);
    }
}
