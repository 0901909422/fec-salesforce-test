@IsTest
private class FEC_BatchCaseHandlingZipService_Test {

    @TestSetup
    static void setupData() {
        // FEC_Final_Status__c is a formula from Status; do not assign on DML.
        Id bulkCaseRtId = bulkCaseHandlingEligibleRecordTypeId();

        // 1. Tạo bản ghi Case mồi phù hợp điều kiện lọc cơ sở của CaseFilter
        Case testCase = new Case(
            Subject = 'Zip Service Test Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone',
            FEC_ID_Search__c = 'CASE-ZIP-2026'
        );
        if (bulkCaseRtId != null) {
            testCase.RecordTypeId = bulkCaseRtId;
        }
        insert testCase;
        update new Case(Id = testCase.Id, FEC_ID_Search__c = 'CASE-ZIP-2026');

        // 2. Tạo file mẫu (ContentVersion) đính kèm vào Case
        ContentVersion cv = new ContentVersion(
            Title = 'SampleAttachment',
            PathOnClient = 'SampleAttachment.pdf',
            VersionData = Blob.valueOf('Initial mock file data bytes'),
            IsMajorVersion = true
        );
        insert cv;

        // Lấy ContentDocumentId tự sinh để tạo liên kết ContentDocumentLink
        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = testCase.Id,
            ContentDocumentId = insertedCv.ContentDocumentId,
            ShareType = 'V'
        );
        insert cdl;
    }

    /**
     * Kịch bản 1: Kiểm tra hàm downloadAttachmentsZip thành công.
     * Mong đợi: Trả về thành công đối tượng ZipResult chứa file .zip và đường dẫn downloadUrl hợp lệ.
     */
    @IsTest
    static void testDownloadAttachmentsZip_Success() {
        String filtersJson = '[]'; // Không dùng bộ lọc động để quét toàn bộ dữ liệu mẫu

        Test.startTest();
        // Nhánh hợp lệ: startIndex = 1, endIndex = 1 (Lấy đúng 1 bản ghi Case mồi)
        FEC_BatchCaseHandlingZipResult result = 
            FEC_BatchCaseHandlingZipService.downloadAttachmentsZip(filtersJson, 1, 1);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Quá trình gom file nén Zip dải phân đoạn phải thành công.');
        System.assertNotEquals(null, result.downloadUrl, 'Đường dẫn downloadUrl của file zip không được null.');
        System.assert(result.fileName.endsWith('.zip'), 'Tên file trả về phải có đuôi mở rộng .zip.');
    }

    /**
     * Kịch bản 2: Kiểm tra các trường hợp biên và chặn lỗi tham số của hàm downloadAttachmentsZip.
     * Bao phủ: Tham số biên null, dải phân đoạn sai logic (endIndex < startIndex), dải offset vượt ngưỡng cấu hình 2000, và dải không tìm thấy Case/Attachment nào.
     */
    @IsTest
    static void testDownloadAttachmentsZip_ValidationAndFailures() {
        String filtersJson = '[]';

        Test.startTest();
        // Nhánh biên 1: Tham số đầu vào null hoặc sai logic dải phân đoạn
        FEC_BatchCaseHandlingZipResult resNull = FEC_BatchCaseHandlingZipService.downloadAttachmentsZip(filtersJson, null, null);
        FEC_BatchCaseHandlingZipResult resInvalidRange = FEC_BatchCaseHandlingZipService.downloadAttachmentsZip(filtersJson, 10, 5);
        FEC_BatchCaseHandlingZipResult resZero = FEC_BatchCaseHandlingZipService.downloadAttachmentsZip(filtersJson, -1, 5);

        // Nhánh biên 2: Kiểm thử ép phủ nhánh logic offsetRows > 2000 bằng cách truyền startIndex lớn
        FEC_BatchCaseHandlingZipResult resHighOffset = FEC_BatchCaseHandlingZipService.downloadAttachmentsZip(filtersJson, 2501, 2505);

        // Nhánh biên 3: Tạo một Case mới không có file đính kèm nào và dùng bộ lọc tìm chính xác Case đó để kích hoạt lỗi links.isEmpty
        Case emptyCase = new Case(
            Subject = 'No Attachment Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone',
            FEC_ID_Search__c = 'EMPTY-CASE'
        );
        Id bulkCaseRtId = bulkCaseHandlingEligibleRecordTypeId();
        if (bulkCaseRtId != null) {
            emptyCase.RecordTypeId = bulkCaseRtId;
        }
        insert emptyCase;
        update new Case(Id = emptyCase.Id, FEC_ID_Search__c = 'EMPTY-CASE');
        String filterEmpty = '[{"propertyKey":"CASE_ID","operatorKey":"equals","valueText":"EMPTY-CASE"}]';
        FEC_BatchCaseHandlingZipResult resNoAttachment = FEC_BatchCaseHandlingZipService.downloadAttachmentsZip(filterEmpty, 1, 1);
        Test.stopTest();

        System.assertEquals(false, resNull.success);
        System.assertEquals(false, resInvalidRange.success);
        System.assertEquals(false, resHighOffset.success);
        System.assertEquals(false, resNoAttachment.success);
    }

    /**
     * Kịch bản 3: Kiểm tra hàm zipExcelFiles đóng gói mảng file Base64 thành công.
     * Bao phủ: Nén file thành công, tự động xử lý đổi tên tránh trùng lặp tệp tin (File Deduplication Logic).
     */
    @IsTest
    static void testZipExcelFiles_SuccessWithDeDuplication() {
        // Chuẩn bị danh sách tệp tin đầu vào chứa nội dung mã hóa Base64
        List<Map<String, Object>> files = new List<Map<String, Object>>();
        String b64Data = EncodingUtil.base64Encode(Blob.valueOf('Mock spreadsheet data lines row text content'));

        // Cố ý thêm 3 file trùng tên hoàn toàn để ép chạy qua vòng lặp xử lý trùng tên `while(usedNames.contains(entry))`
        // Thử nghiệm cả 2 nhánh: File có đuôi mở rộng (dot > 0) và File không có đuôi mở rộng (dot <= 0)
        files.add(new Map<String, Object>{ 'fileName' => 'Report_Export.xlsx', 'base64Body' => b64Data });
        files.add(new Map<String, Object>{ 'fileName' => 'Report_Export.xlsx', 'base64Body' => b64Data }); // Trùng lần 1 -> Report_Export_1.xlsx
        files.add(new Map<String, Object>{ 'fileName' => 'Report_Export.xlsx', 'base64Body' => b64Data }); // Trùng lần 2 -> Report_Export_2.xlsx
        files.add(new Map<String, Object>{ 'fileName' => 'NODOTFILE', 'base64Body' => b64Data });
        files.add(new Map<String, Object>{ 'fileName' => 'NODOTFILE', 'base64Body' => b64Data }); // Trùng file không đuôi -> NODOTFILE_1

        Test.startTest();
        // Chạy nén với tham số tên archiveName tùy chỉnh
        FEC_BatchCaseHandlingZipResult resultCustomName = FEC_BatchCaseHandlingZipService.zipExcelFiles(files, 'CustomArchiveName');
        // Chạy nén với tham số archiveName trống để test fallback mặc định ('FilteredCasesExport')
        FEC_BatchCaseHandlingZipResult resultFallbackName = FEC_BatchCaseHandlingZipService.zipExcelFiles(files, '');
        Test.stopTest();

        System.assertEquals(true, resultCustomName.success, 'Nén mảng file Base64 phải thành công.');
        System.assertEquals(true, resultFallbackName.success);
        System.assert(resultCustomName.fileName.startsWith('CustomArchiveName_'), 'Tên file nén phải ăn theo prefix chỉ định.');
        System.assert(resultFallbackName.fileName.startsWith('FilteredCasesExport_'), 'Tên file nén fallback phải bắt đầu bằng FilteredCasesExport.');
    }

    /**
     * Kịch bản 4: Kiểm tra các nhánh rẽ lỗi và xử lý ngoại lệ biên của hàm zipExcelFiles.
     * Bao phủ: Mảng danh sách file rỗng, phần tử danh sách bị null, file thiếu tên hoặc thiếu body, lỗi giải mã Base64 (khối catch Exception).
     */
    @IsTest
    static void testZipExcelFiles_FailuresAndExceptions() {
        List<Map<String, Object>> files = new List<Map<String, Object>>();
        
        // Dòng lỗi 1: Phần tử Map nhận giá trị null hoàn toàn
        files.add(null);
        // Dòng lỗi 2: Thiếu tên tệp tin fileName
        files.add(new Map<String, Object>{ 'fileName' => '', 'base64Body' => 'YmFzZTY0' });
        // Dòng lỗi 3: Chuỗi Base64Body không hợp lệ phá vỡ quy tắc giải mã EncodingUtil (Bao phủ khối catch(Exception ex))
        files.add(new Map<String, Object>{ 'fileName' => 'Corrupted.xlsx', 'base64Body' => '!!!_NOT_A_VALID_BASE64_STRING_!!!' });

        Test.startTest();
        // Thử nghiệm truyền danh sách rỗng bảo vệ guard clause đầu hàm
        FEC_BatchCaseHandlingZipResult resEmptyList = FEC_BatchCaseHandlingZipService.zipExcelFiles(new List<Map<String, Object>>(), 'Test');
        // Thử nghiệm truyền danh sách chứa toàn các dòng lỗi ở trên
        FEC_BatchCaseHandlingZipResult resBadRows = FEC_BatchCaseHandlingZipService.zipExcelFiles(files, 'Test');
        Test.stopTest();

        System.assertEquals(false, resEmptyList.success);
        System.assertEquals(false, resBadRows.success, 'Nếu không có file nào được add thành công (added == 0) phải trả về success = false.');
    }

    /**
     * Kịch bản 5: Kiểm tra hàm tải file đính kèm của một bản ghi đơn lẻ downloadCaseAttachmentsZip.
     * Bao phủ: Tải thành công file đính kèm theo Case Id chỉ định, chặn lỗi khi truyền Case Id null.
     */
    @IsTest
    static void testDownloadCaseAttachmentsZip_SuccessAndFail() {
        Case c = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'CASE-ZIP-2026' LIMIT 1];

        Test.startTest();
        // Nhánh 1: Truyền Case Id hợp lệ
        FEC_BatchCaseHandlingZipResult resSuccess = FEC_BatchCaseHandlingZipService.downloadCaseAttachmentsZip(c.Id);
        // Nhánh 2: Truyền Case Id null bảo vệ guard clause biên
        FEC_BatchCaseHandlingZipResult resNullId = FEC_BatchCaseHandlingZipService.downloadCaseAttachmentsZip(null);
        Test.stopTest();

        System.assertEquals(true, resSuccess.success, 'Gom file nén cho một Case đơn lẻ phải thành công.');
        System.assertEquals(false, resNullId.success, 'Id đầu vào null phải trả về thành công dạng false.');
    }

    /**
     * Kịch bản 6: Kiểm tra điều kiện chặn giới hạn dung lượng tệp tin (MAX_ZIP_BYTES Limits Check).
     * Bao phủ: Chặn không cho nén tiếp và ngắt vòng lặp (`break`) hoặc trả về thông báo lỗi quá dung lượng.
     */
    @IsTest
    static void testZipService_MaxSizeBytesExceeded() {
        Case c = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'CASE-ZIP-2026' LIMIT 1];

        // Chuẩn bị dữ liệu mồi vượt quá 10MB (MAX_ZIP_BYTES = 10 * 1024 * 1024 bytes) bằng cách chèn một ContentVersion dung lượng khổng lồ.
        // Do trong Unit Test không thể tạo file vật lý > 10MB trực tiếp bằng Heap RAM một cách dễ dàng, chúng ta kiểm thử gián tiếp qua hàm zipExcelFiles
        // bằng cách tạo một chuỗi Base64 giả lập dài để vượt ngưỡng tích lũy byte totalRawBytes.
        
        List<Map<String, Object>> files = new List<Map<String, Object>>();
        // Tạo một chuỗi lớn giả lập dung lượng dữ liệu thô
        String hugeChunk = EncodingUtil.base64Encode(Blob.valueOf('A'.repeat(100000))); 
        
        // Thêm lặp nhiều phần tử để tổng dung lượng thô vượt mốc quy định
        for (Integer i = 0; i < 110; i++) {
            files.add(new Map<String, Object>{ 'fileName' => 'Large_File_' + i + '.xlsx', 'base64Body' => hugeChunk });
        }

        Test.startTest();
        FEC_BatchCaseHandlingZipResult result = FEC_BatchCaseHandlingZipService.zipExcelFiles(files, 'OverloadArchive');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Hệ thống bắt buộc phải chặn và trả về lỗi khi tổng dung lượng tệp vượt quá MAX_ZIP_BYTES.');
        System.assertEquals(System.Label.FEC_Batch_Case_Handling_Zip_Total_Size_Exceeded, result.message, 'Thông báo lỗi trả về phải khớp với nhãn hệ thống.');
    }

    private static Id bulkCaseHandlingEligibleRecordTypeId() {
        List<RecordType> rows = [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE
                SObjectType = 'Case'
                AND DeveloperName IN (
                    :FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME,
                    :FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME
                )
        ];
        for (RecordType rt : rows) {
            if (rt.DeveloperName == FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME) {
                return rt.Id;
            }
        }
        return rows.isEmpty() ? null : rows[0].Id;
    }
}