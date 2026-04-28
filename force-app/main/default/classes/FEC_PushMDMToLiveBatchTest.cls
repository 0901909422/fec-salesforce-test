@isTest
private class FEC_PushMDMToLiveBatchTest {

    @testSetup
    static void setupTestData() {
        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;
        try {
            // 1. Business Process (parent for Case Stage, NOC)
            FEC_MDM_Business_Process__c bp = new FEC_MDM_Business_Process__c(
                Name = 'Test BP', FEC_Code__c = 'BP-001', FEC_Status__c = true,
                Process_Change_Status__c = 'New'
            );
            insert bp;

            // 2. Additional Field
            FEC_MDM_Additional_Field__c af = new FEC_MDM_Additional_Field__c(
                Name = 'Test AF', FEC_Code__c = 'AF-001', FEC_Unique_ID__c = 'AF-UID-001',
                FEC_Type__c = 'String', FEC_Field_Status__c = true,
                Process_Change_Status__c = 'New'
            );
            insert af;

            // 3. Product Type
            FEC_MDM_Product_Type__c pt = new FEC_MDM_Product_Type__c(
                Name = 'Test PT', FEC_Code__c = 'PT-001', FEC_Status__c = true,
                Process_Change_Status__c = 'New'
            );
            insert pt;

            // 4. Category
            FEC_MDM_Category__c cat = new FEC_MDM_Category__c(
                Name = 'Test Cat', FEC_Code__c = 'CAT-001', FEC_Status__c = true,
                Process_Change_Status__c = 'New'
            );
            insert cat;

            // 5. Sub Category
            FEC_MDM_Sub_Category__c scat = new FEC_MDM_Sub_Category__c(
                Name = 'Test SCat', FEC_Code__c = 'SCAT-001', FEC_Status__c = true,
                Process_Change_Status__c = 'New'
            );
            insert scat;

            // 6. Sub Code
            FEC_MDM_Sub_Code__c scode = new FEC_MDM_Sub_Code__c(
                Name = 'Test SCode', FEC_Code__c = 'SCODE-001', FEC_Status__c = true,
                Process_Change_Status__c = 'New'
            );
            insert scode;

            // 7. Channel
            FEC_MDM_Channel__c ch = new FEC_MDM_Channel__c(
                Name = 'Test Channel', FEC_Code__c = 'CH-001',
                FEC_Channel_ID__c = 'CH-ID-001', FEC_Channel_Status__c = true,
                FEC_Channel_Vietnamese_name__c = 'Kênh Test',
                Process_Change_Status__c = 'New'
            );
            insert ch;

            // 8. Case Stage (depends on Business Process)
            FEC_MDM_Case_Stage__c cs = new FEC_MDM_Case_Stage__c(
                Name = 'Test Stage', FEC_Code__c = 'CS-001',
                FEC_Business_Process__c = bp.Id,
                Process_Change_Status__c = 'New'
            );
            insert cs;

            // 8b. Second Case Stage for Next Stage lookup
            FEC_MDM_Case_Stage__c cs2 = new FEC_MDM_Case_Stage__c(
                Name = 'Test Stage 2', FEC_Code__c = 'CS-002',
                FEC_Business_Process__c = bp.Id,
                Process_Change_Status__c = 'New'
            );
            insert cs2;

            // 9. Nature of Case (depends on BP, PT, Cat, SCat, SCode)
            // Do NOT set FEC_Product_Type__c directly to avoid lookup filter validation
            FEC_MDM_Nature_Of_Case__c noc = new FEC_MDM_Nature_Of_Case__c(
                FEC_Code__c = 'NOC-001',
                FEC_Business_Process__c = bp.Id,
                FEC_Customer_Type__c = 'All',
                Process_Change_Status__c = 'New'
            );
            insert noc;

            // 10. Additional Field List Value (depends on AF)
            FEC_MDM_Additional_Field_List_Value__c aflv = new FEC_MDM_Additional_Field_List_Value__c(
                Name = 'Test AFLV', FEC_Code__c = 'AFLV-001',
                FEC_Order__c = 1, FEC_Name_VN__c = 'AFLV VN',
                FEC_Additional_Field__c = af.Id,
                Process_Change_Status__c = 'New'
            );
            insert aflv;

            // 11. Master Data Setting (depends on Case Stage, NOC, AF, Channel)
            FEC_MDM_Master_Data_Setting__c mds = new FEC_MDM_Master_Data_Setting__c(
                FEC_Code__c = 'MDS-001',
                FEC_Field_Object_Name__c = 'Case',
                FEC_Field_Status__c = true,
                FEC_Stage_Name__c = cs.Id,
                Process_Change_Status__c = 'New'
            );
            insert mds;

            // 12. Action Button
            FEC_MDM_Action_Button__c ab = new FEC_MDM_Action_Button__c(
                Name = 'Test Action', FEC_Code__c = 'AB-001',
                Process_Change_Status__c = 'New'
            );
            insert ab;

            // 13. Stage Change (depends on Case Stage, Action Button)
            FEC_MDM_Stage_Change__c sc = new FEC_MDM_Stage_Change__c(
                FEC_Code__c = 'SC-001',
                FEC_Previous_Stage__c = cs.Id,
                FEC_Action_Button__c = ab.Id,
                FEC_Next_Stage__c = cs2.Id,
                FEC_Next_Queue__c = 'Queue1',
                FEC_Team_User_Group__c = 'CA',
                FEC_Active__c = true,
                Process_Change_Status__c = 'New'
            );
            insert sc;

            // 14. Stage Change Condition (depends on Stage Change, MDS)
            FEC_MDM_Stage_Change_Condition__c scc = new FEC_MDM_Stage_Change_Condition__c(
                FEC_Code__c = 'SCC-001',
                FEC_Stage_Change__c = sc.Id,
                FEC_Master_Data_Setting__c = mds.Id,
                FEC_Operator__c = '=',
                FEC_Value__c = 'TestValue',
                FEC_Value_Type__c = 'String',
                Process_Change_Status__c = 'New'
            );
            insert scc;

        } finally {
            FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;
        }
    }

    /**
     * Helper: Call execute() directly for each object in dependency order.
     * Bypasses batch framework limitation in test context where only one
     * executeBatch call is allowed and batch size 14 puts all items in one scope.
     */
    private static void executeAllObjects(FEC_PushMDMToLiveBatch batch) {
        List<String> executionOrder = new List<String>{
            FEC_ObjectConstants.OBJ_MDM_BUSINESS_PROCESS,
            FEC_ObjectConstants.OBJ_MDM_ADDITIONAL_FIELD,
            FEC_ObjectConstants.OBJ_MDM_PRODUCT_TYPE,
            FEC_ObjectConstants.OBJ_MDM_CATEGORY,
            FEC_ObjectConstants.OBJ_MDM_SUB_CATEGORY,
            FEC_ObjectConstants.OBJ_MDM_SUB_CODE,
            FEC_ObjectConstants.OBJ_MDM_CHANNEL,
            FEC_ObjectConstants.OBJ_MDM_CASE_STAGE,
            FEC_ObjectConstants.OBJ_MDM_NATURE_OF_CASE,
            FEC_ObjectConstants.OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE,
            FEC_ObjectConstants.OBJ_MDM_MASTER_DATA_SETTING,
            FEC_ObjectConstants.OBJ_MDM_ACTION_BUTTON,
            FEC_ObjectConstants.OBJ_MDM_STAGE_CHANGE,
            FEC_ObjectConstants.OBJ_MDM_STAGE_CHANGE_CONDITION
        };
        for (String objName : executionOrder) {
            batch.execute(null, new List<String>{ objName });
        }
    }

    /**
     * Test 1: Run Push batch, verify MDM records get status 'Synced'
     */
    @isTest
    static void testPushBatchExecution() {
        Test.startTest();
        FEC_PushMDMToLiveBatch batch = new FEC_PushMDMToLiveBatch();
        executeAllObjects(batch);
        Test.stopTest();

        // Verify MDM Business Process status is Synced
        FEC_MDM_Business_Process__c bp = [
            SELECT Process_Change_Status__c FROM FEC_MDM_Business_Process__c
            WHERE FEC_Code__c = 'BP-001' LIMIT 1
        ];
        Assert.areEqual('Synced', bp.Process_Change_Status__c,
            'MDM Business Process should be Synced after push');

        // Verify MDM Product Type status is Synced
        FEC_MDM_Product_Type__c pt = [
            SELECT Process_Change_Status__c FROM FEC_MDM_Product_Type__c
            WHERE FEC_Code__c = 'PT-001' LIMIT 1
        ];
        Assert.areEqual('Synced', pt.Process_Change_Status__c,
            'MDM Product Type should be Synced after push');

        // Verify MDM Case Stage status is Synced
        FEC_MDM_Case_Stage__c cs = [
            SELECT Process_Change_Status__c FROM FEC_MDM_Case_Stage__c
            WHERE FEC_Code__c = 'CS-001' LIMIT 1
        ];
        Assert.areEqual('Synced', cs.Process_Change_Status__c,
            'MDM Case Stage should be Synced after push');

        // Verify MDM Action Button status is Synced
        FEC_MDM_Action_Button__c ab = [
            SELECT Process_Change_Status__c FROM FEC_MDM_Action_Button__c
            WHERE FEC_Code__c = 'AB-001' LIMIT 1
        ];
        Assert.areEqual('Synced', ab.Process_Change_Status__c,
            'MDM Action Button should be Synced after push');

        // Verify MDM Stage Change status is Synced
        List<FEC_MDM_Stage_Change__c> scList = [
            SELECT Process_Change_Status__c FROM FEC_MDM_Stage_Change__c
            WHERE FEC_Code__c = 'SC-001'
        ];
        Assert.isFalse(scList.isEmpty(), 'MDM Stage Change record should exist');
        Assert.areEqual('Synced', scList[0].Process_Change_Status__c,
            'MDM Stage Change should be Synced after push');

        // Verify MDM Stage Change Condition status is Synced
        List<FEC_MDM_Stage_Change_Condition__c> sccList = [
            SELECT Process_Change_Status__c FROM FEC_MDM_Stage_Change_Condition__c
            WHERE FEC_Code__c = 'SCC-001'
        ];
        Assert.isFalse(sccList.isEmpty(), 'MDM Stage Change Condition record should exist');
        Assert.areEqual('Synced', sccList[0].Process_Change_Status__c,
            'MDM Stage Change Condition should be Synced after push');

        // Verify Live records were created
        Assert.isTrue([SELECT COUNT() FROM FEC_Business_Process__c WHERE FEC_Code__c = 'BP-001'] > 0,
            'Live Business Process should be created after push');
        Assert.isTrue([SELECT COUNT() FROM FEC_Product_Type__c WHERE FEC_Code__c = 'PT-001'] > 0,
            'Live Product Type should be created after push');
        Assert.isTrue([SELECT COUNT() FROM FEC_Case_Stage__c WHERE FEC_Code__c = 'CS-001'] > 0,
            'Live Case Stage should be created after push');
        Assert.isTrue([SELECT COUNT() FROM FEC_Action_Button__c WHERE FEC_Code__c = 'AB-001'] > 0,
            'Live Action Button should be created after push');
        Assert.isTrue([SELECT COUNT() FROM FEC_Stage_Change__c WHERE FEC_Code__c = 'SC-001'] > 0,
            'Live Stage Change should be created after push');
        Assert.isTrue([SELECT COUNT() FROM FEC_Stage_Change_Condition__c WHERE FEC_Code__c = 'SCC-001'] > 0,
            'Live Stage Change Condition should be created after push');
    }

    /**
     * Test 2: After push, verify Live records have same field values as MDM source
     * This is the KEY test — fields must be identical between layers
     */
    @isTest
    static void testPushBatchFieldConsistency() {
        Test.startTest();
        FEC_PushMDMToLiveBatch batch = new FEC_PushMDMToLiveBatch();
        executeAllObjects(batch);
        Test.stopTest();

        // Business Process: Name, FEC_Code__c
        FEC_MDM_Business_Process__c mdmBp = [
            SELECT Name, FEC_Code__c
            FROM FEC_MDM_Business_Process__c WHERE FEC_Code__c = 'BP-001' LIMIT 1
        ];
        FEC_Business_Process__c liveBp = [
            SELECT Name, FEC_Code__c
            FROM FEC_Business_Process__c WHERE FEC_Code__c = 'BP-001' LIMIT 1
        ];
        Assert.areEqual(mdmBp.Name, liveBp.Name,
            'Live BP Name should match MDM BP Name');
        Assert.areEqual(mdmBp.FEC_Code__c, liveBp.FEC_Code__c,
            'Live BP FEC_Code__c should match MDM');

        // Product Type: Name, FEC_Code__c
        FEC_MDM_Product_Type__c mdmPt = [
            SELECT Name, FEC_Code__c
            FROM FEC_MDM_Product_Type__c WHERE FEC_Code__c = 'PT-001' LIMIT 1
        ];
        FEC_Product_Type__c livePt = [
            SELECT Name, FEC_Code__c
            FROM FEC_Product_Type__c WHERE FEC_Code__c = 'PT-001' LIMIT 1
        ];
        Assert.areEqual(mdmPt.Name, livePt.Name,
            'Live PT Name should match MDM PT Name');
        Assert.areEqual(mdmPt.FEC_Code__c, livePt.FEC_Code__c,
            'Live PT FEC_Code__c should match MDM');

        // Category: Name, FEC_Code__c
        FEC_MDM_Category__c mdmCat = [
            SELECT Name, FEC_Code__c FROM FEC_MDM_Category__c WHERE FEC_Code__c = 'CAT-001' LIMIT 1
        ];
        FEC_Category__c liveCat = [
            SELECT Name, FEC_Code__c FROM FEC_Category__c WHERE FEC_Code__c = 'CAT-001' LIMIT 1
        ];
        Assert.areEqual(mdmCat.Name, liveCat.Name,
            'Live Category Name should match MDM');
        Assert.areEqual(mdmCat.FEC_Code__c, liveCat.FEC_Code__c,
            'Live Category FEC_Code__c should match MDM');

        // Channel: Name, FEC_Channel_ID__c, FEC_Channel_Vietnamese_name__c
        FEC_MDM_Channel__c mdmCh = [
            SELECT Name, FEC_Code__c, FEC_Channel_ID__c, FEC_Channel_Vietnamese_name__c
            FROM FEC_MDM_Channel__c WHERE FEC_Code__c = 'CH-001' LIMIT 1
        ];
        FEC_Channel__c liveCh = [
            SELECT Name, FEC_Code__c, FEC_Channel_ID__c, FEC_Channel_Vietnamese_name__c
            FROM FEC_Channel__c WHERE FEC_Code__c = 'CH-001' LIMIT 1
        ];
        Assert.areEqual(mdmCh.Name, liveCh.Name,
            'Live Channel Name should match MDM');
        Assert.areEqual(mdmCh.FEC_Channel_ID__c, liveCh.FEC_Channel_ID__c,
            'Live Channel ID should match MDM');
        Assert.areEqual(mdmCh.FEC_Channel_Vietnamese_name__c, liveCh.FEC_Channel_Vietnamese_name__c,
            'Live Channel VN Name should match MDM');

        // Additional Field: Name, FEC_Unique_ID__c, FEC_Type__c
        FEC_MDM_Additional_Field__c mdmAf = [
            SELECT Name, FEC_Code__c, FEC_Unique_ID__c, FEC_Type__c
            FROM FEC_MDM_Additional_Field__c WHERE FEC_Code__c = 'AF-001' LIMIT 1
        ];
        FEC_Additional_Field__c liveAf = [
            SELECT Name, FEC_Code__c, FEC_Unique_ID__c, FEC_Type__c
            FROM FEC_Additional_Field__c WHERE FEC_Code__c = 'AF-001' LIMIT 1
        ];
        Assert.areEqual(mdmAf.Name, liveAf.Name,
            'Live AF Name should match MDM');
        Assert.areEqual(mdmAf.FEC_Unique_ID__c, liveAf.FEC_Unique_ID__c,
            'Live AF Unique ID should match MDM');
        Assert.areEqual(mdmAf.FEC_Type__c, liveAf.FEC_Type__c,
            'Live AF Type should match MDM');

        // Case Stage: Name, FEC_Code__c
        FEC_MDM_Case_Stage__c mdmCs = [
            SELECT Name, FEC_Code__c FROM FEC_MDM_Case_Stage__c WHERE FEC_Code__c = 'CS-001' LIMIT 1
        ];
        FEC_Case_Stage__c liveCs = [
            SELECT Name, FEC_Code__c FROM FEC_Case_Stage__c WHERE FEC_Code__c = 'CS-001' LIMIT 1
        ];
        Assert.areEqual(mdmCs.Name, liveCs.Name,
            'Live Case Stage Name should match MDM');
        Assert.areEqual(mdmCs.FEC_Code__c, liveCs.FEC_Code__c,
            'Live Case Stage FEC_Code__c should match MDM');

        // Action Button: Name, FEC_Code__c
        FEC_MDM_Action_Button__c mdmAb = [
            SELECT Name, FEC_Code__c FROM FEC_MDM_Action_Button__c WHERE FEC_Code__c = 'AB-001' LIMIT 1
        ];
        FEC_Action_Button__c liveAb = [
            SELECT Name, FEC_Code__c FROM FEC_Action_Button__c WHERE FEC_Code__c = 'AB-001' LIMIT 1
        ];
        Assert.areEqual(mdmAb.Name, liveAb.Name,
            'Live Action Button Name should match MDM');
        Assert.areEqual(mdmAb.FEC_Code__c, liveAb.FEC_Code__c,
            'Live Action Button FEC_Code__c should match MDM');
    }

    /**
     * Test 3: After push, verify Stage Change Live record has correct lookup IDs
     * pointing to Live Case Stage and Live Action Button (not MDM IDs)
     */
    @isTest
    static void testPushBatchLookupRemapping() {
        Test.startTest();
        FEC_PushMDMToLiveBatch batch = new FEC_PushMDMToLiveBatch();
        executeAllObjects(batch);
        Test.stopTest();

        // Get Live Case Stage IDs (remapped from MDM)
        FEC_Case_Stage__c liveCsPrev = [
            SELECT Id FROM FEC_Case_Stage__c WHERE FEC_Code__c = 'CS-001' LIMIT 1
        ];
        FEC_Case_Stage__c liveCsNext = [
            SELECT Id FROM FEC_Case_Stage__c WHERE FEC_Code__c = 'CS-002' LIMIT 1
        ];
        FEC_Action_Button__c liveAb = [
            SELECT Id FROM FEC_Action_Button__c WHERE FEC_Code__c = 'AB-001' LIMIT 1
        ];

        // Get Live Stage Change and verify lookups point to Live IDs
        List<FEC_Stage_Change__c> liveSc = [
            SELECT FEC_Previous_Stage__c, FEC_Action_Button__c, FEC_Next_Stage__c,
                   FEC_Next_Queue__c, FEC_Team_User_Group__c, FEC_Active__c
            FROM FEC_Stage_Change__c WHERE FEC_Code__c = 'SC-001'
        ];
        Assert.isFalse(liveSc.isEmpty(), 'Live Stage Change should exist after push');

        FEC_Stage_Change__c sc = liveSc[0];
        Assert.areEqual(liveCsPrev.Id, sc.FEC_Previous_Stage__c,
            'Stage Change Previous Stage should point to Live Case Stage CS-001');
        Assert.areEqual(liveCsNext.Id, sc.FEC_Next_Stage__c,
            'Stage Change Next Stage should point to Live Case Stage CS-002');
        Assert.areEqual(liveAb.Id, sc.FEC_Action_Button__c,
            'Stage Change Action Button should point to Live Action Button AB-001');
        Assert.areEqual('Queue1', sc.FEC_Next_Queue__c,
            'Stage Change Next Queue should be copied from MDM');
        Assert.areEqual('CA', sc.FEC_Team_User_Group__c,
            'Stage Change Team User Group should be copied from MDM');
        Assert.areEqual(true, sc.FEC_Active__c,
            'Stage Change Active should be copied from MDM');
    }

    /**
     * Test 4: After push, verify Stage Change Condition Live record has correct
     * FEC_Operator__c, FEC_Value__c, FEC_Value_Type__c, and lookups remapped correctly
     */
    @isTest
    static void testPushBatchStageChangeCondition() {
        Test.startTest();
        FEC_PushMDMToLiveBatch batch = new FEC_PushMDMToLiveBatch();
        executeAllObjects(batch);
        Test.stopTest();

        // Get Live Stage Change and Master Data Setting IDs for lookup verification
        List<FEC_Stage_Change__c> liveSc = [
            SELECT Id FROM FEC_Stage_Change__c WHERE FEC_Code__c = 'SC-001'
        ];
        Assert.isFalse(liveSc.isEmpty(), 'Live Stage Change should exist for SCC lookup');

        List<FEC_Master_Data_Setting__c> liveMds = [
            SELECT Id FROM FEC_Master_Data_Setting__c WHERE FEC_Code__c = 'MDS-001'
        ];
        Assert.isFalse(liveMds.isEmpty(), 'Live Master Data Setting should exist for SCC lookup');

        // Verify Stage Change Condition Live record
        List<FEC_Stage_Change_Condition__c> liveScc = [
            SELECT FEC_Code__c, FEC_Stage_Change__c, FEC_Master_Data_Setting__c,
                   FEC_Operator__c, FEC_Value__c, FEC_Value_Type__c
            FROM FEC_Stage_Change_Condition__c WHERE FEC_Code__c = 'SCC-001'
        ];
        Assert.isFalse(liveScc.isEmpty(),
            'Live Stage Change Condition should be created after push');

        FEC_Stage_Change_Condition__c scc = liveScc[0];
        Assert.areEqual('=', scc.FEC_Operator__c,
            'SCC Operator should match MDM source');
        Assert.areEqual('TestValue', scc.FEC_Value__c,
            'SCC Value should match MDM source');
        Assert.areEqual('String', scc.FEC_Value_Type__c,
            'SCC Value Type should match MDM source');
        Assert.areEqual(liveSc[0].Id, scc.FEC_Stage_Change__c,
            'SCC Stage Change lookup should point to Live Stage Change (remapped)');
        Assert.areEqual(liveMds[0].Id, scc.FEC_Master_Data_Setting__c,
            'SCC Master Data Setting lookup should point to Live MDS (remapped)');
    }
}