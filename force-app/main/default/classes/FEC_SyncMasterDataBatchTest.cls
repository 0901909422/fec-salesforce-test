@isTest
private class FEC_SyncMasterDataBatchTest {

    @testSetup
    static void setupTestData() {
        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;
        try {
            // 1. Business Process (Live)
            FEC_Business_Process__c bp = new FEC_Business_Process__c(
                Name = 'Live BP', FEC_Code__c = 'BP-001'
            );
            insert bp;

            // 2. Additional Field (Live)
            FEC_Additional_Field__c af = new FEC_Additional_Field__c(
                Name = 'Live AF', FEC_Code__c = 'AF-001', FEC_Unique_ID__c = 'AF-UID-001',
                FEC_Type__c = 'String', FEC_Field_Status__c = true
            );
            insert af;

            // 3. Product Type (Live)
            FEC_Product_Type__c pt = new FEC_Product_Type__c(
                Name = 'Live PT', FEC_Code__c = 'PT-001'
            );
            insert pt;

            // 4. Category (Live)
            FEC_Category__c cat = new FEC_Category__c(
                Name = 'Live Cat', FEC_Code__c = 'CAT-001'
            );
            insert cat;

            // 5. Sub Category (Live)
            FEC_Sub_Category__c scat = new FEC_Sub_Category__c(
                Name = 'Live SCat', FEC_Code__c = 'SCAT-001'
            );
            insert scat;

            // 6. Sub Code (Live)
            FEC_Sub_Code__c scode = new FEC_Sub_Code__c(
                Name = 'Live SCode', FEC_Code__c = 'SCODE-001'
            );
            insert scode;

            // 7. Channel (Live)
            FEC_Channel__c ch = new FEC_Channel__c(
                Name = 'Live Channel', FEC_Code__c = 'CH-001',
                FEC_Channel_ID__c = 'CH-ID-001', FEC_Channel_Status__c = true,
                FEC_Channel_Vietnamese_name__c = 'Kênh Live'
            );
            insert ch;

            // 8. Case Stage (Live, depends on BP)
            FEC_Case_Stage__c cs = new FEC_Case_Stage__c(
                Name = 'Live Stage', FEC_Code__c = 'CS-001',
                FEC_Business_Process__c = bp.Id
            );
            insert cs;

            // 8b. Second Case Stage for Next Stage lookup
            FEC_Case_Stage__c cs2 = new FEC_Case_Stage__c(
                Name = 'Live Stage 2', FEC_Code__c = 'CS-002',
                FEC_Business_Process__c = bp.Id
            );
            insert cs2;

            // 9. Nature of Case (Live, depends on BP)
            // Do NOT set FEC_Product_Type__c directly to avoid lookup filter validation
            FEC_Nature_Of_Case__c noc = new FEC_Nature_Of_Case__c(
                FEC_Code__c = 'NOC-001',
                FEC_Business_Process__c = bp.Id,
                FEC_Customer_Type__c = 'All'
            );
            insert noc;

            // 10. Additional Field List Value (Live, depends on AF)
            FEC_Additional_Field_List_Value__c aflv = new FEC_Additional_Field_List_Value__c(
                Name = 'Live AFLV', FEC_Code__c = 'AFLV-001',
                FEC_Order__c = 1, FEC_Name_VN__c = 'AFLV VN',
                FEC_Additional_Field__c = af.Id
            );
            insert aflv;

            // 11. Master Data Setting (Live, depends on CS)
            FEC_Master_Data_Setting__c mds = new FEC_Master_Data_Setting__c(
                FEC_Code__c = 'MDS-001',
                FEC_Field_Object_Name__c = 'Case',
                FEC_Field_Status__c = true,
                FEC_Stage_Name__c = cs.Id
            );
            insert mds;

            // 12. Action Button (Live)
            FEC_Action_Button__c ab = new FEC_Action_Button__c(
                Name = 'Live Action', FEC_Code__c = 'AB-001'
            );
            insert ab;

            // 13. Stage Change (Live, depends on CS, AB)
            FEC_Stage_Change__c sc = new FEC_Stage_Change__c(
                FEC_Code__c = 'SC-001',
                FEC_Previous_Stage__c = cs.Id,
                FEC_Action_Button__c = ab.Id,
                FEC_Next_Stage__c = cs2.Id,
                FEC_Next_Queue__c = 'Queue1',
                FEC_Team_User_Group__c = 'CA',
                FEC_Active__c = true
            );
            insert sc;

            // 14. Stage Change Condition (Live, depends on SC, MDS)
            FEC_Stage_Change_Condition__c scc = new FEC_Stage_Change_Condition__c(
                FEC_Code__c = 'SCC-001',
                FEC_Stage_Change__c = sc.Id,
                FEC_Master_Data_Setting__c = mds.Id,
                FEC_Operator__c = '=',
                FEC_Value__c = 'TestValue',
                FEC_Value_Type__c = 'String'
            );
            insert scc;

            // 15. Decision Rule (Live) — to cover text Id remap path
            // FEC_Key_ID__c stores BP Id as text → text Id remap remaps to MDM BP Id
            FEC_Decision_Rule__c dr = new FEC_Decision_Rule__c(
                FEC_Code__c = 'DR-001',
                FEC_Table_Key__c = 'STAGE_TRANSITION',
                FEC_Key_ID__c = String.valueOf(bp.Id),
                FEC_Priority__c = 1,
                FEC_Active__c = true
            );
            insert dr;

            // 16. Decision Condition (Live, depends on DR)
            FEC_Decision_Condition__c dc = new FEC_Decision_Condition__c(
                FEC_Code__c = 'DC-001',
                FEC_Decision_Rule__c = dr.Id,
                FEC_Type__c = 'Condition',
                FEC_Label__c = 'Status',
                FEC_Operator__c = '=',
                FEC_Value__c = 'New',
                FEC_Order__c = 1
            );
            insert dc;

        } finally {
            FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;
        }
    }

    /**
     * Helper: Call execute() directly for each object in dependency order.
     * Bypasses batch framework limitation in test context where only one
     * executeBatch call is allowed and batch size 14 puts all items in one scope.
     */
    private static void executeAllObjects(FEC_SyncMasterDataBatch batch) {
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
            FEC_ObjectConstants.OBJ_MDM_STAGE_CHANGE_CONDITION,
            FEC_ObjectConstants.OBJ_MDM_DECISION_RULE,
            FEC_ObjectConstants.OBJ_MDM_DECISION_CONDITION
        };
        for (String objName : executionOrder) {
            batch.execute(null, new List<String>{ objName });
        }
    }

    /**
     * Test 1: Run Sync batch, verify MDM records created with status 'Synced'
     */
    @isTest
    static void testSyncBatchExecution() {
        Test.startTest();
        FEC_SyncMasterDataBatch batch = new FEC_SyncMasterDataBatch();
        executeAllObjects(batch);
        Test.stopTest();

        // Verify MDM Business Process created with Synced status
        List<FEC_MDM_Business_Process__c> mdmBp = [
            SELECT Process_Change_Status__c FROM FEC_MDM_Business_Process__c
            WHERE FEC_Code__c = 'BP-001'
        ];
        Assert.isFalse(mdmBp.isEmpty(),
            'MDM Business Process should be created after sync');
        Assert.areEqual('Synced', mdmBp[0].Process_Change_Status__c,
            'MDM Business Process should have Synced status');

        // Verify MDM Product Type
        List<FEC_MDM_Product_Type__c> mdmPt = [
            SELECT Process_Change_Status__c FROM FEC_MDM_Product_Type__c
            WHERE FEC_Code__c = 'PT-001'
        ];
        Assert.isFalse(mdmPt.isEmpty(),
            'MDM Product Type should be created after sync');
        Assert.areEqual('Synced', mdmPt[0].Process_Change_Status__c,
            'MDM Product Type should have Synced status');

        // Verify MDM Case Stage
        List<FEC_MDM_Case_Stage__c> mdmCs = [
            SELECT Process_Change_Status__c FROM FEC_MDM_Case_Stage__c
            WHERE FEC_Code__c = 'CS-001'
        ];
        Assert.isFalse(mdmCs.isEmpty(),
            'MDM Case Stage should be created after sync');
        Assert.areEqual('Synced', mdmCs[0].Process_Change_Status__c,
            'MDM Case Stage should have Synced status');

        // Verify MDM Action Button
        List<FEC_MDM_Action_Button__c> mdmAb = [
            SELECT Process_Change_Status__c FROM FEC_MDM_Action_Button__c
            WHERE FEC_Code__c = 'AB-001'
        ];
        Assert.isFalse(mdmAb.isEmpty(),
            'MDM Action Button should be created after sync');
        Assert.areEqual('Synced', mdmAb[0].Process_Change_Status__c,
            'MDM Action Button should have Synced status');

        // Verify MDM Stage Change
        List<FEC_MDM_Stage_Change__c> mdmSc = [
            SELECT Process_Change_Status__c FROM FEC_MDM_Stage_Change__c
            WHERE FEC_Code__c = 'SC-001'
        ];
        Assert.isFalse(mdmSc.isEmpty(),
            'MDM Stage Change should be created after sync');
        Assert.areEqual('Synced', mdmSc[0].Process_Change_Status__c,
            'MDM Stage Change should have Synced status');

        // Verify MDM Stage Change Condition
        List<FEC_MDM_Stage_Change_Condition__c> mdmScc = [
            SELECT Process_Change_Status__c FROM FEC_MDM_Stage_Change_Condition__c
            WHERE FEC_Code__c = 'SCC-001'
        ];
        Assert.isFalse(mdmScc.isEmpty(),
            'MDM Stage Change Condition should be created after sync');
        Assert.areEqual('Synced', mdmScc[0].Process_Change_Status__c,
            'MDM Stage Change Condition should have Synced status');

        // Verify all 14 object types have MDM records
        Assert.isTrue([SELECT COUNT() FROM FEC_MDM_Business_Process__c] > 0,
            'MDM Business Process records should exist');
        Assert.isTrue([SELECT COUNT() FROM FEC_MDM_Additional_Field__c] > 0,
            'MDM Additional Field records should exist');
        Assert.isTrue([SELECT COUNT() FROM FEC_MDM_Product_Type__c] > 0,
            'MDM Product Type records should exist');
        Assert.isTrue([SELECT COUNT() FROM FEC_MDM_Category__c] > 0,
            'MDM Category records should exist');
        Assert.isTrue([SELECT COUNT() FROM FEC_MDM_Sub_Category__c] > 0,
            'MDM Sub Category records should exist');
        Assert.isTrue([SELECT COUNT() FROM FEC_MDM_Sub_Code__c] > 0,
            'MDM Sub Code records should exist');
        Assert.isTrue([SELECT COUNT() FROM FEC_MDM_Channel__c] > 0,
            'MDM Channel records should exist');
        Assert.isTrue([SELECT COUNT() FROM FEC_MDM_Nature_Of_Case__c] > 0,
            'MDM Nature Of Case records should exist');
        Assert.isTrue([SELECT COUNT() FROM FEC_MDM_Additional_Field_List_Value__c] > 0,
            'MDM Additional Field List Value records should exist');
        Assert.isTrue([SELECT COUNT() FROM FEC_MDM_Master_Data_Setting__c] > 0,
            'MDM Master Data Setting records should exist');
    }

    /**
     * Test 2: After sync, verify MDM records have same field values as Live source
     */
    @isTest
    static void testSyncBatchFieldConsistency() {
        Test.startTest();
        FEC_SyncMasterDataBatch batch = new FEC_SyncMasterDataBatch();
        executeAllObjects(batch);
        Test.stopTest();

        // Business Process: Name, FEC_Code__c
        FEC_Business_Process__c liveBp = [
            SELECT Name, FEC_Code__c
            FROM FEC_Business_Process__c WHERE FEC_Code__c = 'BP-001' LIMIT 1
        ];
        FEC_MDM_Business_Process__c mdmBp = [
            SELECT Name, FEC_Code__c
            FROM FEC_MDM_Business_Process__c WHERE FEC_Code__c = 'BP-001' LIMIT 1
        ];
        Assert.areEqual(liveBp.Name, mdmBp.Name,
            'MDM BP Name should match Live BP Name');
        Assert.areEqual(liveBp.FEC_Code__c, mdmBp.FEC_Code__c,
            'MDM BP FEC_Code__c should match Live');

        // Product Type: Name, FEC_Code__c
        FEC_Product_Type__c livePt = [
            SELECT Name, FEC_Code__c FROM FEC_Product_Type__c WHERE FEC_Code__c = 'PT-001' LIMIT 1
        ];
        FEC_MDM_Product_Type__c mdmPt = [
            SELECT Name, FEC_Code__c FROM FEC_MDM_Product_Type__c WHERE FEC_Code__c = 'PT-001' LIMIT 1
        ];
        Assert.areEqual(livePt.Name, mdmPt.Name,
            'MDM PT Name should match Live PT Name');
        Assert.areEqual(livePt.FEC_Code__c, mdmPt.FEC_Code__c,
            'MDM PT FEC_Code__c should match Live');

        // Channel: Name, FEC_Channel_ID__c, FEC_Channel_Vietnamese_name__c
        FEC_Channel__c liveCh = [
            SELECT Name, FEC_Code__c, FEC_Channel_ID__c, FEC_Channel_Vietnamese_name__c
            FROM FEC_Channel__c WHERE FEC_Code__c = 'CH-001' LIMIT 1
        ];
        FEC_MDM_Channel__c mdmCh = [
            SELECT Name, FEC_Code__c, FEC_Channel_ID__c, FEC_Channel_Vietnamese_name__c
            FROM FEC_MDM_Channel__c WHERE FEC_Code__c = 'CH-001' LIMIT 1
        ];
        Assert.areEqual(liveCh.Name, mdmCh.Name,
            'MDM Channel Name should match Live');
        Assert.areEqual(liveCh.FEC_Channel_ID__c, mdmCh.FEC_Channel_ID__c,
            'MDM Channel ID should match Live');
        Assert.areEqual(liveCh.FEC_Channel_Vietnamese_name__c, mdmCh.FEC_Channel_Vietnamese_name__c,
            'MDM Channel VN Name should match Live');

        // Additional Field: Name, FEC_Unique_ID__c, FEC_Type__c
        FEC_Additional_Field__c liveAf = [
            SELECT Name, FEC_Code__c, FEC_Unique_ID__c, FEC_Type__c
            FROM FEC_Additional_Field__c WHERE FEC_Code__c = 'AF-001' LIMIT 1
        ];
        FEC_MDM_Additional_Field__c mdmAf = [
            SELECT Name, FEC_Code__c, FEC_Unique_ID__c, FEC_Type__c
            FROM FEC_MDM_Additional_Field__c WHERE FEC_Code__c = 'AF-001' LIMIT 1
        ];
        Assert.areEqual(liveAf.Name, mdmAf.Name,
            'MDM AF Name should match Live');
        Assert.areEqual(liveAf.FEC_Unique_ID__c, mdmAf.FEC_Unique_ID__c,
            'MDM AF Unique ID should match Live');
        Assert.areEqual(liveAf.FEC_Type__c, mdmAf.FEC_Type__c,
            'MDM AF Type should match Live');

        // Case Stage: Name, FEC_Code__c
        FEC_Case_Stage__c liveCs = [
            SELECT Name, FEC_Code__c FROM FEC_Case_Stage__c WHERE FEC_Code__c = 'CS-001' LIMIT 1
        ];
        FEC_MDM_Case_Stage__c mdmCs = [
            SELECT Name, FEC_Code__c FROM FEC_MDM_Case_Stage__c WHERE FEC_Code__c = 'CS-001' LIMIT 1
        ];
        Assert.areEqual(liveCs.Name, mdmCs.Name,
            'MDM Case Stage Name should match Live');
        Assert.areEqual(liveCs.FEC_Code__c, mdmCs.FEC_Code__c,
            'MDM Case Stage FEC_Code__c should match Live');

        // Action Button: Name, FEC_Code__c
        FEC_Action_Button__c liveAb = [
            SELECT Name, FEC_Code__c FROM FEC_Action_Button__c WHERE FEC_Code__c = 'AB-001' LIMIT 1
        ];
        FEC_MDM_Action_Button__c mdmAb = [
            SELECT Name, FEC_Code__c FROM FEC_MDM_Action_Button__c WHERE FEC_Code__c = 'AB-001' LIMIT 1
        ];
        Assert.areEqual(liveAb.Name, mdmAb.Name,
            'MDM Action Button Name should match Live');
        Assert.areEqual(liveAb.FEC_Code__c, mdmAb.FEC_Code__c,
            'MDM Action Button FEC_Code__c should match Live');
    }

    /**
     * Test 3: Create MDM records with codes that don't exist in Live, run sync,
     * verify they're deleted (obsolete MDM cleanup)
     */
    @isTest
    static void testSyncBatchDeletesObsolete() {
        // Create obsolete MDM records that have no matching Live records
        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;
        try {
            insert new FEC_MDM_Business_Process__c(
                Name = 'Obsolete BP', FEC_Code__c = 'BP-OBSOLETE',
                Process_Change_Status__c = 'Update'
            );
            insert new FEC_MDM_Product_Type__c(
                Name = 'Obsolete PT', FEC_Code__c = 'PT-OBSOLETE',
                Process_Change_Status__c = 'New'
            );
            insert new FEC_MDM_Category__c(
                Name = 'Obsolete Cat', FEC_Code__c = 'CAT-OBSOLETE',
                Process_Change_Status__c = 'Update'
            );
            insert new FEC_MDM_Action_Button__c(
                Name = 'Obsolete AB', FEC_Code__c = 'AB-OBSOLETE',
                Process_Change_Status__c = 'New'
            );
        } finally {
            FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;
        }

        // Verify obsolete records exist before sync
        Assert.areEqual(1, [SELECT COUNT() FROM FEC_MDM_Business_Process__c WHERE FEC_Code__c = 'BP-OBSOLETE'],
            'Obsolete MDM BP should exist before sync');
        Assert.areEqual(1, [SELECT COUNT() FROM FEC_MDM_Product_Type__c WHERE FEC_Code__c = 'PT-OBSOLETE'],
            'Obsolete MDM PT should exist before sync');
        Assert.areEqual(1, [SELECT COUNT() FROM FEC_MDM_Category__c WHERE FEC_Code__c = 'CAT-OBSOLETE'],
            'Obsolete MDM Cat should exist before sync');
        Assert.areEqual(1, [SELECT COUNT() FROM FEC_MDM_Action_Button__c WHERE FEC_Code__c = 'AB-OBSOLETE'],
            'Obsolete MDM AB should exist before sync');

        Test.startTest();
        FEC_SyncMasterDataBatch batch = new FEC_SyncMasterDataBatch();
        executeAllObjects(batch);
        Test.stopTest();

        // Verify obsolete records are deleted after sync
        Assert.areEqual(0, [SELECT COUNT() FROM FEC_MDM_Business_Process__c WHERE FEC_Code__c = 'BP-OBSOLETE'],
            'Obsolete MDM BP should be deleted after sync');
        Assert.areEqual(0, [SELECT COUNT() FROM FEC_MDM_Product_Type__c WHERE FEC_Code__c = 'PT-OBSOLETE'],
            'Obsolete MDM PT should be deleted after sync');
        Assert.areEqual(0, [SELECT COUNT() FROM FEC_MDM_Category__c WHERE FEC_Code__c = 'CAT-OBSOLETE'],
            'Obsolete MDM Cat should be deleted after sync');
        Assert.areEqual(0, [SELECT COUNT() FROM FEC_MDM_Action_Button__c WHERE FEC_Code__c = 'AB-OBSOLETE'],
            'Obsolete MDM AB should be deleted after sync');

        // Verify valid records still exist (not deleted)
        Assert.isTrue([SELECT COUNT() FROM FEC_MDM_Business_Process__c WHERE FEC_Code__c = 'BP-001'] > 0,
            'Valid MDM BP should still exist after sync');
    }

    /**
     * Test 4: After sync, verify Stage Change Condition MDM record has correct
     * fields and lookups remapped to MDM layer
     */
    @isTest
    static void testSyncBatchStageChangeCondition() {
        Test.startTest();
        FEC_SyncMasterDataBatch batch = new FEC_SyncMasterDataBatch();
        executeAllObjects(batch);
        Test.stopTest();

        // Get MDM Stage Change and Master Data Setting IDs for lookup verification
        List<FEC_MDM_Stage_Change__c> mdmSc = [
            SELECT Id FROM FEC_MDM_Stage_Change__c WHERE FEC_Code__c = 'SC-001'
        ];
        Assert.isFalse(mdmSc.isEmpty(),
            'MDM Stage Change should exist for SCC lookup verification');

        List<FEC_MDM_Master_Data_Setting__c> mdmMds = [
            SELECT Id FROM FEC_MDM_Master_Data_Setting__c WHERE FEC_Code__c = 'MDS-001'
        ];
        Assert.isFalse(mdmMds.isEmpty(),
            'MDM Master Data Setting should exist for SCC lookup verification');

        // Verify Stage Change Condition MDM record
        List<FEC_MDM_Stage_Change_Condition__c> mdmScc = [
            SELECT FEC_Code__c, FEC_Stage_Change__c, FEC_Master_Data_Setting__c,
                   FEC_Operator__c, FEC_Value__c, FEC_Value_Type__c,
                   Process_Change_Status__c
            FROM FEC_MDM_Stage_Change_Condition__c WHERE FEC_Code__c = 'SCC-001'
        ];
        Assert.isFalse(mdmScc.isEmpty(),
            'MDM Stage Change Condition should be created after sync');

        FEC_MDM_Stage_Change_Condition__c scc = mdmScc[0];

        // Verify field values match Live source
        Assert.areEqual('=', scc.FEC_Operator__c,
            'MDM SCC Operator should match Live source');
        Assert.areEqual('TestValue', scc.FEC_Value__c,
            'MDM SCC Value should match Live source');
        Assert.areEqual('String', scc.FEC_Value_Type__c,
            'MDM SCC Value Type should match Live source');
        Assert.areEqual('Synced', scc.Process_Change_Status__c,
            'MDM SCC should have Synced status');

        // Verify lookups are remapped to MDM layer (not Live IDs)
        Assert.areEqual(mdmSc[0].Id, scc.FEC_Stage_Change__c,
            'MDM SCC Stage Change lookup should point to MDM Stage Change (remapped)');
        Assert.areEqual(mdmMds[0].Id, scc.FEC_Master_Data_Setting__c,
            'MDM SCC Master Data Setting lookup should point to MDM MDS (remapped)');
    }
}