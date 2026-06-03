@IsTest
private class FEC_CreateCaseInteractionController_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());
        Id interactionRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)
            .getRecordTypeId();

        Case interaction;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            interaction = new Case(
                RecordTypeId = interactionRtId,
                Subject = 'Interaction',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
                FEC_Phone_Number__c = '0901234567',
                FEC_ID_Search__c = 'CCI-' + suffix
            );
            insert interaction;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = interaction.Id,
            FEC_Customer_Name__c = 'Test Customer',
            FEC_Primary_Phone__c = '0901234567'
        );
        insert hist;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = interaction.Id,
                FEC_Account_or_Contract__c = hist.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = 'CC',
            FEC_Active__c = true
        );
        insert prod;

        FEC_KYC__c kycMaster = new FEC_KYC__c(
            Name = 'Test KYC',
            FEC_Product_Type__c = prod.Id
        );
        insert kycMaster;

        insert new FEC_KYC_Result__c(
            Name = 'Test KYC Result',
            FEC_Case_Interaction__c = interaction.Id,
            FEC_KYC__c = kycMaster.Id,
            FEC_Editable__c = true
        );
    }

    @IsTest
    static void testCreateCustomerCaseFromCase_Success() {
        Case interation = [
            SELECT Id FROM Case
            WHERE RecordType.DeveloperName = :FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME
            LIMIT 1
        ];

        Test.startTest();
        Id newCaseId = FEC_CreateCaseInteractionController.createCustomerCaseFromCase(interation.Id);
        Test.stopTest();

        // Kiểm tra case mới được tạo
        Case newCase = [SELECT Id, FEC_Interaction__c, RecordTypeId FROM Case WHERE Id = :newCaseId];
        System.assertEquals(interation.Id, newCase.FEC_Interaction__c);

        // Kiểm tra KYC bị khóa
        FEC_KYC_Result__c kyc = [SELECT FEC_Editable__c FROM FEC_KYC_Result__c WHERE FEC_Case_Interaction__c = :interation.Id];
        System.assertEquals(false, kyc.FEC_Editable__c, 'KYC Result phải bị khóa (editable = false).');
    }

    @IsTest
    static void testCreateCustomerCaseFromCaseNonExistingCustomer_Success() {
        Case interation = [
            SELECT Id FROM Case
            WHERE RecordType.DeveloperName = :FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME
            LIMIT 1
        ];

        Test.startTest();
        Id newCaseId = FEC_CreateCaseInteractionController.createCustomerCaseFromCaseNonExistingCustomer(
            interation.Id, 'New Customer', '123456789', 'true'
        );
        Test.stopTest();

        // Kiểm tra case mới
        Case newCase = [SELECT Id, FEC_Customer_Name__c, FEC_Is_Created_From_Search__c FROM Case WHERE Id = :newCaseId];
        System.assertEquals('New Customer', newCase.FEC_Customer_Name__c);
        System.assertEquals(true, newCase.FEC_Is_Created_From_Search__c);

        // Kiểm tra History được tạo
        FEC_Customer_History__c hist = [SELECT Id FROM FEC_Customer_History__c WHERE FEC_Customer_Name__c = 'New Customer'];
        System.assertNotEquals(null, hist);
    }

    @IsTest
    static void testCreateHistoryNonExistingCustomer_Exception() {
        Test.startTest();
        try {
            // Gây lỗi bằng cách truyền tham số thiếu (nếu cần bắt buộc) hoặc để trống
            FEC_CreateCaseInteractionController.createHistoryNonExistingCustomer(null, null, null);
            System.assert(false, 'Phải ném ra lỗi nếu thông tin không hợp lệ.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}