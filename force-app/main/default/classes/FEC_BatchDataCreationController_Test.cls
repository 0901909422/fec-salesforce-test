@IsTest
private class FEC_BatchDataCreationController_Test {

    @TestSetup
    static void setupData() {
        // 1. Khởi tạo dữ liệu người dùng (User) mồi phục vụ phân giải ServiceResource qua Email
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'sruser', Email = 'res.abs@fecredit.com.vn',
            EmailEncodingKey = 'UTF-8', LastName = 'ResourceUser', LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US', ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles', UserName = 'res_abs_fec@fecredit.com.vn'
        );
        insert testUser;

        // 2. Khởi tạo ServiceResource liên kết với User vừa tạo
        ServiceResource sr = new ServiceResource(
            Name = 'Test Service Resource',
            RelatedRecordId = testUser.Id,
            IsActive = true
        );
        insert sr;

        // 3. Khởi tạo một bản ghi vắng mặt (FEC_Service_Resource_Absence__c) quá khứ để test nhánh check trùng trên Hệ thống (dbExistingKeys)
        // Lưu ý: Datetime.newInstanceGMT nhận mốc thời gian tĩnh để so khớp chính xác time.getTime()
        FEC_Service_Resource_Absence__c existingAbs = new FEC_Service_Resource_Absence__c(
            FEC_Service_Resource__c = sr.Id,
            FEC_Start_Date__c = Datetime.newInstanceGMT(2026, 6, 1, 8, 0, 0),
            FEC_End_Date__c = Datetime.newInstanceGMT(2026, 6, 1, 17, 0, 0),
            FEC_Note__c = 'Existing Absence'
        );
        insert existingAbs;

        // 4. Tạo bản ghi template mẫu để test hàm getTemplateOptions
        Schema.SObjectType templateType = Schema.getGlobalDescribe().get('FEC_Template_Import__c');
        if (templateType != null) {
            SObject testTemplate = templateType.newSObject();
            testTemplate.put('Name', 'Resource Absence Template');
            if (templateType.getDescribe().fields.getMap().containsKey('FEC_Active__c')) {
                testTemplate.put('FEC_Active__c', true);
            }
            if (templateType.getDescribe().fields.getMap().containsKey('FEC_Applicable_for__c')) {
                testTemplate.put('FEC_Applicable_for__c', 'Batch Data Creation');
            }
            insert testTemplate;

            ContentVersion cv = new ContentVersion(Title = 'Template_Abs', PathOnClient = 'Template_Abs.xlsx', VersionData = Blob.valueOf('Template Data'));
            insert cv;
            ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            ContentDocumentLink cdl = new ContentDocumentLink(LinkedEntityId = testTemplate.Id, ContentDocumentId = insertedCv.ContentDocumentId, ShareType = 'V');
            insert cdl;
        }
    }

    /**
     * Kịch bản 1: Kiểm tra hàm lấy danh sách tùy chọn cấu hình mẫu Template (getTemplateOptions).
     */
    @IsTest
    static void testGetTemplateOptions() {
        Test.startTest();
        List<FEC_BatchDataCreationController.TemplateOption> options = FEC_BatchDataCreationController.getTemplateOptions();
        Test.stopTest();

        System.assertNotEquals(null, options);
    }

    /**
     * Kịch bản 2: Kiểm tra hàm lấy danh sách lịch sử import dữ liệu gần đây (getRecentRows).
     */
    @IsTest
    static void testGetRecentRows() {
        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get('FEC_Batch_Data_Creation__c');
        if (sObjType != null) {
            SObject batchLog = sObjType.newSObject();
            Map<String, Schema.SObjectField> fMap = sObjType.getDescribe().fields.getMap();
            // Name is auto-number on FEC_Batch_Data_Creation__c; getRecentRows reads FEC_File_Name__c first.
            if (fMap.containsKey('FEC_File_Name__c')) {
                batchLog.put('FEC_File_Name__c', 'Absence_Upload.xlsx');
            }
            insert batchLog;

            // Gắn file Source đính kèm vào Batch
            ContentVersion cv = new ContentVersion(Title = 'Absence_Upload', PathOnClient = 'Absence_Upload.xlsx', VersionData = Blob.valueOf('Source Data'));
            insert cv;
            ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            
            if (fMap.containsKey('FEC_File_Content_Document_Id__c')) {
                batchLog.put('FEC_File_Content_Document_Id__c', String.valueOf(insertedCv.ContentDocumentId));
                update batchLog;
            }
            
            ContentDocumentLink cdl = new ContentDocumentLink(LinkedEntityId = batchLog.Id, ContentDocumentId = insertedCv.ContentDocumentId, ShareType = 'V');
            insert cdl;
        }

        Test.startTest();
        List<FEC_BatchDataCreationController.BatchRow> recentRows = FEC_BatchDataCreationController.getRecentRows();
        Test.stopTest();

        System.assertNotEquals(null, recentRows);
    }

    /**
     * Kịch bản 3: Xử lý import lô dữ liệu vắng mặt (Absences) - Kịch bản thành công 100%.
     * Bao phủ: Định dạng chuỗi ngày chuẩn kèm múi giờ Offset tương lai, tự động tìm kiếm ServiceResource bằng Email thành công.
     */
    @IsTest
    static void testImportBatchData_Success() {
        String base64Body = EncodingUtil.base64Encode(Blob.valueOf('Mock Excel Data'));
        
        // Tạo chuỗi JSON danh sách dòng vắng mặt hợp lệ (Mốc thời gian tương lai năm 2027 để tránh lỗi quá khứ)
        List<Map<String, String>> rowList = new List<Map<String, String>>();
        Map<String, String> validRow = new Map<String, String>{
            'serviceResource' => 'res.abs@fecredit.com.vn', // Tìm kiếm bằng Email đã tạo ở Setup
            'startDate' => '2027-06-01T08:00:00.000+0700',   // Đúng định dạng Regex PATTERN_BATCH_DATETIME_OFFSET
            'endDate' => '2027-06-01T17:00:00.000+0700',
            'note' => 'Annual leave integration'
        };
        rowList.add(validRow);
        String rowsJson = JSON.serialize(rowList);

        Test.startTest();
        FEC_BatchDataCreationController.ImportResult result = 
            FEC_BatchDataCreationController.importBatchData('Absence_Bulk_Insert.xlsx', base64Body, 'Resource Absence Template', rowsJson);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Quá trình import dữ liệu vắng mặt chuẩn phải thành công.');
        System.assertNotEquals(null, result.batchRecordId, 'Hệ thống phải cấp mã Id cho lô dữ liệu vừa import.');
    }

    /**
     * Kịch bản 4: Kiểm tra tầng validation chặn lỗi chi tiết trên từng dòng dữ liệu sai quy cách (Row-by-Row Validation Error Check).
     * Bao phủ toàn bộ các nhánh rẽ lỗi: Thiếu trường, note quá dài, định dạng ngày lỗi, ngày kết thúc trước ngày bắt đầu, ngày nằm trong quá khứ, trùng lặp trong hệ thống và trùng lặp ngay trong tệp tin Excel.
     */
    @IsTest
    static void testImportBatchData_ValidationFailures() {
        String base64Body = EncodingUtil.base64Encode(Blob.valueOf('Mock Content'));
        List<Map<String, String>> rowList = new List<Map<String, String>>();

        // Dòng lỗi 1: Trống toàn bộ các trường dữ liệu bắt buộc và Note dài quá 255 ký tự
        Map<String, String> rowErr1 = new Map<String, String>{
            'serviceResource' => '',
            'startDate' => '',
            'endDate' => '',
            'note' => 'A'.repeat(256)
        };
        
        // Dòng lỗi 2: Sai định dạng format email và sai định dạng chuỗi Datetime rỗng lỗi
        Map<String, String> rowErr2 = new Map<String, String>{
            'serviceResource' => 'not_an_email_or_id',
            'startDate' => '2026/05/19 12:00:00', // Sai cấu trúc ISO T và Offset
            'endDate' => 'invalid_datetime'
        };

        // Dòng lỗi 3: Ngày kết thúc (End Date) nằm trước ngày bắt đầu (Start Date)
        Map<String, String> rowErr3 = new Map<String, String>{
            'serviceResource' => 'res.abs@fecredit.com.vn',
            'startDate' => '2027-06-02T08:00:00.000+0700',
            'endDate' => '2027-06-01T17:00:00.000+0700' // Nhỏ hơn Start Date
        };

        // Dòng lỗi 4: Thời gian nằm trong quá khứ so với thời điểm hiện tại System.now()
        Map<String, String> rowErr4 = new Map<String, String>{
            'serviceResource' => 'res.abs@fecredit.com.vn',
            'startDate' => '2025-01-01T08:00:00.000+0700', // Năm quá khứ
            'endDate' => '2025-01-01T17:00:00.000+0700'
        };

        // Dòng lỗi 5: Trùng lặp với dữ liệu đã tồn tại sẵn trong hệ thống (dbExistingKeys - setup ở hàm SetupData mốc 2026-06-01)
        Map<String, String> rowErr5 = new Map<String, String>{
            'serviceResource' => 'res.abs@fecredit.com.vn',
            'startDate' => '2026-06-01T08:00:00.000+0000', // Chú ý: dùng offset +0000 khớp khâu ép về GMT ở Setup
            'endDate' => '2026-06-01T17:00:00.000+0000'
        };

        // Dòng lỗi 6 & 7: Hai dòng trùng lặp y xì nhau ngay trong tệp tin gửi lên (uniqueKeys - Duplicate In File)
        Map<String, String> rowErr6 = new Map<String, String>{
            'serviceResource' => 'res.abs@fecredit.com.vn',
            'startDate' => '2027-12-25T08:00:00.000+0000',
            'endDate' => '2027-12-25T17:00:00.000+0000'
        };
        Map<String, String> rowErr7 = rowErr6.clone(); // Bản sao gây lỗi trùng lặp file

        rowList.add(rowErr1);
        rowList.add(rowErr2);
        rowList.add(rowErr3);
        rowList.add(rowErr4);
        rowList.add(rowErr5);
        rowList.add(rowErr6);
        rowList.add(rowErr7);
        String rowsJson = JSON.serialize(rowList);

        Test.startTest();
        FEC_BatchDataCreationController.ImportResult result = 
            FEC_BatchDataCreationController.importBatchData('Batch_With_Validation_Errors.xlsx', base64Body, 'Resource Absence Template', rowsJson);
        Test.stopTest();

        // importBatchData: failedCount > 0 → success=false, vẫn tạo batch + resultRowsJson để xuất báo cáo
        System.assertEquals(
            false,
            result.success,
            'Import không thành công khi có dòng validation lỗi.'
        );
        System.assertNotEquals(
            null,
            result.batchRecordId,
            'Hệ thống vẫn tiếp nhận lô xử lý dòng lỗi để xuất tệp báo cáo kết quả.'
        );
        System.assertEquals('Failure', result.status);
        System.assert(
            String.isNotBlank(result.resultRowsJson) && result.resultRowsJson.contains('Failed'),
            'Chuỗi kết quả trả về bắt buộc phải chứa trạng thái Failed của các dòng lỗi.'
        );
    }

    /**
     * Kịch bản 5: Kiểm tra trường hợp đặc biệt khi chuỗi danh sách JSON truyền vào là một mảng rỗng `[]`.
     */
    @IsTest
    static void testImportBatchData_EmptyJsonArray() {
        String base64Body = EncodingUtil.base64Encode(Blob.valueOf('Empty Data'));

        Test.startTest();
        FEC_BatchDataCreationController.ImportResult result = 
            FEC_BatchDataCreationController.importBatchData('Empty_Array.xlsx', base64Body, 'Resource Absence Template', '[]');
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('Processed', result.status, 'Mảng rỗng phải kết thúc sớm với trạng thái Processed.');
    }

    /**
     * Kịch bản 6: Kiểm tra các tham số đầu vào rỗng hoặc chuỗi JSON sai cấu trúc định dạng để ép phủ khối Catch ngoại lệ.
     */
    @IsTest
    static void testImportBatchData_ParamsBlankAndException() {
        Test.startTest();
        // 1. Nhánh tham số rỗng bảo vệ biên đầu hàm
        FEC_BatchDataCreationController.ImportResult resultBlank = 
            FEC_BatchDataCreationController.importBatchData('', '', '', '');

        // 2. Nhánh lỗi cấu trúc chuỗi JSON phá vỡ hàm deserializeUntyped kích hoạt khối Catch(Exception ex)
        FEC_BatchDataCreationController.ImportResult resultException = 
            FEC_BatchDataCreationController.importBatchData('Crash_File.xlsx', 'YmFzZTY0', 'Template', '{{invalid_json_format}');
        Test.stopTest();

        System.assertEquals(false, resultBlank.success);
        System.assertEquals(false, resultException.success);
    }

    /**
     * Kịch bản 7: Kiểm tra các phương thức lưu file kết quả, ghi nhận vết sự cố độc lập (saveResultFile, logFailedImport, logFailedImportWithFile).
     */
    @IsTest
    static void testLogAndSaveResultFiles() {
        String base64File = EncodingUtil.base64Encode(Blob.valueOf('Log File Result Content Data'));

        Test.startTest();
        // 1. Lưu file kết quả đầu ra thành công
        FEC_BatchDataCreationController.saveResultFile(null, 'Result_Output.csv', base64File); // Test guard clause null Id
        
        // 2. Ghi vết sự cố log lỗi thông thường không file
        FEC_BatchDataCreationController.logFailedImport('Normal_Fail_Log.xlsx', 'Template', 'Client side validation failed completely');

        // 3. Ghi vết log lỗi đi kèm đóng gói lưu trữ tệp đính kèm nguyên bản (logFailedImportWithFile)
        Id loggedBatchId = FEC_BatchDataCreationController.logFailedImportWithFile('Client_Side_Crash.xlsx', base64File, 'Template', 'Lỗi nghiêm trọng tầng giao diện script client');
        Test.stopTest();

        System.assertNotEquals(null, loggedBatchId, 'Hàm ghi log sự cố kèm file phải khởi tạo thành công bản ghi log và cấp Id.');
    }
}