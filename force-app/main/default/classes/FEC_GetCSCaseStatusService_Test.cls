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

    private static FEC_GetCSCaseStatusService.GetCSCaseStatusRequest buildBaseRequest() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req =
            new FEC_GetCSCaseStatusService.GetCSCaseStatusRequest();
        req.Sys = new FEC_GetCSCaseStatusService.SysType();
        req.Sys.TransactionID = 'TXN001';
        req.Sys.DateTime_x = '2026-05-22T10:00:00Z';
        req.Sys.Channel = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;
        req.CaseRequestInfo = new FEC_GetCSCaseStatusService.CaseRequestInfoType();
        req.CaseRequestInfo.CaseID = 'CASE123';
        req.CaseRequestInfo.UserType = FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE;
        req.CaseRequestInfo.IncludeFinishedRequest = true;
        req.CaseRequestInfo.ContractOrAccountInfos =
            new FEC_GetCSCaseStatusService.ContractOrAccountInfosType();
        req.CaseRequestInfo.ContractOrAccountInfos.ContractOrAccountNumber = 'ACC123';
        req.CaseRequestInfo.ContractOrAccountInfos.ProductType = 'CreditCard';
        return req;
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

        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = 'CC',
            FEC_Name_VN__c = 'The Tin Dung',
            FEC_Active__c = true
        );
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Request',
            FEC_Code__c = 'Request',
            FEC_Name_VN__c = 'Yeu Cau',
            FEC_Active__c = true
        );
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'RC27',
            FEC_Code__c = 'RC27',
            FEC_Name_VN__c = 'RC27 VN',
            FEC_Active__c = true
        );
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'RC27.01',
            FEC_Code__c = 'RC27.01',
            FEC_Name_VN__c = 'RC27.01 VN',
            FEC_Active__c = true
        );
        insert new List<SObject>{ pt, cat, subCat, subCode };

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
                FEC_Business_Process__c = proc.Id,
                FEC_Product_Type__c = pt.Id,
                FEC_Category__c = cat.Id,
                FEC_SubCategory__c = subCat.Id,
                FEC_SubCode__c = subCode.Id,
                FEC_Remarks__c = 'Status remark'
            );
            Id rtId = customerCaseRecordTypeId();
            if (rtId != null) {
                statusCase.RecordTypeId = rtId;
            }
            insert statusCase;

            FEC_Customer_History__c accountHist = new FEC_Customer_History__c(
                Name = 'ACC123',
                FEC_Case__c = statusCase.Id,
                FEC_Account_Number__c = 'ACC123',
                FEC_Email__c = 'customer@example.com',
                FEC_Primary_Phone__c = '0901234567',
                FEC_National_ID_Passport_ID__c = '123456789'
            );
            insert accountHist;

            statusCase.FEC_Account_or_Contract__c = accountHist.Id;
            update statusCase;

            if (Schema.sObjectType.FEC_Additional_Info__c.isCreateable()) {
                FEC_Additional_Info__c addInfo = new FEC_Additional_Info__c(
                    FEC_Case__c = statusCase.Id
                );
                Map<String, Schema.SObjectField> fieldMap =
                    FEC_Additional_Info__c.SObjectType.getDescribe().fields.getMap();
                for (String fieldName : fieldMap.keySet()) {
                    if (
                        fieldName.endsWith('__c') &&
                        fieldName != 'FEC_Case__c' &&
                        fieldMap.get(fieldName).getDescribe().getType() == Schema.DisplayType.STRING
                    ) {
                        addInfo.put(fieldName, 'value-' + fieldName);
                        break;
                    }
                }
                insert addInfo;
            }
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testGetCSCaseStatus_SuccessWithFullPayload() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = buildBaseRequest();

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(1, res.Sys.Code);
        System.assertEquals(1, res.CaseResultInfos.size());
        FEC_GetCSCaseStatusService.CaseResultInfoType row = res.CaseResultInfos[0];
        System.assertEquals('CASE123', row.CaseID);
        System.assertNotEquals(null, row.OriginalRequest);
        System.assertEquals('Test Customer', row.OriginalRequest.CustomerInfo.Name);
        System.assertEquals(
            'customer@example.com',
            row.OriginalRequest.CustomerInfo.EmailAddress
        );
        System.assertEquals('Fraud Process', row.OriginalRequest.RequestInfo.CaseType);
        System.assertEquals('The Tin Dung', row.OriginalRequest.RequestInfo.ProductType);
        System.assertEquals('Yeu Cau', row.OriginalRequest.RequestInfo.Category);
    }

    @IsTest
    static void testGetCSCaseStatus_InvalidChannel() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = buildBaseRequest();
        req.Sys.Channel = 'UNKNOWN_CHANNEL_X';

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(2, res.Sys.Code);
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
    static void testGetCSCaseStatus_NoCaseFound() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = buildBaseRequest();
        req.CaseRequestInfo.CaseID = 'NOT_EXIST';
        req.CaseRequestInfo.ContractOrAccountInfos.ContractOrAccountNumber = 'NO_ACC';

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(2, res.Sys.Code);
        System.assert(res.Sys.Description.contains('No Customer_Case found'));
    }

    @IsTest
    static void testGetCSCaseStatus_SearchByPhoneAndNationalId() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = buildBaseRequest();
        req.CaseRequestInfo.CaseID = null;
        req.CaseRequestInfo.PhoneNumber = '0901234567';
        req.CaseRequestInfo.NationalID = '123456789';

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(1, res.Sys.Code);
        System.assertEquals(1, res.CaseResultInfos.size());
    }

    @IsTest
    static void testGetCSCaseStatus_MissingCaseRequestInfo() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest req = buildBaseRequest();
        req.CaseRequestInfo = null;

        Test.startTest();
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse res =
            FEC_GetCSCaseStatusService.GetCSCaseStatus(req);
        Test.stopTest();

        System.assertEquals(2, res.Sys.Code);
    }
}
