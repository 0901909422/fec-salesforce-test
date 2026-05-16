/**
 * FEC_ClientPDFServiceTest
 * Test class cho FEC_ClientPDFService và FEC_PDFTemplateSelector.
 * 
 * @created    : 2026/05/04 long.nguyen.50
 * @modified   : 
 */
@isTest
private class FEC_ClientPDFServiceTest {
    
    // Template code từ FEC_PDFTemplate.ThongBaoChoVayLichTraNo.md-meta.xml
    private static final String VALID_TEMPLATE_CODE = 'TBCV_LTN';
    private static final String INVALID_TEMPLATE_CODE = 'NON_EXISTENT_TEMPLATE_XYZ';
    
    /**
     * testGetTemplateData_Success
     * Test lấy template data thành công với template code hợp lệ.
     */
    @isTest
    static void testGetTemplateData_Success() {
        // Given: Template code hợp lệ (TBCV_LTN - Thông Báo Cho Vay Kiêm Lịch Trả Nợ)
        String strTemplateCode = VALID_TEMPLATE_CODE;
        
        Test.startTest();
        Map<String, String> mapResult = FEC_ClientPDFService.getTemplateData(strTemplateCode);
        Test.stopTest();
        
        // Then: Verify kết quả
        System.assertNotEquals(null, mapResult, 'Result should not be null');
        System.assertEquals(VALID_TEMPLATE_CODE, mapResult.get('templateCode'), 'Template code should match');
        System.assertEquals('ThongBaoChoVay_LichTraNo', mapResult.get('fileName'), 'File name should match');
        System.assertEquals('Cho Vay', mapResult.get('category'), 'Category should match');
        System.assert(String.isNotBlank(mapResult.get('htmlBody')), 'HTML body should not be blank');
    }
    
    /**
     * testGetTemplateData_TemplateNotFound
     * Test xử lý khi template không tồn tại.
     */
    @isTest
    static void testGetTemplateData_TemplateNotFound() {
        // Given: Template code không tồn tại
        String strTemplateCode = INVALID_TEMPLATE_CODE;
        
        // When & Then: Expect AuraHandledException
        Test.startTest();
        try {
            FEC_ClientPDFService.getTemplateData(strTemplateCode);
            System.assert(false, 'Expected AuraHandledException to be thrown');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Exception message should not be null');
        }
        Test.stopTest();
    }
    
    /**
     * testGetTemplateData_NullCode
     * Test xử lý khi template code là null.
     */
    @isTest
    static void testGetTemplateData_NullCode() {
        // Given: Template code null
        String strTemplateCode = null;
        
        // When & Then: Expect AuraHandledException
        Test.startTest();
        try {
            FEC_ClientPDFService.getTemplateData(strTemplateCode);
            System.assert(false, 'Expected AuraHandledException to be thrown');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Exception message should not be null');
        }
        Test.stopTest();
    }
    
    /**
     * testGetTemplateData_EmptyCode
     * Test xử lý khi template code là empty string.
     */
    @isTest
    static void testGetTemplateData_EmptyCode() {
        // Given: Template code empty
        String strTemplateCode = '';
        
        // When & Then: Expect AuraHandledException
        Test.startTest();
        try {
            FEC_ClientPDFService.getTemplateData(strTemplateCode);
            System.assert(false, 'Expected AuraHandledException to be thrown');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Exception message should not be null');
        }
        Test.stopTest();
    }
    
    /**
     * testPDFTemplateSelector_GetByCode_Success
     * Test selector trả về template khi code hợp lệ.
     */
    @isTest
    static void testPDFTemplateSelector_GetByCode_Success() {
        Test.startTest();
        FEC_PDFTemplate__mdt objResult = FEC_PDFTemplateSelector.getByCode(VALID_TEMPLATE_CODE);
        Test.stopTest();
        
        System.assertNotEquals(null, objResult, 'Should return template for valid code');
        System.assertEquals(VALID_TEMPLATE_CODE, objResult.FEC_TemplateCode__c, 'Template code should match');
        System.assertEquals('ThongBaoChoVay_LichTraNo', objResult.FEC_FileName__c, 'File name should match');
        System.assertEquals('Cho Vay', objResult.FEC_Category__c, 'Category should match');
        System.assertEquals(true, objResult.FEC_IsActive__c, 'Template should be active');
    }
    
    /**
     * testPDFTemplateSelector_GetByCode_Null
     * Test selector trả về null khi code null.
     */
    @isTest
    static void testPDFTemplateSelector_GetByCode_Null() {
        Test.startTest();
        FEC_PDFTemplate__mdt objResult = FEC_PDFTemplateSelector.getByCode(null);
        Test.stopTest();
        
        System.assertEquals(null, objResult, 'Should return null for null code');
    }
    
    /**
     * testPDFTemplateSelector_GetByCode_Empty
     * Test selector trả về null khi code empty.
     */
    @isTest
    static void testPDFTemplateSelector_GetByCode_Empty() {
        Test.startTest();
        FEC_PDFTemplate__mdt objResult = FEC_PDFTemplateSelector.getByCode('');
        Test.stopTest();
        
        System.assertEquals(null, objResult, 'Should return null for empty code');
    }
    
    /**
     * testPDFTemplateSelector_GetByCode_NotFound
     * Test selector trả về null khi không tìm thấy template.
     */
    @isTest
    static void testPDFTemplateSelector_GetByCode_NotFound() {
        Test.startTest();
        FEC_PDFTemplate__mdt objResult = FEC_PDFTemplateSelector.getByCode(INVALID_TEMPLATE_CODE);
        Test.stopTest();
        
        System.assertEquals(null, objResult, 'Should return null for non-existent code');
    }
    
    // ==================== FEC_PDFTemplateSelector.getByCategory Tests ====================
    
    /**
     * testPDFTemplateSelector_GetByCategory_Success
     * Test lấy templates theo category hợp lệ.
     */
    @isTest
    static void testPDFTemplateSelector_GetByCategory_Success() {
        // Given: Category 'Cho Vay' có template TBCV_LTN
        String strCategory = 'Cho Vay';
        
        Test.startTest();
        List<FEC_PDFTemplate__mdt> listResults = FEC_PDFTemplateSelector.getByCategory(strCategory);
        Test.stopTest();
        
        System.assertNotEquals(null, listResults, 'Should return a list');
        System.assert(listResults.size() > 0, 'Should have at least one template in Cho Vay category');
    }
    
    /**
     * testPDFTemplateSelector_GetByCategory_Null
     * Test trả về empty list khi category null.
     */
    @isTest
    static void testPDFTemplateSelector_GetByCategory_Null() {
        Test.startTest();
        List<FEC_PDFTemplate__mdt> listResults = FEC_PDFTemplateSelector.getByCategory(null);
        Test.stopTest();
        
        System.assertNotEquals(null, listResults, 'Should return empty list, not null');
        System.assertEquals(0, listResults.size(), 'Should return empty list for null category');
    }
    
    /**
     * testPDFTemplateSelector_GetByCategory_Empty
     * Test trả về empty list khi category empty.
     */
    @isTest
    static void testPDFTemplateSelector_GetByCategory_Empty() {
        Test.startTest();
        List<FEC_PDFTemplate__mdt> listResults = FEC_PDFTemplateSelector.getByCategory('');
        Test.stopTest();
        
        System.assertNotEquals(null, listResults, 'Should return empty list, not null');
        System.assertEquals(0, listResults.size(), 'Should return empty list for empty category');
    }
    
    /**
     * testPDFTemplateSelector_GetByCategory_NotFound
     * Test trả về empty list khi category không tồn tại.
     */
    @isTest
    static void testPDFTemplateSelector_GetByCategory_NotFound() {
        Test.startTest();
        List<FEC_PDFTemplate__mdt> listResults = FEC_PDFTemplateSelector.getByCategory('INVALID_CATEGORY_XYZ');
        Test.stopTest();
        
        System.assertNotEquals(null, listResults, 'Should return empty list, not null');
        System.assertEquals(0, listResults.size(), 'Should return empty list for non-existent category');
    }
    
    // ==================== FEC_PDFTemplateSelector.getAllActive Tests ====================
    
    /**
     * testPDFTemplateSelector_GetAllActive
     * Test lấy tất cả templates active.
     */
    @isTest
    static void testPDFTemplateSelector_GetAllActive() {
        Test.startTest();
        List<FEC_PDFTemplate__mdt> listResults = FEC_PDFTemplateSelector.getAllActive();
        Test.stopTest();
        
        System.assertNotEquals(null, listResults, 'Should return a list, not null');
        System.assert(listResults.size() > 0, 'Should have at least one active template');
    }
    
    // ==================== FEC_PDFTemplateSelector.getTemplateOptions Tests ====================
    
    /**
     * testPDFTemplateSelector_GetTemplateOptions
     * Test lấy template options cho UI combobox.
     */
    @isTest
    static void testPDFTemplateSelector_GetTemplateOptions() {
        Test.startTest();
        List<FEC_PDFTemplateSelector.TemplateOption> listOptions = FEC_PDFTemplateSelector.getTemplateOptions();
        Test.stopTest();
        
        System.assertNotEquals(null, listOptions, 'Should return a list, not null');
        System.assert(listOptions.size() > 0, 'Should have at least one template option');
        
        // Verify option structure
        FEC_PDFTemplateSelector.TemplateOption objFirstOption = listOptions[0];
        System.assertNotEquals(null, objFirstOption.label, 'Option label should not be null');
        System.assertNotEquals(null, objFirstOption.value, 'Option value should not be null');
    }
}