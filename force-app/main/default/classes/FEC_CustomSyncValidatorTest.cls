@isTest
private class FEC_CustomSyncValidatorTest {

    private static String mappingJson = '{"CaseID":"Id","CaseName":"CaseNumber"}';
    private static String dataTypeJson = '{"CaseID":"VARCHAR2","CaseName":"VARCHAR2"}';

    @testSetup
    static void setupData() {
        CustomSyncSetting__c setting = new CustomSyncSetting__c(
            Endpoint__c = 'https://api.test.com',
            ApiKey__c = 'test-key-123',
            LimitQuanitySync__c = 5
        );
        insert setting;
    }

    // ─── Insert ───────────────────────────────────────────────────────────────

    @isTest
    static void testInsertActiveTrue_Valid() {
        CustomSync__c rec = buildRecord(true);
        Test.startTest();
        insert rec;
        Test.stopTest();
        System.assertNotEquals(null, rec.Id);
    }

    @isTest
    static void testInsertActiveFalse_NoValidation() {
        // Active = false → no validation, even without mapping
        CustomSync__c rec = new CustomSync__c(
            Name = 'Test', TableName__c = 'T', SyncTo__c = 'Bix',
            TargetObject__c = 'Case', Active__c = false
        );
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

    // ─── Update: Block edit while Active ──────────────────────────────────────

    @isTest
    static void testUpdateWhileActive_Blocked() {
        CustomSync__c rec = buildRecord(true);
        insert rec;

        rec.TableName__c = 'Changed';
        Test.startTest();
        try {
            update rec;
            System.assert(false, 'Should have thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Cannot edit while Active is true'));
        }
        Test.stopTest();
    }

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
        rec.MappingDataType__c = '{"CaseID":"VARCHAR2"}'; // missing CaseName
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