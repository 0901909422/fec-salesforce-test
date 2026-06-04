/**
 * @description Deep tests for FEC_CleanUpMasterDataController — populate data để cover query paths.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM
 */
@IsTest
private class FEC_CleanUpMDCDeepTest {

    @testSetup
    static void setup() {
        // Live data
        FEC_Product_Type__c lpt = new FEC_Product_Type__c(Name = 'LPT_CU', FEC_Code__c = 'LPT_CU_1', FEC_Active__c = true);
        insert lpt;
        FEC_Business_Process__c lbp = new FEC_Business_Process__c(Name = 'LBP_CU', FEC_Code__c = 'LBP_CU_1');
        insert lbp;
        FEC_Category__c lcat = new FEC_Category__c(Name = 'LCAT_CU', FEC_Code__c = 'LCAT_CU_1', FEC_Active__c = true);
        insert lcat;
        FEC_Sub_Category__c lscat = new FEC_Sub_Category__c(Name = 'LSCAT_CU', FEC_Code__c = 'LSCAT_CU_1', FEC_Active__c = true);
        insert lscat;

        FEC_Nature_of_Case__c lnoc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = lpt.Id, FEC_Business_Process__c = lbp.Id,
            FEC_Category__c = lcat.Id, FEC_Sub_Category__c = lscat.Id,
            FEC_Code__c = 'LNOC_CU_1'
        );
        insert lnoc;

        FEC_Case_Stage__c lstage = new FEC_Case_Stage__c(
            Name = 'LStage_CU', FEC_Code__c = 'LST_CU_1', FEC_Business_Process__c = lbp.Id
        );
        insert lstage;
        FEC_Case_Stage__c lnextStage = new FEC_Case_Stage__c(
            Name = 'LNext_CU', FEC_Code__c = 'LST_CU_2', FEC_Business_Process__c = lbp.Id
        );
        insert lnextStage;

        FEC_Action_Button__c lbtn = new FEC_Action_Button__c(Name = 'LSubmit_CU', FEC_Code__c = 'LAB_CU_1');
        insert lbtn;

        insert new FEC_Stage_Change__c(
            FEC_Active__c = true,
            FEC_Previous_Stage__c = lstage.Id,
            FEC_Action_Button__c = lbtn.Id,
            FEC_Next_Stage__c = lnextStage.Id
        );

        insert new FEC_Channel__c(
            Name = 'LCh_CU', FEC_Code__c = 'LCH_CU_1',
            FEC_Channel_ID__c = 'CU', FEC_Channel_Vietnamese_name__c = 'CU',
            FEC_Channel_Status__c = true, FEC_Self_Service_Flag__c = false,
            FEC_Cancel_Case__c = false, FEC_Get_Nature_Of_Case__c = false, FEC_Update_Case_Status__c = false
        );

        insert new FEC_Additional_Field__c(
            FEC_Unique_ID__c = 'AF_CU_1', FEC_Type__c = 'String',
            FEC_Name_VN__c = 'AFCU', FEC_Field_Status__c = true
        );

        // MDM equivalent
        FEC_MDM_Product_Type__c mpt = new FEC_MDM_Product_Type__c(FEC_Code__c = 'MPT_CU_1');
        insert mpt;
        FEC_MDM_Business_Process__c mbp = new FEC_MDM_Business_Process__c(FEC_Code__c = 'MBP_CU_1');
        insert mbp;
        FEC_MDM_Nature_Of_Case__c mnoc = new FEC_MDM_Nature_Of_Case__c(
            FEC_Product_Type__c = mpt.Id, FEC_Business_Process__c = mbp.Id,
            FEC_Code__c = 'MNOC_CU_1'
        );
        insert mnoc;

        FEC_MDM_Case_Stage__c mstage = new FEC_MDM_Case_Stage__c(
            Name = 'MStage_CU', FEC_Code__c = 'MST_CU_1', FEC_Business_Process__c = mbp.Id
        );
        insert mstage;

        // Batch Log
        insert new FEC_Batch_Log__c(
            FEC_Batch_Name__c = 'FEC_PushMDMToLiveBatch',
            FEC_Status__c = 'Completed',
            FEC_Total_Job_Items__c = 100,
            FEC_Processed_Items__c = 100
        );
    }

    @IsTest
    static void testGetAllMasterData_HasData() {
        Test.startTest();
        Map<String, List<Object>> data = FEC_CleanUpMasterDataController.getAllMasterData();
        Test.stopTest();
        Assert.isNotNull(data);
        Assert.isFalse(data.isEmpty());
    }

    @IsTest
    static void testGetAllMasterDataMDM_HasData() {
        Test.startTest();
        Map<String, List<Object>> data = FEC_CleanUpMasterDataController.getAllMasterDataMDM();
        Test.stopTest();
        Assert.isNotNull(data);
        Assert.isFalse(data.isEmpty());
    }

    @IsTest
    static void testGetRecentBatchLogs_WithData() {
        Test.startTest();
        List<FEC_Batch_Log__c> logs = FEC_CleanUpMasterDataController.getRecentBatchLogs(50);
        Test.stopTest();
        Assert.isFalse(logs.isEmpty());
    }

    @IsTest
    static void testGetRecentBatchLogs_OverMaxLimit() {
        Test.startTest();
        List<FEC_Batch_Log__c> logs = FEC_CleanUpMasterDataController.getRecentBatchLogs(500);
        Test.stopTest();
        // 500 capped to 200
        Assert.isNotNull(logs);
    }
}