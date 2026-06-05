@IsTest
private class FEC_GetCSCaseStatusService_Test {

    private static final String TEST_ACCOUNT_NUMBER = 'ACC123';

    private static final String TEST_CHANNEL_ID = 'InboundUTGetCaseStatus';

    @TestSetup
    static void setupData() {
        insert new FEC_Channel__c(
            Name = 'Inbound UT Get Case Status',
            FEC_Code__c = 'INBOUNDUTGCS',
            FEC_Channel_ID__c = TEST_CHANNEL_ID,
            FEC_Channel_Vietnamese_name__c = 'Inbound UT',
            FEC_Channel_Status__c = true,
            FEC_Update_Case_Status__c = true
        );

        FEC_Business_Process__c proc = new FEC_Business_Process__c(
            Name = 'Fraud Process',
            FEC_Code__c = 'FRAUDPROC',
            FEC_Active__c = true
        );
        insert proc;

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
                Status = 'New',
                FEC_ID_Search__c = 'CASE123',
                FEC_Customer_Name__c = 'Test Customer',
                FEC_Customer_Type__c = FEC_ConstantCommon.CASE_EXISTING_CUSTOMER,
                FEC_Business_Process__c = proc.Id,
                FEC_Product_Type__c = productType.Id
            );
            insert testCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c history = new FEC_Customer_History__c(
            Name = TEST_ACCOUNT_NUMBER,
            FEC_Case__c = testCase.Id,
            FEC_Account_Number__c = TEST_ACCOUNT_NUMBER,
            FEC_National_ID_Passport_ID__c = '123456789012'
        );
        insert history;
        FEC_CommonUltils.resetActiveChannelCacheForTest();

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
        req.Sys.Channel = TEST_CHANNEL_ID;

        req.CaseRequestInfo = new FEC_GetCSCaseStatusService.CaseRequestInfoType();
        req.CaseRequestInfo.CaseID = 'CASE123';
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
        System.assertNotEquals(
            null,
            res.CaseResultInfos[0].CaseStatus,
            'CaseStatus label should be populated from FEC_Case_Status__c mapping.'
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
        req.Sys.Channel = TEST_CHANNEL_ID;
        req.CaseRequestInfo = new FEC_GetCSCaseStatusService.CaseRequestInfoType();
        req.CaseRequestInfo.CaseID = 'CASE123';
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
}
