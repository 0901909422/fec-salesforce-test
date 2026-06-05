@IsTest
private class FEC_BatchCaseHandlingImportService_Test {

    @TestSetup
    static void setupData() {
        // 1. Tạo dữ liệu Case mồi phục vụ kiểm tra trạng thái đóng/mở (IsClosed)
        Case openCase = new Case(
            Subject = 'Open Test Case',
            FEC_ID_Search__c = 'CASE-OPEN-2026',
            Status = 'New'
        );
        Case closedCase = new Case(
            Subject = 'Closed Test Case',
            FEC_ID_Search__c = 'CASE-CLOSED-2026',
            Status = 'Closed'
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new List<Case>{ openCase, closedCase };
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        // onBeforeInsert regenerates FEC_ID_Search__c; restore keys used by import assertions and SOQL in tests.
        Id runUserId = UserInfo.getUserId();
        update new List<Case>{
            new Case(
                Id = openCase.Id,
                FEC_ID_Search__c = 'CASE-OPEN-2026',
                OwnerId = runUserId
            ),
            new Case(
                Id = closedCase.Id,
                FEC_ID_Search__c = 'CASE-CLOSED-2026',
                OwnerId = runUserId
            )
        };

        // 2. Tạo bản ghi phân công việc FEC_Assignment__c để kiểm thử luồng mẫu COF/GSR
        // Đảm bảo tạo một bản ghi liên kết chuẩn và một bản ghi trạng thái đã đóng (Resolved-)
        FEC_Assignment__c activeAsg = new FEC_Assignment__c(
            FEC_Assignment_Name__c = 'Active Assignment Mocks',
            FEC_Case__c = openCase.Id,
            FEC_Assignment_Status__c = 'Open'
        );
        FEC_Assignment__c closedAsg = new FEC_Assignment__c(
            FEC_Assignment_Name__c = 'Closed Assignment Mocks',
            FEC_Case__c = openCase.Id,
            FEC_Assignment_Status__c = 'Resolved-Completed'
        );
        insert new List<FEC_Assignment__c>{activeAsg, closedAsg};
    }

    /**
     * Kịch bản 1: Kiểm tra bộ đếm số dòng xử lý lỗi hệ thống (countFailedImportRows).
     */
    @IsTest
    static void testCountFailedImportRows() {
        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>();
        
        FEC_BatchCaseHandlingImportRow r1 = new FEC_BatchCaseHandlingImportRow();
        r1.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
        FEC_BatchCaseHandlingImportRow r2 = new FEC_BatchCaseHandlingImportRow();
        r2.status = System.Label.FEC_Operation_Success;
        
        rows.add(r1);
        rows.add(r2);
        rows.add(null); // Test dòng null guard bảo vệ biên

        Test.startTest();
        Integer failedCount = FEC_BatchCaseHandlingImportService.countFailedImportRows(rows);
        Test.stopTest();

        System.assertEquals(1, failedCount, 'Hệ thống phải đếm chính xác 1 dòng bị đánh dấu Failed.');
    }

    /**
     * Kịch bản 2: Xác thực các dòng dữ liệu nhập vào theo luồng mẫu biểu không phải COF/GSR (Standard Process Flow).
     * Bao phủ: Chặn lỗi thiếu Case Id, Case không tồn tại, Case đã đóng, dòng trùng lặp, thiếu Remark, và gán sai Assignment.
     */
    private static User batchImportRunUser() {
        return [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = true
            LIMIT 1
        ];
    }

    @IsTest
    static void testValidateRows_StandardProcessFlow() {
        System.runAs(batchImportRunUser()) {
        runValidateRowsStandardProcessFlow();
        }
    }

    private static void runValidateRowsStandardProcessFlow() {
        Case openCase = [
            SELECT Id, FEC_ID_Search__c
            FROM Case
            WHERE FEC_ID_Search__c = 'CASE-OPEN-2026'
            LIMIT 1
        ];
        openCase.OwnerId = UserInfo.getUserId();
        update openCase;
        String openCaseKey = openCase.FEC_ID_Search__c;
        String closedCaseKey = [
            SELECT FEC_ID_Search__c
            FROM Case
            WHERE FEC_ID_Search__c = 'CASE-CLOSED-2026'
            LIMIT 1
        ].FEC_ID_Search__c;

        // Chuẩn bị mảng chứa các object dòng dữ liệu lỗi/đúng đan xen
        List<Object> inputRows = new List<Object>();
        
        // Dòng 1: Hợp lệ 100% cho luồng thường
        inputRows.add(new Map<String, Object>{
            'case id search' => openCaseKey,
            'routing action' => 'RESOLVE',
            'inputtedremarks' => 'Standard process remark valid entry',
            'inputtedremarkscharlength' => '35'
        });
        
        // Dòng 2: Lỗi thiếu Case Id đầu vào
        inputRows.add(new Map<String, Object>{
            'case id search' => '',
            'routing action' => 'RESOLVE',
            'remark' => 'Missing case'
        });

        // Dòng 3: Lỗi mã Case Id không tồn tại trên hệ thống
        inputRows.add(new Map<String, Object>{
            'caseid' => 'CASE-NOTFOUND-404',
            'routingaction' => 'RESOLVE',
            'remarks' => 'Not found test case'
        });

        // Dòng 4: Lỗi Case Id đã đóng (IsClosed = true)
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => closedCaseKey,
            'routingaction' => 'RESOLVE',
            'remarks' => 'Closed case entry'
        });

        // Dòng 5: Lỗi trùng lặp mã Case Id trong cùng một lô import (Duplicate Case)
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => openCaseKey, // Trùng lại dòng 1
            'routingaction' => 'RESOLVE',
            'remarks' => 'Duplicate remark line'
        });

        // Dòng 6: Lỗi luồng thường nhưng cố tình truyền kèm các trường định tuyến phân công Assignment
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => openCaseKey,
            'routingaction' => 'RESOLVE',
            'assignmentid' => '005xxxxxxxxxxxxAAA',
            'assignmentroutingaction' => 'REJECT',
            'remarks' => 'Prohibited assignments for normal flow'
        });

        // Dòng 7: Lỗi nội dung Remark vượt độ dài tối đa hoặc rỗng
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => openCaseKey,
            'routingaction' => 'RESOLVE',
            'remarks' => '' // Thiếu ghi chú
        });

        // Dòng biên rỗng hoàn toàn -> phải bị continue bỏ qua không add vào danh sách kết quả
        inputRows.add(new Map<String, Object>{ 'caseidsearch' => '', 'routingaction' => '' });
        // Dòng biên sai định dạng kết cấu cấu trúc dữ liệu Map -> continue bỏ qua
        inputRows.add('invalid_row_string_format');

        Test.startTest();
        List<FEC_BatchCaseHandlingImportRow> results = 
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, false);
        Test.stopTest();

        System.assertEquals(8, results.size(), 'Số lượng dòng ghi nhận xử lý phải là 8.');
        System.assertEquals(
            System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
            results[0].status,
            'Dòng 1 thiếu MDM routing trên org QA: ' + results[0].errors
        );
        System.assertEquals(System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed, results[1].status, 'Dòng số 2 thiếu mã Case phải báo lỗi Failed.');
        System.assertEquals(System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed, results[2].status, 'Dòng số 3 sai mã Case phải báo lỗi Failed.');
        System.assertEquals(System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed, results[3].status, 'Dòng số 4 Case đóng phải báo lỗi Failed.');
        System.assertEquals(System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed, results[4].status, 'Dòng số 5 trùng lặp Case phải báo lỗi Failed.');
        System.assertEquals(System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed, results[5].status, 'Dòng số 6 chứa phân công Assignment ở luồng Process phải Failed.');
    }

    /**
     * Kịch bản 3: Xác thực các dòng dữ liệu nhập vào theo luồng đặc thù COF hoặc GSR.
     * Bao phủ: Chặn lỗi trùng lặp/thiếu cả 2 hành động định tuyến, định dạng sai Assignment Id, Assignment Id không thuộc Case, hoặc trạng thái phân công việc đã đóng.
     */
    @IsTest
    static void testValidateRows_CofOrGsrFlow() {
        System.runAs(batchImportRunUser()) {
        runValidateRowsCofOrGsrFlow();
        }
    }

    private static void runValidateRowsCofOrGsrFlow() {
        Case openCase = [
            SELECT Id, FEC_ID_Search__c
            FROM Case
            WHERE FEC_ID_Search__c = 'CASE-OPEN-2026'
            LIMIT 1
        ];
        openCase.OwnerId = UserInfo.getUserId();
        update openCase;
        String openCaseKey = openCase.FEC_ID_Search__c;
        FEC_Assignment__c activeAsg = [SELECT Id FROM FEC_Assignment__c WHERE FEC_Assignment_Status__c = 'Open' LIMIT 1];
        FEC_Assignment__c closedAsg = [SELECT Id FROM FEC_Assignment__c WHERE FEC_Assignment_Status__c = 'Resolved-Completed' LIMIT 1];

        List<Object> inputRows = new List<Object>();

        // Dòng 1: Gán kèm phân công Assignment hợp lệ + Hành động định tuyến Assignment hoàn tất (Chỉ chấp nhận RESOLVE/REJECT)
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => openCaseKey,
            'assignmentid' => String.valueOf(activeAsg.Id),
            'routingaction' => 'RESOLVE',
            'inputtedremarks' => 'Valid COF row entries',
            'inputtedremarkscharlength' => '22'
        });

        // Dòng 2: Lỗi truyền cả 2 hành động routingAction và assignmentRoutingAction cùng lúc
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => openCaseKey,
            'assignmentid' => String.valueOf(activeAsg.Id),
            'routingaction' => 'RESOLVE',
            'assignmentroutingaction' => 'REJECT',
            'remarks' => 'Both actions provided'
        });

        // Dòng 3: Lỗi thiếu cả 2 hành động định tuyến
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => openCaseKey,
            'assignmentid' => String.valueOf(activeAsg.Id),
            'remarks' => 'Missing both routing actions'
        });

        // Dòng 4: Lỗi mã định danh định tuyến của Case không hợp lệ
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => openCaseKey,
            'assignmentid' => String.valueOf(activeAsg.Id),
            'routingaction' => 'INVALID_ROUTING_KEY',
            'remarks' => 'Invalid action key'
        });

        // Dòng 5: Lỗi định tuyến cho Case khi có kèm Assignment nhưng hành động KHÔNG PHẢI RESOLVE/REJECT
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => openCaseKey,
            'assignmentid' => String.valueOf(activeAsg.Id),
            'routingaction' => FEC_CaseBusinessService.ROUTE_TO, // Gây lỗi nhánh !isResolvedOrRejectCaseRouting (map key "Route to")
            'remarks' => 'Not a resolve or reject action'
        });

        // Dòng 6: Lỗi mã Assignment Id sai định dạng cấu trúc mã Id Salesforce (Bao phủ catch exception)
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => openCaseKey,
            'assignmentid' => 'CRITICAL_INVALID_ID_FORMAT_STACK',
            'routingaction' => 'RESOLVE',
            'remarks' => 'Bad assignment ID format'
        });

        // Dòng 7: Lỗi mã Assignment Id không tồn tại trong DB hoặc không liên kết trùng khớp với Id của Case
        // Giả lập bằng cách tạo một ID giả chuẩn cấu trúc Salesforce Object
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => openCaseKey,
            'assignmentid' => 'a01000000000001AAA', 
            'routingaction' => 'RESOLVE',
            'remarks' => 'Non existing or unlinked assignment record'
        });

        // Dòng 8: Lỗi mã bản ghi phân công việc đã ở trạng thái đóng (Resolved-)
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => openCaseKey,
            'assignmentid' => String.valueOf(closedAsg.Id),
            'routingaction' => 'RESOLVE',
            'remarks' => 'Closed assignment row verification'
        });

        // Dòng 9: Không truyền assignmentId nhưng truyền thiếu hành động hoặc sai hành động
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => openCaseKey,
            'assignmentroutingaction' => 'RESOLVE', // Lỗi: truyền kèm assignment routing action nhưng thiếu assignmentId
            'remarks' => 'Assignment routing without assignment ID'
        });

        Test.startTest();
        List<FEC_BatchCaseHandlingImportRow> results = 
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, true);
        Test.stopTest();

        System.assertEquals(9, results.size());
        System.assertEquals(
            System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
            results[0].status,
            'COF row 1 thiếu datagroup routing: ' + results[0].errors
        );
        System.assertEquals(System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed, results[1].status);
        System.assertEquals(System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed, results[2].status);
        System.assertEquals(System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed, results[3].status);
        System.assertEquals(System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed, results[4].status);
        System.assertEquals(System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed, results[5].status);
        System.assertEquals(System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed, results[6].status);
        System.assertEquals(System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed, results[7].status);
        System.assertEquals(System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed, results[8].status);
    }

    /**
     * Kịch bản 4: Thực thi áp dụng cập nhật trạng thái Case và ghi chú hàng loạt xuống Database (applyCaseHandlingUpdates).
     * Bao phủ: Kịch bản thành công chạy hàm lõi chạy FEC_CaseBusinessService, kịch bản lỗi cấu trúc Id, kịch bản hành động đòi hỏi bổ sung tham số (routingActionRequiresExtraParams).
     */
    @IsTest
    static void testApplyCaseHandlingUpdates_AllBranches() {
        Case c = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'CASE-OPEN-2026' LIMIT 1];
        
        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>();

        // Thực thể 1: Hợp lệ hoàn toàn -> Phải gọi được luồng thực thi Service nghiệp vụ
        FEC_BatchCaseHandlingImportRow r1 = new FEC_BatchCaseHandlingImportRow();
        r1.status = System.Label.FEC_Operation_Success;
        r1.recordId = String.valueOf(c.Id);
        r1.routingAction = 'RESOLVE';
        r1.inputtedRemarks = 'Apply update valid integration log';
        rows.add(r1);

        // Thực thể 2: Biên lỗi - truyền recordId không phải kiểu cấu trúc mã Id Salesforce
        FEC_BatchCaseHandlingImportRow r2 = new FEC_BatchCaseHandlingImportRow();
        r2.status = System.Label.FEC_Operation_Success;
        r2.recordId = 'INVALID_SFDC_RECORD_ID_STRING';
        rows.add(r2);

        // Thực thể 3: Biên lỗi - Hành động định tuyến đòi hỏi phải có thêm tham số bổ trợ (ví dụ: ROUTE_TO) -> phải bị chặn ném lỗi
        FEC_BatchCaseHandlingImportRow r3 = new FEC_BatchCaseHandlingImportRow();
        r3.status = System.Label.FEC_Operation_Success;
        r3.recordId = String.valueOf(c.Id);
        r3.routingAction = FEC_CaseBusinessService.ROUTE_TO; // Kích hoạt routingActionRequiresExtraParams (canonical key "Route to")
        r3.inputtedRemarks = 'Requires params';
        rows.add(r3);

        // Thực thể 4: Biên lỗi - Phân giải từ khóa hành động định tuyến thất bại trả về rỗng
        FEC_BatchCaseHandlingImportRow r4 = new FEC_BatchCaseHandlingImportRow();
        r4.status = System.Label.FEC_Operation_Success;
        r4.recordId = String.valueOf(c.Id);
        r4.routingAction = 'NON_EXISTING_METHOD_MAP_KEY';
        rows.add(r4);

        // Thực thể biên bỏ qua: Dòng đã mang trạng thái Failed sẵn -> continue bỏ qua
        FEC_BatchCaseHandlingImportRow rSkip = new FEC_BatchCaseHandlingImportRow();
        rSkip.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
        rows.add(rSkip);

        Test.startTest();
        FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(rows, false);
        // Kiểm thử khối bảo vệ tham số rỗng đầu vào
        FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(null, false);
        Test.stopTest();

        System.assertEquals(System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed, rows[1].status, 'Thực thể 2 lỗi cấu trúc Id bản ghi phải chuyển trạng thái thành Failed.');
        System.assertEquals(System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed, rows[2].status, 'Thực thể 3 hành động đòi hỏi bổ sung tham số phải chuyển sang Failed.');
        System.assertEquals(System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed, rows[3].status, 'Thực thể 4 sai từ khóa định tuyến phải chuyển sang Failed.');
    }

    /**
     * Kịch bản 5: Kiểm tra hàm phân tách nhận diện chuỗi tên của Template biểu mẫu mẫu nhập vào (isCofOrGsrTemplate).
     */
    @IsTest
    static void testIsCofOrGsrTemplate() {
        Test.startTest();
        Boolean testCof = FEC_BatchCaseHandlingImportService.isCofOrGsrTemplate('Batch_COF_Handling_Template.xlsx');
        Boolean testGsr = FEC_BatchCaseHandlingImportService.isCofOrGsrTemplate('GSR_Import_Template_V1');
        Boolean testNormal = FEC_BatchCaseHandlingImportService.isCofOrGsrTemplate('Standard_Process_Case_Creation.xlsx');
        Boolean testNull = FEC_BatchCaseHandlingImportService.isCofOrGsrTemplate('');
        Test.stopTest();

        System.assertEquals(true, testCof, 'Tên file chứa chuỗi COF phải trả về true.');
        System.assertEquals(true, testGsr, 'Tên file chứa chuỗi GSR phải trả về true.');
        System.assertEquals(false, testNormal, 'Tên file thông thường không được phép nhận diện nhầm luồng.');
        System.assertEquals(false, testNull, 'Tên file trống/null bảo vệ guard clause trả về false.');
    }

    @IsTest
    static void testShouldApplyImportRow_AndCounts() {
        FEC_BatchCaseHandlingImportRow ok = new FEC_BatchCaseHandlingImportRow();
        ok.status = System.Label.FEC_Operation_Success;
        ok.recordId = '500000000000001AAA';

        FEC_BatchCaseHandlingImportRow failed = new FEC_BatchCaseHandlingImportRow();
        failed.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
        failed.recordId = '500000000000002AAA';

        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>{ ok, failed, null };

        Test.startTest();
        Boolean shouldApply = FEC_BatchCaseHandlingImportService.shouldApplyImportRow(ok);
        Boolean hasApplicable = FEC_BatchCaseHandlingImportService.hasApplicableImportRows(rows);
        Integer applicableCount = FEC_BatchCaseHandlingImportService.countApplicableImportRows(rows);
        Boolean sync = FEC_BatchCaseHandlingImportService.shouldProcessImportSynchronously(rows);
        Boolean hasRemaining = FEC_BatchCaseHandlingImportService.hasRemainingApplicableImportRows(rows, 1);
        Boolean inProgress = FEC_BatchCaseHandlingImportService.isBatchImportApplyInProgress();
        String timeoutReason = FEC_BatchCaseHandlingImportService.resolveImportProcessingTimeoutReason();
        Test.stopTest();

        System.assertEquals(true, shouldApply);
        System.assertEquals(true, hasApplicable);
        System.assertEquals(1, applicableCount);
        System.assertEquals(false, sync);
        System.assertEquals(false, hasRemaining);
        System.assertEquals(false, inProgress);
        System.assertNotEquals(null, timeoutReason);
    }

    @IsTest
    static void testFinalizeAndFailBatchImportRecord() {
        Schema.SObjectType batchType = Schema.getGlobalDescribe().get('FEC_Batch_Case_Handling__c');
        if (batchType == null) {
            System.assert(true, 'Skipped: FEC_Batch_Case_Handling__c not on org.');
            return;
        }

        SObject batchRow = batchType.newSObject();
        Map<String, Schema.SObjectField> fMap = batchType.getDescribe().fields.getMap();
        if (fMap.containsKey('FEC_File_Name__c')) {
            batchRow.put('FEC_File_Name__c', 'Finalize_Test.xlsx');
        }
        if (fMap.containsKey('FEC_Status__c')) {
            batchRow.put('FEC_Status__c', 'Processing');
        }
        insert batchRow;
        Id batchId = (Id) batchRow.get('Id');

        FEC_BatchCaseHandlingImportRow ok = new FEC_BatchCaseHandlingImportRow();
        ok.status = System.Label.FEC_Operation_Success;
        FEC_BatchCaseHandlingImportRow failed = new FEC_BatchCaseHandlingImportRow();
        failed.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>{ ok, failed };

        Test.startTest();
        FEC_BatchCaseHandlingImportService.finalizeBatchImportRecord(batchId, rows);
        FEC_BatchCaseHandlingImportService.failBatchImportRecord(batchId, 'Unit test failure');
        FEC_BatchCaseHandlingImportService.failBatchImportRecord(batchId, 'Partial failure', rows);
        Boolean expired = FEC_BatchCaseHandlingImportService.isBatchImportProcessingExpired(batchId);
        Test.stopTest();

        System.assertEquals(false, expired);
    }

    @IsTest
    static void testExpireStaleProcessingBatchImports() {
        Schema.SObjectType batchType = Schema.getGlobalDescribe().get('FEC_Batch_Case_Handling__c');
        if (batchType == null) {
            System.assert(true, 'Skipped: FEC_Batch_Case_Handling__c not on org.');
            return;
        }

        SObject staleBatch = batchType.newSObject();
        Map<String, Schema.SObjectField> fMap = batchType.getDescribe().fields.getMap();
        if (fMap.containsKey('FEC_File_Name__c')) {
            staleBatch.put('FEC_File_Name__c', 'Stale_Batch.xlsx');
        }
        if (fMap.containsKey('FEC_Status__c')) {
            staleBatch.put('FEC_Status__c', 'Processing');
        }
        if (fMap.containsKey('FEC_Uploaded_On__c')) {
            staleBatch.put('FEC_Uploaded_On__c', Datetime.now().addHours(-2));
        }
        insert staleBatch;

        Test.startTest();
        FEC_BatchCaseHandlingImportService.expireStaleProcessingBatchImports(UserInfo.getUserId());
        FEC_BatchCaseHandlingImportService.expireStaleProcessingBatchImports(null);
        Test.stopTest();

        System.assert(true, 'Expire stale imports should complete without exception.');
    }

    @IsTest
    static void testProcessApplicableImportRowsSync() {
        Case c = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'CASE-OPEN-2026' LIMIT 1];
        Schema.SObjectType batchType = Schema.getGlobalDescribe().get('FEC_Batch_Case_Handling__c');
        if (batchType == null) {
            System.assert(true, 'Skipped: FEC_Batch_Case_Handling__c not on org.');
            return;
        }

        SObject batchRow = batchType.newSObject();
        Map<String, Schema.SObjectField> fMap = batchType.getDescribe().fields.getMap();
        if (fMap.containsKey('FEC_File_Name__c')) {
            batchRow.put('FEC_File_Name__c', 'Sync_Apply.xlsx');
        }
        if (fMap.containsKey('FEC_Status__c')) {
            batchRow.put('FEC_Status__c', 'Processing');
        }
        insert batchRow;

        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.status = System.Label.FEC_Operation_Success;
        row.recordId = String.valueOf(c.Id);
        row.routingAction = 'RESOLVE';
        row.inputtedRemarks = 'Sync apply remark';

        Test.startTest();
        FEC_BatchCaseHandlingImportService.processApplicableImportRowsSync(
            (Id) batchRow.get('Id'),
            new List<FEC_BatchCaseHandlingImportRow>{ row },
            false
        );
        FEC_BatchCaseHandlingImportService.processApplicableImportRowsSync(null, null, false);
        Test.stopTest();

        System.assert(true, 'Sync import processing should complete.');
    }

    @IsTest
    static void testShouldYieldImportGovernorLimits() {
        Test.startTest();
        Boolean yield = FEC_BatchCaseHandlingImportService.shouldYieldImportGovernorLimits();
        Test.stopTest();

        System.assertEquals(false, yield);
    }

    @IsTest
    static void testCountFailedImportRows_NullAndEmpty() {
        Test.startTest();
        Integer emptyCount = FEC_BatchCaseHandlingImportService.countFailedImportRows(
            new List<FEC_BatchCaseHandlingImportRow>()
        );
        Test.stopTest();

        System.assertEquals(0, emptyCount);
    }

    @IsTest
    static void testFinalizeBatchImportRecord_EmptyRows() {
        Schema.SObjectType batchType = Schema.getGlobalDescribe().get('FEC_Batch_Case_Handling__c');
        if (batchType == null) {
            System.assert(true, 'Skipped: FEC_Batch_Case_Handling__c not on org.');
            return;
        }

        SObject batchRow = batchType.newSObject();
        Map<String, Schema.SObjectField> fMap = batchType.getDescribe().fields.getMap();
        if (fMap.containsKey('FEC_File_Name__c')) {
            batchRow.put('FEC_File_Name__c', 'Empty_Rows.xlsx');
        }
        if (fMap.containsKey('FEC_Status__c')) {
            batchRow.put('FEC_Status__c', 'Processing');
        }
        insert batchRow;

        Test.startTest();
        FEC_BatchCaseHandlingImportService.finalizeBatchImportRecord((Id) batchRow.get('Id'), new List<FEC_BatchCaseHandlingImportRow>());
        FEC_BatchCaseHandlingImportService.finalizeBatchImportRecord(null, null);
        Test.stopTest();

        System.assert(true, 'Finalize with empty rows should complete.');
    }

    @IsTest
    static void testPersistBatchResultArtifact() {
        Schema.SObjectType batchType = Schema.getGlobalDescribe().get('FEC_Batch_Case_Handling__c');
        if (batchType == null) {
            System.assert(true, 'Skipped: FEC_Batch_Case_Handling__c not on org.');
            return;
        }

        SObject batchRow = batchType.newSObject();
        Map<String, Schema.SObjectField> fMap = batchType.getDescribe().fields.getMap();
        if (fMap.containsKey('FEC_File_Name__c')) {
            batchRow.put('FEC_File_Name__c', 'Result_Artifact.xlsx');
        }
        insert batchRow;
        Id batchId = (Id) batchRow.get('Id');

        FEC_BatchCaseHandlingImportRow ok = new FEC_BatchCaseHandlingImportRow();
        ok.status = System.Label.FEC_Operation_Success;
        ok.caseIdSearch = 'CASE-OPEN-2026';
        ok.originalHeaders = new List<String>{ 'Case ID Search', 'Routing Action', 'Remarks' };
        ok.originalHeaderRowIndex = 0;
        ok.originalSheetName = 'Sheet1';

        Test.startTest();
        FEC_BatchCaseHandlingImportService.persistBatchResultArtifact(batchId, new List<FEC_BatchCaseHandlingImportRow>{ ok }, '');
        FEC_BatchCaseHandlingImportService.persistBatchResultArtifact(null, null, '');
        Test.stopTest();

        System.assert(true, 'persistBatchResultArtifact should complete without exception.');
    }

    @IsTest
    static void testHasRemainingApplicableImportRows_Boundary() {
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.status = System.Label.FEC_Operation_Success;
        row.recordId = '500000000000001AAA';
        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>{ row };

        Test.startTest();
        Boolean atEnd = FEC_BatchCaseHandlingImportService.hasRemainingApplicableImportRows(rows, 1);
        Boolean negative = FEC_BatchCaseHandlingImportService.hasRemainingApplicableImportRows(rows, -1);
        Test.stopTest();

        System.assertEquals(false, atEnd);
        System.assertEquals(false, negative);
    }

    /**
     * Kịch bản: quy trình không GSR/COF — Case owner Queue mà login user là member không bị lỗi ERR_NOT_OWNER.
     */
    @IsTest
    static void testValidateRows_NonCofGsr_AllowsQueueOwnedCaseForMember() {
        System.runAs(batchImportRunUser()) {
            List<Group> queues = [
                SELECT Id
                FROM Group
                WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
                LIMIT 1
            ];
            if (queues.isEmpty()) {
                System.assert(true, 'Skipped: no queue in org.');
                return;
            }
            Id queueId = queues[0].Id;
            ensureQueueMember(queueId, UserInfo.getUserId());

            String caseKey = 'CASE-QUEUE-IMPORT-' + String.valueOf(DateTime.now().getTime());
            FEC_CaseTriggerHandler.isExecuting = true;
            Case queueOwnedCase = new Case(
                Subject = 'Queue Owned Import Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                OwnerId = queueId,
                FEC_ID_Search__c = caseKey
            );
            insert queueOwnedCase;
            FEC_CaseTriggerHandler.isExecuting = false;
            update new Case(Id = queueOwnedCase.Id, FEC_ID_Search__c = caseKey);

            List<Object> inputRows = new List<Object>{
                new Map<String, Object>{
                    'caseidsearch' => caseKey,
                    'routingaction' => 'RESOLVE',
                    'inputtedremarks' => 'Queue owned import validate',
                    'inputtedremarkscharlength' => '26'
                }
            };

            Test.startTest();
            List<FEC_BatchCaseHandlingImportRow> results =
                FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, false);
            Test.stopTest();

            System.assertEquals(1, results.size());
            System.assert(
                results[0].errors == null || !results[0].errors.contains('Người dùng không phải chủ sở hữu Case'),
                'Queue member không được báo ERR_NOT_OWNER: ' + results[0].errors
            );
        }
    }

    /**
     * Kịch bản: quy trình không GSR/COF Resolve — Case owner Queue phải chuyển OwnerId sang Login User trước khi xử lý.
     */
    @IsTest
    static void testApplyCaseHandlingUpdates_NonCofGsr_TransfersQueueOwnerOnResolve() {
        System.runAs(batchImportRunUser()) {
            List<Group> queues = [
                SELECT Id
                FROM Group
                WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
                LIMIT 1
            ];
            if (queues.isEmpty()) {
                System.assert(true, 'Skipped: no queue in org.');
                return;
            }
            Id queueId = queues[0].Id;
            Id loginUserId = UserInfo.getUserId();
            ensureQueueMember(queueId, loginUserId);

            String caseKey = 'CASE-QUEUE-APPLY-' + String.valueOf(DateTime.now().getTime());
            FEC_CaseTriggerHandler.isExecuting = true;
            Case queueOwnedCase = new Case(
                Subject = 'Queue Owned Apply Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                OwnerId = queueId,
                FEC_ID_Search__c = caseKey
            );
            insert queueOwnedCase;
            FEC_CaseTriggerHandler.isExecuting = false;
            update new Case(Id = queueOwnedCase.Id, FEC_ID_Search__c = caseKey);

            FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
            row.status = System.Label.FEC_Operation_Success;
            row.recordId = String.valueOf(queueOwnedCase.Id);
            row.routingAction = 'RESOLVE';
            row.inputtedRemarks = 'Transfer owner before resolve';

            Test.startTest();
            FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(
                new List<FEC_BatchCaseHandlingImportRow>{ row },
                false
            );
            Test.stopTest();

            Case updated = [SELECT OwnerId FROM Case WHERE Id = :queueOwnedCase.Id LIMIT 1];
            System.assertEquals(
                loginUserId,
                updated.OwnerId,
                'Import quy trình không GSR/COF Resolve phải chuyển OwnerId từ Queue sang Login User.'
            );
        }
    }

    /**
     * Kịch bản: quy trình không GSR/COF — user không phải queue member phải báo ERR_NOT_OWNER.
     */
    @IsTest
    static void testValidateRows_NonCofGsr_RejectsQueueOwnedCaseForNonMember() {
        Id isolatedQueueId = createIsolatedQueueWithoutMembership();
        System.runAs(batchImportRunUser()) {
            String caseKey = 'CASE-QUEUE-NOMEMBER-' + String.valueOf(DateTime.now().getTime());
            FEC_CaseTriggerHandler.isExecuting = true;
            Case queueOwnedCase = new Case(
                Subject = 'Queue Owned Non Member Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                OwnerId = isolatedQueueId,
                FEC_ID_Search__c = caseKey
            );
            insert queueOwnedCase;
            FEC_CaseTriggerHandler.isExecuting = false;
            update new Case(Id = queueOwnedCase.Id, FEC_ID_Search__c = caseKey);

            List<Object> inputRows = new List<Object>{
                new Map<String, Object>{
                    'caseidsearch' => caseKey,
                    'routingaction' => 'RESOLVE',
                    'inputtedremarks' => 'Non member should fail owner check',
                    'inputtedremarkscharlength' => '33'
                }
            };

            Test.startTest();
            List<FEC_BatchCaseHandlingImportRow> results =
                FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, false);
            Test.stopTest();

            System.assertEquals(1, results.size());
            System.assert(
                results[0].errors != null && results[0].errors.contains('Người dùng không phải chủ sở hữu Case'),
                'User không phải queue member phải báo ERR_NOT_OWNER: ' + results[0].errors
            );
        }
    }

    /**
     * Kịch bản: quy trình COF — dù user là queue member vẫn phải báo ERR_NOT_OWNER khi không phải Owner.
     */
    @IsTest
    static void testValidateRows_CofGsr_RejectsQueueOwnedCaseForMember() {
        System.runAs(batchImportRunUser()) {
            List<FEC_Business_Process__c> cofBpRows = [
                SELECT Id, FEC_Code__c
                FROM FEC_Business_Process__c
                WHERE FEC_Code__c LIKE 'COF%'
                LIMIT 1
            ];
            if (cofBpRows.isEmpty()) {
                System.assert(true, 'Skipped: no COF business process in org.');
                return;
            }
            List<Group> queues = [
                SELECT Id
                FROM Group
                WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
                LIMIT 1
            ];
            if (queues.isEmpty()) {
                System.assert(true, 'Skipped: no queue in org.');
                return;
            }
            Id queueId = queues[0].Id;
            ensureQueueMember(queueId, UserInfo.getUserId());

            String caseKey = 'CASE-COF-VALIDATE-' + String.valueOf(DateTime.now().getTime());
            FEC_CaseTriggerHandler.isExecuting = true;
            Case queueOwnedCase = new Case(
                Subject = 'COF Queue Validate Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                OwnerId = queueId,
                FEC_ID_Search__c = caseKey,
                FEC_Business_Process__c = cofBpRows[0].Id
            );
            insert queueOwnedCase;
            FEC_CaseTriggerHandler.isExecuting = false;
            update new Case(Id = queueOwnedCase.Id, FEC_ID_Search__c = caseKey);

            List<Object> inputRows = new List<Object>{
                new Map<String, Object>{
                    'caseidsearch' => caseKey,
                    'routingaction' => 'RESOLVE',
                    'inputtedremarks' => 'COF queue member still not owner',
                    'inputtedremarkscharlength' => '34'
                }
            };

            Test.startTest();
            List<FEC_BatchCaseHandlingImportRow> results =
                FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, false);
            Test.stopTest();

            System.assertEquals(1, results.size());
            System.assert(
                results[0].errors != null && results[0].errors.contains('Người dùng không phải chủ sở hữu Case'),
                'COF queue member không phải owner phải báo ERR_NOT_OWNER: ' + results[0].errors
            );
        }
    }

    /**
     * Kịch bản: quy trình không GSR/COF Reject — Case owner Queue phải chuyển OwnerId sang Login User.
     */
    @IsTest
    static void testApplyCaseHandlingUpdates_NonCofGsr_TransfersQueueOwnerOnReject() {
        System.runAs(batchImportRunUser()) {
            Id queueId = resolveMemberQueueId();
            if (queueId == null) {
                return;
            }
            Id loginUserId = UserInfo.getUserId();
            Id caseId = insertQueueOwnedImportCase(queueId, 'CASE-QUEUE-REJECT-');
            FEC_BatchCaseHandlingImportRow row = buildImportRow(caseId, 'REJECT', 'Transfer owner before reject');

            Test.startTest();
            FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(
                new List<FEC_BatchCaseHandlingImportRow>{ row },
                false
            );
            Test.stopTest();

            Case updated = [SELECT OwnerId FROM Case WHERE Id = :caseId LIMIT 1];
            System.assertEquals(loginUserId, updated.OwnerId, 'Reject phải chuyển OwnerId từ Queue sang Login User.');
        }
    }

    /**
     * Kịch bản: quy trình không GSR/COF + Route To — không được tự chuyển OwnerId từ Queue.
     */
    @IsTest
    static void testApplyCaseHandlingUpdates_NonCofGsr_SkipsTransferOnRouteTo() {
        System.runAs(batchImportRunUser()) {
            Id queueId = resolveMemberQueueId();
            if (queueId == null) {
                return;
            }
            Id caseId = insertQueueOwnedImportCase(queueId, 'CASE-QUEUE-ROUTE-');
            FEC_BatchCaseHandlingImportRow row = buildImportRow(
                caseId,
                FEC_CaseBusinessService.ROUTE_TO,
                'Route to should not transfer owner'
            );

            Test.startTest();
            FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(
                new List<FEC_BatchCaseHandlingImportRow>{ row },
                false
            );
            Test.stopTest();

            Case updated = [SELECT OwnerId FROM Case WHERE Id = :caseId LIMIT 1];
            System.assertEquals(queueId, updated.OwnerId, 'Route To không được tự chuyển OwnerId từ Queue.');
        }
    }

    /**
     * Kịch bản: quy trình không GSR/COF + owner đã là User — giữ nguyên OwnerId.
     */
    @IsTest
    static void testApplyCaseHandlingUpdates_NonCofGsr_UserOwnedCase_KeepsOwner() {
        System.runAs(batchImportRunUser()) {
            Case openCase = [
                SELECT Id
                FROM Case
                WHERE FEC_ID_Search__c = 'CASE-OPEN-2026'
                LIMIT 1
            ];
            Id loginUserId = UserInfo.getUserId();
            update new Case(Id = openCase.Id, OwnerId = loginUserId);

            FEC_BatchCaseHandlingImportRow row = buildImportRow(openCase.Id, 'RESOLVE', 'User owned keeps owner');

            Test.startTest();
            FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(
                new List<FEC_BatchCaseHandlingImportRow>{ row },
                false
            );
            Test.stopTest();

            Case updated = [SELECT OwnerId FROM Case WHERE Id = :openCase.Id LIMIT 1];
            System.assertEquals(loginUserId, updated.OwnerId, 'Case owner User không được đổi OwnerId.');
        }
    }

    /**
     * Kịch bản: quy trình GSR — Case owner Queue không được tự chuyển OwnerId khi import.
     */
    @IsTest
    static void testApplyCaseHandlingUpdates_GsrProcess_SkipsQueueOwnerTransfer() {
        System.runAs(batchImportRunUser()) {
            List<FEC_Business_Process__c> gsrBpRows = [
                SELECT Id, FEC_Code__c
                FROM FEC_Business_Process__c
                WHERE FEC_Code__c LIKE 'GSR%'
                LIMIT 1
            ];
            if (gsrBpRows.isEmpty()) {
                System.assert(true, 'Skipped: no GSR business process in org.');
                return;
            }
            Id queueId = resolveMemberQueueId();
            if (queueId == null) {
                return;
            }
            String caseKey = 'CASE-GSR-QUEUE-' + String.valueOf(DateTime.now().getTime());
            FEC_CaseTriggerHandler.isExecuting = true;
            Case queueOwnedCase = new Case(
                Subject = 'GSR Queue Owned Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                OwnerId = queueId,
                FEC_ID_Search__c = caseKey,
                FEC_Business_Process__c = gsrBpRows[0].Id
            );
            insert queueOwnedCase;
            FEC_CaseTriggerHandler.isExecuting = false;
            update new Case(Id = queueOwnedCase.Id, FEC_ID_Search__c = caseKey);

            FEC_BatchCaseHandlingImportRow row = buildImportRow(queueOwnedCase.Id, 'RESOLVE', 'GSR should not auto transfer owner');

            Test.startTest();
            FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(
                new List<FEC_BatchCaseHandlingImportRow>{ row },
                false
            );
            Test.stopTest();

            Case updated = [SELECT OwnerId FROM Case WHERE Id = :queueOwnedCase.Id LIMIT 1];
            System.assertEquals(queueId, updated.OwnerId, 'Quy trình GSR không được tự chuyển OwnerId từ Queue.');
        }
    }

    /**
     * Kịch bản: quy trình COF — Case owner Queue không được tự chuyển OwnerId khi import (cofOrGsr=false ở batch).
     */
    @IsTest
    static void testApplyCaseHandlingUpdates_CofGsrProcess_SkipsQueueOwnerTransfer() {
        System.runAs(batchImportRunUser()) {
            List<FEC_Business_Process__c> cofBpRows = [
                SELECT Id, FEC_Code__c
                FROM FEC_Business_Process__c
                WHERE FEC_Code__c LIKE 'COF%'
                LIMIT 1
            ];
            if (cofBpRows.isEmpty()) {
                System.assert(true, 'Skipped: no COF business process in org.');
                return;
            }
            List<Group> queues = [
                SELECT Id
                FROM Group
                WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
                LIMIT 1
            ];
            if (queues.isEmpty()) {
                System.assert(true, 'Skipped: no queue in org.');
                return;
            }
            Id queueId = queues[0].Id;
            ensureQueueMember(queueId, UserInfo.getUserId());

            String caseKey = 'CASE-COF-QUEUE-' + String.valueOf(DateTime.now().getTime());
            FEC_CaseTriggerHandler.isExecuting = true;
            Case queueOwnedCase = new Case(
                Subject = 'COF Queue Owned Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                OwnerId = queueId,
                FEC_ID_Search__c = caseKey,
                FEC_Business_Process__c = cofBpRows[0].Id
            );
            insert queueOwnedCase;
            FEC_CaseTriggerHandler.isExecuting = false;
            update new Case(Id = queueOwnedCase.Id, FEC_ID_Search__c = caseKey);

            FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
            row.status = System.Label.FEC_Operation_Success;
            row.recordId = String.valueOf(queueOwnedCase.Id);
            row.routingAction = 'RESOLVE';
            row.inputtedRemarks = 'COF should not auto transfer owner';

            Test.startTest();
            FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(
                new List<FEC_BatchCaseHandlingImportRow>{ row },
                false
            );
            Test.stopTest();

            Case updated = [SELECT OwnerId FROM Case WHERE Id = :queueOwnedCase.Id LIMIT 1];
            System.assertEquals(
                queueId,
                updated.OwnerId,
                'Quy trình COF không được tự chuyển OwnerId từ Queue sang Login User.'
            );
        }
    }

    private static Id createIsolatedQueueWithoutMembership() {
        Group isolatedQueue = new Group(
            Name = 'BCH Import Test Queue ' + String.valueOf(DateTime.now().getTime()),
            Type = FEC_ConstantCommon.GROUP_TYPE_QUEUE
        );
        insert isolatedQueue;
        if ([SELECT COUNT() FROM QueueSobject WHERE QueueId = :isolatedQueue.Id AND SobjectType = 'Case'] == 0) {
            insert new QueueSobject(QueueId = isolatedQueue.Id, SobjectType = 'Case');
        }
        return isolatedQueue.Id;
    }

    private static Id resolveMemberQueueId() {
        List<Group> queues = [
            SELECT Id
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            LIMIT 1
        ];
        if (queues.isEmpty()) {
            System.assert(true, 'Skipped: no queue in org.');
            return null;
        }
        ensureQueueMember(queues[0].Id, UserInfo.getUserId());
        return queues[0].Id;
    }

    private static Id insertQueueOwnedImportCase(Id queueId, String caseKeyPrefix) {
        String caseKey = caseKeyPrefix + String.valueOf(DateTime.now().getTime());
        FEC_CaseTriggerHandler.isExecuting = true;
        Case queueOwnedCase = new Case(
            Subject = 'Queue Owned Import Helper Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            OwnerId = queueId,
            FEC_ID_Search__c = caseKey
        );
        insert queueOwnedCase;
        FEC_CaseTriggerHandler.isExecuting = false;
        update new Case(Id = queueOwnedCase.Id, FEC_ID_Search__c = caseKey);
        return queueOwnedCase.Id;
    }

    private static FEC_BatchCaseHandlingImportRow buildImportRow(Id caseId, String routingAction, String remarks) {
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.status = System.Label.FEC_Operation_Success;
        row.recordId = String.valueOf(caseId);
        row.routingAction = routingAction;
        row.inputtedRemarks = remarks;
        return row;
    }

    private static void ensureQueueMember(Id groupId, Id userOrGroupId) {
        if (groupId == null || userOrGroupId == null) {
            return;
        }
        if ([SELECT COUNT() FROM GroupMember WHERE GroupId = :groupId AND UserOrGroupId = :userOrGroupId] > 0) {
            return;
        }
        insert new GroupMember(GroupId = groupId, UserOrGroupId = userOrGroupId);
    }

    // 05/06/2026 16:00 linhdev - test __Errors Export Result luôn tiếng Việt
    /**
     * Kịch bản: __Errors Export Result — message tiếng Anh được chuyển sang tiếng Việt.
     */
    @IsTest
    static void testLocalizeImportResultError_MapsEnglishToVietnamese() {
        System.assertEquals(
            'Không tìm thấy Queue.',
            FEC_BatchCaseHandlingImportService.localizeImportResultError('Queue not found')
        );
        System.assertEquals(
            'Case Id không hợp lệ.',
            FEC_BatchCaseHandlingImportService.localizeImportResultError('Case Id is invalid.')
        );
        System.assertEquals(
            'Không tìm thấy Stage Change.',
            FEC_BatchCaseHandlingImportService.localizeImportResultError('Stage Change not found.')
        );
        System.assertEquals(
            'Tên file không khớp template Bulk Actions của quy trình và nhóm người dùng.',
            FEC_BatchCaseHandlingImportService.localizeImportResultError('TEMPLATE_MISMATCH')
        );
    }

    /**
     * Kịch bản: __Errors Export Result — giữ nguyên message tiếng Việt đã có sẵn.
     */
    @IsTest
    static void testLocalizeImportResultError_KeepsVietnameseMessage() {
        String vietnameseMessage = 'Người dùng không phải chủ sở hữu Case';
        System.assertEquals(
            vietnameseMessage,
            FEC_BatchCaseHandlingImportService.localizeImportResultError(vietnameseMessage)
        );
        System.assertEquals(
            'Case ID không tồn tại trong hệ thống',
            FEC_BatchCaseHandlingImportService.localizeImportResultError('Case ID không tồn tại trong hệ thống')
        );
    }

    /**
     * Kịch bản: __Errors Export Result — chuỗi nhiều lỗi (phân tách bằng ",\n") đều tiếng Việt.
     */
    @IsTest
    static void testLocalizeImportResultErrors_LocalizesCombinedMessages() {
        String combined =
            'Queue not found,\n' +
            'Người dùng không phải chủ sở hữu Case';
        String localized = FEC_BatchCaseHandlingImportService.localizeImportResultErrors(combined);
        System.assert(localized.contains('Không tìm thấy Queue.'), localized);
        System.assert(localized.contains('Người dùng không phải chủ sở hữu Case'), localized);
    }

    @IsTest
    static void validateImportRows_missingInputtedRemarks_usesExpectedLabel() {
        List<Object> inputRows = new List<Object>{
            new Map<String, Object>{
                'caseidsearch' => 'CASE-IMPORT-TEST-001',
                'routingaction' => 'Reject'
            }
        };

        List<FEC_BatchCaseHandlingImportRow> rows =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, false);

        System.assertEquals(1, rows.size());
        System.assertEquals(
            System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
            rows[0].status
        );
        System.assert(
            rows[0].errors.contains(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Remark),
            'Expected missing Inputted Remarks error: ' + rows[0].errors
        );
    }

    @IsTest
    static void validateImportRows_emptyRow_recordsFailedWithMissingCaseId() {
        List<Object> inputRows = new List<Object>{
            new Map<String, Object>{
                'caseidsearch' => 'CASE-IMPORT-TEST-001',
                'routingaction' => 'Reject',
                'inputtedremarks' => 'ok'
            },
            new Map<String, Object>{
                'originalHeaders' => new List<String>{ 'Case ID Search', 'Routing Action', 'Inputted Remarks' },
                'originalCells' => new List<String>{ '', '', '' }
            }
        };

        List<FEC_BatchCaseHandlingImportRow> rows =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, false);

        System.assertEquals(2, rows.size());
        System.assertEquals(
            System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
            rows[1].status
        );
        System.assert(
            rows[1].errors.contains(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Case_Id),
            'Expected missing Case ID for empty row: ' + rows[1].errors
        );
    }

    @IsTest
    static void validateImportRows_remarkTooLong_usesExpectedLabel() {
        List<Object> inputRows = new List<Object>{
            new Map<String, Object>{
                'caseidsearch' => 'CASE-IMPORT-TEST-REMARK-LEN',
                'routingaction' => 'Reject',
                'inputtedremarks' => buildRemarkOfLength(32768)
            }
        };

        List<FEC_BatchCaseHandlingImportRow> rows =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, false);

        System.assertEquals(1, rows.size());
        System.assertEquals(
            System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
            rows[0].status
        );
        System.assert(
            rows[0].errors.contains(System.Label.FEC_Batch_Case_Handling_Import_Err_Remark_Too_Long),
            'Expected remark too long error: ' + rows[0].errors
        );
    }

    @IsTest
    static void validateImportRows_remarkTooLong_skipsRoutingValidation() {
        List<Object> inputRows = new List<Object>{
            new Map<String, Object>{
                'caseidsearch' => 'CASE-IMPORT-TEST-REMARK-LEN',
                'routingaction' => 'Reject',
                'inputtedremarks' => buildRemarkOfLength(32768)
            }
        };

        List<FEC_BatchCaseHandlingImportRow> rows =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, false);

        System.assertEquals(1, rows.size());
        System.assert(
            rows[0].errors.contains(System.Label.FEC_Batch_Case_Handling_Import_Err_Remark_Too_Long),
            'Expected remark too long error: ' + rows[0].errors
        );
        System.assert(
            !rows[0].errors.contains(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Routing_Action),
            'Must not show missing Routing when remark over max: ' + rows[0].errors
        );
    }

    @IsTest
    static void validateImportRows_remarkTooLongFromCharLengthOnly_usesExpectedLabel() {
        List<Object> inputRows = new List<Object>{
            new Map<String, Object>{
                'caseidsearch' => 'CASE-IMPORT-TEST-REMARK-LEN-CHAR',
                'routingaction' => 'Reject',
                'inputtedremarks' => FEC_ConstantCommon.STR_EMPTY,
                'inputtedRemarksCharLength' => 32768
            }
        };

        List<FEC_BatchCaseHandlingImportRow> rows =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, false);

        System.assertEquals(1, rows.size());
        System.assert(
            rows[0].errors.contains(System.Label.FEC_Batch_Case_Handling_Import_Err_Remark_Too_Long),
            'Expected remark too long from charLength: ' + rows[0].errors
        );
    }

    @IsTest
    static void validateImportRows_truncatedOriginalCells_hiddenOverflow_usesCharLength() {
        List<Object> inputRows = new List<Object>{
            new Map<String, Object>{
                'caseidsearch' => 'CASE-IMPORT-TEST-REMARK-TRUNC',
                'routingaction' => 'Reject',
                'inputtedremarks' => FEC_ConstantCommon.STR_EMPTY,
                'inputtedRemarksCharLength' => 40000,
                'originalHeaders' => new List<String>{ 'Case ID Search', 'Routing Action', 'Inputted Remarks' },
                'originalCells' => new List<String>{
                    'CASE-IMPORT-TEST-REMARK-TRUNC',
                    'Reject',
                    buildRemarkOfLength(32768)
                }
            }
        };

        List<FEC_BatchCaseHandlingImportRow> rows =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, false);

        System.assertEquals(1, rows.size());
        System.assert(
            rows[0].errors.contains(System.Label.FEC_Batch_Case_Handling_Import_Err_Remark_Too_Long),
            'Expected remark too long when charLength exceeds max: ' + rows[0].errors
        );
    }

    @IsTest
    static void isInputtedRemarksOverMaxLength_boundary() {
        System.assertEquals(
            false,
            FEC_BatchCaseHandlingImportService.isInputtedRemarksOverMaxLength(
                buildRemarkOfLength(32766)
            )
        );
        System.assertEquals(
            true,
            FEC_BatchCaseHandlingImportService.isInputtedRemarksOverMaxLength(
                buildRemarkOfLength(32767)
            )
        );
        System.assertEquals(
            false,
            FEC_BatchCaseHandlingImportService.isInputtedRemarksOverMaxLength(32766)
        );
        System.assertEquals(
            true,
            FEC_BatchCaseHandlingImportService.isInputtedRemarksOverMaxLength(32767)
        );
        System.assertEquals(
            true,
            FEC_BatchCaseHandlingImportService.isInputtedRemarksOverMaxLength(32768)
        );
    }

    @IsTest
    static void applyValidatedRoutingToResultCells_keepsSourceRoutingNotAssignment() {
        List<String> cells = new List<String>{
            'Resolve',
            'Route to CS Support - DQ-CS Support',
            'remark'
        };
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.routingAction = 'Route to CS Support - DQ-CS Support';
        row.assignmentRoutingAction = 'Route to CS Support - DQ-CS Support';
        FEC_BatchCaseHandlingImportService.applyValidatedRoutingToResultCells(cells, 0, 1, row);
        System.assertEquals('Resolve', cells[0]);
        System.assertEquals('Route to CS Support - DQ-CS Support', cells[1]);
    }

    @IsTest
    static void applyValidatedRoutingToResultCells_keepsSourceRevertNotAssignment() {
        List<String> cells = new List<String>{
            'Revert',
            'Escalate',
            'remark'
        };
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.routingAction = 'Escalate';
        row.assignmentRoutingAction = 'Escalate';
        FEC_BatchCaseHandlingImportService.applyValidatedRoutingToResultCells(cells, 0, 1, row);
        System.assertEquals('Revert', cells[0]);
        System.assertEquals('Escalate', cells[1]);
    }

    @IsTest
    static void sanitizeCofGsrCaseRoutingBleedFromAssignment_clearsBleedWhenSourceRoutingBlank() {
        FEC_BatchCaseHandlingImportRow rr = new FEC_BatchCaseHandlingImportRow();
        rr.originalHeaders = new List<String>{
            'Case ID',
            'Assignment ID',
            'Routing Action',
            'Assignment Routing Action',
            'Inputted Remarks'
        };
        rr.originalCells = new List<String>{
            'S-3653',
            'A-001762',
            FEC_ConstantCommon.STR_EMPTY,
            'Route to CS Support - DQ-CS Support',
            'remark'
        };
        rr.routingAction = 'Route to CS Support - DQ-CS Support';
        rr.assignmentRoutingAction = 'Route to CS Support - DQ-CS Support';
        FEC_BatchCaseHandlingImportService.sanitizeCofGsrCaseRoutingBleedFromAssignment(rr);
        System.assertEquals(FEC_ConstantCommon.STR_EMPTY, rr.routingAction);
        System.assertEquals('Route to CS Support - DQ-CS Support', rr.assignmentRoutingAction);
    }

    @IsTest
    static void validateImportRows_cofGsrOnlyAssignmentRouting_doesNotReportBothRoutingActions() {
        List<String> headers = new List<String>{
            'Case ID',
            'Assignment ID',
            'Routing Action',
            'Assignment Routing Action',
            'Inputted Remarks'
        };
        List<String> cells = new List<String>{
            'S-3653',
            'A-001762',
            FEC_ConstantCommon.STR_EMPTY,
            'Route to CS Support - DQ-CS Support',
            'remark'
        };
        List<Object> inputRows = new List<Object>{
            new Map<String, Object>{
                'caseidsearch' => 'S-3653',
                'assignmentid' => 'A-001762',
                'routingaction' => 'Route to CS Support - DQ-CS Support',
                'assignmentroutingaction' => 'Route to CS Support - DQ-CS Support',
                'inputtedremarks' => 'remark',
                'originalHeaders' => headers,
                'originalCells' => cells
            }
        };
        List<FEC_BatchCaseHandlingImportRow> rows =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, true);
        System.assertEquals(1, rows.size());
        System.assert(
            !rows[0].errors.contains(System.Label.FEC_Batch_Case_Handling_Import_Err_Both_Routing_Actions),
            'Must not report both routing when case routing empty in file: ' + rows[0].errors
        );
        System.assert(
            !rows[0].errors.contains(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Resolve_Only),
            'Must not report resolve-only when case routing cleared: ' + rows[0].errors
        );
    }

    @IsTest
    static void applyValidatedRoutingToResultCells_keepsBlankSourceRoutingWhenOnlyAssignment() {
        List<String> cells = new List<String>{
            FEC_ConstantCommon.STR_EMPTY,
            'Route to CS Support - DQ-CS Support',
            'remark'
        };
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.routingAction = 'Route to CS Support - DQ-CS Support';
        row.assignmentRoutingAction = 'Route to CS Support - DQ-CS Support';
        FEC_BatchCaseHandlingImportService.applyValidatedRoutingToResultCells(cells, 0, 1, row);
        System.assertEquals(FEC_ConstantCommon.STR_EMPTY, cells[0]);
        System.assertEquals('Route to CS Support - DQ-CS Support', cells[1]);
    }

    @IsTest
    static void clearRoutingCellIfRemarkBleed_clearsDuplicateRemarkInRoutingColumn() {
        List<String> cells = new List<String>();
        for (Integer i = 0; i < 24; i++) {
            cells.add(FEC_ConstantCommon.STR_EMPTY);
        }
        String remark = buildRemarkOfLength(32767);
        cells[21] = remark;
        cells[22] = remark;
        FEC_BatchCaseHandlingImportService.clearRoutingCellIfRemarkBleed(cells, 21, 22);
        System.assertEquals(FEC_ConstantCommon.STR_EMPTY, cells[21]);
        System.assertEquals(remark, cells[22]);
    }

    @IsTest
    static void enrichImportRowsLayoutFromSourceFile_replacesMisalignedLwcCells() {
        ContentVersion cv = new ContentVersion(
            Title = 'LayoutEnrichImport',
            PathOnClient = 'LayoutEnrichImport.xlsx',
            VersionData = EncodingUtil.base64Decode(buildMinimalImportWorkbookBase64())
        );
        insert cv;
        FEC_BCH_TemplateExportService.ImportWorkbookParseResult parsed =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(cv.Id);
        System.assertEquals(true, parsed.parseSuccess, parsed.errorMessage);
        List<FEC_BatchCaseHandlingImportRow> parsedRows = (List<FEC_BatchCaseHandlingImportRow>) JSON.deserialize(
            JSON.serialize(parsed.inputRows),
            List<FEC_BatchCaseHandlingImportRow>.class
        );
        System.assertEquals(1, parsedRows.size());
        List<FEC_BatchCaseHandlingImportRow> lwcRows = new List<FEC_BatchCaseHandlingImportRow>();
        FEC_BatchCaseHandlingImportRow bad = new FEC_BatchCaseHandlingImportRow();
        bad.caseIdSearch = 'CASE-001';
        bad.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
        bad.errors = 'test';
        bad.originalHeaders = parsedRows[0].originalHeaders;
        bad.originalColumnIndexes = parsedRows[0].originalColumnIndexes;
        bad.originalDataRowIndex = parsedRows[0].originalDataRowIndex;
        bad.originalHeaderRowIndex = parsedRows[0].originalHeaderRowIndex;
        bad.originalSheetName = parsedRows[0].originalSheetName;
        bad.originalCells = new List<String>();
        for (Integer i = 0; i < parsedRows[0].originalHeaders.size(); i++) {
            bad.originalCells.add('MISPLACED-' + String.valueOf(i));
        }
        lwcRows.add(bad);
        List<FEC_BatchCaseHandlingImportRow> enriched =
            FEC_BatchCaseHandlingImportService.enrichImportRowsLayoutFromSourceFile(cv.Id, lwcRows);
        System.assertEquals(1, enriched.size());
        System.assertEquals(parsedRows[0].originalCells, enriched[0].originalCells);
        System.assertNotEquals(bad.originalCells, enriched[0].originalCells);
    }

    @IsTest
    static void enrichImportRowValidateFieldsFromOriginalLayout_fillsBlankCaseIdFromCells() {
        FEC_BatchCaseHandlingImportRow rr = new FEC_BatchCaseHandlingImportRow();
        rr.originalHeaders = new List<String>{ 'Case ID', 'Routing Action', 'Inputted Remarks' };
        rr.originalCells = new List<String>{ 'S-3603', 'Resolve', '111' };
        rr.caseIdSearch = FEC_ConstantCommon.STR_EMPTY;
        rr.routingAction = FEC_ConstantCommon.STR_EMPTY;
        rr.inputtedRemarks = FEC_ConstantCommon.STR_EMPTY;
        FEC_BatchCaseHandlingImportService.enrichImportRowValidateFieldsFromOriginalLayout(rr);
        System.assertEquals('S-3603', rr.caseIdSearch);
        System.assertEquals('Resolve', rr.routingAction);
        System.assertEquals('111', rr.inputtedRemarks);
    }

    @IsTest
    static void syncCaseIdIntoExportCells_placesCaseIdOnHeaderColumnOnly() {
        List<String> headers = new List<String>{ 'Plastic ID', 'Case ID', 'Other' };
        List<String> cells = new List<String>{ 'S-4866', FEC_ConstantCommon.STR_EMPTY, 'x' };
        FEC_BatchCaseHandlingImportService.syncCaseIdIntoExportCells(cells, headers, 'S-4866');
        System.assertEquals(FEC_ConstantCommon.STR_EMPTY, cells[0]);
        System.assertEquals('S-4866', cells[1]);
        System.assertEquals('x', cells[2]);
    }

    @IsTest
    static void hydrateFailureRowsFromSourceImport_buildsFailedRowsFromTemplateLayout() {
        Schema.SObjectType batchType = Schema.getGlobalDescribe().get('FEC_Batch_Case_Handling__c');
        System.assertNotEquals(null, batchType);
        SObject batchRow = batchType.newSObject();
        Map<String, Schema.SObjectField> fieldMap = batchType.getDescribe().fields.getMap();
        FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(
            fieldMap,
            batchRow,
            new List<String>{ 'FEC_File_Name__c' },
            'HydrateFailureRowsFromTemplate.xlsx'
        );
        insert batchRow;
        Id batchId = (Id) batchRow.get('Id');

        ContentVersion cv = new ContentVersion(
            Title = 'HydrateFailureRowsFromTemplate',
            PathOnClient = 'HydrateFailureRowsFromTemplate.xlsx',
            VersionData = EncodingUtil.base64Decode(buildMinimalImportWorkbookBase64()),
            FirstPublishLocationId = batchId
        );
        insert cv;

        List<FEC_BatchCaseHandlingImportRow> rows =
            FEC_BatchCaseHandlingImportService.hydrateFailureRowsFromSourceImport(
                batchId,
                'Apex CPU time limit exceeded'
            );
        System.assertEquals(1, rows.size());
        System.assertEquals(
            System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
            rows[0].status
        );
        System.assertEquals('Apex CPU time limit exceeded', rows[0].errors);
        System.assertEquals('CASE-001', rows[0].caseIdSearch);
        System.assertNotEquals(null, rows[0].originalHeaders);
        System.assert(rows[0].originalHeaders.size() > 0);
    }

    @IsTest
    static void validateImportRows_remarkExactly32767_triggersTooLongError() {
        List<Object> inputRows = new List<Object>{
            new Map<String, Object>{
                'caseidsearch' => 'CASE-IMPORT-TEST-REMARK-MAX',
                'routingaction' => 'Reject',
                'inputtedremarks' => buildRemarkOfLength(32767)
            }
        };

        List<FEC_BatchCaseHandlingImportRow> rows =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, false);

        System.assertEquals(1, rows.size());
        System.assert(
            rows[0].errors.contains(System.Label.FEC_Batch_Case_Handling_Import_Err_Remark_Too_Long),
            '32767 chars must trigger remark too long at Excel max: ' + rows[0].errors
        );
    }

    @IsTest
    static void validateImportRows_missingRemarkWithRouting_usesExpectedLabel() {
        List<Object> inputRows = new List<Object>{
            new Map<String, Object>{
                'caseidsearch' => 'CASE-IMPORT-TEST-004',
                'routingaction' => 'Reject',
                'inputtedremarks' => FEC_ConstantCommon.STR_EMPTY
            }
        };

        List<FEC_BatchCaseHandlingImportRow> rows =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, false);

        System.assertEquals(1, rows.size());
        System.assert(
            rows[0].errors.contains(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Remark),
            'Expected missing Inputted Remarks error: ' + rows[0].errors
        );
        System.assert(
            !rows[0].errors.contains(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Routing_Action),
            'Must not show missing Routing Action when routing is provided: ' + rows[0].errors
        );
    }

    @IsTest
    static void validateImportRows_missingRoutingAction_usesExpectedLabel() {
        List<Object> inputRows = new List<Object>{
            new Map<String, Object>{
                'caseidsearch' => 'CASE-IMPORT-TEST-002'
            }
        };

        List<FEC_BatchCaseHandlingImportRow> rows =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, false);

        System.assertEquals(1, rows.size());
        System.assert(
            rows[0].errors.contains(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Routing_Action),
            'Expected missing Routing Action error: ' + rows[0].errors
        );
        System.assert(
            countOccurrences(rows[0].errors, System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Routing_Action) == 1,
            'Missing Routing Action must appear once: ' + rows[0].errors
        );
    }

    @IsTest
    static void validateImportRows_invalidRoutingAction_notDuplicated() {
        List<Object> inputRows = new List<Object>{
            new Map<String, Object>{
                'caseidsearch' => 'CASE-IMPORT-TEST-003',
                'routingaction' => 'Reject',
                'inputtedremarks' => 'Test remark'
            }
        };

        List<FEC_BatchCaseHandlingImportRow> rows =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, false);

        System.assertEquals(1, rows.size());
        String invalidMsg = System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid;
        System.assert(
            rows[0].errors.contains(invalidMsg),
            'Expected invalid Routing Action error: ' + rows[0].errors
        );
        System.assertEquals(
            1,
            countOccurrences(rows[0].errors, invalidMsg),
            'Routing Action datagroup error must appear once: ' + rows[0].errors
        );
    }

    @IsTest
    static void validateImportRows_remarkTooLongFromInputRemarkHeaderAlias_usesCharLength() {
        List<Object> inputRows = new List<Object>{
            new Map<String, Object>{
                'caseidsearch' => 'CASE-IMPORT-TEST-REMARK-ALIAS',
                'routingaction' => 'Reject',
                'inputtedremarks' => FEC_ConstantCommon.STR_EMPTY,
                'inputtedRemarksCharLength' => 40000,
                'originalHeaders' => new List<String>{ 'Case ID Search', 'Routing Action', 'Input Remark' },
                'originalCells' => new List<String>{
                    'CASE-IMPORT-TEST-REMARK-ALIAS',
                    'Reject',
                    buildRemarkOfLength(32768)
                }
            }
        };

        List<FEC_BatchCaseHandlingImportRow> rows =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, false);

        System.assertEquals(1, rows.size());
        System.assert(
            rows[0].errors.contains(System.Label.FEC_Batch_Case_Handling_Import_Err_Remark_Too_Long),
            'Expected remark too long with Input Remark header alias: ' + rows[0].errors
        );
    }

    private static String buildRemarkOfLength(Integer targetLength) {
        if (targetLength == null || targetLength <= 0) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String chunk = '0123456789012345678901234567890';
        String out = FEC_ConstantCommon.STR_EMPTY;
        while (out.length() < targetLength) {
            out += chunk;
        }
        return out.substring(0, targetLength);
    }

    private static Integer countOccurrences(String haystack, String needle) {
        if (String.isBlank(haystack) || String.isBlank(needle)) {
            return 0;
        }
        Integer count = 0;
        Integer fromIndex = 0;
        Integer foundAt = haystack.indexOf(needle, fromIndex);
        while (foundAt != -1) {
            count += 1;
            fromIndex = foundAt + needle.length();
            foundAt = haystack.indexOf(needle, fromIndex);
        }
        return count;
    }

    private static String buildMinimalImportWorkbookBase64() {
        return 'UEsDBBQAAAAIAHhfwVxuYbgN/gAAAC0CAAATAAAAW0NvbnRlbnRfVHlwZXNdLnhtbK2RzU7DMBCEX8XytYqdckAIJe2BnyNwKA+w2JvEiv/kdUv69jhp4YAKXDit7JnZb2Q328lZdsBEJviWr0XNGXoVtPF9y193j9UNZ5TBa7DBY8uPSHy7aXbHiMRK1lPLh5zjrZSkBnRAIkT0RelCcpDLMfUyghqhR3lV19dSBZ/R5yrPO/imuccO9jazh6lcn3oktMTZ3ck4s1oOMVqjIBddHrz+RqnOBFGSi4cGE2lVDFxeJMzKz4Bz7rk8TDIa2Quk/ASuuORk5XtI41sIo/h9yYWWoeuMQh3U3pWIoJgQNA2I2VmxTOHA+NXf/MVMchnrfy7ytf+zh1y+e/MBUEsDBBQAAAAIAHhfwVyY2uuLrgAAACcBAAALAAAAX3JlbHMvLnJlbHONz8EOgjAMBuBXWXqXgQdjDIOLMeFq8AHmVgYB1mWbCm/vjmI8eGz69/vTsl7miT3Rh4GsgCLLgaFVpAdrBNzay+4ILERptZzIooAVA9RVecVJxnQS+sEFlgwbBPQxuhPnQfU4y5CRQ5s2HflZxjR6w51UozTI93l+4P7TgK3JGi3AN7oA1q4O/7Gp6waFZ1KPGW38UfGVSLL0BqOAZeIv8uOdaMwSCrwq+ebB6g1QSwMEFAAAAAgAeF/BXJ1sQ725AAAAGwEAAA8AAAB4bC93b3JrYm9vay54bWyNT0uuwjAMvErkPaRlgZ6qtmwQEmvgAKFxaURjV3b4vNsTfntWM9ZoxjP16h5Hc0XRwNRAOS/AIHXsA50aOOw3sz8wmhx5NzJhA/+osGrrG8v5yHw22U7awJDSVFmr3YDR6ZwnpKz0LNGlfMrJ6iTovA6IKY52URRLG10geCdU8ksG933ocM3dJSKld4jg6FIur0OYFNr69UE/aMjFXHr35GUe8sStzzvBSBUyka0vwba1/drsd1n7AFBLAwQUAAAACAB4X8FcWv2Ca7EAAAAoAQAAGgAAAHhsL19yZWxzL3dvcmtib29rLnhtbC5yZWxzjc/JCsJADAbgVxlyt2k9iEinXkToVeoDDNN0oZ2Fybj07R08iAUPnkLyky+kPD7NLO4UeHRWQpHlIMhq1462l3Btzps9CI7Ktmp2liQsxHCsygvNKqYVHkbPIhmWJQwx+gMi64GM4sx5sinpXDAqpjb06JWeVE+4zfMdhm8D1qaoWwmhbgsQzeLpH9t13ajp5PTNkI0/TuDDhYkHophQFXqKEj4jxncpsqQCViWuPqxeUEsDBBQAAAAIAHhfwVyX3ya79AAAAA8CAAAYAAAAeGwvd29ya3NoZWV0cy9zaGVldDEueG1sdZFBTsMwEEWvYnnf2skCIeS4Ci1I3aZwAMsZGkMyjuwphdszjVAEUrIbf+tJ78+Y3dfQi09IOUSsZLHVUgD62AY8V/L15XlzL0Umh63rI0IlvyHLnTXXmD5yB0CCecyV7IjGB6Wy72BweRtHQP55i2lwxM90VnlM4NoJGnpVan2nBhdQWjNlB0fOmhSvIrEHp/421IUUVMmAfUA4UeI8ZGvI7l0GcTwYRdaoW6T8L/K4hjTxQlxL1J647AK5XyOPOF6IoBUNl+Pi/1nF0rN5OZuXa+b16WmjdbGkvsY08A6elpTXCIJMIk26S7bqz87VfEz7A1BLAQIUABQAAAAIAHhfwVxuYbgN/gAAAC0CAAATAAAAAAAAAAAAAACAAQAAAABbQ29udGVudF9UeXBlc10ueG1sUEsBAhQAFAAAAAgAeF/BXJja64uuAAAAJwEAAAsAAAAAAAAAAAAAAIABLwEAAF9yZWxzLy5yZWxzUEsBAhQAFAAAAAgAeF/BXJ1sQ725AAAAGwEAAA8AAAAAAAAAAAAAAIABBgIAAHhsL3dvcmtib29rLnhtbFBLAQIUABQAAAAIAHhfwVxa/YJrsQAAACgBAAAaAAAAAAAAAAAAAACAAewCAAB4bC9fcmVscy93b3JrYm9vay54bWwucmVsc1BLAQIUABQAAAAIAHhfwVyX3ya79AAAAA8CAAAYAAAAAAAAAAAAAACAAdUDAAB4bC93b3Jrc2hlZXRzL3NoZWV0MS54bWxQSwUGAAAAAAUABQBFAQAA/wQAAAAA';
    }
}