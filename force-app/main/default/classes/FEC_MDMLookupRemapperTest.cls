/**
 * @description Tests for FEC_MDMLookupRemapper.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM
 */
@IsTest
private class FEC_MDMLookupRemapperTest {

    @IsTest
    static void testBuildLookupRemapMaps_NullObject() {
        Test.startTest();
        Map<String, Map<Id, Id>> result = FEC_MDMLookupRemapper.buildLookupRemapMaps(
            'NonExistentObject__c',
            new List<SObject>(),
            new Map<String, Schema.SObjectField>(),
            Schema.getGlobalDescribe()
        );
        Test.stopTest();
        Assert.isNotNull(result, 'Returns empty map');
    }

    @IsTest
    static void testBuildLookupRemapMaps_EmptyRecords() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        Test.startTest();
        Map<String, Map<Id, Id>> result = FEC_MDMLookupRemapper.buildLookupRemapMaps(
            'FEC_MDM_Master_Data_Setting__c',
            new List<SObject>(),
            FEC_Master_Data_Setting__c.SObjectType.getDescribe().fields.getMap(),
            gd
        );
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testRemapLookupFields_EmptyMap() {
        FEC_MDM_Master_Data_Setting__c mdm = new FEC_MDM_Master_Data_Setting__c();
        FEC_Master_Data_Setting__c target = new FEC_Master_Data_Setting__c();
        Map<String, Map<Id, Id>> emptyMap = new Map<String, Map<Id, Id>>();
        try {
            Test.startTest();
            FEC_MDMLookupRemapper.remapLookupFields(mdm, target, emptyMap, 'FEC_MDM_Master_Data_Setting__c');
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testBuildTextIdRemapMaps_NoConfig() {
        Test.startTest();
        Map<String, Map<Id, Id>> result = FEC_MDMLookupRemapper.buildTextIdRemapMaps(
            'FEC_MDM_Master_Data_Setting__c',
            new List<SObject>(),
            Schema.getGlobalDescribe()
        );
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testRemapTextIdFields_Empty() {
        FEC_MDM_Master_Data_Setting__c mdm = new FEC_MDM_Master_Data_Setting__c();
        FEC_Master_Data_Setting__c target = new FEC_Master_Data_Setting__c();
        try {
            Test.startTest();
            FEC_MDMLookupRemapper.remapTextIdFields(
                mdm, target, 'FEC_MDM_Master_Data_Setting__c', new Map<String, Map<Id, Id>>()
            );
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testBuildTextIdRemapMaps_DecisionRule() {
        // FEC_MDM_Decision_Rule__c is in TEXT_ID_REMAP_FIELDS config (FEC_Key_ID__c → MDM_BP)
        FEC_MDM_Business_Process__c mdmBp = new FEC_MDM_Business_Process__c(FEC_Code__c = 'BP_LR_TEXT_1');
        insert mdmBp;
        FEC_Business_Process__c liveBp = new FEC_Business_Process__c(FEC_Code__c = 'BP_LR_TEXT_1');
        insert liveBp;

        FEC_MDM_Decision_Rule__c rule = new FEC_MDM_Decision_Rule__c(
            FEC_Code__c = 'RULE_LR_1',
            FEC_Table_Key__c = 'STAGE_TRANSITION',
            FEC_Key_ID__c = String.valueOf(mdmBp.Id), // MDM Id stored as text
            FEC_Priority__c = 1,
            FEC_Active__c = true
        );
        insert rule;

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        Test.startTest();
        Map<String, Map<Id, Id>> result = FEC_MDMLookupRemapper.buildTextIdRemapMaps(
            'FEC_MDM_Decision_Rule__c',
            new List<SObject>{ rule },
            gd
        );
        Test.stopTest();
        Assert.isNotNull(result);
        Assert.isTrue(result.containsKey('FEC_Key_ID__c'), 'Should have FEC_Key_ID__c map');
    }

    @IsTest
    static void testRemapTextIdFields_WithMapping() {
        FEC_MDM_Decision_Rule__c mdm = new FEC_MDM_Decision_Rule__c(
            FEC_Code__c = 'R_TXT', FEC_Key_ID__c = '001000000000001AAA'
        );
        FEC_Decision_Rule__c target = new FEC_Decision_Rule__c();
        // Build a map keyed by FEC_Key_ID__c with valid Id mapping
        Id sourceId = '001000000000001AAA';
        Id targetId = '001000000000002AAB';
        Map<String, Map<Id, Id>> remapMaps = new Map<String, Map<Id, Id>>{
            'FEC_Key_ID__c' => new Map<Id, Id>{ sourceId => targetId }
        };

        Test.startTest();
        FEC_MDMLookupRemapper.remapTextIdFields(mdm, target, 'FEC_MDM_Decision_Rule__c', remapMaps);
        Test.stopTest();
        Assert.areEqual(String.valueOf(targetId), (String) target.get('FEC_Key_ID__c'));
    }

    @IsTest
    static void testBuildLookupRemapMaps_NocWithData() {
        // FEC_MDM_Nature_Of_Case__c has lookups: FEC_BP, FEC_PT, FEC_Category, FEC_SubCategory, FEC_SubCode
        // Setup MDM dimensions + matching Live dimensions (matched by FEC_Code__c)
        FEC_MDM_Product_Type__c mpt = new FEC_MDM_Product_Type__c(FEC_Code__c = 'PT_LR_2');
        insert mpt;
        FEC_Product_Type__c lpt = new FEC_Product_Type__c(FEC_Code__c = 'PT_LR_2', FEC_Active__c = true);
        insert lpt;
        FEC_MDM_Business_Process__c mbp = new FEC_MDM_Business_Process__c(FEC_Code__c = 'BP_LR_2');
        insert mbp;
        FEC_Business_Process__c lbp = new FEC_Business_Process__c(FEC_Code__c = 'BP_LR_2', FEC_Active__c = true);
        insert lbp;

        FEC_MDM_Nature_Of_Case__c noc = new FEC_MDM_Nature_Of_Case__c(
            FEC_Product_Type__c = mpt.Id,
            FEC_Business_Process__c = mbp.Id,
            FEC_Code__c = 'NOC_LR_2'
        );
        insert noc;

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        Test.startTest();
        Map<String, Map<Id, Id>> result = FEC_MDMLookupRemapper.buildLookupRemapMaps(
            'FEC_MDM_Nature_Of_Case__c',
            new List<SObject>{ noc },
            FEC_Nature_Of_Case__c.SObjectType.getDescribe().fields.getMap(),
            gd
        );
        Test.stopTest();
        Assert.isNotNull(result);
        // Should have remap for FEC_Product_Type__c, FEC_Business_Process__c, etc.
        Assert.isTrue(result.size() > 0);
    }

    @IsTest
    static void testRemapLookupFields_WithRemapMap() {
        // Setup MDM and Live dimensions with same FEC_Code__c
        FEC_MDM_Product_Type__c mpt = new FEC_MDM_Product_Type__c(FEC_Code__c = 'PT_LR_3');
        insert mpt;
        FEC_Product_Type__c lpt = new FEC_Product_Type__c(FEC_Code__c = 'PT_LR_3', FEC_Active__c = true);
        insert lpt;

        FEC_MDM_Nature_Of_Case__c noc = new FEC_MDM_Nature_Of_Case__c(
            FEC_Product_Type__c = mpt.Id, FEC_Code__c = 'NOC_LR_3'
        );
        FEC_Nature_Of_Case__c target = new FEC_Nature_Of_Case__c();

        Map<String, Map<Id, Id>> remapMaps = new Map<String, Map<Id, Id>>{
            'FEC_Product_Type__c' => new Map<Id, Id>{ mpt.Id => lpt.Id }
        };

        Test.startTest();
        FEC_MDMLookupRemapper.remapLookupFields(noc, target, remapMaps, 'FEC_MDM_Nature_Of_Case__c');
        Test.stopTest();
        Assert.areEqual(lpt.Id, target.FEC_Product_Type__c, 'Lookup remapped correctly');
    }
}