/**
 * FEC_AcctOrContractPicklist_Test (tests FEC_AccountOrContractPicklistHandler)
 * Unit tests for FEC_AccountOrContractPicklistHandler
 * Mỗi @IsTest theo cấu trúc:
 *   1. Dựng dữ liệu giả lập
 *   2. Kiểm thử kịch bản thành công
 *   3. Kiểm thử kịch bản lỗi
 */
@IsTest
private class FEC_AcctOrContractPicklist_Test {

    private class CustomerIntegrationMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'text/xml');
            res.setBody(
                '<?xml version="1.0" encoding="UTF-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetCustomerListResponse>' +
                '<Sys><Code>0</Code></Sys><Count>1</Count>' +
                '<Customers><Customer><CIFNumber>CIF-CH</CIFNumber><FullName>Synced</FullName></Customer></Customers>' +
                '</GetCustomerListResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    /* ================================================================
     * CONSTANTS – ánh xạ sang FEC_ConstantCommon để test không hardcode
     * ================================================================ */
    private static final String TYPE_LOAN      = FEC_ConstantCommon.PRODUCT_TYPE_LOAN;
    private static final String TYPE_INSURANCE = FEC_ConstantCommon.PRODUCT_TYPE_INSURANCE;
    private static final String TYPE_CARD      = FEC_ConstantCommon.PRODUCT_TYPE_CARD;
    private static final String TYPE_UBANK     = FEC_ConstantCommon.PRODUCT_TYPE_UBANK;
    private static final String TYPE_NON_EXIST = FEC_ConstantCommon.PRODUCT_NON_EXISTING_CUSTOMER;
    private static final String MODE_HANDLING  = FEC_ConstantCommon.INTERACTION_HANDLING_MODE;
    private static final String MODE_REVIEW    = FEC_ConstantCommon.INTERACTION_REVIEW_MODE;

    /* ================================================================
     * DATA FACTORY
     * ================================================================ */

    /** Tạo FEC_Product_Type__c với tên cho trước (FEC_Code__c bắt buộc + unique). */
    private static FEC_Product_Type__c insertProductType(String name) {
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = name,
            FEC_Code__c = name
        );
        insert pt;
        return pt;
    }

    /** Tạo FEC_Customer_History__c đơn giản gắn với Case */
    private static FEC_Customer_History__c insertCustomerHistory(
            Id caseId, String productCode, String contractNum, String accountNum, String cifNum) {
        System.assertNotEquals(null, caseId,
            'FEC_Case__c is Master-Detail; FEC_Customer_History__c requires a parent Case Id.');

        FEC_Customer_History__c h = new FEC_Customer_History__c(
            Name                  = 'Test-' + productCode,
            FEC_Case__c           = caseId,
            FEC_Product_Code__c   = productCode,
            FEC_Contract_Number__c = contractNum,
            FEC_Account_Number__c  = accountNum,
            FEC_CIF_Number__c      = cifNum
        );
        insert h;
        return h;
    }

    /** Tạo Case có đầy đủ field liên quan */
    private static Case insertCase(
            Id productTypeId, Id customerHistoryId,
            String phoneNum, Boolean hasAccContract,
            String viewMode, String customerType) {

        // FEC_Has_Account_or_Contract__c is formula from FEC_Account_or_Contract__c (not writeable)
        Case c = new Case(
            Status                         = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin                         = 'Phone',
            FEC_Product_Type__c            = productTypeId,
            FEC_Account_or_Contract__c     = customerHistoryId,
            FEC_Phone_Number__c            = phoneNum,
            FEC_Interaction_View_Mode__c   = viewMode,
            FEC_Customer_Type__c           = customerType
        );
        insert c;
        return c;
    }

    /* ================================================================
     * TEST 1 – getInteractionAccountNumber: product LOAN
     * ================================================================ */
    @IsTest
    static void testGetInteractionAccountNumber_Loan() {
        // 1. Dựng dữ liệu giả lập
        FEC_Product_Type__c pt = insertProductType(TYPE_LOAN);
        Case c = insertCase(pt.Id, null, '0901234567', true, MODE_HANDLING, 'Existing');
        FEC_Customer_History__c h = insertCustomerHistory(
            c.Id, TYPE_LOAN, 'LOAN-CONTRACT-001', null, 'CIF-001');
        c.FEC_Account_or_Contract__c = h.Id;
        update c;

        // 2. Kiểm thử kịch bản thành công
        String json = FEC_AccountOrContractPicklistHandler.getInteractionAccountNumber(c.Id);

        Map<String, Object> result = (Map<String, Object>) System.JSON.deserializeUntyped(json);
        System.assertEquals('LOAN-CONTRACT-001', result.get('accountNumber'),
            'Loan phải trả FEC_Contract_Number__c');
        System.assertEquals('CIF-001',           result.get('cifNumber'),    'CIF phải khớp');
        System.assertEquals(TYPE_LOAN,            result.get('productCode'),  'productCode phải là LOAN');
        System.assertEquals('0901234567',          result.get('phone'),        'Phone phải khớp');
        System.assertEquals(true,                 result.get('hasContractAccount'), 'hasContractAccount phải true');

        // 3. Kiểm thử kịch bản lỗi – caseId không tồn tại
        String errorJson = FEC_AccountOrContractPicklistHandler.getInteractionAccountNumber('500000000000000AAA');
        Map<String, Object> empty = (Map<String, Object>) System.JSON.deserializeUntyped(errorJson);
        System.assertEquals(true, empty.isEmpty(), 'Phải trả map rỗng khi caseId không tồn tại');
    }

    /* ================================================================
     * TEST 2 – getInteractionAccountNumber: product INSURANCE
     * ================================================================ */
    @IsTest
    static void testGetInteractionAccountNumber_Insurance() {
        // 1. Dựng dữ liệu giả lập
        FEC_Product_Type__c pt = insertProductType(TYPE_INSURANCE);
        Case c = insertCase(pt.Id, null, '0912345678', true, MODE_HANDLING, 'Existing');
        FEC_Customer_History__c h = insertCustomerHistory(
            c.Id, TYPE_INSURANCE, 'INS-CONTRACT-001', null, 'CIF-002');
        c.FEC_Account_or_Contract__c = h.Id;
        update c;

        // 2. Kiểm thử kịch bản thành công
        String json = FEC_AccountOrContractPicklistHandler.getInteractionAccountNumber(c.Id);

        Map<String, Object> result = (Map<String, Object>) System.JSON.deserializeUntyped(json);
        System.assertEquals('INS-CONTRACT-001', result.get('accountNumber'),
            'Insurance phải trả FEC_Contract_Number__c');
        System.assertEquals(TYPE_INSURANCE, result.get('productCode'), 'productCode phải là INSURANCE');

        // 3. Kiểm thử kịch bản lỗi – caseId null
        String nullJson = FEC_AccountOrContractPicklistHandler.getInteractionAccountNumber(null);
        Map<String, Object> emptyMap = (Map<String, Object>) System.JSON.deserializeUntyped(nullJson);
        System.assertEquals(true, emptyMap.isEmpty(), 'Phải trả map rỗng khi caseId null');
    }

    /* ================================================================
     * TEST 3 – getInteractionAccountNumber: product CARD
     * ================================================================ */
    @IsTest
    static void testGetInteractionAccountNumber_Card() {
        // 1. Dựng dữ liệu giả lập
        FEC_Product_Type__c pt = insertProductType(TYPE_CARD);
        Case c = insertCase(pt.Id, null, '0923456789', true, MODE_REVIEW, 'Existing');
        FEC_Customer_History__c h = insertCustomerHistory(
            c.Id, TYPE_CARD, null, 'ACC-CARD-001', 'CIF-003');
        c.FEC_Account_or_Contract__c = h.Id;
        update c;

        // 2. Kiểm thử kịch bản thành công
        String json = FEC_AccountOrContractPicklistHandler.getInteractionAccountNumber(c.Id);

        Map<String, Object> result = (Map<String, Object>) System.JSON.deserializeUntyped(json);
        System.assertEquals('ACC-CARD-001', result.get('accountNumber'),
            'Card phải trả FEC_Account_Number__c');
        System.assertEquals(TYPE_CARD, result.get('productCode'), 'productCode phải là CARD');

        // 3. Kiểm thử kịch bản lỗi – Case không có FEC_Account_or_Contract__c (null relation)
        Case noHistCase = insertCase(pt.Id, null, null, false, null, null);
        String noHistJson = FEC_AccountOrContractPicklistHandler.getInteractionAccountNumber(noHistCase.Id);
        Map<String, Object> noHistResult = (Map<String, Object>) System.JSON.deserializeUntyped(noHistJson);
        System.assertEquals(true, noHistResult.isEmpty(),
            'Phải trả map rỗng khi Case không có Account_or_Contract');
    }

    /* ================================================================
     * TEST 4 – getInteractionAccountNumber: product UBANK
     * ================================================================ */
    @IsTest
    static void testGetInteractionAccountNumber_UBank() {
        // 1. Dựng dữ liệu giả lập
        FEC_Product_Type__c pt = insertProductType(TYPE_UBANK);
        Case c = insertCase(pt.Id, null, '0934567890', true, MODE_HANDLING, 'Existing');
        FEC_Customer_History__c h = insertCustomerHistory(
            c.Id, TYPE_UBANK, null, TYPE_UBANK, null);
        c.FEC_Account_or_Contract__c = h.Id;
        update c;

        // 2. Kiểm thử kịch bản thành công – UBank lấy FEC_Product_Code__c
        String json = FEC_AccountOrContractPicklistHandler.getInteractionAccountNumber(c.Id);

        Map<String, Object> result = (Map<String, Object>) System.JSON.deserializeUntyped(json);
        System.assertEquals(TYPE_UBANK, result.get('productCode'),
            'productCode phải là UBANK');
        // accountNumber = FEC_Product_Code__c của FEC_Customer_History__c (TYPE_UBANK)
        System.assertNotEquals(null, result.get('accountNumber'),
            'accountNumber phải được set cho UBank');

        // 3. Kiểm thử kịch bản lỗi – product type không khớp bất kỳ nhánh nào
        FEC_Product_Type__c ptUnknown = insertProductType('UNKNOWN_TYPE');
        Case unknownCase = insertCase(ptUnknown.Id, h.Id, null, false, null, null);
        String unknownJson = FEC_AccountOrContractPicklistHandler.getInteractionAccountNumber(unknownCase.Id);
        Map<String, Object> unknownResult = (Map<String, Object>) System.JSON.deserializeUntyped(unknownJson);
        // accountNumber sẽ null nhưng map không rỗng (vẫn có cifNumber, productCode, ...)
        System.assertNotEquals(null, unknownResult, 'Kết quả không được null');
    }

    /* ================================================================
     * TEST 5 – getCustomerHistoryId
     * ================================================================ */
    @IsTest
    static void testGetCustomerHistoryId_Success() {
        // 1. Dựng dữ liệu giả lập
        Case c = insertCase(null, null, null, false, null, null);
        FEC_Customer_History__c h = insertCustomerHistory(
            c.Id, TYPE_LOAN, 'LOAN-002', null, 'CIF-HIST');
        c.FEC_Account_or_Contract__c = h.Id;
        update c;

        // 2. Kiểm thử kịch bản thành công
        Id result = FEC_AccountOrContractPicklistHandler.getCustomerHistoryId(c.Id);

        System.assertEquals(h.Id, result, 'Phải trả đúng FEC_Account_or_Contract__c Id');

        // 3. Kiểm thử kịch bản lỗi – caseId không hợp lệ → AuraHandledException
        Boolean threw = false;
        try {
            FEC_AccountOrContractPicklistHandler.getCustomerHistoryId('500000000000000AAA');
        } catch (AuraHandledException ex) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Phải throw AuraHandledException khi caseId không tồn tại');
    }

    /* ================================================================
     * TEST 6 – getAccountNumberCustomerCase: product LOAN
     * ================================================================ */
    @IsTest
    static void testGetAccountNumberCustomerCase_Loan() {
        // 1. Dựng dữ liệu giả lập
        FEC_Product_Type__c pt = insertProductType(TYPE_LOAN);
        Case c = insertCase(pt.Id, null, '0945678901', true, null, null);
        FEC_Customer_History__c h = insertCustomerHistory(
            c.Id, TYPE_LOAN, 'LOAN-CONTRACT-002', null, 'CIF-ACN');
        c.FEC_Account_or_Contract__c = h.Id;
        update c;

        // 2. Kiểm thử kịch bản thành công
        String json = FEC_AccountOrContractPicklistHandler.getAccountNumberCustomerCase(c.Id, h.Id);

        Map<String, Object> result = (Map<String, Object>) System.JSON.deserializeUntyped(json);
        System.assertEquals('LOAN-CONTRACT-002', result.get('accountNumber'),
            'Loan phải trả FEC_Contract_Number__c');
        System.assertEquals(TYPE_LOAN, result.get('productCode'), 'productCode phải là LOAN');

        // 3. Kiểm thử kịch bản lỗi – customerHistoryId không khớp với case → query trả rỗng
        Case cOther = insertCase(null, null, null, false, null, null);
        FEC_Customer_History__c otherH = insertCustomerHistory(
            cOther.Id, TYPE_CARD, null, 'OTHER-ACC', 'CIF-OTHER');
        String mismatchJson = FEC_AccountOrContractPicklistHandler.getAccountNumberCustomerCase(
            c.Id, otherH.Id);
        Map<String, Object> mismatch = (Map<String, Object>) System.JSON.deserializeUntyped(mismatchJson);
        System.assertEquals(true, mismatch.isEmpty(),
            'Phải trả map rỗng khi customerHistoryId không khớp case');
    }

    /* ================================================================
     * TEST 7 – getInteractionViewMode
     * ================================================================ */
    @IsTest
    static void testGetInteractionViewMode() {
        // 1. Dựng dữ liệu giả lập
        Case c = insertCase(null, null, null, false, MODE_REVIEW, null);

        // 2. Kiểm thử kịch bản thành công
        String mode = FEC_AccountOrContractPicklistHandler.getInteractionViewMode(c.Id);

        System.assertEquals(MODE_REVIEW, mode, 'Phải trả đúng FEC_Interaction_View_Mode__c');

        // 3. Kiểm thử kịch bản lỗi – caseId không tồn tại → AuraHandledException
        Boolean threw = false;
        try {
            FEC_AccountOrContractPicklistHandler.getInteractionViewMode('500000000000000AAA');
        } catch (AuraHandledException ex) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Phải throw AuraHandledException khi caseId không tồn tại');
    }

    /* ================================================================
     * TEST 8 – getInteractionIdFromCustomerCase
     * ================================================================ */
    @IsTest
    static void testGetInteractionIdFromCustomerCase() {
        // 1. Dựng dữ liệu giả lập
        // Tạo interaction Case (cha)
        Case interaction = new Case(
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone'
        );
        insert interaction;

        // Tạo customer Case có FEC_Interaction__c trỏ về interaction
        Case customerCase = new Case(
            Status            = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin            = 'Phone',
            FEC_Interaction__c = interaction.Id
        );
        insert customerCase;

        // 2. Kiểm thử kịch bản thành công
        Id resultId = FEC_AccountOrContractPicklistHandler.getInteractionIdFromCustomerCase(
            customerCase.Id);
        System.assertEquals(interaction.Id, resultId,
            'Phải trả đúng FEC_Interaction__c Id');

        // 3. Kiểm thử kịch bản lỗi – Case không có FEC_Interaction__c (null)
        Case noLinkCase = new Case(Status = FEC_ConstantCommon.CASE_STATUS_OPEN, Origin = 'Phone');
        insert noLinkCase;
        Id nullResult = FEC_AccountOrContractPicklistHandler.getInteractionIdFromCustomerCase(
            noLinkCase.Id);
        System.assertEquals(null, nullResult,
            'Phải trả null khi Case không có Interaction liên kết');
    }

    /* ================================================================
     * TEST 9 – getProductTypeByName
     * ================================================================ */
    @IsTest
    static void testGetProductTypeByName() {
        // 1. Dựng dữ liệu giả lập
        FEC_Product_Type__c pt = insertProductType(TYPE_LOAN);

        // 2. Kiểm thử kịch bản thành công – tìm thấy theo LIKE
        FEC_Product_Type__c found = FEC_AccountOrContractPicklistHandler.getProductTypeByName(
            TYPE_LOAN);
        System.assertNotEquals(null, found, 'Phải tìm thấy ProductType theo keyword');
        System.assertEquals(pt.Id, found.Id, 'Id phải khớp với record đã insert');

        // 3. Kiểm thử kịch bản lỗi – keyword null/blank → trả null
        FEC_Product_Type__c nullResult = FEC_AccountOrContractPicklistHandler.getProductTypeByName(
            null);
        System.assertEquals(null, nullResult, 'Phải trả null khi keyword null');

        FEC_Product_Type__c emptyResult = FEC_AccountOrContractPicklistHandler.getProductTypeByName(
            '   ');
        System.assertEquals(null, emptyResult, 'Phải trả null khi keyword blank');

        FEC_Product_Type__c notFound = FEC_AccountOrContractPicklistHandler.getProductTypeByName(
            'COMPLETELY_UNKNOWN_XYZ');
        System.assertEquals(null, notFound, 'Phải trả null khi không tìm thấy ProductType');
    }

    /* ================================================================
     * TEST 10 – getInteractionCustomerType
     * ================================================================ */
    @IsTest
    static void testGetInteractionCustomerType() {
        // 1. Dựng dữ liệu giả lập
        Case c = insertCase(null, null, null, false, null, 'Existing');

        // 2. Kiểm thử kịch bản thành công
        String customerType = FEC_AccountOrContractPicklistHandler.getInteractionCustomerType(c.Id);

        System.assertEquals('Existing', customerType,
            'Phải trả đúng FEC_Customer_Type__c');

        // 3. Kiểm thử kịch bản lỗi – caseId không tồn tại → AuraHandledException
        Boolean threw = false;
        try {
            FEC_AccountOrContractPicklistHandler.getInteractionCustomerType(
                '500000000000000AAA');
        } catch (AuraHandledException ex) {
            threw = true;
        }
        System.assertEquals(true, threw,
            'Phải throw AuraHandledException khi caseId không tồn tại');
    }

    /* ================================================================
     * TEST 11 – getProductsListByCif: blank cifNumber → exception
     * ================================================================ */
    @IsTest
    static void testGetProductsListByCif_BlankCif() {
        // 1. Dựng dữ liệu giả lập – không cần record, chỉ test guard clause

        // 2. Kiểm thử kịch bản thành công (guard: blank → exception)
        Boolean threwNull = false;
        try {
            FEC_AccountOrContractPicklistHandler.getProductsListByCif(null);
        } catch (AuraHandledException ex) {
            threwNull = true;
        }

        System.assertEquals(true, threwNull,
            'Phải throw AuraHandledException khi cifNumber null');

        // 3. Kiểm thử kịch bản lỗi – empty string
        Boolean threwEmpty = false;
        try {
            FEC_AccountOrContractPicklistHandler.getProductsListByCif('   ');
        } catch (AuraHandledException ex) {
            threwEmpty = true;
        }
        System.assertEquals(true, threwEmpty,
            'Phải throw AuraHandledException khi cifNumber blank');
    }

    /* ================================================================
     * TEST 12 – updateInteractionWithNewCustomerHistory: từng product type
     * ================================================================ */
    @IsTest
    static void testUpdateInteractionWithNewCustomerHistory_Loan() {
        // 1. Dựng dữ liệu giả lập
        FEC_Product_Type__c pt = insertProductType(TYPE_LOAN);
        Case c = insertCase(null, null, null, false, null, null);
        FEC_Customer_History__c h = insertCustomerHistory(
            c.Id, TYPE_LOAN, 'LOAN-UPD-001', null, 'CIF-UPD');

        // 2. Kiểm thử kịch bản thành công – Loan → set FEC_Contract_Number__c
        FEC_AccountOrContractPicklistHandler.updateInteractionWithNewCustomerHistory(
            c.Id, h.Id, pt.Id, TYPE_LOAN, 'LOAN-UPD-001');

        Case updated = [SELECT FEC_Account_or_Contract__c, FEC_Product_Type__c,
                               FEC_Contract_Number__c, FEC_Account_Number__c
                        FROM Case WHERE Id = :c.Id];
        System.assertEquals(h.Id,          updated.FEC_Account_or_Contract__c, 'History phải được gán');
        System.assertEquals(pt.Id,         updated.FEC_Product_Type__c,        'ProductType phải được gán');
        System.assertEquals('LOAN-UPD-001',updated.FEC_Contract_Number__c,     'ContractNumber phải được set');
        System.assertEquals(null,          updated.FEC_Account_Number__c,      'AccountNumber phải null cho Loan');

        // 3. Kiểm thử kịch bản lỗi – caseId không tồn tại → DmlException → AuraHandledException
        Boolean threw = false;
        try {
            FEC_AccountOrContractPicklistHandler.updateInteractionWithNewCustomerHistory(
                '500000000000000AAA', h.Id, pt.Id, TYPE_LOAN, 'LOAN-ERR');
        } catch (AuraHandledException ex) {
            threw = true;
        }
        System.assertEquals(true, threw,
            'Phải throw AuraHandledException khi caseId không hợp lệ');
    }

    @IsTest
    static void testUpdateInteractionWithNewCustomerHistory_Card() {
        // 1. Dựng dữ liệu giả lập
        FEC_Product_Type__c pt = insertProductType(TYPE_CARD);
        Case c = insertCase(null, null, null, false, null, null);
        FEC_Customer_History__c h = insertCustomerHistory(
            c.Id, TYPE_CARD, null, 'CARD-ACC-001', 'CIF-CARD');

        // 2. Kiểm thử kịch bản thành công – Card → set FEC_Account_Number__c
        FEC_AccountOrContractPicklistHandler.updateInteractionWithNewCustomerHistory(
            c.Id, h.Id, pt.Id, TYPE_CARD, 'CARD-ACC-001');

        Case updated = [SELECT FEC_Account_Number__c, FEC_Contract_Number__c FROM Case WHERE Id = :c.Id];
        System.assertEquals('CARD-ACC-001', updated.FEC_Account_Number__c,
            'AccountNumber phải được set cho Card');
        System.assertEquals(null, updated.FEC_Contract_Number__c,
            'ContractNumber phải null cho Card');

        // 3. Kiểm thử kịch bản lỗi – accountContractNumber blank → không set field
        Case c2 = insertCase(null, null, null, false, null, null);
        FEC_AccountOrContractPicklistHandler.updateInteractionWithNewCustomerHistory(
            c2.Id, h.Id, pt.Id, TYPE_CARD, null);
        Case unchanged = [SELECT FEC_Account_Number__c FROM Case WHERE Id = :c2.Id];
        System.assertEquals(null, unchanged.FEC_Account_Number__c,
            'AccountNumber không được set khi accountContractNumber blank');
    }

    @IsTest
    static void testUpdateInteractionWithNewCustomerHistory_UBank() {
        // 1. Dựng dữ liệu giả lập
        FEC_Product_Type__c pt = insertProductType(TYPE_UBANK);
        Case c = insertCase(null, null, null, false, null, null);
        FEC_Customer_History__c h = insertCustomerHistory(
            c.Id, TYPE_UBANK, null, TYPE_UBANK, null);

        // 2. Kiểm thử kịch bản thành công – UBank → set FEC_Account_Number__c = TYPE_UBANK constant
        FEC_AccountOrContractPicklistHandler.updateInteractionWithNewCustomerHistory(
            c.Id, h.Id, pt.Id, TYPE_UBANK, null);

        Case updated = [SELECT FEC_Account_Number__c, FEC_Contract_Number__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(TYPE_UBANK, updated.FEC_Account_Number__c,
            'AccountNumber phải = PRODUCT_TYPE_UBANK constant cho UBank');
        System.assertEquals(null, updated.FEC_Contract_Number__c,
            'ContractNumber phải null cho UBank');

        // 3. Kiểm thử kịch bản lỗi – Insurance giống Loan, không set AccountNumber
        FEC_Product_Type__c ptIns = insertProductType(TYPE_INSURANCE);
        Case cIns = insertCase(null, null, null, false, null, null);
        FEC_Customer_History__c hIns = insertCustomerHistory(
            cIns.Id, TYPE_INSURANCE, 'INS-UPD-001', null, 'CIF-INS');
        FEC_AccountOrContractPicklistHandler.updateInteractionWithNewCustomerHistory(
            cIns.Id, hIns.Id, ptIns.Id, TYPE_INSURANCE, 'INS-UPD-001');
        Case updatedIns = [SELECT FEC_Contract_Number__c, FEC_Account_Number__c FROM Case WHERE Id = :cIns.Id];
        System.assertEquals('INS-UPD-001', updatedIns.FEC_Contract_Number__c,
            'ContractNumber phải được set cho Insurance');
        System.assertEquals(null, updatedIns.FEC_Account_Number__c,
            'AccountNumber phải null cho Insurance');
    }

    /* ================================================================
     * TEST 13 – createHistory: kịch bản thành công + validation lỗi
     * ================================================================ */
    @IsTest
    static void testCreateHistory_Loan_Success() {
        // 1. Dựng dữ liệu giả lập
        FEC_Product_Type__c pt = insertProductType(TYPE_LOAN);
        Case c = insertCase(pt.Id, null, '0956789012', false, null, null);

        // 2. Kiểm thử kịch bản thành công
        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationMock());
        FEC_AccountOrContractPicklistHandler.createHistory(
            c.Id, '12345678-123456-1234', TYPE_LOAN, 'CIF-CH', '0956789012');

        List<FEC_Customer_History__c> histories = [
            SELECT FEC_Contract_Number__c, FEC_Product_Code__c, FEC_Case__c
            FROM FEC_Customer_History__c
            WHERE FEC_Case__c = :c.Id
        ];
        System.assertEquals(1, histories.size(), 'Phải tạo được 1 Customer History');
        System.assertEquals('12345678-123456-1234', histories[0].FEC_Contract_Number__c,
            'ContractNumber phải được set cho Loan');
        System.assertEquals(TYPE_LOAN, histories[0].FEC_Product_Code__c,
            'ProductCode phải là LOAN');

        // 3. Kiểm thử kịch bản lỗi – selectedAccountContractNumber blank
        Boolean threw = false;
        try {
            FEC_AccountOrContractPicklistHandler.createHistory(
                c.Id, '   ', TYPE_LOAN, 'CIF-CH', '0956789012');
        } catch (AuraHandledException ex) {
            threw = true;
        }
        System.assertEquals(true, threw,
            'Phải throw AuraHandledException khi selectedAccountContractNumber blank');
    }

    @IsTest
    static void testCreateHistory_Card_Success() {
        // 1. Dựng dữ liệu giả lập
        FEC_Product_Type__c pt = insertProductType(TYPE_CARD);
        Case c = insertCase(pt.Id, null, '0967890123', false, null, null);

        // 2. Kiểm thử kịch bản thành công
        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationMock());
        FEC_AccountOrContractPicklistHandler.createHistory(
            c.Id, '4111111111111111', TYPE_CARD, 'CIF-CARD2', '0967890123');

        List<FEC_Customer_History__c> histories = [
            SELECT FEC_Account_Number__c, FEC_Product_Code__c FROM FEC_Customer_History__c
            WHERE FEC_Case__c = :c.Id];
        System.assertEquals(1, histories.size(), 'Phải tạo 1 Customer History cho Card');
        System.assertEquals('4111111111111111', histories[0].FEC_Account_Number__c,
            'AccountNumber phải được set cho Card');
        System.assertEquals(TYPE_CARD, histories[0].FEC_Product_Code__c,
            'ProductCode phải là CARD');

        // 3. Kiểm thử kịch bản lỗi – null selectedAccountContractNumber (không phải UBANK)
        Boolean threw = false;
        try {
            FEC_AccountOrContractPicklistHandler.createHistory(
                c.Id, null, TYPE_CARD, 'CIF-CARD2', '0967890123');
        } catch (AuraHandledException ex) {
            threw = true;
        }
        System.assertEquals(true, threw,
            'Phải throw AuraHandledException khi null accountContractNumber cho Card');
    }

    @IsTest
    static void testCreateHistory_UBank_SkipsNullCheck() {
        // 1. Dựng dữ liệu giả lập – UBank không cần accountContractNumber
        FEC_Product_Type__c pt = insertProductType(TYPE_UBANK);
        Case c = insertCase(pt.Id, null, null, false, null, null);

        // 2. Kiểm thử kịch bản thành công – UBank bypass null-check
        Boolean threw = false;
        try {
            FEC_AccountOrContractPicklistHandler.createHistory(
                c.Id, null, TYPE_UBANK, 'CIF-UBANK', null);
        } catch (AuraHandledException ex) {
            threw = true;
        }

        System.assertEquals(false, threw,
            'UBank không được throw exception khi accountContractNumber null');

        List<FEC_Customer_History__c> histories = [
            SELECT Name, FEC_Product_Code__c, FEC_Account_Number__c
            FROM FEC_Customer_History__c
            WHERE FEC_Case__c = :c.Id
        ];
        System.assertEquals(1, histories.size(), 'Phải tạo 1 Customer History cho UBank');
        // createHistory với accountContractNumber null → Name không set (org auto-name), assert field nghiệp vụ
        System.assertEquals(TYPE_UBANK, histories[0].FEC_Product_Code__c,
            'ProductCode phải là UBank');
        System.assertEquals(null, histories[0].FEC_Account_Number__c,
            'AccountNumber null khi không truyền số tài khoản');

        // 3. Kiểm thử kịch bản lỗi – selectedType không khớp bất kỳ loại nào + accountContractNumber null
        Boolean threwUnknown = false;
        try {
            FEC_AccountOrContractPicklistHandler.createHistory(
                c.Id, null, 'UNKNOWN_TYPE', 'CIF-X', null);
        } catch (AuraHandledException ex) {
            threwUnknown = true;
        }
        System.assertEquals(true, threwUnknown,
            'Phải throw AuraHandledException khi type không phải UBANK và account null');
    }

    /* ================================================================
     * TEST 14 – createHistoryNonExistingCustomer
     * ================================================================ */
    @IsTest
    static void testCreateHistoryNonExistingCustomer_UBank() {
        // 1. Dựng dữ liệu giả lập
        FEC_Product_Type__c pt = insertProductType(TYPE_UBANK);
        Case c = insertCase(null, null, null, false, null, null);

        // 2. Kiểm thử kịch bản thành công – UBank non-existing
        FEC_AccountOrContractPicklistHandler.createHistoryNonExistingCustomer(c.Id, TYPE_UBANK);

        List<FEC_Customer_History__c> histories = [
            SELECT Name, FEC_Account_Number__c, FEC_Customer_Type__c, FEC_Product_Code__c
            FROM FEC_Customer_History__c WHERE FEC_Case__c = :c.Id];
        System.assertEquals(1, histories.size(), 'Phải tạo 1 Customer History');
        System.assertEquals(TYPE_UBANK, histories[0].Name,
            'Name phải là PRODUCT_TYPE_UBANK');
        System.assertEquals(FEC_ConstantCommon.CUSTOMER_HISTORY_NON_EXISTING_CUSTOMER,
            histories[0].FEC_Customer_Type__c,
            'CustomerType phải là NON_EXISTING_CUSTOMER');

        // 3. Kiểm thử kịch bản lỗi – type NON_EXISTING_CUSTOMER
        Case c2 = insertCase(null, null, null, false, null, null);
        FEC_AccountOrContractPicklistHandler.createHistoryNonExistingCustomer(c2.Id, TYPE_NON_EXIST);

        List<FEC_Customer_History__c> h2 = [
            SELECT Name FROM FEC_Customer_History__c WHERE FEC_Case__c = :c2.Id];
        System.assertEquals(1, h2.size(), 'Phải tạo 1 Customer History cho NON_EXISTING_CUSTOMER');
        System.assertEquals(FEC_ConstantCommon.PRODUCT_NON_EXISTING_CUSTOMER, h2[0].Name,
            'Name phải là PRODUCT_NON_EXISTING_CUSTOMER constant');
    }

    /* ================================================================
     * TEST 15 – getInteractionFirstCustomerHistoryAccountNumber
     * ================================================================ */
    @IsTest
    static void testGetInteractionFirstCustomerHistoryAccountNumber_Loan() {
        // 1. Dựng dữ liệu giả lập – tạo 2 Customer History, Loan là cũ nhất
        Case c = insertCase(null, null, null, false, null, null);
        FEC_Customer_History__c hOld = insertCustomerHistory(
            c.Id, TYPE_LOAN, 'LOAN-FIRST-001', null, 'CIF-FIRST');
        FEC_Customer_History__c hNew = insertCustomerHistory(
            c.Id, TYPE_CARD, null, 'CARD-SECOND', 'CIF-FIRST');

        // 2. Kiểm thử kịch bản thành công – trả ContractNumber của bản ghi cũ nhất (Loan)
        String result = FEC_AccountOrContractPicklistHandler.getInteractionFirstCustomerHistoryAccountNumber(
            c.Id);

        System.assertEquals('LOAN-FIRST-001', result,
            'Phải trả FEC_Contract_Number__c của Customer History cũ nhất (Loan)');

        // 3. Kiểm thử kịch bản lỗi – caseId null → trả null
        String nullResult = FEC_AccountOrContractPicklistHandler.getInteractionFirstCustomerHistoryAccountNumber(
            null);
        System.assertEquals(null, nullResult,
            'Phải trả null khi caseId null');
    }

    @IsTest
    static void testGetInteractionFirstCustomerHistoryAccountNumber_Card() {
        // 1. Dựng dữ liệu giả lập – Customer History đầu tiên là CARD
        Case c = insertCase(null, null, null, false, null, null);
        insertCustomerHistory(c.Id, TYPE_CARD, null, 'CARD-FIRST-ACC', 'CIF-CARD-FIRST');

        // 2. Kiểm thử kịch bản thành công – trả AccountNumber của CARD
        String result = FEC_AccountOrContractPicklistHandler.getInteractionFirstCustomerHistoryAccountNumber(
            c.Id);

        System.assertEquals('CARD-FIRST-ACC', result,
            'Phải trả FEC_Account_Number__c của Customer History cũ nhất (Card)');

        // 3. Kiểm thử kịch bản lỗi – Case không có Customer History nào
        Case emptyCase = insertCase(null, null, null, false, null, null);
        String emptyResult = FEC_AccountOrContractPicklistHandler.getInteractionFirstCustomerHistoryAccountNumber(
            emptyCase.Id);
        System.assertEquals(null, emptyResult,
            'Phải trả null khi Case không có Customer History');
    }

    @IsTest
    static void testGetInteractionFirstCustomerHistoryAccountNumber_BlankProductCode() {
        // 1. Dựng dữ liệu giả lập – Customer History có FEC_Product_Code__c null
        Case c = insertCase(null, null, null, false, null, null);
        FEC_Customer_History__c h = new FEC_Customer_History__c(
            Name        = 'NO-PRODUCT-CODE',
            FEC_Case__c = c.Id
            // FEC_Product_Code__c không set → null
        );
        insert h;

        // 2. Kiểm thử kịch bản thành công – productCode blank → trả null
        String result = FEC_AccountOrContractPicklistHandler.getInteractionFirstCustomerHistoryAccountNumber(
            c.Id);

        System.assertEquals(null, result,
            'Phải trả null khi FEC_Product_Code__c blank/null');

        // 3. Kiểm thử kịch bản lỗi – productCode là UBANK (không match Loan/Card/Insurance) → trả null
        Case c2 = insertCase(null, null, null, false, null, null);
        insertCustomerHistory(c2.Id, TYPE_UBANK, null, TYPE_UBANK, 'CIF-UB');
        String ubankResult = FEC_AccountOrContractPicklistHandler.getInteractionFirstCustomerHistoryAccountNumber(
            c2.Id);
        System.assertEquals(null, ubankResult,
            'Phải trả null khi productCode là UBANK (không có nhánh xử lý)');
    }
}