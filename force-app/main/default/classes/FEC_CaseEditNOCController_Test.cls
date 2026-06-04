@IsTest
private class FEC_CaseEditNOCController_Test {

    @TestSetup
    static void setupData() {
        // 1. Tạo cấu trúc Master Data Nature of Case nền tảng
        FEC_Product_Type__c prod = new FEC_Product_Type__c(Name = 'Credit Card', FEC_Code__c = 'CC', FEC_Active__c = true);
        insert prod;
        FEC_Category__c cat = new FEC_Category__c(Name = 'Request', FEC_Code__c = 'Request', FEC_Active__c = true); insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(Name = 'RC27', FEC_Code__c = 'RC27', FEC_Active__c = true); insert subCat;
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(Name = 'RC27.01', FEC_Code__c = 'RC27.01', FEC_Active__c = true); insert subCode;

        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'Standard Business Process', FEC_Code__c = 'STDBP', FEC_Active__c = true
        );
        insert bp;

        // 2. Tạo bản ghi ma trận tổ hợp cấu hình NOC (Nature of Case)
        // Bản ghi 1: Dành cho Khách hàng Existing và có đầy đủ Sub-Code
        FEC_Nature_of_Case__c nocFull = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Customer_Type__c = 'Existing',
            FEC_User_Group__c = 'CC',
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true
        );
        
        // Bản ghi 2: Dành cho Khách hàng Existing nhưng không chứa Sub-Code (Phục vụ hàm getNatureOfCaseWithoutSubCode)
        FEC_Nature_of_Case__c nocWithoutSubCode = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Customer_Type__c = 'Existing',
            FEC_User_Group__c = 'CC',
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true
        );
        insert new List<FEC_Nature_of_Case__c>{nocFull, nocWithoutSubCode};

        // 3. Gán User Group cho user chạy test (khớp NOC — INCLUDES trong controller)
        System.runAs(new User(Id = UserInfo.getUserId())) {
            update new User(Id = UserInfo.getUserId(), FEC_User_Group__c = 'CC');
        }

        // 4. Khởi tạo các bản ghi chức năng và Case mồi
        Case testCase = new Case(
            Subject = 'NOC Editing Test Case',
            Status = 'New',
            FEC_Customer_Type__c = 'Existing',
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_SubCategory__c = subCat.Id,
            FEC_SubCode__c = subCode.Id
        );
        insert testCase;

        // 5. Khởi tạo mồi một bản ghi lịch sử luồng (Flow History) để test hàm getOriginalNOCFromFlowHistory
        FEC_Case_Flow_History__c flowHist = new FEC_Case_Flow_History__c(
            FEC_Case__c = testCase.Id,
            FEC_Nature_of_Cases__c = nocFull.Id,
            FEC_Field_List__c = '{"propertyName": "TestValue"}'
        );
        insert flowHist;

        // 6. Khởi tạo một quy tắc Assignment Routing ảo để test cờ hasAutoRoutingAssignment
        FEC_Assignment__c routeAssignment = new FEC_Assignment__c(
            FEC_Assignment_Name__c = 'Routing Assignment NOC Test',
            FEC_Case__c = testCase.Id,
            FEC_Assignment_Type__c = 'Routing'
        );
        insert routeAssignment;
    }

    /**
     * Kịch bản 1: Kiểm tra các hàm lấy mảng ID thô của cây phân cấp danh mục NOC.
     * Bao phủ: getProductTypeIds, getCategoryIds, getSubCategoryIds, getSubCodeIds.
     */
    @IsTest
    static void testGetNocHierarchyIds() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Product_Type__c prod = [SELECT Id FROM FEC_Product_Type__c LIMIT 1];
        FEC_Category__c cat = [SELECT Id FROM FEC_Category__c LIMIT 1];
        FEC_Sub_Category__c subCat = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1];

        Test.startTest();
        List<String> prodIds = FEC_CaseEditNOCController.getProductTypeIds(c.Id);
        List<String> catIds = FEC_CaseEditNOCController.getCategoryIds(c.Id, prod.Id);
        List<String> subCatIds = FEC_CaseEditNOCController.getSubCategoryIds(c.Id, prod.Id, cat.Id);
        List<String> subCodeIds = FEC_CaseEditNOCController.getSubCodeIds(c.Id, prod.Id, cat.Id, subCat.Id);
        Test.stopTest();

        // Xác minh dữ liệu: Mảng phải trả về số lượng 1 phần tử tương ứng với cấu hình mồi hợp lệ
        System.assertEquals(1, prodIds.size());
        System.assertEquals(1, catIds.size());
        System.assertEquals(1, subCatIds.size());
        System.assertEquals(1, subCodeIds.size());
    }

    /**
     * Kịch bản 2: Kiểm tra các hàm lấy mảng đối tượng bọc Picklist LWC (FEC_CommonUltils.PicklistOption) của cây danh mục.
     * Bao phủ: getProductTypelst, getCategorylst, getSubCategorylst, getSubCodelst.
     */
    @IsTest
    static void testGetNocHierarchyPicklistOptions() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Product_Type__c prod = [SELECT Id FROM FEC_Product_Type__c LIMIT 1];
        FEC_Category__c cat = [SELECT Id FROM FEC_Category__c LIMIT 1];
        FEC_Sub_Category__c subCat = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1];

        Test.startTest();
        List<FEC_CommonUltils.PicklistOption> prodOpts = FEC_CaseEditNOCController.getProductTypelst(c.Id);
        List<FEC_CommonUltils.PicklistOption> catOpts = FEC_CaseEditNOCController.getCategorylst(c.Id, prod.Id);
        List<FEC_CommonUltils.PicklistOption> subCatOpts = FEC_CaseEditNOCController.getSubCategorylst(c.Id, prod.Id, cat.Id);
        List<FEC_CommonUltils.PicklistOption> subCodeOpts = FEC_CaseEditNOCController.getSubCodelst(c.Id, prod.Id, cat.Id, subCat.Id);
        Test.stopTest();

        System.assertEquals(1, prodOpts.size());
        System.assertEquals('Credit Card', prodOpts[0].label, 'Nhãn Label trả về phải chứa tên của Product Type.');
        System.assertEquals(1, catOpts.size());
        System.assertEquals(1, subCatOpts.size());
        System.assertEquals(1, subCodeOpts.size());
    }

    /**
     * Kịch bản 3: Kiểm tra các hàm truy vấn đối tượng bản ghi thực thể (getNatureOfCase, getCase).
     * Bao phủ: Lấy NOC theo 4 ID đầy đủ, lấy NOC chỉ gồm 3 ID (Không chứa Sub-Code), và lấy trực tiếp cấu trúc Case.
     */
    @IsTest
    static void testRecordRetrievalMethods() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Product_Type__c prod = [SELECT Id FROM FEC_Product_Type__c LIMIT 1];
        FEC_Category__c cat = [SELECT Id FROM FEC_Category__c LIMIT 1];
        FEC_Sub_Category__c subCat = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1];
        FEC_Sub_Code__c subCode = [SELECT Id FROM FEC_Sub_Code__c LIMIT 1];

        Test.startTest();
        FEC_Nature_of_Case__c nocFull = FEC_CaseEditNOCController.getNatureOfCase(prod.Id, cat.Id, subCat.Id, subCode.Id);
        FEC_Nature_of_Case__c nocWithoutSub = FEC_CaseEditNOCController.getNatureOfCaseWithoutSubCode(prod.Id, cat.Id, subCat.Id);
        Case queriedCase = FEC_CaseEditNOCController.getCase(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, nocFull);
        System.assertNotEquals(null, nocWithoutSub, 'Hệ thống phải bốc đúng bản ghi NOC không gắn SubCode.');
        System.assertEquals(c.Id, queriedCase.Id);
        System.assertNotEquals(null, queriedCase.CaseNumber);
    }

    /**
     * Kịch bản 4: Kiểm tra luồng truy xuất lịch sử Flow History và cờ cấu hình Route.
     * Bao phủ: hasAutoRoutingAssignment, getPropertyFieldsFromFlowHistory, getOriginalNOCFromFlowHistory.
     */
    @IsTest
    static void testFlowHistoryAndRoutingFlags() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        Boolean hasRouting = FEC_CaseEditNOCController.hasAutoRoutingAssignment(c.Id);
        String fieldListJson = FEC_CaseEditNOCController.getPropertyFieldsFromFlowHistory(c.Id);
        Map<String, String> nocOriginalDict = FEC_CaseEditNOCController.getOriginalNOCFromFlowHistory(c.Id);
        Test.stopTest();

        System.assertEquals(true, hasRouting, 'Case mồi đã có gán bản ghi Routing Assignment, cờ phải trả về true.');
        System.assertEquals('{"propertyName": "TestValue"}', fieldListJson);
        System.assertNotEquals(null, nocOriginalDict);
        System.assertEquals('Credit Card', nocOriginalDict.get('productType'), 'Hệ thống phải tự động liên kết chéo tên Product Type từ Lookup cha ra Map.');
    }

    /**
     * Kịch bản 5: Kích hoạt quá trình lưu vết (Save NOC) thành công và thay đổi cờ trạng thái Is_Call_API_Success.
     */
    @IsTest
    static void testSaveNOC_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Product_Type__c prod = [SELECT Id FROM FEC_Product_Type__c LIMIT 1];
        FEC_Category__c cat = [SELECT Id FROM FEC_Category__c LIMIT 1];
        FEC_Sub_Category__c subCat = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1];

        Test.startTest();
        // Gọi lưu Case kèm bộ NOC mới bỏ trống SubCode
        FEC_CaseEditNOCController.saveNOC(c.Id, prod.Id, cat.Id, subCat.Id, null);
        Test.stopTest();

        Case updatedCase = [SELECT FEC_Is_Call_API_Success__c, FEC_SubCode__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(true, updatedCase.FEC_Is_Call_API_Success__c, 'Hành động lưu cấu hình phải bật cờ API Thành công.');
        System.assertEquals(null, updatedCase.FEC_SubCode__c);
    }

    /**
     * Kịch bản 6: Kiểm tra khối bẫy lỗi Catch và xử lý ngoại lệ biên (Guard Clauses).
     * Bao phủ: Truyền các chuỗi null hoặc sai định dạng để ép luồng SOQL kích hoạt lỗi AuraHandledException.
     */
    @IsTest
    static void testExceptionCatchBlocks() {
        Test.startTest();
        
        // Nhánh lỗi 1: Tham số trống trong khối check Null riêng của hàm `getNatureOfCaseWithoutSubCode`
        FEC_Nature_of_Case__c nocNull = FEC_CaseEditNOCController.getNatureOfCaseWithoutSubCode(null, null, null);
        System.assertEquals(null, nocNull);

        // Nhánh lỗi 2: Truyền chuỗi rỗng gây sập câu lệnh SOQL lồng bên trong
        try {
            FEC_CaseEditNOCController.getProductTypeIds('');
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        // Nhánh lỗi 3: Gọi hàm getCase với Id null
        try {
            FEC_CaseEditNOCController.getCase(null);
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        // Nhánh lỗi 4: saveNOC với Case Id hợp lệ định dạng nhưng không tồn tại → AuraHandledException
        String invalidCaseId = Case.SObjectType.getDescribe().getKeyPrefix() + '000000000000';
        try {
            FEC_CaseEditNOCController.saveNOC(invalidCaseId, null, null, null, null);
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true, 'saveNOC phải ném AuraHandledException khi Case Id không tồn tại.');
        }
        
        Test.stopTest();
    }
}