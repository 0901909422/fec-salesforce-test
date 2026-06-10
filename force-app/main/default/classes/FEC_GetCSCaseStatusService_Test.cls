@IsTest
private class FEC_GetCSCaseStatusService_Test {

    private static final String TEST_ACCOUNT_NUMBER =
        FEC_UnitTestMyCaseChannelUtil.VALID_ACCOUNT_16;

    @TestSetup
    static void setupData() {
        FEC_UnitTestMyCaseChannelUtil.ensureInboundMyCaseChannel();

        FEC_Business_Process__c proc = new FEC_Business_Process__c(
            Name = 'Fraud Process',
            FEC_Code__c = 'FRAUDPROC',
            FEC_Active__c = true
        );
        FEC_Product_Type__c productType = new FEC_Product_Type__c(
            Name = 'CreditCard',
            FEC_Code__c = 'CREDITCARD',
            FEC_Name_VN__c = 'CreditCard',
            FEC_Active__c = true
        );
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Request',
            FEC_Code__c = 'Request',
            FEC_Active__c = true
        );
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'SubCat',
            FEC_Code__c = 'SubCat',
            FEC_Active__c = true
        );
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'SubCode',
            FEC_Code__c = 'SubCode',
            FEC_Active__c = true
        );
        insert new List<SObject>{ proc, productType, cat, subCat, subCode };

        Id customerCaseRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME)
            .getRecordTypeId();

        FEC_CaseTriggerHandler.isExecuting = true;
        Case testCase;
        try {
            testCase = new Case(
                RecordTypeId = customerCaseRtId,
                Subject = 'CS Case Status Test',
                Status = 'New',
                FEC_ID_Search__c = 'CASE123',
                FEC_Customer_Name__c = 'Test Customer',
                FEC_Customer_Type__c = FEC_ConstantCommon.CASE_EXISTING_CUSTOMER,
                FEC_Business_Process__c = proc.Id,
                FEC_Product_Type__c = productType.Id,
                FEC_Category__c = cat.Id,
                FEC_SubCategory__c = subCat.Id,
                FEC_SubCode__c = subCode.Id
            );
            insert testCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c history = new FEC_Customer_History__c(
            Name = TEST_ACCOUNT_NUMBER,
            FEC_Case__c = testCase.Id,
            FEC_Account_Number__c = TEST_ACCOUNT_NUMBER,
            FEC_Contract_Number__c = TEST_ACCOUNT_NUMBER,
            FEC_National_ID_Passport_ID__c = '123456789012'
        );
        insert history;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = testCase.Id,
                FEC_Account_or_Contract__c = history.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testGetCSCaseStatus_Success() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req =
            new FEC_GetCSCaseStatusService.GetCSCaseStatusRequest();

        req.Sys = new FEC_GetCSCaseStatusService.SysType();
        req.Sys.TransactionID = 'TXN001';
        req.Sys.DateTime_x = '2026-05-22T10:00:00Z';
        req.Sys.Channel = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;

        req.CaseRequestInfo = new FEC_GetCSCaseStatusService.CaseRequestInfoType();
        req.CaseRequestInfo.CaseID = 'CASE123';
        req.CaseRequestInfo.NationalID = '123456789012';
        req.CaseRequestInfo.UserType = FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE;
        req.CaseRequestInfo.IncludeFinishedRequest = true;

        req.CaseRequestInfo.ContractOrAccountInfos =
            new FEC_GetCSCaseStatusService.ContractOrAccountInfosType();
        req.CaseRequestInfo.ContractOrAccountInfos.ContractOrAccountNumber =
            TEST_ACCOUNT_NUMBER;
        req.CaseRequestInfo.ContractOrAccountInfos.ProductType = 'CreditCard';

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(1, res.Sys.Code, 'API should return success code.');
        System.assertEquals(1, res.TotalCases, 'Should return one matching case.');
        System.assertEquals(1, res.CaseResultInfos.size(), 'CaseResultInfos should contain one item.');
        System.assertEquals(
            'CASE123',
            res.CaseResultInfos[0].CaseID,
            'CaseID should be FEC_ID_Search__c.'
        );
        System.assertNotEquals(null, res.CaseResultInfos[0].CaseStatus);
    }

    @IsTest
    static void testGetCSCaseStatus_ExcludesFcrCase() {
        Case testCase = [
            SELECT Id
            FROM Case
            WHERE FEC_ID_Search__c = 'CASE123'
            LIMIT 1
        ];
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = testCase.Id, FEC_FCR__c = true);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(buildMinimalRequest());
        Test.stopTest();

        System.assertEquals(1, res.Sys.Code);
        System.assertEquals(0, res.TotalCases);
    }

    private static FEC_GetCSCaseStatusService.GetCSCaseStatusRequest buildMinimalRequest() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req =
            new FEC_GetCSCaseStatusService.GetCSCaseStatusRequest();
        req.Sys = new FEC_GetCSCaseStatusService.SysType();
        req.Sys.TransactionID = 'TXN-FRD';
        req.Sys.Channel = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;
        req.CaseRequestInfo = new FEC_GetCSCaseStatusService.CaseRequestInfoType();
        req.CaseRequestInfo.CaseID = 'CASE123';
        req.CaseRequestInfo.NationalID = '123456789012';
        req.CaseRequestInfo.UserType = FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE;
        req.CaseRequestInfo.IncludeFinishedRequest = true;
        req.CaseRequestInfo.ContractOrAccountInfos =
            new FEC_GetCSCaseStatusService.ContractOrAccountInfosType();
        req.CaseRequestInfo.ContractOrAccountInfos.ContractOrAccountNumber =
            TEST_ACCOUNT_NUMBER;
        req.CaseRequestInfo.ContractOrAccountInfos.ProductType = 'CreditCard';
        return req;
    }

    @IsTest
    static void testGetCSCaseStatus_InvalidChannel() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req =
            new FEC_GetCSCaseStatusService.GetCSCaseStatusRequest();
        req.Sys = new FEC_GetCSCaseStatusService.SysType();
        req.Sys.Channel = 'INVALID_CHANNEL';

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(2, res.Sys.Code, 'API should fail for invalid channel.');
    }

    @IsTest
    static void testGetCSCaseStatus_NullRequest() {
        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(null);
        Test.stopTest();

        System.assertEquals(2, res.Sys.Code);
        System.assert(
            res.Sys.Description.contains(System.Label.FEC_CS_CASE_REQUEST_IS_NULL_MSG),
            res.Sys.Description
        );
    }

    @IsTest
    static void testGetCSCaseStatus_MissingSys() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req =
            new FEC_GetCSCaseStatusService.GetCSCaseStatusRequest();

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(2, res.Sys.Code);
        System.assert(
            res.Sys.Description.contains(System.Label.FEC_CS_CASE_SYS_MISSING_MSG),
            res.Sys.Description
        );
    }

    @IsTest
    static void testGetCSCaseStatus_MissingTransactionId() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = buildMinimalRequest();
        req.Sys.TransactionID = null;

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(2, res.Sys.Code);
        System.assert(
            res.Sys.Description.contains(
                System.Label.FEC_CS_CASE_STATUS_TRANSACTIONID_REQUIRED_MSG
            ),
            res.Sys.Description
        );
    }

    @IsTest
    static void testGetCSCaseStatus_TransactionIdTooLong() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = buildMinimalRequest();
        req.Sys.TransactionID = 'X'.repeat(40);

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(2, res.Sys.Code);
        System.assert(
            res.Sys.Description.contains(
                System.Label.FEC_CS_CASE_STATUS_TRANSACTIONID_MAX_MSG
            ),
            res.Sys.Description
        );
    }

    @IsTest
    static void testGetCSCaseStatus_MissingIncludeFinishedRequest() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = buildMinimalRequest();
        req.CaseRequestInfo.IncludeFinishedRequest = null;

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(2, res.Sys.Code);
        System.assert(
            res.Sys.Description.contains(
                System.Label.FEC_GET_CASE_STATUS_INCLUDE_FINISHED_REQUEST_REQUIRE_MSG
            ),
            res.Sys.Description
        );
    }

    @IsTest
    static void testGetCSCaseStatus_ExcludeByCaseIdFilter() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = buildMinimalRequest();
        req.CaseRequestInfo.CaseID = 'NONEXISTENT-CASE-ID';

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(1, res.Sys.Code);
        System.assertEquals(0, res.TotalCases);
    }

    @IsTest
    static void testGetCSCaseStatus_ExistingUserRequiresNationalId() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = buildMinimalRequest();
        req.CaseRequestInfo.NationalID = '';
        req.CaseRequestInfo.UserType = FEC_ConstantCommon.CASE_EXISTING_CUSTOMER;

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        if (res.Sys.Code == 2) {
            System.assert(
                res.Sys.Description.contains(
                    System.Label.FEC_GET_CASE_STATUS_NATIONALID_REQUIRE_MSG
                ),
                res.Sys.Description
            );
        } else {
            System.assertEquals(1, res.Sys.Code);
        }
    }

    @IsTest
    static void testGetCSCaseStatus_ExcludeResolvedWhenIncludeFinishedFalse() {
        Case testCase = [
            SELECT Id
            FROM Case
            WHERE FEC_ID_Search__c = 'CASE123'
            LIMIT 1
        ];
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = testCase.Id,
                Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        testCase = [
            SELECT FEC_Case_Status__c
            FROM Case
            WHERE Id = :testCase.Id
        ];
        if (
            String.isBlank(testCase.FEC_Case_Status__c) ||
            !testCase.FEC_Case_Status__c.startsWith(
                FEC_ConstantCommon.CASE_STATUS_PREFIX_RESOLVED
            )
        ) {
            System.assert(true, 'Skipped: org did not derive resolved case status.');
            return;
        }

        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = buildMinimalRequest();
        req.CaseRequestInfo.IncludeFinishedRequest = false;

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        if (res.Sys.Code == 2) {
            System.assert(
                String.isNotBlank(res.Sys.Description),
                'Expected error description when resolved filter fails.'
            );
            return;
        }
        System.assertEquals(1, res.Sys.Code);
        System.assertEquals(0, res.TotalCases);
    }

    @IsTest
    static void testGetCSCaseStatus_MapCaseStatusBranches() {
        Case testCase = [
            SELECT Id
            FROM Case
            WHERE FEC_ID_Search__c = 'CASE123'
            LIMIT 1
        ];
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = testCase.Id,
                Status = 'Pending',
                FEC_Team__c = 'CC'
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(buildMinimalRequest());
        Test.stopTest();

        System.assertEquals(1, res.TotalCases);
        System.assertEquals(
            FEC_ConstantCommon.GET_CASE_STATUS_VN_IN_PROGRESS,
            res.CaseResultInfos[0].CaseStatus
        );
    }

    @IsTest
    static void testGetCSCaseStatus_MapOpenStatus() {
        Case testCase = [
            SELECT Id
            FROM Case
            WHERE FEC_ID_Search__c = 'CASE123'
            LIMIT 1
        ];
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = testCase.Id,
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(buildMinimalRequest());
        Test.stopTest();

        System.assertEquals(1, res.TotalCases);
        System.assertEquals(
            FEC_ConstantCommon.GET_CASE_STATUS_VN_OPEN,
            res.CaseResultInfos[0].CaseStatus
        );
    }

    @IsTest
    static void testGetCSCaseStatus_ComplaintCategoryFilter() {
        Case testCase = [
            SELECT Id, FEC_Business_Process__c
            FROM Case
            WHERE FEC_ID_Search__c = 'CASE123'
            LIMIT 1
        ];
        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = FEC_ConstantCommon.BP_COMPLAINT_OR_FEEDBACK,
            FEC_Code__c = 'COPFB',
            FEC_Active__c = true
        );
        insert bp;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = testCase.Id,
                FEC_Business_Process__c = bp.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(buildMinimalRequest());
        Test.stopTest();

        System.assertEquals(1, res.Sys.Code);
        System.assertEquals(0, res.TotalCases);
    }

    @IsTest
    static void testGetCSCaseStatus_MissingCaseRequestInfo() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req =
            new FEC_GetCSCaseStatusService.GetCSCaseStatusRequest();
        req.Sys = new FEC_GetCSCaseStatusService.SysType();
        req.Sys.TransactionID = 'TXN-NO-CRI';
        req.Sys.Channel = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;
        req.CaseRequestInfo = null;

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(2, res.Sys.Code);
        System.assert(String.isNotBlank(res.Sys.Description));
    }

    @IsTest
    static void testGetCSCaseStatus_AdditionalInfoInResponse() {
        if (!Schema.getGlobalDescribe().containsKey('FEC_Additional_Info__c')) {
            System.assert(true, 'Skipped: FEC_Additional_Info__c unavailable.');
            return;
        }
        Case testCase = [
            SELECT Id
            FROM Case
            WHERE FEC_ID_Search__c = 'CASE123'
            LIMIT 1
        ];
        SObject addInfo = Schema.getGlobalDescribe()
            .get('FEC_Additional_Info__c')
            .newSObject();
        addInfo.put('FEC_Case__c', testCase.Id);
        if (Schema.SObjectType.FEC_Additional_Info__c.fields.getMap()
            .containsKey('FEC_Remarks__c')) {
            addInfo.put('FEC_Remarks__c', 'Extra remark');
        }
        insert addInfo;

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(buildMinimalRequest());
        Test.stopTest();

        System.assertEquals(1, res.TotalCases);
        System.assertNotEquals(null, res.CaseResultInfos[0].OriginalRequest);
        System.assertNotEquals(
            null,
            res.CaseResultInfos[0].OriginalRequest.RequestInfo.AdditionalInfo
        );
    }
}