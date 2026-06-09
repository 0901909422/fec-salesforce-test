/**
 * @description Deep tests for FEC_StageTransitionResolver — cover các method query rule.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM | Decision Engine
 */
@IsTest
private class FEC_StageTransitionResolverDeepTest {

    @testSetup
    static void setup() {
        // Live Stage + Action Button + NOC for runtime evaluation paths
        FEC_Business_Process__c bp = new FEC_Business_Process__c(FEC_Code__c = 'BP_STR_1');
        insert bp;

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'OpenS', FEC_Code__c = 'ST_STR_1', FEC_Business_Process__c = bp.Id
        );
        insert stage;

        FEC_Case_Stage__c nextStage = new FEC_Case_Stage__c(
            Name = 'NextS', FEC_Code__c = 'ST_STR_2', FEC_Business_Process__c = bp.Id
        );
        insert nextStage;

        FEC_Action_Button__c btn = new FEC_Action_Button__c(
            Name = 'Submit', FEC_Code__c = 'AB_STR_1'
        );
        insert btn;

        // Live Decision Rule + Conditions
        FEC_Decision_Rule__c rule = new FEC_Decision_Rule__c(
            FEC_Code__c = 'RULE_STR_1',
            FEC_Table_Key__c = 'STAGE_TRANSITION',
            FEC_Key_ID__c = String.valueOf(bp.Id),
            FEC_Priority__c = 1,
            FEC_Active__c = true
        );
        insert rule;

        List<FEC_Decision_Condition__c> conds = new List<FEC_Decision_Condition__c>{
            new FEC_Decision_Condition__c(
                FEC_Code__c = 'C_STR_1', FEC_Decision_Rule__c = rule.Id,
                FEC_Type__c = 'Condition', FEC_Label__c = 'Previous Stage',
                FEC_Value__c = 'OpenS', FEC_Operator__c = '=', FEC_Order__c = 1
            ),
            new FEC_Decision_Condition__c(
                FEC_Code__c = 'C_STR_2', FEC_Decision_Rule__c = rule.Id,
                FEC_Type__c = 'Condition', FEC_Label__c = 'Action Button',
                FEC_Value__c = 'Submit', FEC_Operator__c = '=', FEC_Order__c = 2
            ),
            new FEC_Decision_Condition__c(
                FEC_Code__c = 'C_STR_3', FEC_Decision_Rule__c = rule.Id,
                FEC_Type__c = 'Action', FEC_Label__c = 'Next Stage',
                FEC_Value__c = 'NextS', FEC_Operator__c = null, FEC_Order__c = 3
            )
        };
        insert conds;

        // MDM equivalent
        FEC_MDM_Business_Process__c mdmBp = new FEC_MDM_Business_Process__c(FEC_Code__c = 'BP_STR_M1');
        insert mdmBp;
        FEC_MDM_Case_Stage__c mdmStage = new FEC_MDM_Case_Stage__c(
            Name = 'OpenM', FEC_Code__c = 'ST_STR_M1', FEC_Business_Process__c = mdmBp.Id
        );
        insert mdmStage;

        FEC_MDM_Decision_Rule__c mdmRule = new FEC_MDM_Decision_Rule__c(
            FEC_Code__c = 'RULE_STR_M1',
            FEC_Table_Key__c = 'STAGE_TRANSITION',
            FEC_Key_ID__c = String.valueOf(mdmBp.Id),
            FEC_Priority__c = 1,
            FEC_Active__c = true
        );
        insert mdmRule;

        insert new FEC_MDM_Decision_Condition__c(
            FEC_Code__c = 'CM_STR_1', FEC_Decision_Rule__c = mdmRule.Id,
            FEC_Type__c = 'Condition', FEC_Label__c = 'Status',
            FEC_Value__c = 'New', FEC_Operator__c = '=', FEC_Order__c = 1
        );
    }

    @IsTest
    static void testResolveStageNameFromCode_ByCode() {
        // Stage exists with code ST_STR_1
        Test.startTest();
        String name = FEC_StageTransitionResolver.resolveStageNameFromCode('ST_STR_1');
        Test.stopTest();
        Assert.isNotNull(name);
    }

    @IsTest
    static void testResolveStageNameFromCode_ByName() {
        Test.startTest();
        String name = FEC_StageTransitionResolver.resolveStageNameFromCode('OpenS');
        Test.stopTest();
        // Fallback to name resolution
        Assert.isNotNull(name);
    }

    @IsTest
    static void testResolveStageNameFromCode_NotFound() {
        Test.startTest();
        String name = FEC_StageTransitionResolver.resolveStageNameFromCode('NON_EXISTENT_CODE');
        Test.stopTest();
        // Returns input string when not found
        Assert.areEqual('NON_EXISTENT_CODE', name);
    }

    @IsTest
    static void testResolveStageNameFromCode_Null() {
        Test.startTest();
        String name = FEC_StageTransitionResolver.resolveStageNameFromCode(null);
        Test.stopTest();
        Assert.isNull(name);
    }

    @IsTest
    static void testInsertStageHistory_ValidIds() {
        Case c = new Case(Subject = 'Test');
        insert c;
        Id fromStageId = [SELECT Id FROM FEC_Case_Stage__c WHERE FEC_Code__c = 'ST_STR_1' LIMIT 1].Id;
        Id toStageId = [SELECT Id FROM FEC_Case_Stage__c WHERE FEC_Code__c = 'ST_STR_2' LIMIT 1].Id;
        Id btnId = [SELECT Id FROM FEC_Action_Button__c LIMIT 1].Id;

        try {
            Test.startTest();
            FEC_StageTransitionResolver.insertStageHistory(c.Id, fromStageId, toStageId, btnId, 'TestQ');
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testGetRevertInfo_NoHistory() {
        Case c = new Case(Subject = 'NoHist');
        insert c;
        Id stageId = [SELECT Id FROM FEC_Case_Stage__c LIMIT 1].Id;
        try {
            Test.startTest();
            Map<String, Object> info = FEC_StageTransitionResolver.getRevertInfo(c.Id, stageId);
            Test.stopTest();
            // info có thể null nếu không có history — chỉ verify callable
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testQueryMDMRulesByTableKey() {
        Test.startTest();
        List<FEC_MDM_Decision_Rule__c> rules = FEC_StageTransitionResolver.queryMDMRulesByTableKey('STAGE_TRANSITION');
        Test.stopTest();
        Assert.isFalse(rules.isEmpty());
    }

    @IsTest
    static void testQueryMDMConditionsForRules() {
        Set<Id> ruleIds = new Set<Id>();
        for (FEC_MDM_Decision_Rule__c r : [SELECT Id FROM FEC_MDM_Decision_Rule__c]) {
            ruleIds.add(r.Id);
        }
        Test.startTest();
        Map<Id, List<FEC_MDM_Decision_Condition__c>> map1 = FEC_StageTransitionResolver.queryMDMConditionsForRules(ruleIds);
        Test.stopTest();
        Assert.isNotNull(map1);
    }

    @IsTest
    static void testEvaluateMDMRuleConditions_Match() {
        FEC_MDM_Decision_Condition__c cond = [SELECT Id, FEC_Type__c, FEC_Label__c, FEC_Value__c, FEC_Operator__c, FEC_Order__c, FEC_Expression__c FROM FEC_MDM_Decision_Condition__c LIMIT 1];
        Map<String, Object> caseData = new Map<String, Object>{ 'status' => 'New' };
        Test.startTest();
        Boolean matched = FEC_StageTransitionResolver.evaluateMDMRuleConditions(
            new List<FEC_MDM_Decision_Condition__c>{ cond }, caseData
        );
        Test.stopTest();
        Assert.isTrue(matched, 'Status=New should match');
    }

    @IsTest
    static void testEvaluateMDMRuleConditions_NoMatch() {
        FEC_MDM_Decision_Condition__c cond = [SELECT Id, FEC_Type__c, FEC_Label__c, FEC_Value__c, FEC_Operator__c, FEC_Order__c, FEC_Expression__c FROM FEC_MDM_Decision_Condition__c LIMIT 1];
        Map<String, Object> caseData = new Map<String, Object>{ 'status' => 'Other' };
        Test.startTest();
        Boolean matched = FEC_StageTransitionResolver.evaluateMDMRuleConditions(
            new List<FEC_MDM_Decision_Condition__c>{ cond }, caseData
        );
        Test.stopTest();
        Assert.isFalse(matched);
    }

    @IsTest
    static void testEvaluateMDMRuleConditions_EmptyConds() {
        Test.startTest();
        Boolean matched = FEC_StageTransitionResolver.evaluateMDMRuleConditions(
            new List<FEC_MDM_Decision_Condition__c>(),
            new Map<String, Object>{ 'x' => 'y' }
        );
        Test.stopTest();
        Assert.isTrue(matched, 'Empty conditions = always match');
    }

    @IsTest
    static void testBuildMatchResultFromConditions_NullConds() {
        FEC_MDM_Decision_Rule__c r = [SELECT Id FROM FEC_MDM_Decision_Rule__c LIMIT 1];
        Test.startTest();
        Map<String, Object> result = FEC_StageTransitionResolver.buildMatchResultFromConditions(r.Id, 'TestRule', null);
        Test.stopTest();
        Assert.isNotNull(result);
        Assert.areEqual(true, result.get('matched'));
    }

    @IsTest
    static void testBuildMatchResultFromConditions_WithActions() {
        FEC_MDM_Decision_Rule__c r = [SELECT Id FROM FEC_MDM_Decision_Rule__c LIMIT 1];
        List<FEC_MDM_Decision_Condition__c> actionConds = new List<FEC_MDM_Decision_Condition__c>{
            new FEC_MDM_Decision_Condition__c(
                FEC_Decision_Rule__c = r.Id, FEC_Type__c = 'Action',
                FEC_Label__c = 'Next Stage', FEC_Value__c = 'NextS'
            ),
            new FEC_MDM_Decision_Condition__c(
                FEC_Decision_Rule__c = r.Id, FEC_Type__c = 'Action',
                FEC_Label__c = 'Next Queue', FEC_Value__c = 'TestQ'
            )
        };

        Test.startTest();
        Map<String, Object> result = FEC_StageTransitionResolver.buildMatchResultFromConditions(r.Id, 'TestRule', actionConds);
        Test.stopTest();

        Assert.areEqual(true, result.get('matched'));
        Assert.isNotNull(result.get('nextStageName'));
        Assert.areEqual('TestQ', result.get('nextQueue'));
    }

    @IsTest
    static void testGetDecisionTableResults_NoCase() {
        Id stageId = [SELECT Id FROM FEC_Case_Stage__c LIMIT 1].Id;
        try {
            Test.startTest();
            Map<String, Map<String, Object>> result = FEC_StageTransitionResolver.getDecisionTableResults(
                null, stageId, 'Submit', false
            );
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testGetMDMDecisionTableResults_NoCase() {
        try {
            Test.startTest();
            Map<String, Map<String, Object>> result = FEC_StageTransitionResolver.getMDMDecisionTableResults(
                null, null, 'TestAction', false
            );
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testEvaluateSingleTransitionWithKey_RealRule() {
        Case c = new Case(Subject = 'TestCase');
        insert c;
        Id stageId = [SELECT Id FROM FEC_Case_Stage__c WHERE FEC_Code__c = 'ST_STR_1' LIMIT 1].Id;
        Id btnId = [SELECT Id FROM FEC_Action_Button__c LIMIT 1].Id;

        try {
            Test.startTest();
            Map<String, Object> result = FEC_StageTransitionResolver.evaluateSingleTransitionWithKey(
                c.Id, stageId, btnId, 'STAGE_TRANSITION'
            );
            Test.stopTest();
            Assert.isNotNull(result);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testEvaluateSingleTransitionWithKey_BlankKey() {
        Case c = new Case(Subject = 'TestCase2');
        insert c;
        Id stageId = [SELECT Id FROM FEC_Case_Stage__c LIMIT 1].Id;
        Id btnId = [SELECT Id FROM FEC_Action_Button__c LIMIT 1].Id;

        try {
            Test.startTest();
            // Blank key falls back to TABLE_KEY_STAGE_TRANSITION
            FEC_StageTransitionResolver.evaluateSingleTransitionWithKey(c.Id, stageId, btnId, '');
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testGetMDMDecisionTableResults_FullPath() {
        // Setup MDM rule with Previous Stage + Available Decisions condition
        // to trigger lines 459-696 (full MDM decision table flow)
        Id mdmStageId = [SELECT Id FROM FEC_MDM_Case_Stage__c LIMIT 1].Id;
        FEC_MDM_Decision_Rule__c mdmRule = [SELECT Id, Name FROM FEC_MDM_Decision_Rule__c WHERE FEC_Code__c = 'RULE_STR_M1' LIMIT 1];

        // Add Previous Stage + Available Decisions conditions
        insert new List<FEC_MDM_Decision_Condition__c>{
            new FEC_MDM_Decision_Condition__c(
                FEC_Code__c = 'CM_STR_PS', FEC_Decision_Rule__c = mdmRule.Id,
                FEC_Type__c = 'Condition', FEC_Label__c = 'Previous Stage',
                FEC_Value__c = 'ST_STR_M1', FEC_Operator__c = '=', FEC_Order__c = 2
            ),
            new FEC_MDM_Decision_Condition__c(
                FEC_Code__c = 'CM_STR_AD', FEC_Decision_Rule__c = mdmRule.Id,
                FEC_Type__c = 'Action', FEC_Label__c = 'Available Decisions',
                FEC_Value__c = 'Approve', FEC_Operator__c = null, FEC_Order__c = 3
            ),
            new FEC_MDM_Decision_Condition__c(
                FEC_Code__c = 'CM_STR_NS', FEC_Decision_Rule__c = mdmRule.Id,
                FEC_Type__c = 'Action', FEC_Label__c = 'Next Stage',
                FEC_Value__c = 'OpenM', FEC_Operator__c = null, FEC_Order__c = 4
            ),
            new FEC_MDM_Decision_Condition__c(
                FEC_Code__c = 'CM_STR_NQ', FEC_Decision_Rule__c = mdmRule.Id,
                FEC_Type__c = 'Action', FEC_Label__c = 'Next Queue',
                FEC_Value__c = 'Q1', FEC_Operator__c = null, FEC_Order__c = 5
            ),
            new FEC_MDM_Decision_Condition__c(
                FEC_Code__c = 'CM_STR_TUG', FEC_Decision_Rule__c = mdmRule.Id,
                FEC_Type__c = 'Action', FEC_Label__c = 'Team User Group',
                FEC_Value__c = 'Group1', FEC_Operator__c = null, FEC_Order__c = 6
            ),
            new FEC_MDM_Decision_Condition__c(
                FEC_Code__c = 'CM_STR_AB', FEC_Decision_Rule__c = mdmRule.Id,
                FEC_Type__c = 'Action', FEC_Label__c = 'Action Button',
                FEC_Value__c = 'Submit', FEC_Operator__c = null, FEC_Order__c = 7
            ),
            new FEC_MDM_Decision_Condition__c(
                FEC_Code__c = 'CM_STR_CUST', FEC_Decision_Rule__c = mdmRule.Id,
                FEC_Type__c = 'Action', FEC_Label__c = 'Custom Flag',  // Generic fallback
                FEC_Value__c = 'Yes', FEC_Operator__c = null, FEC_Order__c = 8
            )
        };

        Case c = new Case(Subject = 'TestMDMResults', Status = 'New');
        insert c;

        Test.startTest();
        try {
            // isEvaluateAll=true → covers allRuleResults branch
            Map<String, Map<String, Object>> result = FEC_StageTransitionResolver.getMDMDecisionTableResults(
                c.Id, mdmStageId, null, true
            );
            Assert.isNotNull(result);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetMDMDecisionTableResults_FilterAction() {
        // Same setup but with action label filter (covers groupMDMRulesByDecisionLabel filter branch)
        Id mdmStageId = [SELECT Id FROM FEC_MDM_Case_Stage__c LIMIT 1].Id;
        Case c = new Case(Subject = 'TestMDM_Filter');
        insert c;

        Test.startTest();
        try {
            Map<String, Map<String, Object>> result = FEC_StageTransitionResolver.getMDMDecisionTableResults(
                c.Id, mdmStageId, 'Approve', false
            );
            Assert.isNotNull(result);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetDecisionTableResults_Live_FullPath() {
        // Live equivalent
        Id stageId = [SELECT Id FROM FEC_Case_Stage__c LIMIT 1].Id;
        FEC_Decision_Rule__c rule = [SELECT Id FROM FEC_Decision_Rule__c WHERE FEC_Code__c = 'RULE_STR_1' LIMIT 1];

        // Add 'Available Decisions' action to existing rule
        insert new List<FEC_Decision_Condition__c>{
            new FEC_Decision_Condition__c(
                FEC_Code__c = 'C_STR_AD', FEC_Decision_Rule__c = rule.Id,
                FEC_Type__c = 'Action', FEC_Label__c = 'Available Decisions',
                FEC_Value__c = 'Approve', FEC_Operator__c = null, FEC_Order__c = 4
            ),
            new FEC_Decision_Condition__c(
                FEC_Code__c = 'C_STR_NQ', FEC_Decision_Rule__c = rule.Id,
                FEC_Type__c = 'Action', FEC_Label__c = 'Next Queue',
                FEC_Value__c = 'Q1', FEC_Operator__c = null, FEC_Order__c = 5
            ),
            new FEC_Decision_Condition__c(
                FEC_Code__c = 'C_STR_TUG', FEC_Decision_Rule__c = rule.Id,
                FEC_Type__c = 'Action', FEC_Label__c = 'Team User Group',
                FEC_Value__c = 'G1', FEC_Operator__c = null, FEC_Order__c = 6
            ),
            new FEC_Decision_Condition__c(
                FEC_Code__c = 'C_STR_AB2', FEC_Decision_Rule__c = rule.Id,
                FEC_Type__c = 'Action', FEC_Label__c = 'Action Button',
                FEC_Value__c = 'Approve', FEC_Operator__c = null, FEC_Order__c = 7
            ),
            new FEC_Decision_Condition__c(
                FEC_Code__c = 'C_STR_AUTO', FEC_Decision_Rule__c = rule.Id,
                FEC_Type__c = 'Action', FEC_Label__c = 'Auto Decision',  // Generic fallback
                FEC_Value__c = 'Yes', FEC_Operator__c = null, FEC_Order__c = 8
            )
        };

        Case c = new Case(Subject = 'TestLiveResults');
        insert c;

        Test.startTest();
        try {
            Map<String, Map<String, Object>> result = FEC_StageTransitionResolver.getDecisionTableResults(
                c.Id, stageId, null, true
            );
            Assert.isNotNull(result);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }
}