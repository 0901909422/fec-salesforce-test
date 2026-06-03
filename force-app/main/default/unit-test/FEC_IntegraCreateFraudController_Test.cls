@IsTest
private class FEC_IntegraCreateFraudController_Test {

    private static Schema.SObjectType masterDataIntegrationType() {
        return Schema.getGlobalDescribe().get('FEC_Master_Data_Integration__c');
    }

    private static void insertMasterDataHierarchy(String suffix) {
        Schema.SObjectType masterType = masterDataIntegrationType();
        List<SObject> masters = new List<SObject>();

        SObject category = masterType.newSObject();
        category.put('FEC_Source_Type__c', 'Category');
        category.put('FEC_Source_Id__c', 'CAT' + suffix);
        category.put('FEC_Source_Name__c', 'Credit Card');
        category.put('FEC_PosOrder__c', 1);
        masters.add(category);

        SObject subCategory = masterType.newSObject();
        subCategory.put('FEC_Source_Type__c', 'SubCategory');
        subCategory.put('FEC_Source_Parent_Id__c', 'CAT' + suffix);
        subCategory.put('FEC_Source_Id__c', 'SCAT' + suffix);
        subCategory.put('FEC_Source_Name__c', 'Visa');
        masters.add(subCategory);

        insert masters;
    }

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        insert new FEC_Channel__c(
            Name = 'Voice',
            FEC_Code__c = 'CH' + suffix,
            FEC_Channel_Vietnamese_name__c = 'Tổng đài',
            FEC_Channel_ID__c = 'CH01',
            FEC_Channel_Status__c = true
        );

        if (masterDataIntegrationType() != null) {
            insertMasterDataHierarchy(suffix);
        }
    }

    @IsTest
    static void testLoadChannelList() {
        Test.startTest();
        List<FEC_IntegrationCreateFraudController.NodeDTO> channels =
            FEC_IntegrationCreateFraudController.loadChannelList();
        Test.stopTest();

        System.assertNotEquals(0, channels.size(), 'Must return at least one channel.');
        System.assertEquals('CH01', channels[0].value);
    }

    @IsTest
    static void testGetMasterDataForUI() {
        if (masterDataIntegrationType() == null) {
            System.assert(true, 'Skipped: FEC_Master_Data_Integration__c not on org.');
            return;
        }

        Test.startTest();
        String jsonResult = FEC_IntegrationCreateFraudController.getMasterDataForUI();
        Test.stopTest();

        System.assert(String.isNotBlank(jsonResult), 'JSON result must not be blank.');

        List<SObject> categories = Database.query(
            'SELECT FEC_Source_Id__c FROM FEC_Master_Data_Integration__c ' +
            'WHERE FEC_Source_Type__c = \'Category\' LIMIT 1'
        );
        System.assert(!categories.isEmpty(), 'Category master data must exist.');
        System.assert(
            jsonResult.contains((String) categories[0].get('FEC_Source_Id__c')),
            'JSON must contain category master data.'
        );
    }

    @IsTest
    static void testGetIntegrationFieldTypes() {
        Test.startTest();
        Map<String, String> fieldTypes =
            FEC_IntegrationCreateFraudController.getIntegrationFieldTypes();
        Test.stopTest();

        System.assert(fieldTypes.containsKey('File'), 'Map must include File field type config.');
    }

    @IsTest
    static void testGetFraudCaseById_Empty() {
        Test.startTest();
        FEC_IntegrationCreateFraudController.FraudPropertyDTO dto =
            FEC_IntegrationCreateFraudController.getFraudCaseById('003000000000000');
        Test.stopTest();

        System.assertNotEquals(null, dto);
    }
}
