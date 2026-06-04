/**
 * Unit tests for FEC_BCH_ImportRoutingHistoryService.
 * Class name FEC_BCH_ImportRoutingHistoryServiceTest (40-char Apex limit).
 */
@IsTest
private class FEC_BCH_ImportRoutingHistoryServiceTest {

    private class TestData {
        Id caseId;
        Id assignmentId;
        Id stageId;
        Id nextStageId;
        Id updateButtonId;
        Id routeButtonId;
        Id revertButtonId;
        Id blankCodeButtonId;
    }

    @TestSetup
    static void setupData() {
        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'BCH Routing Hist Stage',
            FEC_Code__c = 'BCH_RH_STG',
            FEC_Active__c = true
        );
        FEC_Case_Stage__c nextStage = new FEC_Case_Stage__c(
            Name = 'BCH Routing Hist Next',
            FEC_Code__c = 'BCH_RH_NXT',
            FEC_Active__c = true
        );
        insert new List<FEC_Case_Stage__c>{ stage, nextStage };

        FEC_Action_Button__c updateBtn = new FEC_Action_Button__c(
            Name = 'BCH Update Btn',
            FEC_Code__c = FEC_CaseBusinessService.UPDATEACTION,
            FEC_Type__c = 'Routing Action',
            FEC_Active__c = true
        );
        FEC_Action_Button__c routeBtn = new FEC_Action_Button__c(
            Name = 'BCH Route Btn',
            FEC_Code__c = FEC_CaseBusinessService.ROUTE_TO,
            FEC_Type__c = 'Routing Action',
            FEC_Active__c = true
        );
        FEC_Action_Button__c revertBtn = new FEC_Action_Button__c(
            Name = 'BCH Revert Btn',
            FEC_Code__c = FEC_CaseBusinessService.REVERT,
            FEC_Type__c = 'Routing Action',
            FEC_Active__c = true
        );
        FEC_Action_Button__c blankCodeBtn = new FEC_Action_Button__c(
            Name = 'BCH Blank Code Btn',
            FEC_Code__c = null,
            FEC_Type__c = 'Routing Action',
            FEC_Active__c = true
        );
        insert new List<FEC_Action_Button__c>{ updateBtn, routeBtn, revertBtn, blankCodeBtn };

        String userGroup = 'CC';
        for (User u : [SELECT FEC_User_Group__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1]) {
            if (String.isNotBlank(u.FEC_User_Group__c)) {
                userGroup = u.FEC_User_Group__c;
            }
        }

        insert new List<FEC_Stage_Screen__c>{
            new FEC_Stage_Screen__c(
                FEC_Case_Stage__c = stage.Id,
                FEC_Action_Button__c = updateBtn.Id,
                FEC_User_Group__c = userGroup,
                FEC_Active__c = true,
                FEC_Field_Type__c = 'All',
                FEC_Custom_Action_Button_Label__c = 'Custom Update Label'
            ),
            new FEC_Stage_Screen__c(
                FEC_Case_Stage__c = stage.Id,
                FEC_Action_Button__c = routeBtn.Id,
                FEC_User_Group__c = userGroup,
                FEC_Active__c = true,
                FEC_Field_Type__c = 'All'
            )
        };

        insert new FEC_Stage_Change__c(
            FEC_Previous_Stage__c = stage.Id,
            FEC_Next_Stage__c = nextStage.Id,
            FEC_Action_Button__c = routeBtn.Id,
            FEC_Active__c = true,
            FEC_IsReverted__c = false
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        Case c;
        try {
            c = new Case(Subject = 'BCH Import Routing History', Status = 'New');
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        update new Case(
            Id = c.Id,
            OwnerId = UserInfo.getUserId(),
            FEC_Current_Case_Stage__c = stage.Id,
            Status = 'New'
        );

        FEC_Assignment__c asn = new FEC_Assignment__c(
            FEC_Assignment_Name__c = 'Routing History Assignment',
            FEC_Case__c = c.Id,
            FEC_Assignment_Status__c = 'Open',
            FEC_Assignment_Owner__c = UserInfo.getUserId()
        );
        insert asn;
    }

    private static TestData loadTestData() {
        Case c = [
            SELECT Id, FEC_Current_Case_Stage__c
            FROM Case
            WHERE Subject = 'BCH Import Routing History'
            LIMIT 1
        ];
        FEC_Assignment__c asn = [
            SELECT Id
            FROM FEC_Assignment__c
            WHERE FEC_Case__c = :c.Id
            LIMIT 1
        ];
        FEC_Case_Stage__c nextStage = [
            SELECT Id
            FROM FEC_Case_Stage__c
            WHERE FEC_Code__c = 'BCH_RH_NXT'
            LIMIT 1
        ];
        Map<String, Id> btnByCode = new Map<String, Id>();
        for (FEC_Action_Button__c btn : [
            SELECT Id, FEC_Code__c
            FROM FEC_Action_Button__c
            WHERE Name LIKE 'BCH % Btn'
        ]) {
            btnByCode.put(btn.FEC_Code__c, btn.Id);
        }
        FEC_Action_Button__c blankBtn = [
            SELECT Id
            FROM FEC_Action_Button__c
            WHERE Name = 'BCH Blank Code Btn'
            LIMIT 1
        ];

        TestData data = new TestData();
        data.caseId = c.Id;
        data.assignmentId = asn.Id;
        data.stageId = c.FEC_Current_Case_Stage__c;
        data.nextStageId = nextStage.Id;
        data.updateButtonId = btnByCode.get(FEC_CaseBusinessService.UPDATEACTION);
        data.routeButtonId = btnByCode.get(FEC_CaseBusinessService.ROUTE_TO);
        data.revertButtonId = btnByCode.get(FEC_CaseBusinessService.REVERT);
        data.blankCodeButtonId = blankBtn.Id;
        return data;
    }

    private static FEC_BatchCaseHandlingImportRow newImportRow() {
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.status = System.Label.FEC_Operation_Success;
        row.assignmentRoutingAction = 'Excel Routing Label';
        return row;
    }

    private static Map<Id, Case> caseAfterMap(Id caseId) {
        return new Map<Id, Case>([
            SELECT Id, OwnerId, Owner.Name, Owner.Type, FEC_Final_Status__c, Status, FEC_Team__c
            FROM Case
            WHERE Id = :caseId
        ]);
    }

    private static FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem buildItem(
        TestData data,
        FEC_BatchCaseHandlingImportRow row,
        String methodKey,
        Id actionButtonId,
        String decision
    ) {
        FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem item =
            new FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem();
        item.row = row;
        item.caseId = data.caseId;
        item.assignmentId = data.assignmentId;
        item.methodKey = methodKey;
        item.decision = decision;
        item.actionButtonId = actionButtonId;
        item.currentStageId = data.stageId;
        item.stageNameBefore = 'BCH Routing Hist Stage';
        item.finalStatusBefore = 'Open';
        item.excelRoutingLabel = row.assignmentRoutingAction;
        return item;
    }

    @IsTest
    static void testApplyResult_constructor() {
        FEC_BCH_ImportRoutingHistoryService.ApplyResult result =
            new FEC_BCH_ImportRoutingHistoryService.ApplyResult(UserInfo.getUserId());
        System.assertEquals(false, result.success);
        System.assertEquals(UserInfo.getUserId(), result.caseId);
    }

    @IsTest
    static void testApplyImportBulk_skipsNullAndFailedRows() {
        FEC_BCH_ImportRoutingHistoryService.applyImportBulk(null, null);
        FEC_BCH_ImportRoutingHistoryService.applyImportBulk(
            new List<FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem>(),
            new Map<Id, Case>()
        );

        FEC_BatchCaseHandlingImportRow failedRow = new FEC_BatchCaseHandlingImportRow();
        failedRow.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
        FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem item =
            new FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem();
        item.row = failedRow;
        item.caseId = UserInfo.getUserId();
        item.assignmentId = UserInfo.getUserId();

        FEC_BCH_ImportRoutingHistoryService.applyImportBulk(
            new List<FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem>{ item },
            new Map<Id, Case>()
        );

        System.assertEquals(
            System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
            failedRow.status
        );
    }

    @IsTest
    static void testApplyImportBulk_marksFailedWhenCaseMissingAfterApply() {
        TestData data = loadTestData();
        FEC_BatchCaseHandlingImportRow row = newImportRow();
        FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem item = buildItem(
            data,
            row,
            FEC_CaseBusinessService.UPDATEACTION,
            data.updateButtonId,
            null
        );

        Test.startTest();
        FEC_BCH_ImportRoutingHistoryService.applyImportBulk(
            new List<FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem>{ item },
            new Map<Id, Case>()
        );
        Test.stopTest();

        System.assertEquals(
            System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
            row.status
        );
        System.assert(String.isNotBlank(row.errors));
    }

    @IsTest
    static void testApplyImportBulk_marksFailedWhenRoutingActionUnknown() {
        TestData data = loadTestData();
        FEC_BatchCaseHandlingImportRow row = newImportRow();
        FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem item = buildItem(
            data,
            row,
            '',
            null,
            null
        );

        Test.startTest();
        FEC_BCH_ImportRoutingHistoryService.applyImportBulk(
            new List<FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem>{ item },
            caseAfterMap(data.caseId)
        );
        Test.stopTest();

        System.assertEquals(
            System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
            row.status
        );
        System.assert(row.errors.contains('Routing Action'));
    }

    @IsTest
    static void testApplyImportBulk_successUpdateAction() {
        TestData data = loadTestData();
        FEC_BatchCaseHandlingImportRow row = newImportRow();
        FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem item = buildItem(
            data,
            row,
            FEC_CaseBusinessService.UPDATEACTION,
            data.updateButtonId,
            FEC_ConstantCommon.DECISION_CANNOT_CONTACT
        );

        Test.startTest();
        FEC_BCH_ImportRoutingHistoryService.applyImportBulk(
            new List<FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem>{ item },
            caseAfterMap(data.caseId)
        );
        Test.stopTest();

        List<FEC_Routing_Action_History__c> histories = [
            SELECT FEC_Routing_Action__c,
                FEC_Decision__c,
                FEC_Custom_Action_Button_Label__c,
                FEC_Assignment__c,
                FEC_Changed_Status__c
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c = :data.caseId
            AND FEC_Assignment__c = :data.assignmentId
        ];
        System.assertEquals(1, histories.size());
        System.assertEquals(FEC_CaseBusinessService.UPDATEACTION, histories[0].FEC_Routing_Action__c);
        System.assertEquals('Custom Update Label', histories[0].FEC_Custom_Action_Button_Label__c);
        System.assertEquals(
            System.Label.FEC_Operation_Success,
            row.status
        );
    }

    @IsTest
    static void testApplyImportBulk_successRouteToWithStageChange() {
        TestData data = loadTestData();
        FEC_BatchCaseHandlingImportRow row = newImportRow();
        FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem item = buildItem(
            data,
            row,
            FEC_CaseBusinessService.ROUTE_TO,
            data.routeButtonId,
            null
        );

        Test.startTest();
        FEC_BCH_ImportRoutingHistoryService.applyImportBulk(
            new List<FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem>{ item },
            caseAfterMap(data.caseId)
        );
        Test.stopTest();

        FEC_Routing_Action_History__c history = [
            SELECT FEC_Previous_Stage__c, FEC_Next_Stage__c, FEC_IsReverted__c, FEC_Routing_Action__c
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c = :data.caseId
            AND FEC_Routing_Action__c = :FEC_CaseBusinessService.ROUTE_TO
            LIMIT 1
        ];
        System.assertEquals(data.stageId, history.FEC_Previous_Stage__c);
        System.assertEquals(data.nextStageId, history.FEC_Next_Stage__c);
        System.assertEquals(false, history.FEC_IsReverted__c);
    }

    @IsTest
    static void testApplyImportBulk_successRevertWithDecision() {
        TestData data = loadTestData();
        FEC_BatchCaseHandlingImportRow row = newImportRow();
        FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem item = buildItem(
            data,
            row,
            FEC_CaseBusinessService.REVERT,
            data.revertButtonId,
            FEC_ConstantCommon.DECISION_CANNOT_CONTACT
        );

        Test.startTest();
        FEC_BCH_ImportRoutingHistoryService.applyImportBulk(
            new List<FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem>{ item },
            caseAfterMap(data.caseId)
        );
        Test.stopTest();

        FEC_Routing_Action_History__c history = [
            SELECT FEC_Decision__c, FEC_Routing_Action__c
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c = :data.caseId
            AND FEC_Assignment__c = :data.assignmentId
            AND FEC_Routing_Action__c = :FEC_CaseBusinessService.REVERT
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals(FEC_ConstantCommon.DECISION_CANNOT_CONTACT, history.FEC_Decision__c);
    }

    @IsTest
    static void testApplyImportBulk_successTransferWithDecision() {
        TestData data = loadTestData();
        FEC_BatchCaseHandlingImportRow row = newImportRow();
        row.assignmentRoutingAction = 'Transfer From Excel';
        FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem item = buildItem(
            data,
            row,
            FEC_CaseBusinessService.TRANSFER,
            null,
            FEC_ConstantCommon.DECISION_CANNOT_CONTACT
        );

        Test.startTest();
        FEC_BCH_ImportRoutingHistoryService.applyImportBulk(
            new List<FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem>{ item },
            caseAfterMap(data.caseId)
        );
        Test.stopTest();

        FEC_Routing_Action_History__c history = [
            SELECT FEC_Decision__c, FEC_Custom_Action_Button_Label__c, FEC_Routing_Action__c
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c = :data.caseId
            AND FEC_Assignment__c = :data.assignmentId
            AND FEC_Routing_Action__c = :FEC_CaseBusinessService.TRANSFER
            LIMIT 1
        ];
        System.assertEquals(FEC_CaseBusinessService.TRANSFER, history.FEC_Routing_Action__c);
        System.assertEquals('Transfer From Excel', history.FEC_Custom_Action_Button_Label__c);
        System.assertEquals(FEC_ConstantCommon.DECISION_CANNOT_CONTACT, history.FEC_Decision__c);
    }

    @IsTest
    static void testApplyImportBulk_usesExcelLabelWhenNoStageScreen() {
        TestData data = loadTestData();
        FEC_BatchCaseHandlingImportRow row = newImportRow();
        row.assignmentRoutingAction = 'Only Excel Label';
        FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem item = buildItem(
            data,
            row,
            FEC_CaseBusinessService.ROUTE_TO,
            data.blankCodeButtonId,
            null
        );
        item.currentStageId = null;

        Test.startTest();
        FEC_BCH_ImportRoutingHistoryService.applyImportBulk(
            new List<FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem>{ item },
            caseAfterMap(data.caseId)
        );
        Test.stopTest();

        FEC_Routing_Action_History__c history = [
            SELECT FEC_Custom_Action_Button_Label__c, FEC_Routing_Action__c
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c = :data.caseId
            AND FEC_Custom_Action_Button_Label__c = 'Only Excel Label'
            LIMIT 1
        ];
        System.assertEquals(FEC_CaseBusinessService.ROUTE_TO, history.FEC_Routing_Action__c);
    }

    @IsTest
    static void testCollectItem_skipsInvalidAndCollectsValid() {
        TestData data = loadTestData();
        FEC_BatchCaseHandlingImportRow row = newImportRow();
        row.actionButtonId = 'not-a-valid-id';
        List<FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem> items =
            new List<FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem>();

        FEC_BCH_ImportRoutingHistoryService.collectItem(
            items,
            null,
            data.caseId,
            data.assignmentId,
            FEC_CaseBusinessService.UPDATEACTION,
            null,
            data.stageId,
            'Stage',
            'Open',
            null,
            null,
            null,
            false
        );
        FEC_BCH_ImportRoutingHistoryService.collectItem(
            items,
            row,
            data.caseId,
            data.assignmentId,
            FEC_CaseBusinessService.UPDATEACTION,
            'Approve',
            data.stageId,
            'Stage',
            'Open',
            'Team',
            'Queue',
            'Q1',
            true
        );
        row.actionButtonId = String.valueOf(data.updateButtonId);
        FEC_BCH_ImportRoutingHistoryService.collectItem(
            items,
            row,
            data.caseId,
            data.assignmentId,
            FEC_CaseBusinessService.ROUTE_TO,
            'Reject',
            data.stageId,
            'Stage',
            'Open',
            null,
            null,
            null,
            false
        );

        System.assertEquals(2, items.size());
        System.assertEquals(null, items[0].actionButtonId);
        System.assertEquals(data.updateButtonId, items[1].actionButtonId);
        System.assertEquals(true, items[0].routeViaRevertButton);
        System.assertEquals('Q1', items[0].queueToken);
    }

    @IsTest
    static void testApplyAfterAssignmentBulk_insertsHistory() {
        TestData data = loadTestData();
        FEC_BatchCaseHandlingImportRow row = newImportRow();
        row.actionButtonId = String.valueOf(data.updateButtonId);
        List<FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem> items =
            new List<FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem>();

        FEC_BCH_ImportRoutingHistoryService.collectItem(
            items,
            row,
            data.caseId,
            data.assignmentId,
            FEC_CaseBusinessService.UPDATEACTION,
            FEC_ConstantCommon.DECISION_CANNOT_CONTACT,
            data.stageId,
            'BCH Routing Hist Stage',
            'Open',
            null,
            null,
            null,
            false
        );

        Integer beforeCount = [SELECT COUNT() FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :data.caseId];

        Test.startTest();
        FEC_BCH_ImportRoutingHistoryService.applyAfterAssignmentBulk(items);
        FEC_BCH_ImportRoutingHistoryService.applyAfterAssignmentBulk(null);
        FEC_BCH_ImportRoutingHistoryService.applyAfterAssignmentBulk(
            new List<FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem>()
        );
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :data.caseId] > beforeCount
        );
        System.assertEquals(
            System.Label.FEC_Operation_Success,
            row.status
        );
    }
}
