/*------------------------------------------------------------
Author:        Duan Nguyen
Company:       Isobar
Description:   Test class for FEC_CustomSyncValidator + CustomSyncTrigger
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/04/29     Duan Nguyen          Rewrite - align with actual trigger/validator logic
2026/05/14     Duan Nguyen          Update - cover 5 new validation rules
2026/06/05     Duan Nguyen          Add coverage: Static Map Value validation rules
2026/06/11     Duan Nguyen          Add coverage: Invalid TargetObject, MappingDataType invalid JSON, StaticMapValue key not in mapping
------------------------------------------------------------*/
@isTest
private class FEC_CustomSyncValidatorTest {

    private static String validMappingJson = '{"col1":"Id","col2":"CaseNumber"}';
    private static String validDataTypeJson = '{"col1":"VARCHAR2","col2":"VARCHAR2"}';

    @testSetup
    static void setupData() {
        // Setup CustomSyncSetting (still needed for org)
        CustomSyncSetting__c setting = CustomSyncSetting__c.getOrgDefaults();
        setting.Endpoint__c = 'https://api.test.com';
        setting.ApiKey__c = 'test-key-123';
        setting.LimitQuanitySync__c = 5;
        setting.EmailReport__c = 'test@gmail.com';
        upsert setting;

        // Create FEC_Business_Process__c for Rule 5
        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            FEC_Code__c = 'VALID_CODE'
        );
        insert bp;
    }

    // ─── Rule 1: CaseBusinessCode != null => TargetObject must be Case ────────

    @isTest
    static void testRule1_CaseBusinessCodeWithNonCaseTarget_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Case_Business_Code__c = 'VALID_CODE';
        rec.FEC_Target_Object__c = 'Account';
        rec.FEC_Request_Body_Mapping__c = '{"col1":"Id","col2":"Name"}';
        rec.FEC_Mapping_Data_Type__c = '{"col1":"VARCHAR2","col2":"VARCHAR2"}';
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('CaseBusinessCode is only applicable when Target Object is "Case"'));
        }
        Test.stopTest();
    }

    @isTest
    static void testRule1_CaseBusinessCodeWithCaseTarget_Passes() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Case_Business_Code__c = 'VALID_CODE';
        rec.FEC_Target_Object__c = 'Case';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testRule1_NullCaseBusinessCode_AnyTarget_Passes() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Case_Business_Code__c = null;
        rec.FEC_Target_Object__c = 'Account';
        rec.FEC_Request_Body_Mapping__c = '{"col1":"Id","col2":"Name"}';
        rec.FEC_Mapping_Data_Type__c = '{"col1":"VARCHAR2","col2":"VARCHAR2"}';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    // ─── Rule 2: ProcessingQuantity must be > 0 ───────────────────────────────

    @isTest
    static void testRule2_ProcessingQuantityZero_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Processing_Quantity__c = 0;
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('ProcessingQuantity must be greater than 0'));
        }
        Test.stopTest();
    }

    @isTest
    static void testRule2_ProcessingQuantityNegative_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Processing_Quantity__c = -5;
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('ProcessingQuantity must be greater than 0'));
        }
        Test.stopTest();
    }

    @isTest
    static void testRule2_ProcessingQuantityNull_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Processing_Quantity__c = null;
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('ProcessingQuantity must be greater than 0'));
        }
        Test.stopTest();
    }

    @isTest
    static void testRule2_ProcessingQuantityPositive_Passes() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Processing_Quantity__c = 10;
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    // ─── Rule 3: RequestBodyMapping vs MappingDataType key comparison ─────────

    @isTest
    static void testRule3_MappingDataTypeHasExtraKeys_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Mapping_Data_Type__c = '{"col1":"VARCHAR2","col2":"VARCHAR2","ExtraCol":"NUMBER"}';
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('MappingDataType has extra keys not in RequestBodyMapping'));
        }
        Test.stopTest();
    }

    @isTest
    static void testRule3_MappingDataTypeMissingKeys_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Mapping_Data_Type__c = '{"col1":"VARCHAR2"}';
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('MappingDataType is missing keys from RequestBodyMapping'));
        }
        Test.stopTest();
    }

    @isTest
    static void testRule3_KeysMatch_Passes() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testRule3_InvalidJson_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Request_Body_Mapping__c = '{invalid json}';
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Invalid JSON format'));
        }
        Test.stopTest();
    }

    @isTest
    static void testRule3_BlankMappingDataType_SkipsCheck() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Mapping_Data_Type__c = '';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    // ─── Rule 4: RequestBodyMapping values must be queryable fields on TargetObject ──

    @isTest
    static void testRule4_InvalidFieldOnTargetObject_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Target_Object__c = 'Case';
        // "NonExistentField__x" is not a valid field on Case
        rec.FEC_Request_Body_Mapping__c = '{"col1":"Id","col2":"NonExistentField__x"}';
        rec.FEC_Mapping_Data_Type__c = '{"col1":"VARCHAR2","col2":"VARCHAR2"}';
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Invalid fields in RequestBodyMapping'));
        }
        Test.stopTest();
    }

    @isTest
    static void testRule4_ValidFieldsOnTargetObject_Passes() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Target_Object__c = 'Case';
        // "Id", "CaseNumber" are valid fields on Case
        rec.FEC_Request_Body_Mapping__c = '{"col1":"Id","col2":"CaseNumber"}';
        rec.FEC_Mapping_Data_Type__c = '{"col1":"VARCHAR2","col2":"VARCHAR2"}';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testRule4_RelationshipField_Valid_Passes() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Target_Object__c = 'Case';
        // "Owner.Name" is a valid relationship field on Case
        rec.FEC_Request_Body_Mapping__c = '{"col1":"Id","col2":"Owner.Name"}';
        rec.FEC_Mapping_Data_Type__c = '{"col1":"VARCHAR2","col2":"VARCHAR2"}';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testRule4_RelationshipField_Invalid_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Target_Object__c = 'Case';
        // "Owner.FakeField__c" is not a valid relationship field
        rec.FEC_Request_Body_Mapping__c = '{"col1":"Id","col2":"Owner.FakeField__c"}';
        rec.FEC_Mapping_Data_Type__c = '{"col1":"VARCHAR2","col2":"VARCHAR2"}';
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Invalid fields in RequestBodyMapping'));
        }
        Test.stopTest();
    }

    // ─── Rule 5: CaseBusinessCode must exist in FEC_Business_Process__c ───────

    @isTest
    static void testRule5_InvalidCaseBusinessCode_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Case_Business_Code__c = 'INVALID_CODE_XYZ';
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('does not exist in FEC_Business_Process__c'));
        }
        Test.stopTest();
    }

    @isTest
    static void testRule5_ValidCaseBusinessCode_Passes() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Case_Business_Code__c = 'VALID_CODE';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testRule5_NullCaseBusinessCode_SkipsCheck() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Case_Business_Code__c = null;
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    // ─── Trigger: Active false -> true ────────────────────────────────────────

    @isTest
    static void testTrigger_ActivateRecord_Valid() {
        FEC_Custom_Sync__c rec = buildRecord(false);
        insert rec;

        rec.FEC_Active__c = true;
        Test.startTest();
        update rec;
        Test.stopTest();

        FEC_Custom_Sync__c updated = [SELECT FEC_Active__c FROM FEC_Custom_Sync__c WHERE Id = :rec.Id];
        System.assertEquals(true, updated.FEC_Active__c);
    }

    @isTest
    static void testTrigger_ActivateRecord_InvalidQuantity_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(false);
        insert rec;

        rec.FEC_Active__c = true;
        rec.FEC_Processing_Quantity__c = 0;
        Test.startTest();
        try {
            update rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('ProcessingQuantity must be greater than 0'));
        }
        Test.stopTest();
    }

    // ─── Trigger: Edit validated fields while Active = true ───────────────────

    @isTest
    static void testTrigger_EditWhileActive_InvalidChange_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        insert rec;

        rec.FEC_Processing_Quantity__c = -1;
        Test.startTest();
        try {
            update rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('ProcessingQuantity must be greater than 0'));
        }
        Test.stopTest();
    }

    @isTest
    static void testTrigger_EditWhileActive_MismatchMapping_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        insert rec;

        rec.FEC_Mapping_Data_Type__c = '{"col1":"VARCHAR2","ExtraCol":"NUMBER"}';
        Test.startTest();
        try {
            update rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) { 
        }
        Test.stopTest();
    }

    @isTest
    static void testTrigger_EditNonValidatedField_WhileActive_Passes() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        insert rec;

        rec.FEC_Table_Name__c = 'NEW_TABLE';
        Test.startTest();
        update rec;
        Test.stopTest();

        FEC_Custom_Sync__c updated = [SELECT FEC_Table_Name__c FROM FEC_Custom_Sync__c WHERE Id = :rec.Id];
        System.assertEquals('NEW_TABLE', updated.FEC_Table_Name__c);
    }

    @isTest
    static void testTrigger_Deactivate_NoValidation() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        insert rec;

        rec.FEC_Active__c = false;
        Test.startTest();
        update rec;
        Test.stopTest();

        FEC_Custom_Sync__c updated = [SELECT FEC_Active__c FROM FEC_Custom_Sync__c WHERE Id = :rec.Id];
        System.assertEquals(false, updated.FEC_Active__c);
    }

    @isTest
    static void testTrigger_EditWhileInactive_NoValidation() {
        FEC_Custom_Sync__c rec = buildRecord(false);
        insert rec;

        rec.FEC_Processing_Quantity__c = -99;
        Test.startTest();
        update rec;
        Test.stopTest();

        FEC_Custom_Sync__c updated = [SELECT FEC_Processing_Quantity__c FROM FEC_Custom_Sync__c WHERE Id = :rec.Id];
        System.assertEquals(-99, updated.FEC_Processing_Quantity__c);
    }

    // ─── Rule 6: Static Map Value validation ─────────────────────────────────

    @isTest
    static void testStaticMapValue_InvalidJson_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Static_Map_Value__c = '{invalid json}';
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Invalid JSON format in Static Map Value'));
        }
        Test.stopTest();
    }

    @isTest
    static void testStaticMapValue_KeyWithoutSuffix_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Static_Map_Value__c = '{"BadKey":"value"}';
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('must end with "__g" suffix'));
        }
        Test.stopTest();
    }

    @isTest
    static void testStaticMapValue_ValidKeys_Passes() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Static_Map_Value__c = '{"ObjectClass__g":"NAME123"}';
        rec.FEC_Request_Body_Mapping__c = '{"col1":"Id","col2":"CaseNumber","col3":"ObjectClass__g"}';
        rec.FEC_Mapping_Data_Type__c = '{"col1":"VARCHAR2","col2":"VARCHAR2","col3":"VARCHAR2"}';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testStaticMapValue_NumberTypeMismatch_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Request_Body_Mapping__c = '{"col1":"Id","col2":"ObjectClass__g"}';
        rec.FEC_Mapping_Data_Type__c = '{"col1":"VARCHAR2","col2":"NUMBER"}';
        rec.FEC_Static_Map_Value__c = '{"ObjectClass__g":"NotANumber"}';
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('is not compatible with DataType NUMBER'));
        }
        Test.stopTest();
    }

    @isTest
    static void testStaticMapValue_NumberTypeValid_Passes() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Request_Body_Mapping__c = '{"col1":"Id","col2":"ObjectClass__g"}';
        rec.FEC_Mapping_Data_Type__c = '{"col1":"VARCHAR2","col2":"NUMBER"}';
        rec.FEC_Static_Map_Value__c = '{"ObjectClass__g":123}';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testStaticMapValue_TimestampTypeMismatch_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Request_Body_Mapping__c = '{"col1":"Id","col2":"ObjectClass__g"}';
        rec.FEC_Mapping_Data_Type__c = '{"col1":"VARCHAR2","col2":"TIMESTAMP(6)"}';
        rec.FEC_Static_Map_Value__c = '{"ObjectClass__g":12345}';
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('must be a date/time string for DataType TIMESTAMP'));
        }
        Test.stopTest();
    }

    @isTest
    static void testStaticMapValue_TimestampInvalidString_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Request_Body_Mapping__c = '{"col1":"Id","col2":"time__g"}';
        rec.FEC_Mapping_Data_Type__c = '{"col1":"VARCHAR2","col2":"TIMESTAMP(6)"}';
        rec.FEC_Static_Map_Value__c = '{"time__g":"TriggerClass"}';
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('is not a valid date/time format for DataType TIMESTAMP'));
        }
        Test.stopTest();
    }

    @isTest
    static void testStaticMapValue_TimestampValidFormat_Passes() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Request_Body_Mapping__c = '{"col1":"Id","col2":"time__g"}';
        rec.FEC_Mapping_Data_Type__c = '{"col1":"VARCHAR2","col2":"TIMESTAMP(6)"}';
        rec.FEC_Static_Map_Value__c = '{"time__g":"2024-01-15 10:30:00"}';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testStaticMapValue_TimestampSlashFormat_Passes() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Request_Body_Mapping__c = '{"col1":"Id","col2":"time__g"}';
        rec.FEC_Mapping_Data_Type__c = '{"col1":"VARCHAR2","col2":"TIMESTAMP"}';
        rec.FEC_Static_Map_Value__c = '{"time__g":"12/12/2020"}';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testStaticMapValue_Null_SkipsCheck() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Static_Map_Value__c = null;
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    // ─── Rule 7: Additional Conditions must start with AND or OR ─────────────

    @isTest
    static void testAdditionalConditions_StartsWithAND_Passes() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Additional_Conditions__c = 'AND Status = \'New\'';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testAdditionalConditions_StartsWithOR_Passes() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Additional_Conditions__c = 'OR Status = \'Closed\'';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testAdditionalConditions_StartsWithInvalid_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Additional_Conditions__c = 'Status = \'New\'';
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Additional Conditions must start with "AND" or "OR"'));
        }
        Test.stopTest();
    }

    @isTest
    static void testAdditionalConditions_Null_Passes() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Additional_Conditions__c = null;
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testAdditionalConditions_Blank_Passes() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Additional_Conditions__c = '';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testAdditionalConditions_CaseInsensitive_Passes() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Additional_Conditions__c = 'and Status = \'New\'';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    // ─── Bulk test ────────────────────────────────────────────────────────────

    @isTest
    static void testBulkInsert_Valid() {
        List<FEC_Custom_Sync__c> records = new List<FEC_Custom_Sync__c>();
        for (Integer i = 0; i < 50; i++) {
            records.add(buildRecord(true));
        }
        Test.startTest();
        insert records;
        Test.stopTest();
        System.assertEquals(50, [SELECT COUNT() FROM FEC_Custom_Sync__c WHERE Id IN :records]);
    }

    // ─── Rule 4: Invalid TargetObject name ───────────────────────────────────

    @isTest
    static void testRule4_InvalidTargetObject_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Case_Business_Code__c = null;
        rec.FEC_Target_Object__c = 'NonExistentObject__x';
        rec.FEC_Request_Body_Mapping__c = '{"col1":"Id"}';
        rec.FEC_Mapping_Data_Type__c = '{"col1":"VARCHAR2"}';
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Invalid fields in RequestBodyMapping'));
        }
        Test.stopTest();
    }

    // ─── Rule 3: MappingDataType invalid JSON ────────────────────────────────

    @isTest
    static void testRule3_MappingDataTypeInvalidJson_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Mapping_Data_Type__c = '{not valid json!!!}';
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Invalid JSON format'));
        }
        Test.stopTest();
    }

    // ─── Static Map Value: key not referenced in RequestBodyMapping ──────────

    @isTest
    static void testStaticMapValue_KeyNotInMapping_StillPasses() {
        // StaticMapValue has a key that's not used in mapping - validator only checks __g suffix and type compatibility
        FEC_Custom_Sync__c rec = buildRecord(true);
        rec.FEC_Static_Map_Value__c = '{"UnusedKey__g":"someValue"}';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    // ─── Trigger: Update non-active record, then activate with invalid data ──

    @isTest
    static void testTrigger_InsertInactive_ThenActivateWithInvalidMapping_Fails() {
        FEC_Custom_Sync__c rec = buildRecord(false);
        insert rec;

        rec.FEC_Active__c = true;
        rec.FEC_Request_Body_Mapping__c = '{invalid}';
        Test.startTest();
        try {
            update rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Invalid JSON format'));
        }
        Test.stopTest();
    }

    // ─── Helper ───────────────────────────────────────────────────────────────

    private static FEC_Custom_Sync__c buildRecord(Boolean active) {
        return new FEC_Custom_Sync__c(
            Name = 'Test Sync',
            FEC_Table_Name__c = 'BIX_TEST',
            FEC_Case_Business_Code__c = 'VALID_CODE',
            FEC_Processing_Quantity__c = 10,
            FEC_Active__c = active,
            FEC_Sync_To__c = 'Bix',
            FEC_Target_Object__c = 'Case',
            FEC_Request_Body_Mapping__c = validMappingJson,
            FEC_Mapping_Data_Type__c = validDataTypeJson
        );
    }
}