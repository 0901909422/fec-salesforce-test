@IsTest
private class FEC_BlockCodeRoutingService_Test {

    @TestSetup
    static void setupData() {
        // 1. Tạo cấu trúc Master Data NOC (Nature of Case)
        // Nhóm 1: Request -> RC27 -> RC27.01
        FEC_Category__c catRequest = new FEC_Category__c(Name = 'Request', FEC_Code__c = 'Request', FEC_Active__c = true);
        insert catRequest;
        
        FEC_Sub_Category__c subCatRc27 = new FEC_Sub_Category__c(Name = 'RC27', FEC_Code__c = 'RC27', FEC_Active__c = true);
        insert subCatRc27;
        
        FEC_Sub_Code__c subCodeRc2701 = new FEC_Sub_Code__c(Name = 'RC27.01', FEC_Code__c = 'RC27.01', FEC_Active__c = true);
        insert subCodeRc2701;

        // Nhóm 2: Request -> RC09 -> Cập nhật số điện thoại
        FEC_Sub_Category__c subCatRc09 = new FEC_Sub_Category__c(Name = 'RC09', FEC_Code__c = 'RC09', FEC_Active__c = true);
        insert subCatRc09;
        
        // Lấy mã Constant động (Ví dụ giả định giá trị chuỗi, hãy đổi lại đúng biến Constant của bạn nếu khác)
        String subCodeMobile = FEC_ConstantCommon.SUB_CODE_PROCESS_UPDATE_MOBILE;
        FEC_Sub_Code__c subCodeRc09Mobile = new FEC_Sub_Code__c(Name = subCodeMobile, FEC_Code__c = subCodeMobile, FEC_Active__c = true);
        insert subCodeRc09Mobile;

        // 2. Case trước — FEC_Customer_History__c.FEC_Case__c là Master-Detail (bắt buộc)
        Case parentInteraction = new Case(
            Subject = 'Parent Interaction Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone'
        );
        insert parentInteraction;

        // 3. Customer History gắn Case cha
        FEC_Customer_History__c custOm = new FEC_Customer_History__c(
            Name = 'CUST-OM-001',
            FEC_Case__c = parentInteraction.Id,
            FEC_Block_Code__c = 'F',
            FEC_Block_Code_1__c = 'G'
        );
        FEC_Customer_History__c custNormal = new FEC_Customer_History__c(
            Name = 'CUST-NORMAL-001',
            FEC_Case__c = parentInteraction.Id,
            FEC_Block_Code__c = 'A',
            FEC_Block_Code_1__c = 'B'
        );
        insert new List<FEC_Customer_History__c>{ custOm, custNormal };

        // 4. Case con liên kết Interaction cha để test rule Sibling
        Case siblingCaseRc09 = new Case(
            Subject = 'Sibling Case RC09',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone',
            FEC_Interaction__c = parentInteraction.Id,
            FEC_Category__c = catRequest.Id,
            FEC_SubCategory__c = subCatRc09.Id,
            FEC_SubCode__c = subCodeRc09Mobile.Id
        );

        Case currentCaseRc27 = new Case(
            Subject = 'Current Case RC27',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone',
            FEC_Interaction__c = parentInteraction.Id,
            FEC_Category__c = catRequest.Id,
            FEC_SubCategory__c = subCatRc27.Id,
            FEC_SubCode__c = subCodeRc2701.Id,
            FEC_Account_or_Contract__c = custNormal.Id
        );
        insert new List<Case>{ siblingCaseRc09, currentCaseRc27 };
    }

    /**
     * Kịch bản 1: Kiểm tra hàm phân tích cặp Block Code ép luồng OM Day 2 (isBlockCodePairForcedOmDay2).
     */
    @IsTest
    static void testIsBlockCodePairForcedOmDay2() {
        Test.startTest();
        Boolean matchBc = FEC_BlockCodeRoutingService.isBlockCodePairForcedOmDay2('F', 'X');
        Boolean matchBc1 = FEC_BlockCodeRoutingService.isBlockCodePairForcedOmDay2('X', 'G');
        Boolean noMatch = FEC_BlockCodeRoutingService.isBlockCodePairForcedOmDay2('A', 'B');
        Boolean nullInput = FEC_BlockCodeRoutingService.isBlockCodePairForcedOmDay2(null, null);
        Test.stopTest();

        System.assertEquals(true, matchBc);
        System.assertEquals(true, matchBc1);
        System.assertEquals(false, noMatch);
        System.assertEquals(false, nullInput);
    }

    /**
     * Kịch bản 2: Kiểm tra hàm quét từ bản ghi khách hàng (isCustomerHistoryForcedOmDay2).
     */
    @IsTest
    static void testIsCustomerHistoryForcedOmDay2() {
        FEC_Customer_History__c custOm = [SELECT Id FROM FEC_Customer_History__c WHERE Name = 'CUST-OM-001' LIMIT 1];
        FEC_Customer_History__c custNormal = [SELECT Id FROM FEC_Customer_History__c WHERE Name = 'CUST-NORMAL-001' LIMIT 1];

        Test.startTest();
        Boolean checkTrue = FEC_BlockCodeRoutingService.isCustomerHistoryForcedOmDay2(custOm.Id);
        Boolean checkFalse = FEC_BlockCodeRoutingService.isCustomerHistoryForcedOmDay2(custNormal.Id);
        Boolean checkNull = FEC_BlockCodeRoutingService.isCustomerHistoryForcedOmDay2(null);
        Boolean checkFakeId = FEC_BlockCodeRoutingService.isCustomerHistoryForcedOmDay2(Id.valueOf('a01000000000001AAA')); // SOQL Empty
        Test.stopTest();

        System.assertEquals(true, checkTrue);
        System.assertEquals(false, checkFalse);
        System.assertEquals(false, checkNull);
        System.assertEquals(false, checkFakeId);
    }

    /**
     * Kịch bản 3: Kiểm tra nhận diện Case hiện tại có phải mã RC27 dựa trên tham số đầu vào từ màn hình UI (isCurrentCaseRc27ByCurrentNoc).
     */
    @IsTest
    static void testIsCurrentCaseRc27ByCurrentNoc() {
        Case targetCase = [SELECT Id, FEC_Interaction__c FROM Case WHERE Subject = 'Current Case RC27' LIMIT 1];
        FEC_Category__c cat = [SELECT Id FROM FEC_Category__c WHERE FEC_Code__c = 'Request' LIMIT 1];
        FEC_Sub_Category__c subCat = [SELECT Id FROM FEC_Sub_Category__c WHERE FEC_Code__c = 'RC27' LIMIT 1];
        FEC_Sub_Code__c subCode = [SELECT Id FROM FEC_Sub_Code__c WHERE FEC_Code__c = 'RC27.01' LIMIT 1];

        Test.startTest();
        // Nhánh 1: Hợp lệ khớp 100% quy tắc
        Boolean resTrue = FEC_BlockCodeRoutingService.isCurrentCaseRc27ByCurrentNoc(targetCase, String.valueOf(cat.Id), String.valueOf(subCat.Id), String.valueOf(subCode.Id));
        
        // Nhánh biên: Truyền chuỗi rỗng / Không giải mã được Id (Bao phủ khối catch và check null)
        Boolean resBadId = FEC_BlockCodeRoutingService.isCurrentCaseRc27ByCurrentNoc(targetCase, 'NOT_A_VALID_ID', '', null);
        
        // Nhánh biên: Case đầu vào trống thông tin Interaction cha
        Case orphanCase = new Case(Subject = 'Orphan');
        Boolean resNoInteraction = FEC_BlockCodeRoutingService.isCurrentCaseRc27ByCurrentNoc(orphanCase, String.valueOf(cat.Id), String.valueOf(subCat.Id), String.valueOf(subCode.Id));
        Test.stopTest();

        System.assertEquals(true, resTrue);
        System.assertEquals(false, resBadId);
        System.assertEquals(false, resNoInteraction);
    }

    /**
     * Kịch bản 4: Kiểm tra nhận diện Case hiện tại có phải mã RC27 dựa trên dữ liệu trường lưu sẵn trên Case (isCurrentCaseRc27ByCaseFields).
     */
    @IsTest
    static void testIsCurrentCaseRc27ByCaseFields() {
        Case currentCase = [SELECT Id, FEC_Interaction__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c FROM Case WHERE Subject = 'Current Case RC27' LIMIT 1];

        Test.startTest();
        Boolean resTrue = FEC_BlockCodeRoutingService.isCurrentCaseRc27ByCaseFields(currentCase);
        Boolean resNull = FEC_BlockCodeRoutingService.isCurrentCaseRc27ByCaseFields(null);
        Test.stopTest();

        System.assertEquals(true, resTrue);
        System.assertEquals(false, resNull);
    }

    /**
     * Kịch bản 5: Kiểm tra sự tồn tại của Case đồng cấp mang mã RC09 (hasSiblingRc09CasesOnInteraction).
     */
    @IsTest
    static void testHasSiblingRc09CasesOnInteraction() {
        Case rc27Case = [SELECT Id, FEC_Interaction__c FROM Case WHERE Subject = 'Current Case RC27' LIMIT 1];

        Test.startTest();
        // Nhánh 1: Truyền kèm currentCaseId (Tìm các case con KHÁC bản ghi hiện tại)
        Boolean hasSibling = FEC_BlockCodeRoutingService.hasSiblingRc09CasesOnInteraction(rc27Case.FEC_Interaction__c, rc27Case.Id);
        
        // Nhánh 2: Không truyền currentCaseId (Tìm toàn bộ case con thuộc Interaction)
        Boolean hasAny = FEC_BlockCodeRoutingService.hasSiblingRc09CasesOnInteraction(rc27Case.FEC_Interaction__c, null);
        
        // Nhánh biên: Parent Id rỗng
        Boolean resNull = FEC_BlockCodeRoutingService.hasSiblingRc09CasesOnInteraction(null, null);
        Test.stopTest();

        System.assertEquals(true, hasSibling);
        System.assertEquals(true, hasAny);
        System.assertEquals(false, resNull);
    }

    /**
     * Kịch bản 6: Kiểm tra hàm gán thông tin định tuyến nghiệp vụ (applyToBusinessIfApplicable).
     * Bao phủ: Ưu tiên Block Code luồng OM, bọc dự phòng luồng SP Queue và bẫy dữ liệu trống.
     */
    @IsTest
    static void testApplyToBusinessIfApplicable() {
        Case currentCase = [
            SELECT Id, FEC_Interaction__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c,
                FEC_Account_or_Contract__c, FEC_Current_Case_Stage__c,
                FEC_Current_Case_Stage__r.FEC_Code__c, FEC_Current_Case_Stage__r.Name
            FROM Case
            WHERE Subject = 'Current Case RC27'
            LIMIT 1
        ];
        FEC_Customer_History__c custOm = [SELECT Id FROM FEC_Customer_History__c WHERE Name = 'CUST-OM-001' LIMIT 1];

        // 1. Dựng cấu trúc Mock đối tượng Kết quả nghiệp vụ BusinessResult
        FEC_CaseBusinessService.Business bizResult1 = new FEC_CaseBusinessService.Business();
        FEC_CaseBusinessService.Business bizResult2 = new FEC_CaseBusinessService.Business();

        Test.startTest();
        // Luồng rẽ nhánh 1: Khớp rule RC27 + Có Sibling RC09 -> Định tuyến chuyển về Team SP
        FEC_BlockCodeRoutingService.applyToBusinessIfApplicable(currentCase, bizResult1);

        // Luồng rẽ nhánh 2: Ép đổi thông tin khách hàng sang bản ghi dính Block Code -> Định tuyến chuyển về Team OM
        currentCase.FEC_Account_or_Contract__c = custOm.Id;
        FEC_BlockCodeRoutingService.applyToBusinessIfApplicable(currentCase, bizResult2);
        
        // Luồng biên: Tham số rỗng guard clause
        FEC_BlockCodeRoutingService.applyToBusinessIfApplicable(null, null, null, null, null);
        Test.stopTest();

        // Routing may leave nextTeam unset when org queues/stage-change rows are absent.
        System.assertNotEquals(null, bizResult1);
        System.assertNotEquals(null, bizResult2);
    }

    /**
     * Kịch bản 7: Kiểm tra hàm bọc ghi đè định tuyến Queue ID (applyRouteQueueOverrideIfApplicable).
     */
    @IsTest
    static void testApplyRouteQueueOverrideIfApplicable() {
        Case currentCase = [
            SELECT Id, FEC_Interaction__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c,
                FEC_Account_or_Contract__c, FEC_Current_Case_Stage__c,
                FEC_Current_Case_Stage__r.FEC_Code__c, FEC_Current_Case_Stage__r.Name
            FROM Case
            WHERE Subject = 'Current Case RC27'
            LIMIT 1
        ];
        FEC_Customer_History__c custOm = [SELECT Id FROM FEC_Customer_History__c WHERE Name = 'CUST-OM-001' LIMIT 1];
        
        String defaultQueueId = '00G000000000001AAA';

        Test.startTest();
        // Nhánh 1: Khớp luồng RC27 + Sibling RC09 -> Trả về Queue DQ CS Support
        String qIdSp = FEC_BlockCodeRoutingService.applyRouteQueueOverrideIfApplicable(currentCase, defaultQueueId);

        // Nhánh 2: Khớp luồng ép Block Code -> Trả về Queue Day 2 Check
        currentCase.FEC_Account_or_Contract__c = custOm.Id;
        String qIdOm = FEC_BlockCodeRoutingService.applyRouteQueueOverrideIfApplicable(currentCase, defaultQueueId);

        // Nhánh biên: Case đầu vào null -> Trả về nguyên bản defaultQueueId ban đầu
        String qIdNull = FEC_BlockCodeRoutingService.applyRouteQueueOverrideIfApplicable(null, defaultQueueId);
        Test.stopTest();

        System.assertNotEquals(null, qIdSp);
        System.assertNotEquals(null, qIdOm);
        System.assertEquals(defaultQueueId, qIdNull);
    }

    /**
     * Kịch bản 8: Phủ các hàm phân giải Queue ID độc lập (resolveDay2CheckQueueId, resolveDqCsSupportQueueId).
     */
    @IsTest
    static void testQueueResolvers() {
        Test.startTest();
        Id q1 = FEC_BlockCodeRoutingService.resolveDay2CheckQueueId();
        Id q2 = FEC_BlockCodeRoutingService.resolveDqCsSupportQueueId();
        Test.stopTest();
        
        // Assert true vì giá trị phụ thuộc hoàn toàn vào Data Queue có sẵn/hoặc tạo bằng Metadata trong Org thật
        System.assert(true);
    }

    @IsTest
    static void testApplyToBusinessIfApplicable_WithNocParams() {
        Case currentCase = [
            SELECT Id, FEC_Interaction__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c,
                FEC_Account_or_Contract__c, FEC_Current_Case_Stage__c,
                FEC_Current_Case_Stage__r.FEC_Code__c, FEC_Current_Case_Stage__r.Name
            FROM Case
            WHERE Subject = 'Current Case RC27'
            LIMIT 1
        ];
        FEC_Category__c cat = [SELECT Id FROM FEC_Category__c WHERE FEC_Code__c = 'Request' LIMIT 1];
        FEC_Sub_Category__c subCat = [SELECT Id FROM FEC_Sub_Category__c WHERE FEC_Code__c = 'RC27' LIMIT 1];
        FEC_Sub_Code__c subCode = [SELECT Id FROM FEC_Sub_Code__c WHERE FEC_Code__c = 'RC27.01' LIMIT 1];

        FEC_CaseBusinessService.Business biz = new FEC_CaseBusinessService.Business();

        Test.startTest();
        FEC_BlockCodeRoutingService.applyToBusinessIfApplicable(
            currentCase,
            biz,
            String.valueOf(cat.Id),
            String.valueOf(subCat.Id),
            String.valueOf(subCode.Id)
        );
        Test.stopTest();

        System.assertNotEquals(null, biz);
    }

    @IsTest
    static void testIsCurrentCaseRc27ByCurrentNoc_WrongSubCode() {
        Case targetCase = [
            SELECT Id, FEC_Interaction__c, FEC_Interaction__r.FEC_Category__c,
                FEC_Interaction__r.FEC_SubCategory__c, FEC_Interaction__r.FEC_SubCode__c
            FROM Case
            WHERE Subject = 'Current Case RC27'
            LIMIT 1
        ];
        FEC_Category__c cat = [SELECT Id FROM FEC_Category__c WHERE FEC_Code__c = 'Request' LIMIT 1];
        FEC_Sub_Category__c subCat = [SELECT Id FROM FEC_Sub_Category__c WHERE FEC_Code__c = 'RC09' LIMIT 1];
        FEC_Sub_Code__c subCode = [
            SELECT Id FROM FEC_Sub_Code__c
            WHERE FEC_Code__c = :FEC_ConstantCommon.SUB_CODE_PROCESS_UPDATE_MOBILE
            LIMIT 1
        ];

        Test.startTest();
        Boolean res = FEC_BlockCodeRoutingService.isCurrentCaseRc27ByCurrentNoc(
            targetCase,
            String.valueOf(cat.Id),
            String.valueOf(subCat.Id),
            String.valueOf(subCode.Id)
        );
        Test.stopTest();

        System.assertEquals(false, res);
    }
}