/**
 * @description Smoke test for FEC_StageChangeToDecisionBatch (one-time migration batch).
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM | Decision Engine
 */
@IsTest
private class FEC_StageChangeToDecisionBatchTest {

    @IsTest
    static void testBatch_RunWithEmptyData() {
        // No FEC_Stage_Change__c records → batch start returns empty, execute không chạy
        Test.startTest();
        Database.executeBatch(new FEC_StageChangeToDecisionBatch(), 200);
        Test.stopTest();
        Assert.isTrue(true, 'Batch lifecycle ran without throw');
    }

    @IsTest
    static void testBatch_WithStageChangeData() {
        // Tạo dữ liệu Stage Change tối thiểu để batch xử lý 1 record
        FEC_Product_Type__c pt = new FEC_Product_Type__c(FEC_Code__c = 'PT_SCD_1', FEC_Active__c = true);
        insert pt;

        FEC_Business_Process__c bp = new FEC_Business_Process__c(FEC_Code__c = 'BP_SCD_1');
        insert bp;

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Code__c = 'NOC_SCD_1'
        );
        insert noc;

        FEC_Case_Stage__c prevStage = new FEC_Case_Stage__c(
            Name = 'PrevStg', FEC_Code__c = 'PRV_SCD_1',
            FEC_Nature_of_Cases__c = noc.Id
        );
        FEC_Case_Stage__c nextStage = new FEC_Case_Stage__c(
            Name = 'NextStg', FEC_Code__c = 'NXT_SCD_1',
            FEC_Nature_of_Cases__c = noc.Id
        );
        insert new List<FEC_Case_Stage__c>{prevStage, nextStage};

        FEC_Action_Button__c btn = new FEC_Action_Button__c(
            Name = 'Route to', FEC_Code__c = 'AB_SCD_1'
        );
        insert btn;

        FEC_Stage_Change__c sc = new FEC_Stage_Change__c(
            FEC_Active__c = true,
            FEC_Previous_Stage__c = prevStage.Id,
            FEC_Action_Button__c = btn.Id,
            FEC_Next_Stage__c = nextStage.Id,
            FEC_Next_Queue__c = 'TestQueue'
            // FEC_Team_User_Group__c skipped — restricted picklist (User_Group GVS)
        );
        insert sc;

        Test.startTest();
        Database.executeBatch(new FEC_StageChangeToDecisionBatch(), 200);
        Test.stopTest();

        // Verify rules created
        Integer mdmRules = [SELECT COUNT() FROM FEC_MDM_Decision_Rule__c WHERE FEC_Code__c LIKE 'STG_%'];
        Assert.isTrue(mdmRules >= 1, 'Phải tạo ít nhất 1 MDM rule');
        Integer liveRules = [SELECT COUNT() FROM FEC_Decision_Rule__c WHERE FEC_Code__c LIKE 'STG_%'];
        Assert.isTrue(liveRules >= 1, 'Phải tạo ít nhất 1 Live rule');
    }
}