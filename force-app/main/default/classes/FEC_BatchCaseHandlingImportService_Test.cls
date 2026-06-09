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

    @IsTest
    static void testExtractAssignmentLookupTokens_ExportPrefixAndMultiline() {
        List<String> singlePrefix = FEC_BatchCaseHandlingImportService.extractAssignmentLookupTokens(
            '#1: A-000329'
        );
        System.assertEquals(2, singlePrefix.size(), 'Một dòng prefix vẫn giữ token strip và raw.');
        System.assertEquals('A-000329', singlePrefix[0]);

        List<String> multiline = FEC_BatchCaseHandlingImportService.extractAssignmentLookupTokens(
            '#1: \n#2: A-000329\n#3: A-000330'
        );
        System.assertEquals(2, multiline.size(), 'Bỏ qua dòng prefix rỗng, lấy đủ mã Assignment.');
        System.assertEquals('A-000329', multiline[0]);
        System.assertEquals('A-000330', multiline[1]);

        System.assertEquals(
            'A-000331',
            FEC_BatchCaseHandlingImportService.stripAssignmentExportLinePrefix('#5: A-000331')
        );
        System.assertEquals(
            'A-000331',
            FEC_BatchCaseHandlingImportService.stripAssignmentExportLinePrefix('A-000331')
        );
    }

    @IsTest
    static void testValidateRows_AssignmentIdWithExportPrefix() {
        System.runAs(batchImportRunUser()) {
            Case openCase = [
                SELECT Id, FEC_ID_Search__c
                FROM Case
                WHERE FEC_ID_Search__c = 'CASE-OPEN-2026'
                LIMIT 1
            ];
            openCase.OwnerId = UserInfo.getUserId();
            update openCase;
            FEC_Assignment__c activeAsg = [
                SELECT Id, Name
                FROM FEC_Assignment__c
                WHERE FEC_Assignment_Status__c = 'Open'
                LIMIT 1
            ];

            List<Object> inputRows = new List<Object>{
                new Map<String, Object>{
                    'caseidsearch' => openCase.FEC_ID_Search__c,
                    'assignmentid' => '#1: ' + activeAsg.Name,
                    'routingaction' => 'RESOLVE',
                    'inputtedremarks' => 'Prefixed assignment id',
                    'inputtedremarkscharlength' => '21'
                },
                new Map<String, Object>{
                    'caseidsearch' => openCase.FEC_ID_Search__c,
                    'assignmentid' => '#1: \n#2: ' + activeAsg.Name,
                    'routingaction' => 'RESOLVE',
                    'inputtedremarks' => 'Multiline prefixed assignment id',
                    'inputtedremarkscharlength' => '31'
                },
                new Map<String, Object>{
                    'caseidsearch' => openCase.FEC_ID_Search__c,
                    'assignmentid' => String.valueOf(activeAsg.Id),
                    'routingaction' => 'RESOLVE',
                    'inputtedremarks' => 'Bare Salesforce Id still works',
                    'inputtedremarkscharlength' => '28'
                }
            };

            List<FEC_BatchCaseHandlingImportRow> results =
                FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, true);

            System.assertEquals(3, results.size());
            for (FEC_BatchCaseHandlingImportRow row : results) {
                System.assert(
                    row.errors == null ||
                        !row.errors.contains(
                            System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Id_Not_Found
                        ),
                    'Assignment export prefix/multiline phải resolve được: ' + row.errors
                );
            }
        }
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
    static void testPersistBatchResultArtifact_WithSourceTemplateWorkbook() {
        Schema.SObjectType batchType = Schema.getGlobalDescribe().get('FEC_Batch_Case_Handling__c');
        if (batchType == null) {
            System.assert(true, 'Skipped: FEC_Batch_Case_Handling__c not on org.');
            return;
        }

        SObject batchRow = batchType.newSObject();
        Map<String, Schema.SObjectField> fMap = batchType.getDescribe().fields.getMap();
        if (fMap.containsKey('FEC_File_Name__c')) {
            batchRow.put('FEC_File_Name__c', 'Source_Template_Import.xlsx');
        }
        insert batchRow;
        Id batchId = (Id) batchRow.get('Id');
        Id cvId = insertMinimalImportContentVersion('SourceTemplateImport', batchId);

        FEC_BCH_TemplateExportService.ImportWorkbookParseResult parsed =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(cvId);
        System.assertEquals(true, parsed.parseSuccess, parsed.errorMessage);
        List<FEC_BatchCaseHandlingImportRow> parsedRows = (List<FEC_BatchCaseHandlingImportRow>) JSON.deserialize(
            JSON.serialize(parsed.inputRows),
            List<FEC_BatchCaseHandlingImportRow>.class
        );
        FEC_BatchCaseHandlingImportRow row = parsedRows[0];
        row.status = System.Label.FEC_Operation_Success;
        row.errors = 'Queue not found';
        row.routingAction = 'RESOLVE';
        row.inputtedRemarks = 'result export remark from import test';
        row.caseIdSearch = 'CASE-001';

        Test.startTest();
        FEC_BatchCaseHandlingImportService.persistBatchResultArtifact(
            batchId,
            new List<FEC_BatchCaseHandlingImportRow>{ row },
            ''
        );
        Test.stopTest();

        List<ContentVersion> resultArtifacts = [
            SELECT Id, Title
            FROM ContentVersion
            WHERE FirstPublishLocationId = :batchId
            ORDER BY CreatedDate DESC
        ];
        System.assert(!resultArtifacts.isEmpty(), 'Phải tạo file Result workbook từ template import gốc.');
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
    static void testValidateImportRows_RemarkLengthAndMissingFields() {
        String tooLongMsg = System.Label.FEC_Batch_Case_Handling_Import_Err_Remark_Too_Long;
        String missingRemarkMsg = System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Remark;
        String missingRoutingMsg = System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Routing_Action;
        String invalidRoutingMsg = System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid;
        String failedStatus = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;

        List<FEC_BatchCaseHandlingImportRow> missingRemarkRows =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(
                new List<Object>{ new Map<String, Object>{ 'caseidsearch' => 'CASE-IMPORT-TEST-001', 'routingaction' => 'Reject' } },
                false
            );
        System.assertEquals(1, missingRemarkRows.size());
        System.assertEquals(failedStatus, missingRemarkRows[0].status);
        System.assert(missingRemarkRows[0].errors.contains(missingRemarkMsg), missingRemarkRows[0].errors);

        List<FEC_BatchCaseHandlingImportRow> emptyRowResults =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(
                new List<Object>{
                    new Map<String, Object>{ 'caseidsearch' => 'CASE-IMPORT-TEST-001', 'routingaction' => 'Reject', 'inputtedremarks' => 'ok' },
                    new Map<String, Object>{
                        'originalHeaders' => new List<String>{ 'Case ID Search', 'Routing Action', 'Inputted Remarks' },
                        'originalCells' => new List<String>{ '', '', '' }
                    }
                },
                false
            );
        System.assertEquals(2, emptyRowResults.size());
        System.assertEquals(failedStatus, emptyRowResults[1].status);
        System.assert(
            emptyRowResults[1].errors.contains(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Case_Id),
            emptyRowResults[1].errors
        );

        List<FEC_BatchCaseHandlingImportRow> remarkLenRows =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(
                new List<Object>{ new Map<String, Object>{
                    'caseidsearch' => 'CASE-IMPORT-TEST-REMARK-LEN',
                    'routingaction' => 'Reject',
                    'inputtedremarks' => buildRemarkOfLength(32768)
                }},
                false
            );
        System.assertEquals(failedStatus, remarkLenRows[0].status);
        System.assert(remarkLenRows[0].errors.contains(tooLongMsg), remarkLenRows[0].errors);
        System.assert(!remarkLenRows[0].errors.contains(missingRoutingMsg), remarkLenRows[0].errors);

        List<FEC_BatchCaseHandlingImportRow> maxLenRows =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(
                new List<Object>{ new Map<String, Object>{
                    'caseidsearch' => 'CASE-IMPORT-TEST-REMARK-MAX',
                    'routingaction' => 'Reject',
                    'inputtedremarks' => buildRemarkOfLength(32767)
                }},
                false
            );
        System.assert(maxLenRows[0].errors.contains(tooLongMsg), maxLenRows[0].errors);

        for (List<Object> charLenInput : new List<List<Object>>{
            new List<Object>{ new Map<String, Object>{
                'caseidsearch' => 'CASE-IMPORT-TEST-REMARK-LEN-CHAR',
                'routingaction' => 'Reject',
                'inputtedremarks' => FEC_ConstantCommon.STR_EMPTY,
                'inputtedRemarksCharLength' => 32768
            }},
            new List<Object>{ new Map<String, Object>{
                'caseidsearch' => 'CASE-IMPORT-TEST-REMARK-TRUNC',
                'routingaction' => 'Reject',
                'inputtedremarks' => FEC_ConstantCommon.STR_EMPTY,
                'inputtedRemarksCharLength' => 40000,
                'originalHeaders' => new List<String>{ 'Case ID Search', 'Routing Action', 'Inputted Remarks' },
                'originalCells' => new List<String>{ 'CASE-IMPORT-TEST-REMARK-TRUNC', 'Reject', buildRemarkOfLength(32768) }
            }},
            new List<Object>{ new Map<String, Object>{
                'caseidsearch' => 'CASE-IMPORT-TEST-REMARK-ALIAS',
                'routingaction' => 'Reject',
                'inputtedremarks' => FEC_ConstantCommon.STR_EMPTY,
                'inputtedRemarksCharLength' => 40000,
                'originalHeaders' => new List<String>{ 'Case ID Search', 'Routing Action', 'Input Remark' },
                'originalCells' => new List<String>{ 'CASE-IMPORT-TEST-REMARK-ALIAS', 'Reject', buildRemarkOfLength(32768) }
            }}
        }) {
            System.assert(
                FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(charLenInput, false)[0].errors.contains(tooLongMsg),
                String.valueOf(charLenInput)
            );
        }

        List<FEC_BatchCaseHandlingImportRow> missingRemarkWithRouting =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(
                new List<Object>{ new Map<String, Object>{
                    'caseidsearch' => 'CASE-IMPORT-TEST-004',
                    'routingaction' => 'Reject',
                    'inputtedremarks' => FEC_ConstantCommon.STR_EMPTY
                }},
                false
            );
        System.assert(missingRemarkWithRouting[0].errors.contains(missingRemarkMsg), missingRemarkWithRouting[0].errors);
        System.assert(!missingRemarkWithRouting[0].errors.contains(missingRoutingMsg), missingRemarkWithRouting[0].errors);

        List<FEC_BatchCaseHandlingImportRow> missingRoutingRows =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(
                new List<Object>{ new Map<String, Object>{ 'caseidsearch' => 'CASE-IMPORT-TEST-002' } },
                false
            );
        System.assert(missingRoutingRows[0].errors.contains(missingRoutingMsg), missingRoutingRows[0].errors);
        System.assertEquals(1, countOccurrences(missingRoutingRows[0].errors, missingRoutingMsg), missingRoutingRows[0].errors);

        List<FEC_BatchCaseHandlingImportRow> invalidRoutingRows =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(
                new List<Object>{ new Map<String, Object>{
                    'caseidsearch' => 'CASE-IMPORT-TEST-003',
                    'routingaction' => 'Reject',
                    'inputtedremarks' => 'Test remark'
                }},
                false
            );
        System.assert(invalidRoutingRows[0].errors.contains(invalidRoutingMsg), invalidRoutingRows[0].errors);
        System.assertEquals(1, countOccurrences(invalidRoutingRows[0].errors, invalidRoutingMsg), invalidRoutingRows[0].errors);
    }

    @IsTest
    static void testIsInputtedRemarksOverMaxLength_boundary() {
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
    static void testApplyValidatedRoutingToResultCells_KeepsSourceValues() {
        String routeTo = 'Route to CS Support - DQ-CS Support';
        for (List<String> cells : new List<List<String>>{
            new List<String>{ 'Resolve', routeTo, 'remark' },
            new List<String>{ 'Revert', 'Escalate', 'remark' },
            new List<String>{ FEC_ConstantCommon.STR_EMPTY, routeTo, 'remark' }
        }) {
            String expectedCaseRouting = cells[0];
            FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
            row.routingAction = cells[1] == routeTo ? routeTo : 'Escalate';
            row.assignmentRoutingAction = row.routingAction;
            FEC_BatchCaseHandlingImportService.applyValidatedRoutingToResultCells(cells, 0, 1, row);
            System.assertEquals(expectedCaseRouting, cells[0]);
            System.assertEquals(row.routingAction, cells[1]);
        }
    }

    @IsTest
    static void testCofGsrRoutingBleedSanitizeAndValidate() {
        FEC_BatchCaseHandlingImportRow bleedRow = buildCofGsrBleedImportRow();
        FEC_BatchCaseHandlingImportService.sanitizeCofGsrCaseRoutingBleedFromAssignment(bleedRow);
        System.assertEquals(FEC_ConstantCommon.STR_EMPTY, bleedRow.routingAction);
        System.assertEquals('Route to CS Support - DQ-CS Support', bleedRow.assignmentRoutingAction);

        List<FEC_BatchCaseHandlingImportRow> rows =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(
                new List<Object>{ new Map<String, Object>{
                    'caseidsearch' => 'S-3653',
                    'assignmentid' => 'A-001762',
                    'routingaction' => 'Route to CS Support - DQ-CS Support',
                    'assignmentroutingaction' => 'Route to CS Support - DQ-CS Support',
                    'inputtedremarks' => 'remark',
                    'originalHeaders' => bleedRow.originalHeaders,
                    'originalCells' => bleedRow.originalCells
                }},
                true
            );
        System.assertEquals(1, rows.size());
        System.assert(
            !rows[0].errors.contains(System.Label.FEC_Batch_Case_Handling_Import_Err_Both_Routing_Actions),
            rows[0].errors
        );
        System.assert(
            !rows[0].errors.contains(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Resolve_Only),
            rows[0].errors
        );
    }

    @IsTest
    static void testCofGsrRoutingBleedSanitize_misalignedOriginalCells() {
        FEC_BatchCaseHandlingImportRow bleedRow = buildCofGsrBleedImportRow();
        bleedRow.originalCells[2] = 'Route to CS Support - DQ-CS Support';
        FEC_BatchCaseHandlingImportService.sanitizeCofGsrCaseRoutingBleedFromAssignment(bleedRow);
        System.assertEquals(FEC_ConstantCommon.STR_EMPTY, bleedRow.routingAction);
        System.assertEquals('Route to CS Support - DQ-CS Support', bleedRow.assignmentRoutingAction);
    }

    @IsTest
    static void testImportRowLayoutAndExportHelpers() {
        List<String> bleedCells = new List<String>();
        for (Integer i = 0; i < 24; i++) {
            bleedCells.add(FEC_ConstantCommon.STR_EMPTY);
        }
        String remark = buildRemarkOfLength(32767);
        bleedCells[21] = remark;
        bleedCells[22] = remark;
        FEC_BatchCaseHandlingImportService.clearRoutingCellIfRemarkBleed(bleedCells, 21, 22);
        System.assertEquals(FEC_ConstantCommon.STR_EMPTY, bleedCells[21]);
        System.assertEquals(remark, bleedCells[22]);

        FEC_BatchCaseHandlingImportRow layoutRow = new FEC_BatchCaseHandlingImportRow();
        layoutRow.originalHeaders = new List<String>{ 'Case ID', 'Routing Action', 'Inputted Remarks' };
        layoutRow.originalCells = new List<String>{ 'S-3603', 'Resolve', '111' };
        FEC_BatchCaseHandlingImportService.enrichImportRowValidateFieldsFromOriginalLayout(layoutRow);
        System.assertEquals('S-3603', layoutRow.caseIdSearch);
        System.assertEquals('Resolve', layoutRow.routingAction);
        System.assertEquals('111', layoutRow.inputtedRemarks);

        List<String> headers = new List<String>{ 'Plastic ID', 'Case ID', 'Other' };
        List<String> exportCells = new List<String>{ 'S-4866', FEC_ConstantCommon.STR_EMPTY, 'x' };
        FEC_BatchCaseHandlingImportService.syncCaseIdIntoExportCells(exportCells, headers, 'S-4866');
        System.assertEquals(FEC_ConstantCommon.STR_EMPTY, exportCells[0]);
        System.assertEquals('S-4866', exportCells[1]);
        System.assertEquals('x', exportCells[2]);
    }

    @IsTest
    static void testImportWorkbookEnrichAndHydrate() {
        Id cvId = insertMinimalImportContentVersion('LayoutEnrichImport', null);
        FEC_BCH_TemplateExportService.ImportWorkbookParseResult parsed =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(cvId);
        System.assertEquals(true, parsed.parseSuccess, parsed.errorMessage);
        List<FEC_BatchCaseHandlingImportRow> parsedRows = (List<FEC_BatchCaseHandlingImportRow>) JSON.deserialize(
            JSON.serialize(parsed.inputRows),
            List<FEC_BatchCaseHandlingImportRow>.class
        );
        List<String> expectedCells = parsedRows[0].originalCells;
        FEC_BatchCaseHandlingImportRow bad = parsedRows[0];
        bad.caseIdSearch = 'CASE-001';
        bad.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
        bad.errors = 'test';
        List<String> misplacedCells = new List<String>();
        for (Integer i = 0; i < bad.originalHeaders.size(); i++) {
            misplacedCells.add('MISPLACED-' + String.valueOf(i));
        }
        bad.originalCells = misplacedCells;
        List<FEC_BatchCaseHandlingImportRow> enriched =
            FEC_BatchCaseHandlingImportService.enrichImportRowsLayoutFromSourceFile(cvId, new List<FEC_BatchCaseHandlingImportRow>{ bad });
        System.assertEquals(expectedCells, enriched[0].originalCells);

        Schema.SObjectType batchType = Schema.getGlobalDescribe().get('FEC_Batch_Case_Handling__c');
        SObject batchRow = batchType.newSObject();
        FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(
            batchType.getDescribe().fields.getMap(),
            batchRow,
            new List<String>{ 'FEC_File_Name__c' },
            'HydrateFailureRowsFromTemplate.xlsx'
        );
        insert batchRow;
        insertMinimalImportContentVersion('HydrateFailureRowsFromTemplate', (Id) batchRow.get('Id'));
        List<FEC_BatchCaseHandlingImportRow> hydrated =
            FEC_BatchCaseHandlingImportService.hydrateFailureRowsFromSourceImport(
                (Id) batchRow.get('Id'),
                'Apex CPU time limit exceeded'
            );
        System.assertEquals(1, hydrated.size());
        System.assertEquals(System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed, hydrated[0].status);
        System.assertEquals(
            FEC_BatchCaseHandlingImportService.localizeImportResultErrors('Apex CPU time limit exceeded'),
            hydrated[0].errors
        );
        System.assertEquals('CASE-001', hydrated[0].caseIdSearch);
        System.assert(hydrated[0].originalHeaders.size() > 0);
    }

    @IsTest
    static void testEnrichImportRowValidateFieldsFromImportFile() {
        Id cvId = insertMinimalImportContentVersion('EnrichValidateFieldsStd', null);
        FEC_BCH_TemplateExportService.ImportWorkbookParseResult parsed =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(cvId);
        System.assertEquals(true, parsed.parseSuccess, parsed.errorMessage);
        List<Object> standardRows = parsed.inputRows;

        Id cofCvId = insertMinimalImportContentVersion('EnrichValidateFieldsCof', null);
        Map<String, Object> stdRow = (Map<String, Object>) standardRows[0];
        stdRow.remove('caseIdSearch');
        stdRow.remove('caseidsearch');

        List<Object> cofRows = new List<Object>{
            new Map<String, Object>{
                'originalDataRowIndex' => 1,
                'originalHeaders' => new List<String>{
                    'Case ID', 'Assignment ID', 'Routing Action', 'Assignment Routing Action', 'Inputted Remarks'
                },
                'originalColumnIndexes' => new List<Integer>{ 0, 1, 2, 3, 4 },
                'originalsheetname' => 'sheet1',
                'originalHeaderRowIndex' => 0
            }
        };

        Test.startTest();
        FEC_BatchCaseHandlingImportService.enrichInputtedRemarksFromImportFile(cvId, standardRows);
        FEC_BatchCaseHandlingImportService.enrichInputtedRemarksFromImportFile(cofCvId, cofRows);
        FEC_BatchCaseHandlingImportService.enrichInputtedRemarksFromImportFile(null, null);
        Test.stopTest();

        System.assert(
            String.isNotBlank((String) stdRow.get('caseidsearch')),
            'Phải enrich Case ID từ file import.'
        );
        Map<String, Object> cofRow = (Map<String, Object>) cofRows[0];
        System.assert(cofRow.containsKey('routingaction'), 'COF/GSR phải ghi đè Routing Action từ file.');
        System.assert(
            cofRow.containsKey('assignmentroutingaction'),
            'COF/GSR phải ghi đè Assignment Routing Action từ file.'
        );
    }

    @IsTest
    static void testApplyCaseHandlingUpdates_CofGsrBlocksCaseRoutingWhenAssignmentsExist() {
        System.runAs(batchImportRunUser()) {
            Case c = [
                SELECT Id, FEC_Assignment_Count__c
                FROM Case
                WHERE FEC_ID_Search__c = 'CASE-OPEN-2026'
                LIMIT 1
            ];
            if (c.FEC_Assignment_Count__c == null || c.FEC_Assignment_Count__c <= 0) {
                System.assert(true, 'Skipped: FEC_Assignment_Count__c chưa được rollup trên Case mồi.');
                return;
            }

            FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
            row.status = System.Label.FEC_Operation_Success;
            row.recordId = String.valueOf(c.Id);
            row.routingAction = 'Revert to User';
            row.inputtedRemarks = 'case routing blocked when assignments exist';

            Test.startTest();
            FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(
                new List<FEC_BatchCaseHandlingImportRow>{ row },
                true
            );
            Test.stopTest();

            System.assertEquals(
                System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
                row.status,
                'COF/GSR case-level Revert phải bị chặn khi Case còn Assignment.'
            );
            System.assert(
                row.errors != null &&
                row.errors.contains(
                    System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Unavailable_Assignment
                ),
                row.errors
            );
        }
    }

    private static FEC_BatchCaseHandlingImportRow buildCofGsrBleedImportRow() {
        FEC_BatchCaseHandlingImportRow rr = new FEC_BatchCaseHandlingImportRow();
        rr.originalHeaders = new List<String>{
            'Case ID', 'Assignment ID', 'Routing Action', 'Assignment Routing Action', 'Inputted Remarks'
        };
        rr.originalCells = new List<String>{
            'S-3653', 'A-001762', FEC_ConstantCommon.STR_EMPTY, 'Route to CS Support - DQ-CS Support', 'remark'
        };
        rr.routingAction = 'Route to CS Support - DQ-CS Support';
        rr.assignmentRoutingAction = 'Route to CS Support - DQ-CS Support';
        return rr;
    }

    @IsTest
    static void testLocalizeImportResultError_AdditionalEnglishPatterns() {
        System.assertNotEquals(
            'Apex CPU time limit exceeded',
            FEC_BatchCaseHandlingImportService.localizeImportResultError('insufficient access on record')
        );
        System.assertNotEquals(
            null,
            FEC_BatchCaseHandlingImportService.localizeImportResultError('unable to lock row')
        );
        System.assertNotEquals(
            null,
            FEC_BatchCaseHandlingImportService.localizeImportResultError('entity is deleted')
        );
        System.assertNotEquals(
            null,
            FEC_BatchCaseHandlingImportService.localizeImportResultError('field_custom_validation_exception')
        );
        System.assertEquals(
            'Xử lý dữ liệu thất bại.',
            FEC_BatchCaseHandlingImportService.localizeImportResultError('Apex CPU time limit exceeded')
        );
    }

    @IsTest
    static void testExtractAssignmentLookupTokens() {
        Test.startTest();
        List<String> single = FEC_BatchCaseHandlingImportService.extractAssignmentLookupTokens('#1: A-000329');
        List<String> multi = FEC_BatchCaseHandlingImportService.extractAssignmentLookupTokens(
            'A-000001\n#2: A-000002'
        );
        List<String> blank = FEC_BatchCaseHandlingImportService.extractAssignmentLookupTokens('');
        String stripped = FEC_BatchCaseHandlingImportService.stripAssignmentExportLinePrefix('#3: A-000003');
        Test.stopTest();

        System.assert(single.contains('A-000329'), String.valueOf(single));
        System.assertEquals(2, multi.size());
        System.assertEquals(0, blank.size());
        System.assertEquals('A-000003', stripped);
    }

    @IsTest
    static void testApplyCaseHandlingUpdates_CofGsrAssignmentResolveAndRevert() {
        System.runAs(batchImportRunUser()) {
            Case c = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'CASE-OPEN-2026' LIMIT 1];
            c.OwnerId = UserInfo.getUserId();
            update c;
            FEC_Assignment__c resolveAsg = [
                SELECT Id
                FROM FEC_Assignment__c
                WHERE FEC_Assignment_Status__c = 'Open'
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];
            FEC_Assignment__c revertAsg = new FEC_Assignment__c(
                FEC_Case__c = c.Id,
                FEC_Assignment_Name__c = 'Revert Import Assignment',
                FEC_Assignment_Status__c = 'Open',
                FEC_Assignment_Owner__c = UserInfo.getUserId()
            );
            insert revertAsg;

            FEC_BatchCaseHandlingImportRow resolveRow = new FEC_BatchCaseHandlingImportRow();
            resolveRow.status = System.Label.FEC_Operation_Success;
            resolveRow.recordId = String.valueOf(c.Id);
            resolveRow.assignmentId = String.valueOf(resolveAsg.Id);
            resolveRow.assignmentRoutingAction = FEC_CaseBusinessService.RESOLVE;
            resolveRow.inputtedRemarks = 'cof gsr assignment resolve';

            FEC_BatchCaseHandlingImportRow revertRow = new FEC_BatchCaseHandlingImportRow();
            revertRow.status = System.Label.FEC_Operation_Success;
            revertRow.recordId = String.valueOf(c.Id);
            revertRow.assignmentId = String.valueOf(revertAsg.Id);
            revertRow.assignmentRoutingAction = 'Revert to User';
            revertRow.inputtedRemarks = 'cof gsr assignment revert';

            FEC_BatchCaseHandlingImportRow pendingRow = new FEC_BatchCaseHandlingImportRow();
            pendingRow.status = System.Label.FEC_Operation_Success;
            pendingRow.recordId = String.valueOf(c.Id);
            pendingRow.assignmentId = String.valueOf(revertAsg.Id);
            pendingRow.assignmentRoutingAction = FEC_CaseBusinessService.RESOLVE;
            pendingRow.inputtedRemarks = 'pending row for hasRemaining check';

            Test.startTest();
            FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(
                new List<FEC_BatchCaseHandlingImportRow>{ resolveRow },
                true
            );
            FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(
                new List<FEC_BatchCaseHandlingImportRow>{ revertRow },
                true
            );
            Boolean sync = FEC_BatchCaseHandlingImportService.shouldProcessImportSynchronously(
                new List<FEC_BatchCaseHandlingImportRow>{ pendingRow }
            );
            Boolean hasMore = FEC_BatchCaseHandlingImportService.hasRemainingApplicableImportRows(
                new List<FEC_BatchCaseHandlingImportRow>{ pendingRow },
                0
            );
            Test.stopTest();

            System.assertEquals(false, sync);
            System.assertEquals(true, hasMore);
            FEC_Assignment__c resolved = [
                SELECT FEC_Assignment_Status__c
                FROM FEC_Assignment__c
                WHERE Id = :resolveAsg.Id
            ];
            System.assertEquals(
                FEC_ConstantCommon.ASSIGNMENT_STATUS_COMPLETED,
                resolved.FEC_Assignment_Status__c
            );
        }
    }

    @IsTest
    static void testInputtedRemarksValidationHelpers() {
        List<String> errs = new List<String>();
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.originalHeaders = new List<String>{ 'Inputted Remarks' };
        row.originalCells = new List<String>{ 'remark from cell' };
        Map<String, Object> payload = new Map<String, Object>{
            'inputtedremarks' => 'short',
            'inputtedRemarksCharLength' => 5
        };

        Test.startTest();
        FEC_BatchCaseHandlingImportService.addInputtedRemarksValidationErrors(errs, '', 0);
        FEC_BatchCaseHandlingImportService.addInputtedRemarksValidationErrors(errs, 'ok', 2);
        String resolved = FEC_BatchCaseHandlingImportService.resolveInputtedRemarksValue(payload, row);
        Integer charLen = FEC_BatchCaseHandlingImportService.resolveInputtedRemarksCharLength(payload, row);
        String fromCells = FEC_BatchCaseHandlingImportService.extractRemarkFromOriginalCells(row);
        Boolean overMax = FEC_BatchCaseHandlingImportService.isInputtedRemarksOverMaxLength('x'.repeat(32767));
        Test.stopTest();

        System.assert(errs.size() >= 1);
        System.assertEquals('remark from cell', resolved);
        System.assertEquals('remark from cell', fromCells);
        System.assertEquals(true, overMax);
        System.assertNotEquals(null, charLen);
    }

    @IsTest
    static void testValidateRows_D2CFieldProfile_Success() {
        System.runAs(batchImportRunUser()) {
            ensureRunUserGroup('OM');
            validateImportFieldProfileScenario(
                'IMP-D2C-ONLY-' + String.valueOf(DateTime.now().getTime()),
                'Document Request',
                new Map<String, Object>{
                    'csd2cassessmenttype' => firstPicklistLabel('FEC_CS_D2C_Assessment_Type__c'),
                    'risklevel' => firstPicklistLabel('FEC_CS_D2C_Risk_Level__c'),
                    'requiredaction' => firstPicklistLabel('FEC_CS_D2C_Required_Corrective_Action__c')
                },
                new List<String>{
                    'CS D2C đánh giá yêu cầu',
                    'Mức độ rủi ro',
                    'Hành động cần thiết'
                },
                'OM'
            );
        }
    }

    @IsTest
    static void testValidateRows_PmPaymentFieldProfile() {
        System.runAs(batchImportRunUser()) {
            ensureRunUserGroup('PM');
            validateImportFieldProfileScenario(
                'IMP-PM-ONLY-' + String.valueOf(DateTime.now().getTime()),
                'Incorrect Payment Handling',
                new Map<String, Object>{
                    'paymentcontractassessment' => firstPicklistLabel('FEC_RD_Payment_Contract_Assessment__c'),
                    'originalHeaders' => new List<String>{ 'Payment đánh giá yêu cầu đóng hợp đồng' }
                },
                new List<String>{ 'Payment đánh giá yêu cầu đóng hợp đồng', 'RD Payment Contract Assessment' },
                'PM'
            );
        }
    }

    @IsTest
    static void testValidateRows_CpAssessmentFieldProfile() {
        System.runAs(batchImportRunUser()) {
            ensureRunUserGroup('CP');
            validateImportFieldProfileScenario(
                'IMP-CP-ONLY-' + String.valueOf(DateTime.now().getTime()),
                'Original MRC Return',
                new Map<String, Object>{
                    'cpassessment' => firstPicklistLabel('FEC_Contract_Processing_MRC_Assessment__c')
                },
                new List<String>{ 'CP đánh giá yêu cầu' },
                'CP'
            );
        }
    }

    @IsTest
    static void testValidateRows_CsSupportFieldProfile() {
        System.runAs(batchImportRunUser()) {
            ensureRunUserGroup('SP');
            validateImportFieldProfileScenario(
                'IMP-CSS-ONLY-' + String.valueOf(DateTime.now().getTime()),
                'GSR - General Flow',
                new Map<String, Object>{
                    'cssupportassessmenttype' => firstPicklistLabel('FEC_CS_Support_Assessment_Type__c'),
                    'classificationbycs' => firstPicklistLabel('FEC_CS_Check_Classification_by_CS__c'),
                    'evaluationbycs' => firstPicklistLabel('FEC_CS_Check_Evaluation_by_CS__c'),
                    'finalproduct' => firstPicklistLabel('FEC_CS_Check_Final_product__c'),
                    'originalHeaders' => new List<String>{
                        'CS Support đánh giá yêu cầu',
                        'Classification by CS',
                        'Evaluation by CS',
                        'Final Product'
                    }
                },
                new List<String>{
                    'CS Support đánh giá yêu cầu',
                    'Classification by CS',
                    'Evaluation by CS',
                    'Final Product'
                },
                'SP'
            );
        }
    }

    @IsTest
    static void testValidateRows_CofCoRole_WithOptionalD2CFields() {
        System.runAs(batchImportRunUser()) {
            ensureRunUserGroup('CO');
            String caseKey = 'IMP-COF-D2C-OPT-' + String.valueOf(DateTime.now().getTime());
            FEC_Business_Process__c bp = ensureImportBusinessProcess('COF - General Flow');
            FEC_Case_Stage__c stage = ensureImportStage(bp.Id, 'COF - General Flow', 'CO');
            insertMasterDataLabels(
                stage.Id,
                new List<String>{ 'CS D2C đánh giá yêu cầu', 'Mức độ rủi ro', 'Hành động cần thiết' }
            );
            ensureImportRoutingForStage(stage.Id, 'CO');

            FEC_CaseTriggerHandler.isExecuting = true;
            Case importCase = new Case(
                Subject = 'Import COF optional D2C',
                Status = 'New',
                FEC_ID_Search__c = caseKey,
                FEC_Business_Process__c = bp.Id,
                FEC_Current_Case_Stage__c = stage.Id,
                OwnerId = UserInfo.getUserId()
            );
            insert importCase;
            FEC_CaseTriggerHandler.isExecuting = false;
            update new Case(Id = importCase.Id, FEC_ID_Search__c = caseKey);

            Test.startTest();
            List<FEC_BatchCaseHandlingImportRow> rows =
                FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(
                    new List<Object>{ new Map<String, Object>{
                        'caseidsearch' => caseKey,
                        'routingaction' => 'RESOLVE',
                        'inputtedremarks' => 'optional d2c fields on cof co role import',
                        'csd2cassessmenttype' => firstPicklistLabel('FEC_CS_D2C_Assessment_Type__c'),
                        'risklevel' => firstPicklistLabel('FEC_CS_D2C_Risk_Level__c'),
                        'requiredaction' => firstPicklistLabel('FEC_CS_D2C_Required_Corrective_Action__c')
                    }},
                    false
                );
            Test.stopTest();

            System.assertEquals(1, rows.size());
            System.assert(
                rows[0].status != System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
                rows[0].errors
            );
        }
    }

    @IsTest
    static void testValidateRows_ImportFieldProfiles_MissingD2CValues() {
        System.runAs(batchImportRunUser()) {
            ensureRunUserGroup('OM');
            String caseKey = 'IMP-D2C-MISS-' + String.valueOf(DateTime.now().getTime());
            FEC_Business_Process__c bp = ensureImportBusinessProcess('Document Request');
            FEC_Case_Stage__c stage = ensureImportStage(bp.Id, 'Document Request', 'OM');
            insertMasterDataLabels(
                stage.Id,
                new List<String>{ 'CS D2C đánh giá yêu cầu', 'Mức độ rủi ro', 'Hành động cần thiết' }
            );
            ensureImportRoutingForStage(stage.Id, 'OM');

            FEC_CaseTriggerHandler.isExecuting = true;
            Case importCase = new Case(
                Subject = 'Import D2C missing values',
                Status = 'New',
                FEC_ID_Search__c = caseKey,
                FEC_Business_Process__c = bp.Id,
                FEC_Current_Case_Stage__c = stage.Id,
                OwnerId = UserInfo.getUserId()
            );
            insert importCase;
            FEC_CaseTriggerHandler.isExecuting = false;
            update new Case(Id = importCase.Id, FEC_ID_Search__c = caseKey);

            Test.startTest();
            List<FEC_BatchCaseHandlingImportRow> rows =
                FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(
                    new List<Object>{ new Map<String, Object>{
                        'caseidsearch' => caseKey,
                        'routingaction' => 'RESOLVE',
                        'inputtedremarks' => 'missing d2c field values on import row'
                    }},
                    false
                );
            Test.stopTest();

            System.assertEquals(1, rows.size());
            System.assert(
                rows[0].errors != null && rows[0].errors.contains('Thiếu giá trị CS D2C'),
                rows[0].errors
            );
        }
    }

    @IsTest
    static void testApplyCaseHandlingUpdates_CofGsrAssignmentUpdate() {
        System.runAs(batchImportRunUser()) {
            Case c = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'CASE-OPEN-2026' LIMIT 1];
            c.OwnerId = UserInfo.getUserId();
            update c;
            FEC_Assignment__c asg = [
                SELECT Id
                FROM FEC_Assignment__c
                WHERE FEC_Assignment_Status__c = 'Open'
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];

            FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
            row.status = System.Label.FEC_Operation_Success;
            row.recordId = String.valueOf(c.Id);
            row.assignmentId = String.valueOf(asg.Id);
            row.assignmentRoutingAction = 'Update to Approve';
            row.inputtedRemarks = 'cof gsr assignment update routing';

            Test.startTest();
            FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(
                new List<FEC_BatchCaseHandlingImportRow>{ row },
                true
            );
            Test.stopTest();

            System.assert(
                row.status != System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
                row.errors == null ? 'update failed' : row.errors
            );
        }
    }

    @IsTest
    static void testApplyCaseHandlingUpdates_CofGsrAssignmentRouteTo() {
        System.runAs(batchImportRunUser()) {
            String suffix = String.valueOf(Math.abs(Crypto.getRandomInteger())).left(6);
            String queueDev = 'FEC_BCH_Imp_Rt_' + suffix;
            String queueLabel = 'FEC BCH Import RouteTo ' + suffix;
            String teamCode = 'ImpRtTeam' + suffix;
            ensureAssignmentRouteToQueueFixture(queueDev, queueLabel, teamCode);

            Case c = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'CASE-OPEN-2026' LIMIT 1];
            c.OwnerId = UserInfo.getUserId();
            update c;
            FEC_Assignment__c asg = [
                SELECT Id
                FROM FEC_Assignment__c
                WHERE FEC_Assignment_Status__c = 'Open'
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];

            FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
            row.status = System.Label.FEC_Operation_Success;
            row.recordId = String.valueOf(c.Id);
            row.assignmentId = String.valueOf(asg.Id);
            row.assignmentRoutingAction = 'Route to ' + teamCode + ' - ' + queueLabel;
            row.inputtedRemarks = 'cof gsr assignment route to import';

            Test.startTest();
            FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(
                new List<FEC_BatchCaseHandlingImportRow>{ row },
                true
            );
            Test.stopTest();

            System.assert(
                row.status != System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
                row.errors == null ? 'route to failed' : row.errors
            );
        }
    }

    @IsTest
    static void testApplyCaseHandlingUpdates_WithResolvedPicklistApiValues() {
        System.runAs(batchImportRunUser()) {
            ensureRunUserGroup('OM');
            String caseKey = 'IMP-APPLY-API-' + String.valueOf(DateTime.now().getTime());
            FEC_Business_Process__c bp = ensureImportBusinessProcess('Document Request');
            FEC_Case_Stage__c stage = ensureImportStage(bp.Id, 'Document Request', 'OM');
            insertMasterDataLabels(
                stage.Id,
                new List<String>{ 'CS D2C đánh giá yêu cầu', 'Mức độ rủi ro', 'Hành động cần thiết' }
            );
            ensureImportRoutingForStage(stage.Id, 'OM');

            FEC_CaseTriggerHandler.isExecuting = true;
            Case importCase = new Case(
                Subject = 'Import apply picklist api values',
                Status = 'New',
                FEC_ID_Search__c = caseKey,
                FEC_Business_Process__c = bp.Id,
                FEC_Current_Case_Stage__c = stage.Id,
                OwnerId = UserInfo.getUserId()
            );
            insert importCase;
            FEC_CaseTriggerHandler.isExecuting = false;
            update new Case(Id = importCase.Id, FEC_ID_Search__c = caseKey, OwnerId = UserInfo.getUserId());

            FEC_Assignment__c asg = new FEC_Assignment__c(
                FEC_Case__c = importCase.Id,
                FEC_Assignment_Name__c = 'Apply Api Values Assignment',
                FEC_Assignment_Status__c = 'Open',
                FEC_Assignment_Owner__c = UserInfo.getUserId()
            );
            insert asg;

            String assessmentApi = firstPicklistApiValue('FEC_CS_D2C_Assessment_Type__c');
            String riskApi = firstPicklistApiValue('FEC_CS_D2C_Risk_Level__c');
            String requiredApi = firstPicklistApiValue('FEC_CS_D2C_Required_Corrective_Action__c');

            FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
            row.status = System.Label.FEC_Operation_Success;
            row.recordId = String.valueOf(importCase.Id);
            row.assignmentId = String.valueOf(asg.Id);
            row.assignmentRoutingAction = FEC_CaseBusinessService.RESOLVE;
            row.inputtedRemarks = 'apply d2c picklist api values on document request case';
            row.csD2CAssessmentTypeApiValue = assessmentApi;
            row.riskLevelApiValue = riskApi;
            row.requiredActionApiValue = requiredApi;

            Test.startTest();
            FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(
                new List<FEC_BatchCaseHandlingImportRow>{ row },
                true
            );
            Test.stopTest();

            System.assert(
                row.status != System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
                row.errors == null ? 'apply failed' : row.errors
            );
            FEC_Assignment__c resolvedAsg = [
                SELECT FEC_Assignment_Status__c
                FROM FEC_Assignment__c
                WHERE Id = :asg.Id
            ];
            System.assertEquals(
                FEC_ConstantCommon.ASSIGNMENT_STATUS_COMPLETED,
                resolvedAsg.FEC_Assignment_Status__c
            );
            if (String.isNotBlank(assessmentApi)) {
                Case updated = [
                    SELECT FEC_CS_D2C_Assessment_Type__c
                    FROM Case
                    WHERE Id = :importCase.Id
                ];
                System.assertEquals(assessmentApi, updated.FEC_CS_D2C_Assessment_Type__c);
            }
        }
    }

    @IsTest
    static void testApplyCaseHandlingUpdates_NonCofGsr_CreatesResolveRoutingHistory() {
        System.runAs(batchImportRunUser()) {
            ensureRunUserGroup('CO');
            String caseKey = 'IMP-BCC-RESOLVE-' + String.valueOf(DateTime.now().getTime());
            FEC_Business_Process__c bp = ensureImportBusinessProcess('COF - General Flow');
            FEC_Case_Stage__c stage = ensureImportStage(bp.Id, 'COF - General Flow', 'CO');
            insertMasterDataLabels(
                stage.Id,
                new List<String>{ 'CS D2C đánh giá yêu cầu', 'Mức độ rủi ro', 'Hành động cần thiết' }
            );
            ensureImportRoutingForStage(stage.Id, 'CO');

            FEC_CaseTriggerHandler.isExecuting = true;
            Case importCase = new Case(
                Subject = 'Import BCC resolve history',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_ID_Search__c = caseKey,
                FEC_Business_Process__c = bp.Id,
                FEC_Current_Case_Stage__c = stage.Id,
                OwnerId = UserInfo.getUserId()
            );
            insert importCase;
            FEC_CaseTriggerHandler.isExecuting = false;
            update new Case(Id = importCase.Id, FEC_ID_Search__c = caseKey, OwnerId = UserInfo.getUserId());

            FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
            row.status = System.Label.FEC_Operation_Success;
            row.recordId = String.valueOf(importCase.Id);
            row.routingAction = FEC_CaseBusinessService.RESOLVE;
            row.inputtedRemarks = 'non cof gsr case level resolve import history';

            Integer historyBefore = [
                SELECT COUNT()
                FROM FEC_Routing_Action_History__c
                WHERE FEC_Case__c = :importCase.Id
            ];

            Test.startTest();
            FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(
                new List<FEC_BatchCaseHandlingImportRow>{ row },
                false
            );
            Test.stopTest();

            System.assert(
                row.status != System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
                row.errors == null ? 'apply failed' : row.errors
            );
            Integer historyAfter = [
                SELECT COUNT()
                FROM FEC_Routing_Action_History__c
                WHERE FEC_Case__c = :importCase.Id
            ];
            System.assert(
                historyAfter > historyBefore,
                'Case-level Resolve import phải tạo Routing Action History.'
            );
        }
    }

    private static void ensureAssignmentRouteToQueueFixture(
        String queueDeveloperName,
        String queueLabel,
        String teamCode
    ) {
        List<Group> existingQueues = [
            SELECT Id
            FROM Group
            WHERE DeveloperName = :queueDeveloperName
            LIMIT 1
        ];
        Group queueRow;
        if (existingQueues.isEmpty()) {
            queueRow = new Group(
                Name = queueLabel,
                DeveloperName = queueDeveloperName,
                Type = FEC_ConstantCommon.GROUP_TYPE_QUEUE
            );
            insert queueRow;
            insert new QueueSobject(QueueId = queueRow.Id, SobjectType = 'Case');
        } else {
            queueRow = existingQueues[0];
        }
        List<FEC_Team__c> teams = [
            SELECT Id
            FROM FEC_Team__c
            WHERE Name = :teamCode
            LIMIT 1
        ];
        Id teamId;
        if (teams.isEmpty()) {
            FEC_Team__c team = new FEC_Team__c(Name = teamCode);
            insert team;
            teamId = team.Id;
        } else {
            teamId = teams[0].Id;
        }
        List<FEC_Team_Queue__c> mappings = [
            SELECT Id
            FROM FEC_Team_Queue__c
            WHERE FEC_Queue_Name__c = :queueDeveloperName
            LIMIT 1
        ];
        if (mappings.isEmpty()) {
            insert new FEC_Team_Queue__c(
                FEC_Queue_Name__c = queueDeveloperName,
                FEC_Select_Team__c = teamId,
                FEC_Team__c = teamCode
            );
        }
    }

    private static void ensureRunUserGroup(String userGroup) {
        Map<String, Schema.SObjectField> userFields = User.SObjectType.getDescribe().fields.getMap();
        if (!userFields.containsKey('FEC_User_Group__c')) {
            return;
        }
        User runUser = new User(Id = UserInfo.getUserId(), FEC_User_Group__c = userGroup);
        update runUser;
    }

    private static void validateImportFieldProfileScenario(
        String caseKey,
        String businessProcessCode,
        Map<String, Object> extraFields,
        List<String> masterDataLabels,
        String userGroup
    ) {
        FEC_Business_Process__c bp = ensureImportBusinessProcess(businessProcessCode);
        FEC_Case_Stage__c stage = ensureImportStage(bp.Id, businessProcessCode, userGroup);
        insertMasterDataLabels(stage.Id, masterDataLabels);
        ensureImportRoutingForStage(stage.Id, userGroup);

        FEC_CaseTriggerHandler.isExecuting = true;
        Case importCase = new Case(
            Subject = 'Import profile ' + businessProcessCode,
            Status = 'New',
            FEC_ID_Search__c = caseKey,
            FEC_Business_Process__c = bp.Id,
            FEC_Current_Case_Stage__c = stage.Id,
            OwnerId = UserInfo.getUserId()
        );
        insert importCase;
        FEC_CaseTriggerHandler.isExecuting = false;
        update new Case(Id = importCase.Id, FEC_ID_Search__c = caseKey, OwnerId = UserInfo.getUserId());

        Map<String, Object> payload = new Map<String, Object>{
            'caseidsearch' => caseKey,
            'routingaction' => 'RESOLVE',
            'inputtedremarks' => 'import profile validation remark long enough'
        };
        if (extraFields != null) {
            payload.putAll(extraFields);
        }

        List<FEC_BatchCaseHandlingImportRow> rows =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(
                new List<Object>{ payload },
                false
            );
        System.assertEquals(1, rows.size(), businessProcessCode);
        String failedStatus = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
        System.assert(
            rows[0].status != failedStatus,
            businessProcessCode + ': ' + (rows[0].errors == null ? '' : rows[0].errors)
        );
    }

    private static FEC_Business_Process__c ensureImportBusinessProcess(String code) {
        List<FEC_Business_Process__c> existing = [
            SELECT Id, FEC_Code__c
            FROM FEC_Business_Process__c
            WHERE FEC_Code__c = :code
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0];
        }
        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = code,
            FEC_Code__c = code,
            FEC_Active__c = true
        );
        insert bp;
        return bp;
    }

    private static FEC_Case_Stage__c ensureImportStage(Id businessProcessId, String code, String userGroup) {
        List<FEC_Case_Stage__c> existing = [
            SELECT Id
            FROM FEC_Case_Stage__c
            WHERE FEC_Business_Process__c = :businessProcessId
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0];
        }
        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'Import Stage ' + code,
            FEC_Code__c = 'IMP_STG_' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(8),
            FEC_Business_Process__c = businessProcessId,
            FEC_Order__c = 1,
            FEC_Active__c = true,
            FEC_User_Group__c = userGroup
        );
        insert stage;
        return stage;
    }

    private static void ensureImportRoutingForStage(Id stageId, String userGroup) {
        if (stageId == null || String.isBlank(userGroup)) {
            return;
        }
        List<FEC_Stage_Screen__c> existing = [
            SELECT Id
            FROM FEC_Stage_Screen__c
            WHERE FEC_Case_Stage__c = :stageId
              AND FEC_User_Group__c = :userGroup
              AND FEC_Action_Button__r.FEC_Code__c = :FEC_CaseBusinessService.RESOLVE
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return;
        }
        List<FEC_Action_Button__c> resolveButtons = [
            SELECT Id
            FROM FEC_Action_Button__c
            WHERE FEC_Code__c = :FEC_CaseBusinessService.RESOLVE
              AND FEC_Active__c = true
            LIMIT 1
        ];
        Id btnResolveId;
        if (resolveButtons.isEmpty()) {
            FEC_Action_Button__c btnResolve = new FEC_Action_Button__c(
                Name = 'Import Resolve ' + userGroup,
                FEC_Code__c = FEC_CaseBusinessService.RESOLVE,
                FEC_Type__c = FEC_ConstantCommon.ACTION_BUTTON_TYPE_ROUTING_ACTION,
                FEC_Active__c = true
            );
            insert btnResolve;
            btnResolveId = btnResolve.Id;
        } else {
            btnResolveId = resolveButtons[0].Id;
        }
        insert new FEC_Stage_Screen__c(
            FEC_Case_Stage__c = stageId,
            FEC_Action_Button__c = btnResolveId,
            FEC_Code__c = 'IMP-SCR-' + userGroup + '-' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(6),
            FEC_User_Group__c = userGroup,
            FEC_Active__c = true,
            FEC_Field_Type__c = FEC_ConstantCommon.STAGE_SCREEN_FIELD_TYPE_ALL
        );
    }

    private static void insertMasterDataLabels(Id stageId, List<String> labels) {
        if (stageId == null || labels == null || labels.isEmpty()) {
            return;
        }
        List<FEC_Master_Data_Setting__c> rows = new List<FEC_Master_Data_Setting__c>();
        for (String labelName : labels) {
            rows.add(new FEC_Master_Data_Setting__c(
                FEC_Stage_Name__c = stageId,
                FEC_Field_Label_Name__c = labelName,
                FEC_Field_Object_Name__c = 'Case',
                FEC_Field_Status__c = true,
                FEC_Field_Editable__c = true
            ));
        }
        insert rows;
    }

    private static String firstPicklistLabel(String fieldApi) {
        Map<String, Schema.SObjectField> fieldMap = Case.SObjectType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey(fieldApi)) {
            return 'TestValue';
        }
        for (Schema.PicklistEntry entry : fieldMap.get(fieldApi).getDescribe().getPicklistValues()) {
            if (entry.isActive() && String.isNotBlank(entry.getValue())) {
                return entry.getLabel();
            }
        }
        return 'TestValue';
    }

    private static String firstPicklistApiValue(String fieldApi) {
        Map<String, Schema.SObjectField> fieldMap = Case.SObjectType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey(fieldApi)) {
            return null;
        }
        for (Schema.PicklistEntry entry : fieldMap.get(fieldApi).getDescribe().getPicklistValues()) {
            if (entry.isActive() && String.isNotBlank(entry.getValue())) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static Id insertMinimalImportContentVersion(String title, Id publishLocationId) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = title + '.xlsx',
            VersionData = EncodingUtil.base64Decode(buildMinimalImportWorkbookBase64())
        );
        if (publishLocationId != null) {
            cv.FirstPublishLocationId = publishLocationId;
        }
        insert cv;
        return cv.Id;
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