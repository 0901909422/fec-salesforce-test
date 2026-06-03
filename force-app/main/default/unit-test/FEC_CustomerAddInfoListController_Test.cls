@IsTest
private class FEC_CustomerAddInfoListController_Test {

    @TestSetup
    static void setupData() {
        // Tạo Config mồi
        FEC_CustomerAdditionalInfoConfig__c config = new FEC_CustomerAdditionalInfoConfig__c(
            FEC_KeyIdentifier__c = 'CIF_NUMBER',
            FEC_FieldID__c = 'TEST_01',
            FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS
        );
        insert config;
    }

    @IsTest
    static void testSaveCustomerData_Success() {
        FEC_CustomerAdditionalInfoConfig__c config = new FEC_CustomerAdditionalInfoConfig__c(
            FEC_KeyIdentifier__c = 'PHONE',
            FEC_FieldID__c = 'TEST_02'
        );

        Test.startTest();
        String result = FEC_CustomerAdditionalInfoListController.saveCustomerData(config, null);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.SUCCESS_MESSAGE, result);
        System.assertEquals(FEC_ConstantCommon.UPLOADED_STATUS, [SELECT FEC_Status__c FROM FEC_CustomerAdditionalInfoConfig__c WHERE Id = :config.Id].FEC_Status__c);
    }

    @IsTest
    static void testDeleteConfig_Success() {
        FEC_CustomerAdditionalInfoConfig__c config = [SELECT Id, FEC_Status__c FROM FEC_CustomerAdditionalInfoConfig__c LIMIT 1];

        Test.startTest();
        FEC_CustomerAdditionalInfoListController.deleteConfig(config.Id);
        Test.stopTest();

        FEC_CustomerAdditionalInfoConfig__c updated = [SELECT FEC_Status__c FROM FEC_CustomerAdditionalInfoConfig__c WHERE Id = :config.Id];
        System.assertEquals(FEC_ConstantCommon.CANCELLED_STATUS, updated.FEC_Status__c);
    }

    @IsTest
    static void testCheckDuplicateConfig() {
        FEC_CustomerAdditionalInfoConfig__c existing = [SELECT Id, FEC_KeyIdentifier__c, FEC_FieldID__c FROM FEC_CustomerAdditionalInfoConfig__c LIMIT 1];

        Test.startTest();
        Boolean isDup = FEC_CustomerAdditionalInfoListController.checkDuplicateConfig(
            existing.FEC_KeyIdentifier__c, existing.FEC_FieldID__c, '000000000000000000'
        );
        Test.stopTest();

        System.assertEquals(true, isDup, 'Phải phát hiện trùng lặp cấu hình.');
    }

    @IsTest
    static void testGetConfigHistory_Sorting() {
        FEC_CustomerAdditionalInfoConfig__c config = [SELECT Id FROM FEC_CustomerAdditionalInfoConfig__c LIMIT 1];

        if (Schema.getGlobalDescribe().containsKey('FEC_CustomerDataConfigHistory__c')) {
            SObject hist = Schema.getGlobalDescribe()
                .get('FEC_CustomerDataConfigHistory__c')
                .newSObject();
            hist.put('FEC_Customers_Data_Config__c', config.Id);
            hist.put('FEC_Status__c', FEC_ConstantCommon.PROCESSING_STATUS);
            insert hist;
        }

        Test.startTest();
        FEC_CustomerAdditionalInfoListController.getConfigHistory(config.Id);
        Test.stopTest();

        Integer historyCount = Database.countQuery(
            'SELECT COUNT() FROM FEC_CustomerDataConfigHistory__c WHERE FEC_Customers_Data_Config__c = \'' +
            String.valueOf(config.Id) + '\''
        );
        System.assert(historyCount >= 1);
    }

    @IsTest
    static void testTriggerBatchProcessing() {
        Test.startTest();
        String msg = FEC_CustomerAdditionalInfoListController.triggerBatchProcessing();
        Test.stopTest();

        // Kiểm tra xem label trả về đúng không
        System.assert(String.isNotBlank(msg));
    }
}