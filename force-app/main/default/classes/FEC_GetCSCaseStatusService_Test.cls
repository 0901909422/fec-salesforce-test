@IsTest
private class FEC_GetCSCaseStatusService_Test {

    private static Id customerCaseRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        if (byDev.containsKey(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME)) {
            return byDev.get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME).getRecordTypeId();
        }
        return null;
    }

    @TestSetup
    static void setupData() {
        insert new FEC_Channel__c(
            Name = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
            FEC_Code__c = 'INBOUND',
            FEC_Channel_ID__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
            FEC_Channel_Vietnamese_name__c = 'Inbound',
            FEC_Channel_Status__c = true
        );

        FEC_Business_Process__c proc = new FEC_Business_Process__c(
            Name = 'Fraud Process',
            FEC_Code__c = 'FRAUDPROC',
            FEC_Active__c = true
        );
        insert proc;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Case statusCase = new Case(
                Subject = 'CS Case Status Test',
                Status = 'New',
                FEC_ID_Search__c = 'CASE123',
                FEC_Customer_Name__c = 'Test Customer',
                FEC_Business_Process__c = proc.Id
            );
            Id rtId = customerCaseRecordTypeId();
            if (rtId != null) {
                statusCase.RecordTypeId = rtId;
            }
            insert statusCase;

            FEC_Customer_History__c accountHist = new FEC_Customer_History__c(
                Name = 'ACC123',
                FEC_Case__c = statusCase.Id,
                FEC_Account_Number__c = 'ACC123'
            );
            insert accountHist;

            statusCase.FEC_Account_or_Contract__c = accountHist.Id;
            update statusCase;
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
        req.CaseRequestInfo.UserType = FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE;
        req.CaseRequestInfo.IncludeFinishedRequest = true;

        req.CaseRequestInfo.ContractOrAccountInfos = new FEC_GetCSCaseStatusService.ContractOrAccountInfosType();
        req.CaseRequestInfo.ContractOrAccountInfos.ContractOrAccountNumber = 'ACC123';
        req.CaseRequestInfo.ContractOrAccountInfos.ProductType = 'CreditCard';

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res = FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(1, res.Sys.Code, 'API nên trả về code 1 (Success).');
        System.assertNotEquals(null, res.CaseResultInfos, 'CaseResultInfos phải được trả về.');
        System.assertEquals(1, res.CaseResultInfos.size(), 'Phải có đúng 1 case trong kết quả.');
        System.assertEquals('CASE123', res.CaseResultInfos[0].CaseID, 'CaseID phải là FEC_ID_Search__c.');
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