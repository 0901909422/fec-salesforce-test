@IsTest
private class FEC_BeneficiaryBankInfoController_Test {

    @TestSetup
    static void setupData() {
        // 1. Tạo bản ghi Tỉnh/Thành phố (FEC_Province__c) hợp lệ
        FEC_Province__c province = new FEC_Province__c(
            FEC_Name_VN__c = 'Hà Nội'
        );
        insert province;

        // 2. Tạo bản ghi Tên ngân hàng (FEC_Bank_Name__c)
        FEC_Bank_Name__c bank = new FEC_Bank_Name__c(
            FEC_Bank_Name_Noaccent__c = 'VIETCOMBANK'
        );
        insert bank;

        // 3. Tạo bản ghi Chi nhánh ngân hàng (FEC_Bank_Branch__c) liên kết với ngân hàng trên
        FEC_Bank_Branch__c branch = new FEC_Bank_Branch__c(
            FEC_Bank_Branch_Name_Noaccent__c = 'CHI NHANH BA DINH',
            FEC_Bank_Name__r = bank // Gán quan hệ cho SOQL parent query
        );
        // Do là trường Lookup, ta gán field ID thực tế trước khi insert
        // Giả sử trường lookup trên hệ thống của bạn là FEC_Bank_Name__c
        Map<String, Schema.SObjectField> branchFields = FEC_Bank_Branch__c.SObjectType.getDescribe().fields.getMap();
        if (branchFields.containsKey('FEC_Bank_Name__c')) {
            branch.put('FEC_Bank_Name__c', bank.Id);
        }
        insert branch;

        // 4. Case trước — FEC_Customer_History__c.FEC_Case__c là Master-Detail (bắt buộc)
        Case testCase = new Case(
            Subject = 'Refund Bank Info Test',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone'
        );
        insert testCase;

        // 5. Customer History gắn Case, rồi liên kết ngược lên Case qua FEC_Account_or_Contract__c
        FEC_Customer_History__c customer = new FEC_Customer_History__c(
            Name = 'CUST-2026',
            FEC_Case__c = testCase.Id,
            FEC_Customer_Name__c = 'BUI VIET HOANG',
            FEC_First_Name__c = 'HOANG',
            FEC_Middle_Name__c = 'VIET',
            FEC_Last_Name__c = 'BUI'
        );
        insert customer;

        update new Case(
            Id = testCase.Id,
            FEC_Account_or_Contract__c = customer.Id
        );
    }

    /**
     * Kịch bản 1: Lấy danh sách tùy chọn ngân hàng và tỉnh thành từ DB (getBankNamePicklistOptions, getProvinceCityPicklistOptions).
     */
    @IsTest
    static void testGetPicklistOptions_Success() {
        System.runAs(testRunAsUser()) {
            Test.startTest();
            List<FEC_BeneficiaryBankInfoController.PicklistOptionDTO> bankOptions =
                FEC_BeneficiaryBankInfoController.getBankNamePicklistOptions();
            List<FEC_BeneficiaryBankInfoController.PicklistOptionDTO> provinceOptions =
                FEC_BeneficiaryBankInfoController.getProvinceCityPicklistOptions();
            List<FEC_BeneficiaryBankInfoController.PicklistOptionDTO> branchOptions =
                FEC_BeneficiaryBankInfoController.getBankBranchPicklistOptions('VIETCOMBANK');
            List<FEC_BeneficiaryBankInfoController.PicklistOptionDTO> branchEmpty =
                FEC_BeneficiaryBankInfoController.getBankBranchPicklistOptions('');
            Test.stopTest();

            System.assertNotEquals(null, bankOptions);
            System.assertNotEquals(null, provinceOptions);
            System.assertNotEquals(null, branchOptions);
            System.assertEquals(0, branchEmpty.size(), 'Truyền tên ngân hàng trống phải trả về mảng rỗng.');
        }
    }

    /**
     * Kịch bản 2: Lấy thông tin mặc định của người thụ hưởng khi Case ĐÃ CÓ sẵn tên thụ hưởng.
     */
    @IsTest
    static void testGetBeneficiaryFormDefaults_WithExistingName() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            c.FEC_Beneficiary_Name__c = 'NGUYEN VAN A';
            update c;

            Test.startTest();
            FEC_BeneficiaryBankInfoController.RefundFormDefaultsDTO dto =
                FEC_BeneficiaryBankInfoController.getBeneficiaryFormDefaults(c.Id);
            Test.stopTest();

            System.assertEquals('NGUYEN VAN A', dto.beneficiaryName, 'Nếu Case đã có tên thụ hưởng thì phải ưu tiên lấy từ Case.');
        }
    }

    /**
     * Kịch bản 3: Lấy thông tin mặc định khi Case CHƯA CÓ tên thụ hưởng (Hệ thống phải map tự động từ Customer History).
     * Bao phủ: Trường hợp có trường FEC_Customer_Name__c và trường hợp ghép từ các trường First/Middle/Last Name.
     */
    @IsTest
    static void testGetBeneficiaryFormDefaults_FromCustomerHistory() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            c.FEC_Beneficiary_Name__c = null;
            update c;

            Test.startTest();
            FEC_BeneficiaryBankInfoController.RefundFormDefaultsDTO dtoFullName =
                FEC_BeneficiaryBankInfoController.getBeneficiaryFormDefaults(c.Id);

            FEC_Customer_History__c cust = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];
            cust.FEC_Customer_Name__c = '';
            update cust;
            FEC_BeneficiaryBankInfoController.RefundFormDefaultsDTO dtoSplitName =
                FEC_BeneficiaryBankInfoController.getBeneficiaryFormDefaults(c.Id);

            FEC_BeneficiaryBankInfoController.RefundFormDefaultsDTO dtoNull =
                FEC_BeneficiaryBankInfoController.getBeneficiaryFormDefaults(null);
            Test.stopTest();

            System.assertNotEquals(null, dtoFullName.beneficiaryName);
            System.assertNotEquals(null, dtoSplitName.beneficiaryName);
            System.assertEquals(null, dtoNull.beneficiaryName);
        }
    }

    /**
     * Kịch bản 4: Lưu thông tin ngân hàng thụ hưởng chính thức (saveBeneficiaryBankInfo) thành công và các nhánh chặn lỗi tham số.
     */
    @IsTest
    static void testSaveBeneficiaryBankInfo_AllBranches() {
        System.runAs(testRunAsUser()) {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // 1. Nhánh thành công kịch bản chuẩn
        FEC_BeneficiaryBankInfoController.SaveBeneficiaryResultDTO resSuccess = 
            FEC_BeneficiaryBankInfoController.saveBeneficiaryBankInfo(c.Id, 'BUI VIET HOANG', '19030000001', 'VIETCOMBANK', 'CHI NHANH BA DINH', 'Hà Nội');

        // 2. Nhánh lỗi: Thiếu Case Id đầu vào
        FEC_BeneficiaryBankInfoController.SaveBeneficiaryResultDTO resNoCase = 
            FEC_BeneficiaryBankInfoController.saveBeneficiaryBankInfo(null, 'BUI VIET HOANG', '19030000001', 'VIETCOMBANK', 'CHI NHANH BA DINH', 'Hà Nội');

        // 3. Nhánh lỗi: Thiếu các trường thông tin thụ hưởng bắt buộc
        FEC_BeneficiaryBankInfoController.SaveBeneficiaryResultDTO resMissingFields = 
            FEC_BeneficiaryBankInfoController.saveBeneficiaryBankInfo(c.Id, '', '19030000001', 'VIETCOMBANK', 'CHI NHANH BA DINH', 'Hà Nội');

        // 4. Nhánh lỗi: Thiếu tên ngân hàng (bankPicklistValue)
        FEC_BeneficiaryBankInfoController.SaveBeneficiaryResultDTO resNoBank = 
            FEC_BeneficiaryBankInfoController.saveBeneficiaryBankInfo(c.Id, 'BUI VIET HOANG', '19030000001', '', 'CHI NHANH BA DINH', 'Hà Nội');

        // 5. Nhánh lỗi: Điền sai tên Tỉnh/Thành phố không tồn tại trong hệ thống (Validation từ isValidProvinceNameVn)
        FEC_BeneficiaryBankInfoController.SaveBeneficiaryResultDTO resBadProvince = 
            FEC_BeneficiaryBankInfoController.saveBeneficiaryBankInfo(c.Id, 'BUI VIET HOANG', '19030000001', 'VIETCOMBANK', 'CHI NHANH BA DINH', 'TINH_KHONG_TON_TAI');

        // 6. Nhánh lỗi: Truyền một ID Case ngẫu nhiên không tồn tại trong hệ thống (SOQL empty)
        Id fakeCaseId = Id.valueOf('500000000000001AAA');
        FEC_BeneficiaryBankInfoController.SaveBeneficiaryResultDTO resCaseNotFound = 
            FEC_BeneficiaryBankInfoController.saveBeneficiaryBankInfo(fakeCaseId, 'BUI VIET HOANG', '19030000001', 'VIETCOMBANK', 'CHI NHANH BA DINH', 'Hà Nội');
        Test.stopTest();

        System.assertEquals(true, resSuccess.success, 'Mọi thông tin hợp lệ phải lưu thành công.');
        System.assertEquals(false, resNoCase.success);
        System.assertEquals(false, resMissingFields.success);
        System.assertEquals(false, resNoBank.success);
        System.assertEquals(false, resBadProvince.success);
        System.assertEquals(false, resCaseNotFound.success);
        }
    }

    /**
     * Kịch bản 5: Lưu thông tin dưới dạng nháp (saveBeneficiaryBankInfoDraft) thành công và các kịch bản chặn Exception.
     */
    @IsTest
    static void testSaveBeneficiaryBankInfoDraft_AllBranches() {
        System.runAs(testRunAsUser()) {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // 1. Nhánh nháp thành công điền đầy đủ trường hợp lệ
        FEC_BeneficiaryBankInfoController.saveBeneficiaryBankInfoDraft(c.Id, 'BUI VIET HOANG', '19030000001', 'VIETCOMBANK', 'CHI NHANH BA DINH', 'Hà Nội');

        // 2. Nhánh nháp thành công cho phép bỏ trống một số trường (Tính năng lưu nháp)
        FEC_BeneficiaryBankInfoController.saveBeneficiaryBankInfoDraft(c.Id, 'BUI VIET HOANG', '', null, null, 'Hà Nội');

        // 3. Nhánh lỗi: Truyền tham số Case Id rỗng -> phải ném lỗi AuraHandledException
        Boolean isCaseNullThrown = false;
        try {
            FEC_BeneficiaryBankInfoController.saveBeneficiaryBankInfoDraft(null, 'A', '1', 'B', 'B', 'Hà Nội');
        } catch (AuraHandledException e) {
            isCaseNullThrown = true;
        }

        // 4. Nhánh lỗi: Điền sai tên Tỉnh/Thành phố khi lưu nháp đầy đủ -> phải ném lỗi AuraHandledException
        Boolean isProvinceInvalidThrown1 = false;
        try {
            FEC_BeneficiaryBankInfoController.saveBeneficiaryBankInfoDraft(c.Id, 'A', '1', 'B', 'B', 'SAI_TINH_THANH');
        } catch (AuraHandledException e) {
            isProvinceInvalidThrown1 = true;
        }

        // 5. Nhánh lỗi: Điền sai tên Tỉnh/Thành phố khi các trường ngân hàng đang trống -> phải ném lỗi AuraHandledException
        Boolean isProvinceInvalidThrown2 = false;
        try {
            FEC_BeneficiaryBankInfoController.saveBeneficiaryBankInfoDraft(c.Id, 'A', '1', '', '', 'SAI_TINH_THANH');
        } catch (AuraHandledException e) {
            isProvinceInvalidThrown2 = true;
        }

        // 6. Nhánh lỗi: Bản ghi Case không tồn tại
        Boolean isCaseNotFoundThrown = false;
        try {
            Id fakeCaseId = Id.valueOf('500000000000001AAA');
            FEC_BeneficiaryBankInfoController.saveBeneficiaryBankInfoDraft(fakeCaseId, 'A', '1', 'B', 'B', 'Hà Nội');
        } catch (AuraHandledException e) {
            isCaseNotFoundThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, isCaseNullThrown);
        System.assertEquals(true, isProvinceInvalidThrown1);
        System.assertEquals(true, isProvinceInvalidThrown2);
        System.assertEquals(true, isCaseNotFoundThrown);

        // Kiểm định lại db xem thông tin nháp cuối cùng lưu đúng không
        Case updatedCase = [SELECT FEC_Beneficiary_Name__c, FEC_Province_City__c FROM Case WHERE Id = :c.Id];
        System.assertEquals('BUI VIET HOANG', updatedCase.FEC_Beneficiary_Name__c);
        System.assertEquals('Hà Nội', updatedCase.FEC_Province_City__c);
        }
    }

    /**
     * Kịch bản 6: Ép kích hoạt khối ngoại lệ DmlException / Exception thông thường để bao phủ khối catch.
     */
    @IsTest
    static void testSaveBeneficiaryBankInfo_DmlException() {
        System.runAs(testRunAsUser()) {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // FEC_Beneficiary_Account__c max length 255 — vượt ngưỡng để kích hoạt DmlException
        String superLongAccount = '1'.repeat(300);
        
        FEC_BeneficiaryBankInfoController.SaveBeneficiaryResultDTO resultDml = 
            FEC_BeneficiaryBankInfoController.saveBeneficiaryBankInfo(c.Id, 'BUI VIET HOANG', superLongAccount, 'VIETCOMBANK', 'CHI NHANH BA DINH', 'Hà Nội');
        
        // Thử nghiệm tương tự cho luồng lưu nháp (Draft) để bao phủ khối catch DmlException
        Boolean isDraftDmlCaught = false;
        try {
            FEC_BeneficiaryBankInfoController.saveBeneficiaryBankInfoDraft(c.Id, 'BUI VIET HOANG', superLongAccount, 'VIETCOMBANK', 'CHI NHANH BA DINH', 'Hà Nội');
        } catch (AuraHandledException e) {
            isDraftDmlCaught = true;
        }
        Test.stopTest();

        System.assertEquals(false, resultDml.success, 'Khi dính lỗi DML, thuộc tính success phải trả về false.');
        System.assertNotEquals(null, resultDml.errorMessage, 'Thông báo lỗi chi tiết phải được ghi nhận.');
        System.assertEquals(true, isDraftDmlCaught, 'Luồng lưu nháp dính lỗi DML phải chuyển đổi ném thành AuraHandledException.');
        }
    }

    private static User testRunAsUser() {
        List<User> admins = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        return admins.isEmpty() ? new User(Id = UserInfo.getUserId()) : admins[0];
    }
}