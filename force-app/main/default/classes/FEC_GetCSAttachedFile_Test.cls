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

    private static FEC_GetCSAttachedFile.SysType buildValidSys() {
        FEC_GetCSAttachedFile.SysType sys = new FEC_GetCSAttachedFile.SysType();
        sys.Channel = FEC_ConstantCommon.CANCEL_CS_VALID_CHANNELS_ORDERED[0];
        return sys;
    }

    private static FEC_GetCSAttachedFile.RequestInfoType buildValidRequest(Case c, String fileId, String contractNumber) {
        FEC_GetCSAttachedFile.RequestInfoType req = new FEC_GetCSAttachedFile.RequestInfoType();
        req.CaseID = c.FEC_ID_Search__c;
        req.UserType = FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE;
        req.FileID = fileId;
        req.ContractOrAccountInfos = new FEC_GetCSAttachedFile.ContractOrAccountInfoType();
        req.ContractOrAccountInfos.ContractOrAccountNumber = contractNumber;
        req.ContractOrAccountInfos.ProductType = 'CreditCard';
        return req;
    }

    @IsTest
    static void testGetCSAttachedFile_Success() {
        Case c = [SELECT Id, FEC_ID_Search__c FROM Case LIMIT 1];
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(
                buildValidSys(),
                buildValidRequest(c, String.valueOf(docId), 'CTR123')
            );
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

    @IsTest
    static void testGetCSAttachedFile_InvalidChannel() {
        Case c = [SELECT Id, FEC_ID_Search__c FROM Case LIMIT 1];
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;

        FEC_GetCSAttachedFile.SysType sys = buildValidSys();
        sys.Channel = 'INVALID_CHANNEL';

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(
                sys,
                buildValidRequest(c, String.valueOf(docId), 'CTR123')
            );
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_SYS_ERROR, res.Sys.Code);
        System.assert(res.Sys.Description.contains(FEC_ConstantCommon.ERROR_PREFIX));
    }

    @IsTest
    static void testGetCSAttachedFile_CaseNotFound() {
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;
        Case c = [SELECT Id, FEC_ID_Search__c FROM Case LIMIT 1];

        FEC_GetCSAttachedFile.RequestInfoType req = buildValidRequest(c, String.valueOf(docId), 'CTR123');
        req.CaseID = 'CASE-NOT-FOUND-99';

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(buildValidSys(), req);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_SYS_ERROR, res.Sys.Code);
    }

    @IsTest
    static void testGetCSAttachedFile_WrongContract() {
        Case c = [SELECT Id, FEC_ID_Search__c FROM Case LIMIT 1];
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(
                buildValidSys(),
                buildValidRequest(c, String.valueOf(docId), 'WRONG999')
            );
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_SYS_ERROR, res.Sys.Code);
        System.assert(
            res.Sys.Description.contains(System.Label.FEC_MSG_Contract_Or_Account_Info_Case_Mismatch)
        );
    }

    @IsTest
    static void testGetCSAttachedFile_MissingFile() {
        Case c = [SELECT Id, FEC_ID_Search__c FROM Case LIMIT 1];

        ContentVersion orphanCv = new ContentVersion(
            Title = 'OrphanFile',
            PathOnClient = 'orphan.pdf',
            VersionData = Blob.valueOf('Orphan'),
            IsMajorVersion = true
        );
        insert orphanCv;
        Id orphanDocId = [
            SELECT ContentDocumentId FROM ContentVersion WHERE Id = :orphanCv.Id
        ].ContentDocumentId;

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(
                buildValidSys(),
                buildValidRequest(c, String.valueOf(orphanDocId), 'CTR123')
            );
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_SYS_ERROR, res.Sys.Code);
        System.assert(
            res.Sys.Description.contains(System.Label.FEC_MSG_GetCSAttached_File_Not_Linked_To_Case)
        );
    }

    @IsTest
    static void testGetCSAttachedFile_BlankChannel() {
        Case c = [SELECT Id, FEC_ID_Search__c FROM Case LIMIT 1];
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;

        FEC_GetCSAttachedFile.SysType sys = new FEC_GetCSAttachedFile.SysType();

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(
                sys,
                buildValidRequest(c, String.valueOf(docId), 'CTR123')
            );
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_SYS_ERROR, res.Sys.Code);
    }

    @IsTest
    static void testGetCSAttachedFile_NonExistingUserType() {
        Case c = [SELECT Id, FEC_ID_Search__c FROM Case LIMIT 1];
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;

        FEC_GetCSAttachedFile.RequestInfoType req = buildValidRequest(c, String.valueOf(docId), 'CTR123');
        req.UserType = FEC_ConstantCommon.REQUEST_NON_EXISTING_USER_TYPE;

        Test.startTest();
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType res =
            FEC_GetCSAttachedFile.GetCSAttachedFileRequest(buildValidSys(), req);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_SYS_ERROR, res.Sys.Code);
        System.assert(
            res.Sys.Description.contains(System.Label.FEC_MSG_Case_Customer_Type_Mismatch)
        );
    }
}
