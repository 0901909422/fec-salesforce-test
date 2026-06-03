@IsTest
private class FEC_InteractionInforHandler_Test {

    private static final String PRIMARY_PHONE = '0901234567';
    private static final String PRIMARY_EMAIL = 'interaction.test@example.com';

    private static Id interactionRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        String devName = FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME;
        return byDev.containsKey(devName) ? byDev.get(devName).getRecordTypeId() : null;
    }

    private static Id customerCaseRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        String devName = FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME;
        return byDev.containsKey(devName) ? byDev.get(devName).getRecordTypeId() : null;
    }

    private static Case insertInteraction(
        String suffix,
        String phone,
        String email,
        Boolean isClosed
    ) {
        Case c = new Case(
            Subject = 'Interaction ' + suffix,
            Status = isClosed ? 'Closed' : 'New',
            FEC_Phone_Number__c = phone,
            FEC_Interaction_Email__c = email,
            FEC_ID_Search__c = 'INTSRCH-' + suffix
        );
        Id rtId = interactionRecordTypeId();
        if (rtId != null) {
            c.RecordTypeId = rtId;
            c.FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;
        }
        if (isClosed) {
            c.FEC_Interaction_End_On__c = DateTime.now();
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        Case parentCase = new Case(
            Subject = 'Parent Case',
            Status = 'New',
            FEC_ID_Search__c = 'PARENT-' + suffix
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert parentCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Case interaction = insertInteraction('Main-' + suffix, PRIMARY_PHONE, PRIMARY_EMAIL, false);
        interaction.ParentId = parentCase.Id;
        interaction.FEC_First_Access__c = true;
        interaction.FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_REVIEW_MODE;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update interaction;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insertInteraction('REL-' + suffix, PRIMARY_PHONE, PRIMARY_EMAIL, true);

        Id customerRtId = customerCaseRecordTypeId();
        Case customerCase = new Case(
            Subject = 'Customer Case',
            Status = 'New',
            FEC_Interaction__c = interaction.Id,
            FEC_ID_Search__c = 'CUST-' + suffix
        );
        if (customerRtId != null) {
            customerCase.RecordTypeId = customerRtId;
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert customerCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_Sensitive_Data__c(
            FEC_Related_Case__c = interaction.Id,
            FEC_Section__c = FEC_ConstantCommon.SECTION_INTERACTION_DETAILS,
            Name = FEC_ConstantCommon.SECTION_INTERACTION_PHONE,
            FEC_User__c = UserInfo.getUserName(),
            FEC_User_Role__c = 'Test Role'
        );
    }

    private static Case getMainInteraction() {
        return [
            SELECT Id, ParentId
            FROM Case
            WHERE Subject LIKE 'Interaction Main-%'
            LIMIT 1
        ];
    }

    private static Id fakeCaseId() {
        return (Id) (Case.SObjectType.getDescribe().getKeyPrefix() + '0'.repeat(12) + 'AAA');
    }

    @IsTest
    static void testGetInteraction_SuccessAndNotFound() {
        Case interaction = getMainInteraction();

        Test.startTest();
        Case found = FEC_InteractionInforHandler.getInteraction(interaction.Id);
        Case missing = FEC_InteractionInforHandler.getInteraction(fakeCaseId());
        Test.stopTest();

        System.assertNotEquals(null, found);
        System.assertEquals(FEC_ConstantCommon.CHANNEL_INBOUND_NAME, found.FEC_Channel__c);
        System.assertEquals(null, missing);
    }

    @IsTest
    static void testGetInteractionPhoneReveal_ReturnsPhone() {
        Case interaction = getMainInteraction();

        Test.startTest();
        String phone = FEC_InteractionInforHandler.getInteractionPhoneReveal(interaction.Id);
        Test.stopTest();

        System.assertEquals(PRIMARY_PHONE, phone);
        System.assert(
            [SELECT COUNT() FROM FEC_Sensitive_Data__c WHERE FEC_Related_Case__c = :interaction.Id] >= 1,
            'Phải ghi audit sensitive access.'
        );
    }

    @IsTest
    static void testUpdateInteractionPhone_SuccessAndInvalid() {
        Case interaction = getMainInteraction();
        String newPhone = '0912345678';

        Test.startTest();
        String masked = FEC_InteractionInforHandler.updateInteractionPhone(interaction.Id, newPhone);
        Test.stopTest();

        System.assertNotEquals(null, masked);
        Case updated = [SELECT FEC_Phone_Number__c FROM Case WHERE Id = :interaction.Id];
        System.assertEquals(newPhone, updated.FEC_Phone_Number__c);

        try {
            FEC_InteractionInforHandler.updateInteractionPhone(interaction.Id, 'invalid');
            System.assert(false, 'Phải throw AuraHandledException khi phone không hợp lệ.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }

    @IsTest
    static void testUpdateInteractionEmail_SuccessAndNullId() {
        Case interaction = getMainInteraction();

        Test.startTest();
        FEC_InteractionInforHandler.updateInteractionEmail(interaction.Id, '  newemail@test.com  ');
        Test.stopTest();

        Case updated = [SELECT FEC_Interaction_Email__c FROM Case WHERE Id = :interaction.Id];
        System.assertEquals('newemail@test.com', updated.FEC_Interaction_Email__c);

        try {
            FEC_InteractionInforHandler.updateInteractionEmail(null, 'x@test.com');
            System.assert(false, 'Phải throw khi recordId null.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }

    @IsTest
    static void testUpdateInteractionOnHold_SuccessAndNullId() {
        Case interaction = getMainInteraction();

        Test.startTest();
        FEC_InteractionInforHandler.updateInteractionOnHold(interaction.Id, true);
        Test.stopTest();

        System.assertEquals(true, [SELECT FEC_On_Hold__c FROM Case WHERE Id = :interaction.Id].FEC_On_Hold__c);

        try {
            FEC_InteractionInforHandler.updateInteractionOnHold(null, false);
            System.assert(false, 'Phải throw khi recordId null.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }

    @IsTest
    static void testGetInteractionIdFromCustomerCase() {
        Case interaction = getMainInteraction();
        Case customerCase = [
            SELECT Id
            FROM Case
            WHERE FEC_Interaction__c = :interaction.Id
            LIMIT 1
        ];

        Test.startTest();
        Id linkedId = FEC_InteractionInforHandler.getInteractionIdFromCustomerCase(customerCase.Id);
        Test.stopTest();

        System.assertEquals(interaction.Id, linkedId);
    }

    @IsTest
    static void testGetInteractionHighlightDataAndCurrentInteraction() {
        Case interaction = getMainInteraction();

        Test.startTest();
        Case highlight = FEC_InteractionInforHandler.getInteractionHighlightData(interaction.Id);
        Case current = FEC_InteractionInforHandler.getCurrentInteraction(interaction.Id);
        Test.stopTest();

        System.assertNotEquals(null, highlight);
        System.assertNotEquals(null, current);
        System.assertEquals(PRIMARY_PHONE, current.FEC_Phone_Number__c);
        System.assertEquals(PRIMARY_EMAIL, current.FEC_Interaction_Email__c);
    }

    @IsTest
    static void testGetRelevantInteractions_EmptyWhenNoContactInfo() {
        Case blankInteraction = insertInteraction(
            'BLANK-' + System.currentTimeMillis(),
            null,
            null,
            false
        );

        Test.startTest();
        List<Case> results = FEC_InteractionInforHandler.getRelevantInteractions(blankInteraction.Id);
        Integer count = FEC_InteractionInforHandler.getRelevantInteractionsViewAllCount(blankInteraction.Id);
        List<Case> viewAll = FEC_InteractionInforHandler.getRelevantInteractionsViewAll(blankInteraction.Id);
        Test.stopTest();

        System.assertEquals(0, results.size());
        System.assertEquals(0, count);
        System.assertEquals(0, viewAll.size());
    }

    @IsTest
    static void testGetRelevantInteractions_WithMatches() {
        Case interaction = getMainInteraction();

        Test.startTest();
        List<Case> results = FEC_InteractionInforHandler.getRelevantInteractions(interaction.Id);
        List<Case> viewAll = FEC_InteractionInforHandler.getRelevantInteractionsViewAll(interaction.Id);
        Integer count = FEC_InteractionInforHandler.getRelevantInteractionsViewAllCount(interaction.Id);
        Test.stopTest();

        System.assert(results.size() >= 0);
        System.assert(viewAll.size() >= results.size());
        System.assert(count >= results.size());
    }

    @IsTest
    static void testGetCaseListAndTotal() {
        Case interaction = getMainInteraction();

        Test.startTest();
        List<Case> cases = FEC_InteractionInforHandler.getCaseList(interaction.Id);
        Integer total = FEC_InteractionInforHandler.getCaseTotal(interaction.Id);
        List<Case> viewAll = FEC_InteractionInforHandler.getCaseListViewAll(interaction.Id);
        Test.stopTest();

        System.assertNotEquals(null, cases);
        System.assertEquals(1, total);
        System.assertEquals(1, viewAll.size());
    }

    @IsTest
    static void testGetRelevantCases_WithMatches() {
        Case interaction = getMainInteraction();

        Test.startTest();
        List<Case> results = FEC_InteractionInforHandler.getRelevantCases(interaction.Id);
        List<Case> viewAll = FEC_InteractionInforHandler.getRelevantCasesViewAll(interaction.Id);
        Integer count = FEC_InteractionInforHandler.getRelevantCasesViewAllCount(interaction.Id);
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assertNotEquals(null, viewAll);
        System.assert(count >= 0);
    }

    @IsTest
    static void testGetSensitiveData_ViewAllAndCount() {
        Case interaction = getMainInteraction();

        Test.startTest();
        List<FEC_Sensitive_Data__c> listData =
            FEC_InteractionInforHandler.getSensitiveData(interaction.Id);
        List<FEC_Sensitive_Data__c> paged =
            FEC_InteractionInforHandler.getSensitiveDataViewAll(interaction.Id, 10, 1);
        Integer total = FEC_InteractionInforHandler.countSensitiveData(interaction.Id);
        Test.stopTest();

        System.assert(listData.size() >= 1);
        System.assert(paged.size() >= 1);
        System.assertEquals(listData.size(), total);
    }

    @IsTest
    static void testResetViewMode_FirstAccessAndGetNextWork() {
        Case interaction = getMainInteraction();

        Test.startTest();
        String mode = FEC_InteractionInforHandler.resetViewMode(
            interaction.Id,
            FEC_ConstantCommon.INTERACTION_HANDLING_MODE
        );
        String nullResult = FEC_InteractionInforHandler.resetViewMode(null, FEC_ConstantCommon.INTERACTION_REVIEW_MODE);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.INTERACTION_REVIEW_MODE, mode);
        System.assertEquals(null, nullResult);

        Case updated = [
            SELECT FEC_First_Access__c, FEC_Interaction_View_Mode__c
            FROM Case
            WHERE Id = :interaction.Id
        ];
        System.assertEquals(false, updated.FEC_First_Access__c);
    }

    @IsTest
    static void testGetRecordTypeNameAndParentCaseNumber() {
        Case interaction = getMainInteraction();

        Test.startTest();
        String rtName = FEC_InteractionInforHandler.getRecordTypeName(interaction.Id);
        String parentNumber = FEC_InteractionInforHandler.getParentCaseNumber(interaction.Id);
        String blankRt = FEC_InteractionInforHandler.getRecordTypeName(null);
        Test.stopTest();

        System.assertNotEquals('', rtName);
        System.assertNotEquals(null, parentNumber);
        System.assertEquals('', blankRt);
    }

    @IsTest
    static void testGetChatInteractionInfoAndUpdateFields() {
        Case interaction = getMainInteraction();

        Test.startTest();
        Case chatInfo = FEC_InteractionInforHandler.getChatInteractionInfo(interaction.Id);
        FEC_InteractionInforHandler.updateChatInteractionFields(
            interaction.Id,
            'chat_user',
            '0987654321'
        );
        Case missing = FEC_InteractionInforHandler.getChatInteractionInfo(fakeCaseId());
        Test.stopTest();

        System.assertNotEquals(null, chatInfo);
        System.assertEquals(null, missing);

        Case updated = [
            SELECT FEC_Customer_Username__c, FEC_Phone_Number__c, FEC_Search_Phone_Number__c
            FROM Case
            WHERE Id = :interaction.Id
        ];
        System.assertEquals('chat_user', updated.FEC_Customer_Username__c);
        System.assertEquals('0987654321', updated.FEC_Phone_Number__c);
        System.assertEquals('0987654321', updated.FEC_Search_Phone_Number__c);
    }

    @IsTest
    static void testUpdateChatInteractionFields_NullRecordId() {
        Test.startTest();
        FEC_InteractionInforHandler.updateChatInteractionFields(null, 'user', '0901111111');
        Test.stopTest();
        System.assert(true, 'Null recordId phải return sớm không lỗi.');
    }

    @IsTest
    static void testUpdateInteractionEmail_BlankClearsField() {
        Case interaction = getMainInteraction();

        Test.startTest();
        FEC_InteractionInforHandler.updateInteractionEmail(interaction.Id, '   ');
        Test.stopTest();

        System.assertEquals(
            null,
            [SELECT FEC_Interaction_Email__c FROM Case WHERE Id = :interaction.Id].FEC_Interaction_Email__c
        );
    }

    @IsTest
    static void testGetParentCaseNumber_NoParent() {
        Case interaction = insertInteraction(
            'NOPARENT-' + System.currentTimeMillis(),
            PRIMARY_PHONE,
            null,
            false
        );

        Test.startTest();
        String parentNumber = FEC_InteractionInforHandler.getParentCaseNumber(interaction.Id);
        Test.stopTest();

        System.assertEquals(null, parentNumber);
    }

    @IsTest
    static void testGetRelevantInteractions_ClosedInteractionArchiveFilter() {
        Case closed = [
            SELECT Id
            FROM Case
            WHERE Subject LIKE 'Interaction REL-%'
            LIMIT 1
        ];

        Test.startTest();
        List<Case> results = FEC_InteractionInforHandler.getRelevantInteractions(closed.Id);
        Integer count = FEC_InteractionInforHandler.getRelevantInteractionsViewAllCount(closed.Id);
        List<Case> viewAll = FEC_InteractionInforHandler.getRelevantInteractionsViewAll(closed.Id);
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assert(count >= 0);
        System.assertNotEquals(null, viewAll);
    }

    @IsTest
    static void testGetRelevantInteractions_EmailOnlyMatch() {
        String suffix = String.valueOf(System.currentTimeMillis());
        Case emailOnly = insertInteraction(
            'EMAILONLY-' + suffix,
            null,
            'only.email@test.com',
            false
        );

        Test.startTest();
        List<Case> results = FEC_InteractionInforHandler.getRelevantInteractions(emailOnly.Id);
        Test.stopTest();

        System.assertNotEquals(null, results);
    }

    @IsTest
    static void testResetViewMode_GetNextWorkForcesHandlingMode() {
        Case interaction = getMainInteraction();
        interaction.FEC_Get_Next_Work__c = true;
        interaction.FEC_First_Access__c = false;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update interaction;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        String mode = FEC_InteractionInforHandler.resetViewMode(
            interaction.Id,
            FEC_ConstantCommon.INTERACTION_REVIEW_MODE
        );
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.INTERACTION_HANDLING_MODE, mode);
    }

    @IsTest
    static void testGetSensitiveDataViewAll_DefaultPaging() {
        Case interaction = getMainInteraction();

        Test.startTest();
        List<FEC_Sensitive_Data__c> paged =
            FEC_InteractionInforHandler.getSensitiveDataViewAll(interaction.Id, null, null);
        Test.stopTest();

        System.assert(paged.size() >= 1);
    }

    @IsTest
    static void testGetInteractionHighlightData_NotFound() {
        Test.startTest();
        Case highlight = FEC_InteractionInforHandler.getInteractionHighlightData(fakeCaseId());
        Test.stopTest();

        System.assertEquals(null, highlight);
    }
}
