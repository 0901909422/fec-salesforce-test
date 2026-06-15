@IsTest
private class FEC_GetCSCaseStatusService_Test {

    private static final String TEST_ACCOUNT_NUMBER = 'ACC123';

    @TestSetup
    static void setupData() {
        insert new FEC_Channel__c(
            Name = 'Inbound',
            FEC_Channel_ID__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
            FEC_Channel_Vietnamese_name__c = 'Inbound',
            FEC_Channel_Status__c = true,
            FEC_Update_Case_Status__c = true
        );

        FEC_Business_Process__c proc = new FEC_Business_Process__c(
            Name = FEC_ConstantCommon.BP_GENERAL_SERVICE,
            FEC_Code__c = 'GENSVC',
            FEC_Alias__c = 'GSR',
            FEC_Name_VN__c = 'General Service',
            FEC_Active__c = true
        );
        FEC_Category__c category = new FEC_Category__c(
            Name = FEC_ConstantCommon.FEC_CATEGORY_REQUEST,
            FEC_Code__c = 'Request',
            FEC_Name_VN__c = 'Request VN',
            FEC_Active__c = true
        );
        FEC_Sub_Category__c subCategory = new FEC_Sub_Category__c(
            Name = 'Status SubCat',
            FEC_Code__c = 'STATSC',
            FEC_Alias__c = 'REQ_ALIAS',
            FEC_Name_VN__c = 'Request Type VN',
            FEC_Active__c = true
        );
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'Status SubCode',
            FEC_Code__c = 'STATSB',
            FEC_Name_VN__c = 'SubCode VN',
            FEC_Active__c = true
        );
        insert new List<SObject>{ proc, category, subCategory, subCode };

        FEC_Product_Type__c productType = new FEC_Product_Type__c(
            Name = 'CreditCard',
            FEC_Code__c = 'CREDITCARD',
            FEC_Name_VN__c = 'CreditCard',
            FEC_Active__c = true
        );
        insert productType;

        Id customerCaseRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME)
            .getRecordTypeId();

        FEC_CaseTriggerHandler.isExecuting = true;
        Case testCase;
        try {
            testCase = new Case(
                RecordTypeId = customerCaseRtId,
                Subject = 'CS Case Status Test',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_ID_Search__c = 'CASE123',
                FEC_Customer_Name__c = 'Test Customer',
                FEC_Customer_Type__c = FEC_ConstantCommon.CASE_EXISTING_CUSTOMER,
                FEC_Business_Process__c = proc.Id,
                FEC_Product_Type__c = productType.Id,
                FEC_Category__c = category.Id,
                FEC_SubCategory__c = subCategory.Id,
                FEC_SubCode__c = subCode.Id,
                FEC_Remarks__c = 'Status test remarks'
            );
            insert testCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c history = new FEC_Customer_History__c(
            Name = TEST_ACCOUNT_NUMBER,
            FEC_Case__c = testCase.Id,
            FEC_Account_Number__c = TEST_ACCOUNT_NUMBER,
            FEC_National_ID_Passport_ID__c = '123456789012',
            FEC_Primary_Phone__c = '0901234567',
            FEC_Email__c = 'customer@example.com'
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

        insert new FEC_Additional_Info__c(
            FEC_Case__c = testCase.Id
        );
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
        System.assertEquals(
            FEC_ConstantCommon.GET_CASE_STATUS_VN_OPEN,
            res.CaseResultInfos[0].CaseStatus,
            'Open status should map to Vietnamese API label.'
        );
        System.assertNotEquals(null, res.CaseResultInfos[0].OriginalRequest);
        System.assertEquals(
            'Test Customer',
            res.CaseResultInfos[0].OriginalRequest.CustomerInfo.Name
        );
        System.assertEquals(
            '0901234567',
            res.CaseResultInfos[0].OriginalRequest.CustomerInfo.PhoneNumber
        );
        System.assertEquals(
            'customer@example.com',
            res.CaseResultInfos[0].OriginalRequest.CustomerInfo.EmailAddress
        );
        System.assertEquals(
            FEC_ConstantCommon.BP_GENERAL_SERVICE,
            res.CaseResultInfos[0].OriginalRequest.RequestInfo.CaseType
        );
        System.assertEquals(
            'REQ_ALIAS',
            res.CaseResultInfos[0].OriginalRequest.RequestInfo.RequestType
        );
        System.assertEquals(
            'Request Type VN',
            res.CaseResultInfos[0].OriginalRequest.RequestInfo.RequestTypeVN
        );
        System.assertEquals(
            'Status SubCat',
            res.CaseResultInfos[0].OriginalRequest.RequestInfo.RequestTypeEN
        );
        System.assertNotEquals(
            null,
            res.CaseResultInfos[0].OriginalRequest.RequestInfo.AdditionalInfo
        );
        System.assertEquals(
            'Status test remarks',
            res.CaseResultInfos[0].Remarks,
            'Without FEC_Case_Remarks__c, CaseResultInfo.Remarks falls back to FEC_Remarks__c.'
        );
        System.assertEquals(
            'Status test remarks',
            res.CaseResultInfos[0].OriginalRequest.RequestInfo.Remarks,
            'OriginalRequest keeps create-case remark.'
        );
    }

    @IsTest
    static void testGetCSCaseStatus_RequestTypeLabelsFromSubCategory() {
        FEC_Business_Process__c welcomeProcess = new FEC_Business_Process__c(
            Name = 'Welcome Call',
            FEC_Code__c = 'WELCOMECALL',
            FEC_Alias__c = 'Welcome Call',
            FEC_Active__c = true
        );
        FEC_Sub_Category__c subCategory = new FEC_Sub_Category__c(
            Name = 'WC Sub Name',
            FEC_Code__c = 'WC_CODE_0',
            FEC_Alias__c = 'WC_CODE_0',
            FEC_Name_VN__c = null,
            FEC_Active__c = true
        );
        insert new List<SObject>{ welcomeProcess, subCategory };

        Id customerCaseRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME)
            .getRecordTypeId();
        FEC_Product_Type__c productType = [
            SELECT Id
            FROM FEC_Product_Type__c
            WHERE FEC_Name_VN__c = 'CreditCard'
            LIMIT 1
        ];

        FEC_CaseTriggerHandler.isExecuting = true;
        Case welcomeCase;
        try {
            welcomeCase = new Case(
                RecordTypeId = customerCaseRtId,
                Subject = 'Welcome Call Request Type Test',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_ID_Search__c = 'CASE-WC-RT',
                FEC_Customer_Name__c = 'Welcome Customer',
                FEC_Customer_Type__c = FEC_ConstantCommon.CASE_EXISTING_CUSTOMER,
                FEC_Business_Process__c = welcomeProcess.Id,
                FEC_Product_Type__c = productType.Id,
                FEC_SubCategory__c = subCategory.Id
            );
            insert welcomeCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c history = new FEC_Customer_History__c(
            Name = 'ACC-WC-RT',
            FEC_Case__c = welcomeCase.Id,
            FEC_Account_Number__c = 'ACC-WC-RT',
            FEC_National_ID_Passport_ID__c = '999888777666',
            FEC_Primary_Phone__c = '0901111222',
            FEC_Email__c = 'welcome@example.com'
        );
        insert history;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = welcomeCase.Id,
                FEC_Account_or_Contract__c = history.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req =
            new FEC_GetCSCaseStatusService.GetCSCaseStatusRequest();
        req.Sys = new FEC_GetCSCaseStatusService.SysType();
        req.Sys.TransactionID = 'TXN-WC-RT';
        req.Sys.Channel = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;
        req.CaseRequestInfo = new FEC_GetCSCaseStatusService.CaseRequestInfoType();
        req.CaseRequestInfo.CaseID = 'CASE-WC-RT';
        req.CaseRequestInfo.NationalID = '999888777666';
        req.CaseRequestInfo.UserType = FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE;
        req.CaseRequestInfo.IncludeFinishedRequest = true;
        req.CaseRequestInfo.ContractOrAccountInfos =
            new FEC_GetCSCaseStatusService.ContractOrAccountInfosType();
        req.CaseRequestInfo.ContractOrAccountInfos.ContractOrAccountNumber = 'ACC-WC-RT';
        req.CaseRequestInfo.ContractOrAccountInfos.ProductType = 'CreditCard';

        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);

        System.assertEquals(1, res.CaseResultInfos.size());
        System.assertEquals(
            'Welcome Call',
            res.CaseResultInfos[0].OriginalRequest.RequestInfo.RequestType
        );
        System.assertEquals(
            'WC Sub Name',
            res.CaseResultInfos[0].OriginalRequest.RequestInfo.RequestTypeVN,
            'RequestTypeVN should fall back to SubCategory Name when FEC_Name_VN__c is blank.'
        );
        System.assertEquals(
            'WC Sub Name',
            res.CaseResultInfos[0].OriginalRequest.RequestInfo.RequestTypeEN
        );
    }

    @IsTest
    static void testGetCSCaseStatus_LastRemarkFromCaseRemarks() {
        Case testCase = [
            SELECT Id
            FROM Case
            WHERE FEC_ID_Search__c = 'CASE123'
            LIMIT 1
        ];

        insert new FEC_Case_Remarks__c(
            FEC_Case__c = testCase.Id,
            FEC_Case_Remarks__c = 'Older stage remark',
            FEC_Stage_Name__c = 'Stage 1',
            FEC_User_Role__c = 'Maker'
        );
        FEC_Case_Remarks__c latestRemark = new FEC_Case_Remarks__c(
            FEC_Case__c = testCase.Id,
            FEC_Case_Remarks__c = 'Latest stage remark',
            FEC_Stage_Name__c = 'Stage 2',
            FEC_User_Role__c = 'Checker'
        );
        insert latestRemark;
        Test.setCreatedDate(latestRemark.Id, System.now().addMinutes(5));

        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(buildMinimalRequest());

        System.assertEquals(1, res.CaseResultInfos.size());
        System.assertEquals(
            'Latest stage remark',
            res.CaseResultInfos[0].Remarks,
            'CaseResultInfo.Remarks should be the latest FEC_Case_Remarks__c record.'
        );
        System.assertEquals(
            'Status test remarks',
            res.CaseResultInfos[0].OriginalRequest.RequestInfo.Remarks,
            'OriginalRequest.RequestInfo.Remarks should remain the create-case remark.'
        );
    }

    @IsTest
    static void testGetLastCaseRemarksBulk_EmptyInput() {
        System.assertEquals(
            0,
            FEC_GetCSCaseStatusService.getLastCaseRemarksBulk(new Set<Id>()).size()
        );
        System.assertEquals(
            0,
            FEC_GetCSCaseStatusService.getLastCaseRemarksBulk(null).size()
        );
    }

    @IsTest
    static void testGetCSCaseStatus_BlankLastRemarkFallsBackToCreateRemark() {
        Case testCase = [
            SELECT Id
            FROM Case
            WHERE FEC_ID_Search__c = 'CASE123'
            LIMIT 1
        ];

        insert new FEC_Case_Remarks__c(
            FEC_Case__c = testCase.Id,
            FEC_Case_Remarks__c = '   ',
            FEC_Stage_Name__c = 'Stage blank',
            FEC_User_Role__c = 'Maker'
        );

        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(buildMinimalRequest());

        System.assertEquals(
            'Status test remarks',
            res.CaseResultInfos[0].Remarks,
            'Blank FEC_Case_Remarks__c should fall back to FEC_Remarks__c.'
        );
    }

    @IsTest
    static void testGetCSCaseStatus_NoRemarkDataReturnsEmptyString() {
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
                FEC_Remarks__c = null
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(buildMinimalRequest());

        System.assertEquals(
            FEC_ConstantCommon.STR_EMPTY,
            res.CaseResultInfos[0].Remarks,
            'No remark data should return empty string, not null.'
        );
        System.assertEquals(
            FEC_ConstantCommon.STR_EMPTY,
            res.CaseResultInfos[0].OriginalRequest.RequestInfo.Remarks
        );
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
    static void testGetCSCaseStatus_ChannelFunctionNotAllowed() {
        insert new FEC_Channel__c(
            Name = 'Vtiger',
            FEC_Channel_ID__c = 'Vtiger',
            FEC_Channel_Vietnamese_name__c = 'Vtiger',
            FEC_Channel_Status__c = true,
            FEC_Cancel_Case__c = true,
            FEC_Update_Case_Status__c = false
        );

        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = buildMinimalRequest();
        req.Sys.Channel = 'Vtiger';

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(2, res.Sys.Code);
        System.assert(
            res.Sys.Description.contains(
                FEC_ConstantCommon.MY_CASE_CHANNEL_GET_CASE_STATUS_NOT_ALLOWED_MSG
            )
        );
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
    }

    @IsTest
    static void testGetCSCaseStatus_MissingCaseRequestInfo() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req =
            new FEC_GetCSCaseStatusService.GetCSCaseStatusRequest();
        req.Sys = new FEC_GetCSCaseStatusService.SysType();
        req.Sys.Channel = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;
        req.Sys.TransactionID = 'TXN-MISSING-INFO';

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(2, res.Sys.Code);
    }

    @IsTest
    static void testGetCSCaseStatus_TransactionIdTooLong() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = buildMinimalRequest();
        req.Sys.TransactionID = 'TXN'.repeat(13);

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(2, res.Sys.Code);
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
    }

    @IsTest
    static void testGetCSCaseStatus_FiltersComplaintCaseWithoutFeedbackCategory() {
        Id customerCaseRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME)
            .getRecordTypeId();
        FEC_Business_Process__c complaintProcess = new FEC_Business_Process__c(
            Name = FEC_ConstantCommon.BP_COMPLAINT,
            FEC_Code__c = 'ComplaintFilter',
            FEC_Active__c = true
        );
        FEC_Category__c requestCategory = new FEC_Category__c(
            Name = FEC_ConstantCommon.FEC_CATEGORY_REQUEST,
            FEC_Code__c = 'RequestFilter',
            FEC_Active__c = true
        );
        insert new List<SObject>{ complaintProcess, requestCategory };

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                RecordTypeId = customerCaseRtId,
                Subject = 'Filtered Complaint Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_ID_Search__c = 'CASE-FILTER',
                FEC_Business_Process__c = complaintProcess.Id,
                FEC_Category__c = requestCategory.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req =
            new FEC_GetCSCaseStatusService.GetCSCaseStatusRequest();
        req.Sys = new FEC_GetCSCaseStatusService.SysType();
        req.Sys.TransactionID = 'TXN-FILTER';
        req.Sys.Channel = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;
        req.CaseRequestInfo = new FEC_GetCSCaseStatusService.CaseRequestInfoType();
        req.CaseRequestInfo.CaseID = 'CASE-FILTER';
        req.CaseRequestInfo.UserType = FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE;
        req.CaseRequestInfo.IncludeFinishedRequest = true;
        req.CaseRequestInfo.ContractOrAccountInfos =
            new FEC_GetCSCaseStatusService.ContractOrAccountInfosType();
        req.CaseRequestInfo.ContractOrAccountInfos.ContractOrAccountNumber = 'ANY';
        req.CaseRequestInfo.ContractOrAccountInfos.ProductType = 'ANY';

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(1, res.Sys.Code);
        System.assertEquals(0, res.TotalCases);
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
    }

    @IsTest
    static void testGetCSCaseStatus_FilterByPhoneNumber() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = buildMinimalRequest();
        req.CaseRequestInfo.NationalID = null;
        req.CaseRequestInfo.PhoneNumber = '0901234567';

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(1, res.Sys.Code);
        System.assertEquals(1, res.TotalCases);
    }

    @IsTest
    static void testGetCSCaseStatus_MissingChannel() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = buildMinimalRequest();
        req.Sys.Channel = null;

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(2, res.Sys.Code);
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
    }

    @IsTest
    static void testGetCSCaseStatus_MissingUserType() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = buildMinimalRequest();
        req.CaseRequestInfo.UserType = null;

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(2, res.Sys.Code);
    }

    @IsTest
    static void testGetCSCaseStatus_MissingProductType() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = buildMinimalRequest();
        req.CaseRequestInfo.ContractOrAccountInfos.ProductType = null;

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(2, res.Sys.Code);
    }

    @IsTest
    static void testGetCSCaseStatus_MissingContractOrAccountInfos() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = buildMinimalRequest();
        req.CaseRequestInfo.ContractOrAccountInfos = null;

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(2, res.Sys.Code);
    }
}