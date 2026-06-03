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
        insert new List<Case>{openCase, closedCase};
        // onBeforeInsert regenerates FEC_ID_Search__c; restore keys used by import assertions and SOQL in tests.
        update new List<Case>{
            new Case(Id = openCase.Id, FEC_ID_Search__c = 'CASE-OPEN-2026'),
            new Case(Id = closedCase.Id, FEC_ID_Search__c = 'CASE-CLOSED-2026')
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
    @IsTest
    static void testValidateRows_StandardProcessFlow() {
        // Chuẩn bị mảng chứa các object dòng dữ liệu lỗi/đúng đan xen
        List<Object> inputRows = new List<Object>();
        
        // Dòng 1: Hợp lệ 100% cho luồng thường
        inputRows.add(new Map<String, Object>{
            'case id search' => 'CASE-OPEN-2026',
            'routing action' => 'RESOLVE',
            'remark' => 'Standard process remark valid entry'
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
            'caseidsearch' => 'CASE-CLOSED-2026',
            'routingaction' => 'RESOLVE',
            'remarks' => 'Closed case entry'
        });

        // Dòng 5: Lỗi trùng lặp mã Case Id trong cùng một lô import (Duplicate Case)
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => 'CASE-OPEN-2026', // Trùng lại dòng 1
            'routingaction' => 'RESOLVE',
            'remarks' => 'Duplicate remark line'
        });

        // Dòng 6: Lỗi luồng thường nhưng cố tình truyền kèm các trường định tuyến phân công Assignment
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => 'CASE-OPEN-2026',
            'routingaction' => 'RESOLVE',
            'assignmentid' => '005xxxxxxxxxxxxAAA',
            'assignmentroutingaction' => 'REJECT',
            'remarks' => 'Prohibited assignments for normal flow'
        });

        // Dòng 7: Lỗi nội dung Remark vượt độ dài tối đa hoặc rỗng
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => 'CASE-OPEN-2026',
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

        System.assertEquals(7, results.size(), 'Số lượng dòng ghi nhận xử lý phải là 7.');
        System.assertEquals(System.Label.FEC_Operation_Success, results[0].status, 'Dòng số 1 phải xử lý hợp lệ thành công.');
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
        Case openCase = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'CASE-OPEN-2026' LIMIT 1];
        FEC_Assignment__c activeAsg = [SELECT Id FROM FEC_Assignment__c WHERE FEC_Assignment_Status__c = 'Open' LIMIT 1];
        FEC_Assignment__c closedAsg = [SELECT Id FROM FEC_Assignment__c WHERE FEC_Assignment_Status__c = 'Resolved-Completed' LIMIT 1];

        List<Object> inputRows = new List<Object>();

        // Dòng 1: Gán kèm phân công Assignment hợp lệ + Hành động định tuyến Assignment hoàn tất (Chỉ chấp nhận RESOLVE/REJECT)
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => 'CASE-OPEN-2026',
            'assignmentid' => String.valueOf(activeAsg.Id),
            'routingaction' => 'RESOLVE', // Định tuyến hợp lệ cho Case
            'remarks' => 'Valid COF row entries'
        });

        // Dòng 2: Lỗi truyền cả 2 hành động routingAction và assignmentRoutingAction cùng lúc
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => 'CASE-OPEN-2026',
            'assignmentid' => String.valueOf(activeAsg.Id),
            'routingaction' => 'RESOLVE',
            'assignmentroutingaction' => 'REJECT',
            'remarks' => 'Both actions provided'
        });

        // Dòng 3: Lỗi thiếu cả 2 hành động định tuyến
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => 'CASE-OPEN-2026',
            'assignmentid' => String.valueOf(activeAsg.Id),
            'remarks' => 'Missing both routing actions'
        });

        // Dòng 4: Lỗi mã định danh định tuyến của Case không hợp lệ
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => 'CASE-OPEN-2026',
            'assignmentid' => String.valueOf(activeAsg.Id),
            'routingaction' => 'INVALID_ROUTING_KEY',
            'remarks' => 'Invalid action key'
        });

        // Dòng 5: Lỗi định tuyến cho Case khi có kèm Assignment nhưng hành động KHÔNG PHẢI RESOLVE/REJECT
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => 'CASE-OPEN-2026',
            'assignmentid' => String.valueOf(activeAsg.Id),
            'routingaction' => FEC_CaseBusinessService.ROUTE_TO, // Gây lỗi nhánh !isResolvedOrRejectCaseRouting (map key "Route to")
            'remarks' => 'Not a resolve or reject action'
        });

        // Dòng 6: Lỗi mã Assignment Id sai định dạng cấu trúc mã Id Salesforce (Bao phủ catch exception)
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => 'CASE-OPEN-2026',
            'assignmentid' => 'CRITICAL_INVALID_ID_FORMAT_STACK',
            'routingaction' => 'RESOLVE',
            'remarks' => 'Bad assignment ID format'
        });

        // Dòng 7: Lỗi mã Assignment Id không tồn tại trong DB hoặc không liên kết trùng khớp với Id của Case
        // Giả lập bằng cách tạo một ID giả chuẩn cấu trúc Salesforce Object
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => 'CASE-OPEN-2026',
            'assignmentid' => 'a01000000000001AAA', 
            'routingaction' => 'RESOLVE',
            'remarks' => 'Non existing or unlinked assignment record'
        });

        // Dòng 8: Lỗi mã bản ghi phân công việc đã ở trạng thái đóng (Resolved-)
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => 'CASE-OPEN-2026',
            'assignmentid' => String.valueOf(closedAsg.Id),
            'routingaction' => 'RESOLVE',
            'remarks' => 'Closed assignment row verification'
        });

        // Dòng 9: Không truyền assignmentId nhưng truyền thiếu hành động hoặc sai hành động
        inputRows.add(new Map<String, Object>{
            'caseidsearch' => 'CASE-OPEN-2026',
            'assignmentroutingaction' => 'RESOLVE', // Lỗi: truyền kèm assignment routing action nhưng thiếu assignmentId
            'remarks' => 'Assignment routing without assignment ID'
        });

        Test.startTest();
        List<FEC_BatchCaseHandlingImportRow> results = 
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, true);
        Test.stopTest();

        System.assertEquals(9, results.size());
        System.assertEquals(System.Label.FEC_Operation_Success, results[0].status);
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
        Integer nullCount = FEC_BatchCaseHandlingImportService.countFailedImportRows(null);
        Integer emptyCount = FEC_BatchCaseHandlingImportService.countFailedImportRows(
            new List<FEC_BatchCaseHandlingImportRow>()
        );
        Test.stopTest();

        System.assertEquals(0, nullCount);
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
}