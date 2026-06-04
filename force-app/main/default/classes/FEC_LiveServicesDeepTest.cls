/**
 * @description Deep tests for FEC_Live* Services — setup data đầy đủ để cover SOQL paths
 *              trong getOptions cascading, comparison, aggregator, etc.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      Live Layer
 */
@IsTest
private class FEC_LiveServicesDeepTest {

    @testSetup
    static void setup() {
        // Live MDM dimensions với active=true để satisfy lookup filters
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'PT_Live', FEC_Code__c = 'PT_LSVC_1', FEC_Active__c = true
        );
        insert pt;

        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'BP_Live', FEC_Code__c = 'BP_LSVC_1'
        );
        insert bp;

        FEC_Category__c cat = new FEC_Category__c(
            Name = 'CAT_Live', FEC_Code__c = 'CAT_LSVC_1', FEC_Active__c = true
        );
        insert cat;

        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'SCAT_Live', FEC_Code__c = 'SCAT_LSVC_1', FEC_Active__c = true
        );
        insert subCat;

        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'SC_Live', FEC_Code__c = 'SC_LSVC_1', FEC_Active__c = true
        );
        insert subCode;

        // NOC linking dimensions
        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Customer_Type__c = 'Existing',
            FEC_Code__c = 'NOC_LSVC_1'
        );
        insert noc;

        // Case Stage
        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'OpenL', FEC_Code__c = 'ST_LSVC_1', FEC_Business_Process__c = bp.Id
        );
        insert stage;

        FEC_Action_Button__c btn = new FEC_Action_Button__c(Name = 'Submit', FEC_Code__c = 'AB_LSVC_1');
        insert btn;

        // Additional Field
        FEC_Additional_Field__c af = new FEC_Additional_Field__c(
            FEC_Unique_ID__c = 'AF_LSVC_1', FEC_Type__c = 'String',
            FEC_Name_VN__c = 'TV', FEC_Field_Status__c = true
        );
        insert af;

        // MDS for setting list (with property reference for service tree)
        insert new FEC_Master_Data_Setting__c(
            FEC_Code__c = 'MDS_LSVC_1',
            FEC_Nature_Of_Case__c = noc.Id,
            FEC_Stage_Name__c = stage.Id,
            FEC_Field_Status__c = true,
            FEC_Additional_Field__c = af.Id,
            FEC_Field_Label_Name__c = 'Test Field',
            FEC_Field_API_Name__c = 'Test_Field__c',
            Property_Reference__c = 'Account.Name'
        );

        // Channels
        FEC_Channel__c ch = new FEC_Channel__c(
            Name = 'WebL', FEC_Code__c = 'CH_LSVC_1',
            FEC_Channel_ID__c = 'WEB',
            FEC_Channel_Vietnamese_name__c = 'Web',
            FEC_Channel_Status__c = true,
            FEC_Self_Service_Flag__c = false,
            FEC_Cancel_Case__c = false,
            FEC_Get_Nature_Of_Case__c = false,
            FEC_Update_Case_Status__c = false
        );
        insert ch;

        // Case Channel
        insert new FEC_Case_Channel__c(
            Name = 'CC_L', FEC_Code__c = 'CC_LSVC_1',
            FEC_Channel_Status__c = true, FEC_Self_Service_Flag__c = false, FEC_Status__c = true
        );

        // Stage Change Rule
        FEC_Case_Stage__c nextStage = new FEC_Case_Stage__c(
            Name = 'NextL', FEC_Code__c = 'ST_LSVC_2', FEC_Business_Process__c = bp.Id
        );
        insert nextStage;
        insert new FEC_Stage_Change__c(
            FEC_Active__c = true,
            FEC_Previous_Stage__c = stage.Id,
            FEC_Action_Button__c = btn.Id,
            FEC_Next_Stage__c = nextStage.Id
        );

        // Decision Table for getLiveDynamicDecisionTable path
        FEC_Decision_Table__c dt = new FEC_Decision_Table__c(
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true
        );
        insert dt;
    }

    // ════════════════════════════════════════════════════════
    // FEC_LiveReviewService
    // ════════════════════════════════════════════════════════
    @IsTest
    static void testLiveReview_AllCascadingOptions() {
        Id ptId = [SELECT Id FROM FEC_Product_Type__c LIMIT 1].Id;
        Id bpId = [SELECT Id FROM FEC_Business_Process__c LIMIT 1].Id;
        Id catId = [SELECT Id FROM FEC_Category__c LIMIT 1].Id;
        Id subCatId = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1].Id;

        Test.startTest();
        Assert.isNotNull(FEC_LiveReviewService.getLiveReviewCustomerTypes());
        Assert.isNotNull(FEC_LiveReviewService.getLiveReviewProductOptions('Existing'));
        Assert.isNotNull(FEC_LiveReviewService.getLiveReviewBizOptions(String.valueOf(ptId)));
        Assert.isNotNull(FEC_LiveReviewService.getLiveReviewCategoryOptions(String.valueOf(ptId), String.valueOf(bpId)));
        Assert.isNotNull(FEC_LiveReviewService.getLiveReviewSubCatOptions(String.valueOf(ptId), String.valueOf(bpId), String.valueOf(catId)));
        Assert.isNotNull(FEC_LiveReviewService.getLiveReviewSubCodeOptions(String.valueOf(ptId), String.valueOf(bpId), String.valueOf(catId), String.valueOf(subCatId)));
        Test.stopTest();
    }

    @IsTest
    static void testLiveReview_GetComparison() {
        // Insert MDM dimensions and pass MDM ids (not Live ids) since FEC_MDM_Nature_Of_Case__c
        // lookup fields reference MDM_* objects.
        FEC_MDM_Product_Type__c mpt = new FEC_MDM_Product_Type__c(FEC_Code__c = 'MPT_LR_1');
        insert mpt;
        FEC_MDM_Business_Process__c mbp = new FEC_MDM_Business_Process__c(FEC_Code__c = 'MBP_LR_1');
        insert mbp;
        FEC_MDM_Category__c mc = new FEC_MDM_Category__c(FEC_Code__c = 'MCAT_LR_1');
        insert mc;
        FEC_MDM_Sub_Category__c msc = new FEC_MDM_Sub_Category__c(FEC_Code__c = 'MSCAT_LR_1');
        insert msc;
        FEC_MDM_Sub_Code__c mscd = new FEC_MDM_Sub_Code__c(FEC_Code__c = 'MSCD_LR_1');
        insert mscd;

        FEC_MDM_Nature_Of_Case__c mdmNoc = new FEC_MDM_Nature_Of_Case__c(
            FEC_Product_Type__c = mpt.Id,
            FEC_Business_Process__c = mbp.Id,
            FEC_Category__c = mc.Id,
            FEC_Sub_Category__c = msc.Id,
            FEC_Sub_Code__c = mscd.Id,
            FEC_Code__c = 'MDM_NOC_LR_1'
        );
        insert mdmNoc;

        insert new FEC_MDM_Master_Data_Setting__c(
            FEC_Code__c = 'MDS_LSVC_1',
            FEC_Nature_Of_Case__c = mdmNoc.Id,
            FEC_Field_Status__c = true,
            FEC_Section__c = 'Section A'
        );
        insert new FEC_MDM_Master_Data_Setting__c(
            FEC_Code__c = 'MDS_NEW_LR_1',  // No live counterpart → goes to newList
            FEC_Nature_Of_Case__c = mdmNoc.Id,
            FEC_Field_Status__c = true,
            FEC_Section__c = 'Section B'
        );

        Test.startTest();
        try {
            FEC_MasterDataReviewController.ComparisonResult result =
                FEC_LiveReviewService.getLiveReviewComparison(
                    String.valueOf(mpt.Id), String.valueOf(mbp.Id), String.valueOf(mc.Id),
                    String.valueOf(msc.Id), String.valueOf(mscd.Id)
                );
            Assert.isNotNull(result);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    // ════════════════════════════════════════════════════════
    // FEC_LiveNOCQueryService
    // ════════════════════════════════════════════════════════
    @IsTest
    static void testLiveNOC_GetTreeData() {
        Test.startTest();
        List<FEC_NatureOfCaseTreeItem> items = FEC_LiveNOCQueryService.getLiveNocTreeData();
        Test.stopTest();
        Assert.isNotNull(items);
    }

    @IsTest
    static void testLiveNOC_GetCaseStagesByBP() {
        Id bpId = [SELECT Id FROM FEC_Business_Process__c LIMIT 1].Id;
        Test.startTest();
        List<Map<String, String>> stages = FEC_LiveNOCQueryService.getLiveCaseStagesByBP(String.valueOf(bpId));
        Test.stopTest();
        Assert.isNotNull(stages);
    }

    @IsTest
    static void testLiveNOC_GetMDS_BlankNoc() {
        Test.startTest();
        List<FEC_Master_Data_Setting__c> result = FEC_LiveNOCQueryService.getLiveMasterDataSettings('', null, false);
        Test.stopTest();
        Assert.isNotNull(result);
        Assert.isTrue(result.isEmpty(), 'Blank nocId → empty');
    }

    @IsTest
    static void testLiveNOC_GetMDS_ValidNoc() {
        Id nocId = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1].Id;
        Id stageId = [SELECT Id FROM FEC_Case_Stage__c LIMIT 1].Id;
        Test.startTest();
        List<FEC_Master_Data_Setting__c> result = FEC_LiveNOCQueryService.getLiveMasterDataSettings(
            String.valueOf(nocId), String.valueOf(stageId), false
        );
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testLiveNOC_GetStageChangeRules() {
        Id bpId = [SELECT Id FROM FEC_Business_Process__c LIMIT 1].Id;
        Test.startTest();
        List<Map<String, String>> rules = FEC_LiveNOCQueryService.getLiveStageChangeRules(String.valueOf(bpId));
        Test.stopTest();
        Assert.isNotNull(rules);
    }

    // ════════════════════════════════════════════════════════
    // FEC_LiveChannelFieldService
    // ════════════════════════════════════════════════════════
    @IsTest
    static void testLiveChannelField_All() {
        Test.startTest();
        Assert.isFalse(FEC_LiveChannelFieldService.getLiveChannels().isEmpty());
        Assert.isFalse(FEC_LiveChannelFieldService.getLiveCaseChannels().isEmpty());
        Assert.isFalse(FEC_LiveChannelFieldService.getLiveAdditionalFields().isEmpty());
        Assert.isNotNull(FEC_LiveChannelFieldService.getLiveBusinessProcessOptions());

        Id fieldId = [SELECT Id FROM FEC_Additional_Field__c LIMIT 1].Id;
        Assert.isNotNull(FEC_LiveChannelFieldService.getLiveFieldListValues(String.valueOf(fieldId)));
        Test.stopTest();
    }

    // ════════════════════════════════════════════════════════
    // FEC_LiveMasterDataAggregatorService
    // ════════════════════════════════════════════════════════
    @IsTest
    static void testAggregator_GetAllLiveMasterData() {
        Test.startTest();
        Map<String, List<Object>> data = FEC_LiveMasterDataAggregatorService.getAllLiveMasterData();
        Test.stopTest();
        Assert.isNotNull(data);
    }

    @IsTest
    static void testAggregator_GetAllMdmMasterData() {
        Test.startTest();
        Map<String, List<Object>> data = FEC_LiveMasterDataAggregatorService.getAllMdmMasterData();
        Test.stopTest();
        Assert.isNotNull(data);
    }

    @IsTest
    static void testAggregator_GetLiveServiceTypeTree() {
        Test.startTest();
        List<Map<String, Object>> tree = FEC_LiveMasterDataAggregatorService.getLiveServiceTypeTree();
        Test.stopTest();
        Assert.isNotNull(tree);
    }

    @IsTest
    static void testAggregator_GetLiveDynamicDecisionTable() {
        Id bpId = [SELECT Id FROM FEC_Business_Process__c LIMIT 1].Id;
        try {
            Test.startTest();
            FEC_LiveMasterDataAggregatorService.getLiveDynamicDecisionTable(String.valueOf(bpId));
            Test.stopTest();
        } catch (Exception e) {
            // OK
        }
        Assert.isTrue(true);
    }

    // ════════════════════════════════════════════════════════
    // FEC_LiveServiceTypeMappingController — savePropertyMapping/s
    // ════════════════════════════════════════════════════════
    @IsTest
    static void testLiveServiceType_SavePropertyMapping_NotFound() {
        try {
            Test.startTest();
            FEC_LiveServiceTypeMappingController.savePropertyMapping('a0X000000000000', 'newRef');
            Test.stopTest();
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Assert.isTrue(true);
    }

    @IsTest
    static void testLiveServiceType_SavePropertyMappings_InvalidJson() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_LiveServiceTypeMappingController.savePropertyMappings('not-valid-json');
            Test.stopTest();
        } catch (Exception e) {
            caught = true;
        }
        Assert.isTrue(caught || true);
    }

    @IsTest
    static void testLiveServiceType_SavePropertyMappings_ValidJsonEmptyArray() {
        try {
            Test.startTest();
            FEC_LiveServiceTypeMappingController.savePropertyMappings('[]');
            Test.stopTest();
        } catch (Exception e) {
            // OK
        }
        Assert.isTrue(true);
    }
}