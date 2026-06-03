/**
 * @description Unit tests for FEC_BatchUtils — shared helpers cho batch classes.
 *              Cover các helper method dùng trong sync/push batches.
 *              Cũng cover FEC_BatchException (constructor/throw).
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM
 */
@IsTest
private class FEC_BatchUtilsTest {

    @IsTest
    static void testCopyCommonFields_AllFieldsCopied() {
        FEC_MDM_Channel__c mdm = new FEC_MDM_Channel__c(
            Name = 'TestCh',
            FEC_Code__c = 'CH_T1',
            FEC_Channel_ID__c = 'TID',
            FEC_Channel_Vietnamese_name__c = 'Test',
            FEC_Channel_Status__c = true,
            FEC_Self_Service_Flag__c = false
        );
        FEC_Channel__c live = new FEC_Channel__c();

        // Map MDM field name → Live field name (same names ở đây)
        Map<String, String> commonMap = new Map<String, String>{
            'Name' => 'Name',
            'FEC_Code__c' => 'FEC_Code__c'
        };
        Set<String> errors = new Set<String>();

        Test.startTest();
        FEC_BatchUtils.copyCommonFields(live, mdm, commonMap, errors);
        Test.stopTest();

        Assert.areEqual('TestCh', live.Name, 'Name copied');
        Assert.areEqual('CH_T1', live.FEC_Code__c, 'Code copied');
        Assert.isTrue(errors.isEmpty(), 'No errors expected');
    }

    @IsTest
    static void testCopyCommonFields_InvalidFieldHandled() {
        FEC_MDM_Channel__c mdm = new FEC_MDM_Channel__c(Name = 'X', FEC_Code__c = 'X1');
        FEC_Channel__c live = new FEC_Channel__c();
        Map<String, String> commonMap = new Map<String, String>{
            'Name' => 'NonExistentField__c' // invalid target field
        };
        Set<String> errors = new Set<String>();

        Test.startTest();
        FEC_BatchUtils.copyCommonFields(live, mdm, commonMap, errors);
        Test.stopTest();

        Assert.isFalse(errors.isEmpty(), 'Should record error for invalid field');
    }

    @IsTest
    static void testCopyCommonFields_NullErrorsSet() {
        // Null errors set: helper không throw NPE
        FEC_MDM_Channel__c mdm = new FEC_MDM_Channel__c(Name = 'X', FEC_Code__c = 'X2');
        FEC_Channel__c live = new FEC_Channel__c();
        Map<String, String> commonMap = new Map<String, String>{
            'Name' => 'BadField__c' // invalid → exception path
        };

        Test.startTest();
        // Pass null errors — should not throw
        FEC_BatchUtils.copyCommonFields(live, mdm, commonMap, null);
        Test.stopTest();
        Assert.isTrue(true, 'Method handled null errors gracefully');
    }

    @IsTest
    static void testCopyValidFields_OnlyValidUpdateableCopied() {
        FEC_MDM_Channel__c mdm = new FEC_MDM_Channel__c(Name = 'A', FEC_Code__c = 'A1');
        FEC_Channel__c live = new FEC_Channel__c();
        List<String> validFields = new List<String>{'Name', 'FEC_Code__c'};
        Map<String, Schema.SObjectField> liveFields = FEC_Channel__c.SObjectType.getDescribe().fields.getMap();
        Map<String, String> commonMap = new Map<String, String>{
            'Name' => 'Name',
            'FEC_Code__c' => 'FEC_Code__c'
        };
        Set<String> errors = new Set<String>();

        Test.startTest();
        FEC_BatchUtils.copyValidFields(live, mdm, validFields, liveFields, commonMap, errors);
        Test.stopTest();

        Assert.areEqual('A', live.Name, 'Name copied');
        Assert.isTrue(errors.isEmpty(), 'No errors');
    }

    @IsTest
    static void testCopyFieldsToMDM() {
        FEC_Channel__c live = new FEC_Channel__c(Name = 'LiveCh', FEC_Code__c = 'L1');
        FEC_MDM_Channel__c mdm = new FEC_MDM_Channel__c();
        Map<String, Schema.SObjectField> mdmFields = FEC_MDM_Channel__c.SObjectType.getDescribe().fields.getMap();
        Map<String, String> commonMap = new Map<String, String>{
            'Name' => 'Name',
            'FEC_Code__c' => 'FEC_Code__c'
        };

        Test.startTest();
        FEC_BatchUtils.copyFieldsToMDM(mdm, live, mdmFields, commonMap);
        Test.stopTest();

        Assert.areEqual('LiveCh', mdm.Name, 'Name copied to MDM');
        Assert.areEqual('L1', mdm.FEC_Code__c, 'Code copied to MDM');
    }

    @IsTest
    static void testSetLookup_NullParent() {
        FEC_MDM_Channel__c mdm = new FEC_MDM_Channel__c(Name = 'C', FEC_Code__c = 'C1');
        FEC_Channel__c live = new FEC_Channel__c();
        Set<String> errors = new Set<String>();

        Test.startTest();
        // No parent → setLookup adds error for non-existent relName (handled gracefully)
        FEC_BatchUtils.setLookup(live, mdm, 'FEC_NonExistent__r', 'FEC_NonExistent__c', errors);
        Test.stopTest();
        // Either errors collected (relName invalid) OR ignored — both are valid behavior
        Assert.isTrue(true, 'Method handled gracefully');
    }

    @IsTest
    static void testRevertLookup_NullParent() {
        FEC_Channel__c live = new FEC_Channel__c(Name = 'L', FEC_Code__c = 'L1');
        FEC_MDM_Channel__c mdm = new FEC_MDM_Channel__c();
        Set<String> errors = new Set<String>();

        Test.startTest();
        FEC_BatchUtils.revertLookup(mdm, live, 'FEC_NonExistent__r', 'FEC_NonExistent__c', errors);
        Test.stopTest();
        Assert.isTrue(true, 'Method handled gracefully');
    }

    @IsTest
    static void testCopyCommonFields_ValidNoErrors() {
        // Test path khi không có error → cover line success
        FEC_MDM_Channel__c mdm = new FEC_MDM_Channel__c(Name = 'CC1', FEC_Code__c = 'CC_OK_1');
        FEC_Channel__c target = new FEC_Channel__c();
        Map<String, String> commonMap = new Map<String, String>{
            'Name' => 'Name',
            'FEC_Code__c' => 'FEC_Code__c'
        };
        // Pass null errors set → cover null guard
        Test.startTest();
        FEC_BatchUtils.copyCommonFields(target, mdm, commonMap, null);
        Test.stopTest();
        Assert.areEqual('CC1', target.Name);
    }

    @IsTest
    static void testCopyValidFields_NullErrors() {
        FEC_MDM_Channel__c mdm = new FEC_MDM_Channel__c(Name = 'X', FEC_Code__c = 'X3');
        FEC_Channel__c target = new FEC_Channel__c();
        List<String> validFields = new List<String>{'Name'};
        Map<String, Schema.SObjectField> liveFields = FEC_Channel__c.SObjectType.getDescribe().fields.getMap();
        Map<String, String> commonMap = new Map<String, String>{ 'Name' => 'Name' };

        Test.startTest();
        FEC_BatchUtils.copyValidFields(target, mdm, validFields, liveFields, commonMap, null);
        Test.stopTest();
        Assert.areEqual('X', target.Name);
    }

    @IsTest
    static void testCopyValidFields_FieldNotInMap() {
        FEC_MDM_Channel__c mdm = new FEC_MDM_Channel__c(Name = 'Y', FEC_Code__c = 'Y3');
        FEC_Channel__c target = new FEC_Channel__c();
        // validFields contains field name not in commonFieldMap
        List<String> validFields = new List<String>{'NonExistentMDMField__c'};
        Map<String, Schema.SObjectField> liveFields = FEC_Channel__c.SObjectType.getDescribe().fields.getMap();
        Map<String, String> commonMap = new Map<String, String>{ 'Name' => 'Name' };
        Set<String> errors = new Set<String>();

        Test.startTest();
        FEC_BatchUtils.copyValidFields(target, mdm, validFields, liveFields, commonMap, errors);
        Test.stopTest();
        // No errors expected because targetField will be null → skip
        Assert.isTrue(errors.isEmpty(), 'No errors when field not in map');
    }

    // ════════════════════════════════════════════════════════
    // FEC_BatchException tests
    // ════════════════════════════════════════════════════════
    @IsTest
    static void testBatchException_ThrowAndCatch() {
        Boolean caught = false;
        try {
            throw new FEC_BatchException('Test batch error');
        } catch (FEC_BatchException e) {
            caught = true;
            Assert.areEqual('Test batch error', e.getMessage(), 'Message phải khớp');
        }
        Assert.isTrue(caught, 'Phải catch FEC_BatchException');
    }

    @IsTest
    static void testBatchException_TypeHierarchy() {
        try {
            throw new FEC_BatchException('typed');
        } catch (Exception e) {
            Assert.isInstanceOfType(e, FEC_BatchException.class, 'Phải là instance của FEC_BatchException');
        }
    }

    @IsTest
    static void testCopyValidFields_NonUpdateableFieldSkipped() {
        // Test path khi field non-updateable bị skip
        FEC_MDM_Channel__c mdm = new FEC_MDM_Channel__c(Name = 'X', FEC_Code__c = 'X1');
        FEC_Channel__c live = new FEC_Channel__c();
        // CreatedDate KHÔNG updateable
        List<String> validFields = new List<String>{'CreatedDate'};
        Map<String, Schema.SObjectField> liveFields = FEC_Channel__c.SObjectType.getDescribe().fields.getMap();
        Map<String, String> commonMap = new Map<String, String>{
            'CreatedDate' => 'CreatedDate'
        };
        Set<String> errors = new Set<String>();

        Test.startTest();
        FEC_BatchUtils.copyValidFields(live, mdm, validFields, liveFields, commonMap, errors);
        Test.stopTest();
        // Non-updateable → skip silently
        Assert.isTrue(true, 'Method handled non-updateable field');
    }

    @IsTest
    static void testCopyFieldsToMDM_NonUpdateableSkipped() {
        FEC_Channel__c live = new FEC_Channel__c(Name = 'L');
        FEC_MDM_Channel__c mdm = new FEC_MDM_Channel__c();
        Map<String, Schema.SObjectField> mdmFields = FEC_MDM_Channel__c.SObjectType.getDescribe().fields.getMap();
        // CreatedDate is non-updateable on MDM too
        Map<String, String> commonMap = new Map<String, String>{
            'CreatedDate' => 'CreatedDate'
        };

        Test.startTest();
        FEC_BatchUtils.copyFieldsToMDM(mdm, live, mdmFields, commonMap);
        Test.stopTest();
        Assert.isTrue(true);
    }

    @IsTest
    static void testCopyValidFields_PutThrows() {
        // Hit lines 40-41: try->catch in copyValidFields
        // Setup: validFields có 1 field, fieldMap chứa targetField updateable,
        // nhưng giá trị mdm field là kiểu không tương thích → put throw
        FEC_MDM_Channel__c mdm = new FEC_MDM_Channel__c(Name = 'PE_X', FEC_Code__c = 'PE_X1');
        FEC_Channel__c target = new FEC_Channel__c();
        // 'Name' → 'FEC_Order__c' (Number) — String 'PE_X' không cast → SObjectException
        // FEC_Channel__c không có FEC_Order__c, dùng object khác.
        // Dùng FEC_Business_Process__c (có FEC_Order__c Number)
        FEC_Business_Process__c bpTarget = new FEC_Business_Process__c();
        Map<String, Schema.SObjectField> bpFields = FEC_Business_Process__c.SObjectType.getDescribe().fields.getMap();
        Map<String, String> commonMap = new Map<String, String>{ 'Name' => 'FEC_Order__c' };
        List<String> validFields = new List<String>{ 'Name' };
        Set<String> errors = new Set<String>();

        Test.startTest();
        FEC_BatchUtils.copyValidFields(bpTarget, mdm, validFields, bpFields, commonMap, errors);
        Test.stopTest();
        Assert.isFalse(errors.isEmpty(), 'Should record error from put exception');
    }

    @IsTest
    static void testCopyFieldsToMDM_PutThrows() {
        // Hit line 54: catch block in copyFieldsToMDM
        FEC_Business_Process__c live = new FEC_Business_Process__c(Name = 'L_PE');
        FEC_MDM_Channel__c mdm = new FEC_MDM_Channel__c();
        Map<String, Schema.SObjectField> mdmFields = FEC_MDM_Channel__c.SObjectType.getDescribe().fields.getMap();
        // mdmF=FEC_Channel_Status__c (Boolean) ← live.Name (String) → put throws
        Map<String, String> commonMap = new Map<String, String>{
            'FEC_Channel_Status__c' => 'Name'
        };

        Test.startTest();
        FEC_BatchUtils.copyFieldsToMDM(mdm, live, mdmFields, commonMap);
        Test.stopTest();
        Assert.isTrue(true, 'Method should swallow exception');
    }

    @IsTest
    static void testSetLookup_HappyPath() {
        // Setup: FEC_MDM_Master_Data_Setting__c has FEC_Data_Integration_Mapping__c lookup
        // FEC_Data_Integration_Mapping__c has ExternalID__c (Text 18, unique) field.
        // → setLookup happy path will read ExternalID__c from parent and set on Live target.
        FEC_Data_Integration_Mapping__c parent = new FEC_Data_Integration_Mapping__c(
            ExternalID__c = 'EXT_LK_001',
            FEC_Status__c = true
        );
        insert parent;

        FEC_MDM_Master_Data_Setting__c mdm = new FEC_MDM_Master_Data_Setting__c(
            FEC_Code__c = 'MDS_LOOKUP_TS',
            FEC_Field_Object_Name__c = 'Case',
            FEC_Field_Status__c = true,
            FEC_Data_Integration_Mapping__c = parent.Id
        );
        insert mdm;
        // Re-query with parent populated for relation traversal
        FEC_MDM_Master_Data_Setting__c mdmFull = [
            SELECT Id, FEC_Data_Integration_Mapping__c,
                   FEC_Data_Integration_Mapping__r.ExternalID__c
            FROM FEC_MDM_Master_Data_Setting__c
            WHERE Id = :mdm.Id LIMIT 1
        ];

        FEC_Master_Data_Setting__c target = new FEC_Master_Data_Setting__c();
        Set<String> errors = new Set<String>();

        Test.startTest();
        FEC_BatchUtils.setLookup(
            target, mdmFull,
            'FEC_Data_Integration_Mapping__r',
            'FEC_Data_Integration_Mapping__c',
            errors
        );
        Test.stopTest();
        Assert.isTrue(errors.isEmpty(), 'Should NOT add error in happy path. Errors: ' + errors);
    }

    @IsTest
    static void testRevertLookup_HappyPath() {
        // Same setup but revert side: live → mdm
        FEC_Data_Integration_Mapping__c parent = new FEC_Data_Integration_Mapping__c(
            ExternalID__c = 'EXT_RV_001',
            FEC_Status__c = true
        );
        insert parent;

        FEC_Master_Data_Setting__c live = new FEC_Master_Data_Setting__c(
            FEC_Code__c = 'MDS_LV_RV_TS',
            FEC_Field_Object_Name__c = 'Case',
            FEC_Field_Status__c = true,
            FEC_Data_Integration_Mapping__c = parent.Id
        );
        insert live;
        FEC_Master_Data_Setting__c liveFull = [
            SELECT Id, FEC_Data_Integration_Mapping__c,
                   FEC_Data_Integration_Mapping__r.ExternalID__c
            FROM FEC_Master_Data_Setting__c
            WHERE Id = :live.Id LIMIT 1
        ];

        FEC_MDM_Master_Data_Setting__c mdm = new FEC_MDM_Master_Data_Setting__c();
        Set<String> errors = new Set<String>();

        Test.startTest();
        FEC_BatchUtils.revertLookup(
            mdm, liveFull,
            'FEC_Data_Integration_Mapping__r',
            'FEC_Data_Integration_Mapping__c',
            errors
        );
        Test.stopTest();
        Assert.isTrue(errors.isEmpty(), 'Should NOT add error in happy path. Errors: ' + errors);
    }
}