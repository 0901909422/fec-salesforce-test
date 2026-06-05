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
            FEC_StartDate__c = Date.today().addDays(-1),
            FEC_EndDate__c = Date.today().addDays(1),
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
    static void testGetAdditionalDataRows_InvalidRecordType() {
        // Tạo case khác record type
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

        System.assertEquals(0, rows.size());
    }
}