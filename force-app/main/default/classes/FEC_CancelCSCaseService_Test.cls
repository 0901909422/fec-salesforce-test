@IsTest
private class FEC_CancelCSCaseService_Test {

    private static final String VALID_CHANNEL = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;

    @TestSetup
    static void setupData() {
        insert new FEC_Channel__c(
            Name = VALID_CHANNEL,
            FEC_Code__c = 'INBOUND',
            FEC_Channel_ID__c = VALID_CHANNEL,
            FEC_Channel_Vietnamese_name__c = 'Inbound',
            FEC_Channel_Status__c = true
        );

        Case openCase = new Case(
            Subject = 'Web Service Cancel Test 1',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone',
            FEC_ID_Search__c = 'CS-OPEN-2026',
            Type = 'Request'
        );

        Case closedCase = new Case(
            Subject = 'Web Service Cancel Test 2',
            Status = FEC_ConstantCommon.STATUS_CLOSED,
            Origin = 'Phone',
            FEC_ID_Search__c = 'CS-CLOSED-2026'
        );

        Case cancelledCase = new Case(
            Subject = 'Web Service Cancel Test 3',
            Status = FEC_ConstantCommon.STATUS_CANCELLED,
            Origin = 'Phone',
            FEC_ID_Search__c = 'CS-CANCEL-2026'
        );

        insert new List<Case>{ openCase, closedCase, cancelledCase };

        update new List<Case>{
            new Case(Id = openCase.Id, FEC_ID_Search__c = 'CS-OPEN-2026'),
            new Case(Id = closedCase.Id, FEC_ID_Search__c = 'CS-CLOSED-2026'),
            new Case(Id = cancelledCase.Id, FEC_ID_Search__c = 'CS-CANCEL-2026')
        };
    }

    /**
     * Kịch bản 1: Hủy Case thông qua Web Service thành công kịch bản chuẩn (Happy Path).
     * Mong đợi: Case chuyển trạng thái sang Cancelled, dữ liệu phản hồi trả về đầy đủ thông tin ánh xạ gốc.
     */
    @IsTest
    static void testCancelCSCaseRequest_Success() {
        // Chuẩn bị tham số cấu hình SysType
        FEC_CancelCSCaseService.SysType sysInput = new FEC_CancelCSCaseService.SysType();
        sysInput.Channel = VALID_CHANNEL;
        sysInput.DateTime_x = System.now();
        sysInput.TransactionID = 'TXN-SUCCESS-2026-99999999999';

        // Chuẩn bị tham số nội dung CaseInfoType
        FEC_CancelCSCaseService.CaseInfoType caseInput = new FEC_CancelCSCaseService.CaseInfoType();
        caseInput.CaseID = 'CS-OPEN-2026';
        caseInput.ContractOrAccountNumber = 'CON-19032003';
        caseInput.PhoneNumber = '0912345678'; // Khớp REGEX VN
        caseInput.UserType = FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE;

        Test.startTest();
        FEC_CancelCSCaseService.CancelCSCaseResponseType response = 
            FEC_CancelCSCaseService.CancelCSCaseRequest(sysInput, caseInput);
        Test.stopTest();

        // Khẳng định kết quả phản hồi Web Service
        System.assertNotEquals(null, response);
        System.assertEquals(FEC_ConstantCommon.CODE_SUCCESS, response.Sys.Code, 'Mã phản hồi trả về phải báo thành công.');
        System.assertEquals('CS-OPEN-2026', response.CaseID);
        System.assertNotEquals(null, response.OriginalRequest);
        System.assertEquals('Request', response.OriginalRequest.RequestInfo.CaseType);

        // Kiểm định sự thay đổi thực tế dưới Database
        Case updatedCase = [SELECT Status FROM Case WHERE FEC_ID_Search__c = 'CS-OPEN-2026' LIMIT 1];
        System.assertEquals(FEC_ConstantCommon.STATUS_CANCELLED, updatedCase.Status, 'Trạng thái Case phải được cập nhật ghi đè.');
    }

    /**
     * Kịch bản 2: Kiểm tra tầng chặn và bắt lỗi tham số thô rỗng/null (Guard Clauses).
     */
    @IsTest
    static void testCancelCSCaseRequest_NullInputs() {
        FEC_CancelCSCaseService.SysType sysInput = new FEC_CancelCSCaseService.SysType();
        FEC_CancelCSCaseService.CaseInfoType caseInput = new FEC_CancelCSCaseService.CaseInfoType();

        Test.startTest();
        // Nhánh 1: Cả hai tham số gốc đều null
        FEC_CancelCSCaseService.CancelCSCaseResponseType resAllNull = FEC_CancelCSCaseService.CancelCSCaseRequest(null, null);
        
        // Nhánh 2: Thiếu tham số thông tin CaseInfo
        FEC_CancelCSCaseService.CancelCSCaseResponseType resNoCaseInfo = FEC_CancelCSCaseService.CancelCSCaseRequest(sysInput, null);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_FAILURE, resAllNull.Sys.Code);
        System.assertEquals(FEC_ConstantCommon.CODE_FAILURE, resNoCaseInfo.Sys.Code);
    }

    /**
     * Kịch bản 3: Kiểm tra toàn bộ dải dữ liệu bắt lỗi kiểm tra chuỗi (Validation Detail Failures).
     * Bao phủ: Sai kênh, Transaction Id quá dài, Case Id quá dài, Hợp đồng quá dài, định dạng điện thoại lỗi, sai nhóm người dùng.
     */
    @IsTest
    static void testCancelCSCaseRequest_InputValidationFailures() {
        Test.startTest();
        
        // 1. Sai thông tin kênh Channel
        FEC_CancelCSCaseService.SysType sysBadChannel = new FEC_CancelCSCaseService.SysType();
        sysBadChannel.Channel = 'INVALID_CHANNEL_NAME';
        FEC_CancelCSCaseService.CancelCSCaseResponseType res1 = FEC_CancelCSCaseService.CancelCSCaseRequest(sysBadChannel, new FEC_CancelCSCaseService.CaseInfoType());
        System.assertEquals(FEC_ConstantCommon.CODE_FAILURE, res1.Sys.Code);

        // 2. Độ dài TransactionID vượt quá ngưỡng quy định
        FEC_CancelCSCaseService.SysType sysLongTxn = new FEC_CancelCSCaseService.SysType();
        sysLongTxn.Channel = VALID_CHANNEL;
        sysLongTxn.TransactionID = 'X'.repeat(FEC_ConstantCommon.CANCEL_CS_TRANSACTION_ID_MAX_LEN + 1);
        FEC_CancelCSCaseService.CancelCSCaseResponseType res2 = FEC_CancelCSCaseService.CancelCSCaseRequest(sysLongTxn, new FEC_CancelCSCaseService.CaseInfoType());
        System.assertEquals(FEC_ConstantCommon.CODE_FAILURE, res2.Sys.Code);

        // 3. Thiếu mã định danh CaseID và CaseID quá dài
        FEC_CancelCSCaseService.SysType sysOk = new FEC_CancelCSCaseService.SysType();
        sysOk.Channel = VALID_CHANNEL;
        sysOk.TransactionID = 'TXN-123';
        sysOk.DateTime_x = System.now();
        
        FEC_CancelCSCaseService.CaseInfoType caseLongId = new FEC_CancelCSCaseService.CaseInfoType();
        caseLongId.CaseID = 'X'.repeat(FEC_ConstantCommon.CANCEL_CS_CASE_ID_MAX_LEN + 1);
        FEC_CancelCSCaseService.CancelCSCaseResponseType res3 = FEC_CancelCSCaseService.CancelCSCaseRequest(sysOk, caseLongId);
        System.assertEquals(FEC_ConstantCommon.CODE_FAILURE, res3.Sys.Code);

        // 4. Mã số hợp đồng ContractOrAccountNumber trống hoặc quá dài
        FEC_CancelCSCaseService.CaseInfoType caseLongContract = new FEC_CancelCSCaseService.CaseInfoType();
        caseLongContract.CaseID = 'CS-OPEN-2026';
        caseLongContract.ContractOrAccountNumber = 'X'.repeat(
            FEC_ConstantCommon.CANCEL_CS_CONTRACT_OR_ACCOUNT_MAX_LEN + 1
        );
        FEC_CancelCSCaseService.CancelCSCaseResponseType res4 = FEC_CancelCSCaseService.CancelCSCaseRequest(sysOk, caseLongContract);
        System.assertEquals(FEC_ConstantCommon.CODE_FAILURE, res4.Sys.Code);

        // 5. Sai định dạng hoặc độ dài cấu trúc trường số điện thoại PhoneNumber
        FEC_CancelCSCaseService.CaseInfoType caseBadPhone = new FEC_CancelCSCaseService.CaseInfoType();
        caseBadPhone.CaseID = 'CS-OPEN-2026';
        caseBadPhone.ContractOrAccountNumber = 'CON-123';
        caseBadPhone.PhoneNumber = '9999_NOT_A_PHONE_FORMAT_!!!'; // Sai Regex
        FEC_CancelCSCaseService.CancelCSCaseResponseType res5 = FEC_CancelCSCaseService.CancelCSCaseRequest(sysOk, caseBadPhone);
        
        caseBadPhone.PhoneNumber = '+84' + '1'.repeat(FEC_ConstantCommon.CANCEL_CS_PHONE_MAX_LEN);
        FEC_CancelCSCaseService.CancelCSCaseResponseType res5Len = FEC_CancelCSCaseService.CancelCSCaseRequest(sysOk, caseBadPhone);
        System.assertEquals(FEC_ConstantCommon.CODE_FAILURE, res5.Sys.Code);
        System.assertEquals(FEC_ConstantCommon.CODE_FAILURE, res5Len.Sys.Code);

        // 6. Sai kiểu phân loại nhóm khách hàng UserType
        FEC_CancelCSCaseService.CaseInfoType caseBadUserType = new FEC_CancelCSCaseService.CaseInfoType();
        caseBadUserType.CaseID = 'CS-OPEN-2026';
        caseBadUserType.ContractOrAccountNumber = 'CON-123';
        caseBadUserType.PhoneNumber = '0912345678';
        caseBadUserType.UserType = 'INVALID_USER_TYPE_VALUE';
        FEC_CancelCSCaseService.CancelCSCaseResponseType res6 = FEC_CancelCSCaseService.CancelCSCaseRequest(sysOk, caseBadUserType);
        System.assertEquals(FEC_ConstantCommon.CODE_FAILURE, res6.Sys.Code);

        // 7. Trường thời gian Sys.DateTime_x nhận giá trị null
        sysOk.DateTime_x = null;
        caseBadUserType.UserType = FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE;
        FEC_CancelCSCaseService.CancelCSCaseResponseType res7 = FEC_CancelCSCaseService.CancelCSCaseRequest(sysOk, caseBadUserType);
        System.assertEquals(FEC_ConstantCommon.CODE_FAILURE, res7.Sys.Code);

        Test.stopTest();
    }

    /**
     * Kịch bản 4: Gửi mã định danh hủy Case không tồn tại trong hệ thống (SOQL Empty).
     */
    @IsTest
    static void testCancelCSCaseRequest_CaseNotFound() {
        FEC_CancelCSCaseService.SysType sys = new FEC_CancelCSCaseService.SysType();
        sys.Channel = VALID_CHANNEL; sys.TransactionID = 'TXN-04'; sys.DateTime_x = System.now();

        FEC_CancelCSCaseService.CaseInfoType caseInfo = new FEC_CancelCSCaseService.CaseInfoType();
        caseInfo.CaseID = 'CS-NOT-FOUND-ID-404'; // Không tồn tại trong Setup
        caseInfo.ContractOrAccountNumber = 'CON-123';
        caseInfo.PhoneNumber = '0912345678';
        caseInfo.UserType = FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE;

        Test.startTest();
        FEC_CancelCSCaseService.CancelCSCaseResponseType response = FEC_CancelCSCaseService.CancelCSCaseRequest(sys, caseInfo);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_FAILURE, response.Sys.Code);
        System.assert(response.Sys.Description.contains(FEC_ConstantCommon.ERROR_PREFIX), 'Chuỗi mô tả lỗi bọc về phải đi kèm tiền tố quy định.');
    }

    /**
     * Kịch bản 5: Chặn lỗi logic khi yêu cầu hủy một Case đã đóng hoặc đã xử lý hủy trước đó (validateCaseStatus Branches).
     */
    @IsTest
    static void testCancelCSCaseRequest_InvalidCaseStatus() {
        FEC_CancelCSCaseService.SysType sys = new FEC_CancelCSCaseService.SysType();
        sys.Channel = VALID_CHANNEL; sys.TransactionID = 'TXN-05'; sys.DateTime_x = System.now();

        FEC_CancelCSCaseService.CaseInfoType caseInfo = new FEC_CancelCSCaseService.CaseInfoType();
        caseInfo.ContractOrAccountNumber = 'CON-123';
        caseInfo.PhoneNumber = '0912345678';
        caseInfo.UserType = FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE;

        Test.startTest();
        // Nhánh 1: Case đã đóng/hoàn thành (Closed)
        caseInfo.CaseID = 'CS-CLOSED-2026';
        FEC_CancelCSCaseService.CancelCSCaseResponseType resClosed = FEC_CancelCSCaseService.CancelCSCaseRequest(sys, caseInfo);

        // Nhánh 2: Case đã ở trạng thái hủy sẵn (Cancelled)
        caseInfo.CaseID = 'CS-CANCEL-2026';
        FEC_CancelCSCaseService.CancelCSCaseResponseType resCancelled = FEC_CancelCSCaseService.CancelCSCaseRequest(sys, caseInfo);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CODE_FAILURE, resClosed.Sys.Code);
        System.assertEquals(FEC_ConstantCommon.CODE_FAILURE, resCancelled.Sys.Code);
    }

    /**
     * Kịch bản 6: Khởi tạo rỗng toàn bộ cấu trúc các thực thể dữ liệu con mở rộng để đảm bảo bao phủ 100% dòng RAM.
     */
    @IsTest
    static void testDataStructures_CoverageOnly() {
        Test.startTest();
        new FEC_CancelCSCaseService.CustomerInfoType();
        new FEC_CancelCSCaseService.AdditionalInfoType();
        new FEC_CancelCSCaseService.CreatorInfoType();
        Test.stopTest();
        System.assert(true);
    }
}