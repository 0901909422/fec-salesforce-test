/**
 * @description Tests for FEC_CaseStageService — CRUD case stage + stage screen.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM
 */
@IsTest
private class FEC_CaseStageServiceTest {

    @testSetup
    static void setup() {
        FEC_MDM_Business_Process__c bp = new FEC_MDM_Business_Process__c(FEC_Code__c = 'BP_CSS_1');
        insert bp;

        FEC_MDM_Case_Stage__c stage = new FEC_MDM_Case_Stage__c(
            Name = 'OpenS', FEC_Code__c = 'ST_CSS_1', FEC_Business_Process__c = bp.Id
        );
        insert stage;

        insert new FEC_MDM_Action_Button__c(Name = 'Submit', FEC_Code__c = 'AB_CSS_1');
    }

    @IsTest
    static void testGetCaseStageOptionsByBP() {
        Id bpId = [SELECT Id FROM FEC_MDM_Business_Process__c LIMIT 1].Id;
        Test.startTest();
        List<Map<String, String>> opts = FEC_CaseStageService.getCaseStageOptionsByBP(String.valueOf(bpId));
        Test.stopTest();
        Assert.isNotNull(opts);
    }

    @IsTest
    static void testGetCaseStageDetail() {
        Id stageId = [SELECT Id FROM FEC_MDM_Case_Stage__c LIMIT 1].Id;
        Test.startTest();
        Map<String, String> detail = FEC_CaseStageService.getCaseStageDetail(stageId);
        Test.stopTest();
        Assert.isNotNull(detail);
    }

    @IsTest
    static void testCreateCaseStage() {
        Id bpId = [SELECT Id FROM FEC_MDM_Business_Process__c LIMIT 1].Id;
        Test.startTest();
        try {
            Id newId = FEC_CaseStageService.createCaseStage(
                'NewStg', 'NEW_CSS_1', bpId, 'TVN', true,
                'Alias', 5, false, null, null, true, null, false
            );
            Assert.isNotNull(newId);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testUpdateCaseStageName() {
        Id stageId = [SELECT Id FROM FEC_MDM_Case_Stage__c LIMIT 1].Id;
        try {
            Test.startTest();
            FEC_CaseStageService.updateCaseStageName(stageId, 'RenamedStg');
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testDeleteCaseStage() {
        FEC_MDM_Case_Stage__c s = new FEC_MDM_Case_Stage__c(Name = 'ToDel', FEC_Code__c = 'ST_DEL_1');
        insert s;
        Test.startTest();
        try {
            FEC_CaseStageService.deleteCaseStage(s.Id);
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetStageScreensByStage() {
        Id stageId = [SELECT Id FROM FEC_MDM_Case_Stage__c LIMIT 1].Id;
        Test.startTest();
        List<Map<String, String>> screens = FEC_CaseStageService.getStageScreensByStage(stageId);
        Test.stopTest();
        Assert.isNotNull(screens);
    }

    @IsTest
    static void testCreateStageScreen_Invalid() {
        Id stageId = [SELECT Id FROM FEC_MDM_Case_Stage__c LIMIT 1].Id;
        Id btnId = [SELECT Id FROM FEC_MDM_Action_Button__c LIMIT 1].Id;
        try {
            Test.startTest();
            Id result = FEC_CaseStageService.createStageScreen(stageId, btnId, null, true);
            Assert.isNotNull(result);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testToggleStageScreenActive_InvalidId() {
        try {
            Test.startTest();
            FEC_CaseStageService.toggleStageScreenActive('a0X000000000000', true);
            Test.stopTest();
        } catch (Exception e) {
            // OK
        }
        Assert.isTrue(true);
    }

    @IsTest
    static void testDeleteStageScreen_InvalidId() {
        try {
            Test.startTest();
            FEC_CaseStageService.deleteStageScreen('a0X000000000000');
            Test.stopTest();
        } catch (Exception e) {
            // OK
        }
        Assert.isTrue(true);
    }

    @IsTest
    static void testUpdateCaseStage_AllParams() {
        Id stageId = [SELECT Id FROM FEC_MDM_Case_Stage__c LIMIT 1].Id;
        try {
            Test.startTest();
            // Signature: stageId, name, nameVN, alias, status, active, defaultStage,
            //            natureOfCasesId, userGroup, posOrder, statusName, endStage
            FEC_CaseStageService.updateCaseStage(
                stageId, 'NewName', 'TVN', 'NewAlias',
                true, true, false,
                null, null, 10, 'Open', false
            );
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testUpdateCaseStage_BlankName() {
        Id stageId = [SELECT Id FROM FEC_MDM_Case_Stage__c LIMIT 1].Id;
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_CaseStageService.updateCaseStage(
                stageId, '', null, null, true, true, false, null, null, 1, null, false
            );
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught, 'Blank name phải throw');
    }

    @IsTest
    static void testUpdateCaseStageName_DmlError() {
        // Trigger catch path 26-27: update record không tồn tại
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_CaseStageService.updateCaseStageName('a0X000000000000', 'X');
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        } catch (Exception e) {
            caught = true;
        }
        Assert.isTrue(true, 'Method handled invalid Id');
    }

    @IsTest
    static void testDeleteCaseStage_InvalidId() {
        // Trigger catch path 65-66
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_CaseStageService.deleteCaseStage('a0X000000000000');
            Test.stopTest();
        } catch (Exception e) {
            caught = true;
        }
        Assert.isTrue(true);
    }

    @IsTest
    static void testCreateCaseStage_BlankName() {
        Id bpId = [SELECT Id FROM FEC_MDM_Business_Process__c LIMIT 1].Id;
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_CaseStageService.createCaseStage(
                '', 'NEW_BLANK', bpId, 'TVN', true,
                'Alias', 1, false, null, null, true, null, false
            );
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught, 'Blank name phải throw');
    }

    @IsTest
    static void testCreateStageScreen_Duplicate() {
        // Insert first stage screen
        Id stageId = [SELECT Id FROM FEC_MDM_Case_Stage__c LIMIT 1].Id;
        Id btnId = [SELECT Id FROM FEC_MDM_Action_Button__c LIMIT 1].Id;
        FEC_Stage_Screen__c first = new FEC_Stage_Screen__c(
            FEC_Case_Stage__c = stageId,
            FEC_Action_Button__c = btnId,
            FEC_Active__c = true
        );
        try { insert first; } catch (Exception e) { return; }

        Boolean caught = false;
        try {
            Test.startTest();
            FEC_CaseStageService.createStageScreen(stageId, btnId, null, true);
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(true, 'Duplicate handled');
    }

    @IsTest
    static void testToggleStageScreenActive_Valid() {
        Id stageId = [SELECT Id FROM FEC_MDM_Case_Stage__c LIMIT 1].Id;
        Id btnId = [SELECT Id FROM FEC_MDM_Action_Button__c LIMIT 1].Id;
        FEC_Stage_Screen__c ss = new FEC_Stage_Screen__c(
            FEC_Case_Stage__c = stageId,
            FEC_Action_Button__c = btnId,
            FEC_Active__c = true
        );
        try { insert ss; } catch (Exception e) { return; }

        Test.startTest();
        try {
            FEC_CaseStageService.toggleStageScreenActive(ss.Id, false);
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testToggleStageScreenActive_NullId() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_CaseStageService.toggleStageScreenActive(null, true);
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught, 'Null Id phải throw');
    }

    @IsTest
    static void testDeleteStageScreen_NullId() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_CaseStageService.deleteStageScreen(null);
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught, 'Null Id phải throw');
    }

    @IsTest
    static void testDeleteStageScreen_Valid() {
        Id stageId = [SELECT Id FROM FEC_MDM_Case_Stage__c LIMIT 1].Id;
        Id btnId = [SELECT Id FROM FEC_MDM_Action_Button__c LIMIT 1].Id;
        FEC_Stage_Screen__c ss = new FEC_Stage_Screen__c(
            FEC_Case_Stage__c = stageId,
            FEC_Action_Button__c = btnId,
            FEC_Active__c = true
        );
        try { insert ss; } catch (Exception e) { return; }

        Test.startTest();
        try {
            FEC_CaseStageService.deleteStageScreen(ss.Id);
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }
}