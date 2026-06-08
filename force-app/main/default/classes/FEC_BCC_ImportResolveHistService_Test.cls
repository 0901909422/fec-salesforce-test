@IsTest
private class FEC_BCC_ImportResolveHistService_Test {

    private static final String USER_GROUP_CC = 'CC';

    @TestSetup
    static void setupResolveHistoryData() {
        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'BCC Resolve History BP',
            FEC_Code__c = 'BCCRH',
            FEC_Active__c = true
        );
        insert bp;

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Card',
            FEC_Code__c = 'CARD',
            FEC_Active__c = true
        );
        insert prod;

        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Request',
            FEC_Code__c = 'Request',
            FEC_Active__c = true
        );
        insert cat;

        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'BCC Sub',
            FEC_Code__c = 'BCC',
            FEC_Active__c = true
        );
        insert subCat;

        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'BCC.01',
            FEC_Code__c = 'BCC.01',
            FEC_Active__c = true
        );
        insert subCode;

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_User_Group__c = USER_GROUP_CC,
            FEC_Active__c = true
        );
        insert noc;

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'BCC Resolve Stage 1',
            FEC_Code__c = 'Stage 1',
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Default_Stage__c = true,
            FEC_Active__c = true,
            FEC_Business_Process__c = bp.Id,
            FEC_User_Group__c = USER_GROUP_CC
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
            FEC_Code__c = 'SCR-BCC-RESOLVE',
            FEC_Custom_Action_Button_Label__c = 'Resolve',
            FEC_User_Group__c = USER_GROUP_CC,
            FEC_Active__c = true,
            FEC_Field_Type__c = FEC_ConstantCommon.STAGE_SCREEN_FIELD_TYPE_ALL
        );

        Case testCase = new Case(
            Subject = 'BCC Resolve History Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_Current_Case_Stage__c = stage.Id,
            OwnerId = UserInfo.getUserId()
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert testCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void applyImportBulk_skipsNullAndFailedRows() {
        FEC_BCC_ImportResolveHistService.applyImportBulk(null, null);
        FEC_BCC_ImportResolveHistService.applyImportBulk(
            new List<FEC_BCC_ImportResolveHistService.ImportResolveHistoryItem>(),
            new Map<Id, Case>()
        );

        FEC_BatchCaseCreationController.CaseRowResult failedRow = new FEC_BatchCaseCreationController.CaseRowResult();
        failedRow.status = 'Failed';
        FEC_BCC_ImportResolveHistService.ImportResolveHistoryItem item =
            new FEC_BCC_ImportResolveHistService.ImportResolveHistoryItem();
        item.row = failedRow;
        item.caseId = UserInfo.getUserId();

        Test.startTest();
        FEC_BCC_ImportResolveHistService.applyImportBulk(
            new List<FEC_BCC_ImportResolveHistService.ImportResolveHistoryItem>{ item },
            new Map<Id, Case>()
        );
        Test.stopTest();

        System.assertEquals('Failed', failedRow.status, 'Dòng đã fail phải bỏ qua, không đổi status.');
    }

    @IsTest
    static void applyImportBulk_createsResolveHistoryWithFieldMapping() {
        Case testCase = [
            SELECT Id, OwnerId, FEC_Current_Case_Stage__c, FEC_Final_Status__c,
                FEC_Current_Case_Stage__r.FEC_Code__c
            FROM Case
            WHERE Subject = 'BCC Resolve History Case'
            LIMIT 1
        ];
        User runUser = [
            SELECT Id, Email, UserRole.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String importerEmailId = FEC_CaseBusinessService.emailLocalPart(runUser.Email);

        FEC_BatchCaseCreationController.CaseRowResult row = new FEC_BatchCaseCreationController.CaseRowResult();
        row.caseStatus = FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED;
        row.status = 'Succeeded';

        FEC_BCC_ImportResolveHistService.ImportResolveHistoryItem item =
            new FEC_BCC_ImportResolveHistService.ImportResolveHistoryItem();
        item.row = row;
        item.caseId = testCase.Id;
        item.currentStageId = testCase.FEC_Current_Case_Stage__c;
        item.stageNameBefore = testCase.FEC_Current_Case_Stage__r.FEC_Code__c;
        item.finalStatusBefore = FEC_ConstantCommon.CASE_STATUS_OPEN;

        update new Case(
            Id = testCase.Id,
            Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED
        );
        Case caseAfter = [
            SELECT Id, OwnerId, Owner.Name, Owner.Type, Status, FEC_Final_Status__c, FEC_Team__c,
                FEC_Current_Case_Stage__c, FEC_Current_Case_Stage__r.FEC_Code__c
            FROM Case
            WHERE Id = :testCase.Id
            LIMIT 1
        ];

        Test.startTest();
        FEC_BCC_ImportResolveHistService.applyImportBulk(
            new List<FEC_BCC_ImportResolveHistService.ImportResolveHistoryItem>{ item },
            new Map<Id, Case>{ caseAfter.Id => caseAfter }
        );
        Test.stopTest();

        List<FEC_Routing_Action_History__c> histories = [
            SELECT FEC_Routing_Action__c, FEC_Decision__c, FEC_Original_User_Queue__c,
                FEC_Original_User_Queue_ID__c, FEC_Updated_User_Queue__c,
                FEC_Updated_User_Queue_ID__c, FEC_Stage_Name__c, FEC_User__c,
                FEC_User_Role__c, FEC_Current_Status__c, FEC_Changed_Status__c,
                FEC_Custom_Action_Button_Label__c, FEC_Routing_Action_Type__c,
                FEC_Perform_User__c, FEC_IsReverted__c, FEC_Case__c
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c = :testCase.Id
        ];
        System.assertEquals(1, histories.size(), 'Phải tạo đúng 1 Routing Action History.');
        FEC_Routing_Action_History__c history = histories[0];
        System.assertEquals(FEC_CaseBusinessService.RESOLVE, history.FEC_Routing_Action__c);
        System.assertEquals(null, history.FEC_Decision__c);
        System.assertEquals(importerEmailId, history.FEC_Original_User_Queue__c);
        System.assertEquals(String.valueOf(runUser.Id), history.FEC_Original_User_Queue_ID__c);
        System.assertEquals(importerEmailId, history.FEC_User__c);
        System.assertEquals(runUser.UserRole?.Name, history.FEC_User_Role__c);
        System.assertEquals('Stage 1', history.FEC_Stage_Name__c);
        System.assertEquals(FEC_ConstantCommon.CASE_STATUS_OPEN, history.FEC_Current_Status__c);
        System.assertEquals(
            FEC_CaseBusinessService.routingHistoryStatusSnapshot(caseAfter),
            history.FEC_Changed_Status__c
        );
        System.assertEquals('Resolve', history.FEC_Custom_Action_Button_Label__c);
        System.assertEquals('Case', history.FEC_Routing_Action_Type__c);
        System.assertEquals(runUser.Id, history.FEC_Perform_User__c);
        System.assertEquals(false, history.FEC_IsReverted__c);
        System.assertEquals(testCase.Id, history.FEC_Case__c);
        System.assertEquals(
            FEC_CaseBusinessService.resolveRoutingHistoryOwnerLabel(caseAfter.OwnerId, caseAfter.Owner?.Name),
            history.FEC_Updated_User_Queue__c
        );
        System.assertEquals(String.valueOf(caseAfter.OwnerId), history.FEC_Updated_User_Queue_ID__c);
    }

    @IsTest
    static void collectItem_andApplyAfterCaseCreateBulk() {
        Case testCase = [
            SELECT Id, FEC_Current_Case_Stage__c, FEC_Current_Case_Stage__r.FEC_Code__c
            FROM Case
            WHERE Subject = 'BCC Resolve History Case'
            LIMIT 1
        ];

        List<FEC_BCC_ImportResolveHistService.ImportResolveHistoryItem> items =
            new List<FEC_BCC_ImportResolveHistService.ImportResolveHistoryItem>();
        FEC_BCC_ImportResolveHistService.collectItem(null, null, null);
        FEC_BCC_ImportResolveHistService.collectItem(items, null, null);
        FEC_BCC_ImportResolveHistService.applyAfterCaseCreateBulk(null);
        FEC_BCC_ImportResolveHistService.applyAfterCaseCreateBulk(items);

        FEC_BatchCaseCreationController.CaseRowResult row = new FEC_BatchCaseCreationController.CaseRowResult();
        row.caseStatus = FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED;
        row.status = 'Succeeded';
        FEC_BCC_ImportResolveHistService.collectItem(items, row, testCase.Id);

        update new Case(
            Id = testCase.Id,
            Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED
        );

        Test.startTest();
        FEC_BCC_ImportResolveHistService.applyAfterCaseCreateBulk(items);
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :testCase.Id],
            'applyAfterCaseCreateBulk phải insert history.'
        );
    }

    @IsTest
    static void applyImportBulk_marksFailedWhenCaseAfterMissing() {
        FEC_BatchCaseCreationController.CaseRowResult row = new FEC_BatchCaseCreationController.CaseRowResult();
        row.status = 'Succeeded';
        FEC_BCC_ImportResolveHistService.ImportResolveHistoryItem item =
            new FEC_BCC_ImportResolveHistService.ImportResolveHistoryItem();
        item.row = row;
        item.caseId = UserInfo.getUserId();
        item.currentStageId = UserInfo.getUserId();

        Test.startTest();
        FEC_BCC_ImportResolveHistService.applyImportBulk(
            new List<FEC_BCC_ImportResolveHistService.ImportResolveHistoryItem>{ item },
            new Map<Id, Case>()
        );
        Test.stopTest();

        System.assertEquals('Failed', row.status);
        System.assert(row.errors.contains('Không tải được Case sau khi import tạo Resolve.'));
    }
}
