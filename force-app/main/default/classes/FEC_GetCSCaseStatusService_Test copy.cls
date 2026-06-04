@IsTest
private class FEC_GetCSCaseStatusService_Test {

    @TestSetup
    static void setupData() {
        FEC_Business_Process__c proc = new FEC_Business_Process__c(
            Name = 'Fraud Process',
            FEC_Code__c = 'FRAUDPROC',
            FEC_Active__c = true
        );
        insert proc;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                Subject = 'CS Case Status Test',
                Status = 'New',
                FEC_ID_Search__c = 'CASE123',
                FEC_Customer_Name__c = 'Test Customer',
                FEC_Business_Process__c = proc.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testGetCSCaseStatus_Success() {
        // Chuẩn bị Request
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = new FEC_GetCSCaseStatusService.GetCSCaseStatusRequest();
        
        req.Sys = new FEC_GetCSCaseStatusService.SysType();
        req.Sys.TransactionID = 'TXN001';
        req.Sys.DateTime_x = '2026-05-22T10:00:00Z';
        // Sử dụng channel hợp lệ theo channelSet trong class
        req.Sys.Channel = FEC_ConstantCommon.CHANNEL_INBOUND_NAME; 

        req.CaseRequestInfo = new FEC_GetCSCaseStatusService.CaseRequestInfoType();
        req.CaseRequestInfo.CaseID = 'CASE123';
        req.CaseRequestInfo.NationalID = '123456789';
        req.CaseRequestInfo.PhoneNumber = '0901234567';
        req.CaseRequestInfo.UserType = FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE;
        req.CaseRequestInfo.IncludeFinishedRequest = true;

        req.CaseRequestInfo.ContractOrAccountInfos = new FEC_GetCSCaseStatusService.ContractOrAccountInfosType();
        req.CaseRequestInfo.ContractOrAccountInfos.ContractOrAccountNumber = 'ACC123';
        req.CaseRequestInfo.ContractOrAccountInfos.ProductType = 'CreditCard';

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res = FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        // Xác thực kết quả
        Case c = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'CASE123' LIMIT 1];

        System.assertEquals(1, res.Sys.Code, 'API nên trả về code 1 (Success).');
        System.assertEquals(c.Id, res.CaseResultInfo.CaseID, 'CaseID phải là Id Case tìm được.');
    }

    @IsTest
    static void testGetCSCaseStatus_InvalidChannel() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = new FEC_GetCSCaseStatusService.GetCSCaseStatusRequest();
        req.Sys = new FEC_GetCSCaseStatusService.SysType();
        req.Sys.Channel = 'INVALID_CHANNEL'; // Kích hoạt lỗi validation

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res = FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(2, res.Sys.Code, 'API phải báo lỗi khi channel không hợp lệ.');
    }
}