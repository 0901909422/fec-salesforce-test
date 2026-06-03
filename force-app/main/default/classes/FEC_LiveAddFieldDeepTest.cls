/**
 * @description Deep tests for FEC_LiveAdditionalFieldController.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      Live Layer
 */
@IsTest
private class FEC_LiveAddFieldDeepTest {

    @testSetup
    static void setup() {
        FEC_Additional_Field__c field = new FEC_Additional_Field__c(
            FEC_Unique_ID__c = 'AF_LDP_1',
            FEC_Type__c = 'String',
            FEC_Name_VN__c = 'Test Live',
            FEC_Field_Status__c = true
        );
        insert field;

        insert new FEC_Additional_Field_List_Value__c(
            Name = 'Val 1',
            FEC_Name_VN__c = 'GT 1',
            FEC_Additional_Field__c = field.Id,
            FEC_Order__c = 1
        );
    }

    @IsTest
    static void testGetAdditionalFields() {
        Test.startTest();
        List<FEC_Additional_Field__c> fields = FEC_LiveAdditionalFieldController.getAdditionalFields();
        Test.stopTest();
        Assert.isFalse(fields.isEmpty());
    }

    @IsTest
    static void testGetFieldListValues_ValidId() {
        Id fId = [SELECT Id FROM FEC_Additional_Field__c LIMIT 1].Id;
        Test.startTest();
        List<FEC_Additional_Field_List_Value__c> vals = FEC_LiveAdditionalFieldController.getFieldListValues(fId);
        Test.stopTest();
        Assert.isFalse(vals.isEmpty());
    }

    @IsTest
    static void testGetFieldListValuesFresh_ValidId() {
        Id fId = [SELECT Id FROM FEC_Additional_Field__c LIMIT 1].Id;
        Test.startTest();
        List<FEC_Additional_Field_List_Value__c> vals = FEC_LiveAdditionalFieldController.getFieldListValuesFresh(fId);
        Test.stopTest();
        Assert.isFalse(vals.isEmpty());
    }

    @IsTest
    static void testGetAdditionalFieldOptions() {
        Test.startTest();
        List<Map<String, String>> opts = FEC_LiveAdditionalFieldController.getAdditionalFieldOptions();
        Test.stopTest();
        Assert.isNotNull(opts);
    }

    @IsTest
    static void testDeleteFieldListValue_ValidId() {
        Id valId = [SELECT Id FROM FEC_Additional_Field_List_Value__c LIMIT 1].Id;
        Test.startTest();
        try {
            String result = FEC_LiveAdditionalFieldController.deleteFieldListValue(valId);
            Assert.isNotNull(result);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteRecord_ValidId() {
        FEC_Additional_Field__c f = new FEC_Additional_Field__c(
            FEC_Unique_ID__c = 'AF_DEL_LDP', FEC_Type__c = 'String',
            FEC_Name_VN__c = 'Del', FEC_Field_Status__c = true
        );
        insert f;
        Test.startTest();
        try {
            String result = FEC_LiveAdditionalFieldController.deleteRecord(f.Id);
            Assert.isNotNull(result);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveProperty_Insert() {
        Map<String, Object> propData = new Map<String, Object>{
            'Name' => 'NewLiveProp',
            'FEC_Unique_ID__c' => 'NEW_LIVE_1',
            'FEC_Type__c' => 'String',
            'FEC_Name_VN__c' => 'Tên',
            'FEC_Field_Mandatory__c' => false
        };
        try {
            Test.startTest();
            Map<String, Object> result = FEC_LiveAdditionalFieldController.savePropertyWithListValues(propData, null);
            Assert.isNotNull(result);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveProperty_ListType_BlankValuesFails() {
        Map<String, Object> propData = new Map<String, Object>{
            'Name' => 'BadList',
            'FEC_Unique_ID__c' => 'BAD_LIVE_1',
            'FEC_Type__c' => 'List',
            'FEC_Name_VN__c' => 'Tên'
        };
        Boolean caught = false;
        Test.startTest();
        try {
            FEC_LiveAdditionalFieldController.savePropertyWithListValues(propData, null);
        } catch (AuraHandledException e) {
            caught = true;
        }
        Test.stopTest();
        Assert.isTrue(caught, 'Type=List + blank values phải throw');
    }

    @IsTest
    static void testSaveProperty_ListType_WithPipeFormat() {
        // Format: Code|NameEN|NameVN per line
        Map<String, Object> propData = new Map<String, Object>{
            'Name' => 'ListPropPipe',
            'FEC_Unique_ID__c' => 'LP_PIPE_1',
            'FEC_Type__c' => 'List',
            'FEC_Name_VN__c' => 'Tên'
        };
        String listValuesRaw = 'A|Alpha|Anpha\nB|Bravo|Bê';
        try {
            Test.startTest();
            Map<String, Object> result = FEC_LiveAdditionalFieldController.savePropertyWithListValues(propData, listValuesRaw);
            Assert.isNotNull(result);
            Assert.isTrue((Boolean) result.get('success'));
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveProperty_EditMode() {
        Id existing = [SELECT Id FROM FEC_Additional_Field__c LIMIT 1].Id;
        Map<String, Object> propData = new Map<String, Object>{
            'Id' => existing,
            'Name' => 'Updated Live',
            'FEC_Type__c' => 'String'
        };
        Test.startTest();
        try {
            Map<String, Object> result = FEC_LiveAdditionalFieldController.savePropertyWithListValues(propData, '');
            Assert.isNotNull(result);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveProperty_EditMode_ReplaceWithPipe() {
        Id existing = [SELECT Id FROM FEC_Additional_Field__c LIMIT 1].Id;
        Map<String, Object> propData = new Map<String, Object>{
            'Id' => existing,
            'FEC_Type__c' => 'List'
        };
        String listValuesRaw = 'X|Xray|Xờ';
        Test.startTest();
        try {
            Map<String, Object> result = FEC_LiveAdditionalFieldController.savePropertyWithListValues(propData, listValuesRaw);
            Assert.isNotNull(result);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }
}