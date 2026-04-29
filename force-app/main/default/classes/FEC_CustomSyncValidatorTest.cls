/*------------------------------------------------------------
Author:        Duan Nguyen
Company:       Isobar
Description:   Test class for FEC_CustomSyncValidator + CustomSyncTrigger
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/04/29     Kiro                 Rewrite - align with actual trigger/validator logic, add coverage
------------------------------------------------------------*/
@isTest
private class FEC_CustomSyncValidatorTest {

    private static String mappingJson = '{"CaseID":"Id","CaseName":"CaseNumber"}';
    private static String dataTypeJson = '{"CaseID":"VARCHAR2","CaseName":"VARCHAR2"}';

    @testSetup
    static void setupData() {
        CustomSyncSetting__c setting = CustomSyncSetting__c.getOrgDefaults();
        setting.Endpoint__c = 'https://api.test.com';
        setting.ApiKey__c = 'test-key-123';
        setting.LimitQuanitySync__c = 5;
        setting.EmailReport__c = 'asd@gmail.com';
        upsert setting;
    }

    // ─── Insert: Active = true ────────────────────────────────────────────────

    @isTest
    static void testInsertActiveTrue_Valid() {
        CustomSync__c rec = buildRecord(true);
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    } 

    @isTest
    static void testInsertActiveTrue_MissingSettingFails() {
        delete [SELECT Id FROM CustomSyncSetting__c];
        CustomSync__c rec = buildRecord(true);
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('CustomSyncSetting is incomplete'));
        }
        Test.stopTest();
    }

    @isTest
    static void testInsertActiveTrue_MismatchedKeysFails() {
        CustomSync__c rec = buildRecord(true);
        rec.MappingDataType__c = '{"CaseID":"VARCHAR2","ExtraKey":"NUMBER"}';
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('MappingDataType is missing keys')
                       || e.getMessage().contains('RequestBodyMapping is missing keys'));
        }
        Test.stopTest();
    }

    @isTest
    static void testInsertActiveTrue_InvalidJsonFails() {
        CustomSync__c rec = buildRecord(true);
        rec.RequestBodyMapping__c = '{bad json}';
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
    static void testInsertActiveTrue_BothKeysMismatchFails() {
        CustomSync__c rec = buildRecord(true);
        rec.MappingDataType__c = '{"CaseID":"VARCHAR2","ExtraKey":"NUMBER"}';
        Test.startTest();
        try {
            insert rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            String msg = e.getMessage();
            System.assert(msg.contains('MappingDataType is missing keys')
                       || msg.contains('RequestBodyMapping is missing keys'),
                       'Expected key mismatch error, got: ' + msg);
        }
        Test.stopTest();
    }

    @isTest
    static void testInsertActiveTrue_BlankMappingDataType_NoKeyCheck() {
        CustomSync__c rec = buildRecord(true);
        rec.MappingDataType__c = '';
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testInsertActiveTrue_NullMappingDataType_NoKeyCheck() {
        CustomSync__c rec = buildRecord(true);
        rec.MappingDataType__c = null;
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testInsertActiveTrue_BulkRecords() {
        List<CustomSync__c> records = new List<CustomSync__c>();
        for (Integer i = 0; i < 5; i++) {
            records.add(buildRecord(true));
        }
        Test.startTest();
        insert records;
        Test.stopTest();
        System.assertEquals(5, [SELECT COUNT() FROM CustomSync__c WHERE Id IN :records]);
    }

    // ─── Update: Activate (false → true) ─────────────────────────────────────

    @isTest
    static void testActivate_Valid() {
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
    static void testActivate_MismatchedKeysFails() {
        CustomSync__c rec = buildRecord(false);
        rec.MappingDataType__c = '{"CaseID":"VARCHAR2"}';
        insert rec;

        rec.Active__c = true;
        Test.startTest();
        try {
            update rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('MappingDataType is missing keys'));
        }
        Test.stopTest();
    }

    @isTest
    static void testActivate_MissingSettingFails() {
        CustomSync__c rec = buildRecord(false);
        insert rec;

        delete [SELECT Id FROM CustomSyncSetting__c];

        rec.Active__c = true;
        Test.startTest();
        try {
            update rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('CustomSyncSetting is incomplete'));
        }
        Test.stopTest();
    }

    // ─── Update: Deactivate + Edit while inactive ─────────────────────────────

    @isTest
    static void testDeactivate_Allowed() {
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
    static void testEditWhileInactive_Allowed() {
        CustomSync__c rec = buildRecord(false);
        insert rec;

        rec.TableName__c = 'Changed';
        Test.startTest();
        update rec;
        Test.stopTest();

        CustomSync__c updated = [SELECT TableName__c FROM CustomSync__c WHERE Id = :rec.Id];
        System.assertEquals('Changed', updated.TableName__c);
    }

    @isTest
    static void testEditWhileActive_NoReactivation_Allowed() {
        CustomSync__c rec = buildRecord(true);
        insert rec;

        rec.TableName__c = 'Changed';
        Test.startTest();
        update rec;
        Test.stopTest();

        CustomSync__c updated = [SELECT TableName__c FROM CustomSync__c WHERE Id = :rec.Id];
        System.assertEquals('Changed', updated.TableName__c);
    }

    // ─── Direct validator call ────────────────────────────────────────────────

    @isTest
    static void testValidateDirectly_ValidRecord() {
        CustomSync__c rec = buildRecord(true);
        insert rec;

        rec = [SELECT Id, RequestBodyMapping__c, MappingDataType__c, Active__c FROM CustomSync__c WHERE Id = :rec.Id];

        Test.startTest();
        FEC_CustomSyncValidator.validate(new List<CustomSync__c>{ rec });
        Test.stopTest();
    }

    // ─── Helper ───────────────────────────────────────────────────────────────

    private static CustomSync__c buildRecord(Boolean active) {
        return new CustomSync__c(
            Name = 'Test Sync',
            TableName__c = 'BIX_TEST',
            WhatSync__c = 'Phone Update',
            ProcessingQuantity__c = 10,
            Active__c = active,
            SyncTo__c = 'Bix',
            TargetObject__c = 'Case',
            RequestBodyMapping__c = mappingJson,
            MappingDataType__c = dataTypeJson,
            PkColumn__c = 'PXEXTRACTDATETIME'
        );
    }
}