/**
 * Unit tests for FEC_TransferCallNocService (persist NOC before Transfer Call).
 */
@IsTest
private class FEC_TransferCallNocService_Test {

    private static User adminUser() {
        return [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = TRUE
            LIMIT 1
        ];
    }

    private static void ensureApiSettings() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        apiSetting.FEC_Endpoint__c = 'https://mock-api.fecredit.com.vn';
        apiSetting.FEC_Call_Mock__c = false;
        apiSetting.FEC_Enviroment__c = 'Production';
        upsert apiSetting;
    }

    @TestSetup
    static void setupData() {
        ensureApiSettings();

        String suffix = String.valueOf(System.currentTimeMillis()).right(6);
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Card',
            FEC_Code__c = 'PT' + suffix,
            FEC_Active__c = true
        );
        insert pt;

        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Request',
            FEC_Code__c = 'CA' + suffix,
            FEC_Active__c = true
        );
        insert cat;

        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'RC01',
            FEC_Code__c = 'SC' + suffix,
            FEC_Active__c = true
        );
        insert subCat;

        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'RC01.01',
            FEC_Code__c = 'SX' + suffix,
            FEC_Active__c = true
        );
        insert subCode;

        FEC_Nature_of_Case__c templateNoc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Active__c = true
        );
        insert templateNoc;

        FEC_Nature_of_Case__c nocWithoutSubCode = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Active__c = true
        );
        insert nocWithoutSubCode;

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'Transfer NOC Stage',
            FEC_Code__c = 'STG' + suffix,
            FEC_Nature_of_Cases__c = templateNoc.Id,
            FEC_Active__c = true
        );
        insert stage;

        User admin = adminUser();
        Case persistCase = new Case(
            OwnerId = admin.Id,
            Subject = 'NOC Persist Case',
            FEC_Is_Submited__c = false,
            FEC_External_Interaction_ID__c = 'GEN-NOC-001',
            FEC_ID_Search__c = 'NOC' + suffix,
            FEC_Phone_Number__c = '0901234567',
            FEC_Remark_for_Collections__c = 'Transfer remark',
            FEC_Current_Case_Stage__c = stage.Id
        );
        Case skipPersistCase = new Case(
            OwnerId = admin.Id,
            Subject = 'NOC Skip Persist Case',
            FEC_Is_Submited__c = false,
            FEC_External_Interaction_ID__c = 'GEN-NOC-002',
            FEC_ID_Search__c = 'NOS' + suffix,
            FEC_Phone_Number__c = '0907654321',
            FEC_Remark_for_Collections__c = 'Already has NOC',
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_SubCategory__c = subCat.Id,
            FEC_SubCode__c = subCode.Id,
            FEC_Current_Case_Stage__c = stage.Id
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new List<Case>{ persistCase, skipPersistCase };
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new List<FEC_Customer_History__c>{
            new FEC_Customer_History__c(
                FEC_Case__c = persistCase.Id,
                FEC_Contract_Number__c = 'APP123456'
            ),
            new FEC_Customer_History__c(
                FEC_Case__c = skipPersistCase.Id,
                FEC_Contract_Number__c = 'APP789012'
            )
        };

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new List<Case>{
                new Case(
                    Id = persistCase.Id,
                    FEC_Account_or_Contract__c = [
                        SELECT Id
                        FROM FEC_Customer_History__c
                        WHERE FEC_Case__c = :persistCase.Id
                        LIMIT 1
                    ]
                    .Id
                ),
                new Case(
                    Id = skipPersistCase.Id,
                    FEC_Account_or_Contract__c = [
                        SELECT Id
                        FROM FEC_Customer_History__c
                        WHERE FEC_Case__c = :skipPersistCase.Id
                        LIMIT 1
                    ]
                    .Id
                )
            };
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static Case persistCase() {
        return [SELECT Id FROM Case WHERE Subject = 'NOC Persist Case' LIMIT 1];
    }

    private static Case skipPersistCase() {
        return [SELECT Id FROM Case WHERE Subject = 'NOC Skip Persist Case' LIMIT 1];
    }

    private static FEC_Nature_of_Case__c templateNoc() {
        return [
            SELECT Id, FEC_Product_Type__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Sub_Code__c != NULL
            LIMIT 1
        ];
    }

    private static FEC_Nature_of_Case__c nocWithoutSubCode() {
        return [
            SELECT Id, FEC_Product_Type__c, FEC_Category__c, FEC_Sub_Category__c
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Sub_Code__c = NULL
            LIMIT 1
        ];
    }

    private class TransferSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"Code": "1", "ResultOfClass": "Success", "Reason": "OK", ' +
                '"TransID": "NOC-TXN-1", "ActionDate": "2026-04-21T08:13:36.000Z"}'
            );
            return res;
        }
    }

    @IsTest
    static void testPersistBeforeTransfer_NullCaseId_DoesNothing() {
        Test.startTest();
        FEC_TransferCallNocService.persistBeforeTransfer(
            null,
            'any',
            null,
            null,
            null,
            null
        );
        Test.stopTest();
        System.assert(true, 'Null case id should return without error.');
    }

    @IsTest
    static void testPersistBeforeTransfer_SkipsWhenCategoryAlreadySet() {
        Case c = skipPersistCase();
        Id catBefore = [
            SELECT FEC_Category__c
            FROM Case
            WHERE Id = :c.Id
        ]
        .FEC_Category__c;

        FEC_Nature_of_Case__c noc = templateNoc();
        System.runAs(adminUser()) {
            Test.startTest();
            FEC_TransferCallNocService.persistBeforeTransfer(
                c.Id,
                noc.Id,
                noc.FEC_Product_Type__c,
                noc.FEC_Category__c,
                noc.FEC_Sub_Category__c,
                noc.FEC_Sub_Code__c
            );
            Test.stopTest();

            System.assertEquals(
                catBefore,
                [SELECT FEC_Category__c FROM Case WHERE Id = :c.Id].FEC_Category__c
            );
        }
    }

    @IsTest
    static void testPersistBeforeTransfer_SaveCaseNocByNatureId() {
        Case c = persistCase();
        FEC_Nature_of_Case__c noc = templateNoc();

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_TransferCallNocService.persistBeforeTransfer(
                c.Id,
                noc.Id,
                null,
                null,
                null,
                null
            );
            Test.stopTest();

            Case updated = [
                SELECT FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c
                FROM Case
                WHERE Id = :c.Id
            ];
            System.assertEquals(noc.FEC_Category__c, updated.FEC_Category__c);
            System.assertEquals(noc.FEC_Sub_Category__c, updated.FEC_SubCategory__c);
            System.assertEquals(noc.FEC_Sub_Code__c, updated.FEC_SubCode__c);
        }
    }

    @IsTest
    static void testResolveNatureOfCaseId_WithSubCode() {
        FEC_Nature_of_Case__c noc = templateNoc();

        Test.startTest();
        String resolved = FEC_TransferCallNocService.resolveNatureOfCaseId(
            noc.FEC_Product_Type__c,
            noc.FEC_Category__c,
            noc.FEC_Sub_Category__c,
            noc.FEC_Sub_Code__c
        );
        Test.stopTest();

        System.assertEquals(noc.Id, resolved);
    }

    @IsTest
    static void testResolveNatureOfCaseId_WithoutSubCode() {
        FEC_Nature_of_Case__c noc = nocWithoutSubCode();

        Test.startTest();
        String resolved = FEC_TransferCallNocService.resolveNatureOfCaseId(
            noc.FEC_Product_Type__c,
            noc.FEC_Category__c,
            noc.FEC_Sub_Category__c,
            null
        );
        Test.stopTest();

        System.assertEquals(noc.Id, resolved);
    }

    @IsTest
    static void testResolveNatureOfCaseId_ReturnsNullWhenIncomplete() {
        FEC_Nature_of_Case__c noc = templateNoc();

        Test.startTest();
        String resolved = FEC_TransferCallNocService.resolveNatureOfCaseId(
            noc.FEC_Product_Type__c,
            null,
            noc.FEC_Sub_Category__c,
            noc.FEC_Sub_Code__c
        );
        Test.stopTest();

        System.assertEquals(null, resolved);
    }

    @IsTest
    static void testPersistBeforeTransfer_UpdatesCaseDirectlyWhenNoNocMatch() {
        Case c = persistCase();
        FEC_Nature_of_Case__c noc = templateNoc();
        FEC_Sub_Code__c orphanSubCode = new FEC_Sub_Code__c(
            Name = 'Orphan SubCode',
            FEC_Code__c = 'ORP' + String.valueOf(System.currentTimeMillis()).right(4),
            FEC_Active__c = true
        );
        insert orphanSubCode;

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_TransferCallNocService.persistBeforeTransfer(
                c.Id,
                null,
                noc.FEC_Product_Type__c,
                noc.FEC_Category__c,
                noc.FEC_Sub_Category__c,
                orphanSubCode.Id
            );
            Test.stopTest();

            Case updated = [
                SELECT FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c
                FROM Case
                WHERE Id = :c.Id
            ];
            System.assertEquals(noc.FEC_Product_Type__c, updated.FEC_Product_Type__c);
            System.assertEquals(noc.FEC_Category__c, updated.FEC_Category__c);
            System.assertEquals(noc.FEC_Sub_Category__c, updated.FEC_SubCategory__c);
            System.assertEquals(orphanSubCode.Id, updated.FEC_SubCode__c);
        }
    }

    @IsTest
    static void testTransferCallFromCase_SkipsPersistAndTransfers() {
        Case c = skipPersistCase();
        FEC_Nature_of_Case__c noc = templateNoc();
        Id catBefore = [SELECT FEC_Category__c FROM Case WHERE Id = :c.Id].FEC_Category__c;
        Test.setMock(HttpCalloutMock.class, new TransferSuccessMock());

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_TranferInformationCallout.TransferCallResponse res =
                FEC_TransferCallNocService.transferCallFromCase(
                    c.Id,
                    'Transfer remark from NOC service',
                    noc.Id,
                    noc.FEC_Product_Type__c,
                    noc.FEC_Category__c,
                    noc.FEC_Sub_Category__c,
                    noc.FEC_Sub_Code__c
                );
            Test.stopTest();

            System.assertEquals(true, res.success);
            System.assertEquals(
                catBefore,
                [SELECT FEC_Category__c FROM Case WHERE Id = :c.Id].FEC_Category__c
            );
        }
    }

    @IsTest
    static void testTransferCallFromCase_PersistsNocThenTransfers() {
        Case c = persistCase();
        FEC_Nature_of_Case__c noc = templateNoc();
        Test.setMock(HttpCalloutMock.class, new TransferSuccessMock());

        System.runAs(adminUser()) {
            FEC_TransferCallNocService.persistBeforeTransfer(
                c.Id,
                noc.Id,
                null,
                null,
                null,
                null
            );
            Test.startTest();
            FEC_TranferInformationCallout.TransferCallResponse res =
                FEC_TransferCallNocService.transferCallFromCase(
                    c.Id,
                    'Transfer remark after NOC persist',
                    noc.Id,
                    null,
                    null,
                    null,
                    null
                );
            Test.stopTest();

            System.assertEquals(true, res.success);
            System.assertEquals(
                noc.FEC_Category__c,
                [SELECT FEC_Category__c FROM Case WHERE Id = :c.Id].FEC_Category__c
            );
        }
    }
}
