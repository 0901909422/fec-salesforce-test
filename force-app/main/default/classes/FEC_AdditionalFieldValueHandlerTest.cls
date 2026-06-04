/**
 * @description Tests for FEC_AdditionalFieldValueTriggerHandler — duplicate detection logic.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM
 */
@IsTest
private class FEC_AdditionalFieldValueHandlerTest {

    @testSetup
    static void setup() {
        FEC_MDM_Additional_Field__c af = new FEC_MDM_Additional_Field__c(
            Name = 'TestField',
            FEC_Unique_ID__c = 'AFV_1',
            FEC_Type__c = 'List',
            FEC_Name_VN__c = 'Trường'
        );
        insert af;

        // 1 existing list value
        insert new FEC_MDM_Additional_Field_List_Value__c(
            Name = 'Option1',
            FEC_Code__c = 'OPT_1',
            FEC_Name_VN__c = 'Giá trị 1',
            FEC_Additional_Field__c = af.Id,
            FEC_Order__c = 1
        );
    }

    @IsTest
    static void testInsert_DuplicateCode_BlockedByTrigger() {
        Id parentId = [SELECT Id FROM FEC_MDM_Additional_Field__c LIMIT 1].Id;

        FEC_MDM_Additional_Field_List_Value__c dup = new FEC_MDM_Additional_Field_List_Value__c(
            Name = 'OptionDup',
            FEC_Code__c = 'OPT_1', // duplicate
            FEC_Name_VN__c = 'Trùng',
            FEC_Additional_Field__c = parentId,
            FEC_Order__c = 2
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(dup, false);
        Test.stopTest();

        Assert.isFalse(sr.isSuccess(), 'Insert duplicate phải fail');
    }

    @IsTest
    static void testInsert_DifferentParent_AllowedSameCode() {
        // Tạo parent thứ 2 → cùng code OK
        FEC_MDM_Additional_Field__c af2 = new FEC_MDM_Additional_Field__c(
            Name = 'TestField2',
            FEC_Unique_ID__c = 'AFV_2',
            FEC_Type__c = 'List',
            FEC_Name_VN__c = 'Trường 2'
        );
        insert af2;

        FEC_MDM_Additional_Field_List_Value__c rec = new FEC_MDM_Additional_Field_List_Value__c(
            Name = 'Option1Other',
            FEC_Code__c = 'OPT_1', // same code, different parent
            FEC_Name_VN__c = 'Khác parent',
            FEC_Additional_Field__c = af2.Id,
            FEC_Order__c = 1
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(rec, false);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Cùng code khác parent phải insert được');
    }

    @IsTest
    static void testInsert_SameTransactionDuplicate_Blocked() {
        Id parentId = [SELECT Id FROM FEC_MDM_Additional_Field__c LIMIT 1].Id;

        List<FEC_MDM_Additional_Field_List_Value__c> dups = new List<FEC_MDM_Additional_Field_List_Value__c>{
            new FEC_MDM_Additional_Field_List_Value__c(
                Name = 'A', FEC_Code__c = 'OPT_NEW', FEC_Name_VN__c = 'A',
                FEC_Additional_Field__c = parentId, FEC_Order__c = 5
            ),
            new FEC_MDM_Additional_Field_List_Value__c(
                Name = 'B', FEC_Code__c = 'OPT_NEW', FEC_Name_VN__c = 'B',
                FEC_Additional_Field__c = parentId, FEC_Order__c = 6
            )
        };

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(dups, false);
        Test.stopTest();

        // 1 success, 1 fail (duplicate within transaction)
        Assert.isTrue(results[0].isSuccess(), 'Record đầu insert OK');
        Assert.isFalse(results[1].isSuccess(), 'Record thứ 2 cùng code phải fail');
    }

    @IsTest
    static void testUpdate_ChangeCodeToExisting_Blocked() {
        FEC_MDM_Additional_Field__c af = [SELECT Id FROM FEC_MDM_Additional_Field__c LIMIT 1];

        // Tạo thêm 1 record OPT_2
        FEC_MDM_Additional_Field_List_Value__c second = new FEC_MDM_Additional_Field_List_Value__c(
            Name = 'Option2',
            FEC_Code__c = 'OPT_2',
            FEC_Name_VN__c = 'Giá trị 2',
            FEC_Additional_Field__c = af.Id,
            FEC_Order__c = 3
        );
        insert second;

        // Update OPT_2 thành OPT_1 → trùng với existing
        second.FEC_Code__c = 'OPT_1';

        Test.startTest();
        Database.SaveResult sr = Database.update(second, false);
        Test.stopTest();

        Assert.isFalse(sr.isSuccess(), 'Update sang code đã tồn tại phải fail');
    }

    @IsTest
    static void testUpdate_NoCodeChange_NotValidated() {
        FEC_MDM_Additional_Field_List_Value__c existing = [SELECT Id, Name FROM FEC_MDM_Additional_Field_List_Value__c LIMIT 1];
        existing.Name = 'NewName';

        Test.startTest();
        Database.SaveResult sr = Database.update(existing, false);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Không đổi Code → bỏ qua validation');
    }
}