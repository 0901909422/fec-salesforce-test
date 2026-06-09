@IsTest
private class FEC_BCC_CreationResolveHistService_Test {

    @TestSetup
    static void setupStageScreen() {
        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Loan',
            FEC_Code__c = 'LOAN',
            FEC_Active__c = true
        );
        insert prod;

        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Welcome Loan',
            FEC_Code__c = 'WL',
            FEC_Active__c = true
        );
        insert cat;

        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'WC Sub',
            FEC_Code__c = 'WCS',
            FEC_Active__c = true
        );
        insert subCat;

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Active__c = true
        );
        insert noc;

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'Creation Resolve Stage',
            FEC_Code__c = 'CRS1',
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Default_Stage__c = true,
            FEC_Active__c = true
        );
        insert stage;

        FEC_Action_Button__c btnResolve = new FEC_Action_Button__c(
            Name = 'Resolve',
            FEC_Code__c = FEC_CaseBusinessService.RESOLVE,
            FEC_Type__c = FEC_ConstantCommon.ACTION_BUTTON_TYPE_ROUTING_ACTION,
            FEC_Active__c = true
        );
        insert btnResolve;

        insert new FEC_Stage_Screen__c(
            FEC_Case_Stage__c = stage.Id,
            FEC_Action_Button__c = btnResolve.Id,
            FEC_Code__c = 'SCR-CRS-RESOLVE',
            FEC_Custom_Action_Button_Label__c = 'Custom Resolve',
            FEC_Active__c = true,
            FEC_Field_Type__c = FEC_ConstantCommon.STAGE_SCREEN_FIELD_TYPE_ALL
        );
    }

    @IsTest
    static void collectItem_handlesNullInputs() {
        FEC_BCC_CreationResolveHistService.collectItem(null, null, null);
        List<FEC_BCC_CreationResolveHistService.CreationResolveHistoryItem> items =
            new List<FEC_BCC_CreationResolveHistService.CreationResolveHistoryItem>();
        FEC_BCC_CreationResolveHistService.collectItem(items, null, null);
        System.assertEquals(0, items.size());
    }

    @IsTest
    static void collectItem_skipsNonSucceededRow() {
        List<FEC_BCC_CreationResolveHistService.CreationResolveHistoryItem> items =
            new List<FEC_BCC_CreationResolveHistService.CreationResolveHistoryItem>();
        FEC_BatchCaseCreationController.CaseRowResult rowResult =
            new FEC_BatchCaseCreationController.CaseRowResult();
        rowResult.status = 'Failed';
        FEC_BCC_CreationResolveHistService.collectItem(items, rowResult, UserInfo.getUserId());
        System.assertEquals(0, items.size());
    }

    @IsTest
    static void collectItemIfResolvedStatus_skipsNonResolved() {
        List<FEC_BCC_CreationResolveHistService.CreationResolveHistoryItem> items =
            new List<FEC_BCC_CreationResolveHistService.CreationResolveHistoryItem>();
        FEC_BatchCaseCreationController.CaseRowResult rowResult =
            new FEC_BatchCaseCreationController.CaseRowResult();
        rowResult.status = 'Succeeded';
        FEC_BCC_CreationResolveHistService.collectItemIfResolvedStatus(
            items,
            rowResult,
            UserInfo.getUserId(),
            FEC_ConstantCommon.CASE_STATUS_OPEN
        );
        System.assertEquals(0, items.size());
    }

    @IsTest
    static void applyAfterCreationBulk_skipsNullAndFailedRows() {
        FEC_BCC_CreationResolveHistService.applyAfterCreationBulk(null);
        FEC_BCC_CreationResolveHistService.applyAfterCreationBulk(
            new List<FEC_BCC_CreationResolveHistService.CreationResolveHistoryItem>()
        );

        FEC_BatchCaseCreationController.CaseRowResult failedRow =
            new FEC_BatchCaseCreationController.CaseRowResult();
        failedRow.status = 'Failed';
        FEC_BCC_CreationResolveHistService.CreationResolveHistoryItem item =
            new FEC_BCC_CreationResolveHistService.CreationResolveHistoryItem();
        item.rowResult = failedRow;
        item.caseId = UserInfo.getUserId();

        Test.startTest();
        FEC_BCC_CreationResolveHistService.applyAfterCreationBulk(
            new List<FEC_BCC_CreationResolveHistService.CreationResolveHistoryItem>{ item }
        );
        Test.stopTest();

        System.assertEquals('Failed', failedRow.status);
    }

    @IsTest
    static void applyAfterCreationBulk_createsResolveHistory() {
        Case testCase = new Case(
            Subject = 'BCC Creation Resolve History',
            Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            OwnerId = UserInfo.getUserId()
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert testCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_BatchCaseCreationController.CaseRowResult rowResult =
            new FEC_BatchCaseCreationController.CaseRowResult();
        rowResult.status = 'Succeeded';
        List<FEC_BCC_CreationResolveHistService.CreationResolveHistoryItem> items =
            new List<FEC_BCC_CreationResolveHistService.CreationResolveHistoryItem>();
        FEC_BCC_CreationResolveHistService.collectItem(items, rowResult, testCase.Id);

        Test.startTest();
        FEC_BCC_CreationResolveHistService.applyAfterCreationBulk(items);
        Test.stopTest();

        List<FEC_Routing_Action_History__c> histories = [
            SELECT FEC_Routing_Action__c, FEC_Routing_Action_Type__c, FEC_Case__c,
                FEC_Current_Status__c, FEC_Changed_Status__c, FEC_Custom_Action_Button_Label__c
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c = :testCase.Id
        ];
        System.assertEquals(1, histories.size(), 'Phải tạo đúng 1 Routing Action History.');
        System.assertEquals(FEC_CaseBusinessService.RESOLVE, histories[0].FEC_Routing_Action__c);
        System.assertEquals('Case', histories[0].FEC_Routing_Action_Type__c);
        System.assertEquals(FEC_ConstantCommon.CASE_STATUS_OPEN, histories[0].FEC_Current_Status__c);
        System.assertEquals(
            FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            histories[0].FEC_Changed_Status__c
        );
        System.assertEquals(FEC_CaseBusinessService.RESOLVE, histories[0].FEC_Custom_Action_Button_Label__c);
        System.assertEquals('Succeeded', rowResult.status);
    }

    @IsTest
    static void applyAfterCreationBulk_marksRowFailedWhenCaseMissing() {
        FEC_BatchCaseCreationController.CaseRowResult rowResult =
            new FEC_BatchCaseCreationController.CaseRowResult();
        rowResult.status = 'Succeeded';
        FEC_BCC_CreationResolveHistService.CreationResolveHistoryItem item =
            new FEC_BCC_CreationResolveHistService.CreationResolveHistoryItem();
        item.rowResult = rowResult;
        item.caseId = '500000000000000AAA';

        Test.startTest();
        FEC_BCC_CreationResolveHistService.applyAfterCreationBulk(
            new List<FEC_BCC_CreationResolveHistService.CreationResolveHistoryItem>{ item }
        );
        Test.stopTest();

        System.assertEquals('Failed', rowResult.status);
        System.assertNotEquals('', rowResult.errors);
    }

    @IsTest
    static void applyAfterCreationBulk_usesStageCustomLabel() {
        FEC_Case_Stage__c stage = [
            SELECT Id
            FROM FEC_Case_Stage__c
            WHERE FEC_Code__c = 'CRS1'
            LIMIT 1
        ];
        Case testCase = new Case(
            Subject = 'BCC Creation Resolve Stage Label',
            Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            FEC_Current_Case_Stage__c = stage.Id,
            OwnerId = UserInfo.getUserId()
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert testCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_BatchCaseCreationController.CaseRowResult rowResult =
            new FEC_BatchCaseCreationController.CaseRowResult();
        rowResult.status = 'Succeeded';
        List<FEC_BCC_CreationResolveHistService.CreationResolveHistoryItem> items =
            new List<FEC_BCC_CreationResolveHistService.CreationResolveHistoryItem>();
        FEC_BCC_CreationResolveHistService.collectItem(items, rowResult, testCase.Id);

        Test.startTest();
        FEC_BCC_CreationResolveHistService.applyAfterCreationBulk(items);
        Test.stopTest();

        FEC_Routing_Action_History__c history = [
            SELECT FEC_Stage_Name__c, FEC_Custom_Action_Button_Label__c
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c = :testCase.Id
            LIMIT 1
        ];
        System.assertEquals('CRS1', history.FEC_Stage_Name__c);
        System.assertEquals('Custom Resolve', history.FEC_Custom_Action_Button_Label__c);
    }
}
