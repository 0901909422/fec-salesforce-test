/**
 * @description Tests for FEC_MDMFieldOptionService.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM | Decision Engine
 */
@IsTest
private class FEC_MDMFieldOptionServiceTest {

    @IsTest
    static void testGetAdditionalFieldOptions() {
        // Insert at least 1 additional field
        insert new FEC_MDM_Additional_Field__c(
            FEC_Unique_ID__c = 'AF_FOS_1',
            FEC_Type__c = 'String',
            FEC_Name_VN__c = 'Tên',
            FEC_Field_Status__c = true
        );
        Test.startTest();
        List<Map<String, Object>> result = FEC_MDMFieldOptionService.getAdditionalFieldOptions();
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetFieldsForBusinessProcess_Null() {
        Test.startTest();
        List<Map<String, String>> result = FEC_MDMFieldOptionService.getFieldsForBusinessProcess(null);
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetFieldsForBusinessProcess_Valid() {
        FEC_MDM_Business_Process__c bp = new FEC_MDM_Business_Process__c(FEC_Code__c = 'BP_FOS_1');
        insert bp;
        Test.startTest();
        List<Map<String, String>> result = FEC_MDMFieldOptionService.getFieldsForBusinessProcess(bp.Id);
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetFieldsForStage_Null() {
        Test.startTest();
        List<Map<String, String>> result = FEC_MDMFieldOptionService.getFieldsForStage(null);
        Test.stopTest();
        Assert.isNotNull(result);
    }
}