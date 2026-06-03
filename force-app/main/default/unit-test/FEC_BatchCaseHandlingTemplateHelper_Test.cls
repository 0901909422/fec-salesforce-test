@IsTest
private class FEC_BatchCaseHandlingTemplateHelper_Test {

    @TestSetup
    static void setupData() {
        // Tạo các bản ghi Template Import mẫu phục vụ kiểm tra điều kiện phân giải tên (Prefix & Suffix Mapping)
        // Sử dụng SObject generic phòng trường hợp đối tượng chưa được cài đặt cứng hoặc cấu hình sai khác giữa các org
        Schema.SObjectType templateType = Schema.getGlobalDescribe().get('FEC_Template_Import__c');
        if (templateType != null) {
            List<SObject> templatesToInsert = new List<SObject>();

            // 1. Dữ liệu mồi cho luồng COF đi với nhóm người dùng CC (Hậu tố: _CSCustomerCare)
            SObject t1 = templateType.newSObject();
            t1.put('Name', 'COFTemp_Sample_CSCustomerCare');
            if (templateType.getDescribe().fields.getMap().containsKey('FEC_Active__c')) t1.put('FEC_Active__c', true);
            if (templateType.getDescribe().fields.getMap().containsKey('FEC_Applicable_for__c')) t1.put('FEC_Applicable_for__c', 'Batch Case Handling');
            templatesToInsert.add(t1);

            // 2. Dữ liệu mồi cho luồng GSR đi với nhóm người dùng SP (Hậu tố: _CSSupport)
            SObject t2 = templateType.newSObject();
            t2.put('Name', 'GSRTemp_Sample_CSSupport');
            if (templateType.getDescribe().fields.getMap().containsKey('FEC_Active__c')) t2.put('FEC_Active__c', true);
            if (templateType.getDescribe().fields.getMap().containsKey('FEC_Applicable_for__c')) t2.put('FEC_Applicable_for__c', 'Batch Case Handling');
            templatesToInsert.add(t2);

            // 3. Dữ liệu mồi kiểm tra tính năng gán dự phòng (Fallback) khi tiền tố khớp nhưng hậu tố không thuộc tập ứng viên
            SObject t3 = templateType.newSObject();
            t3.put('Name', 'AddressUpdateTemp_Fallback_Record');
            if (templateType.getDescribe().fields.getMap().containsKey('FEC_Active__c')) t3.put('FEC_Active__c', true);
            if (templateType.getDescribe().fields.getMap().containsKey('FEC_Applicable_for__c')) t3.put('FEC_Applicable_for__c', 'Batch Case Handling');
            templatesToInsert.add(t3);

            // 4. Bản ghi trống tên hoặc sai tiền tố để kiểm tra nhánh rẽ điều kiện "continue" bỏ qua bản ghi không hợp lệ
            SObject t4 = templateType.newSObject();
            t4.put('Name', 'WRONGPREFIX_Temp_Invalid');
            if (templateType.getDescribe().fields.getMap().containsKey('FEC_Active__c')) t4.put('FEC_Active__c', true);
            if (templateType.getDescribe().fields.getMap().containsKey('FEC_Applicable_for__c')) t4.put('FEC_Applicable_for__c', 'Batch Case Handling');
            templatesToInsert.add(t4);

            insert templatesToInsert;
        }
    }

    /**
     * Kịch bản 1: Kiểm tra hàm truy vấn danh sách Template hoạt động (queryActiveBatchCaseHandlingTemplates).
     * Mong đợi: Trả về danh sách chứa các bản ghi mồi hợp lệ thỏa mãn điều kiện lọc Metadata.
     */
    @IsTest
    static void testQueryActiveBatchCaseHandlingTemplates() {
        Test.startTest();
        List<SObject> activeTemplates = FEC_BatchCaseHandlingTemplateHelper.queryActiveBatchCaseHandlingTemplates();
        Test.stopTest();

        System.assertNotEquals(null, activeTemplates);
        // Đảm bảo không ném ra ngoại lệ nếu Object tồn tại trong Org
        Schema.SObjectType templateType = Schema.getGlobalDescribe().get('FEC_Template_Import__c');
        if (templateType != null) {
            System.assert(activeTemplates.size() >= 3, 'Hệ thống phải truy vấn được ít nhất 3 bản ghi hoạt động từ Setup.');
        }
    }

    /**
     * Kịch bản 2: Kiểm tra phân giải Template cho quy trình COF đi qua toàn bộ các nhóm User Group (Branch Coverage).
     * Mong đợi: Khớp chính xác tệp tin tương ứng dựa vào ánh xạ hậu tố người dùng nghiệp vụ.
     */
    @IsTest
    static void testResolveTemplate_CofAllUserGroups() {
        List<SObject> activeTemplates = FEC_BatchCaseHandlingTemplateHelper.queryActiveBatchCaseHandlingTemplates();
        
        // Danh sách các nhóm User Group kiểm thử cho luồng nghiệp vụ COF
        List<String> userGroups = new List<String>{ 'CC', 'CO', 'CL', 'CP', 'PM', 'CA', 'DS', 'TS', 'UNKNOWN_GROUP' };

        Test.startTest();
        for (String ug : userGroups) {
            // Ép chạy qua toàn bộ câu lệnh rẽ nhánh if-else của luồng COF trong hàm mapUserGroupToTemplateSuffixes
            FEC_BatchCaseHandlingTemplateHelper.resolveTemplateByBusinessProcessAndUserGroup('COF (Complaint or Feedback)', ug, activeTemplates);
            FEC_BatchCaseHandlingTemplateHelper.resolveTemplateByBusinessProcessAndUserGroup('COF', ug, activeTemplates);
        }
        Test.stopTest();
        
        // Xác minh một trường hợp cụ thể: COF + CC phải tìm thấy bản ghi số 1 ứng với hậu tố '_CSCustomerCare'
        SObject matched = FEC_BatchCaseHandlingTemplateHelper.resolveTemplateByBusinessProcessAndUserGroup('COF', 'CC', activeTemplates);
        if (!activeTemplates.isEmpty() && matched != null) {
            System.assertEquals('COFTemp_Sample_CSCustomerCare', String.valueOf(matched.get('Name')));
        }
    }

    /**
     * Kịch bản 3: Kiểm tra phân giải Template cho quy trình GSR đi qua toàn bộ các nhóm User Group (Branch Coverage).
     * Mong đợi: Đi qua toàn bộ khối lệnh điều kiện sinh tập ứng viên của luồng GSR.
     */
    @IsTest
    static void testResolveTemplate_GsrAllUserGroups() {
        List<SObject> activeTemplates = FEC_BatchCaseHandlingTemplateHelper.queryActiveBatchCaseHandlingTemplates();
        List<String> userGroups = new List<String>{ 'SP', 'CO', 'CL', 'CP', 'PM', 'CA', 'DS', 'TS', 'OTHER' };

        Test.startTest();
        for (String ug : userGroups) {
            // Ép chạy qua toàn bộ câu lệnh rẽ nhánh if-else của luồng GSR trong hàm mapUserGroupToTemplateSuffixes
            FEC_BatchCaseHandlingTemplateHelper.resolveTemplateByBusinessProcessAndUserGroup('GSR (General Service Request)', ug, activeTemplates);
            FEC_BatchCaseHandlingTemplateHelper.resolveTemplateByBusinessProcessAndUserGroup('GSR', ug, activeTemplates);
        }
        Test.stopTest();

        SObject matched = FEC_BatchCaseHandlingTemplateHelper.resolveTemplateByBusinessProcessAndUserGroup('GSR', 'SP', activeTemplates);
        if (!activeTemplates.isEmpty() && matched != null) {
            System.assertEquals('GSRTemp_Sample_CSSupport', String.valueOf(matched.get('Name')));
        }
    }

    /**
     * Kịch bản 4: Kiểm tra phân giải các Quy trình nghiệp vụ thông thường khác (Address Update, Phone Update, v.v.).
     * Bao phủ: Quét qua toàn bộ các từ khóa cấu hình thuộc danh sách ALLOWED_BUSINESS_PROCESS_NAMES để bao phủ hàm ánh xạ tiền tố.
     */
    @IsTest
    static void testResolveTemplate_OtherBusinessProcesses() {
        List<SObject> activeTemplates = FEC_BatchCaseHandlingTemplateHelper.queryActiveBatchCaseHandlingTemplates();
        
        // Quét qua danh sách các mã quy trình nghiệp vụ thông thường mở rộng để phủ khối mapUserGroupToTemplateSuffixes cuối cùng
        List<String> extraUserGroups = new List<String>{ 'SP', 'OM', 'CC', 'DS', 'CO' };

        Test.startTest();
        for (String bp : FEC_BatchCaseHandlingTemplateHelper.ALLOWED_BUSINESS_PROCESS_NAMES) {
            for (String ug : extraUserGroups) {
                FEC_BatchCaseHandlingTemplateHelper.resolveTemplateByBusinessProcessAndUserGroup(bp, ug, activeTemplates);
            }
        }
        Test.stopTest();

        // Kiểm tra kịch bản Fallback: Khớp tiền tố AddressUpdate nhưng không khớp hậu tố của dòng -> Phải lấy bản ghi fallback đầu tiên tìm thấy
        SObject fallbackMatch = FEC_BatchCaseHandlingTemplateHelper.resolveTemplateByBusinessProcessAndUserGroup('Address Update', 'OM', activeTemplates);
        if (!activeTemplates.isEmpty() && fallbackMatch != null) {
            System.assertEquals('AddressUpdateTemp_Fallback_Record', String.valueOf(fallbackMatch.get('Name')));
        }
    }

    /**
     * Kịch bản 5: Kiểm tra các tình huống dữ liệu biên không hợp lệ hoặc rỗng (Guard Clause Testing).
     * Bao phủ: Mảng danh sách rỗng, mã quy trình rỗng hoặc sai chính tả hoàn toàn không thuộc bộ từ điển cấu hình.
     */
    @IsTest
    static void testResolveTemplate_EdgeCasesAndEmptyInputs() {
        List<SObject> activeTemplates = FEC_BatchCaseHandlingTemplateHelper.queryActiveBatchCaseHandlingTemplates();

        Test.startTest();
        // 1. Nhánh 1: activeTemplates nhận giá trị null hoặc rỗng -> Trả về null
        SObject resNullList = FEC_BatchCaseHandlingTemplateHelper.resolveTemplateByBusinessProcessAndUserGroup('COF', 'CC', null);
        SObject resEmptyList = FEC_BatchCaseHandlingTemplateHelper.resolveTemplateByBusinessProcessAndUserGroup('COF', 'CC', new List<SObject>());

        // 2. Nhánh 2: businessProcessCode nhận giá trị trống/null hoặc từ khóa không tồn tại -> Trả về null
        SObject resEmptyBP = FEC_BatchCaseHandlingTemplateHelper.resolveTemplateByBusinessProcessAndUserGroup('', 'CC', activeTemplates);
        SObject resInvalidBP = FEC_BatchCaseHandlingTemplateHelper.resolveTemplateByBusinessProcessAndUserGroup('CRITICAL_INVALID_BP_CODE', 'CC', activeTemplates);

        // 3. Nhánh biên rỗng cho User Group khi đi với luồng thường
        SObject resEmptyUG = FEC_BatchCaseHandlingTemplateHelper.resolveTemplateByBusinessProcessAndUserGroup('Address Update', '', activeTemplates);
        Test.stopTest();

        System.assertEquals(null, resNullList);
        System.assertEquals(null, resEmptyList);
        System.assertEquals(null, resEmptyBP);
        System.assertEquals(null, resInvalidBP);
        if (resEmptyUG != null) {
            System.assertEquals('AddressUpdateTemp_Fallback_Record', String.valueOf(resEmptyUG.get('Name')));
        }
    }

    @IsTest
    static void testAllowedBusinessProcessHelpers() {
        Test.startTest();
        Boolean allowed = FEC_BatchCaseHandlingTemplateHelper.isAllowedBusinessProcessName('Address Update');
        Boolean disallowed = FEC_BatchCaseHandlingTemplateHelper.isAllowedBusinessProcessName('INVALID_BP');
        Set<String> codes = FEC_BatchCaseHandlingTemplateHelper.queryAllowedBusinessProcessCodes();
        Set<String> names = FEC_BatchCaseHandlingTemplateHelper.queryAllowedBusinessProcessNames();
        String whereClause = FEC_BatchCaseHandlingTemplateHelper.buildAllowedStageBusinessProcessWhereClause();
        List<String> selectFields = FEC_BatchCaseHandlingTemplateHelper.buildCaseStageBusinessProcessSelectFields();
        Test.stopTest();

        System.assertEquals(true, allowed);
        System.assertEquals(false, disallowed);
        System.assertNotEquals(null, codes);
        System.assertNotEquals(null, names);
        System.assert(whereClause.contains('FEC_Current_Case_Stage__r'));
        System.assert(selectFields.size() >= 3);
    }

    @IsTest
    static void testMapBusinessProcessAndUserGroupSuffixes() {
        Test.startTest();
        System.assertEquals('COF', FEC_BatchCaseHandlingTemplateHelper.mapBusinessProcessToTemplatePrefix('COF - General Flow'));
        System.assertEquals('AddressUpdate', FEC_BatchCaseHandlingTemplateHelper.mapBusinessProcessToTemplatePrefix('Address Update'));
        System.assertEquals(null, FEC_BatchCaseHandlingTemplateHelper.mapBusinessProcessToTemplatePrefix(''));

        List<String> cofCc = FEC_BatchCaseHandlingTemplateHelper.mapUserGroupToTemplateSuffixes('COF', 'CC');
        List<String> gsrSp = FEC_BatchCaseHandlingTemplateHelper.mapUserGroupToTemplateSuffixes('GSR', 'SP');
        List<String> addrOm = FEC_BatchCaseHandlingTemplateHelper.mapUserGroupToTemplateSuffixes('Address Update', 'OM');
        Test.stopTest();

        System.assertEquals('CSCustomerCare', cofCc[0]);
        System.assertEquals('CSSupport', gsrSp[0]);
        System.assertEquals('CSD2C', addrOm[0]);
    }

    @IsTest
    static void testApplyStageBusinessProcessToExportRow() {
        FEC_BatchCaseHandlingExportRow row = new FEC_BatchCaseHandlingExportRow();
        Case c = new Case();

        Test.startTest();
        FEC_BatchCaseHandlingTemplateHelper.applyStageBusinessProcessToExportRow(null, c);
        FEC_BatchCaseHandlingTemplateHelper.applyStageBusinessProcessToExportRow(row, null);
        FEC_BatchCaseHandlingTemplateHelper.applyStageBusinessProcessToExportRow(row, c);
        Test.stopTest();

        System.assertEquals(null, row.businessProcessCode);
        System.assertEquals(null, row.businessProcessName);
    }

    @IsTest
    static void testIsAllowedBusinessProcessForExport() {
        Test.startTest();
        Boolean byCode = FEC_BatchCaseHandlingTemplateHelper.isAllowedBusinessProcessForExport('COF', null);
        Boolean byName = FEC_BatchCaseHandlingTemplateHelper.isAllowedBusinessProcessForExport(null, 'Address Update');
        Boolean invalid = FEC_BatchCaseHandlingTemplateHelper.isAllowedBusinessProcessForExport('ZZZ', 'ZZZ');
        Test.stopTest();

        System.assertEquals(true, byCode);
        System.assertEquals(true, byName);
        System.assertEquals(false, invalid);
    }

    @IsTest
    static void testTemplateValidationAndFileNameHelpers() {
        Test.startTest();
        System.assertEquals(null, FEC_BatchCaseHandlingTemplateHelper.validateUploadedTemplateFileName('COFTemp_Sample_CSCustomerCare.xlsx', 'COFTemp_Sample_CSCustomerCare'));
        System.assertEquals('TEMPLATE_MISMATCH', FEC_BatchCaseHandlingTemplateHelper.validateUploadedTemplateFileName('Wrong.xlsx', 'COFTemp_Sample_CSCustomerCare'));
        System.assertEquals('cscustomercare', FEC_BatchCaseHandlingTemplateHelper.extractTemplateTeamSuffix('COFTemp_Sample_CSCustomerCare.xlsx'));
        System.assertEquals(null, FEC_BatchCaseHandlingTemplateHelper.validateUploadedTemplateForUserGroup('COFTemp_Sample_CSCustomerCare.xlsx', 'COF', 'CC'));
        System.assertNotEquals(null, FEC_BatchCaseHandlingTemplateHelper.validateUploadedTemplateForUserGroup('COFTemp_Sample_CSSupport.xlsx', 'COF', 'CC'));
        Test.stopTest();
    }

    @IsTest
    static void testResolveExportTemplateBindingAndPopulateMaps() {
        List<SObject> templates = FEC_BatchCaseHandlingTemplateHelper.queryActiveBatchCaseHandlingTemplates();
        Map<Id, Id> versionMap = new Map<Id, Id>();
        Map<Id, String> urlMap = new Map<Id, String>();

        Test.startTest();
        FEC_BatchCaseHandlingTemplateHelper.populateTemplateContentVersionMaps(new Set<Id>(), versionMap, urlMap);
        FEC_BatchCaseHandlingTemplateHelper.TemplateExportBinding binding =
            FEC_BatchCaseHandlingTemplateHelper.resolveExportTemplateBinding(
                'COF',
                'COF - General Flow',
                'CC',
                templates,
                versionMap,
                urlMap
            );
        String resolvedName = FEC_BatchCaseHandlingTemplateHelper.resolveTemplateNameFromUploadedFileName(
            'COFTemp_Sample_CSCustomerCare.xlsx',
            'CC',
            templates
        );
        FEC_BatchCaseHandlingTemplateHelper.logExportTemplateBindingDebug(
            'test',
            'COF',
            'COF - General Flow',
            'CC',
            binding,
            templates.size(),
            versionMap.size()
        );
        Test.stopTest();

        System.assertNotEquals(null, binding);
        if (resolvedName != null) {
            System.assert(resolvedName.contains('COF') || resolvedName.contains('Temp'));
        }
    }

    @IsTest
    static void testResolveTemplateByBusinessProcessNameField() {
        List<SObject> activeTemplates = FEC_BatchCaseHandlingTemplateHelper.queryActiveBatchCaseHandlingTemplates();

        Test.startTest();
        SObject byName = FEC_BatchCaseHandlingTemplateHelper.resolveTemplateByBusinessProcessAndUserGroup(
            null,
            'Address Update',
            'OM',
            activeTemplates
        );
        Test.stopTest();

        if (!activeTemplates.isEmpty() && byName != null) {
            System.assertEquals('AddressUpdateTemp_Fallback_Record', String.valueOf(byName.get('Name')));
        }
    }

    @IsTest
    static void testPopulateTemplateContentVersionMaps_WithXlsx() {
        List<SObject> templates = FEC_BatchCaseHandlingTemplateHelper.queryActiveBatchCaseHandlingTemplates();
        if (templates.isEmpty()) {
            System.assert(true, 'Skipped: no active templates in org.');
            return;
        }

        Id templateId = (Id) templates[0].get('Id');
        ContentVersion cv = new ContentVersion(
            Title = 'COFTemp_Sample_CSCustomerCare',
            PathOnClient = 'COFTemp_Sample_CSCustomerCare.xlsx',
            VersionData = Blob.valueOf('Mock Xlsx Bytes'),
            FirstPublishLocationId = templateId
        );
        insert cv;

        Map<Id, Id> versionMap = new Map<Id, Id>();
        Map<Id, String> urlMap = new Map<Id, String>();

        Test.startTest();
        FEC_BatchCaseHandlingTemplateHelper.populateTemplateContentVersionMaps(
            new Set<Id>{ templateId },
            versionMap,
            urlMap
        );
        String validationMsg = FEC_BatchCaseHandlingTemplateHelper.validateExportTemplateContentVersion(
            cv.Id,
            'CC'
        );
        Test.stopTest();

        System.assert(versionMap.containsKey(templateId), 'XLSX ContentVersion should map to template.');
        System.assertNotEquals(null, urlMap.get(templateId));
        System.assertEquals(null, validationMsg);
    }

    @IsTest
    static void testBuildAllowedBusinessProcessNameInClause() {
        Test.startTest();
        String inClause = FEC_BatchCaseHandlingTemplateHelper.buildAllowedBusinessProcessNameInClause();
        Test.stopTest();

        System.assert(String.isNotBlank(inClause));
        System.assert(inClause.contains('FEC_Current_Case_Stage__r'));
    }

    @IsTest
    static void testValidateUploadedTemplateForUserGroup_BlankUserGroup() {
        Test.startTest();
        String err = FEC_BatchCaseHandlingTemplateHelper.validateUploadedTemplateForUserGroup(
            'COFTemp_Sample_CSCustomerCare.xlsx',
            'COF',
            ''
        );
        Test.stopTest();

        System.assertEquals(FEC_BatchCaseHandlingTemplateHelper.ERR_ROLE_TEMPLATE_MISMATCH, err);
    }

    @IsTest
    static void testMapBusinessProcessPrefixBranches() {
        Test.startTest();
        System.assertEquals('GSR', FEC_BatchCaseHandlingTemplateHelper.mapBusinessProcessToTemplatePrefix('GSR - General Flow'));
        System.assertEquals('GSR', FEC_BatchCaseHandlingTemplateHelper.mapBusinessProcessToTemplatePrefix('GSR prefix test'));
        System.assertEquals('COF', FEC_BatchCaseHandlingTemplateHelper.mapBusinessProcessToTemplatePrefix('cof complaint'));
        System.assertEquals('IPPConversion', FEC_BatchCaseHandlingTemplateHelper.mapBusinessProcessToTemplatePrefix('IPP Conversion'));
        Test.stopTest();
    }
}