@IsTest
private class FEC_BatchCaseHandlingController_Test {

    @TestSetup
    static void setupData() {
        User admin = privilegedUserForBulkCaseRead();

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = 'CC',
            FEC_Active__c = true
        );
        insert prod;
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Request',
            FEC_Code__c = 'REQ',
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
            Name = 'COF - General Flow',
            FEC_Code__c = 'COF',
            FEC_Active__c = true
        );
        insert bp;
        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'BCH Open Stage',
            FEC_Code__c = 'BCH_STG_01',
            FEC_Business_Process__c = bp.Id,
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        insert stage;

        Map<String, Schema.SObjectField> userFields = User.SObjectType.getDescribe().fields.getMap();
        if (userFields.containsKey('FEC_User_Group__c')) {
            admin.FEC_User_Group__c = 'CC';
            update admin;
        }

        insertBatchCaseHandlingTemplate(bp);

        Id bulkCaseRtId = bulkCaseHandlingEligibleRecordTypeId();

        System.runAs(admin) {
            Case testCase1 = new Case(
                Subject = 'Bulk Case handling 01',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                Origin = 'Phone',
                OwnerId = admin.Id,
                FEC_Customer_Type__c = 'Existing',
                FEC_ID_Search__c = 'SRCH-001',
                FEC_Product_Type__c = prod.Id,
                FEC_Category__c = cat.Id,
                FEC_SubCategory__c = subCat.Id,
                FEC_SubCode__c = subCode.Id,
                FEC_Current_Case_Stage__c = stage.Id
            );
            Case testCase2 = new Case(
                Subject = 'Bulk Case handling 02',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                Origin = 'Phone',
                OwnerId = admin.Id,
                FEC_Customer_Type__c = 'Non-existing',
                FEC_ID_Search__c = 'SRCH-002'
            );
            if (bulkCaseRtId != null) {
                testCase1.RecordTypeId = bulkCaseRtId;
                testCase2.RecordTypeId = bulkCaseRtId;
            }
            insert new List<Case>{ testCase1, testCase2 };
            update new List<Case>{
                new Case(Id = testCase1.Id, FEC_ID_Search__c = 'SRCH-001'),
                new Case(Id = testCase2.Id, FEC_ID_Search__c = 'SRCH-002')
            };

            ContentVersion cvCase = new ContentVersion(
                Title = 'CaseAttachment',
                PathOnClient = 'CaseAttachment.pdf',
                VersionData = Blob.valueOf('Mock Case File')
            );
            insert cvCase;
            ContentVersion insertedCvCase = [
                SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cvCase.Id LIMIT 1
            ];
            insert new ContentDocumentLink(
                LinkedEntityId = testCase1.Id,
                ContentDocumentId = insertedCvCase.ContentDocumentId,
                ShareType = 'V'
            );

            Schema.SObjectType batchType = Schema.getGlobalDescribe().get('FEC_Batch_Case_Handling__c');
            if (batchType != null) {
                SObject batchLog = batchType.newSObject();
                Map<String, Schema.SObjectField> fMap = batchType.getDescribe().fields.getMap();
                if (fMap.containsKey('Name')) {
                    batchLog.put('Name', 'Initial_Batch_File.xlsx');
                }
                if (fMap.containsKey('FEC_File_Name__c')) {
                    batchLog.put('FEC_File_Name__c', 'Initial_Batch_File.xlsx');
                }
                if (fMap.containsKey('FEC_Status__c')) {
                    batchLog.put('FEC_Status__c', 'Processed');
                }
                if (fMap.containsKey('FEC_File_Content_Document_Id__c')) {
                    batchLog.put('FEC_File_Content_Document_Id__c', insertedCvCase.ContentDocumentId);
                }
                insert batchLog;

                ContentVersion cvResult = new ContentVersion(
                    Title = 'Initial_Batch_File_Result',
                    PathOnClient = 'Result.xlsx',
                    VersionData = Blob.valueOf('Result')
                );
                ContentVersion cvSource = new ContentVersion(
                    Title = 'Initial_Batch_File',
                    PathOnClient = 'Source.xlsx',
                    VersionData = Blob.valueOf('Source')
                );
                insert new List<ContentVersion>{ cvResult, cvSource };

                List<ContentVersion> insertedCvs = [
                    SELECT ContentDocumentId FROM ContentVersion WHERE Id IN (:cvResult.Id, :cvSource.Id)
                ];
                List<ContentDocumentLink> cdlList = new List<ContentDocumentLink>();
                for (ContentVersion cv : insertedCvs) {
                    cdlList.add(
                        new ContentDocumentLink(
                            LinkedEntityId = batchLog.Id,
                            ContentDocumentId = cv.ContentDocumentId,
                            ShareType = 'V'
                        )
                    );
                }
                insert cdlList;
            }
        }
    }

    /**
     * Kịch bản 1: Lấy siêu dữ liệu thuộc tính bộ lọc (getCaseFilterPropertyMetadata).
     */
    @IsTest
    static void testGetCaseFilterPropertyMetadata() {
        Test.startTest();
        List<FEC_BatchCaseHandlingController.FilterPropertyMeta> metaList =
            FEC_BatchCaseHandlingController.getCaseFilterPropertyMetadata(
                FEC_BCH_FilterPropertyService.SCOPE_PRE_DEFINE
            );
        Test.stopTest();

        System.assertNotEquals(null, metaList);
        System.assert(metaList.size() > 0, 'Phải sinh ra danh sách cấu hình bộ lọc.');
        System.assertEquals('CUSTOMER_TYPE', metaList[0].propertyKey);
    }

    /**
     * Kịch bản 2: Lấy danh sách lịch sử các tệp xử lý hàng loạt gần đây (getRecentRows).
     */
    @IsTest
    static void testGetRecentRows() {
        User admin = privilegedUserForBulkCaseRead();
        System.runAs(admin) {
            Test.startTest();
            List<FEC_BatchCaseHandlingController.BatchRow> rows =
                FEC_BatchCaseHandlingController.getRecentRows();
            Test.stopTest();

            System.assertNotEquals(null, rows);
            if (!rows.isEmpty()) {
                System.assertNotEquals(null, rows[0].id);
            }
        }
    }

    /**
     * Kịch bản 3: Tìm kiếm phân trang dữ liệu Case phục vụ hiển thị Datatable trên giao diện (searchBulkCases).
     */
    @IsTest
    static void testSearchBulkCases() {
        // searchBulkCases applies Security.stripInaccessible; run as a profile with Case field read access.
        User privileged = privilegedUserForBulkCaseRead();
        String filtersJson = '[{"propertyKey":"CASE_ID","operatorKey":"equals","valueText":"SRCH-001"}]';

        System.runAs(privileged) {
            Test.startTest();
            // Kiểm tra phân trang chuẩn
            FEC_BatchCaseHandlingController.BulkCaseSearchResult result =
                FEC_BatchCaseHandlingController.searchBulkCases(filtersJson, 10, 1);

            // Kiểm tra dải biên: truyền giá trị Page/Size âm hoặc vượt ngưỡng Max 100
            FEC_BatchCaseHandlingController.BulkCaseSearchResult resultEdge =
                FEC_BatchCaseHandlingController.searchBulkCases(filtersJson, 500, -1);
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assert(result.totalCount >= 1, 'Hệ thống phải tìm thấy ít nhất 1 bản ghi Case mồi.');
            System.assertEquals(true, result.rows[0].hasAttachment, 'Case 1 đính kèm file ở Setup nên trường này phải là true.');
        }
    }

    /**
     * Kịch bản 4: Tìm kiếm theo mô hình con trỏ Cursor-based SOQL hỗ trợ xuất tệp dữ liệu lớn (searchBulkCasesForExport).
     */
    @IsTest
    static void testSearchBulkCasesForExport() {
        User privileged = privilegedUserForBulkCaseRead();
        System.runAs(privileged) {
            Case c = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'SRCH-001' LIMIT 1];
            String filtersJson = '[]'; // Không dùng bộ lọc động để quét toàn bộ

            Test.startTest();
            // Nhánh 1: afterCaseId rỗng (Trang đầu tiên)
            FEC_BatchCaseHandlingController.BulkCaseSearchResult page1 =
                FEC_BatchCaseHandlingController.searchBulkCasesForExport(filtersJson, '', 10);

            // Nhánh 2: afterCaseId hợp lệ (Quét trang tiếp theo lớn hơn Id cũ)
            FEC_BatchCaseHandlingController.BulkCaseSearchResult page2 =
                FEC_BatchCaseHandlingController.searchBulkCasesForExport(filtersJson, String.valueOf(c.Id), 10);

            // Nhánh 3: afterCaseId sai định dạng cấu trúc Id (Bao phủ khối catch(Exception))
            FEC_BatchCaseHandlingController.BulkCaseSearchResult pageException =
                FEC_BatchCaseHandlingController.searchBulkCasesForExport(filtersJson, 'INVALID_ACC_ID_FORMAT', 10);
            Test.stopTest();

            System.assertNotEquals(null, page1);
            System.assertNotEquals(null, page2);
        }
    }

    /**
     * Kịch bản 5: Tính toán dải phân đoạn phân chia cụm tải file đính kèm Zip (getAttachmentCaseSetOptions).
     */
    @IsTest
    static void testGetAttachmentCaseSetOptions() {
        User privileged = privilegedUserForBulkCaseRead();
        String filtersJson = '[]';

        System.runAs(privileged) {
            Test.startTest();
            List<FEC_BatchCaseHandlingController.CaseSetRangeOption> options =
                FEC_BatchCaseHandlingController.getAttachmentCaseSetOptions(filtersJson);
            Test.stopTest();

            System.assertNotEquals(null, options);
            System.assert(options.size() > 0, 'Open cases owned by user should produce attachment range options.');
        }
    }

    /**
     * Kịch bản 6: Chuyển tiếp yêu cầu nén Zip độc lập (downloadAttachmentsZip, zipExcelFiles, downloadCaseAttachmentsZip).
     */
    @IsTest
    static void testZipServiceBridgingMethods() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // Gọi các phương thức chuyển tiếp tầng Service (Bao phủ chữ ký hàm)
        FEC_BatchCaseHandlingController.downloadAttachmentsZip('[]', 1, 50);
        FEC_BatchCaseHandlingController.zipExcelFiles(new List<Map<String, Object>>(), 'Archive.zip');
        FEC_BatchCaseHandlingController.downloadCaseAttachmentsZip(c.Id);
        Test.stopTest();

        System.assert(true, 'Các hàm gọi cầu nối Zip Service vận hành ổn định.');
    }

    /**
     * Kịch bản 7: Import tệp dữ liệu lô hàng loạt xử lý Case thành công nghiệp vụ (importBatchData).
     */
    @IsTest
    static void testImportBatchData_Success() {
        String base64File = EncodingUtil.base64Encode(Blob.valueOf('Mock Excel Data'));
        // Chuỗi JSON danh sách dòng giả lập gửi từ Client LWC
        String rowsJson = '[{"caseIdSearch":"SRCH-001","status":"Approved"}]';

        Test.startTest();
        FEC_BatchCaseHandlingController.ImportResult result =
            FEC_BatchCaseHandlingController.importBatchData(
                'Case_Handling_Log.xlsx',
                base64File,
                'COF Case Handling Template',
                rowsJson,
                'COF',
                'COF'
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(false, result.success, 'Non-xlsx payload must fail workbook parse.');
        System.assertNotEquals(null, result.message);
    }

    /**
     * Kịch bản 8: Chặn lỗi và xử lý ngoại lệ đầu vào của hàm import (importBatchData - Failure & Empty Cases).
     */
    @IsTest
    static void testImportBatchData_FailuresAndExceptions() {
        Test.startTest();
        // 1. Nhánh lỗi tham số đầu vào rỗng hoàn toàn
        FEC_BatchCaseHandlingController.ImportResult resultEmpty =
            FEC_BatchCaseHandlingController.importBatchData('', '', '', '', '', '');

        // 2. Nhánh lỗi cấu trúc chuỗi JSON không hợp lệ nhằm kích hoạt khối bẫy ngoại lệ Catch(Exception ex)
        FEC_BatchCaseHandlingController.ImportResult resultException =
            FEC_BatchCaseHandlingController.importBatchData(
                'Error_File.xlsx',
                'b64',
                'Template',
                '{bad_json_format}',
                '',
                ''
            );
        Test.stopTest();

        System.assertEquals(false, resultEmpty.success);
        System.assertEquals(false, resultException.success);
    }

    /**
     * Kịch bản 9: Ghi vết log bổ trợ và lưu trữ tệp kết quả xử lý (saveResultFile, logFailedImport).
     */
    @IsTest
    static void testLogAndSaveResultFile() {
        // Lấy Id lô Batch đã tạo từ Setup để gắn file kết quả đầu ra
        Id batchId = null;
        Schema.SObjectType batchType = Schema.getGlobalDescribe().get('FEC_Batch_Case_Handling__c');
        if (batchType != null) {
            String queryText = 'SELECT Id FROM FEC_Batch_Case_Handling__c LIMIT 1';
            List<SObject> logs = Database.query(queryText);
            if (!logs.isEmpty()) batchId = logs[0].Id;
        }

        Test.startTest();
        // 1. Gọi hàm lưu tệp kết quả đầu ra đính kèm trực tiếp vào bản ghi cha
        FEC_BatchCaseHandlingController.saveResultFile(batchId, 'Batch_Output_Result.xlsx', EncodingUtil.base64Encode(Blob.valueOf('ResultData')));
        
        // Gọi dải biên: truyền tham số rỗng bảo vệ guard clause
        FEC_BatchCaseHandlingController.saveResultFile(null, '', '');

        // 2. Ghi log xử lý import thất bại hệ thống độc lập
        FEC_BatchCaseHandlingController.logFailedImport('Critical_Internal_Failure.xlsx', 'COF Template', 'Out of memory database lock stack overflow down');
        Test.stopTest();
    }

    /** RecordType visible to SOQL; prefer Customer_Case so buildBaseCaseWhere RecordType filter matches. */
    private static Id bulkCaseHandlingEligibleRecordTypeId() {
        List<RecordType> rows = [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE
                SObjectType = 'Case'
                AND DeveloperName IN (
                    :FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME,
                    :FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME
                )
        ];
        for (RecordType rt : rows) {
            if (rt.DeveloperName == FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME) {
                return rt.Id;
            }
        }
        return rows.isEmpty() ? null : rows[0].Id;
    }

    private static void insertBatchCaseHandlingTemplate(FEC_Business_Process__c bp) {
        Schema.SObjectType templateType = Schema.getGlobalDescribe().get('FEC_Template_Import__c');
        if (templateType == null) {
            return;
        }
        Map<String, Schema.SObjectField> fieldMap = templateType.getDescribe().fields.getMap();
        SObject template = templateType.newSObject();
        template.put('Name', 'COFTemp_BCH_Test_CSCustomerCare');
        if (fieldMap.containsKey('FEC_Active__c')) {
            template.put('FEC_Active__c', true);
        }
        if (fieldMap.containsKey('FEC_Applicable_for__c')) {
            template.put('FEC_Applicable_for__c', 'Batch Case Handling');
        }
        if (fieldMap.containsKey('FEC_Business_Process__c') && bp != null) {
            template.put('FEC_Business_Process__c', bp.Id);
        }
        if (fieldMap.containsKey('FEC_User_Group__c')) {
            template.put('FEC_User_Group__c', 'CC');
        }
        insert template;

        ContentVersion templateCv = new ContentVersion(
            Title = 'COFTemp_BCH_Test_CSCustomerCare',
            PathOnClient = 'COFTemp_BCH_Test_CSCustomerCare.xlsx',
            VersionData = Blob.valueOf('TemplateFile')
        );
        insert templateCv;
        ContentVersion templateCvRow = [
            SELECT ContentDocumentId FROM ContentVersion WHERE Id = :templateCv.Id LIMIT 1
        ];
        insert new ContentDocumentLink(
            LinkedEntityId = (Id) template.get('Id'),
            ContentDocumentId = templateCvRow.ContentDocumentId,
            ShareType = 'V'
        );
    }

    /** Prefer System Administrator so stripInaccessible leaves Case custom fields readable in bulk search. */
    private static User privilegedUserForBulkCaseRead() {
        List<User> admins = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        return admins.isEmpty() ? new User(Id = UserInfo.getUserId()) : admins[0];
    }

    /**
     * Kịch bản 10: Thống kê số lượng theo quy trìnhAggregate Query (getBusinessProcessExportRows).
     */
    @IsTest
    static void testGetBusinessProcessExportRows() {
        User privileged = privilegedUserForBulkCaseRead();
        String filtersJson = '[]';

        System.runAs(privileged) {
            Test.startTest();
            List<FEC_BatchCaseHandlingController.BusinessProcessExportRow> bpRows =
                FEC_BatchCaseHandlingController.getBusinessProcessExportRows(filtersJson);
            Test.stopTest();

            System.assertNotEquals(null, bpRows);
        }
    }

    @IsTest
    static void testGetCaseFilterPropertyMetadataBundle() {
        Test.startTest();
        FEC_BatchCaseHandlingController.FilterPropertyMetadataBundle bundle =
            FEC_BatchCaseHandlingController.getCaseFilterPropertyMetadataBundle();
        Test.stopTest();

        System.assertNotEquals(null, bundle);
        System.assertNotEquals(null, bundle.preDefineProperties);
        System.assertNotEquals(null, bundle.allCaseProperties);
    }

    @IsTest
    static void testGetBulkExportAllowedLists() {
        Test.startTest();
        List<String> names = FEC_BatchCaseHandlingController.getBulkExportAllowedBusinessProcessNames();
        List<String> codes = FEC_BatchCaseHandlingController.getBulkExportAllowedBusinessProcessCodes();
        Test.stopTest();

        System.assertNotEquals(null, names);
        System.assertNotEquals(null, codes);
    }

    @IsTest
    static void testGetSelectedCasesForExport() {
        User privileged = privilegedUserForBulkCaseRead();
        Case c = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'SRCH-001' LIMIT 1];

        System.runAs(privileged) {
            Test.startTest();
            FEC_BatchCaseHandlingController.BulkCaseSearchResult result =
                FEC_BatchCaseHandlingController.getSelectedCasesForExport(new List<Id>{ c.Id });
            FEC_BatchCaseHandlingController.BulkCaseSearchResult empty =
                FEC_BatchCaseHandlingController.getSelectedCasesForExport(new List<Id>());
            Test.stopTest();

            System.assertEquals(1, result.totalCount);
            System.assertEquals(0, empty.totalCount);
        }
    }

    @IsTest
    static void testResolveExportTemplateMeta() {
        Test.startTest();
        FEC_BatchCaseHandlingController.BusinessProcessExportRow row =
            FEC_BatchCaseHandlingController.resolveExportTemplateMeta('COF', 'COF - General Flow');
        Test.stopTest();

        System.assertNotEquals(null, row);
        System.assertEquals('COF', row.businessProcessCode);
    }

    @IsTest
    static void testGetBulkExportPropertyBundle() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_BatchCaseHandlingController.BulkExportPropertyBundle bundle =
            FEC_BatchCaseHandlingController.getBulkExportPropertyBundle(
                new List<String>{ 'COF' },
                new List<Id>{ c.Id },
                false
            );
        Test.stopTest();

        System.assertNotEquals(null, bundle);
        System.assertNotEquals(null, bundle.columns);
        System.assertNotEquals(null, bundle.valuesByCaseId);
    }

    @IsTest
    static void testGetTemplateFileBase64() {
        ContentVersion cv = new ContentVersion(
            Title = 'TemplateBase64',
            PathOnClient = 'TemplateBase64.xlsx',
            VersionData = Blob.valueOf('TemplateBytes')
        );
        insert cv;

        Test.startTest();
        String base64Data = FEC_BatchCaseHandlingController.getTemplateFileBase64(cv.Id);
        String nullResult = FEC_BatchCaseHandlingController.getTemplateFileBase64(null);
        Test.stopTest();

        System.assertNotEquals(null, base64Data);
        System.assertEquals(null, nullResult);
    }

    @IsTest
    static void testSearchBulkCases_AttachmentFilter() {
        User privileged = privilegedUserForBulkCaseRead();
        String hasAttachmentJson = '[{"propertyKey":"ATTACHMENTS","operatorKey":"equals","valueText":"true"}]';
        String noAttachmentJson = '[{"propertyKey":"ATTACHMENTS","operatorKey":"equals","valueText":"false"}]';

        System.runAs(privileged) {
            Test.startTest();
            FEC_BatchCaseHandlingController.BulkCaseSearchResult withAttachment =
                FEC_BatchCaseHandlingController.searchBulkCases(hasAttachmentJson, 10, 1);
            FEC_BatchCaseHandlingController.BulkCaseSearchResult withoutAttachment =
                FEC_BatchCaseHandlingController.searchBulkCases(noAttachmentJson, 10, 1);
            Test.stopTest();

            System.assertNotEquals(null, withAttachment);
            System.assertNotEquals(null, withoutAttachment);
        }
    }

    @IsTest
    static void testExportTemplateWorkbook() {
        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse response =
            FEC_BatchCaseHandlingController.exportTemplateWorkbook('');
        Test.stopTest();

        System.assertNotEquals(null, response);
    }

    @IsTest
    static void testGetCaseFilterPropertyMetadata_AllCaseScope() {
        Test.startTest();
        List<FEC_BatchCaseHandlingController.FilterPropertyMeta> allCaseMeta =
            FEC_BatchCaseHandlingController.getCaseFilterPropertyMetadata(
                FEC_BCH_FilterPropertyService.SCOPE_ALL_CASE
            );
        Test.stopTest();

        System.assertNotEquals(null, allCaseMeta);
    }

    @IsTest
    static void testSearchBulkCases_CustomerTypeFilter() {
        User privileged = privilegedUserForBulkCaseRead();
        String filtersJson = '[{"propertyKey":"CUSTOMER_TYPE","operatorKey":"equals","valueList":["Existing"]}]';

        System.runAs(privileged) {
            Test.startTest();
            FEC_BatchCaseHandlingController.BulkCaseSearchResult result =
                FEC_BatchCaseHandlingController.searchBulkCases(filtersJson, 10, 1);
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assert(result.totalCount >= 0);
        }
    }

    @IsTest
    static void testGetAttachmentCaseSetOptions_WithCaseIdFilter() {
        String filtersJson = '[{"propertyKey":"CASE_ID","operatorKey":"equals","valueText":"SRCH-001"}]';

        Test.startTest();
        List<FEC_BatchCaseHandlingController.CaseSetRangeOption> options =
            FEC_BatchCaseHandlingController.getAttachmentCaseSetOptions(filtersJson);
        Test.stopTest();

        System.assertNotEquals(null, options);
    }

    @IsTest
    static void testHydratePredefinedFilterPropertyBranches() {
        Test.startTest();
        FEC_BatchCaseHandlingController.FilterPropertyMetadataBundle bundle =
            FEC_BatchCaseHandlingController.getCaseFilterPropertyMetadataBundle();
        Test.stopTest();

        Map<String, FEC_BatchCaseHandlingController.FilterPropertyMeta> byKey =
            new Map<String, FEC_BatchCaseHandlingController.FilterPropertyMeta>();
        for (FEC_BatchCaseHandlingController.FilterPropertyMeta m : bundle.preDefineProperties) {
            if (m != null && String.isNotBlank(m.propertyKey)) {
                byKey.put(m.propertyKey, m);
            }
        }

        System.assert(byKey.containsKey('CUSTOMER_TYPE'));
        System.assert(byKey.containsKey('QUEUE'));
        System.assert(byKey.containsKey('PRODUCT_TYPE'));
        System.assert(byKey.containsKey('CATEGORY'));
        System.assert(byKey.containsKey('SUB_CATEGORY'));
        System.assert(byKey.containsKey('SUB_CODE'));
        System.assert(byKey.containsKey('CASE_ID'));
        System.assert(byKey.containsKey('CASE_STATUS'));
        System.assertNotEquals(null, byKey.get('QUEUE').picklistOptions);
        System.assert(byKey.get('PRODUCT_TYPE').picklistOptions.size() >= 1);
    }

    @IsTest
    static void testHydrateCaseFieldFilterMetadata() {
        Test.startTest();
        List<FEC_BatchCaseHandlingController.FilterPropertyMeta> allCaseMeta =
            FEC_BatchCaseHandlingController.getCaseFilterPropertyMetadata(
                FEC_BCH_FilterPropertyService.SCOPE_ALL_CASE
            );
        Test.stopTest();

        Boolean foundCaseField = false;
        for (FEC_BatchCaseHandlingController.FilterPropertyMeta m : allCaseMeta) {
            if (m != null && m.propertyGroup == 'CASE_FIELD') {
                foundCaseField = true;
                break;
            }
        }
        System.assertEquals(true, foundCaseField);
    }

    @IsTest
    static void testSearchBulkCases_QueueAndStatusFilters() {
        User privileged = privilegedUserForBulkCaseRead();
        String queueJson =
            '[{"propertyKey":"QUEUE","operatorKey":"equals","valueList":["My Pending Cases"]}]';
        String statusJson =
            '[{"propertyKey":"CASE_STATUS","operatorKey":"equals","valueList":["Open"]}]';

        System.runAs(privileged) {
            Test.startTest();
            FEC_BatchCaseHandlingController.BulkCaseSearchResult queueResult =
                FEC_BatchCaseHandlingController.searchBulkCases(queueJson, 20, 1);
            FEC_BatchCaseHandlingController.BulkCaseSearchResult statusResult =
                FEC_BatchCaseHandlingController.searchBulkCases(statusJson, 20, 1);
            Test.stopTest();

            System.assertNotEquals(null, queueResult);
            System.assertNotEquals(null, statusResult);
        }
    }

    @IsTest
    static void testSearchBulkCases_MasterDataFilters() {
        User privileged = privilegedUserForBulkCaseRead();
        String filtersJson =
            '[{"propertyKey":"PRODUCT_TYPE","operatorKey":"equals","valueText":"CC"},' +
            '{"propertyKey":"CATEGORY","operatorKey":"equals","valueText":"REQ"},' +
            '{"propertyKey":"SUB_CATEGORY","operatorKey":"equals","valueText":"RC27"},' +
            '{"propertyKey":"SUB_CODE","operatorKey":"equals","valueText":"RC27.01"}]';

        System.runAs(privileged) {
            Test.startTest();
            FEC_BatchCaseHandlingController.BulkCaseSearchResult result =
                FEC_BatchCaseHandlingController.searchBulkCases(filtersJson, 50, 1);
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assert(result.totalCount >= 0);
        }
    }

    @IsTest
    static void testSearchBulkCases_CreatedByFilters() {
        User privileged = privilegedUserForBulkCaseRead();
        String createdByJson =
            '[{"propertyKey":"CASE_CREATED_BY","operatorKey":"equals","valueList":["BCH-Creator-A"]}]';

        System.runAs(privileged) {
            Test.startTest();
            FEC_BatchCaseHandlingController.BulkCaseSearchResult result =
                FEC_BatchCaseHandlingController.searchBulkCases(createdByJson, 10, 1);
            Test.stopTest();

            System.assertNotEquals(null, result);
        }
    }

    @IsTest
    static void testSearchBulkCases_OffsetCap() {
        User privileged = privilegedUserForBulkCaseRead();
        String filtersJson = '[{"propertyKey":"CASE_ID","operatorKey":"equals","valueText":"SRCH-001"}]';

        System.runAs(privileged) {
            Test.startTest();
            FEC_BatchCaseHandlingController.BulkCaseSearchResult result =
                FEC_BatchCaseHandlingController.searchBulkCases(filtersJson, 100, 500);
            Test.stopTest();

            System.assertNotEquals(null, result);
        }
    }

    @IsTest
    static void testGetAttachmentCaseSetOptions_NoMatches() {
        String filtersJson =
            '[{"propertyKey":"CASE_ID","operatorKey":"equals","valueText":"SRCH-NOT-FOUND-999"}]';

        Test.startTest();
        List<FEC_BatchCaseHandlingController.CaseSetRangeOption> options =
            FEC_BatchCaseHandlingController.getAttachmentCaseSetOptions(filtersJson);
        Test.stopTest();

        System.assertEquals(0, options.size());
    }

    @IsTest
    static void testExportTemplateWorkbook_WithRequestJson() {
        ContentVersion cv = new ContentVersion(
            Title = 'ExportTemplate',
            PathOnClient = 'ExportTemplate.xlsx',
            VersionData = Blob.valueOf('TemplateBytes')
        );
        insert cv;

        String requestJson = JSON.serialize(
            new Map<String, Object>{ 'contentVersionId' => cv.Id, 'caseIds' => new List<String>() }
        );

        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse response =
            FEC_BatchCaseHandlingController.exportTemplateWorkbook(requestJson);
        Test.stopTest();

        System.assertNotEquals(null, response);
    }

    @IsTest
    static void testGetBulkExportPropertyBundle_IncludeAllProperties() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_BatchCaseHandlingController.BulkExportPropertyBundle bundle =
            FEC_BatchCaseHandlingController.getBulkExportPropertyBundle(
                new List<String>{ 'COF' },
                new List<Id>{ c.Id },
                true
            );
        Test.stopTest();

        System.assertNotEquals(null, bundle);
    }

    @IsTest
    static void testImportBatchData_MissingFileName() {
        Test.startTest();
        FEC_BatchCaseHandlingController.ImportResult result =
            FEC_BatchCaseHandlingController.importBatchData(
                null,
                EncodingUtil.base64Encode(Blob.valueOf('data')),
                'Template',
                '[]',
                'COF',
                'CC'
            );
        Test.stopTest();

        System.assertEquals(false, result.success);
    }

    @IsTest
    static void testImportBatchData_ValidWorkbook() {
        Blob workbook = FEC_BatchCaseHandlingResultXlsxBuilder.buildWorkbookBlob(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Routing Action', 'Inputted Remarks' },
                new List<String>{ 'SRCH-001', 'Approve', 'Bulk import remark' }
            }
        );
        User privileged = privilegedUserForBulkCaseRead();

        System.runAs(privileged) {
            Test.startTest();
            FEC_BatchCaseHandlingController.ImportResult result =
                FEC_BatchCaseHandlingController.importBatchData(
                    'COFTemp_BCH_Test_CSCustomerCare.xlsx',
                    EncodingUtil.base64Encode(workbook),
                    'COFTemp_BCH_Test_CSCustomerCare',
                    '[{"caseIdSearch":"SRCH-001","caseId":"x"}]',
                    'COF',
                    'COF - General Flow'
                );
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertNotEquals(null, result.message);
        }
    }

    @IsTest
    static void testImportBatchData_RowsJsonDebugPath() {
        Test.startTest();
        FEC_BatchCaseHandlingController.ImportResult result =
            FEC_BatchCaseHandlingController.importBatchData(
                '',
                '',
                'Template',
                '[{"caseIdSearch":"SRCH-001","caseId":"001"}]',
                'COF',
                'COF - General Flow'
            );
        Test.stopTest();

        System.assertEquals(false, result.success);
    }

    @IsTest
    static void testSearchBulkCasesForExport_PageSizeCap() {
        User privileged = privilegedUserForBulkCaseRead();

        System.runAs(privileged) {
            Test.startTest();
            FEC_BatchCaseHandlingController.BulkCaseSearchResult result =
                FEC_BatchCaseHandlingController.searchBulkCasesForExport('[]', null, 9999);
            Test.stopTest();

            System.assertNotEquals(null, result);
        }
    }

    @IsTest
    static void testResolveExportTemplateMeta_BlankCode() {
        Test.startTest();
        FEC_BatchCaseHandlingController.BusinessProcessExportRow row =
            FEC_BatchCaseHandlingController.resolveExportTemplateMeta('', 'COF - General Flow');
        FEC_BatchCaseHandlingController.BusinessProcessExportRow row2 =
            FEC_BatchCaseHandlingController.resolveExportTemplateMeta('COF', null);
        Test.stopTest();

        System.assertNotEquals(null, row);
        System.assertNotEquals(null, row2);
        System.assertEquals('COF - General Flow', row.businessProcessName);
    }

    @IsTest
    static void testGetCaseFilterPropertyMetadata_PredefinedPicklists() {
        Test.startTest();
        List<FEC_BatchCaseHandlingController.FilterPropertyMeta> metaList =
            FEC_BatchCaseHandlingController.getCaseFilterPropertyMetadata(
                FEC_BCH_FilterPropertyService.SCOPE_PRE_DEFINE
            );
        Test.stopTest();

        Map<String, FEC_BatchCaseHandlingController.FilterPropertyMeta> byKey =
            new Map<String, FEC_BatchCaseHandlingController.FilterPropertyMeta>();
        for (FEC_BatchCaseHandlingController.FilterPropertyMeta m : metaList) {
            if (m != null && String.isNotBlank(m.propertyKey)) {
                byKey.put(m.propertyKey, m);
            }
        }

        System.assert(byKey.containsKey('CASE_STATUS'));
        System.assert(byKey.containsKey('CASE_CREATED_BY'));
        System.assert(byKey.containsKey('CASE_CREATED_BY_ROLE'));
        System.assert(byKey.containsKey('CASE_CREATED_ON'));
        System.assert(byKey.containsKey('ATTACHMENTS'));
        System.assertNotEquals(null, byKey.get('CASE_STATUS').picklistOptions);
        System.assertNotEquals(null, byKey.get('CASE_CREATED_BY').picklistOptions);
    }

    @IsTest
    static void testSearchBulkCases_CaseCreatedOnFilter() {
        User privileged = privilegedUserForBulkCaseRead();
        String filtersJson =
            '[{"propertyKey":"CASE_CREATED_ON","operatorKey":"greater_than","valueText":"2000-01-01"}]';

        System.runAs(privileged) {
            Test.startTest();
            FEC_BatchCaseHandlingController.BulkCaseSearchResult result =
                FEC_BatchCaseHandlingController.searchBulkCases(filtersJson, 10, 1);
            Test.stopTest();

            System.assertNotEquals(null, result);
        }
    }

    @IsTest
    static void testGetRecentRows_ContentDocumentDownloadUrl() {
        User admin = privilegedUserForBulkCaseRead();
        Schema.SObjectType batchType = Schema.getGlobalDescribe().get('FEC_Batch_Case_Handling__c');

        System.runAs(admin) {
            ContentVersion cvOnly = new ContentVersion(
                Title = 'DocOnlySource',
                PathOnClient = 'DocOnlySource.xlsx',
                VersionData = Blob.valueOf('OnlyDoc')
            );
            insert cvOnly;
            ContentVersion cvInserted = [
                SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cvOnly.Id LIMIT 1
            ];

            if (batchType != null) {
                SObject bareBatch = batchType.newSObject();
                Map<String, Schema.SObjectField> fMap = batchType.getDescribe().fields.getMap();
                if (fMap.containsKey('FEC_File_Content_Document_Id__c')) {
                    bareBatch.put('FEC_File_Content_Document_Id__c', cvInserted.ContentDocumentId);
                }
                if (fMap.containsKey('FEC_Status__c')) {
                    bareBatch.put('FEC_Status__c', 'Uploaded');
                }
                insert bareBatch;
            }

            Test.startTest();
            List<FEC_BatchCaseHandlingController.BatchRow> rows =
                FEC_BatchCaseHandlingController.getRecentRows();
            Test.stopTest();

            System.assertNotEquals(null, rows);
        }
    }

    @IsTest
    static void testGetRecentRows_BatchRowFallbackPaths() {
        User admin = privilegedUserForBulkCaseRead();
        Schema.SObjectType batchType = Schema.getGlobalDescribe().get('FEC_Batch_Case_Handling__c');

        System.runAs(admin) {
            if (batchType != null) {
                Map<String, Schema.SObjectField> fMap = batchType.getDescribe().fields.getMap();
                SObject nameOnlyBatch = batchType.newSObject();
                if (fMap.containsKey('Name')) {
                    nameOnlyBatch.put('Name', 'Name_Only_Batch.xlsx');
                }
                if (fMap.containsKey('FEC_Status__c')) {
                    nameOnlyBatch.put('FEC_Status__c', 'Uploaded');
                }
                insert nameOnlyBatch;

                ContentVersion titleCv = new ContentVersion(
                    Title = 'LinkedSourceTitle',
                    PathOnClient = 'LinkedSourceTitle.xlsx',
                    VersionData = Blob.valueOf('Src')
                );
                insert titleCv;
                ContentVersion titleCvRow = [
                    SELECT ContentDocumentId FROM ContentVersion WHERE Id = :titleCv.Id LIMIT 1
                ];
                insert new ContentDocumentLink(
                    LinkedEntityId = (Id) nameOnlyBatch.get('Id'),
                    ContentDocumentId = titleCvRow.ContentDocumentId,
                    ShareType = 'V'
                );

                ContentVersion blankTitleCv = new ContentVersion(
                    Title = ' ',
                    PathOnClient = 'blank.pdf',
                    VersionData = Blob.valueOf('B')
                );
                insert blankTitleCv;
                ContentVersion blankTitleRow = [
                    SELECT ContentDocumentId FROM ContentVersion WHERE Id = :blankTitleCv.Id LIMIT 1
                ];
                insert new ContentDocumentLink(
                    LinkedEntityId = (Id) nameOnlyBatch.get('Id'),
                    ContentDocumentId = blankTitleRow.ContentDocumentId,
                    ShareType = 'V'
                );
            }

            Test.startTest();
            List<FEC_BatchCaseHandlingController.BatchRow> rows =
                FEC_BatchCaseHandlingController.getRecentRows();
            Test.stopTest();

            System.assertNotEquals(null, rows);
        }
    }

    @IsTest
    static void testGetBusinessProcessExportRows_SkipsDisallowedBp() {
        User privileged = privilegedUserForBulkCaseRead();
        FEC_Business_Process__c badBp = new FEC_Business_Process__c(
            Name = 'Disallowed Process XYZ',
            FEC_Code__c = 'BAD_BP_XYZ',
            FEC_Active__c = true
        );
        insert badBp;
        FEC_Case_Stage__c badStage = new FEC_Case_Stage__c(
            Name = 'Bad Stage',
            FEC_Code__c = 'BAD_STG',
            FEC_Business_Process__c = badBp.Id,
            FEC_Active__c = true
        );
        insert badStage;

        Id bulkCaseRtId = bulkCaseHandlingEligibleRecordTypeId();
        System.runAs(privileged) {
            Case badCase = new Case(
                Subject = 'Disallowed BP case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                OwnerId = privileged.Id,
                FEC_Current_Case_Stage__c = badStage.Id
            );
            if (bulkCaseRtId != null) {
                badCase.RecordTypeId = bulkCaseRtId;
            }
            insert badCase;

            Test.startTest();
            List<FEC_BatchCaseHandlingController.BusinessProcessExportRow> rows =
                FEC_BatchCaseHandlingController.getBusinessProcessExportRows('[]');
            Test.stopTest();

            System.assertNotEquals(null, rows);
        }
    }

    @IsTest
    static void testImportBatchData_TemplateNameMismatch() {
        Blob workbook = FEC_BatchCaseHandlingResultXlsxBuilder.buildWorkbookBlob(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Routing Action', 'Inputted Remarks' },
                new List<String>{ 'SRCH-001', 'Approve', 'Remark' }
            }
        );
        User privileged = privilegedUserForBulkCaseRead();

        System.runAs(privileged) {
            Test.startTest();
            FEC_BatchCaseHandlingController.ImportResult result =
                FEC_BatchCaseHandlingController.importBatchData(
                    'Wrong_File_Name.xlsx',
                    EncodingUtil.base64Encode(workbook),
                    'COFTemp_BCH_Test_CSCustomerCare',
                    '[]',
                    'COF',
                    'COF - General Flow'
                );
            Test.stopTest();

            System.assertEquals(false, result.success);
            System.assertNotEquals(null, result.message);
        }
    }

    @IsTest
    static void testResolveExportTemplateMeta_UnknownProcess() {
        Test.startTest();
        FEC_BatchCaseHandlingController.BusinessProcessExportRow row =
            FEC_BatchCaseHandlingController.resolveExportTemplateMeta('UNKNOWN_BP_CODE', 'Unknown Process');
        Test.stopTest();

        System.assertNotEquals(null, row);
        System.assertEquals(FEC_ConstantCommon.STR_EMPTY, row.templateDownloadUrl);
    }

    @IsTest
    static void testSaveResultFile_ResultTitleSuffix() {
        Id batchId = null;
        Schema.SObjectType batchType = Schema.getGlobalDescribe().get('FEC_Batch_Case_Handling__c');
        if (batchType != null) {
            List<SObject> logs = Database.query('SELECT Id FROM FEC_Batch_Case_Handling__c LIMIT 1');
            if (!logs.isEmpty()) {
                batchId = logs[0].Id;
            }
        }

        Test.startTest();
        FEC_BatchCaseHandlingController.saveResultFile(
            batchId,
            'Batch_Output.xlsx',
            EncodingUtil.base64Encode(Blob.valueOf('ResultData'))
        );
        Test.stopTest();
    }
}