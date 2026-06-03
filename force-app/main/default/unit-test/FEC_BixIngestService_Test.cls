@IsTest
private class FEC_BixIngestService_Test {

    /**
     * Kịch bản 1: Kiểm tra hàm buildCompositeKey tạo khóa tổ hợp động.
     * Mong đợi: Khóa trả về đúng định dạng ghép chuỗi phân tách bởi dấu Delimiter, xử lý an toàn giá trị rỗng/null.
     */
    @IsTest
    static void testBuildCompositeKey_AndSafeMethod() {
        // Khởi tạo một bản ghi mẫu đầy đủ các trường khóa
        FEC_CustomerAdditionalInfo__c rec = new FEC_CustomerAdditionalInfo__c(
            FEC_KeyIDValue__c = 'CUST001',
            FEC_KeyIdentifier__c = 'CIF',
            FEC_FieldID__c = 'MOBI_PHONE'
        );

        // Khởi tạo một bản ghi trống để kiểm tra hàm bẫy giá trị rỗng safe() ngầm bên trong
        FEC_CustomerAdditionalInfo__c emptyRec = new FEC_CustomerAdditionalInfo__c();

        String delimiter = FEC_ConstantCommon.COMPOSITE_KEY_DELIMITER;

        Test.startTest();
        String compositeKey = FEC_BixIngestService.buildCompositeKey(rec);
        String compositeKeyEmpty = FEC_BixIngestService.buildCompositeKey(emptyRec);
        Test.stopTest();

        // Xác minh định dạng chuỗi mẫu: KeyIDValue!KeyIdentifier!FieldID
        String expectedKey = 'CUST001' + delimiter + 'CIF' + delimiter + 'MOBI_PHONE';
        System.assertEquals(expectedKey, compositeKey, 'Chuỗi khóa tổ hợp tạo ra phải trùng khớp định dạng quy định.');
        
        String expectedKeyEmpty = '' + delimiter + '' + delimiter + '';
        System.assertEquals(expectedKeyEmpty, compositeKeyEmpty, 'Bản ghi trống trường khi tạo khóa tổ hợp phải trả về các chuỗi trống an toàn.');
    }

    /**
     * Kịch bản 2: Kiểm tra hàm mapToBixRecord ánh xạ dữ liệu Salesforce sang cấu trúc bản ghi BIX DTO.
     * Mong đợi: Các trường dữ liệu chữ, số, cờ Boolean (`ISACTIVE` dạng '1'/'0'), thông tin toán ca (`CreatedById`) và thời gian GMT được gán chính xác.
     */
    @IsTest
    static void testMapToBixRecord_FieldMappingSuccess() {
        // Dựng một bản ghi mẫu giả lập đầy đủ dữ liệu hệ thống (Gán cứng các trường audit để dùng kiểm thử)
        // Lưu ý: Do CreatedDate/CreatedById là trường hệ thống không thể chỉnh sửa trực tiếp qua câu lệnh gán thông thường,
        // chúng ta giả lập bằng cách Serialize - Deserialize qua chuỗi JSON.
        String currentUserId = UserInfo.getUserId();
        String jsonRecordStr = '{' +
            '"FEC_KeyIdentifier__c": "LEAD_ID",' +
            '"FEC_KeyIDValue__c": "00Q000000001",' +
            '"FEC_FieldID__c": "CreditScore",' +
            '"FEC_FieldValue__c": "750",' +
            '"FEC_IsActive__c": true,' +
            '"CreatedDate": "2026-05-20T12:00:00.000Z",' +
            '"CreatedById": "' + currentUserId + '",' +
            '"LastModifiedDate": "2026-05-20T13:00:00.000Z",' +
            '"LastModifiedById": "' + currentUserId + '"' +
        '}';
        FEC_CustomerAdditionalInfo__c record = (FEC_CustomerAdditionalInfo__c) JSON.deserialize(jsonRecordStr, FEC_CustomerAdditionalInfo__c.class);

        String mockIsoTimestamp = '20260520135251';

        Test.startTest();
        FEC_BixIngestService.BixRecord bix = FEC_BixIngestService.mapToBixRecord(record, mockIsoTimestamp);
        Test.stopTest();

        // Khẳng định độ chính xác của ánh xạ dữ liệu
        System.assertEquals('LEAD_ID', bix.KEYIDENTIFIER);
        System.assertEquals('00Q000000001', bix.KEYIDVALUE);
        System.assertEquals('CreditScore', bix.FIELDID);
        System.assertEquals('750', bix.FIELDVALUE);
        System.assertEquals('1', bix.ISACTIVE, 'Cờ IsActive = true phải được chuyển đổi thành chuỗi 1.');
        System.assertEquals(mockIsoTimestamp, bix.PXEXTRACTDATETIME);
        System.assertEquals(currentUserId, bix.PXCREATEOPERATOR);
        System.assertNotEquals(null, bix.PZINSKEY);
        System.assertNotEquals(null, bix.PXEXTRACTIDENTIFIER);
    }

    /**
     * Kịch bản 3: Ánh xạ dòng dữ liệu biên có cờ hoạt động mang giá trị false và trống thông tin audit.
     * Mong đợi: Cờ `ISACTIVE` trả về giá trị '0' và các trường toán tử hệ thống trả về giá trị null an toàn.
     */
    @IsTest
    static void testMapToBixRecord_InactiveAndNullAuditFields() {
        FEC_CustomerAdditionalInfo__c record = new FEC_CustomerAdditionalInfo__c(
            FEC_KeyIdentifier__c = 'LEAD_ID',
            FEC_IsActive__c = false
        );

        Test.startTest();
        FEC_BixIngestService.BixRecord bix = FEC_BixIngestService.mapToBixRecord(record, '20260520135251');
        Test.stopTest();

        System.assertEquals('0', bix.ISACTIVE, 'Cờ IsActive = false phải được chuyển đổi thành chuỗi 0.');
        System.assertEquals(null, bix.PXCREATEDATETIME, 'Trường CreatedDate trống thì giá trị quy đổi sang cấu trúc BIX phải nhận null.');
        System.assertEquals(null, bix.PXCREATEOPERATOR);
    }

    /**
     * Kịch bản 4: Kiểm tra hàm buildRequestBody đóng gói danh sách bản ghi thành chuỗi JSON Payload hoàn chỉnh.
     * Mong đợi: Chuỗi JSON trả về chứa đầy đủ tên bảng (`tableName`), cột khóa chính (`pkColumn`) và mảng dữ liệu bản ghi.
     */
    @IsTest
    static void testBuildRequestBody_SerializationSuccess() {
        List<FEC_CustomerAdditionalInfo__c> records = new List<FEC_CustomerAdditionalInfo__c>();
        records.add(new FEC_CustomerAdditionalInfo__c(FEC_KeyIdentifier__c = 'LEAD_ID', FEC_KeyIDValue__c = 'A01'));
        records.add(new FEC_CustomerAdditionalInfo__c(FEC_KeyIdentifier__c = 'LEAD_ID', FEC_KeyIDValue__c = 'A02'));

        Test.startTest();
        String jsonPayload = FEC_BixIngestService.buildRequestBody(records);
        Test.stopTest();

        System.assertNotEquals(null, jsonPayload);
        
        // Deserialize ngược chuỗi payload thu được để thẩm định cấu trúc
        FEC_BixIngestService.BixIngestRequest request = 
            (FEC_BixIngestService.BixIngestRequest) JSON.deserialize(jsonPayload, FEC_BixIngestService.BixIngestRequest.class);
            
        System.assertEquals(FEC_BixIngestService.TABLE_NAME, request.tableName, 'Tên bảng gán trong request phải chính xác.');
        System.assertEquals(FEC_BixIngestService.PK_COLUMN, request.pkColumn, 'Cột khóa chính gán trong request phải chính xác.');
        System.assertEquals(2, request.records.size(), 'Số lượng bản ghi nằm trong mảng JSON request phải khớp đầu vào.');
    }

    /**
     * Kịch bản 5a: Phân lô bình thường — payload nhỏ, tất cả bản ghi trong một lô.
     */
    @IsTest
    static void testSplitIntoBatches_SingleBatchUnderLimit() {
        List<FEC_CustomerAdditionalInfo__c> records = new List<FEC_CustomerAdditionalInfo__c>();
        records.add(new FEC_CustomerAdditionalInfo__c(FEC_KeyIdentifier__c = 'ID', FEC_KeyIDValue__c = 'R1', FEC_FieldValue__c = 'V1'));
        records.add(new FEC_CustomerAdditionalInfo__c(FEC_KeyIdentifier__c = 'ID', FEC_KeyIDValue__c = 'R2', FEC_FieldValue__c = 'V2'));
        records.add(new FEC_CustomerAdditionalInfo__c(FEC_KeyIdentifier__c = 'ID', FEC_KeyIDValue__c = 'R3', FEC_FieldValue__c = 'V3'));

        Test.startTest();
        List<List<FEC_CustomerAdditionalInfo__c>> batches = FEC_BixIngestService.splitIntoBatches(records);
        Test.stopTest();

        System.assertEquals(1, batches.size(), 'Payload nhỏ: 3 bản ghi phải nằm chung một lô.');
        System.assertEquals(3, batches[0].size());
    }

    /**
     * Kịch bản 5b: Vượt MAX_PAYLOAD_SIZE (6_000_000) — ép nhánh tách lô mới.
     * Không gán lại static final; dùng nhiều bản ghi có FIELDVALUE lớn để vượt ngưỡng thực tế.
     */
    @IsTest
    static void testSplitIntoBatches_MultipleBatchesWhenPayloadLarge() {
        String largeValue = 'X'.repeat(4000);
        List<FEC_CustomerAdditionalInfo__c> records = new List<FEC_CustomerAdditionalInfo__c>();
        for (Integer i = 0; i < 900; i++) {
            records.add(
                new FEC_CustomerAdditionalInfo__c(
                    FEC_KeyIdentifier__c = 'ID',
                    FEC_KeyIDValue__c = String.valueOf(i),
                    FEC_FieldID__c = 'F',
                    FEC_FieldValue__c = largeValue
                )
            );
        }

        Test.startTest();
        List<List<FEC_CustomerAdditionalInfo__c>> batches = FEC_BixIngestService.splitIntoBatches(records);
        Test.stopTest();

        System.assert(batches.size() > 1, 'Payload lớn phải được tách thành nhiều lô.');
        Integer total = 0;
        for (List<FEC_CustomerAdditionalInfo__c> batch : batches) {
            total += batch.size();
        }
        System.assertEquals(900, total, 'Tổng số bản ghi sau phân lô phải bằng đầu vào.');
    }

    /**
     * Kịch bản 6: Kiểm tra hàm splitIntoBatches với tham số mảng rỗng đầu vào.
     * Mong đợi: Trả về một danh sách rỗng, không phát sinh lỗi hệ thống.
     */
    @IsTest
    static void testSplitIntoBatches_EmptyInput() {
        Test.startTest();
        List<List<FEC_CustomerAdditionalInfo__c>> result = FEC_BixIngestService.splitIntoBatches(new List<FEC_CustomerAdditionalInfo__c>());
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(0, result.size(), 'Mảng đầu vào trống phải trả về kết quả phân lô trống.');
    }
}