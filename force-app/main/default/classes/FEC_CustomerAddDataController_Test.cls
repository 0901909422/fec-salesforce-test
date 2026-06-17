@IsTest
private class FEC_CustomerAddDataController_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        FEC_CustomerAdditionalInfoConfig__c cfg = new FEC_CustomerAdditionalInfoConfig__c(
            FEC_KeyIdentifier__c = 'CIF_NUMBER',
            FEC_FieldID__c = 'TestField',
            FEC_Status__c = FEC_ConstantCommon.PROCESSED_STATUS,
            FEC_IsActive__c = true,
            // 05/06/2026 18:00 linhdev - StartDate = today VN (inclusive >=)
            FEC_StartDate__c = FEC_CustomerAdditionalDataController.getTodayVietnam(),
            FEC_EndDate__c = FEC_CustomerAdditionalDataController.getTodayVietnam().addDays(1),
            FEC_FieldName__c = 'Test Field'
        );
        insert cfg;

        insert new FEC_CustomerAdditionalInfo__c(
            FEC_IsActive__c = true,
            FEC_KeyIdentifier__c = 'CIF_NUMBER',
            FEC_KeyIDValue__c = 'CIF123',
            FEC_FieldID__c = 'TestField',
            FEC_Config__c = cfg.Id,
            FEC_FieldValue__c = 'ValueABC',
            FEC_CompositeKey__c = 'CIF123!CIF_NUMBER!TestField'
        );

        Id interactionRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)
            .getRecordTypeId();

        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                RecordTypeId = interactionRtId,
                Subject = 'Additional Data Test',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
                FEC_ID_Search__c = 'CAD-' + suffix
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_CIF_Number__c = 'CIF123',
            FEC_National_ID_Passport_ID__c = 'ID999'
        );
        insert hist;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, FEC_Account_or_Contract__c = hist.Id);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testGetAdditionalDataRows_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<FEC_CustomerAdditionalDataController.RowDTO> rows = 
            FEC_CustomerAdditionalDataController.getAdditionalDataRows(c.Id);
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Phải lấy được 1 dòng dữ liệu.');
        System.assertEquals('ValueABC', rows[0].fieldValue);
        System.assertEquals('Test Field', rows[0].fieldLabel);
    }

    // 05/06/2026 18:00 linhdev - StartDate = EndDate = today VN phải hiển thị
    @IsTest
    static void testGetAdditionalDataRows_StartDateEqualsTodayVietnam() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_CustomerAdditionalInfoConfig__c cfg = [
            SELECT Id FROM FEC_CustomerAdditionalInfoConfig__c LIMIT 1
        ];
        Date todayVn = FEC_CustomerAdditionalDataController.getTodayVietnam();
        cfg.FEC_StartDate__c = todayVn;
        cfg.FEC_EndDate__c = todayVn;
        update cfg;

        Test.startTest();
        List<FEC_CustomerAdditionalDataController.RowDTO> rows =
            FEC_CustomerAdditionalDataController.getAdditionalDataRows(c.Id);
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'StartDate = today VN phải hiển thị dữ liệu.');
    }

    @IsTest
    static void testGetAdditionalDataRows_DateMismatch() {
        // Test logic CreatedDate Case < Row CreatedDate
        FEC_CustomerAdditionalInfo__c info = [SELECT Id, CreatedDate FROM FEC_CustomerAdditionalInfo__c LIMIT 1];
        Case c = [SELECT Id, CreatedDate FROM Case LIMIT 1];
        
        // Giả lập Case được tạo trước cả row thông tin bổ sung
        Test.setCreatedDate(c.Id, info.CreatedDate.addDays(-5));

        Test.startTest();
        List<FEC_CustomerAdditionalDataController.RowDTO> rows = 
            FEC_CustomerAdditionalDataController.getAdditionalDataRows(c.Id);
        Test.stopTest();

        System.assertEquals(0, rows.size(), 'Case tạo trước thông tin bổ sung thì không nên trả về dữ liệu.');
    }

    @IsTest
    static void testGetAdditionalDataRows_NoAccountOrContract() {
        FEC_CaseTriggerHandler.isExecuting = true;
        Case otherCase;
        try {
            otherCase = new Case(
                Subject = 'Other',
                FEC_ID_Search__c = 'CAD-OTH-' + String.valueOf(System.currentTimeMillis())
            );
            insert otherCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        List<FEC_CustomerAdditionalDataController.RowDTO> rows = 
            FEC_CustomerAdditionalDataController.getAdditionalDataRows(otherCase.Id);
        Test.stopTest();

        System.assertEquals(0, rows.size(), 'Case không có Account/Contract thì không trả dữ liệu.');
    }

    @IsTest
    static void testGetAdditionalDataRows_InternalRecordType() {
        Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        if (!rtMap.containsKey(FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME)) {
            return;
        }

        Case c = [
            SELECT Id, FEC_Account_or_Contract__c
            FROM Case
            LIMIT 1
        ];
        Id internalRtId = rtMap.get(FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME).getRecordTypeId();

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                RecordTypeId = internalRtId
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        List<FEC_CustomerAdditionalDataController.RowDTO> rows =
            FEC_CustomerAdditionalDataController.getAdditionalDataRows(c.Id);
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Internal Case với Account/Contract phải hiển thị Additional Data.');
    }

    @IsTest
    static void testGetAdditionalDataRows_CustomerRecordType() {
        Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        if (!rtMap.containsKey(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME)) {
            return;
        }

        Case c = [
            SELECT Id, FEC_Account_or_Contract__c
            FROM Case
            LIMIT 1
        ];
        Id customerRtId = rtMap.get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME).getRecordTypeId();

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                RecordTypeId = customerRtId
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        List<FEC_CustomerAdditionalDataController.RowDTO> rows =
            FEC_CustomerAdditionalDataController.getAdditionalDataRows(c.Id);
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Customer Case với Account/Contract phải hiển thị Additional Data.');
    }

    @IsTest
    static void testGetAdditionalDataRows_SearchRecordType() {
        Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        if (!rtMap.containsKey(FEC_ConstantCommon.CASE_SEARCH_RECORD_TYPE_DEV_NAME)) {
            return;
        }

        Case c = [
            SELECT Id, FEC_Account_or_Contract__c
            FROM Case
            LIMIT 1
        ];
        Id searchRtId = rtMap.get(FEC_ConstantCommon.CASE_SEARCH_RECORD_TYPE_DEV_NAME).getRecordTypeId();

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                RecordTypeId = searchRtId
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        List<FEC_CustomerAdditionalDataController.RowDTO> rows =
            FEC_CustomerAdditionalDataController.getAdditionalDataRows(c.Id);
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Search Interaction với Account/Contract phải hiển thị Additional Data.');
    }
}