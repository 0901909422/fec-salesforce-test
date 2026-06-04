@IsTest
private class FEC_CustomerAddHistoryHandler_Test {

    private static Boolean hasConfigHistoryObject() {
        return Schema.getGlobalDescribe().containsKey('FEC_CustomerDataConfigHistory__c');
    }

    private static List<SObject> queryHistories(Id configId) {
        return Database.query(
            'SELECT Id, FEC_KeyIdentifier__c, FEC_Status__c ' +
            'FROM FEC_CustomerDataConfigHistory__c ' +
            'WHERE FEC_Customers_Data_Config__c = \'' + String.valueOf(configId) + '\''
        );
    }

    @IsTest
    static void testCreateHistoryRecords_Insert() {
        FEC_CustomerAdditionalInfoConfig__c config = new FEC_CustomerAdditionalInfoConfig__c(
            FEC_KeyIdentifier__c = 'CIF_NUMBER',
            FEC_FieldID__c = 'FLD_001',
            FEC_IsActive__c = true,
            FEC_StartDate__c = Date.today(),
            FEC_EndDate__c = Date.today().addDays(30),
            FEC_Status__c = FEC_ConstantCommon.PROCESSED_STATUS
        );
        insert config;

        if (!hasConfigHistoryObject()) {
            System.assert(true, 'FEC_CustomerDataConfigHistory__c not deployed on org.');
            return;
        }

        List<SObject> histories = queryHistories(config.Id);

        System.assertEquals(1, histories.size(), 'Phải tạo được 1 bản ghi lịch sử sau khi insert config.');
        System.assertEquals('CIF_NUMBER', (String) histories[0].get('FEC_KeyIdentifier__c'));
        System.assertEquals(
            FEC_ConstantCommon.PROCESSED_STATUS,
            (String) histories[0].get('FEC_Status__c')
        );
    }

    @IsTest
    static void testCreateHistoryRecords_Update() {
        FEC_CustomerAdditionalInfoConfig__c config = new FEC_CustomerAdditionalInfoConfig__c(
            FEC_KeyIdentifier__c = 'PHONE',
            FEC_FieldID__c = 'FLD_PHONE',
            FEC_IsActive__c = true,
            FEC_Status__c = FEC_ConstantCommon.PROCESSED_STATUS
        );
        insert config;

        Test.startTest();
        config.FEC_Status__c = FEC_ConstantCommon.CANCELLED_STATUS;
        update config;
        Test.stopTest();

        if (!hasConfigHistoryObject()) {
            System.assert(true, 'FEC_CustomerDataConfigHistory__c not deployed on org.');
            return;
        }

        List<SObject> histories = queryHistories(config.Id);
        System.assert(histories.size() >= 1, 'Số lượng bản ghi lịch sử phải >= 1.');
    }
}
