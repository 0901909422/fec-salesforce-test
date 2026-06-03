/**
 * @description Unit tests for FEC_DecisionEngineController (deprecated utility methods).
 *              Chỉ còn `getStatusNameByStageId` và `getMDMStatusNameByStageId`.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM | Decision Engine
 */
@IsTest
private class FEC_DecisionEngineControllerTest {

    @IsTest
    static void testGetStatusNameByStageId_NullId() {
        Test.startTest();
        String result = FEC_DecisionEngineController.getStatusNameByStageId(null);
        Test.stopTest();
        Assert.isNull(result, 'null id → null result');
    }

    @IsTest
    static void testGetStatusNameByStageId_NotFound() {
        // Insert a Case_Stage with no Status_Name → result null
        FEC_Case_Stage__c s = new FEC_Case_Stage__c(Name = 'NoStatusStage', FEC_Code__c = 'NSS_001');
        insert s;

        Test.startTest();
        String result = FEC_DecisionEngineController.getStatusNameByStageId(s.Id);
        Test.stopTest();

        Assert.isNull(result, 'Stage không có Status_Name → null');
    }

    @IsTest
    static void testGetStatusNameByStageId_Found() {
        FEC_Case_Stage__c s = new FEC_Case_Stage__c(
            Name = 'WithStatus',
            FEC_Code__c = 'WS_001',
            FEC_Status_Name__c = 'In Progress'
        );
        insert s;

        Test.startTest();
        String result = FEC_DecisionEngineController.getStatusNameByStageId(s.Id);
        Test.stopTest();

        Assert.areEqual('In Progress', result);
    }

    @IsTest
    static void testGetMDMStatusNameByStageId_NullId() {
        Test.startTest();
        String result = FEC_DecisionEngineController.getMDMStatusNameByStageId(null);
        Test.stopTest();
        Assert.isNull(result);
    }

    @IsTest
    static void testGetMDMStatusNameByStageId_Found() {
        FEC_MDM_Case_Stage__c s = new FEC_MDM_Case_Stage__c(
            Name = 'MDMWithStatus',
            FEC_Code__c = 'MWS_001',
            FEC_Status_Name__c = 'Completed'
        );
        insert s;

        Test.startTest();
        String result = FEC_DecisionEngineController.getMDMStatusNameByStageId(s.Id);
        Test.stopTest();

        Assert.areEqual('Completed', result);
    }

    @IsTest
    static void testGetMDMStatusNameByStageId_NotFound() {
        FEC_MDM_Case_Stage__c s = new FEC_MDM_Case_Stage__c(Name = 'NoStat', FEC_Code__c = 'NS_002');
        insert s;
        Test.startTest();
        String result = FEC_DecisionEngineController.getMDMStatusNameByStageId(s.Id);
        Test.stopTest();
        Assert.isNull(result);
    }
}