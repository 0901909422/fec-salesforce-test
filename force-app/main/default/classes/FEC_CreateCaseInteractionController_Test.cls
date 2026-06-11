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

    @IsTest
    static void testCreateInteractionCase_Success() {
        Test.startTest();
        Id caseId = FEC_CreateCaseInteractionController.createInteractionCase(
            'Listview Customer',
            'NAT-001'
        );
        Test.stopTest();

        Case created = [
            SELECT FEC_Customer_Name__c, FEC_National_ID_Passport_ID__c, RecordType.DeveloperName
            FROM Case
            WHERE Id = :caseId
        ];
        System.assertEquals('Listview Customer', created.FEC_Customer_Name__c);
        System.assertEquals('NAT-001', created.FEC_National_ID_Passport_ID__c);
        System.assertEquals(
            FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME,
            created.RecordType.DeveloperName
        );
    }

    @IsTest
    static void testCreateHistoryNonExistingCustomer_Success() {
        Case interaction = [
            SELECT Id FROM Case
            WHERE RecordType.DeveloperName = :FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME
            LIMIT 1
        ];

        Test.startTest();
        FEC_Customer_History__c hist = FEC_CreateCaseInteractionController.createHistoryNonExistingCustomer(
            interaction.Id,
            'Direct History',
            'DOC-999'
        );
        Test.stopTest();

        System.assertNotEquals(null, hist.Id);
        System.assertEquals('Direct History', hist.FEC_Customer_Name__c);
    }

    @IsTest
    static void testCreateCustomerCaseFromCase_PhoneRequiredForManualInbound() {
        String suffix = String.valueOf(System.currentTimeMillis());
        Id interactionRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)
            .getRecordTypeId();

        Case manualInteraction;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            manualInteraction = new Case(
                RecordTypeId = interactionRtId,
                Subject = 'Manual Inbound',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_Is_Manual__c = true,
                FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
                FEC_ID_Search__c = 'CCI-MAN-' + suffix
            );
            insert manualInteraction;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_CreateCaseInteractionController.createCustomerCaseFromCase(manualInteraction.Id);
        } catch (AuraHandledException e) {
            threw = true;
            System.assert(
                e.getMessage().contains(System.Label.FEC_PHONE_IS_REQUIRED_MSG)
                    || e.getMessage().contains('Script-thrown'),
                'Expected phone required message.'
            );
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testCreateCustomerCaseFromCaseNonExistingCustomer_Validations() {
        Case interaction = [
            SELECT Id FROM Case
            WHERE RecordType.DeveloperName = :FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME
            LIMIT 1
        ];

        Boolean nullCaseThrew = false;
        Test.startTest();
        try {
            FEC_CreateCaseInteractionController.createCustomerCaseFromCaseNonExistingCustomer(
                null,
                'X',
                'Y',
                'false'
            );
        } catch (AuraHandledException e) {
            nullCaseThrew = true;
        }

        Id newCaseId = FEC_CreateCaseInteractionController.createCustomerCaseFromCaseNonExistingCustomer(
            interaction.Id,
            'No Search Flag',
            'ID-555',
            'false'
        );
        Test.stopTest();

        System.assertEquals(true, nullCaseThrew);
        Case newCase = [
            SELECT FEC_Is_Created_From_Search__c
            FROM Case
            WHERE Id = :newCaseId
        ];
        System.assertNotEquals(true, newCase.FEC_Is_Created_From_Search__c);
    }

    @IsTest
    static void testCreateCustomerCaseFromCaseNonExistingCustomer_PhoneRequired() {
        String suffix = String.valueOf(System.currentTimeMillis());
        Id interactionRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)
            .getRecordTypeId();

        Case manualInteraction;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            manualInteraction = new Case(
                RecordTypeId = interactionRtId,
                Subject = 'Manual Outbound',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_Is_Manual__c = true,
                FEC_Channel__c = 'Outbound',
                FEC_ID_Search__c = 'CCI-OUT-' + suffix
            );
            insert manualInteraction;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_CreateCaseInteractionController.createCustomerCaseFromCaseNonExistingCustomer(
                manualInteraction.Id,
                'X',
                'Y',
                'false'
            );
        } catch (AuraHandledException e) {
            threw = true;
            System.assert(
                e.getMessage().contains(System.Label.FEC_PHONE_IS_REQUIRED_MSG)
                    || e.getMessage().contains('Script-thrown'),
                'Expected phone required message.'
            );
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testCreateCustomerCaseFromCaseNonExistingCustomer_InternalRecordType() {
        Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        if (!rtMap.containsKey(FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME)) {
            return;
        }

        String suffix = String.valueOf(System.currentTimeMillis());
        Id internalRtId = rtMap.get(FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME).getRecordTypeId();
        List<FEC_Product_Type__c> productTypes = [
            SELECT Id
            FROM FEC_Product_Type__c
            WHERE FEC_Code__c = :FEC_ConstantCommon.CASE_INTERNAL_REQUEST
            LIMIT 1
        ];

        Case internalInteraction;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            internalInteraction = new Case(
                RecordTypeId = internalRtId,
                Subject = 'Internal Interaction',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
                FEC_Phone_Number__c = '0909999888',
                FEC_Customer_Type__c = FEC_ConstantCommon.CASE_ALL_REQUEST,
                FEC_ID_Search__c = 'INT-' + suffix
            );
            if (!productTypes.isEmpty()) {
                internalInteraction.FEC_Product_Type__c = productTypes[0].Id;
            }
            insert internalInteraction;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        Id newCaseId = FEC_CreateCaseInteractionController.createCustomerCaseFromCaseNonExistingCustomer(
            internalInteraction.Id,
            'Internal Non Existing',
            'INT-ID-1',
            'true'
        );
        Test.stopTest();

        Case newCase = [SELECT RecordTypeId FROM Case WHERE Id = :newCaseId];
        System.assertEquals(internalRtId, newCase.RecordTypeId);
    }
}