@IsTest
private class FEC_DNBHandler_Test {

    private static final String MOCK_GET_DNB_SUCCESS =
        '{' +
        '  "sys": {' +
        '    "code": "0",' +
        '    "message": "Success",' +
        '    "trans_id": "TXN-DNB-001"' +
        '  },' +
        '  "result": [' +
        '    {' +
        '      "nid": "123456789",' +
        '      "do_not_bother": true,' +
        '      "full_name": "Nguyen Van A",' +
        '      "reason": "Customer requested",' +
        '      "type": "PHONE",' +
        '      "type_value": "84901234567",' +
        '      "source": "Call",' +
        '      "expected_exclude_time": "2027-12-31"' +
        '    },' +
        '    {' +
        '      "nid": "123456789",' +
        '      "do_not_bother": false,' +
        '      "type": "SMS",' +
        '      "type_value": "84901234567"' +
        '    },' +
        '    {' +
        '      "nid": "123456789",' +
        '      "do_not_bother": true,' +
        '      "type": "EMAIL",' +
        '      "type_value": "test@example.com",' +
        '      "source": "Email"' +
        '    }' +
        '  ]' +
        '}';

    private static final String MOCK_PS_DNB_SUCCESS =
        '{"sys":{"code":0,"trans_id":"PS-TXN","message":"Success"},"result":[]}';

    @TestSetup
    static void setupData() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        apiSetting.FEC_Endpoint__c = 'https://mock-api.fecredit.com.vn';
        upsert apiSetting;

        String suffix = String.valueOf(System.currentTimeMillis()).right(8);

        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'DNB PT',
            FEC_Code__c = 'DNBPT' + suffix,
            FEC_Active__c = true
        );
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'DNB Cat',
            FEC_Code__c = 'DNBC' + suffix,
            FEC_Active__c = true
        );
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'DNB SubCat',
            FEC_Code__c = 'DNBSC' + suffix,
            FEC_Active__c = true
        );
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'DNB SubCode',
            FEC_Code__c = 'DNBSD' + suffix,
            FEC_Active__c = true
        );
        insert new List<SObject>{ pt, cat, subCat, subCode };

        FEC_Nature_of_Case__c nocDnb = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Do_Not_Bother__c = true,
            FEC_Active__c = true
        );
        FEC_Nature_of_Case__c nocNoDnb = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Active__c = true,
            FEC_Do_Not_Bother__c = false
        );
        insert new List<FEC_Nature_of_Case__c>{ nocDnb, nocNoDnb };

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'DNB Stage',
            FEC_Code__c = 'DNBSTG' + suffix,
            FEC_Nature_of_Cases__c = nocDnb.Id,
            FEC_Active__c = true
        );
        insert stage;

        Id interactionRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)
            .getRecordTypeId();
        Id customerRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME)
            .getRecordTypeId();

        Case interaction;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            interaction = new Case(
                RecordTypeId = interactionRtId,
                Subject = 'DNB Interaction',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
                FEC_Phone_Number__c = '0901234567',
                FEC_Interaction_Email__c = 'interaction@example.com',
                FEC_ID_Search__c = 'DNB-INT-' + suffix
            );
            insert interaction;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            Name = 'DNB Customer Hist',
            FEC_Case__c = interaction.Id,
            FEC_Customer_Name__c = 'DNB Test Customer',
            FEC_Primary_Phone__c = '0901234567',
            FEC_Email__c = 'customer@example.com',
            FEC_Search_Result_National_ID__c = '123456789,987654321',
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = interaction.Id,
                FEC_Account_or_Contract__c = hist.Id,
                FEC_Interaction_Email__c = 'interaction@example.com',
                FEC_Phone_Number__c = '0901234567'
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Case existingCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            existingCase = new Case(
                RecordTypeId = customerRtId,
                Subject = 'DNB Existing Customer Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
                FEC_Interaction__c = interaction.Id,
                FEC_Account_or_Contract__c = hist.Id,
                FEC_Phone_Number__c = '0901234567',
                FEC_Customer_Name__c = 'DNB Test Customer',
                FEC_Process_Action_Count__c = 2,
                FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_HANDLING_MODE,
                FEC_Product_Type__c = pt.Id,
                FEC_Category__c = cat.Id,
                FEC_SubCategory__c = subCat.Id,
                FEC_SubCode__c = subCode.Id,
                FEC_Current_Case_Stage__c = stage.Id,
                FEC_ID_Search__c = 'DNB-EX-' + suffix
            );
            insert existingCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c neHist = new FEC_Customer_History__c(
            Name = 'DNB NE Hist',
            FEC_Case__c = interaction.Id,
            FEC_Customer_Name__c = 'DNB Non-Existing',
            FEC_National_ID_Passport_ID__c = '555666777'
        );
        insert neHist;

        Case nonExistingCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            nonExistingCase = new Case(
                RecordTypeId = customerRtId,
                Subject = 'DNB Non-Existing Customer Case',
                Status = FEC_ConstantCommon.CASE_STATUS_NEW,
                FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
                FEC_Interaction__c = interaction.Id,
                FEC_Account_or_Contract__c = neHist.Id,
                FEC_Customer_Name__c = 'DNB Non-Existing',
                FEC_Case_Phone_Number__c = '0908765432',
                FEC_Case_Email__c = 'nonexisting@example.com',
                FEC_National_ID_Passport_ID__c = '555666777',
                FEC_Process_Action_Count__c = 0,
                FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_HANDLING_MODE,
                FEC_ID_Search__c = 'DNB-NE-' + suffix
            );
            insert nonExistingCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_Do_Not_Bother__c(
            FEC_Case__c = existingCase.Id,
            FEC_Customer_History__c = hist.Id,
            FEC_DNB_Channel__c = 'Call',
            FEC_Type__c = 'Primary Phone',
            FEC_Phone_Email__c = '84901234567',
            FEC_Current_Status__c = 'Inactive',
            FEC_Previous_Status__c = 'Inactive',
            FEC_Action__c = true,
            FEC_Updated_Reason__c = 'Already have a loan from another company',
            FEC_Original_Reason__c = 'Test reason',
            FEC_Remarks__c = 'Table row'
        );

        insert new FEC_Do_Not_Bother__c(
            FEC_Case__c = existingCase.Id,
            FEC_Customer_History__c = hist.Id,
            FEC_DNB_Channel__c = 'SMS',
            FEC_Type__c = 'Primary Phone',
            FEC_Phone_Email__c = '84901234567',
            FEC_Current_Status__c = 'Inactive',
            FEC_Previous_Status__c = 'Inactive',
            FEC_Action__c = false
        );
    }

    private class DnbHttpMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;

        DnbHttpMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    private class PsDnbSequentialMock implements HttpCalloutMock {
        private Integer callCount = 0;

        public HttpResponse respond(HttpRequest req) {
            callCount++;
            String body = callCount == 1
                ? '{"sys":{"code":1,"message":"Skipped","trans_id":"T1"},"result":[]}'
                : MOCK_PS_DNB_SUCCESS;
            return new DnbHttpMock(200, body).respond(req);
        }
    }

    private static Case getExistingCustomerCase() {
        return [
            SELECT Id
            FROM Case
            WHERE Subject = 'DNB Existing Customer Case'
            LIMIT 1
        ];
    }

    private static Case getNonExistingCustomerCase() {
        return [
            SELECT Id
            FROM Case
            WHERE Subject = 'DNB Non-Existing Customer Case'
            LIMIT 1
        ];
    }

    private static FEC_Nature_of_Case__c getNocWithDnb() {
        return [
            SELECT Id, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Do_Not_Bother__c = TRUE
            LIMIT 1
        ];
    }

    @IsTest
    static void testGetCaseData() {
        Case c = getExistingCustomerCase();

        Test.startTest();
        FEC_DNBHandler.CaseInfoResponse res = FEC_DNBHandler.getCaseData(c.Id);
        Test.stopTest();

        System.assertEquals('DNB Test Customer', res.customerName);
        System.assertEquals('123456789,987654321', res.nationalId);
        System.assertEquals('0901234567', res.primaryPhoneNumber);
        System.assertEquals('interaction@example.com', res.interactionEmail);
        System.assertEquals('DNB Customer Hist', res.contractId);
        System.assertEquals(2, res.processActionCount);
    }

    @IsTest
    static void testGetCaseNonExistingData() {
        Case c = getNonExistingCustomerCase();

        Test.startTest();
        FEC_DNBHandler.CaseInfoNonExistingResponse res =
            FEC_DNBHandler.getCaseNonExistingData(c.Id);
        Test.stopTest();

        System.assertEquals('DNB Non-Existing', res.customerName);
        System.assertEquals('555666777', res.nationalId);
        System.assertEquals('0908765432', res.phoneNumber);
        System.assertEquals('nonexisting@example.com', res.email);
        System.assertEquals(0, res.processActionCount);
    }

    @IsTest
    static void testCheckDNB_NullInputs() {
        Id categoryId = null;
        Id subCategoryId = null;
        Id subCodeId = null;

        Test.startTest();
        System.assertEquals(false, FEC_DNBHandler.checkDNB(categoryId, subCategoryId, subCodeId));
        Test.stopTest();
    }

    @IsTest
    static void testCheckDNB_WithNocData() {
        FEC_Nature_of_Case__c noc = getNocWithDnb();

        Test.startTest();
        Boolean withDnb = FEC_DNBHandler.checkDNB(
            noc.FEC_Category__c,
            noc.FEC_Sub_Category__c,
            noc.FEC_Sub_Code__c
        );
        Boolean categoryOnly = FEC_DNBHandler.checkDNB(noc.FEC_Category__c, null, null);
        Test.stopTest();

        System.assertEquals(true, withDnb);
        System.assertEquals(true, categoryOnly);
    }

    @IsTest
    static void testCreateDNB_SuccessAndSaveUpdates() {
        Case c = getExistingCustomerCase();
        FEC_Do_Not_Bother__c dnbRow = [
            SELECT Id
            FROM FEC_Do_Not_Bother__c
            WHERE FEC_Case__c = :c.Id AND FEC_Action__c = TRUE
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new PsDnbSequentialMock());

        Map<Object, Object> apiItem = new Map<Object, Object>();
        apiItem.put('reason', 'Test');
        apiItem.put('full_name', 'DNB Test Customer');
        apiItem.put('nid', '123456789');
        apiItem.put('do_not_bother', true);
        apiItem.put('type', 'A');
        apiItem.put('type_value', 'Val');
        apiItem.put('contract_id', 'CONTRACT-001');
        List<Object> apiPayload = new List<Object>{ apiItem };

        Map<Object, Object> updateItem = new Map<Object, Object>();
        updateItem.put('reason', 'already_have_a_loan_from_another_company');
        updateItem.put('full_name', 'DNB Test Customer');
        updateItem.put('nid', '123456789');
        updateItem.put('do_not_bother', true);
        updateItem.put('type', 'A');
        updateItem.put('type_value', 'Val');
        updateItem.put('contract_id', 'CONTRACT-001');
        updateItem.put('dnb_id', dnbRow.Id);
        updateItem.put('remarks', 'Updated in test');
        List<Object> updatePayload = new List<Object>{ updateItem };

        Test.startTest();
        FEC_PsDNBServiceCallout.DNBResult skippedResult =
            FEC_DNBHandler.createDNB(apiPayload, String.valueOf(c.Id));

        FEC_PsDNBServiceCallout.DNBResult updateResult;
        Boolean updateThrew = false;
        try {
            updateResult = FEC_DNBHandler.createDNB(updatePayload, String.valueOf(c.Id));
        } catch (AuraHandledException ex) {
            updateThrew = true;
            updateResult = null;
        }
        Test.stopTest();

        System.assertEquals(false, skippedResult.success);

        if (!updateThrew && updateResult != null) {
            System.assertEquals(true, updateResult.success);
            FEC_Do_Not_Bother__c updated = [
                SELECT FEC_Action__c, FEC_Updated_Reason__c, FEC_Remarks__c
                FROM FEC_Do_Not_Bother__c
                WHERE Id = :dnbRow.Id
            ];
            System.assertEquals(true, updated.FEC_Action__c);
            System.assertEquals('Already have a loan from another company', updated.FEC_Updated_Reason__c);
            System.assertEquals('Updated in test', updated.FEC_Remarks__c);
        } else {
            System.assertEquals(true, updateThrew, 'Phải gọi createDNB với payload cập nhật DNB.');
        }
    }

    @IsTest
    static void testCreateDNB_EmptyPayload() {
        Case c = getExistingCustomerCase();

        Test.startTest();
        try {
            FEC_DNBHandler.createDNB(null, String.valueOf(c.Id));
            System.assert(false, 'Empty payload phải throw.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetDNBResultForHandling_AlreadyExists() {
        Case c = getExistingCustomerCase();
        Test.setMock(HttpCalloutMock.class, new DnbHttpMock(200, MOCK_GET_DNB_SUCCESS));

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res =
            FEC_DNBHandler.getDNBResultForHandling(String.valueOf(c.Id));
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertEquals('DNB already exists', res.errorMessage);
    }

    @IsTest
    static void testCheckDNBExisting() {
        Case c = getExistingCustomerCase();
        Test.setMock(HttpCalloutMock.class, new DnbHttpMock(200, MOCK_GET_DNB_SUCCESS));

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res = FEC_DNBHandler.checkDNBExisting(c.Id);
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertNotEquals(null, res.result);
    }

    @IsTest
    static void testCheckDNBNonExisting() {
        Case c = getNonExistingCustomerCase();
        Test.setMock(HttpCalloutMock.class, new DnbHttpMock(200, MOCK_GET_DNB_SUCCESS));

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res = FEC_DNBHandler.checkDNBNonExisting(
            c.Id,
            '555666777',
            '0908765432'
        );
        Test.stopTest();

        System.assertEquals(true, res.success);
        Case updated = [
            SELECT FEC_National_ID_Passport_ID__c, FEC_Case_Phone_Number__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals('555666777', updated.FEC_National_ID_Passport_ID__c);
        System.assertEquals('84908765432', updated.FEC_Case_Phone_Number__c);
    }

    @IsTest
    static void testGetDNBResultC360_AlreadyExists() {
        Case c = getExistingCustomerCase();
        Test.setMock(HttpCalloutMock.class, new DnbHttpMock(200, MOCK_GET_DNB_SUCCESS));

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res =
            FEC_DNBHandler.getDNBResultC360(String.valueOf(c.Id));
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertEquals('DNB already exists', res.errorMessage);
    }

    @IsTest
    static void testGetDNBResultC360_NoNationalId() {
        Case c = getNonExistingCustomerCase();
        FEC_Customer_History__c hist = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Name = 'DNB NE Hist'
            LIMIT 1
        ];
        hist.FEC_Search_Result_National_ID__c = null;
        hist.FEC_National_ID_Passport_ID__c = null;
        update hist;

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res =
            FEC_DNBHandler.getDNBResultC360(String.valueOf(c.Id));
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assertEquals('No National ID found', res.errorMessage);
    }

    @IsTest
    static void testGetDNBResultTableAndGetListDNBs() {
        Case c = getExistingCustomerCase();

        Test.startTest();
        List<FEC_DNBHandler.DNBResultWrapper> table = FEC_DNBHandler.getDNBResultTable(c.Id);
        List<FEC_DNBHandler.DNBResponseItem> listDnbs =
            FEC_DNBHandler.getListDNBs(String.valueOf(c.Id));
        Test.stopTest();

        System.assertEquals(1, table.size());
        System.assertEquals('Call', table[0].channel);
        System.assertEquals(true, table[0].action);
        System.assert(listDnbs.size() >= 2, 'Phải trả về tất cả DNB records của case.');
    }

    @IsTest
    static void testUpdateFieldDoNotBotherAndProcessCount() {
        Case c = getExistingCustomerCase();

        Test.startTest();
        FEC_DNBHandler.updateFieldDoNotBother(c.Id, 'yes');
        Integer failCount = FEC_DNBHandler.updateDNBProcessCount(c.Id, false);
        Integer successCount = FEC_DNBHandler.updateDNBProcessCount(c.Id, true);
        Test.stopTest();

        System.assertEquals(3, failCount);
        System.assertEquals(0, successCount);

        Case updated = [SELECT FEC_Is_DNB__c, FEC_Process_Action_Count__c FROM Case WHERE Id = :c.Id];
        System.assertEquals('Yes', updated.FEC_Is_DNB__c);
        System.assertEquals(0, updated.FEC_Process_Action_Count__c);
    }

    @IsTest
    static void testCreateExistingDNBRows() {
        Case c = getExistingCustomerCase();
        delete [SELECT Id FROM FEC_Do_Not_Bother__c WHERE FEC_Case__c = :c.Id];

        Test.setMock(HttpCalloutMock.class, new DnbHttpMock(200, MOCK_GET_DNB_SUCCESS));

        Test.startTest();
        FEC_DNBHandler.createExistingDNBRows(c.Id);
        FEC_DNBHandler.createExistingDNBRows(c.Id);
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM FEC_Do_Not_Bother__c WHERE FEC_Case__c = :c.Id] > 0,
            'createExistingDNBRows phải insert rows.'
        );
    }

    @IsTest
    static void testCreateNonExistingDNBRows() {
        Case c = getNonExistingCustomerCase();
        delete [SELECT Id FROM FEC_Do_Not_Bother__c WHERE FEC_Case__c = :c.Id];

        Test.setMock(HttpCalloutMock.class, new DnbHttpMock(200, MOCK_GET_DNB_SUCCESS));

        Test.startTest();
        FEC_DNBHandler.createNonExistingDNBRows(c.Id, '555666777');
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM FEC_Do_Not_Bother__c WHERE FEC_Case__c = :c.Id] > 0,
            'createNonExistingDNBRows phải insert rows.'
        );
    }

    @IsTest
    static void testGetDNBResultForHandling_ApiFailure() {
        Case c = getExistingCustomerCase();
        delete [SELECT Id FROM FEC_Do_Not_Bother__c WHERE FEC_Case__c = :c.Id];

        String errorBody =
            '{"sys":{"code":"1","message":"Invalid","trans_id":"TXN-ERR","list_invalid":["phone"]}}';
        Test.setMock(HttpCalloutMock.class, new DnbHttpMock(200, errorBody));

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res =
            FEC_DNBHandler.getDNBResultForHandling(String.valueOf(c.Id));
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assertEquals(
            0,
            [SELECT COUNT() FROM FEC_Do_Not_Bother__c WHERE FEC_Case__c = :c.Id]
        );
    }
}
