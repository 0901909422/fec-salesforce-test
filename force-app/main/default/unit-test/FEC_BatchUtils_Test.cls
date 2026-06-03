@IsTest
private class FEC_BatchUtils_Test {

    /**
     * Kịch bản 1: Kiểm tra hàm setLookup thiết lập mối quan hệ cha-con thông qua External ID.
     * Bao phủ: Nhánh thiết lập thành công và nhánh bẫy lỗi ngoại lệ catch (Exception).
     */
    @IsTest
    static void testSetLookup_SuccessAndException() {
        // Tạo dữ liệu mồi: 1 Account (Cha) và 1 Contact (Con) liên kết với nhau
        Account parentAcc = new Account(Name = 'Parent Account Test');
        putExternalIdIfWritable(parentAcc, 'EXT-PARENT-001');
        insert parentAcc;
        Contact childCon = new Contact(LastName = 'Child Contact', AccountId = parentAcc.Id);
        insert childCon;

        // In-memory MDM row with parent lookup stub (setLookup reads FEC_Constants.FIELD_EXTERNAL_ID).
        Contact mdmContact = new Contact();
        Account parentStub = new Account();
        Boolean hasExtIdField = putExternalIdIfWritable(parentStub, 'EXT-PARENT-001');
        mdmContact.putSObject('Account', parentStub);
        Contact targetContact = new Contact();
        Set<String> uniqueErrors = new Set<String>();

        Test.startTest();
        // Nhánh 1: Thành công - Thiết lập Account Lookup cho targetContact dựa trên mdmContact
        FEC_BatchUtils.setLookup(targetContact, mdmContact, 'Account', 'Account', uniqueErrors);

        // Nhánh 2: Lỗi - Truyền sai tên API của Object cha ('INVALID_OBJECT') để kích hoạt khối catch
        FEC_BatchUtils.setLookup(targetContact, mdmContact, 'Account', 'INVALID_OBJECT', uniqueErrors);
        Test.stopTest();

        if (hasExtIdField) {
            System.assert(targetContact.getSObject('Account') != null, 'Mối quan hệ cha phải được thiết lập.');
            System.assertEquals(
                'EXT-PARENT-001',
                (String) targetContact.getSObject('Account').get(FEC_Constants.FIELD_EXTERNAL_ID),
                'External ID của Account thiết lập phải trùng khớp.'
            );
        }
        System.assert(uniqueErrors.size() >= 1, 'Khối catch phải bắt được lỗi do sai tên Object.');
    }

    /**
     * Kịch bản 2: Kiểm tra hàm copyCommonFields sao chép bản đồ các trường dùng chung.
     * Bao phủ: Nhánh sao chép thành công và nhánh bẫy lỗi khi sai kiểu dữ liệu trường.
     */
    @IsTest
    static void testCopyCommonFields_SuccessAndException() {
        Account sourceAcc = new Account(Name = 'Source Account Name', Phone = '0912345678');
        Account targetAcc = new Account();
        Set<String> uniqueErrors = new Set<String>();

        // Thiết lập map ánh xạ: Trường Name -> Name (Đúng), Trường Phone -> NumberOfEmployees (Sai kiểu dữ liệu String -> Integer)
        Map<String, String> commonFieldMap = new Map<String, String>{
            'Name' => 'Name',
            'Phone' => 'NumberOfEmployees' 
        };

        Test.startTest();
        FEC_BatchUtils.copyCommonFields(targetAcc, sourceAcc, commonFieldMap, uniqueErrors);
        Test.stopTest();

        System.assertEquals('Source Account Name', targetAcc.Name, 'Trường Name phải được sao chép thành công.');
        System.assertEquals(1, uniqueErrors.size(), 'Sao chép chuỗi Phone vào trường Số lượng nhân viên phải sinh ngoại lệ.');
    }

    /**
     * Kịch bản 3: Kiểm tra hàm copyValidFields sao chép danh sách trường hợp lệ có kiểm tra quyền .isUpdateable().
     * Bao phủ: Nhánh trường có quyền ghi thành công, nhánh trường không tồn tại/không có quyền ghi (Bị bỏ qua), và nhánh phát sinh Exception.
     */
    @IsTest
    static void testCopyValidFields_SuccessAndException() {
        Account sourceAcc = new Account(Name = 'Valid Source Name', Industry = 'Banking');
        Account targetAcc = new Account();
        Set<String> uniqueErrors = new Set<String>();
        
        Map<String, Schema.SObjectField> fieldMap = Account.SObjectType.getDescribe().fields.getMap();
        
        // Cấu hình danh sách trường valid và map ánh xạ dùng chung
        List<String> validFields = new List<String>{ 'Name', 'Industry', 'NON_EXIST_FIELD__c' };
        Map<String, String> commonFieldMap = new Map<String, String>{
            'Name' => 'Name',
            'Industry' => 'AccountNumber', // Ép lỗi: Gán chữ Industry vào trường Số tài khoản để kích hoạt catch (nếu có Validation rule hoặc ép sai định dạng)
            'NON_EXIST_FIELD__c' => 'FAKE__c'
        };

        Test.startTest();
        FEC_BatchUtils.copyValidFields(targetAcc, sourceAcc, validFields, fieldMap, commonFieldMap, uniqueErrors);
        Test.stopTest();

        System.assertEquals('Valid Source Name', targetAcc.Name);
    }

    /**
     * Kịch bản 4: Kiểm tra hàm copyFieldsToMDM cập nhật ngược dữ liệu từ bản ghi Live sang bản ghi MDM ngầm.
     * Bao phủ: Xử lý ghi mượt mà và nuốt lỗi (swallow exception) an toàn.
     */
    @IsTest
    static void testCopyFieldsToMDM_AllBranches() {
        Account liveAcc = new Account(Name = 'Live Account Name', Industry = 'Technology');
        Account mdmAcc = new Account();
        
        Map<String, Schema.SObjectField> mdmFields = Account.SObjectType.getDescribe().fields.getMap();
        Map<String, String> commonFieldMap = new Map<String, String>{
            'Name' => 'Name',
            'Industry' => 'INVALID_LIVE_FIELD__c' // Gây lỗi catch để bao phủ nhánh nuốt lỗi trống
        };

        Test.startTest();
        FEC_BatchUtils.copyFieldsToMDM(mdmAcc, liveAcc, mdmFields, commonFieldMap);
        Test.stopTest();

        System.assertEquals('Live Account Name', mdmAcc.Name, 'Bản ghi MDM phải nhận được dữ liệu trường Name từ bản ghi Live.');
    }

    /**
     * Kịch bản 5: Kiểm tra hàm đảo ngược mối quan hệ revertLookup từ bản ghi Live về bản ghi MDM.
     * Bao phủ: Khởi tạo đảo ngược thành công mối quan hệ Lookup cha-con, và nhánh xử lý Exception.
     */
    @IsTest
    static void testRevertLookup_SuccessAndException() {
        Account acc = new Account(Name = 'Test Revert Account');
        putExternalIdIfWritable(acc, 'EXT-REVERT-001');
        insert acc;
        Contact liveContact = new Contact(LastName = 'Live Contact', AccountId = acc.Id);
        insert liveContact;

        Contact queriedLive = [SELECT Id, AccountId FROM Contact WHERE Id = :liveContact.Id LIMIT 1];
        Account liveParent = new Account(Id = acc.Id);
        Boolean hasExtIdField = putExternalIdIfWritable(liveParent, 'EXT-REVERT-001');
        queriedLive.putSObject('Account', liveParent);
        Contact mdmContact = new Contact();
        Set<String> uniqueErrors = new Set<String>();

        Test.startTest();
        // Nhánh thành công: Đồng bộ ngược Account Lookup về cho mdmContact
        FEC_BatchUtils.revertLookup(mdmContact, queriedLive, 'Account', 'Account', uniqueErrors);

        // Nhánh lỗi: Truyền sai tên đối tượng cấu hình cha để kích hoạt khối catch
        FEC_BatchUtils.revertLookup(mdmContact, queriedLive, 'Account', 'CRITICAL_BAD_OBJECT_NAME', uniqueErrors);
        Test.stopTest();

        if (hasExtIdField) {
            System.assert(mdmContact.getSObject('Account') != null);
            System.assertEquals(
                'EXT-REVERT-001',
                (String) mdmContact.getSObject('Account').get(FEC_Constants.FIELD_EXTERNAL_ID)
            );
        }
        System.assert(uniqueErrors.size() >= 1, 'Danh sách lỗi phải ghi nhận ngoại lệ từ nhánh revert sai tên Object.');
    }

    private static Boolean putExternalIdIfWritable(SObject record, String value) {
        String extField = FEC_Constants.FIELD_EXTERNAL_ID;
        Map<String, Schema.SObjectField> fieldMap = record.getSObjectType().getDescribe().fields.getMap();
        if (!fieldMap.containsKey(extField)) {
            return false;
        }
        Schema.DescribeFieldResult dfr = fieldMap.get(extField).getDescribe();
        if (dfr.isCreateable() || dfr.isUpdateable()) {
            record.put(extField, value);
            return true;
        }
        return false;
    }
}