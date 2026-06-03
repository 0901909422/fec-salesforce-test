@IsTest
private class FEC_AddIPP_Test {

    /* ============================================================
     * MOCK CALLOUT: Giả lập phản hồi API thành công (HTTP 200 + XML Success)
     * ============================================================ */
    private class MockSuccessCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'text/xml');
            res.setBody(
                '<?xml version="1.0" encoding="UTF-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"' +
                '                  xmlns:est="http://esbservice.fecredit.org/EStatementService/">' +
                '  <soapenv:Body>' +
                '    <est:AddIPPResponse>' +
                '      <SysResponse>' +
                '        <TransID>TXN-001</TransID>' +
                '        <DateTime>20240101120000</DateTime>' +
                '        <Status>1</Status>' +
                '        <Description>Success</Description>' +
                '      </SysResponse>' +
                '      <AccountNumber>ACC-123456</AccountNumber>' +
                '      <IPPTerm>12</IPPTerm>' +
                '      <PrincipalAmount>10000000</PrincipalAmount>' +
                '      <InstallmentAmount>900000</InstallmentAmount>' +
                '      <ConversionFee>50000</ConversionFee>' +
                '      <EMI>950000</EMI>' +
                '      <Description>Converted successfully</Description>' +
                '      <PlanNumber>PLAN-001</PlanNumber>' +
                '      <InterestRate>1.5</InterestRate>' +
                '    </est:AddIPPResponse>' +
                '  </soapenv:Body>' +
                '</soapenv:Envelope>'
            );
            return res;
        }
    }

    /* ============================================================
     * MOCK CALLOUT: Giả lập phản hồi API thất bại nghiệp vụ (HTTP 200 + XML Failed)
     * ============================================================ */
    private class MockFailureCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'text/xml');
            res.setBody(
                '<?xml version="1.0" encoding="UTF-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"' +
                '                  xmlns:est="http://esbservice.fecredit.org/EStatementService/">' +
                '  <soapenv:Body>' +
                '    <est:AddIPPResponse>' +
                '      <SysResponse>' +
                '        <TransID>TXN-002</TransID>' +
                '        <DateTime>20240101120000</DateTime>' +
                '        <Status>0</Status>' +
                '        <Description>Failed</Description>' +
                '      </SysResponse>' +
                '    </est:AddIPPResponse>' +
                '  </soapenv:Body>' +
                '</soapenv:Envelope>'
            );
            return res;
        }
    }

    /* ============================================================
     * MOCK CALLOUT: Giả lập kết nối lỗi hệ thống phía Server (HTTP 500)
     * ============================================================ */
    private class MockServerErrorCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    /* ============================================================
     * MOCK CALLOUT: Giả lập phản hồi trả về nội dung rỗng (Empty Body)
     * ============================================================ */
    private class MockEmptyBodyCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('');
            return res;
        }
    }

    /* ============================================================
     * KHOỞI TẠO DỮ LIỆU: Tạo lập bản ghi Case, Customer History và Transaction mẫu
     * ============================================================ */
    private static Map<String, Id> createTestData() {
        Case testCase = new Case(
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone',
            FEC_Is_Test_API__c = true
        );
        insert testCase;

        // FEC_Case__c (MD) + FEC_Customer_History__c (MD cha của Transaction)
        FEC_Customer_History__c history = new FEC_Customer_History__c(
            Name = 'ACC-123456',
            FEC_Case__c = testCase.Id,
            FEC_Product_Code__c = FEC_ConstantCommon.PRODUCT_TYPE_CARD,
            FEC_Account_Number__c = 'ACC-123456'
        );
        insert history;

        // Cập nhật mối quan hệ để công thức FEC_Account_Contract_Number_Text__c hoạt động
        update new Case(
            Id = testCase.Id,
            FEC_Account_or_Contract__c = history.Id
        );

        FEC_Transaction__c testTransaction = new FEC_Transaction__c(
            FEC_Customer_History__c = history.Id,
            FEC_Effective_Date__c = Date.today(),
            FEC_Transaction_Amount__c = 10000000,
            FEC_Transaction_Plan__c = 'PLAN-001',
            FEC_Transaction_Code__c = 'REF-001',
            FEC_Post_Date__c = Date.today()
        );
        insert testTransaction;

        return new Map<String, Id>{
            'caseId' => testCase.Id,
            'transactionId' => testTransaction.Id
        };
    }

    /* ------------------------------------------------------------
     * HÀM TRỢ GIÚP: Tạo IPPRequest hợp lệ điền đầy đủ các trường bắt buộc
     * ------------------------------------------------------------ */
    private static FEC_AddIPP.IPPRequest buildValidRequest() {
        FEC_AddIPP.IPPRequest req = new FEC_AddIPP.IPPRequest();
        req.accountNumber   = 'ACC-123456';
        req.effectiveDate   = Date.today();
        req.amount          = 10000000;
        req.planNumber      = 'PLAN-001';
        req.ippTerm         = 12;
        req.referenceNumber = 'REF-001';
        req.transactionPlan = 'TP-001';
        req.postingDate     = Date.today();
        req.cardNumber      = '4111111111111111';
        req.cardSeq         = 1;
        req.ippKey          = 'KEY-001';
        return req;
    }

    /* ============================================================
     * TEST 1 – getIPPRequest
     * ============================================================ */
    @IsTest
    static void testGetIPPRequest_Success() {
        // 1. Setup: Khởi tạo Case + Customer History + Transaction dữ liệu mẫu
        Map<String, Id> ids = createTestData();

        Case c = [
            SELECT FEC_Account_Contract_Number_Text__c
            FROM Case
            WHERE Id = :ids.get('caseId')
        ];
        System.assertEquals(
            'ACC-123456',
            c.FEC_Account_Contract_Number_Text__c,
            'Trường công thức phải hiển thị đúng theo Name của Customer History'
        );

        // 2. Hàm getIPPRequest chỉ map một vài trường; việc gọi API đầy đủ sẽ được bao phủ ở phần testAddIPP_Success
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());
        Boolean validationFailed = false;
        try {
            FEC_AddIPP.getIPPRequest(ids.get('caseId'), ids.get('transactionId'));
        } catch (AuraHandledException ex) {
            validationFailed = true;
        }
        System.assertEquals(
            true,
            validationFailed,
            'Hàm getIPPRequest phải dừng lại ở bước validate do thiếu các trường ippTerm/card từ Case hoặc Transaction'
        );

        // 3. Truyền tham số null phải trả về null
        System.assertEquals(null, FEC_AddIPP.getIPPRequest(null, null),
            'Phải trả về null khi giá trị caseId hoặc transactionId nhận vào là null');
    }

    @IsTest
    static void testGetIPPRequest_NullIds() {
        // 1. Khởi tạo dữ liệu giả lập – không cần tạo record thực tế, chỉ kiểm tra guard clause bảo vệ giá trị null
        FEC_AddIPP.AddIPPResult resultBothNull = FEC_AddIPP.getIPPRequest(null, null);

        System.assertEquals(null, resultBothNull,
            'Phải trả về null khi cả hai tham số đầu vào đều là null');

        // 2. Kiểm thử kịch bản lỗi biên – chỉ truyền null một trong hai Id
        Map<String, Id> ids = createTestData();

        FEC_AddIPP.AddIPPResult resultNullCase = FEC_AddIPP.getIPPRequest(null, ids.get('transactionId'));
        FEC_AddIPP.AddIPPResult resultNullTxn  = FEC_AddIPP.getIPPRequest(ids.get('caseId'), null);

        System.assertEquals(null, resultNullCase, 'Phải trả về null khi tham số caseId nhận vào là null');
        System.assertEquals(null, resultNullTxn, 'Phải trả về null khi tham số transactionId nhận vào là null');
    }

    /* ============================================================
     * TEST 2 – addIPP (Xử lý logic cốt lõi)
     * ============================================================ */
    @IsTest
    static void testAddIPP_Success() {
        // 1. Khởi tạo dữ liệu giả lập
        FEC_AddIPP.IPPRequest req = buildValidRequest();
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());

        // 2. Kiểm thử kịch bản thành công khi tích hợp gọi API
        FEC_AddIPP.AddIPPResult result = FEC_AddIPP.addIPP(req, true);

        System.assertNotEquals(null, result, 'Kết quả trả về không được rỗng (null)');
        System.assertEquals(true, result.success, 'Gọi API thành công phải trả về trường success = true');
        System.assertEquals('TXN-001', result.transId, 'Mã transId phải khớp chính xác với nội dung phản hồi từ Mock');
        System.assertEquals(200, result.httpStatus, 'Mã trạng thái phản hồi HTTP status phải là 200');
        System.assertEquals('ACC-123456', result.accountNumber, 'Trường số tài khoản accountNumber phải khớp');
        System.assertEquals(12, result.ippTerm, 'Thời hạn trả góp IPPTerm phải là 12');
        System.assertEquals(10000000, result.principalAmount, 'Số tiền gốc PrincipalAmount phải chính xác');
        System.assertEquals(900000, result.installmentAmount, 'Số tiền trả góp từng kỳ InstallmentAmount phải chính xác');
        System.assertEquals(50000, result.conversionFee, 'Phí chuyển đổi conversionFee phải chính xác');
        System.assertEquals(950000, result.emi, 'Số tiền EMI phải trùng khớp');
        System.assertEquals('PLAN-001', result.planNumber, 'Mã kế hoạch planNumber phải trùng khớp');
        System.assertEquals(1.5, result.interestRate, 'Mức lãi suất interestRate phải đúng kỳ vọng');

        // 3. Kiểm thử kịch bản lỗi kết nối – hệ thống Server trả về lỗi HTTP 500
        Test.setMock(HttpCalloutMock.class, new MockServerErrorCallout());

        FEC_AddIPP.AddIPPResult errorResult = FEC_AddIPP.addIPP(buildValidRequest(), true);

        System.assertNotEquals(null, errorResult, 'Kết quả trả về không được rỗng dù gặp lỗi hệ thống');
        System.assertEquals(false, errorResult.success, 'Hệ thống phải trả về trường success = false khi Server lỗi');
    }

    @IsTest
    static void testAddIPP_FailureResponse() {
        // 1. Khởi tạo dữ liệu giả lập
        FEC_AddIPP.IPPRequest req = buildValidRequest();
        Test.setMock(HttpCalloutMock.class, new MockFailureCallout());

        // 2. Kiểm thử kịch bản xử lý lỗi (Kết nối thành công nhưng API trả lỗi logic nghiệp vụ)
        FEC_AddIPP.AddIPPResult result = FEC_AddIPP.addIPP(req, true);

        System.assertNotEquals(null, result, 'Kết quả nhận được không được phép rỗng');
        System.assertEquals(false, result.success, 'Hệ thống phải trả về trường success = false khi Status từ API bằng 0');
        System.assertEquals('TXN-002', result.transId, 'Mã giao dịch transId nhận về phải chính xác');

        // 3. Kiểm thử kịch bản lỗi phản hồi – Nội dung XML trống (Body rỗng)
        Test.setMock(HttpCalloutMock.class, new MockEmptyBodyCallout());

        FEC_AddIPP.AddIPPResult emptyResult = FEC_AddIPP.addIPP(buildValidRequest(), true);

        System.assertEquals(false, emptyResult.success, 'Hệ thống phải trả về trường success = false khi body rỗng');
        System.assertNotEquals(null, emptyResult.errorMessage, 'Phải gán nội dung vào trường lỗi errorMessage khi phản hồi rỗng');
    }

    /* ============================================================
     * TEST 3 – buildRequestDocument
     * ============================================================ */
    @IsTest
    static void testBuildRequestDocument_Success() {
        // 1. Khởi tạo dữ liệu giả lập
        FEC_AddIPP.IPPRequest req = buildValidRequest();
        String transId  = 'TXN-TEST-001';
        String timestamp = '20240101120000';

        // 2. Kiểm thử kịch bản dựng cấu trúc XML – tạo tài liệu XML chứa đầy đủ các trường thông tin
        Dom.Document doc = FEC_AddIPP.buildRequestDocument(req, transId, timestamp);

        System.assertNotEquals(null, doc, 'Đối tượng Document khởi tạo không được rỗng');
        String xmlStr = doc.toXmlString();
        System.assert(xmlStr.contains('ACC-123456'), 'Chuỗi cấu trúc XML bắt buộc phải chứa nội dung AccountNumber');
        System.assert(xmlStr.contains('PLAN-001'),   'Chuỗi cấu trúc XML bắt buộc phải chứa nội dung PlanNumber');
        System.assert(xmlStr.contains('12'),         'Chuỗi cấu trúc XML bắt buộc phải chứa nội dung IPPTerm');
        System.assert(xmlStr.contains('REF-001'),    'Chuỗi cấu trúc XML bắt buộc phải chứa nội dung ReferenceNumber');
        System.assert(xmlStr.contains('TP-001'),     'Chuỗi cấu trúc XML bắt buộc phải chứa nội dung TransactionPlan');
        System.assert(xmlStr.contains('4111111111111111'), 'Chuỗi cấu trúc XML bắt buộc phải chứa nội dung CardNumber');
        System.assert(xmlStr.contains('KEY-001'),    'Chuỗi cấu trúc XML bắt buộc phải chứa nội dung IPPKey');
        System.assert(xmlStr.contains('TXN-TEST-001'), 'Chuỗi cấu trúc XML bắt buộc phải chứa nội dung TransID');

        // 3. Kiểm thử kịch bản biên – Request thiếu các trường không bắt buộc (Hệ thống phải chạy mượt, không lỗi)
        FEC_AddIPP.IPPRequest minimalReq = new FEC_AddIPP.IPPRequest();
        minimalReq.accountNumber   = 'ACC-MIN';
        minimalReq.effectiveDate   = Date.today();
        minimalReq.amount          = 5000000;

        Dom.Document minDoc = FEC_AddIPP.buildRequestDocument(minimalReq, transId, timestamp);

        System.assertNotEquals(null, minDoc, 'Tài liệu XML vẫn phải được khởi tạo bình thường dù chỉ truyền các trường tối thiểu');
        System.assert(minDoc.toXmlString().contains('ACC-MIN'), 'Chuỗi XML tối giản tạo ra bắt buộc phải chứa AccountNumber');
    }

    /* ============================================================
     * TEST 4 – parseResponse
     * ============================================================ */
    @IsTest
    static void testParseResponse_Success() {
        // 1. Khởi tạo dữ liệu giả lập – Chuỗi phản hồi SOAP XML cấu trúc chuẩn thành công
        String successXml =
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"' +
            '                  xmlns:est="http://esbservice.fecredit.org/EStatementService/">' +
            '  <soapenv:Body>' +
            '    <est:AddIPPResponse>' +
            '      <SysResponse>' +
            '        <TransID>TXN-PARSE-001</TransID>' +
            '        <DateTime>20240101090000</DateTime>' +
            '        <Status>1</Status>' +
            '        <Description>Success</Description>' +
            '      </SysResponse>' +
            '      <AccountNumber>ACC-PARSE</AccountNumber>' +
            '      <IPPTerm>6</IPPTerm>' +
            '      <PrincipalAmount>5000000</PrincipalAmount>' +
            '      <InstallmentAmount>850000</InstallmentAmount>' +
            '      <ConversionFee>25000</ConversionFee>' +
            '      <EMI>875000</EMI>' +
            '      <Description>OK</Description>' +
            '      <PlanNumber>PL-002</PlanNumber>' +
            '      <InterestRate>2.0</InterestRate>' +
            '    </est:AddIPPResponse>' +
            '  </soapenv:Body>' +
            '</soapenv:Envelope>';

        // 2. Kiểm thử kịch bản bóc tách dữ liệu XML thành công
        FEC_AddIPP.AddIPPResult result = FEC_AddIPP.parseResponse(successXml, 200);

        System.assertEquals(true, result.success,   'Dữ liệu cấu trúc chuẩn phải bóc tách thành công');
        System.assertEquals('TXN-PARSE-001', result.transId, 'Mã transId bóc tách được phải trùng khớp');
        System.assertEquals(1, result.status,        'Trạng thái status nhận về phải có giá trị bằng 1');
        System.assertEquals('ACC-PARSE', result.accountNumber, 'Trường số tài khoản accountNumber phải chính xác');
        System.assertEquals(6, result.ippTerm,        'Thời hạn trả góp IPPTerm bóc tách ra phải bằng 6');
        System.assertEquals(5000000, result.principalAmount, 'Số tiền gốc PrincipalAmount thu được phải chính xác');
        System.assertEquals(2.0, result.interestRate, 'Mức lãi suất InterestRate nhận về phải bằng 2.0');
        System.assertEquals(200, result.httpStatus,   'Trường trạng thái kết nối httpStatus phải lưu đúng mức 200');

        // 3. Kiểm thử kịch bản xử lý lỗi – Tham số chuỗi XML nhận vào bị null hoặc trống
        FEC_AddIPP.AddIPPResult nullResult  = FEC_AddIPP.parseResponse(null, 200);
        FEC_AddIPP.AddIPPResult emptyResult = FEC_AddIPP.parseResponse('', 200);

        System.assertEquals(false, nullResult.success, 'Hệ thống phải trả về success = false nếu chuỗi XML nhận vào là null');
        System.assertNotEquals(null, nullResult.errorMessage, 'Phải hiển thị nội dung thông báo lỗi errorMessage khi chuỗi XML là null');
        System.assertEquals(false, emptyResult.success, 'Hệ thống phải trả về success = false nếu chuỗi XML nhận vào bị trống');
    }

    @IsTest
    static void testParseResponse_InvalidXml() {
        // 1. Khởi tạo dữ liệu giả lập – Cấu trúc chuỗi XML bị lỗi định dạng nghiêm trọng
        String badXml = '<broken><xml>missing closing tags';

        // 2. Kiểm thử kịch bản xử lý ngoại lệ (Hệ thống phải bắt lỗi an toàn, không được crash ứng dụng)
        FEC_AddIPP.AddIPPResult result = FEC_AddIPP.parseResponse(badXml, 200);

        System.assertEquals(false, result.success, 'Hệ thống phải trả về success = false khi chuỗi cấu trúc định dạng XML sai');
        System.assertNotEquals(null, result.errorMessage, 'Trường thông báo lỗi errorMessage phải ghi nhận lý do lỗi phân tích cấu trúc');

        // 3. Kiểm thử kịch bản lỗi thiếu thẻ – Cấu trúc XML hợp lệ nhưng bị thiếu khối logic quan trọng SysResponse
        String noSysResponseXml =
            '<?xml version="1.0"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '  <soapenv:Body>' +
            '    <AddIPPResponse/>' +
            '  </soapenv:Body>' +
            '</soapenv:Envelope>';

        FEC_AddIPP.AddIPPResult noSysResult = FEC_AddIPP.parseResponse(noSysResponseXml, 200);

        System.assertEquals(false, noSysResult.success, 'Hệ thống phải trả về success = false khi thiếu mất node thông tin SysResponse');
        System.assertNotEquals(null, noSysResult.errorMessage, 'Trường thông báo lỗi errorMessage phải ghi nhận lý do thiếu node');
    }

    /* ============================================================
     * TEST 5 – Kiểm tra hàm validate (Kích hoạt gián tiếp thông qua hàm addIPP)
     * ============================================================ */
    @IsTest
    static void testValidate_MissingAccountNumber() {
        // 1. Khởi tạo dữ liệu giả lập – Gửi request thiếu trường bắt buộc accountNumber
        FEC_AddIPP.IPPRequest req = buildValidRequest();
        req.accountNumber = null;

        // 2. Kiểm thử kịch bản chặn lỗi (Hệ thống phải ném ra đúng loại Exception mong muốn)
        Boolean exceptionThrown = false;
        try {
            FEC_AddIPP.addIPP(req, true);
        } catch (FEC_APIServiceException ex) {
            exceptionThrown = true;
        }

        System.assertEquals(true, exceptionThrown, 'Hệ thống phải ném lỗi FEC_APIServiceException khi trường accountNumber bị null');

        // 3. Kiểm thử kịch bản lỗi vượt giới hạn – Trường accountNumber dài vượt quá 255 ký tự cho phép
        FEC_AddIPP.IPPRequest longAccReq = buildValidRequest();
        longAccReq.accountNumber = 'A'.repeat(256);

        Boolean lengthExceptionThrown = false;
        try {
            FEC_AddIPP.addIPP(longAccReq, true);
        } catch (CalloutException ex) {
            lengthExceptionThrown = true;
        }

        System.assertEquals(true, lengthExceptionThrown, 'Hệ thống phải ném lỗi CalloutException khi chiều dài trường accountNumber > 255 ký tự');
    }

    @IsTest
    static void testValidate_MissingEffectiveDate() {
        // 1. Khởi tạo dữ liệu giả lập – Gửi request thiếu trường bắt buộc effectiveDate
        FEC_AddIPP.IPPRequest req = buildValidRequest();
        req.effectiveDate = null;

        // 2. Kiểm thử kịch bản chặn lỗi (Hệ thống phải ném ra đúng loại Exception mong muốn)
        Boolean exceptionThrown = false;
        try {
            FEC_AddIPP.addIPP(req, true);
        } catch (FEC_APIServiceException ex) {
            exceptionThrown = true;
        }

        System.assertEquals(true, exceptionThrown, 'Hệ thống phải ném lỗi FEC_APIServiceException khi trường effectiveDate bị null');

        // 3. Kiểm thử kịch bản lỗi thiếu trường bắt buộc số tiền – trường amount bị null
        FEC_AddIPP.IPPRequest noAmtReq = buildValidRequest();
        noAmtReq.amount = null;

        Boolean amtException = false;
        try {
            FEC_AddIPP.addIPP(noAmtReq, true);
        } catch (AuraHandledException ex) {
            amtException = true;
        }

        System.assertEquals(true, amtException, 'Hệ thống phải ném lỗi AuraHandledException khi trường số tiền amount bị null');
    }

    @IsTest
    static void testValidate_MissingRequiredFields() {
        // 1. Khởi tạo dữ liệu giả lập – Lập danh sách các tập request mẫu, mỗi mẫu cố tình thiếu đi một trường bắt buộc riêng biệt
        Map<String, FEC_AddIPP.IPPRequest> badRequests = new Map<String, FEC_AddIPP.IPPRequest>();

        FEC_AddIPP.IPPRequest noPlan = buildValidRequest();
        noPlan.planNumber = null;
        badRequests.put('planNumber', noPlan);

        FEC_AddIPP.IPPRequest noTerm = buildValidRequest();
        noTerm.ippTerm = null;
        badRequests.put('ippTerm', noTerm);

        FEC_AddIPP.IPPRequest noRef = buildValidRequest();
        noRef.referenceNumber = null;
        badRequests.put('referenceNumber', noRef);

        FEC_AddIPP.IPPRequest noTxnPlan = buildValidRequest();
        noTxnPlan.transactionPlan = null;
        badRequests.put('transactionPlan', noTxnPlan);

        FEC_AddIPP.IPPRequest noPostDate = buildValidRequest();
        noPostDate.postingDate = null;
        badRequests.put('postingDate', noPostDate);

        FEC_AddIPP.IPPRequest noCard = buildValidRequest();
        noCard.cardNumber = null;
        badRequests.put('cardNumber', noCard);

        FEC_AddIPP.IPPRequest noCardSeq = buildValidRequest();
        noCardSeq.cardSeq = null;
        badRequests.put('cardSeq', noCardSeq);

        FEC_AddIPP.IPPRequest noIppKey = buildValidRequest();
        noIppKey.ippKey = null;
        badRequests.put('ippKey', noIppKey);

        // 2. Vòng lặp duyệt qua toàn bộ danh sách lỗi để kiểm tra khả năng chặn và ném lỗi của hàm kiểm tra dữ liệu đầu vào
        for (String fieldName : badRequests.keySet()) {
            Boolean thrown = false;
            try {
                FEC_AddIPP.addIPP(badRequests.get(fieldName), true);
            } catch (FEC_APIServiceException ex) {
                thrown = true;
            } catch (Exception ex) {
                thrown = true;
            }
            System.assertEquals(true, thrown, 'Hệ thống bắt buộc phải ném ngoại lệ khi kiểm tra dữ liệu đầu vào thiếu trường: ' + fieldName);
        }

        // 3. Kiểm thử kịch bản lỗi độ dài trường – Trường cardNumber dài vượt quá 80 ký tự cho phép
        FEC_AddIPP.IPPRequest longCard = buildValidRequest();
        longCard.cardNumber = '1'.repeat(81);

        Boolean cardLengthEx = false;
        try {
            FEC_AddIPP.addIPP(longCard, true);
        } catch (CalloutException ex) {
            cardLengthEx = true;
        }

        System.assertEquals(true, cardLengthEx, 'Hệ thống phải ném lỗi CalloutException khi chiều dài trường số thẻ cardNumber > 80 ký tự');
    }

    /* ============================================================
     * TEST 6 – Hàm addIPP chạy với tham số kiểm thử isTestApi = false (Hệ thống dùng số tài khoản mặc định hardcode)
     * ============================================================ */
    @IsTest
    static void testAddIPP_NonProductionEnvironment() {
        // 1. Khởi tạo dữ liệu giả lập – Chạy trong điều kiện môi trường non-production với biến cờ điều hướng isTestApi = false
        FEC_AddIPP.IPPRequest req = buildValidRequest();
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());

        // 2. Kiểm thử kịch bản chạy thành công – Đảm bảo hệ thống vận hành ổn định không lỗi dù số tài khoản bị đổi sang mã hardcode
        FEC_AddIPP.AddIPPResult result = FEC_AddIPP.addIPP(req, false);

        System.assertNotEquals(null, result, 'Kết quả xử lý thu về không được rỗng');

        // 3. Kiểm thử kịch bản lỗi – Chạy điều kiện isTestApi = false kết hợp giả lập lỗi kết nối từ phía Server trả về 500
        Test.setMock(HttpCalloutMock.class, new MockServerErrorCallout());

        FEC_AddIPP.AddIPPResult errResult = FEC_AddIPP.addIPP(buildValidRequest(), false);

        System.assertNotEquals(null, errResult, 'Kết quả thu về không được rỗng kể cả trong tình huống hệ thống phát sinh lỗi Server');
        System.assertEquals(false, errResult.success, 'Hệ thống phải trả về trường success = false khi Server lỗi ở môi trường non-production');
    }

    /* ============================================================
     * TEST 7 – Kiểm thử cấu trúc lớp dữ liệu bọc kết quả phản hồi (AddIPPResult Wrapper)
     * ============================================================ */
    @IsTest
    static void testAddIPPResult_Wrapper() {
        // 1. Khởi tạo dữ liệu giả lập – Gán thông tin trực tiếp bằng tay vào đối tượng kết quả mẫu
        FEC_AddIPP.AddIPPResult result = new FEC_AddIPP.AddIPPResult();

        // 2. Kiểm thử kịch bản gán và đọc dữ liệu – Đảm bảo toàn bộ các trường thông tin hoạt động bình thường
        result.transId             = 'TXN-W-001';
        result.dateTimes           = '20240101000000';
        result.status              = 1;
        result.description         = 'Success';
        result.httpStatus          = 200;
        result.rawResponse         = '<xml/>';
        result.success             = true;
        result.errorMessage        = null;
        result.accountNumber       = 'ACC-W';
        result.ippTerm             = 3;
        result.principalAmount     = 1000000;
        result.installmentAmount   = 350000;
        result.conversionFee       = 10000;
        result.emi                 = 360000;
        result.responseDescription = 'OK';
        result.planNumber          = 'PL-W';
        result.interestRate        = 0.5;

        System.assertEquals('TXN-W-001', result.transId);
        System.assertEquals(1, result.status);
        System.assertEquals(true, result.success);
        System.assertEquals(3, result.ippTerm);
        System.assertEquals(0.5, result.interestRate);

        // 3. Kiểm thử kịch bản gán trạng thái xử lý không thành công (Thất bại)
        result.success       = false;
        result.errorMessage  = 'Lỗi hệ thống';

        System.assertEquals(false, result.success, 'Trường giá trị thuộc tính success phải hiển thị là false');
        System.assertNotEquals(null, result.errorMessage, 'Trường thuộc tính lỗi errorMessage phải ghi nhận thông tin chuỗi thông báo lỗi');
    }

    /* ============================================================
     * TEST 8 – Kiểm thử cấu trúc lớp dữ liệu bọc tham số yêu cầu đầu vào (IPPRequest Wrapper)
     * ============================================================ */
    @IsTest
    static void testIPPRequest_Wrapper() {
        // 1. Khởi tạo dữ liệu giả lập – Tạo mới một thực thể bọc tham số yêu cầu đầu vào
        FEC_AddIPP.IPPRequest req = new FEC_AddIPP.IPPRequest();

        // 2. Kiểm thử kịch bản gán và đọc thông tin – Gán dữ liệu đầy đủ cho các thuộc tính bên trong lớp bọc
        req.accountNumber   = 'ACC-RQ';
        req.effectiveDate   = Date.today();
        req.amount          = 2000000;
        req.planNumber      = 'PL-RQ';
        req.ippTerm         = 24;
        req.referenceNumber = 'REF-RQ';
        req.transactionPlan = 'TP-RQ';
        req.postingDate     = Date.today();
        req.cardNumber      = '4000000000001234';
        req.cardSeq         = 2;
        req.ippKey          = 'KEY-RQ';

        System.assertEquals('ACC-RQ', req.accountNumber);
        System.assertEquals(2000000, req.amount);
        System.assertEquals(24, req.ippTerm);
        System.assertEquals(2, req.cardSeq);

        // 3. Kiểm thử kịch bản biên – Đối tượng bọc mới tạo ở trạng thái trống hoàn toàn (Chưa gán thông tin)
        FEC_AddIPP.IPPRequest emptyReq = new FEC_AddIPP.IPPRequest();
        System.assertEquals(null, emptyReq.accountNumber, 'Trường thuộc tính accountNumber mặc định ban đầu phải mang giá trị null');
        System.assertEquals(null, emptyReq.amount, 'Trường thuộc tính số tiền amount mặc định ban đầu phải mang giá trị null');
    }
}