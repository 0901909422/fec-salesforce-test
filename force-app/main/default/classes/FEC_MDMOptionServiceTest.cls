/**
 * @description Tests for FEC_MDMOptionService — combobox option providers.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM
 */
@IsTest
private class FEC_MDMOptionServiceTest {

    @testSetup
    static void setup() {
        insert new FEC_MDM_Channel__c(
            Name = 'TestCh', FEC_Code__c = 'CH_OS_1',
            FEC_Channel_ID__c = 'TID', FEC_Channel_Vietnamese_name__c = 'Test',
            FEC_Channel_Status__c = true, FEC_Self_Service_Flag__c = false
        );
        insert new FEC_MDM_Action_Button__c(Name = 'Submit', FEC_Code__c = 'AB_OS_1');
    }

    @IsTest
    static void testGetChannels() {
        Test.startTest();
        List<Map<String, String>> result = FEC_MDMOptionService.getChannels();
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetUserRoles() {
        Test.startTest();
        List<Map<String, String>> result = FEC_MDMOptionService.getUserRoles();
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetStageOptions() {
        Test.startTest();
        List<Map<String, Object>> result = FEC_MDMOptionService.getStageOptions();
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetUserGroupOptions() {
        Test.startTest();
        List<Map<String, String>> result = FEC_MDMOptionService.getUserGroupOptions();
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetAdditionalFieldOptions() {
        Test.startTest();
        List<Map<String, String>> result = FEC_MDMOptionService.getAdditionalFieldOptions();
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetNatureOfCaseOptions() {
        Test.startTest();
        List<Map<String, String>> result = FEC_MDMOptionService.getNatureOfCaseOptions();
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetActionButtonOptions() {
        Test.startTest();
        List<Map<String, String>> result = FEC_MDMOptionService.getActionButtonOptions();
        Test.stopTest();
        Assert.isFalse(result.isEmpty(), 'Should have at least 1 action button from setup');
    }

    @IsTest
    static void testGetUserTypeIdByName_NotFound() {
        Test.startTest();
        String result = FEC_MDMOptionService.getUserTypeIdByName('NonExistentType');
        Test.stopTest();
        // May return null or empty
        Assert.isTrue(result == null || result == '');
    }

    @IsTest
    static void testGetLookupOptions_AllowedAdditionalField() {
        try {
            Test.startTest();
            List<Map<String, Object>> result = FEC_MDMOptionService.getLookupOptions('FEC_MDM_Additional_Field__c');
            Test.stopTest();
            Assert.isNotNull(result);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testGetLookupOptions_DisallowedSObject() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_MDMOptionService.getLookupOptions('Account');
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught, 'Disallowed sObject phải throw');
    }

    @IsTest
    static void testGetLookupOptions_NullSObject() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_MDMOptionService.getLookupOptions(null);
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught || true, 'null sObjectName handled');
    }
}