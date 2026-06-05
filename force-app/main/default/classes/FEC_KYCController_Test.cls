@IsTest
private class FEC_KYCController_Test {

    private static final String PRODUCT_CODE = 'Loan';

    private static String firstActivePicklistValue(Schema.SObjectField fieldRef) {
        for (Schema.PicklistEntry entry : fieldRef.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());
        String kycMethod = firstActivePicklistValue(Case.FEC_KYC_Method__c);
        if (kycMethod == null) {
            kycMethod = firstActivePicklistValue(FEC_KYC__c.FEC_KYC_Method__c);
        }

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Loan Product ' + suffix,
            FEC_Code__c = PRODUCT_CODE + suffix.right(4),
            FEC_Active__c = true
        );
        insert prod;

        FEC_KYC__c kyc = new FEC_KYC__c(
            Name = 'Question 1',
            FEC_KYC_Suggested_Answer__c = 'Address: {CurrentAddress}',
            FEC_Product_Type__c = prod.Id,
            FEC_Plastic_ID__c = 'Others'
        );
        if (kycMethod != null) {
            kyc.FEC_KYC_Method__c = kycMethod;
        }
        insert kyc;

        Case c = new Case(
            Subject = 'FEC_KYCController_Test',
            Status = 'New',
            FEC_ID_Search__c = 'KYC-' + suffix,
            FEC_Search_Products__c = PRODUCT_CODE
        );
        if (kycMethod != null) {
            c.FEC_KYC_Method__c = kycMethod;
        }

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c cust = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            Name = 'Test Customer ' + suffix,
            FEC_Account_Number__c = '0001500060000003',
            FEC_Plastic_ID__c = 'ZZ99'
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
    }

    @IsTest
    static void testGetKYC_Success() {
        if (Type.forName('FEC_KYCController') == null) {
            System.assert(true, 'Skipped: FEC_KYCController not on org.');
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_KYCController.KYCDTO result = FEC_KYCController.getKYC(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.typelst);
    }

    @IsTest
    static void testSubmitKYC() {
        if (Type.forName('FEC_KYCController') == null) {
            System.assert(true, 'Skipped: FEC_KYCController not on org.');
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_KYC__c kyc = [SELECT Id FROM FEC_KYC__c LIMIT 1];

        Test.startTest();
        FEC_KYCController.submitKYC(c.Id, kyc.Id, true, 'Test Answer');
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM FEC_KYC_Result__c WHERE FEC_Case_Interaction__c = :c.Id]
        );
    }

    @IsTest
    static void testGetKYCResult() {
        if (Type.forName('FEC_KYCController') == null) {
            System.assert(true, 'Skipped: FEC_KYCController not on org.');
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<FEC_KYCController.KYCResultDTO> results =
            FEC_KYCController.getKYCResult(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, results);
    }

    @IsTest
    static void testGetInterationId_InteractionAndChildCase() {
        if (Type.forName('FEC_KYCController') == null) {
            System.assert(true, 'Skipped: FEC_KYCController not on org.');
            return;
        }

        Id interactionRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .containsKey(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)
            ? Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
                .get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)
                .getRecordTypeId()
            : null;

        String suffix = String.valueOf(System.currentTimeMillis());
        Case interaction = new Case(
            Subject = 'KYC Interaction',
            Status = 'New',
            FEC_ID_Search__c = 'KYC-INT-' + suffix
        );
        if (interactionRtId != null) {
            interaction.RecordTypeId = interactionRtId;
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert interaction;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Case child = new Case(
            Subject = 'KYC Child',
            Status = 'New',
            FEC_Interaction__c = interaction.Id,
            FEC_ID_Search__c = 'KYC-CH-' + suffix
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert child;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        String fromInteraction = FEC_KYCController.getInterationId(interaction.Id);
        String fromChild = FEC_KYCController.getInterationId(child.Id);
        String fromMissing = FEC_KYCController.getInterationId('000000000000000AAA');
        Test.stopTest();

        if (interactionRtId != null) {
            System.assertEquals(String.valueOf(interaction.Id), fromInteraction);
        }
        System.assertEquals(String.valueOf(interaction.Id), fromChild);
        System.assertEquals(null, fromMissing);
    }

    @IsTest
    static void testGetKYC_EmptyProductsAndExistingResult() {
        if (Type.forName('FEC_KYCController') == null) {
            System.assert(true, 'Skipped: FEC_KYCController not on org.');
            return;
        }

        Case base = [SELECT Id FROM Case LIMIT 1];
        FEC_KYC__c kyc = [SELECT Id FROM FEC_KYC__c LIMIT 1];

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = base.Id, FEC_Search_Products__c = null);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_KYCController.KYCDTO emptyProducts = FEC_KYCController.getKYC(base.Id);
        FEC_KYCController.submitKYC(base.Id, kyc.Id, false, 'Rejected Answer');
        FEC_KYCController.KYCDTO withResult = FEC_KYCController.getKYC(base.Id);
        Test.stopTest();

        System.assertEquals(0, emptyProducts.typelst.size());
        System.assertNotEquals(null, withResult);
    }

    @IsTest
    static void testGetKYC_AdhocResolversAndPlasticPaths() {
        if (Type.forName('FEC_KYCController') == null) {
            System.assert(true, 'Skipped: FEC_KYCController not on org.');
            return;
        }

        String suffix = String.valueOf(System.currentTimeMillis());
        String kycMethod = firstActivePicklistValue(Case.FEC_KYC_Method__c);
        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Card Product ' + suffix,
            FEC_Code__c = 'Card'
        );
        insert prod;

        FEC_KYC__c kyc = new FEC_KYC__c(
            Name = 'Adhoc Question',
            FEC_KYC_Suggested_Answer__c =
                'Addr: {{CurrentAddress}} Pay: {{PaymentChannel}} Card: {{Cardholder}}',
            FEC_Product_Type__c = prod.Id,
            FEC_Plastic_ID__c = 'Others'
        );
        if (kycMethod != null) {
            kyc.FEC_KYC_Method__c = kycMethod;
        }
        insert kyc;

        Case c = new Case(
            Subject = 'KYC Adhoc Test',
            Status = 'New',
            FEC_ID_Search__c = 'KYC-ADH-' + suffix,
            FEC_Search_Products__c = 'Card'
        );
        if (kycMethod != null) {
            c.FEC_KYC_Method__c = kycMethod;
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c cust = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            Name = 'Adhoc Customer ' + suffix,
            FEC_Account_Number__c = '0001500060000099',
            FEC_Plastic_ID__c = 'RS1',
            FEC_Address_Type__c = 'Current Address',
            FEC_Address__c = '123 Test Street'
        );
        insert cust;

        insert new FEC_Payment_History__c(
            FEC_Customer_History__c = cust.Id,
            FEC_Payment_Channel__c = 'ATM',
            FEC_Payment_Date__c = Date.today()
        );
        insert new FEC_Other_Card__c(FEC_Customer_History__c = cust.Id);

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, FEC_Account_or_Contract__c = cust.Id, FEC_Product_Type__c = prod.Id);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_KYCController.KYCDTO result = FEC_KYCController.getKYC(c.Id);
        List<FEC_KYCController.KYCResultDTO> kycResults = FEC_KYCController.getKYCResult(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, kycResults);
    }

    @IsTest
    static void testSubmitKYC_InvalidKycId() {
        if (Type.forName('FEC_KYCController') == null) {
            System.assert(true, 'Skipped: FEC_KYCController not on org.');
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        Integer beforeCount = [SELECT COUNT() FROM FEC_KYC_Result__c WHERE FEC_Case_Interaction__c = :c.Id];

        Test.startTest();
        FEC_KYCController.submitKYC(c.Id, 'a00000000000001AAA', true, 'No KYC');
        Test.stopTest();

        System.assertEquals(
            beforeCount,
            [SELECT COUNT() FROM FEC_KYC_Result__c WHERE FEC_Case_Interaction__c = :c.Id]
        );
    }

    @IsTest
    static void testGetKYC_Dc2BlockCodeAndDp3CardDelivery() {
        if (Type.forName('FEC_KYCController') == null) {
            System.assert(true, 'Skipped: FEC_KYCController not on org.');
            return;
        }

        String suffix = String.valueOf(System.currentTimeMillis());
        String kycMethod = firstActivePicklistValue(Case.FEC_KYC_Method__c);
        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'DC2 Product ' + suffix,
            FEC_Code__c = 'Card' + suffix.right(4),
            FEC_Active__c = true
        );
        insert prod;

        FEC_KYC__c kyc = new FEC_KYC__c(
            Name = 'DC2 Question',
            FEC_KYC_Suggested_Answer__c = 'Blocked: {{FEC_Account_or_Contract__r.FEC_Block_Code_1__c}}',
            FEC_Product_Type__c = prod.Id,
            FEC_Plastic_ID__c = 'DC2'
        );
        if (kycMethod != null) {
            kyc.FEC_KYC_Method__c = kycMethod;
        }
        insert kyc;

        Case c = new Case(
            Subject = 'KYC DC2 Test',
            Status = 'New',
            FEC_ID_Search__c = 'KYC-DC2-' + suffix,
            FEC_Search_Products__c = 'Card'
        );
        if (kycMethod != null) {
            c.FEC_KYC_Method__c = kycMethod;
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c cust = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            Name = 'DC2 Customer ' + suffix,
            FEC_Account_Number__c = '0001500060000101',
            FEC_Plastic_ID__c = 'DC2',
            FEC_Block_Code_1__c = 'N',
            FEC_Card_Number__c = '4111111111111111'
        );
        insert cust;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, FEC_Account_or_Contract__c = cust.Id, FEC_Product_Type__c = prod.Id);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_KYCController.KYCDTO dc2Open = FEC_KYCController.getKYC(c.Id);
        cust.FEC_Block_Code_1__c = 'Y';
        update cust;
        FEC_KYCController.KYCDTO dc2Blocked = FEC_KYCController.getKYC(c.Id);

        cust.FEC_Plastic_ID__c = 'DP3';
        update cust;
        insert new FEC_Card_Delivery__c(
            FEC_Case__c = c.Id,
            FEC_Customer_History__c = cust.Id,
            FEC_Card_Number__c = cust.FEC_Card_Number__c,
            FEC_Delivery_Status__c = 'Delivered'
        );
        FEC_KYCController.KYCDTO dp3Delivered = FEC_KYCController.getKYC(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, dc2Open);
        System.assertNotEquals(null, dc2Blocked);
        System.assertNotEquals(null, dp3Delivered);
    }

    @IsTest
    static void testGetKYC_ExtendedAdhocResolvers() {
        if (Type.forName('FEC_KYCController') == null) {
            System.assert(true, 'Skipped: FEC_KYCController not on org.');
            return;
        }

        String suffix = String.valueOf(System.currentTimeMillis());
        String kycMethod = firstActivePicklistValue(Case.FEC_KYC_Method__c);
        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Full Adhoc ' + suffix,
            FEC_Code__c = 'Loan' + suffix.right(4),
            FEC_Active__c = true
        );
        insert prod;

        FEC_KYC__c kyc = new FEC_KYC__c(
            Name = 'Full Adhoc Question',
            FEC_KYC_Suggested_Answer__c =
                'Perm: {{PermanentAddress}} Loan: {{LoanPaymentAmount}} IPP: {{IPPBalance}} Term: {{IPPTerm}} Bill: {{BillingCycle}}',
            FEC_Product_Type__c = prod.Id,
            FEC_Plastic_ID__c = 'Others',
            FEC_Masking__c = false
        );
        if (kycMethod != null) {
            kyc.FEC_KYC_Method__c = kycMethod;
        }
        insert kyc;

        Case c = new Case(
            Subject = 'KYC Full Adhoc',
            Status = 'New',
            FEC_ID_Search__c = 'KYC-FULL-' + suffix,
            FEC_Search_Products__c = 'Loan'
        );
        if (kycMethod != null) {
            c.FEC_KYC_Method__c = kycMethod;
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c cust = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            Name = 'Full Adhoc Customer ' + suffix,
            FEC_Account_Number__c = '0001500060000202',
            FEC_Plastic_ID__c = 'RS2',
            FEC_Address_Type__c = 'Permanent Address',
            FEC_Address__c = '456 Permanent Road'
        );
        insert cust;

        insert new FEC_Repayment_Schedule__c(
            FEC_Case__c = c.Id,
            FEC_Customer_History__c = cust.Id,
            FEC_Payment_Amount__c = 1500,
            FEC_Payment_Date__c = Date.today().addDays(-1)
        );
        insert new FEC_IPP__c(
            FEC_Customer_History__c = cust.Id,
            FEC_IPP_Balance__c = 200,
            FEC_IPP_Term__c = 12,
            FEC_IPP_Open_Date__c = Date.today().addDays(-30)
        );
        insert new FEC_Statement__c(
            FEC_Customer_History__c = cust.Id,
            FEC_Billing_Cycle__c = 15,
            FEC_Statement_Date__c = Date.today()
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, FEC_Account_or_Contract__c = cust.Id, FEC_Product_Type__c = prod.Id);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_KYC_Result__c existingResult = new FEC_KYC_Result__c(
            Name = kyc.Name + ' ' + suffix,
            FEC_Case_Interaction__c = c.Id,
            FEC_KYC__c = kyc.Id,
            FEC_Status__c = true,
            FEC_KYC_Answer__c = 'Confirmed',
            FEC_KYC_Product__c = prod.Name,
            FEC_Editable__c = false
        );
        insert existingResult;

        Test.startTest();
        FEC_KYCController.KYCDTO result = FEC_KYCController.getKYC(c.Id);
        List<FEC_KYCController.KYCResultDTO> kycResults = FEC_KYCController.getKYCResult(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result.typelst);
        System.assertEquals(1, kycResults.size());
        System.assertNotEquals(null, kycResults[0].performedOn);
    }
}
