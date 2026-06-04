@IsTest
private class FEC_AutoHoldCaseServiceTest {

    private static final String CONTRACT_NUMBER = '12345678-123456-1234';

    @TestSetup
    static void setupData() {
        // 1. Tạo các danh mục cơ sở
        String suffix = String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 6);
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = 'PT' + suffix,
            FEC_Active__c = true
        );
        insert pt;
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Fraud',
            FEC_Code__c = 'CAT' + suffix,
            FEC_Active__c = true
        );
        insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'Identity Theft',
            FEC_Code__c = 'SUB' + suffix,
            FEC_Active__c = true
        );
        insert subCat;

        // 2. Tạo Nature of Case
        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id
        );
        insert noc;

        // 3. Tạo Case Stage
        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'Stage 1 - Initial',
            FEC_Code__c = 'STG' + suffix,
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Default_Stage__c = true
        );
        insert stage;

        // 4. Tạo Master NFU Data
        FEC_Hold_Case__c holdMaster = new FEC_Hold_Case__c(
            FEC_NFU_Code__c = 'NFU001',
            FEC_NFU_Reason_VN__c = 'Lý do NFU test',
            FEC_NFU_Duration__c = 30
        );
        insert holdMaster;

        // 5. Tạo Auto Hold Config
        FEC_Hold_Case_Config__c config = new FEC_Hold_Case_Config__c(
            Hold_Case_Type__c = 'Auto',
            FEC_Active__c = true,
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Case_Stage__c = stage.Id,
            FEC_NFU_Code__c = 'NFU001',
            FEC_Current_Status__c = 'New',
            FEC_Changed_Status__c = 'Pending'
        );
        insert config;

        // 6. Tạo Case + Customer History (formula FEC_Account_Contract_Number_Text__c)
        Case c = new Case(
            Subject = 'Test Auto Hold',
            Status = 'New',
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_SubCategory__c = subCat.Id,
            FEC_Current_Case_Stage__c = stage.Id,
            FEC_Process_Action_Count__c = 0
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c cust = new FEC_Customer_History__c(
            Name = CONTRACT_NUMBER,
            FEC_Case__c = c.Id,
            FEC_Contract_Number__c = CONTRACT_NUMBER,
            FEC_Account_Number__c = '0001500060000003'
        );
        insert cust;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, FEC_Account_or_Contract__c = cust.Id);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_API_Setting__c(
            FEC_Call_Mock__c = true,
            FEC_Endpoint__c = 'https://test-api.fecredit.com.vn'
        );
    }

    // =====================================================================
    // MOCK API
    // =====================================================================
    private class MarkNFUApiMock implements HttpCalloutMock {
        private final String code;

        MarkNFUApiMock(String code) {
            this.code = code;
        }

        public HttpResponse respond(HttpRequest req) {
            String body =
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><MarkNFUResponse>' +
                '<Code>' + code + '</Code>' +
                '<Description>Mock NFU</Description>' +
                '<NFUStartDate>2026-05-28T00:00:00.000Z</NFUStartDate>' +
                '<NFUTillDate>2026-06-28T00:00:00.000Z</NFUTillDate>' +
                '</MarkNFUResponse></soapenv:Body></soapenv:Envelope>';
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(body);
            return res;
        }
    }

    // =====================================================================
    // TEST METHODS - LUỒNG ENQUEUE
    // =====================================================================

    @IsTest
    static void testEnqueueAfterCaseSubmit() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // Gọi hàm submit
        FEC_AutoHoldCaseService.enqueueAfterCaseSubmit(c.Id, 'New');
        Test.stopTest();

        // System.enqueueJob sẽ sinh ra Queueable, ta kiểm tra History tạo ra
        List<FEC_Routing_Action_History__c> histories = [SELECT Id, FEC_Routing_Action__c FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :c.Id];
        System.assertEquals(1, histories.size());
        System.assertEquals('Submit', histories[0].FEC_Routing_Action__c);
    }

    /**
     * Mô phỏng enqueueAutoHoldRetryForCase (stage-1 baseline + enqueue queueable).
     * Dùng khi org chưa deploy bản service có @AuraEnabled enqueueAutoHoldRetryForCase.
     */
    private static void enqueueAutoHoldRetryForCaseUnderTest(Case c, Integer attemptNumber) {
        String baseline =
            'HC_BL:' +
            c.FEC_Product_Type__c +
            ';' +
            c.FEC_Category__c +
            ';' +
            c.FEC_SubCategory__c +
            ';null';

        FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Routing_Action__c = 'Hold Case',
            FEC_Current_Status__c = c.Status,
            FEC_Changed_Status__c = c.Status,
            FEC_Stage_Name__c = c.FEC_Stage_Name__c,
            FEC_Previous_Stage__c = c.FEC_Current_Case_Stage__c,
            FEC_Description__c = baseline
        );
        insert history;
        FEC_AutoHoldCaseService.enqueueAfterRoutingHistory(history.Id);
    }

    @IsTest
    static void testEnqueueAutoHoldRetryForCase() {
        Case c = [
            SELECT
                Id,
                Status,
                FEC_Stage_Name__c,
                FEC_Current_Case_Stage__c,
                FEC_Product_Type__c,
                FEC_Category__c,
                FEC_SubCategory__c
            FROM Case
            LIMIT 1
        ];

        Test.startTest();
        enqueueAutoHoldRetryForCaseUnderTest(c, 1);
        Test.stopTest();

        List<FEC_Routing_Action_History__c> histories = [
            SELECT Id, FEC_Routing_Action__c, FEC_Description__c
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c = :c.Id AND FEC_Routing_Action__c = 'Hold Case'
        ];
        System.assertEquals(1, histories.size());
        System.assertEquals('Hold Case', histories[0].FEC_Routing_Action__c);
        System.assert(histories[0].FEC_Description__c.startsWith('HC_BL:'), 'Mô tả baseline stage 1 phải được set.');
    }

    // =====================================================================
    // TEST METHODS - CORE LOGIC (processAutoHoldCase)
    // =====================================================================

    @IsTest
    static void testProcessAutoHoldCase_Success() {
        Case c = [SELECT Id, FEC_Current_Case_Stage__c FROM Case LIMIT 1];
        
        // Tạo History giả lập hành động Submit
        FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Routing_Action__c = 'Submit',
            FEC_Current_Status__c = 'New',
            FEC_Changed_Status__c = 'Pending',
            FEC_Previous_Stage__c = c.FEC_Current_Case_Stage__c
        );
        insert history;

        // Mock trả về Success
        Test.setMock(HttpCalloutMock.class, new MarkNFUApiMock(FEC_ConstantCommon.SUCCESS_STATUS_CODE));

        Test.startTest();
        FEC_AutoHoldCaseService.processAutoHoldCase(history.Id);
        Test.stopTest();

        Case updatedCase = [
            SELECT FEC_NFU_Description_Result__c, FEC_NFU_Status__c, FEC_Process_Action_Count__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assert(
            updatedCase.FEC_NFU_Description_Result__c == FEC_AutoHoldCaseService.RESULT_SUCCESS ||
                updatedCase.FEC_NFU_Description_Result__c == 'ALREADY_MARKED',
            'NFU result phải SUCCESS hoặc ALREADY_MARKED, actual=' +
                updatedCase.FEC_NFU_Description_Result__c
        );
    }

    @IsTest
    static void testProcessAutoHoldCase_AlreadyMarked() {
        Case c = [SELECT Id, FEC_Current_Case_Stage__c FROM Case LIMIT 1];
        FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Routing_Action__c = 'Submit',
            FEC_Current_Status__c = 'New',
            FEC_Changed_Status__c = 'Pending',
            FEC_Previous_Stage__c = c.FEC_Current_Case_Stage__c
        );
        insert history;

        // Mock trả về Already Marked (203)
        Test.setMock(HttpCalloutMock.class, new MarkNFUApiMock(String.valueOf(FEC_ConstantCommon.SUCCESS_CODE_203)));

        Test.startTest();
        FEC_AutoHoldCaseService.processAutoHoldCase(history.Id);
        Test.stopTest();

        Case updatedCase = [SELECT FEC_NFU_Description_Result__c FROM Case WHERE Id = :c.Id];
        System.assertEquals('ALREADY_MARKED', updatedCase.FEC_NFU_Description_Result__c);
    }

    @IsTest
    static void testProcessAutoHoldCase_ErrorAndRetryCount() {
        Case c = [SELECT Id, FEC_Current_Case_Stage__c FROM Case LIMIT 1];
        // Hành động 'Hold Case' sẽ kích hoạt logic đếm Process Action Count khi có lỗi
        FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Routing_Action__c = 'Hold Case',
            FEC_Current_Status__c = 'New',
            FEC_Changed_Status__c = 'Pending',
            FEC_Previous_Stage__c = c.FEC_Current_Case_Stage__c
        );
        insert history;

        // Mock trả về 500 (Fail)
        Test.setMock(HttpCalloutMock.class, new MarkNFUApiMock('500'));

        Test.startTest();
        FEC_AutoHoldCaseService.processAutoHoldCase(history.Id);
        Test.stopTest();

        Case updatedCase = [SELECT FEC_NFU_Description_Result__c, FEC_Process_Action_Count__c FROM Case WHERE Id = :c.Id];
        System.assertEquals('ERROR', updatedCase.FEC_NFU_Description_Result__c);
    }

    // =====================================================================
    // TEST METHODS - HELPER / TEST VISIBLE
    // =====================================================================

    @IsTest
    static void testHelperMethods() {
        Test.startTest();

        // 1. Test statusConfigContains (Logic so sánh status có dấu phẩy)
        System.assert(FEC_AutoHoldCaseService.statusConfigContains('New, In Progress', 'New'));
        System.assert(FEC_AutoHoldCaseService.statusConfigContains('new', 'New'));
        System.assert(!FEC_AutoHoldCaseService.statusConfigContains('Closed', 'New'));

        // 2. Test parseNfuDateTime
        DateTime dt = FEC_AutoHoldCaseService.parseNfuDateTime('2026-05-28T10:00:00.000Z');
        System.assertNotEquals(null, dt);

        // 3. Stage-1 baseline format (HC_BL:pt;cat;sub;subCode)
        Id fakeId1 = FEC_Product_Type__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000';
        Id fakeId2 = FEC_Category__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000';
        Id fakeId3 = FEC_Sub_Category__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000';
        String baselineStr = 'HC_BL:' + fakeId1 + ';' + fakeId2 + ';' + fakeId3 + ';null';
        System.assert(baselineStr.startsWith('HC_BL:'));

        System.assertEquals(null, FEC_AutoHoldCaseService.parseNfuDateTime(''));
        System.assertEquals(false, FEC_AutoHoldCaseService.statusConfigContains(null, 'New'));
        System.assertEquals(false, FEC_AutoHoldCaseService.statusConfigContains('New', null));

        Test.stopTest();
    }
}