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
}