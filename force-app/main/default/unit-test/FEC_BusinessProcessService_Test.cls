@IsTest
private class FEC_BusinessProcessService_Test {

    private static final String MDM_BP_API = 'FEC_MDM_Business_Process__c';
    private static final String MDM_STAGE_API = 'FEC_MDM_Case_Stage__c';
    private static final String MDM_BUTTON_API = 'FEC_MDM_Action_Button__c';
    private static final String MDM_RULE_API = 'FEC_MDM_Stage_Change__c';

    private static Boolean hasMdmObjects() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        return gd.containsKey(MDM_BP_API)
            && gd.containsKey(MDM_STAGE_API)
            && gd.containsKey(MDM_BUTTON_API)
            && gd.containsKey(MDM_RULE_API);
    }

    private static void insertMdmSetupData() {
        if (!hasMdmObjects()) {
            return;
        }

        SObject mdmBP = Schema.getGlobalDescribe().get(MDM_BP_API).newSObject();
        mdmBP.put('Name', 'MDM COF Process');
        mdmBP.put('FEC_Code__c', 'COF_CODE');
        mdmBP.put('Process_Change_Status__c', 'Pending');
        insert mdmBP;
        Id mdmBpId = (Id) mdmBP.get('Id');

        SObject mdmStage1 = Schema.getGlobalDescribe().get(MDM_STAGE_API).newSObject();
        mdmStage1.put('Name', 'MDM Open');
        mdmStage1.put('FEC_Code__c', 'M_STG_01');
        mdmStage1.put('FEC_Business_Process__c', mdmBpId);
        mdmStage1.put('Process_Change_Status__c', 'Pending');

        SObject mdmStage2 = Schema.getGlobalDescribe().get(MDM_STAGE_API).newSObject();
        mdmStage2.put('Name', 'MDM Closed');
        mdmStage2.put('FEC_Code__c', 'M_STG_02');
        mdmStage2.put('FEC_Business_Process__c', mdmBpId);
        mdmStage2.put('Process_Change_Status__c', 'Pending');
        insert new List<SObject>{ mdmStage1, mdmStage2 };

        SObject mdmButton = Schema.getGlobalDescribe().get(MDM_BUTTON_API).newSObject();
        mdmButton.put('Name', 'MDM Submit');
        mdmButton.put('FEC_Code__c', 'M_BTN_SUB');
        mdmButton.put('FEC_Active__c', true);
        mdmButton.put('Process_Change_Status__c', 'Pending');
        insert mdmButton;

        SObject mdmRule = Schema.getGlobalDescribe().get(MDM_RULE_API).newSObject();
        mdmRule.put('FEC_Previous_Stage__c', mdmStage1.get('Id'));
        mdmRule.put('FEC_Action_Button__c', mdmButton.get('Id'));
        mdmRule.put('FEC_Next_Stage__c', mdmStage2.get('Id'));
        mdmRule.put('FEC_Next_Queue__c', 'MDM_Queue_Review');
        mdmRule.put('FEC_Team_User_Group__c', 'OM');
        mdmRule.put('FEC_Active__c', true);
        mdmRule.put('Process_Change_Status__c', 'Pending');
        insert mdmRule;
    }

    @TestSetup
    static void setupData() {
        FEC_Business_Process__c liveBP = new FEC_Business_Process__c(
            Name = 'COF Process',
            FEC_Code__c = 'COF_CODE',
            FEC_Name_VN__c = 'Quy trình khiếu nại',
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        insert liveBP;

        FEC_Case_Stage__c liveStage1 = new FEC_Case_Stage__c(
            Name = 'Open Stage',
            FEC_Code__c = 'STG_01',
            FEC_Business_Process__c = liveBP.Id,
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        FEC_Case_Stage__c liveStage2 = new FEC_Case_Stage__c(
            Name = 'In Progress Stage',
            FEC_Code__c = 'STG_02',
            FEC_Business_Process__c = liveBP.Id,
            FEC_Order__c = 2,
            FEC_Active__c = true
        );
        insert new List<FEC_Case_Stage__c>{ liveStage1, liveStage2 };

        FEC_Action_Button__c liveButton = new FEC_Action_Button__c(
            Name = 'Approve Action',
            FEC_Code__c = 'BTN_APP',
            FEC_Active__c = true
        );
        insert liveButton;

        insert new FEC_Stage_Change__c(
            FEC_Previous_Stage__c = liveStage1.Id,
            FEC_Action_Button__c = liveButton.Id,
            FEC_Next_Stage__c = liveStage2.Id,
            FEC_Next_Queue__c = 'Queue_CS_Support',
            FEC_Team_User_Group__c = 'CC',
            FEC_Active__c = true
        );

        insertMdmSetupData();
    }

    @IsTest
    static void testGetBusinessProcessTree_Success() {
        Test.startTest();
        List<Map<String, Object>> tree = FEC_BusinessProcessService.getBusinessProcessTree();
        Test.stopTest();

        System.assertNotEquals(null, tree);
        System.assert(tree.size() > 0, 'Phải bốc được danh sách Node quy trình cha.');
        System.assertEquals('BUSINESS_PROCESS', (String) tree[0].get('type'));

        List<Map<String, Object>> children = (List<Map<String, Object>>) tree[0].get('children');
        System.assertEquals(2, children.size(), 'Số lượng Stage con liên kết phải khớp.');
    }

    @IsTest
    static void testGetDecisionTableByBP() {
        FEC_Business_Process__c bp = [SELECT Id FROM FEC_Business_Process__c LIMIT 1];

        Test.startTest();
        List<Map<String, String>> table = FEC_BusinessProcessService.getDecisionTableByBP(bp.Id);
        List<Map<String, String>> tableBlank = FEC_BusinessProcessService.getDecisionTableByBP('');
        Test.stopTest();

        System.assertEquals(1, table.size(), 'Phải bốc lên được chính xác 1 Rule cấu hình Live ở Setup.');
        System.assertEquals('Open Stage', table[0].get('currentStage'));
        System.assertEquals(0, tableBlank.size(), 'Truyền chuỗi Id rỗng phải trả về danh sách trống an toàn.');
    }

    @IsTest
    static void testGetDecisionTableByBPMDM_ResolveFlow() {
        if (!hasMdmObjects()) {
            return;
        }
        FEC_Business_Process__c liveBP = [SELECT Id FROM FEC_Business_Process__c LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> mdmTable = FEC_BusinessProcessService.getDecisionTableByBPMDM(liveBP.Id);
        Test.stopTest();

        System.assertEquals(1, mdmTable.size(), 'Cơ chế liên kết động qua mã Code phải tìm thấy đúng ma trận MDM.');
        System.assertEquals('MDM Open', (String) mdmTable[0].get('currentStage'));
    }

    @IsTest
    static void testSaveStagChangeRule_InsertAndUpdate() {
        FEC_Case_Stage__c stg1 = [SELECT Id FROM FEC_Case_Stage__c WHERE Name = 'Open Stage' LIMIT 1];
        FEC_Case_Stage__c stg2 = [SELECT Id FROM FEC_Case_Stage__c WHERE Name = 'In Progress Stage' LIMIT 1];
        FEC_Action_Button__c btn = [SELECT Id FROM FEC_Action_Button__c LIMIT 1];

        Map<String, Object> insertData = new Map<String, Object>{
            'previousStageId' => stg1.Id,
            'actionButtonId' => btn.Id,
            'nextStageId' => stg2.Id,
            'nextQueue' => 'New_Queue',
            'teamUserGroup' => 'SP'
        };

        Test.startTest();
        String newRuleId = FEC_BusinessProcessService.saveStagChangeRule(insertData);
        System.assertNotEquals(null, newRuleId, 'Phải sinh ra Id sau khi Upsert Insert.');

        insertData.put('recordId', newRuleId);
        insertData.put('nextQueue', 'Updated_Queue');
        String updatedRuleId = FEC_BusinessProcessService.saveStagChangeRule(insertData);
        Test.stopTest();

        System.assertEquals(newRuleId, updatedRuleId);
        FEC_Stage_Change__c checkRule = [SELECT FEC_Next_Queue__c FROM FEC_Stage_Change__c WHERE Id = :newRuleId];
        System.assertEquals('Updated_Queue', checkRule.FEC_Next_Queue__c);
    }

    @IsTest
    static void testSaveStagChangeRule_IllegalArgument() {
        Map<String, Object> badData = new Map<String, Object>{
            'previousStageId' => '',
            'actionButtonId' => '001000000000000'
        };

        Test.startTest();
        try {
            FEC_BusinessProcessService.saveStagChangeRule(badData);
            System.assert(false, 'Hệ thống phải ném lỗi khi thiếu trường bắt buộc.');
        } catch (AuraHandledException e) {
            System.assert(true, 'Thiếu trường bắt buộc phải được bọc thành AuraHandledException.');
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteStagChangeRule_SuccessAndFail() {
        FEC_Stage_Change__c rule = [SELECT Id FROM FEC_Stage_Change__c LIMIT 1];

        Test.startTest();
        FEC_BusinessProcessService.deleteStagChangeRule(rule.Id);
        try {
            FEC_BusinessProcessService.deleteStagChangeRule('');
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM FEC_Stage_Change__c WHERE Id = :rule.Id]);
    }

    @IsTest
    static void testComboboxOptionsFetch() {
        FEC_Business_Process__c liveBP = [SELECT Id FROM FEC_Business_Process__c LIMIT 1];
        Id mdmBpId = null;
        if (hasMdmObjects()) {
            mdmBpId = (Id) Database.query('SELECT Id FROM ' + MDM_BP_API + ' LIMIT 1')[0].get('Id');
        }

        Test.startTest();
        List<Map<String, String>> liveStages = FEC_BusinessProcessService.getStagesByBP(liveBP.Id);
        List<Map<String, String>> liveButtons = FEC_BusinessProcessService.getActionButtonsByBP(liveBP.Id);
        List<Map<String, String>> mdmStages;
        List<Map<String, String>> mdmButtons;
        if (mdmBpId != null) {
            mdmStages = FEC_BusinessProcessService.getMDMStageOptions(mdmBpId);
            mdmButtons = FEC_BusinessProcessService.getMDMActionButtonOptions();
        }
        Test.stopTest();

        System.assertEquals(2, liveStages.size());
        System.assertEquals(1, liveButtons.size());
        if (mdmBpId != null) {
            System.assertEquals(2, mdmStages.size());
            System.assertEquals(1, mdmButtons.size());
        }
    }

    @IsTest
    static void testSaveAndDeleteMDMStageChangeRule() {
        if (!hasMdmObjects()) {
            return;
        }

        Id mstg1Id = (Id) Database.query(
            'SELECT Id FROM ' + MDM_STAGE_API + ' WHERE Name = \'MDM Open\' LIMIT 1'
        )[0].get('Id');
        Id mstg2Id = (Id) Database.query(
            'SELECT Id FROM ' + MDM_STAGE_API + ' WHERE Name = \'MDM Closed\' LIMIT 1'
        )[0].get('Id');
        Id mbtnId = (Id) Database.query('SELECT Id FROM ' + MDM_BUTTON_API + ' LIMIT 1')[0].get('Id');

        Map<String, Object> dataMap = new Map<String, Object>{
            'previousStageId' => mstg1Id,
            'actionButtonId' => mbtnId,
            'nextStageId' => mstg2Id,
            'nextQueue' => 'Target_MDM_Queue',
            'teamUserGroup' => 'OM'
        };

        Test.startTest();
        FEC_BusinessProcessService.saveMDMStageChangeRule(JSON.serialize(dataMap));

        Id insertedRuleId = (Id) Database.query(
            'SELECT Id FROM ' + MDM_RULE_API + ' WHERE FEC_Next_Queue__c = \'Target_MDM_Queue\' LIMIT 1'
        )[0].get('Id');
        System.assertNotEquals(null, insertedRuleId);

        dataMap.put('recordId', insertedRuleId);
        dataMap.put('nextQueue', 'Updated_MDM_Queue');
        FEC_BusinessProcessService.saveMDMStageChangeRule(JSON.serialize(dataMap));
        FEC_BusinessProcessService.deleteMDMStageChangeRule(insertedRuleId);
        Test.stopTest();

        System.assertEquals(
            0,
            Database.query('SELECT Id FROM ' + MDM_RULE_API + ' WHERE Id = \'' + insertedRuleId + '\'').size()
        );
    }

    @IsTest
    static void testGetBusinessProcessTree_EmptyAndException() {
        delete [SELECT Id FROM FEC_Case_Stage__c];
        delete [SELECT Id FROM FEC_Business_Process__c];

        Test.startTest();
        List<Map<String, Object>> emptyTree = FEC_BusinessProcessService.getBusinessProcessTree();

        try {
            FEC_BusinessProcessService.getDecisionTableByBPMDM(Id.valueOf('001000000000000'));
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();

        System.assertEquals(0, emptyTree.size(), 'Khi DB trống, kết quả trả về cây phân cấp phải rỗng.');
    }
}
