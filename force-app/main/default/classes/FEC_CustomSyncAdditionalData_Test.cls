/**
 * @description Test class for FEC_CustomSyncAdditionalData
 * @author Kiro AI Assistant
 * @since 2026-06-18
 */
@isTest
private class FEC_CustomSyncAdditionalData_Test {
    
    /**
     * @description Setup test data for all test methods
     */
    @TestSetup
    static void setupTestData() {
        // Create Business Process
        FEC_Business_Process__c businessProcess = new FEC_Business_Process__c(
            Name = 'Test Business Process',
            FEC_Code__c = 'TEST_BP_001'
        );
        insert businessProcess;
        
        // Create Actual Nature of Case (simplified - without full MDM hierarchy)
        FEC_Actual_Nature_of_Case__c natureOfCase = new FEC_Actual_Nature_of_Case__c(
            Name = 'Test Nature of Case'
        );
        insert natureOfCase;
        
        // Create Master Data Settings for FEC_Additional_Info__c fields
        List<FEC_Actual_Master_Data_Setting__c> settings = new List<FEC_Actual_Master_Data_Setting__c>();
        settings.add(new FEC_Actual_Master_Data_Setting__c(
            FEC_Actual_Nature_of_Case__c = natureOfCase.Id,
            FEC_Field_Object_Name__c = 'FEC_Additional_Info__c',
            FEC_Field_API_Name__c = 'FEC_Contract_No__c'
        ));
        settings.add(new FEC_Actual_Master_Data_Setting__c(
            FEC_Actual_Nature_of_Case__c = natureOfCase.Id,
            FEC_Field_Object_Name__c = 'FEC_Additional_Info__c',
            FEC_Field_API_Name__c = 'FEC_Payment_Amount__c'
        ));
        settings.add(new FEC_Actual_Master_Data_Setting__c(
            FEC_Actual_Nature_of_Case__c = natureOfCase.Id,
            FEC_Field_Object_Name__c = 'FEC_Additional_Info__c',
            FEC_Field_API_Name__c = 'FEC_Customer_Name__c'
        ));
        insert settings;
        
        // Create Case with Actual Nature of Case
        Case testCase = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Origin = 'Phone',
            FEC_ID_Search__c = 'TEST-CASE-001',
            FEC_Actual_Nature_of_Case__c = natureOfCase.Id,
            FEC_Business_Process__c = businessProcess.Id
        );
        insert testCase;
        
        // Create Additional Info record
        FEC_Additional_Info__c addInfo = new FEC_Additional_Info__c(
            FEC_Case__c = testCase.Id,
            FEC_Contract_No__c = 'LC-2026-001',
            FEC_Payment_Amount__c = 5000000,
            FEC_Customer_Name__c = 'Test Customer'
        );
        insert addInfo;
    }
    
    /**
     * @description Test getAdditionalNeedToSync with custom date fields
     */
    @isTest
    static void testGetAdditionalNeedToSync_CustomFields() {
        // Setup
        FEC_Custom_Sync__c customSync = new FEC_Custom_Sync__c(
            FEC_Target_Object__c = 'FEC_Additional_Info__c',
            FEC_Modified_Date_Field__c = 'LastModifiedDate',
            FEC_Created_Date_Field__c = 'CreatedDate'
        );
        
        DateTime startTime = DateTime.now().addDays(-1);
        DateTime toDate = DateTime.now();
        
        Test.startTest();
        String query = FEC_CustomSyncAdditionalData.getAdditionalNeedToSync(customSync, startTime, toDate);
        Test.stopTest();
        
        // Verify query contains expected parts
        System.assert(query.contains('SELECT Id, FEC_Case__c FROM FEC_Additional_Info__c'), 'Query should select from correct object');
        System.assert(query.contains('LastModifiedDate'), 'Query should include LastModifiedDate');
        System.assert(query.contains('CreatedDate'), 'Query should include CreatedDate');
        System.assert(query.contains('WHERE'), 'Query should have WHERE clause');
    }
    
    /**
     * @description Test getAdditionalNeedToSync with default date fields
     */
    @isTest
    static void testGetAdditionalNeedToSync_DefaultFields() {
        // Setup
        FEC_Custom_Sync__c customSync = new FEC_Custom_Sync__c(
            FEC_Target_Object__c = 'FEC_Additional_Info__c',
            FEC_Modified_Date_Field__c = '',
            FEC_Created_Date_Field__c = ''
        );
        
        DateTime startTime = DateTime.now().addDays(-1);
        DateTime toDate = DateTime.now();
        
        Test.startTest();
        String query = FEC_CustomSyncAdditionalData.getAdditionalNeedToSync(customSync, startTime, toDate);
        Test.stopTest();
        
        // Verify default fields are used
        System.assert(query.contains('LastModifiedDate'), 'Query should default to LastModifiedDate');
        System.assert(query.contains('CreatedDate'), 'Query should default to CreatedDate');
    }
    
    /**
     * @description Test getAdditionalInfoJson with valid data
     */
    @isTest
    static void testGetAdditionalInfoJson_ValidData() {
        // Query test data
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        FEC_Additional_Info__c addInfo = [SELECT Id, FEC_Case__c FROM FEC_Additional_Info__c WHERE FEC_Case__c = :testCase.Id LIMIT 1];
        
        List<SObject> scope = new List<SObject>{ addInfo };
        String tableName = 'AdditionalProperties';
        
        Test.startTest();
        String jsonResult = FEC_CustomSyncAdditionalData.getAdditionalInfoJson(scope, tableName);
        Test.stopTest();
        
        // Verify JSON structure without deserializing (Value field is Object type and cannot be deserialized)
        System.assertNotEquals(null, jsonResult, 'JSON result should not be null');
        System.assert(jsonResult.contains('records'), 'JSON should contain records array');
        System.assert(jsonResult.contains('tableName'), 'JSON should contain tableName');
        System.assert(jsonResult.contains(tableName), 'JSON should contain the correct tableName');
        System.assert(jsonResult.contains('PZINSKEY'), 'JSON should contain PZINSKEY field');
        System.assert(jsonResult.contains('PXEXTRACTIDENTIFIER'), 'JSON should contain PXEXTRACTIDENTIFIER field');
        System.assert(jsonResult.contains('PXEXTRACTDATETIME'), 'JSON should contain PXEXTRACTDATETIME field');
        System.assert(jsonResult.contains('ID'), 'JSON should contain ID field');
        System.assert(jsonResult.contains('Type'), 'JSON should contain Type field');
    }
    
    /**
     * @description Test getAdditionalInfoJson with empty scope
     */
    @isTest
    static void testGetAdditionalInfoJson_EmptyScope() {
        List<SObject> emptyScope = new List<SObject>();
        String tableName = 'AdditionalProperties';
        
        Test.startTest();
        String jsonResult = FEC_CustomSyncAdditionalData.getAdditionalInfoJson(emptyScope, tableName);
        Test.stopTest();
        
        // Verify empty result
        FEC_CustomSyncAdditionalData.OutputWrapper result = 
            (FEC_CustomSyncAdditionalData.OutputWrapper) JSON.deserialize(jsonResult, FEC_CustomSyncAdditionalData.OutputWrapper.class);
        
        System.assertEquals(0, result.records.size(), 'Should have no records');
        System.assertEquals('', result.tableName, 'Table name should be empty');
    }
    
    /**
     * @description Test getAdditionalInfoJson with null Case ID
     */
    @isTest
    static void testGetAdditionalInfoJson_NullCaseId() {
        // Create a mock SObject with null FEC_Case__c
        FEC_Additional_Info__c addInfo = new FEC_Additional_Info__c();
        List<SObject> scope = new List<SObject>{ addInfo };
        String tableName = 'AdditionalProperties';
        
        Test.startTest();
        String jsonResult = FEC_CustomSyncAdditionalData.getAdditionalInfoJson(scope, tableName);
        Test.stopTest();
        
        // Verify empty result
        FEC_CustomSyncAdditionalData.OutputWrapper result = 
            (FEC_CustomSyncAdditionalData.OutputWrapper) JSON.deserialize(jsonResult, FEC_CustomSyncAdditionalData.OutputWrapper.class);
        
        System.assertEquals(0, result.records.size(), 'Should have no records for null case ID');
    }
    
    /**
     * @description Test getAdditionalInfoJson with Case without Nature of Case
     */
    @isTest
    static void testGetAdditionalInfoJson_NoNatureOfCase() {
        // Create Case without Nature of Case
        Case caseWithoutNature = new Case(
            Subject = 'Test Case Without Nature',
            Status = 'New',
            Origin = 'Phone',
            FEC_ID_Search__c = 'TEST-CASE-002'
        );
        insert caseWithoutNature;
        
        FEC_Additional_Info__c addInfo = new FEC_Additional_Info__c(
            FEC_Case__c = caseWithoutNature.Id
        );
        insert addInfo;
        
        List<SObject> scope = new List<SObject>{ 
            [SELECT Id, FEC_Case__c FROM FEC_Additional_Info__c WHERE Id = :addInfo.Id] 
        };
        String tableName = 'AdditionalProperties';
        
        Test.startTest();
        String jsonResult = FEC_CustomSyncAdditionalData.getAdditionalInfoJson(scope, tableName);
        Test.stopTest();
        
        // Verify empty result
        FEC_CustomSyncAdditionalData.OutputWrapper result = 
            (FEC_CustomSyncAdditionalData.OutputWrapper) JSON.deserialize(jsonResult, FEC_CustomSyncAdditionalData.OutputWrapper.class);
        
        System.assertEquals(0, result.records.size(), 'Should have no records when Nature of Case is missing');
    }
    
    /**
     * @description Test getAdditionalInfoJson with no Master Data Settings
     */
    @isTest
    static void testGetAdditionalInfoJson_NoMasterDataSettings() {
        // Create Nature of Case without Master Data Settings
        FEC_Business_Process__c bp = [SELECT Id FROM FEC_Business_Process__c LIMIT 1];
        
        FEC_Actual_Nature_of_Case__c newNature = new FEC_Actual_Nature_of_Case__c(
            Name = 'Nature Without Settings'
        );
        insert newNature;
        
        Case testCase = new Case(
            Subject = 'Test Case No Settings',
            Status = 'New',
            Origin = 'Phone',
            FEC_ID_Search__c = 'TEST-CASE-003',
            FEC_Actual_Nature_of_Case__c = newNature.Id,
            FEC_Business_Process__c = bp.Id
        );
        insert testCase;
        
        FEC_Additional_Info__c addInfo = new FEC_Additional_Info__c(
            FEC_Case__c = testCase.Id
        );
        insert addInfo;
        
        List<SObject> scope = new List<SObject>{ 
            [SELECT Id, FEC_Case__c FROM FEC_Additional_Info__c WHERE Id = :addInfo.Id] 
        };
        String tableName = 'AdditionalProperties';
        
        Test.startTest();
        String jsonResult = FEC_CustomSyncAdditionalData.getAdditionalInfoJson(scope, tableName);
        Test.stopTest();
        
        // Verify empty result
        FEC_CustomSyncAdditionalData.OutputWrapper result = 
            (FEC_CustomSyncAdditionalData.OutputWrapper) JSON.deserialize(jsonResult, FEC_CustomSyncAdditionalData.OutputWrapper.class);
        
        System.assertEquals(0, result.records.size(), 'Should have no records when no Master Data Settings exist');
    }
    
    /**
     * @description Test OutputWrapper initialization
     */
    @isTest
    static void testOutputWrapperInitialization() {
        Test.startTest();
        FEC_CustomSyncAdditionalData.OutputWrapper wrapper = new FEC_CustomSyncAdditionalData.OutputWrapper();
        Test.stopTest();
        
        System.assertNotEquals(null, wrapper.records, 'Records list should be initialized');
        System.assertEquals(0, wrapper.records.size(), 'Records list should be empty');
        System.assertEquals('', wrapper.tableName, 'Table name should be empty string');
    }
    
    /**
     * @description Test RecordDetail field assignments
     */
    @isTest
    static void testRecordDetailFields() {
        Test.startTest();
        FEC_CustomSyncAdditionalData.RecordDetail detail = new FEC_CustomSyncAdditionalData.RecordDetail();
        detail.PZINSKEY = 'TEST-KEY';
        detail.PXEXTRACTIDENTIFIER = 'TEST-IDENTIFIER';
        detail.PXEXTRACTDATETIME = '2026-06-18 12:00:00';
        detail.ID = 'FEC_Card_Number__c';
        detail.Value = '1234567890123456';
        detail.Type = 'STRING';
        Test.stopTest();
        
        System.assertEquals('TEST-KEY', detail.PZINSKEY, 'PZINSKEY should match');
        System.assertEquals('TEST-IDENTIFIER', detail.PXEXTRACTIDENTIFIER, 'PXEXTRACTIDENTIFIER should match');
        System.assertEquals('2026-06-18 12:00:00', detail.PXEXTRACTDATETIME, 'PXEXTRACTDATETIME should match');
        System.assertEquals('FEC_Card_Number__c', detail.ID, 'ID should match');
        System.assertEquals('1234567890123456', detail.Value, 'Value should match');
        System.assertEquals('STRING', detail.Type, 'Type should match');
    }
    
    /**
     * @description Test with multiple Additional Info records for same Case
     */
    @isTest
    static void testGetAdditionalInfoJson_MultipleRecords() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        // Create additional FEC_Additional_Info__c records
        FEC_Additional_Info__c addInfo2 = new FEC_Additional_Info__c(
            FEC_Case__c = testCase.Id,
            FEC_Contract_No__c = 'LC-2026-002',
            FEC_Payment_Amount__c = 3000000,
            FEC_Customer_Name__c = 'Test Customer 2'
        );
        insert addInfo2;
        
        List<FEC_Additional_Info__c> addInfoList = [
            SELECT Id, FEC_Case__c 
            FROM FEC_Additional_Info__c 
            WHERE FEC_Case__c = :testCase.Id
        ];
        
        List<SObject> scope = new List<SObject>();
        scope.addAll(addInfoList);
        String tableName = 'AdditionalProperties';
        
        Test.startTest();
        String jsonResult = FEC_CustomSyncAdditionalData.getAdditionalInfoJson(scope, tableName);
        Test.stopTest();
        
        // Verify JSON contains multiple records without deserializing (Value field is Object type)
        System.assert(jsonResult.contains('records'), 'JSON should contain records array');
        System.assert(jsonResult.contains(tableName), 'JSON should contain the correct tableName');
        
        // Parse to check we have multiple records by counting occurrences of PZINSKEY
        Integer recordCount = jsonResult.countMatches('PZINSKEY');
        System.assert(recordCount > 3, 'Should have multiple record details from multiple Additional Info records');
    }
    
    /**
     * @description Test getAdditionalInfoJson with invalid (non-existent) fields
     * This tests the field validation logic where configured fields don't exist in the object
     */
    @isTest
    static void testGetAdditionalInfoJson_InvalidFields() {
        // Query test data
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        FEC_Actual_Nature_of_Case__c natureOfCase = [SELECT Id FROM FEC_Actual_Nature_of_Case__c LIMIT 1];
        
        // Create Master Data Settings with some invalid field names
        List<FEC_Actual_Master_Data_Setting__c> invalidSettings = new List<FEC_Actual_Master_Data_Setting__c>();
        invalidSettings.add(new FEC_Actual_Master_Data_Setting__c(
            FEC_Actual_Nature_of_Case__c = natureOfCase.Id,
            FEC_Field_Object_Name__c = 'FEC_Additional_Info__c',
            FEC_Field_API_Name__c = 'FEC_NonExistent_Field_1__c' // Invalid field
        ));
        invalidSettings.add(new FEC_Actual_Master_Data_Setting__c(
            FEC_Actual_Nature_of_Case__c = natureOfCase.Id,
            FEC_Field_Object_Name__c = 'FEC_Additional_Info__c',
            FEC_Field_API_Name__c = 'FEC_Invalid_Field_2__c' // Invalid field
        ));
        invalidSettings.add(new FEC_Actual_Master_Data_Setting__c(
            FEC_Actual_Nature_of_Case__c = natureOfCase.Id,
            FEC_Field_Object_Name__c = 'FEC_Additional_Info__c',
            FEC_Field_API_Name__c = 'FEC_Contract_No__c' // Valid field
        ));
        insert invalidSettings;
        
        FEC_Additional_Info__c addInfo = [SELECT Id, FEC_Case__c FROM FEC_Additional_Info__c WHERE FEC_Case__c = :testCase.Id LIMIT 1];
        List<SObject> scope = new List<SObject>{ addInfo };
        String tableName = 'AdditionalProperties';
        
        Test.startTest();
        String jsonResult = FEC_CustomSyncAdditionalData.getAdditionalInfoJson(scope, tableName);
        Test.stopTest();
        
        // Verify JSON is generated without errors
        System.assertNotEquals(null, jsonResult, 'JSON result should not be null even with invalid fields');
        System.assert(jsonResult.contains('records'), 'JSON should contain records array');
        System.assert(jsonResult.contains(tableName), 'JSON should contain the correct tableName');
        
        // Verify that both valid and invalid fields are in the response
        System.assert(jsonResult.contains('FEC_NonExistent_Field_1__c'), 'JSON should contain invalid field name');
        System.assert(jsonResult.contains('FEC_Invalid_Field_2__c'), 'JSON should contain another invalid field name');
        System.assert(jsonResult.contains('FEC_Contract_No__c'), 'JSON should contain valid field name');
        
        // Verify UNKNOWN type is used for invalid fields
        System.assert(jsonResult.contains('UNKNOWN'), 'JSON should contain UNKNOWN type for invalid fields');
        
        // Count the number of records - should have all fields from original setup (3) + new fields (3) = 6 total
        Integer recordCount = jsonResult.countMatches('"ID"');
        System.assert(recordCount >= 3, 'Should have at least 3 record details including the new invalid fields');
    }
}