/**
 * @description Tests for FEC_AdditionalFieldValueTriggerHandler — duplicate code check.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM
 */
@IsTest
private class FEC_AdditionalFieldValueHandlerExtraTest {

    @testSetup
    static void setup() {
        FEC_MDM_Additional_Field__c af = new FEC_MDM_Additional_Field__c(
            FEC_Unique_ID__c = 'AF_AVH_1',
            FEC_Type__c = 'List',
            FEC_Name_VN__c = 'TenAVH',
            FEC_Field_Status__c = true
        );
        insert af;

        insert new FEC_MDM_Additional_Field_List_Value__c(
            Name = 'V1', FEC_Name_VN__c = 'GT1',
            FEC_Code__c = 'CODE_AVH_1',
            FEC_Additional_Field__c = af.Id, FEC_Order__c = 1
        );
    }

    @IsTest
    static void testBeforeInsert_DuplicateCodeFails() {
        Id afId = [SELECT Id FROM FEC_MDM_Additional_Field__c LIMIT 1].Id;
        FEC_MDM_Additional_Field_List_Value__c dup = new FEC_MDM_Additional_Field_List_Value__c(
            Name = 'V2', FEC_Name_VN__c = 'GT2',
            FEC_Code__c = 'CODE_AVH_1', // duplicate
            FEC_Additional_Field__c = afId, FEC_Order__c = 2
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(dup, false);
        Test.stopTest();

        Assert.isFalse(sr.isSuccess(), 'Duplicate code should fail insert');
    }

    @IsTest
    static void testBeforeInsert_UniqueCodeSucceeds() {
        Id afId = [SELECT Id FROM FEC_MDM_Additional_Field__c LIMIT 1].Id;
        FEC_MDM_Additional_Field_List_Value__c v = new FEC_MDM_Additional_Field_List_Value__c(
            Name = 'V_NEW', FEC_Name_VN__c = 'GT_NEW',
            FEC_Code__c = 'CODE_NEW_1',
            FEC_Additional_Field__c = afId, FEC_Order__c = 3
        );

        Test.startTest();
        insert v;
        Test.stopTest();
        Assert.isNotNull(v.Id);
    }

    @IsTest
    static void testBulkInsert_DupInSameTransaction() {
        Id afId = [SELECT Id FROM FEC_MDM_Additional_Field__c LIMIT 1].Id;
        List<FEC_MDM_Additional_Field_List_Value__c> recs = new List<FEC_MDM_Additional_Field_List_Value__c>{
            new FEC_MDM_Additional_Field_List_Value__c(
                Name = 'V3', FEC_Name_VN__c = 'GT3',
                FEC_Code__c = 'CODE_BULK_1',
                FEC_Additional_Field__c = afId, FEC_Order__c = 4
            ),
            new FEC_MDM_Additional_Field_List_Value__c(
                Name = 'V4', FEC_Name_VN__c = 'GT4',
                FEC_Code__c = 'CODE_BULK_1', // duplicate trong cùng transaction
                FEC_Additional_Field__c = afId, FEC_Order__c = 5
            )
        };

        Test.startTest();
        Database.SaveResult[] results = Database.insert(recs, false);
        Test.stopTest();

        Assert.isTrue(results[0].isSuccess(), 'First record success');
        Assert.isFalse(results[1].isSuccess(), 'Second duplicate fails');
    }

    @IsTest
    static void testUpdate_NoCodeChange_NoValidation() {
        FEC_MDM_Additional_Field_List_Value__c v = [SELECT Id, Name FROM FEC_MDM_Additional_Field_List_Value__c LIMIT 1];
        v.Name = 'Updated Name';

        Test.startTest();
        update v;
        Test.stopTest();
        Assert.areEqual('Updated Name', [SELECT Name FROM FEC_MDM_Additional_Field_List_Value__c WHERE Id = :v.Id].Name);
    }

    @IsTest
    static void testUpdate_CodeChangeToDuplicateFails() {
        FEC_MDM_Additional_Field__c af = [SELECT Id FROM FEC_MDM_Additional_Field__c LIMIT 1];

        // Insert another value with different code
        FEC_MDM_Additional_Field_List_Value__c v2 = new FEC_MDM_Additional_Field_List_Value__c(
            Name = 'V5', FEC_Name_VN__c = 'GT5',
            FEC_Code__c = 'CODE_AVH_2',
            FEC_Additional_Field__c = af.Id, FEC_Order__c = 6
        );
        insert v2;

        // Try to change code of v2 to existing CODE_AVH_1
        v2.FEC_Code__c = 'CODE_AVH_1';

        Test.startTest();
        Database.SaveResult sr = Database.update(v2, false);
        Test.stopTest();

        Assert.isFalse(sr.isSuccess(), 'Update to duplicate code should fail');
    }
}