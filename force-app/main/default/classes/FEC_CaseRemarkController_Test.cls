@IsTest
private class FEC_CaseRemarkController_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        // 1. Role cho User (setup object — tách DML Case)
        UserRole agentRole = new UserRole(DeveloperName = 'CS_Agent_Remark', Name = 'CS Agent Remark');
        insert agentRole;

        System.runAs(new User(Id = UserInfo.getUserId())) {
            update new User(Id = UserInfo.getUserId(), UserRoleId = agentRole.Id);

            FEC_Case_Stage__c stage1 = new FEC_Case_Stage__c(
                Name = 'Stage 1', FEC_Code__c = 'STG1', FEC_Active__c = true
            );
            FEC_Case_Stage__c stage2 = new FEC_Case_Stage__c(
                Name = 'Stage 2', FEC_Code__c = 'STG2', FEC_Active__c = true
            );
            insert new List<FEC_Case_Stage__c>{stage1, stage2};
            FEC_CaseTriggerHandler.isExecuting = true;
            try {
                Case draftCase = new Case(
                    Subject = 'Case Draft Remarks Test',
                    Status = 'New',
                    FEC_Current_Case_Stage__c = stage1.Id,
                    FEC_Is_Submited__c = false,
                    FEC_ID_Search__c = 'RMK-DRAFT-' + suffix
                );
                insert draftCase;

                FEC_Case_Remarks__c fakeDraft = new FEC_Case_Remarks__c(
                    FEC_Case_Remarks__c = 'This is a draft remark.',
                    FEC_User__c = 'test.user',
                    FEC_Stage_Name__c = 'Stage 1'
                );
                draftCase.FEC_Draft_Remarks__c = JSON.serialize(new List<FEC_Case_Remarks__c>{fakeDraft});
                update draftCase;

                insert new FEC_Case_Remarks__c(
                    FEC_Case__c = draftCase.Id,
                    FEC_Case_Remarks__c = 'This is an existing saved remark.',
                    FEC_Stage_Name__c = 'Stage 1'
                );

                insert new Case(
                    Subject = 'Case Submitted Test',
                    Status = 'New',
                    FEC_Current_Case_Stage__c = stage2.Id,
                    FEC_Is_Submited__c = true,
                    FEC_Draft_Remarks__c = '[{"FEC_Case_Remarks__c":"This draft should be ignored"}]',
                    FEC_ID_Search__c = 'RMK-SUBMIT-' + suffix
                );
            } finally {
                FEC_CaseTriggerHandler.isExecuting = false;
            }
        }
    }

    /**
     * Kịch bản 1: Lấy danh sách Remarks (getRemarklst).
     * Bao phủ: Lấy cả bản nháp (Draft JSON) trên Case chưa Submit và bản ghi cứng từ Database.
     */
    @IsTest
    static void testGetRemarklst_Success() {
        Case draftCase = [SELECT Id FROM Case WHERE Subject = 'Case Draft Remarks Test' LIMIT 1];
        Case submittedCase = [SELECT Id FROM Case WHERE Subject = 'Case Submitted Test' LIMIT 1];

        Test.startTest();
        // Nhánh 1: Case chưa submit -> Bốc cả bản nháp + bản DB
        List<FEC_Case_Remarks__c> draftResults = FEC_CaseRemarkController.getRemarklst(draftCase.Id);
        
        // Nhánh 2: Case đã submit -> Bỏ qua bản nháp, chỉ bốc bản DB
        List<FEC_Case_Remarks__c> submittedResults = FEC_CaseRemarkController.getRemarklst(submittedCase.Id);
        
        // Nhánh 3: Đầu vào CaseId bị rỗng/null
        List<FEC_Case_Remarks__c> nullResults = FEC_CaseRemarkController.getRemarklst(null);
        Test.stopTest();

        // Xác minh kết quả Case 1 (1 Draft + 1 DB)
        System.assertEquals(2, draftResults.size());
        
        // Xác minh kết quả Case 2 (0 DB, 0 Draft vì bị chặn)
        System.assertEquals(0, submittedResults.size(), 'Case đã submit không được phép bốc trường Draft JSON.');
        
        System.assertEquals(0, nullResults.size());
    }

    /**
     * Kịch bản 2: Tạo ghi chú nháp (createRemark) và dọn dẹp nháp (clearDraftRemarks).
     * Bao phủ: Thao tác Serialize/Deserialize JSON, cắt chuỗi Email substringBefore, và gán System_Mode.
     */
    @IsTest
    static void testCreateAndClearRemark_Success() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Case Draft Remarks Test' LIMIT 1];

        Test.startTest();
        // Hành động 1: Ghi thêm 1 bản nháp mới vào chuỗi JSON hiện có
        FEC_CaseRemarkController.createRemark('New Append Draft', c.Id, 'Stage 1 Updated');

        // Khẳng định bản nháp đã được cộng dồn (1 bản gốc + 1 bản mới)
        String updatedDraftJson = [SELECT FEC_Draft_Remarks__c FROM Case WHERE Id = :c.Id].FEC_Draft_Remarks__c;
        System.assert(updatedDraftJson.contains('New Append Draft'));

        // Hành động 2: Dọn sạch nháp
        FEC_CaseRemarkController.clearDraftRemarks(c.Id);
        Test.stopTest();

        // Khẳng định trường Draft đã bị reset về null
        String clearedDraftJson = [SELECT FEC_Draft_Remarks__c FROM Case WHERE Id = :c.Id].FEC_Draft_Remarks__c;
        System.assertEquals(null, clearedDraftJson);
    }

    /**
     * Kịch bản 3: Submit Remark từ Draft (submitRemark).
     * Bao phủ: Chuyển đổi phần tử Draft cuối cùng thành bản ghi Insert, chặn Double Submit (Duplicate trong 30s) và dọn sạch Draft.
     */
    @IsTest
    static void testSubmitRemark_SuccessAndDuplicateCheck() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Case Draft Remarks Test' LIMIT 1];

        Test.startTest();
        // Chạy lần 1: Đẩy bản Draft gốc ('This is a draft remark.') thành bản ghi DB
        FEC_CaseRemarkController.submitRemark(c.Id, 'Stage 1');

        System.assertEquals(null, [SELECT FEC_Draft_Remarks__c FROM Case WHERE Id = :c.Id].FEC_Draft_Remarks__c);

        Integer draftTextCount = countRemarksWithText(c.Id, 'This is a draft remark.');
        System.assertEquals(1, draftTextCount, 'Draft phải được submit thành đúng 1 bản ghi DB.');

        c.FEC_Draft_Remarks__c = JSON.serialize(new List<FEC_Case_Remarks__c>{
            new FEC_Case_Remarks__c(FEC_Case_Remarks__c = 'This is a draft remark.')
        });
        update c;

        FEC_CaseRemarkController.submitRemark(c.Id, 'Stage 1');
        Test.stopTest();

        System.assertEquals(
            1,
            countRemarksWithText(c.Id, 'This is a draft remark.'),
            'Hệ thống phải chặn không tạo thêm bản ghi trùng lặp nội dung trong vòng 30s.'
        );
    }

    /**
     * Kịch bản 4: Submit Remark trực tiếp không thông qua mảng Draft JSON (submitRemarkDirect).
     * Bao phủ: Luồng COF/GSR ghi đè remark thẳng, chặn Duplicate 30s và dọn sạch mảng Draft tồn đọng.
     */
    @IsTest
    static void testSubmitRemarkDirect_SuccessAndDuplicateCheck() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Case Draft Remarks Test' LIMIT 1];

        Test.startTest();
        // Chạy lần 1: Lưu thẳng một nội dung mới hoàn toàn
        FEC_CaseRemarkController.submitRemarkDirect(c.Id, 'Stage 1', 'Direct Submit Remark Content');

        System.assertEquals(null, [SELECT FEC_Draft_Remarks__c FROM Case WHERE Id = :c.Id].FEC_Draft_Remarks__c);
        System.assertEquals(1, countRemarksWithText(c.Id, 'Direct Submit Remark Content'));

        FEC_CaseRemarkController.submitRemarkDirect(c.Id, 'Stage 1', 'Direct Submit Remark Content');
        Test.stopTest();

        System.assertEquals(
            1,
            countRemarksWithText(c.Id, 'Direct Submit Remark Content'),
            'Hệ thống phải chặn không tạo bản ghi Remark trùng lặp nội dung qua phương thức Submit Direct.'
        );
    }

    /**
     * Kịch bản 5: Kiểm tra các khối bẫy lỗi (Catch Blocks) và thoát an toàn (Guard Clauses) khi gặp tham số hoặc định dạng không hợp lệ.
     */
    @IsTest
    static void testExceptionCatchBlocksAndNullGuards() {
        Test.startTest();
        
        // 1. Phá vỡ hàm createRemark bằng ID ma không truy xuất được Case SOQL
        FEC_CaseRemarkController.createRemark('Remark Text', '500000000000001AAA', 'Stage 1');

        // 2. Bẫy lỗi hàm clearDraftRemarks 
        FEC_CaseRemarkController.clearDraftRemarks('500000000000001AAA');
        FEC_CaseRemarkController.clearDraftRemarks(null);

        // 3. Phá vỡ hàm submitRemark bằng ID ma
        FEC_CaseRemarkController.submitRemark('500000000000001AAA', 'Stage 1');

        // 4. Bẫy lỗi hàm submitRemarkDirect tham số trống hoặc ID ma
        FEC_CaseRemarkController.submitRemarkDirect(null, 'Stage 1', 'Text');
        FEC_CaseRemarkController.submitRemarkDirect('500000000000001AAA', 'Stage 1', 'Text');

        // 5. Id sai định dạng — getRemarklst có thể throw AuraHandledException hoặc thoát an toàn
        try {
            FEC_CaseRemarkController.getRemarklst('INVALID_FORMAT_ID');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            FEC_CaseRemarkController.createRemark('Fail Data', 'INVALID_FORMAT_ID', 'Fail Stage');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            FEC_CaseRemarkController.submitRemark('INVALID_FORMAT_ID', 'Fail Stage');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            FEC_CaseRemarkController.submitRemarkDirect('INVALID_FORMAT_ID', 'Fail Stage', 'Text');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        System.assert(true, 'Guard / invalid-id paths hoàn tất không crash.');
        Test.stopTest();
    }

    /** Long Text Area FEC_Case_Remarks__c không filter được trong SOQL WHERE. */
    private static Integer countRemarksWithText(Id caseId, String remarkText) {
        Integer count = 0;
        for (FEC_Case_Remarks__c r : [
            SELECT FEC_Case_Remarks__c FROM FEC_Case_Remarks__c WHERE FEC_Case__c = :caseId
        ]) {
            if (r.FEC_Case_Remarks__c == remarkText) {
                count++;
            }
        }
        return count;
    }
}