@IsTest
private class FEC_CofGsrRoutePrepareService_Test {

    @TestSetup
    static void setupData() {
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = 'CC',
            FEC_Active__c = true
        );
        insert pt;
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Request',
            FEC_Code__c = 'Request',
            FEC_Active__c = true
        );
        insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'RC27',
            FEC_Code__c = 'RC27',
            FEC_Active__c = true
        );
        insert subCat;
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'RC27.01',
            FEC_Code__c = 'RC27.01',
            FEC_Active__c = true
        );
        insert subCode;

        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'COF Prepare BP',
            FEC_Code__c = 'COFBP',
            FEC_Active__c = true
        );
        insert bp;

        FEC_Business_Process__c gsrBp = new FEC_Business_Process__c(
            Name = 'GSR Process',
            FEC_Code__c = 'GSR01',
            FEC_Active__c = true
        );
        insert gsrBp;

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true
        );
        insert noc;

        FEC_Nature_of_Case__c gsrNoc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Business_Process__c = gsrBp.Id,
            FEC_Active__c = true
        );
        insert gsrNoc;

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'Stage 1 Open',
            FEC_Code__c = 'STG01',
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Active__c = true,
            FEC_Business_Process__c = bp.Id
        );
        insert stage;

        FEC_Case_Stage__c gsrStage1 = new FEC_Case_Stage__c(
            Name = 'GSR Stage 1',
            FEC_Code__c = 'GSRSTG1',
            FEC_Nature_of_Cases__c = gsrNoc.Id,
            FEC_Active__c = true,
            FEC_Business_Process__c = gsrBp.Id
        );
        insert gsrStage1;

        insert new List<FEC_Master_Data_Setting__c>{
            new FEC_Master_Data_Setting__c(
                FEC_Nature_Of_Case__c = noc.Id,
                FEC_Stage_Name__c = stage.Id,
                FEC_Section__c = 'Account Information',
                FEC_Sub_Section__c = 'Account Infor',
                FEC_Field_Object_Name__c = 'Case',
                FEC_Field_API_Name__c = 'Subject',
                FEC_Field_Label_Name__c = 'Subject Label',
                FEC_Field_Status__c = true,
                FEC_Field_Editable__c = true
            ),
            new FEC_Master_Data_Setting__c(
                FEC_Nature_Of_Case__c = gsrNoc.Id,
                FEC_Stage_Name__c = gsrStage1.Id,
                FEC_Section__c = 'Account Information',
                FEC_Sub_Section__c = 'Account Infor',
                FEC_Field_Object_Name__c = 'Case',
                FEC_Field_API_Name__c = 'Subject',
                FEC_Field_Label_Name__c = 'Subject Label',
                FEC_Field_Status__c = true,
                FEC_Field_Editable__c = true
            )
        };

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                Subject = 'Test NOC Clone',
                Status = 'New',
                FEC_Is_Submited__c = false,
                FEC_Product_Type__c = pt.Id,
                FEC_Category__c = cat.Id,
                FEC_SubCategory__c = subCat.Id,
                FEC_SubCode__c = subCode.Id,
                FEC_Current_Case_Stage__c = gsrStage1.Id,
                FEC_ID_Search__c = 'COFPREP-' + String.valueOf(System.currentTimeMillis())
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testCloneActualNatureAndMasterData() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c WHERE FEC_Business_Process__r.FEC_Code__c = 'COFBP' LIMIT 1];
        Id templateNocId = noc.Id;
        Map<String, String> params = new Map<String, String>{
            'natureOfCaseId' => String.valueOf(templateNocId)
        };

        Test.startTest();
        FEC_CofGsrRoutePrepareService.cloneActualNatureAndMasterData(c.Id, params);
        Test.stopTest();

        Case updatedCase = [SELECT FEC_Actual_Nature_of_Case__c FROM Case WHERE Id = :c.Id];
        System.assertNotEquals(null, updatedCase.FEC_Actual_Nature_of_Case__c);
        System.assertEquals(
            String.valueOf(updatedCase.FEC_Actual_Nature_of_Case__c),
            params.get('natureOfCaseId')
        );
        System.assertNotEquals(String.valueOf(templateNocId), params.get('natureOfCaseId'));
    }

    @IsTest
    static void testPrepareActualNatureCloneAndCreationHistory() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c WHERE FEC_Business_Process__r.FEC_Code__c = 'COFBP' LIMIT 1];
        Map<String, String> params = new Map<String, String>{
            'natureOfCaseId' => String.valueOf(noc.Id),
            'fieldListJson' => '{}'
        };

        Test.startTest();
        FEC_CofGsrRoutePrepareService.prepareActualNatureCloneAndCreationHistory(
            c.Id,
            params,
            'SUBMIT'
        );
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM FEC_Case_Flow_History__c WHERE FEC_Case__c = :c.Id] > 0
        );
    }

    @IsTest
    static void testPrepareActualNatureClone_SkipsCloneOnRouteTo() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c WHERE FEC_Business_Process__r.FEC_Code__c = 'COFBP' LIMIT 1];
        Map<String, String> params = new Map<String, String>{
            'natureOfCaseId' => String.valueOf(noc.Id),
            'fieldListJson' => '{}'
        };

        Test.startTest();
        FEC_CofGsrRoutePrepareService.prepareActualNatureCloneAndCreationHistory(
            c.Id,
            params,
            FEC_CaseBusinessService.ROUTE_TO
        );
        Test.stopTest();

        System.assertEquals(
            String.valueOf(noc.Id),
            params.get('natureOfCaseId'),
            'ROUTE_TO không clone trong prepare.'
        );
    }

    @IsTest
    static void testCreateCaseFlowHistoryIfCreationStage() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];

        Test.startTest();
        FEC_CofGsrRoutePrepareService.createCaseFlowHistoryIfCreationStage(
            c.Id,
            noc.Id,
            '{}'
        );
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM FEC_Case_Flow_History__c WHERE FEC_Case__c = :c.Id] > 0
        );
    }

    @IsTest
    static void testUpdateCaseNocFromSelection_TemplateNoc() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Nature_of_Case__c noc = [
            SELECT Id, FEC_Product_Type__c, FEC_Category__c
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Business_Process__r.FEC_Code__c = 'COFBP'
            LIMIT 1
        ];

        Test.startTest();
        FEC_CofGsrRoutePrepareService.updateCaseNocFromSelection(c.Id, noc.Id);
        Test.stopTest();

        Case updatedCase = [
            SELECT FEC_Product_Type__c, FEC_Category__c, FEC_Actual_Nature_of_Case__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals(noc.FEC_Product_Type__c, updatedCase.FEC_Product_Type__c);
        System.assertEquals(noc.FEC_Category__c, updatedCase.FEC_Category__c);
        System.assertNotEquals(null, updatedCase.FEC_Actual_Nature_of_Case__c);
    }

    @IsTest
    static void testUpdateCaseNocFromSelection_ActualNoc() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Nature_of_Case__c noc = [
            SELECT Id FROM FEC_Nature_of_Case__c WHERE FEC_Business_Process__r.FEC_Code__c = 'COFBP' LIMIT 1
        ];
        Map<String, String> params = new Map<String, String>{
            'natureOfCaseId' => String.valueOf(noc.Id)
        };
        FEC_CofGsrRoutePrepareService.cloneActualNatureAndMasterData(c.Id, params);
        Id actualId = (Id) params.get('natureOfCaseId');

        Test.startTest();
        FEC_CofGsrRoutePrepareService.updateCaseNocFromSelection(c.Id, actualId);
        Test.stopTest();

        Case updatedCase = [
            SELECT FEC_Actual_Nature_of_Case__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertNotEquals(null, updatedCase.FEC_Actual_Nature_of_Case__c);
        System.assertNotEquals(
            actualId,
            updatedCase.FEC_Actual_Nature_of_Case__c,
            'Actual NOC selection clones a fresh actual record from template dimensions.'
        );
    }

    @IsTest
    static void testSyncActualNatureToMatchCurrentCaseStage() {
        Case c = [
            SELECT Id, FEC_Current_Case_Stage__c, FEC_Current_Case_Stage__r.FEC_Nature_of_Cases__c
            FROM Case
            LIMIT 1
        ];

        Test.startTest();
        FEC_CofGsrRoutePrepareService.cloneActualNatureFromCurrentCaseStageAfterRevert(c.Id);
        Test.stopTest();

        Case updatedCase = [SELECT FEC_Actual_Nature_of_Case__c FROM Case WHERE Id = :c.Id];
        System.assertNotEquals(null, updatedCase.FEC_Actual_Nature_of_Case__c);
    }

    @IsTest
    static void testRestoreGsrStage1BaselineAfterStage2Revert() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Nature_of_Case__c gsrNoc = [
            SELECT Id FROM FEC_Nature_of_Case__c WHERE FEC_Business_Process__r.FEC_Code__c = 'GSR01' LIMIT 1
        ];

        FEC_CofGsrRoutePrepareService.createCaseFlowHistoryIfCreationStage(
            c.Id,
            gsrNoc.Id,
            '{}'
        );

        Test.startTest();
        FEC_CofGsrRoutePrepareService.restoreGsrStage1BaselineAfterStage2Revert(c.Id);
        Test.stopTest();

        Case updatedCase = [
            SELECT FEC_Actual_Nature_of_Case__c, FEC_Current_Case_Stage__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertNotEquals(null, updatedCase.FEC_Actual_Nature_of_Case__c);
    }

    @IsTest
    static void testGuardClauses() {
        Test.startTest();
        FEC_CofGsrRoutePrepareService.updateCaseNocFromSelection(null, null);
        FEC_CofGsrRoutePrepareService.updateCaseNocFromSelection('001', 'not-an-id');
        FEC_CofGsrRoutePrepareService.cloneActualNatureFromCurrentCaseStageAfterRevert(null);
        FEC_CofGsrRoutePrepareService.restoreGsrStage1BaselineAfterStage2Revert(null);
        FEC_CofGsrRoutePrepareService.cloneActualNatureAndMasterData(
            null,
            new Map<String, String>{ 'natureOfCaseId' => UserInfo.getUserId() }
        );
        Test.stopTest();

        System.assert(true, 'Guard clauses không throw.');
    }

    @IsTest
    static void testCreateCaseFlowHistoryIfCreationStage_SubmittedCase() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        c.FEC_Is_Submited__c = true;
        update c;
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];
        Integer countBefore = [SELECT COUNT() FROM FEC_Case_Flow_History__c WHERE FEC_Case__c = :c.Id];

        Test.startTest();
        FEC_CofGsrRoutePrepareService.createCaseFlowHistoryIfCreationStage(
            c.Id,
            noc.Id,
            '{}'
        );
        Test.stopTest();

        System.assertEquals(
            countBefore,
            [SELECT COUNT() FROM FEC_Case_Flow_History__c WHERE FEC_Case__c = :c.Id],
            'Submitted case không tạo flow history.'
        );
    }

    @IsTest
    static void testCloneActualNatureAndMasterData_InvalidNatureId() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Map<String, String> params = new Map<String, String>{
            'natureOfCaseId' => UserInfo.getUserId()
        };

        Test.startTest();
        FEC_CofGsrRoutePrepareService.cloneActualNatureAndMasterData(c.Id, params);
        Test.stopTest();

        Case updated = [SELECT FEC_Actual_Nature_of_Case__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(null, updated.FEC_Actual_Nature_of_Case__c);
    }

    @IsTest
    static void testRestoreGsrStage1Baseline_NoFlowHistory() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        delete [SELECT Id FROM FEC_Case_Flow_History__c WHERE FEC_Case__c = :c.Id];

        Test.startTest();
        FEC_CofGsrRoutePrepareService.restoreGsrStage1BaselineAfterStage2Revert(c.Id);
        Test.stopTest();

        System.assert(true, 'No flow history phải return sớm.');
    }
}
