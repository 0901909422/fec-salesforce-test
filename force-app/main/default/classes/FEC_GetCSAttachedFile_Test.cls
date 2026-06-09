@IsTest
private class FEC_GetCSAttachedFile_Test {

    @TestSetup
    static void setupData() {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                Subject = 'CS Attached File Test',
                Status = 'New',
                FEC_ID_Search__c = ('CSA' + String.valueOf(System.now().getTime())).substring(0, 15),
                FEC_Customer_Type__c = FEC_ConstantCommon.CASE_EXISTING_CUSTOMER,
                FEC_Contract_Number__c = 'CTR123'
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        ContentVersion cv = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'test.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;

        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        Case c = [SELECT Id FROM Case LIMIT 1];

        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = c.Id,
            ShareType = 'V'
        );
    }

    @IsTest
    static void testGetCSAttachedFile_Success() {
        Case c = [SELECT Id, FEC_ID_Search__c FROM Case LIMIT 1];
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;

        FEC_GetCSAttachedFile.SysType sys = new FEC_GetCSAttachedFile.SysType();
        sys.Channel = FEC_ConstantCommon.CANCEL_CS_VALID_CHANNELS_ORDERED[0];

        FEC_GetCSAttachedFile.RequestInfoType req = new FEC_GetCSAttachedFile.RequestInfoType();
        req.CaseID = c.FEC_ID_Search__c;
        req.UserType = FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE;
        req.FileID = String.valueOf(docId);
        req.ContractOrAccountInfos = new FEC_GetCSAttachedFile.ContractOrAccountInfoType();
        req.ContractOrAccountInfos.ContractOrAccountNumber = 'CTR123';
        req.ContractOrAccountInfos.ProductType = 'CreditCard';

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(sys, req);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_SUCCESS, res.Sys.Code);
        System.assertEquals('TestFile', res.FileName);
        System.assertNotEquals(null, res.FileContent);
    }

    @IsTest
    static void testValidateInput_MissingParams() {
        FEC_GetCSAttachedFile.SysType sys = new FEC_GetCSAttachedFile.SysType();
        sys.Channel = 'INVALID_CHANNEL';

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(sys, null);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_SYS_ERROR, res.Sys.Code);
    }

    private static FEC_GetCSAttachedFile.RequestInfoType buildValidRequest(Case c, String fileId) {
        FEC_GetCSAttachedFile.RequestInfoType req = new FEC_GetCSAttachedFile.RequestInfoType();
        req.CaseID = c.FEC_ID_Search__c;
        req.UserType = FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE;
        req.FileID = fileId;
        req.ContractOrAccountInfos = new FEC_GetCSAttachedFile.ContractOrAccountInfoType();
        req.ContractOrAccountInfos.ContractOrAccountNumber = 'CTR123';
        req.ContractOrAccountInfos.ProductType = 'CreditCard';
        return req;
    }

    @IsTest
    static void testValidateInput_CaseNotFound() {
        FEC_GetCSAttachedFile.SysType sys = new FEC_GetCSAttachedFile.SysType();
        sys.Channel = FEC_ConstantCommon.CANCEL_CS_VALID_CHANNELS_ORDERED[0];
        FEC_GetCSAttachedFile.RequestInfoType req = buildValidRequest(
            new Case(FEC_ID_Search__c = 'NOT-FOUND-01'),
            '015000000000000AAA'
        );

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(sys, req);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_SYS_ERROR, res.Sys.Code);
    }

    @IsTest
    static void testValidateInput_ContractMismatch() {
        Case c = [SELECT Id, FEC_ID_Search__c FROM Case LIMIT 1];
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;
        FEC_GetCSAttachedFile.SysType sys = new FEC_GetCSAttachedFile.SysType();
        sys.Channel = FEC_ConstantCommon.CANCEL_CS_VALID_CHANNELS_ORDERED[0];
        FEC_GetCSAttachedFile.RequestInfoType req = buildValidRequest(c, String.valueOf(docId));
        req.ContractOrAccountInfos.ContractOrAccountNumber = 'WRONG-NUMBER';

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(sys, req);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_SYS_ERROR, res.Sys.Code);
    }

    @IsTest
    static void testValidateInput_InvalidFileId() {
        Case c = [SELECT Id, FEC_ID_Search__c FROM Case LIMIT 1];
        FEC_GetCSAttachedFile.SysType sys = new FEC_GetCSAttachedFile.SysType();
        sys.Channel = FEC_ConstantCommon.CANCEL_CS_VALID_CHANNELS_ORDERED[0];
        FEC_GetCSAttachedFile.RequestInfoType req = buildValidRequest(c, 'not-a-valid-id');

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(sys, req);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_SYS_ERROR, res.Sys.Code);
    }

    @IsTest
    static void testValidateInput_FileNotLinkedToCase() {
        Case c = [SELECT Id, FEC_ID_Search__c FROM Case LIMIT 1];
        ContentVersion otherCv = new ContentVersion(
            Title = 'Unlinked',
            PathOnClient = 'other.pdf',
            VersionData = Blob.valueOf('Other'),
            IsMajorVersion = true
        );
        insert otherCv;
        Id otherDocId = [
            SELECT ContentDocumentId FROM ContentVersion WHERE Id = :otherCv.Id
        ].ContentDocumentId;

        FEC_GetCSAttachedFile.SysType sys = new FEC_GetCSAttachedFile.SysType();
        sys.Channel = FEC_ConstantCommon.CANCEL_CS_VALID_CHANNELS_ORDERED[0];
        FEC_GetCSAttachedFile.RequestInfoType req = buildValidRequest(
            c,
            String.valueOf(otherDocId)
        );

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(sys, req);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_SYS_ERROR, res.Sys.Code);
    }

    @IsTest
    static void testValidateInput_InvalidUserType() {
        Case c = [SELECT Id, FEC_ID_Search__c FROM Case LIMIT 1];
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;
        FEC_GetCSAttachedFile.SysType sys = new FEC_GetCSAttachedFile.SysType();
        sys.Channel = FEC_ConstantCommon.CANCEL_CS_VALID_CHANNELS_ORDERED[0];
        FEC_GetCSAttachedFile.RequestInfoType req = buildValidRequest(c, String.valueOf(docId));
        req.UserType = 'INVALID';

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(sys, req);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_SYS_ERROR, res.Sys.Code);
    }

    @IsTest
    static void testGetCSAttachedFile_NullSysDefaults() {
        Case c = [SELECT Id, FEC_ID_Search__c FROM Case LIMIT 1];
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(
                null,
                buildValidRequest(c, String.valueOf(docId))
            );
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_SYS_ERROR, res.Sys.Code);
        System.assertNotEquals(null, res.Sys.TransactionID);
    }

    @IsTest
    static void testValidateInput_CustomerTypeMismatch() {
        Case c = [SELECT Id, FEC_ID_Search__c FROM Case LIMIT 1];
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;
        FEC_GetCSAttachedFile.SysType sys = new FEC_GetCSAttachedFile.SysType();
        sys.Channel = FEC_ConstantCommon.CANCEL_CS_VALID_CHANNELS_ORDERED[0];
        FEC_GetCSAttachedFile.RequestInfoType req = buildValidRequest(c, String.valueOf(docId));
        req.UserType = FEC_ConstantCommon.REQUEST_NON_EXISTING_USER_TYPE;

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(sys, req);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_SYS_ERROR, res.Sys.Code);
    }

    @IsTest
    static void testValidateInput_MissingCaseId() {
        Case c = [SELECT Id, FEC_ID_Search__c FROM Case LIMIT 1];
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;
        FEC_GetCSAttachedFile.SysType sys = new FEC_GetCSAttachedFile.SysType();
        sys.Channel = FEC_ConstantCommon.CANCEL_CS_VALID_CHANNELS_ORDERED[0];
        FEC_GetCSAttachedFile.RequestInfoType req = buildValidRequest(c, String.valueOf(docId));
        req.CaseID = null;

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(sys, req);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_SYS_ERROR, res.Sys.Code);
    }

    @IsTest
    static void testValidateInput_MissingFileId() {
        Case c = [SELECT Id, FEC_ID_Search__c FROM Case LIMIT 1];
        FEC_GetCSAttachedFile.SysType sys = new FEC_GetCSAttachedFile.SysType();
        sys.Channel = FEC_ConstantCommon.CANCEL_CS_VALID_CHANNELS_ORDERED[0];
        FEC_GetCSAttachedFile.RequestInfoType req = buildValidRequest(c, null);
        req.FileID = null;

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(sys, req);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_SYS_ERROR, res.Sys.Code);
    }

    @IsTest
    static void testValidateInput_TransactionIdTooLong() {
        Case c = [SELECT Id, FEC_ID_Search__c FROM Case LIMIT 1];
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;
        FEC_GetCSAttachedFile.SysType sys = new FEC_GetCSAttachedFile.SysType();
        sys.Channel = FEC_ConstantCommon.CANCEL_CS_VALID_CHANNELS_ORDERED[0];
        sys.TransactionID = 'X'.repeat(
            FEC_ConstantCommon.CANCEL_CS_TRANSACTION_ID_MAX_LEN + 1
        );
        FEC_GetCSAttachedFile.RequestInfoType req = buildValidRequest(c, String.valueOf(docId));

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(sys, req);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_SYS_ERROR, res.Sys.Code);
    }

    @IsTest
    static void testGetCSAttachedFile_WithAccountNumber() {
        Case c = [SELECT Id, FEC_ID_Search__c FROM Case LIMIT 1];
        c.FEC_Contract_Number__c = null;
        c.FEC_Account_Number__c = 'ACC123';
        update c;

        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;
        FEC_GetCSAttachedFile.SysType sys = new FEC_GetCSAttachedFile.SysType();
        sys.Channel = FEC_ConstantCommon.CANCEL_CS_VALID_CHANNELS_ORDERED[0];
        FEC_GetCSAttachedFile.RequestInfoType req = buildValidRequest(c, String.valueOf(docId));
        req.ContractOrAccountInfos.ContractOrAccountNumber = 'ACC123';

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(sys, req);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_SUCCESS, res.Sys.Code);
        System.assertNotEquals(null, res.FileContent);
    }
}