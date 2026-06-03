@IsTest
private class FEC_BatchCaseCreationController_Test {
    private class BatchCaseCustomerListMock implements HttpCalloutMock {
        private final String accountOrContract;

        BatchCaseCustomerListMock(String accountOrContract) {
            this.accountOrContract = accountOrContract;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><cif:GetCustomerListResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerSearch">' +
                '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                '<Count>1</Count><Customers><Customer>' +
                '<Applications><Application>' +
                '<AccountNumber>' + accountOrContract + '</AccountNumber>' +
                '<ContractNumber>' + accountOrContract + '</ContractNumber>' +
                '</Application></Applications>' +
                '</Customer></Customers>' +
                '</cif:GetCustomerListResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }
    @TestSetup
    static void setupData() {
        FEC_Product_Type__c prod = new FEC_Product_Type__c(Name = 'Credit Card', FEC_Code__c = 'CC', FEC_Active__c = true);
        FEC_Category__c cat = new FEC_Category__c(Name = 'Inquiry', FEC_Code__c = 'INQ', FEC_Active__c = true);
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(Name = 'Card Issue', FEC_Code__c = 'CI', FEC_Active__c = true);
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(Name = 'Lost Card', FEC_Code__c = 'LC', FEC_Active__c = true);
        insert new List<SObject>{ prod, cat, subCat, subCode };

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Active__c = true
        );
        insert noc;

        Schema.SObjectType templateType = Schema.getGlobalDescribe().get('FEC_Template_Import__c');
        if (templateType != null) {
            SObject template = templateType.newSObject();
            template.put('Name', 'Standard Case Template');
            Map<String, Schema.SObjectField> fieldMap = templateType.getDescribe().fields.getMap();
            if (fieldMap.containsKey('FEC_Active__c')) {
                template.put('FEC_Active__c', true);
            }
            if (fieldMap.containsKey('FEC_Applicable_for__c')) {
                template.put('FEC_Applicable_for__c', 'Batch Case Creation');
            }
            insert template;

            ContentVersion cv = new ContentVersion(
                Title = 'Template_Sample',
                PathOnClient = 'Template_Sample.xlsx',
                VersionData = Blob.valueOf('Template Data')
            );
            insert cv;
            ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            insert new ContentDocumentLink(
                LinkedEntityId = (Id) template.get('Id'),
                ContentDocumentId = insertedCv.ContentDocumentId,
                ShareType = 'V'
            );
        }
    }

    @IsTest
    static void testGetTemplateOptions() {
        Test.startTest();
        List<FEC_BatchCaseCreationController.TemplateOption> options = FEC_BatchCaseCreationController.getTemplateOptions();
        Test.stopTest();

        System.assertNotEquals(null, options);
        if (!options.isEmpty()) {
            System.assertEquals('Standard Case Template', options[0].value);
        }
    }

    @IsTest
    static void testGetRecentRows() {
        ContentVersion sourceCv = new ContentVersion(
            Title = 'Recent_Batch',
            PathOnClient = 'Recent_Batch.xlsx',
            VersionData = Blob.valueOf('source')
        );
        insert sourceCv;
        ContentVersion sourceInserted = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :sourceCv.Id LIMIT 1];

        FEC_Batch_Case_Creation__c batch = new FEC_Batch_Case_Creation__c(
            Name = 'Recent_Batch.xlsx',
            FEC_Status__c = 'Processed',
            FEC_Result__c = 'Result'
        );
        Map<String, Schema.SObjectField> batchFields =
            FEC_Batch_Case_Creation__c.SObjectType.getDescribe().fields.getMap();
        if (batchFields.containsKey('FEC_File_Content_Document_Id__c')) {
            batch.put('FEC_File_Content_Document_Id__c', sourceInserted.ContentDocumentId);
        }
        insert batch;

        insert new ContentDocumentLink(
            LinkedEntityId = batch.Id,
            ContentDocumentId = sourceInserted.ContentDocumentId,
            ShareType = 'V'
        );

        ContentVersion resultCv = new ContentVersion(
            Title = 'Recent_Batch_result',
            PathOnClient = 'Recent_Batch_result.csv',
            VersionData = Blob.valueOf('result')
        );
        insert resultCv;
        ContentVersion resultInserted = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :resultCv.Id LIMIT 1];
        insert new ContentDocumentLink(
            LinkedEntityId = batch.Id,
            ContentDocumentId = resultInserted.ContentDocumentId,
            ShareType = 'V'
        );

        Test.startTest();
        List<FEC_BatchDataCreationController.BatchRow> recentRows = FEC_BatchCaseCreationController.getRecentRows();
        Test.stopTest();

        System.assertNotEquals(null, recentRows);
        System.assert(recentRows.size() > 0, 'Must return at least one row.');
        Boolean foundDownload = false;
        for (FEC_BatchDataCreationController.BatchRow row : recentRows) {
            if (row != null && String.isNotBlank(row.fileDownloadUrl)) {
                foundDownload = true;
                break;
            }
        }
        System.assert(foundDownload, 'Recent rows should include download URLs.');
    }

    @IsTest
    static void testImportBatchData_EmptyParams() {
        Test.startTest();
        FEC_BatchDataCreationController.ImportResult result = FEC_BatchCaseCreationController.importBatchData('', '', '', '', '', '');
        Test.stopTest();
        System.assertEquals(false, result.success);
    }

    @IsTest
    static void testImportBatchData_InvalidJsonCatch() {
        Test.startTest();
        FEC_BatchDataCreationController.ImportResult result = FEC_BatchCaseCreationController.importBatchData(
            'Error.xlsx',
            EncodingUtil.base64Encode(Blob.valueOf('x')),
            'Template',
            '{invalid_json}',
            '',
            ''
        );
        Test.stopTest();
        System.assertEquals(false, result.success);
        System.assertNotEquals(null, result.message);
    }

    @IsTest
    static void testImportBatchData_ValidationRows() {
        List<Map<String, String>> rowList = new List<Map<String, String>>();
        rowList.add(new Map<String, String>{
            'layout' => 'broken_layout',
            'contractNumber' => '',
            'interactionPhone' => '',
            'productType' => 'Unknown Prod',
            'category' => 'Unknown Cat',
            'subCategory' => 'Unknown SubCat',
            'subCode' => 'Unknown SubCode',
            'caseStatus' => 'InvalidStatus',
            'interactionEmail' => 'bad_email'
        });

        Test.startTest();
        FEC_BatchDataCreationController.ImportResult result = FEC_BatchCaseCreationController.importBatchData(
            'Batch_Invalid.xlsx',
            EncodingUtil.base64Encode(Blob.valueOf('Mock Content')),
            'Standard Case Template',
            JSON.serialize(rowList),
            '',
            ''
        );
        Test.stopTest();

        System.assertEquals(false, result.success, 'Invalid row should follow failure path.');
        System.assert(result.resultRowsJson != null && result.resultRowsJson.contains('Failed'));
    }

    @IsTest
    static void testImportBatchData_StandardAndWelcome() {
        List<Map<String, String>> standardRows = new List<Map<String, String>>();
        standardRows.add(new Map<String, String>{
            'layout' => 'simple',
            'contractNumber' => '0001500010000000261',
            'interactionPhone' => '0912345678',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'standard import'
        });

        List<Map<String, String>> welcomeRows = new List<Map<String, String>>();
        welcomeRows.add(new Map<String, String>{
            'fileType' => 'welcome',
            'layout' => 'extended',
            'contractNumber' => '20140807-103046-0002',
            'interactionPhone' => '0988888888',
            'productType' => 'CC',
            'category' => 'INQ',
            'subCategory' => 'CI',
            'subCode' => 'LC',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'caseRemarks' => 'welcome import',
            'interactionChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
            'interactionSubChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME
        });

        Test.startTest();
        FEC_BatchDataCreationController.ImportResult standardResult = FEC_BatchCaseCreationController.importBatchData(
            'Batch_Standard.xlsx',
            EncodingUtil.base64Encode(Blob.valueOf('Mock Excel Content')),
            'Standard Case Template',
            JSON.serialize(standardRows),
            '',
            ''
        );
        FEC_BatchDataCreationController.ImportResult welcomeResult = FEC_BatchCaseCreationController.importBatchData(
            'Batch_Welcome.xlsx',
            EncodingUtil.base64Encode(Blob.valueOf('Mock Excel Content')),
            'welcome call template',
            JSON.serialize(welcomeRows),
            '',
            ''
        );
        Test.stopTest();

        System.assertNotEquals(null, standardResult);
        System.assertNotEquals(null, welcomeResult);
        System.assertNotEquals(null, standardResult.batchRecordId);
        System.assertNotEquals(null, welcomeResult.batchRecordId);

        markBatchProcessed(standardResult.batchRecordId);
        markBatchProcessed(welcomeResult.batchRecordId);
    }

    @IsTest
    static void testLogFailedImportAndSaveResultFile() {
        FEC_Batch_Case_Creation__c batch = new FEC_Batch_Case_Creation__c(Name = 'Result_Batch.xlsx', FEC_Status__c = 'Uploaded');
        insert batch;

        Test.startTest();
        FEC_BatchCaseCreationController.logFailedImport('Failure_Log.xlsx', 'Standard Case Template', 'Forced failure reason');
        FEC_BatchCaseCreationController.saveResultFile(
            batch.Id,
            'Result_Log.csv',
            EncodingUtil.base64Encode(Blob.valueOf('Status,Id\nSucceeded,500xx'))
        );
        Test.stopTest();

        List<FEC_Batch_Case_Creation__c> logs = [
            SELECT Id
            FROM FEC_Batch_Case_Creation__c
            WHERE Name = 'Failure_Log.xlsx'
            LIMIT 1
        ];
        System.assert(!logs.isEmpty(), 'Failure log should be inserted.');
    }

    @IsTest
    static void testPendingImportPublicApis() {
        clearUploadedBatchRecords();

        FEC_Batch_Case_Creation__c pending = new FEC_Batch_Case_Creation__c(
            Name = 'Pending_NoPayload.xlsx',
            FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS
        );
        insert pending;

        Test.startTest();
        FEC_BatchCaseCreationController.processPendingBatchImport(pending.Id);
        FEC_BatchCaseCreationController.enqueuePendingImport(pending.Id);
        Test.stopTest();

        System.assertNotEquals(null, pending.Id);
    }

    @IsTest
    static void testProcessPendingBatchImportSuccessPath() {
        List<Object> rows = new List<Object>{
            new Map<String, Object>{
                'layout' => 'simple',
                'contractNumber' => '0001500010000000261',
                'interactionPhone' => '0912345678',
                'productType' => 'Credit Card',
                'category' => 'Inquiry',
                'subCategory' => 'Card Issue',
                'subCode' => 'Lost Card',
                'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
                'caseRemarks' => 'pending import success path'
            }
        };

        FEC_Batch_Case_Creation__c pending = new FEC_Batch_Case_Creation__c(
            Name = 'Pending_Success.xlsx',
            FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS
        );
        insert pending;
        FEC_BatchCaseCreationPendingService.attachPendingImportPayload(
            pending.Id,
            'Standard Case Template',
            JSON.serialize(rows),
            null,
            null
        );

        Test.setMock(HttpCalloutMock.class, new BatchCaseCustomerListMock('0001500010000000261'));
        FEC_CaseTriggerHandler.isExecuting = true;
        Test.startTest();
        FEC_BatchCaseCreationController.processPendingBatchImport(pending.Id);
        Test.stopTest();
        FEC_CaseTriggerHandler.isExecuting = false;

        FEC_Batch_Case_Creation__c refreshed = [
            SELECT Id, FEC_Status__c
            FROM FEC_Batch_Case_Creation__c
            WHERE Id = :pending.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, refreshed.FEC_Status__c);
    }

    @IsTest
    static void testImportParsedRowsPublicApi() {
        List<Object> inputRows = new List<Object>{
            new Map<String, Object>{
                'layout' => 'bad-layout',
                'contractNumber' => '',
                'productType' => '',
                'category' => '',
                'subCategory' => '',
                'caseStatus' => '',
                'caseRemarks' => ''
            }
        };

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            FEC_BatchCaseCreationController.importParsedRows(inputRows);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Failed', results[0].status);
    }

    @IsTest
    static void testGetRecentData() {
        FEC_Batch_Case_Creation__c batch = new FEC_Batch_Case_Creation__c(
            Name = 'RecentData.xlsx',
            FEC_Status__c = 'Processed',
            FEC_Result__c = 'OK'
        );
        insert batch;

        Test.startTest();
        List<FEC_BatchDataCreationController.BatchRow> rows =
            FEC_BatchCaseCreationController.getRecentData();
        Test.stopTest();

        System.assertNotEquals(null, rows);
    }

    @IsTest
    static void testRunPendingImportBatch_EmptyQueue() {
        clearUploadedBatchRecords();
        Test.startTest();
        Integer count = FEC_BatchCaseCreationController.runPendingImportBatch();
        Test.stopTest();
        System.assertEquals(0, count);
    }

    @IsTest
    static void testProcessAllPendingImports_SinglePendingSync() {
        clearUploadedBatchRecords();

        List<Object> rows = new List<Object>{
            new Map<String, Object>{
                'layout' => 'simple',
                'contractNumber' => '0001500010000000261',
                'interactionPhone' => '0912345678',
                'productType' => 'Credit Card',
                'category' => 'Inquiry',
                'subCategory' => 'Card Issue',
                'subCode' => 'Lost Card',
                'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
                'caseRemarks' => 'single pending sync'
            }
        };

        FEC_Batch_Case_Creation__c pending = new FEC_Batch_Case_Creation__c(
            Name = 'SinglePending_Sync.xlsx',
            FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS
        );
        insert pending;
        FEC_BatchCaseCreationPendingService.attachPendingImportPayload(
            pending.Id,
            'Standard Case Template',
            JSON.serialize(rows),
            null,
            null
        );

        Test.setMock(HttpCalloutMock.class, new BatchCaseCustomerListMock('0001500010000000261'));
        Test.startTest();
        Integer count = FEC_BatchCaseCreationController.processAllPendingImports();
        Test.stopTest();

        System.assertEquals(1, count);
    }

    @IsTest
    static void testImportBatchData_WelcomeTemplateWithChannel() {
        List<Map<String, String>> welcomeRows = new List<Map<String, String>>();
        welcomeRows.add(new Map<String, String>{
            'fileType' => 'welcome',
            'layout' => 'extended',
            'contractNumber' => '20140807-103046-0999',
            'interactionPhone' => '0911111111',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'caseRemarks' => 'welcome channel test',
            'interactionChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
            'interactionSubChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME,
            'interactionEmail' => 'welcome@fecredit.com.vn'
        });

        Test.setMock(HttpCalloutMock.class, new BatchCaseCustomerListMock('20140807-103046-0999'));
        Test.startTest();
        FEC_BatchDataCreationController.ImportResult result =
            FEC_BatchCaseCreationController.importBatchData(
                'Batch_Welcome_Channel.xlsx',
                EncodingUtil.base64Encode(Blob.valueOf('Mock Excel Content')),
                'welcome call template',
                JSON.serialize(welcomeRows),
                '',
                ''
            );
        Test.stopTest();

        System.assertNotEquals(null, result.batchRecordId);
    }

    @IsTest
    static void testImportThenProcessPendingBatchEndToEnd() {
        List<Map<String, String>> rowList = new List<Map<String, String>>();
        rowList.add(new Map<String, String>{
            'layout' => 'simple',
            'contractNumber' => '0001500010000000261',
            'interactionPhone' => '0912345678',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'end to end process pending'
        });

        Test.setMock(HttpCalloutMock.class, new BatchCaseCustomerListMock('0001500010000000261'));
        Test.startTest();
        FEC_BatchDataCreationController.ImportResult importResult =
            FEC_BatchCaseCreationController.importBatchData(
                'Batch_EndToEnd.xlsx',
                EncodingUtil.base64Encode(Blob.valueOf('xlsx')),
                'Standard Case Template',
                JSON.serialize(rowList),
                '',
                ''
            );
        FEC_BatchCaseCreationController.processPendingBatchImport(importResult.batchRecordId);
        Test.stopTest();

        FEC_Batch_Case_Creation__c refreshed = [
            SELECT Id, FEC_Status__c
            FROM FEC_Batch_Case_Creation__c
            WHERE Id = :importResult.batchRecordId
            LIMIT 1
        ];
        System.assertNotEquals(FEC_ConstantCommon.UPLOADED_STATUS, refreshed.FEC_Status__c);
    }

    @IsTest
    static void testEnqueuePendingImport() {
        FEC_Batch_Case_Creation__c pending = new FEC_Batch_Case_Creation__c(
            Name = 'Enqueue_Test.xlsx',
            FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS
        );
        insert pending;

        Test.startTest();
        FEC_BatchCaseCreationController.enqueuePendingImport(pending.Id);
        Test.stopTest();

        System.assertNotEquals(null, pending.Id);
    }

    @IsTest
    static void testImportParsedRows_SuccessPath() {
        List<Object> inputRows = new List<Object>{
            new Map<String, Object>{
                'layout' => 'simple',
                'contractNumber' => '0001500010000000261',
                'interactionPhone' => '0912345678',
                'productType' => 'Credit Card',
                'category' => 'Inquiry',
                'subCategory' => 'Card Issue',
                'subCode' => 'Lost Card',
                'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
                'caseRemarks' => 'parsed row success'
            }
        };

        Test.setMock(HttpCalloutMock.class, new BatchCaseCustomerListMock('0001500010000000261'));
        FEC_CaseTriggerHandler.isExecuting = true;
        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            FEC_BatchCaseCreationController.importParsedRows(inputRows);
        Test.stopTest();
        FEC_CaseTriggerHandler.isExecuting = false;

        System.assertEquals(1, results.size());
        System.assertNotEquals('Failed', results[0].status);
    }

    @IsTest
    static void testProcessPendingBatchImport_NullId() {
        Test.startTest();
        FEC_BatchCaseCreationController.processPendingBatchImport(null);
        Test.stopTest();

        System.assert(true, 'Null batch id không throw.');
    }

    @IsTest
    static void testSaveResultFile_AndLogFailedImport() {
        FEC_Batch_Case_Creation__c batch = new FEC_Batch_Case_Creation__c(
            Name = 'SaveResult.xlsx',
            FEC_Status__c = 'Uploaded'
        );
        insert batch;

        Test.startTest();
        FEC_BatchCaseCreationController.saveResultFile(
            batch.Id,
            'Result_Output.csv',
            EncodingUtil.base64Encode(Blob.valueOf('CaseId,Status\n001,OK'))
        );
        FEC_BatchCaseCreationController.logFailedImport(
            'LogFail.xlsx',
            'Standard Case Template',
            'Row validation failed'
        );
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :batch.Id
        ];
        System.assert(links.size() > 0, 'Result file phải được link vào batch record.');
    }

    @IsTest
    static void testImportBatchData_EmptyInputRows() {
        Test.startTest();
        FEC_BatchDataCreationController.ImportResult result =
            FEC_BatchCaseCreationController.importBatchData(
                'Empty_Rows.xlsx',
                EncodingUtil.base64Encode(Blob.valueOf('content')),
                'Standard Case Template',
                '[]',
                '',
                ''
            );
        Test.stopTest();

        System.assertEquals(false, result.success);
    }

    @IsTest
    static void testImportBatchData_WelcomeValidationFailure() {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        rows.add(new Map<String, String>{
            'fileType' => 'welcome',
            'layout' => 'extended',
            'contractNumber' => '0001500010000000999',
            'interactionPhone' => '0912345678',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'invalid welcome status',
            'interactionChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
            'interactionSubChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME
        });

        Test.startTest();
        FEC_BatchDataCreationController.ImportResult result =
            FEC_BatchCaseCreationController.importBatchData(
                'Welcome_Invalid.xlsx',
                EncodingUtil.base64Encode(Blob.valueOf('xlsx')),
                'welcome call template',
                JSON.serialize(rows),
                '',
                ''
            );
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(result.resultRowsJson != null && result.resultRowsJson.contains('Failed'));
    }

    @IsTest
    static void testImportBatchData_OtherExtendedLayout() {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        rows.add(new Map<String, String>{
            'fileType' => 'other',
            'layout' => 'extended',
            'contractNumber' => '0001500010000000888',
            'interactionPhone' => '0922222222',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'other extended',
            'interactionChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
            'interactionSubChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME,
            'interactionEmail' => 'other@example.com'
        });

        Test.setMock(HttpCalloutMock.class, new BatchCaseCustomerListMock('0001500010000000888'));
        Test.startTest();
        FEC_BatchDataCreationController.ImportResult result =
            FEC_BatchCaseCreationController.importBatchData(
                'Other_Extended.xlsx',
                EncodingUtil.base64Encode(Blob.valueOf('xlsx')),
                'Standard Case Template',
                JSON.serialize(rows),
                '',
                ''
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testImportBatchData_WelcomeUploadSuccess() {
        List<Map<String, String>> welcomeRows = new List<Map<String, String>>();
        welcomeRows.add(new Map<String, String>{
            'fileType' => 'welcome',
            'layout' => 'extended',
            'contractNumber' => '20140807-103046-0001',
            'interactionPhone' => '0912345678',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'caseRemarks' => 'welcome upload success',
            'interactionChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
            'interactionSubChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME
        });

        Test.startTest();
        FEC_BatchDataCreationController.ImportResult result =
            FEC_BatchCaseCreationController.importBatchData(
                'Welcome_Upload.xlsx',
                EncodingUtil.base64Encode(Blob.valueOf('xlsx')),
                'welcome call template',
                JSON.serialize(welcomeRows),
                '',
                ''
            );
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(FEC_ConstantCommon.UPLOADED_STATUS, result.status);
    }

    @IsTest
    static void testGetRecentRows_ContentDocumentDownloadFallback() {
        FEC_Batch_Case_Creation__c batch = new FEC_Batch_Case_Creation__c(
            FEC_Status__c = 'Processed'
        );
        Map<String, Schema.SObjectField> fMap =
            FEC_Batch_Case_Creation__c.SObjectType.getDescribe().fields.getMap();
        if (fMap.containsKey('FEC_File_Content_Document_Id__c')) {
            ContentVersion cv = new ContentVersion(
                Title = 'DocOnly',
                PathOnClient = 'DocOnly.xlsx',
                VersionData = Blob.valueOf('doc')
            );
            insert cv;
            ContentVersion cvRow = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            batch.put('FEC_File_Content_Document_Id__c', cvRow.ContentDocumentId);
        }
        insert batch;

        Test.startTest();
        List<FEC_BatchDataCreationController.BatchRow> rows =
            FEC_BatchCaseCreationController.getRecentRows();
        Test.stopTest();

        System.assertNotEquals(null, rows);
    }

    @IsTest
    static void testGetTemplateOptions_DownloadUrlPopulation() {
        Schema.SObjectType templateType = Schema.getGlobalDescribe().get('FEC_Template_Import__c');
        if (templateType == null) {
            return;
        }
        SObject secondTemplate = templateType.newSObject();
        secondTemplate.put('Name', 'Second Case Template');
        Map<String, Schema.SObjectField> fieldMap = templateType.getDescribe().fields.getMap();
        if (fieldMap.containsKey('FEC_Active__c')) {
            secondTemplate.put('FEC_Active__c', true);
        }
        if (fieldMap.containsKey('FEC_Applicable_for__c')) {
            secondTemplate.put('FEC_Applicable_for__c', 'Batch Case Creation');
        }
        insert secondTemplate;

        ContentVersion cv = new ContentVersion(
            Title = 'Second_Case_Template',
            PathOnClient = 'Second_Case_Template.xlsx',
            VersionData = Blob.valueOf('tpl2')
        );
        insert cv;
        ContentVersion cvRow = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        insert new ContentDocumentLink(
            LinkedEntityId = (Id) secondTemplate.get('Id'),
            ContentDocumentId = cvRow.ContentDocumentId,
            ShareType = 'V'
        );

        Test.startTest();
        List<FEC_BatchCaseCreationController.TemplateOption> options =
            FEC_BatchCaseCreationController.getTemplateOptions();
        Test.stopTest();

        Boolean foundDownload = false;
        for (FEC_BatchCaseCreationController.TemplateOption opt : options) {
            if (opt != null && String.isNotBlank(opt.downloadUrl)) {
                foundDownload = true;
                break;
            }
        }
        System.assert(foundDownload, 'At least one template should expose a download URL.');
    }

    @IsTest
    static void testProcessPendingBatchImport_WelcomeInsert() {
        clearUploadedBatchRecords();

        List<Object> rows = new List<Object>{
            new Map<String, Object>{
                'fileType' => 'welcome',
                'layout' => 'extended',
                'contractNumber' => '20140807-103046-0001',
                'interactionPhone' => '0912345678',
                'productType' => 'Credit Card',
                'category' => 'Inquiry',
                'subCategory' => 'Card Issue',
                'subCode' => 'Lost Card',
                'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
                'caseRemarks' => 'welcome insert path',
                'interactionChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
                'interactionSubChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME
            }
        };

        FEC_Batch_Case_Creation__c pending = new FEC_Batch_Case_Creation__c(
            Name = 'Pending_Welcome_Insert.xlsx',
            FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS
        );
        insert pending;
        FEC_BatchCaseCreationPendingService.attachPendingImportPayload(
            pending.Id,
            'welcome call template',
            JSON.serialize(rows),
            '["Case ID"]',
            '[["20140807-103046-0001"]]'
        );

        Test.setMock(HttpCalloutMock.class, new BatchCaseCustomerListMock('20140807-103046-0001'));
        FEC_CaseTriggerHandler.isExecuting = true;
        Test.startTest();
        FEC_BatchCaseCreationController.processPendingBatchImport(pending.Id);
        Test.stopTest();
        FEC_CaseTriggerHandler.isExecuting = false;

        FEC_Batch_Case_Creation__c refreshed = [
            SELECT FEC_Status__c, FEC_Total_Success_Records__c
            FROM FEC_Batch_Case_Creation__c
            WHERE Id = :pending.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, refreshed.FEC_Status__c);
    }

    @IsTest
    static void testImportBatchData_ValidationFailureUpdatesBatch() {
        List<Map<String, String>> rowList = new List<Map<String, String>>();
        rowList.add(new Map<String, String>{
            'layout' => 'broken',
            'contractNumber' => '',
            'productType' => '',
            'category' => '',
            'subCategory' => '',
            'caseStatus' => '',
            'caseRemarks' => ''
        });

        Test.startTest();
        FEC_BatchDataCreationController.ImportResult result =
            FEC_BatchCaseCreationController.importBatchData(
                'Batch_All_Fail.xlsx',
                EncodingUtil.base64Encode(Blob.valueOf('x')),
                'Standard Case Template',
                JSON.serialize(rowList),
                '',
                ''
            );
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertNotEquals(null, result.batchRecordId);
    }

    @IsTest
    static void testImportBatchData_InvalidPhoneAndEmail() {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        rows.add(new Map<String, String>{
            'layout' => 'simple',
            'contractNumber' => '0001500010000000261',
            'interactionPhone' => 'not-a-phone',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'invalid phone',
            'interactionEmail' => 'not-an-email'
        });

        Test.startTest();
        FEC_BatchDataCreationController.ImportResult result =
            FEC_BatchCaseCreationController.importBatchData(
                'Invalid_Contact.xlsx',
                EncodingUtil.base64Encode(Blob.valueOf('x')),
                'Standard Case Template',
                JSON.serialize(rows),
                '',
                ''
            );
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(result.resultRowsJson.contains('Failed'));
    }

    @IsTest
    static void testImportBatchData_ProductTypeCodeWithDash() {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        rows.add(new Map<String, String>{
            'layout' => 'simple',
            'contractNumber' => '0001500010000000261',
            'productType' => 'CC-Display',
            'category' => 'INQ',
            'subCategory' => 'CI',
            'subCode' => 'LC',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'code key extract'
        });

        Test.startTest();
        FEC_BatchDataCreationController.ImportResult result =
            FEC_BatchCaseCreationController.importBatchData(
                'Code_Key.xlsx',
                EncodingUtil.base64Encode(Blob.valueOf('x')),
                'Standard Case Template',
                JSON.serialize(rows),
                '',
                ''
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testImportBatchData_WelcomeMissingPhone() {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        rows.add(new Map<String, String>{
            'fileType' => 'welcome',
            'layout' => 'extended',
            'contractNumber' => '20140807-103046-0001',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'caseRemarks' => 'no phone',
            'interactionChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
            'interactionSubChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME
        });

        Test.startTest();
        FEC_BatchDataCreationController.ImportResult result =
            FEC_BatchCaseCreationController.importBatchData(
                'Welcome_NoPhone.xlsx',
                EncodingUtil.base64Encode(Blob.valueOf('x')),
                'welcome call template',
                JSON.serialize(rows),
                '',
                ''
            );
        Test.stopTest();

        System.assertEquals(false, result.success);
    }

    @IsTest
    static void testImportBatchData_OtherExtendedMissingChannel() {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        rows.add(new Map<String, String>{
            'fileType' => 'other',
            'layout' => 'extended',
            'contractNumber' => '0001500010000000261',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'missing channel'
        });

        Test.startTest();
        FEC_BatchDataCreationController.ImportResult result =
            FEC_BatchCaseCreationController.importBatchData(
                'Other_NoChannel.xlsx',
                EncodingUtil.base64Encode(Blob.valueOf('x')),
                'Standard Case Template',
                JSON.serialize(rows),
                '',
                ''
            );
        Test.stopTest();

        System.assertEquals(false, result.success);
    }

    @IsTest
    static void testProcessPendingBatchImport_ExtendedOther() {
        clearUploadedBatchRecords();

        List<Object> rows = new List<Object>{
            new Map<String, Object>{
                'fileType' => 'other',
                'layout' => 'extended',
                'contractNumber' => '0001500010000000888',
                'interactionPhone' => '0933333333',
                'productType' => 'Credit Card',
                'category' => 'Inquiry',
                'subCategory' => 'Card Issue',
                'subCode' => 'Lost Card',
                'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
                'caseRemarks' => 'extended other pending',
                'interactionChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
                'interactionSubChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME
            }
        };

        FEC_Batch_Case_Creation__c pending = new FEC_Batch_Case_Creation__c(
            Name = 'Pending_Other_Extended.xlsx',
            FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS
        );
        insert pending;
        FEC_BatchCaseCreationPendingService.attachPendingImportPayload(
            pending.Id,
            'Standard Case Template',
            JSON.serialize(rows),
            null,
            null
        );

        Test.setMock(HttpCalloutMock.class, new BatchCaseCustomerListMock('0001500010000000888'));
        Test.startTest();
        FEC_BatchCaseCreationController.processPendingBatchImport(pending.Id);
        Test.stopTest();

        FEC_Batch_Case_Creation__c refreshed = [
            SELECT FEC_Status__c
            FROM FEC_Batch_Case_Creation__c
            WHERE Id = :pending.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, refreshed.FEC_Status__c);
    }

    @IsTest
    static void testImportBatchData_WelcomeContractWithoutDash() {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        rows.add(new Map<String, String>{
            'fileType' => 'welcome',
            'layout' => 'extended',
            'contractNumber' => '0001500010000000261',
            'interactionPhone' => '0912345678',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'caseRemarks' => 'missing dash',
            'interactionChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
            'interactionSubChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME
        });

        Test.startTest();
        FEC_BatchDataCreationController.ImportResult result =
            FEC_BatchCaseCreationController.importBatchData(
                'Welcome_NoDash.xlsx',
                EncodingUtil.base64Encode(Blob.valueOf('x')),
                'welcome call template',
                JSON.serialize(rows),
                '',
                ''
            );
        Test.stopTest();

        System.assertEquals(false, result.success);
    }

    @IsTest
    static void testImportBatchData_AccountNumberFormat() {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        rows.add(new Map<String, String>{
            'fileType' => 'other',
            'layout' => 'simple',
            'contractNumber' => '1500010000000261',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'account number path'
        });

        Test.setMock(HttpCalloutMock.class, new BatchCaseCustomerListMock('1500010000000261'));
        FEC_CaseTriggerHandler.isExecuting = true;
        Test.startTest();
        FEC_BatchDataCreationController.ImportResult result =
            FEC_BatchCaseCreationController.importBatchData(
                'Account_Format.xlsx',
                EncodingUtil.base64Encode(Blob.valueOf('xlsx')),
                'Standard Case Template',
                JSON.serialize(rows),
                '',
                ''
            );
        FEC_BatchCaseCreationController.processPendingBatchImport(result.batchRecordId);
        Test.stopTest();
        FEC_CaseTriggerHandler.isExecuting = false;

        System.assertNotEquals(null, result.batchRecordId);
    }

    private static void clearUploadedBatchRecords() {
        List<FEC_Batch_Case_Creation__c> uploaded = [
            SELECT Id, FEC_Status__c
            FROM FEC_Batch_Case_Creation__c
            WHERE FEC_Status__c = :FEC_ConstantCommon.UPLOADED_STATUS
        ];
        if (uploaded.isEmpty()) {
            return;
        }
        for (FEC_Batch_Case_Creation__c row : uploaded) {
            row.FEC_Status__c = 'Processed';
        }
        update uploaded;
    }

    @IsTest
    static void testImportBatchData_WithSourceHeadersAndRows() {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        rows.add(new Map<String, String>{
            'layout' => 'simple',
            'contractNumber' => '0001500010000000261',
            'interactionPhone' => '0912345678',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'with source payload'
        });

        Test.startTest();
        FEC_BatchDataCreationController.ImportResult result =
            FEC_BatchCaseCreationController.importBatchData(
                'Source_Payload.xlsx',
                EncodingUtil.base64Encode(Blob.valueOf('xlsx')),
                'Standard Case Template',
                JSON.serialize(rows),
                '["Case ID","Remarks"]',
                '[["0001500010000000261","remark1"]]'
            );
        Test.stopTest();

        System.assertEquals(true, result.success);
        markBatchProcessed(result.batchRecordId);
    }

    private static void markBatchProcessed(Id batchId) {
        if (batchId == null) {
            return;
        }
        update new FEC_Batch_Case_Creation__c(Id = batchId, FEC_Status__c = 'Processed');
    }

}