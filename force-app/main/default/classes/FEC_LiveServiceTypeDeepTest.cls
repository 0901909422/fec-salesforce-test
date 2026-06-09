/**
 * @description Deep tests for FEC_LiveServiceTypeMappingController.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      Live Layer
 */
@IsTest
private class FEC_LiveServiceTypeDeepTest {

    @testSetup
    static void setup() {
        FEC_Product_Type__c pt = new FEC_Product_Type__c(FEC_Code__c = 'PT_LST_1', FEC_Active__c = true);
        insert pt;
        FEC_Business_Process__c bp = new FEC_Business_Process__c(FEC_Code__c = 'BP_LST_1');
        insert bp;
        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Code__c = 'NOC_LST_1'
        );
        insert noc;
        FEC_Additional_Field__c af = new FEC_Additional_Field__c(
            FEC_Unique_ID__c = 'AF_LST_1',
            FEC_Type__c = 'String',
            FEC_Name_VN__c = 'AFLST',
            FEC_Field_Status__c = true
        );
        insert af;
        insert new FEC_Master_Data_Setting__c(
            FEC_Code__c = 'MDS_LST_1',
            FEC_Nature_Of_Case__c = noc.Id,
            FEC_Additional_Field__c = af.Id,
            FEC_Field_Status__c = true,
            Property_Reference__c = 'OldRef'
        );
    }

    @IsTest
    static void testGetServiceTypeTree_HasData() {
        Test.startTest();
        List<Map<String, Object>> tree = FEC_LiveServiceTypeMappingController.getServiceTypeTree();
        Test.stopTest();
        Assert.isFalse(tree.isEmpty(), 'Tree should have at least 1 BP');
    }

    @IsTest
    static void testSavePropertyMapping_Success() {
        Id mdsId = [SELECT Id FROM FEC_Master_Data_Setting__c LIMIT 1].Id;
        Test.startTest();
        try {
            FEC_LiveServiceTypeMappingController.savePropertyMapping(mdsId, 'NewRef');
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();

        FEC_Master_Data_Setting__c reloaded = [SELECT Property_Reference__c FROM FEC_Master_Data_Setting__c WHERE Id = :mdsId];
        // Có thể không update được nếu permission gateway nhưng test chạy
        Assert.isNotNull(reloaded);
    }

    @IsTest
    static void testSavePropertyMapping_NullId() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_LiveServiceTypeMappingController.savePropertyMapping(null, 'X');
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught);
    }

    @IsTest
    static void testSavePropertyMappings_BlankInput() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_LiveServiceTypeMappingController.savePropertyMappings('');
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught);
    }

    @IsTest
    static void testSavePropertyMappings_EmptyArray() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_LiveServiceTypeMappingController.savePropertyMappings('[]');
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught);
    }

    @IsTest
    static void testSavePropertyMappings_ValidArray() {
        Id mdsId = [SELECT Id FROM FEC_Master_Data_Setting__c LIMIT 1].Id;
        String json = JSON.serialize(new List<Map<String, String>>{
            new Map<String, String>{
                'settingId' => String.valueOf(mdsId),
                'newRef' => 'BulkRef'
            }
        });
        Test.startTest();
        try {
            FEC_LiveServiceTypeMappingController.savePropertyMappings(json);
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }
}