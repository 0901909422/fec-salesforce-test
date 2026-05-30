@IsTest
private class FEC_BCH_ImportRoutingHistoryServiceTest {

    @IsTest
    static void applyImportBulk_skipsNullAndFailedRows() {
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

        Test.startTest();
        FEC_BCH_ImportRoutingHistoryService.applyImportBulk(
            new List<FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem>{ item },
            new Map<Id, Case>()
        );
        Test.stopTest();

        System.assertEquals(
            System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
            failedRow.status,
            'Dòng đã fail phải bỏ qua, không đổi status.'
        );
    }

    @IsTest
    static void applyImportBulk_marksFailedWhenCaseMissingAfterApply() {
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem item =
            new FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem();
        item.row = row;
        item.caseId = UserInfo.getUserId();
        item.assignmentId = UserInfo.getUserId();
        item.methodKey = FEC_CaseBusinessService.UPDATEACTION;
        item.stageNameBefore = 'Stage 1';
        item.finalStatusBefore = 'Open';

        Test.startTest();
        FEC_BCH_ImportRoutingHistoryService.applyImportBulk(
            new List<FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem>{ item },
            new Map<Id, Case>()
        );
        Test.stopTest();

        System.assertEquals(
            System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
            row.status,
            'Thiếu Case sau apply phải fail dòng import.'
        );
        System.assert(String.isNotBlank(row.errors), 'Phải có message lỗi.');
    }
}
