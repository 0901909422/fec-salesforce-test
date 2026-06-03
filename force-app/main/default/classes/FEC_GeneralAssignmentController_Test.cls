@IsTest
private class FEC_GeneralAssignmentController_Test {

    @TestSetup
    static void setupData() {
        // Tạo Channel
        insert new FEC_Channel__c(
            Name = 'Call Center',
            FEC_Channel_ID__c = 'CH01',
            FEC_Channel_Vietnamese_name__c = 'Tổng đài Call Center',
            FEC_Channel_Status__c = true
        );

        // Tạo General Assignment mồi
        insert new FEC_General_Assignment__c(
            FEC_General_Assignment_Name__c = 'GA Test',
            FEC_General_Assignment_Code__c = 'GA001',
            FEC_Active__c = true
        );
    }

    @IsTest
    static void testGetChannels() {
        Test.startTest();
        List<FEC_Channel__c> channels = FEC_GeneralAssignmentController.getChannels('Call');
        List<FEC_Channel__c> all = FEC_GeneralAssignmentController.getChannels('');
        Test.stopTest();

        System.assertEquals(1, channels.size());
        System.assert(all.size() > 0);
    }

    @IsTest
    static void testGetGeneralAssignmentNames() {
        Test.startTest();
        List<Map<String, String>> names = FEC_GeneralAssignmentController.getGeneralAssignmentNames();
        Test.stopTest();

        System.assertEquals(1, names.size());
        System.assertEquals('GA Test', names[0].get('label'));
    }

    @IsTest
    static void testSaveAndGetCode() {
        Test.startTest();
        // Test Save
        Id gaId = FEC_GeneralAssignmentController.saveGeneralAssignment(
            null, 'Existing', null, null, 'New GA', 'GA002', true
        );
        
        // Test Getters
        String recordName = FEC_GeneralAssignmentController.getRecordName(gaId);
        String code = FEC_GeneralAssignmentController.getGACodeByName('New GA');
        Test.stopTest();

        System.assertNotEquals(null, gaId);
        System.assertEquals('GA002', code);
    }

    @IsTest
    static void testUpdateGeneralAssignment() {
        FEC_General_Assignment__c ga = [SELECT Id FROM FEC_General_Assignment__c LIMIT 1];

        Test.startTest();
        FEC_GeneralAssignmentController.updateGeneralAssignment(
            ga.Id, 'New', 'CH01', 'GA Updated', 'GA001-U', true
        );
        Test.stopTest();

        FEC_General_Assignment__c updatedGa = [SELECT FEC_General_Assignment_Name__c FROM FEC_General_Assignment__c WHERE Id = :ga.Id];
        System.assertEquals('GA Updated', updatedGa.FEC_General_Assignment_Name__c);
    }
}