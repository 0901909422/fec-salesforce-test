/*------------------------------------------------------------
Author:        Duan Nguyen
Company:       Isobar
Description:   Test class for FEC_CustomSyncValidator + CustomSyncTrigger
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/04/29     Kiro                 Rewrite - align with actual trigger/validator logic
2026/05/14     Kiro                 Update - cover 5 new validation rules
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
        CustomSync__c rec = buildRecord(true);
        rec.CaseBusinessCode__c = 'VALID_CODE';
        rec.TargetObject__c = 'Account';
        rec.RequestBodyMapping__c = '{"col1":"Id","col2":"Name"}';
        rec.MappingDataType__c = '{"col1":"VARCHAR2","col2":"VARCHAR2"}';
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
        CustomSync__c rec = buildRecord(true);
        rec.CaseBusinessCode__c = 'VALID_CODE';
        rec.TargetObject__c = 'Case';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testRule1_NullCaseBusinessCode_AnyTarget_Passes() {
        CustomSync__c rec = buildRecord(true);
        rec.CaseBusinessCode__c = null;
        rec.TargetObject__c = 'Account';
        rec.RequestBodyMapping__c = '{"col1":"Id","col2":"Name"}';
        rec.MappingDataType__c = '{"col1":"VARCHAR2","col2":"VARCHAR2"}';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    // ─── Rule 2: ProcessingQuantity must be > 0 ───────────────────────────────

    @isTest
    static void testRule2_ProcessingQuantityZero_Fails() {
        CustomSync__c rec = buildRecord(true);
        rec.ProcessingQuantity__c = 0;
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
        CustomSync__c rec = buildRecord(true);
        rec.ProcessingQuantity__c = -5;
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
        CustomSync__c rec = buildRecord(true);
        rec.ProcessingQuantity__c = null;
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
        CustomSync__c rec = buildRecord(true);
        rec.ProcessingQuantity__c = 10;
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    // ─── Rule 3: RequestBodyMapping vs MappingDataType key comparison ─────────

    @isTest
    static void testRule3_MappingDataTypeHasExtraKeys_Fails() {
        CustomSync__c rec = buildRecord(true);
        rec.MappingDataType__c = '{"col1":"VARCHAR2","col2":"VARCHAR2","ExtraCol":"NUMBER"}';
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
        CustomSync__c rec = buildRecord(true);
        rec.MappingDataType__c = '{"col1":"VARCHAR2"}';
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
        CustomSync__c rec = buildRecord(true);
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testRule3_InvalidJson_Fails() {
        CustomSync__c rec = buildRecord(true);
        rec.RequestBodyMapping__c = '{invalid json}';
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
        CustomSync__c rec = buildRecord(true);
        rec.MappingDataType__c = '';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    // ─── Rule 4: RequestBodyMapping values must be queryable fields on TargetObject ──

    @isTest
    static void testRule4_InvalidFieldOnTargetObject_Fails() {
        CustomSync__c rec = buildRecord(true);
        rec.TargetObject__c = 'Case';
        // "NonExistentField__x" is not a valid field on Case
        rec.RequestBodyMapping__c = '{"col1":"Id","col2":"NonExistentField__x"}';
        rec.MappingDataType__c = '{"col1":"VARCHAR2","col2":"VARCHAR2"}';
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
        CustomSync__c rec = buildRecord(true);
        rec.TargetObject__c = 'Case';
        // "Id", "CaseNumber" are valid fields on Case
        rec.RequestBodyMapping__c = '{"col1":"Id","col2":"CaseNumber"}';
        rec.MappingDataType__c = '{"col1":"VARCHAR2","col2":"VARCHAR2"}';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testRule4_RelationshipField_Valid_Passes() {
        CustomSync__c rec = buildRecord(true);
        rec.TargetObject__c = 'Case';
        // "Owner.Name" is a valid relationship field on Case
        rec.RequestBodyMapping__c = '{"col1":"Id","col2":"Owner.Name"}';
        rec.MappingDataType__c = '{"col1":"VARCHAR2","col2":"VARCHAR2"}';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testRule4_RelationshipField_Invalid_Fails() {
        CustomSync__c rec = buildRecord(true);
        rec.TargetObject__c = 'Case';
        // "Owner.FakeField__c" is not a valid relationship field
        rec.RequestBodyMapping__c = '{"col1":"Id","col2":"Owner.FakeField__c"}';
        rec.MappingDataType__c = '{"col1":"VARCHAR2","col2":"VARCHAR2"}';
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
        CustomSync__c rec = buildRecord(true);
        rec.CaseBusinessCode__c = 'INVALID_CODE_XYZ';
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
        CustomSync__c rec = buildRecord(true);
        rec.CaseBusinessCode__c = 'VALID_CODE';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testRule5_NullCaseBusinessCode_SkipsCheck() {
        CustomSync__c rec = buildRecord(true);
        rec.CaseBusinessCode__c = null;
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    // ─── Trigger: Active false -> true ────────────────────────────────────────

    @isTest
    static void testTrigger_ActivateRecord_Valid() {
        CustomSync__c rec = buildRecord(false);
        insert rec;

        rec.Active__c = true;
        Test.startTest();
        update rec;
        Test.stopTest();

        CustomSync__c updated = [SELECT Active__c FROM CustomSync__c WHERE Id = :rec.Id];
        System.assertEquals(true, updated.Active__c);
    }

    @isTest
    static void testTrigger_ActivateRecord_InvalidQuantity_Fails() {
        CustomSync__c rec = buildRecord(false);
        insert rec;

        rec.Active__c = true;
        rec.ProcessingQuantity__c = 0;
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
        CustomSync__c rec = buildRecord(true);
        insert rec;

        rec.ProcessingQuantity__c = -1;
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
        CustomSync__c rec = buildRecord(true);
        insert rec;

        rec.MappingDataType__c = '{"col1":"VARCHAR2","ExtraCol":"NUMBER"}';
        Test.startTest();
        try {
            update rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('MappingDataType has extra keys'));
        }
        Test.stopTest();
    }

    @isTest
    static void testTrigger_EditNonValidatedField_WhileActive_Passes() {
        CustomSync__c rec = buildRecord(true);
        insert rec;

        rec.TableName__c = 'NEW_TABLE';
        Test.startTest();
        update rec;
        Test.stopTest();

        CustomSync__c updated = [SELECT TableName__c FROM CustomSync__c WHERE Id = :rec.Id];
        System.assertEquals('NEW_TABLE', updated.TableName__c);
    }

    @isTest
    static void testTrigger_Deactivate_NoValidation() {
        CustomSync__c rec = buildRecord(true);
        insert rec;

        rec.Active__c = false;
        Test.startTest();
        update rec;
        Test.stopTest();

        CustomSync__c updated = [SELECT Active__c FROM CustomSync__c WHERE Id = :rec.Id];
        System.assertEquals(false, updated.Active__c);
    }

    @isTest
    static void testTrigger_EditWhileInactive_NoValidation() {
        CustomSync__c rec = buildRecord(false);
        insert rec;

        rec.ProcessingQuantity__c = -99;
        Test.startTest();
        update rec;
        Test.stopTest();

        CustomSync__c updated = [SELECT ProcessingQuantity__c FROM CustomSync__c WHERE Id = :rec.Id];
        System.assertEquals(-99, updated.ProcessingQuantity__c);
    }

    // ─── Bulk test ────────────────────────────────────────────────────────────

    @isTest
    static void testBulkInsert_Valid() {
        List<CustomSync__c> records = new List<CustomSync__c>();
        for (Integer i = 0; i < 50; i++) {
            records.add(buildRecord(true));
        }
        Test.startTest();
        insert records;
        Test.stopTest();
        System.assertEquals(50, [SELECT COUNT() FROM CustomSync__c WHERE Id IN :records]);
    }

    // ─── Helper ───────────────────────────────────────────────────────────────

    private static CustomSync__c buildRecord(Boolean active) {
        return new CustomSync__c(
            Name = 'Test Sync',
            TableName__c = 'BIX_TEST',
            CaseBusinessCode__c = 'VALID_CODE',
            ProcessingQuantity__c = 10,
            Active__c = active,
            SyncTo__c = 'Bix',
            TargetObject__c = 'Case',
            RequestBodyMapping__c = validMappingJson,
            MappingDataType__c = validDataTypeJson,
            PkColumn__c = 'PXEXTRACTDATETIME'
        );
    }
}
