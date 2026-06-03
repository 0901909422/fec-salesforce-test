@IsTest
private class FEC_SubProcessService_Test {

    private static User adminUser() {
        return [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = TRUE
            LIMIT 1
        ];
    }

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);

        // 1. Tạo các danh mục (Lookup)
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Test Product',
            FEC_Code__c = 'PT' + suffix,
            FEC_Active__c = true
        );
        insert pt;

        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Test Category',
            FEC_Code__c = 'CAT' + suffix,
            FEC_Active__c = true
        );
        insert cat;

        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'Test Sub Category',
            FEC_Code__c = 'SUB' + suffix,
            FEC_Active__c = true
        );
        insert subCat;

        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'Test Sub Code',
            FEC_Code__c = 'SC' + suffix,
            FEC_Active__c = true
        );
        insert subCode;

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'Test Stage',
            FEC_Code__c = 'STG' + suffix,
            FEC_Active__c = true
        );
        insert stage;

        // 2. Tạo Nature of Case (NOC) với các cờ (flags) = true
        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Active__c = true,
            FEC_Remove_Phone__c = true,
            FEC_Do_Not_Bother__c = true,
            FEC_Transfer_Call_to_Collection__c = true
        );
        insert noc;

        // 3. Tạo Hold Case Config (Manual & Auto)
        FEC_Hold_Case_Config__c manualConfig = new FEC_Hold_Case_Config__c(
            Hold_Case_Type__c = 'Manual',
            FEC_Active__c = true,
            FEC_Case_Stage__c = stage.Id
        );
        
        FEC_Hold_Case_Config__c autoConfig = new FEC_Hold_Case_Config__c(
            Hold_Case_Type__c = 'Auto',
            FEC_Active__c = true,
            FEC_Case_Stage__c = stage.Id,
            FEC_Nature_of_Cases__c = noc.Id
        );
        insert new List<FEC_Hold_Case_Config__c>{manualConfig, autoConfig};

        // 4. Tạo Case ĐÃ Submit (Cover luồng có RecordId và getSubmitted)
        Case caseSubmitted = new Case(
            Subject = 'Test Submitted',
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_SubCategory__c = subCat.Id,
            FEC_SubCode__c = subCode.Id,
            FEC_Current_Case_Stage__c = stage.Id,
            FEC_Is_Submited__c = true,
            FEC_NFU_Description_Result__c = 'SUCCESS'
        );

        // 5. Tạo Case CHƯA Submit (Cover luồng early exit)
        Case caseNotSubmitted = new Case(
            Subject = 'Test Not Submitted',
            FEC_Is_Submited__c = false
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new List<Case>{ caseSubmitted, caseNotSubmitted };
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testGetSubProcesses_WithRecordId() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Test Submitted' LIMIT 1];

        System.runAs(adminUser()) {
            Test.startTest();
            // Truyền RecordId, các param khác null -> Code sẽ tự query Case để lấy category/product
            FEC_SubProcessService.SubProcessWrapper result = FEC_SubProcessService.getSubProcesses(
                c.Id, null, null, null, null
            );
            Test.stopTest();

        // Kiểm tra tất cả các flag phải được bật (Dựa trên dữ liệu TestSetup)
        System.assertEquals(true, result.showHoldCaseAuto, 'Hold Case Auto phải được bật (do có NFU & Config).');
        System.assertEquals(true, result.showHoldCaseManual, 'Hold Case Manual phải được bật.');
        System.assertEquals(true, result.showHoldCase, 'Hold Case tổng phải được bật.');
        System.assertEquals(true, result.showRemovePhone, 'Remove Phone phải được lấy từ NOC.');
        System.assertEquals(true, result.showDNB, 'DNB phải được lấy từ NOC.');
        System.assertEquals(true, result.showTransferCall, 'Transfer Call phải được lấy từ NOC.');
        }
    }

    @IsTest
    static void testGetSubProcesses_WithParamsOnly() {
        FEC_Nature_of_Case__c noc = [SELECT FEC_Product_Type__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c FROM FEC_Nature_of_Case__c LIMIT 1];

        Test.startTest();
        // Không truyền RecordId, chỉ truyền các ID danh mục
        FEC_SubProcessService.SubProcessWrapper result = FEC_SubProcessService.getSubProcesses(
            null, noc.FEC_Product_Type__c, noc.FEC_Category__c, noc.FEC_Sub_Category__c, noc.FEC_Sub_Code__c
        );
        Test.stopTest();

        // Cờ cấu hình từ NOC phải = true
        System.assertEquals(true, result.showRemovePhone);
        System.assertEquals(true, result.showDNB);
        // Vì RecordId null -> currentStageId null -> không tìm thấy Hold Case Config
        System.assertEquals(false, result.showHoldCaseManual); 
    }

    @IsTest
    static void testGetSubProcesses_NullParameters() {
        Test.startTest();
        // Gửi tham số null để vào khối if early exit
        FEC_SubProcessService.SubProcessWrapper result = FEC_SubProcessService.getSubProcesses(
            null, null, null, null, null
        );
        Test.stopTest();

        System.assertEquals(false, result.showRemovePhone, 'Phải return sớm và trả về kết quả rỗng.');
    }

    @IsTest
    static void testGetSubmittedSubProcesses_Submitted() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Test Submitted' LIMIT 1];

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_SubProcessService.SubProcessWrapper result =
                FEC_SubProcessService.getSubmittedSubProcesses(c.Id);
            Test.stopTest();

            // Case đã submit nên sẽ đi tiếp vào getSubProcesses và lấy config bình thường
            System.assertEquals(true, result.showRemovePhone);
        }
    }

    @IsTest
    static void testGetSubmittedSubProcesses_NotSubmitted() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Test Not Submitted' LIMIT 1];

        Test.startTest();
        FEC_SubProcessService.SubProcessWrapper result = FEC_SubProcessService.getSubmittedSubProcesses(c.Id);
        Test.stopTest();

        // Case chưa submit, code sẽ return early wrapper với các biến mặc định (false)
        System.assertEquals(false, result.showRemovePhone);
    }

    @IsTest
    static void testExceptions() {
        Test.startTest();
        try {
            FEC_SubProcessService.getSubProcesses('InvalidId', null, null, null, null);
            System.assert(false, 'Phải ném exception khi RecordId không hợp lệ.');
        } catch (Exception e) {
            System.assert(
                e instanceof AuraHandledException || e instanceof StringException,
                'Phải bắt AuraHandledException hoặc StringException.'
            );
        }
        Test.stopTest();
    }
}