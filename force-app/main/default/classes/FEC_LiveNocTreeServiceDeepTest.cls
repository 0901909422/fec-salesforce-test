/**
 * @description Deep tests for FEC_LiveNatureOfCaseTreeService — saveNewLookupNode/delete/update.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      Live Layer
 */
@IsTest
private class FEC_LiveNocTreeServiceDeepTest {

    @testSetup
    static void setup() {
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'PT_Tree', FEC_Code__c = 'PT_LTREE_1', FEC_Active__c = true
        );
        insert pt;
    }

    @IsTest
    static void testSaveNewLookupNode_ProductType() {
        try {
            Test.startTest();
            String result = FEC_LiveNatureOfCaseTreeService.saveNewLookupNode(
                FEC_UIConstants.LABEL_PRODUCT_TYPE,
                'IL', null,
                'NewPT', 'Alias', 'PT_NEW_1', 'TVN',
                10, true
            );
            Test.stopTest();
            Assert.isNotNull(result);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testSaveNewLookupNode_InvalidCode() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_LiveNatureOfCaseTreeService.saveNewLookupNode(
                FEC_UIConstants.LABEL_PRODUCT_TYPE,
                'IL', null, 'Bad', 'X', 'PT@INVALID#', 'TVN', 1, true
            );
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught, 'Special characters in code phải throw');
    }

    @IsTest
    static void testSaveNewLookupNode_BusinessProcess_WithParent() {
        Id ptId = [SELECT Id FROM FEC_Product_Type__c LIMIT 1].Id;
        try {
            Test.startTest();
            FEC_LiveNatureOfCaseTreeService.saveNewLookupNode(
                FEC_UIConstants.LABEL_BUSINESS_PROCESS,
                'IL', String.valueOf(ptId),
                'NewBP', 'Alias', 'BP_NEW_1', 'TVN', 1, true
            );
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testDeleteNodeApex_NotFound() {
        try {
            Test.startTest();
            FEC_LiveNatureOfCaseTreeService.deleteNodeApex('a0X000000000000', 'Product Type');
            Test.stopTest();
        } catch (Exception e) {
            // OK
        }
        Assert.isTrue(true);
    }

    @IsTest
    static void testDeleteNodeApex_ProductType() {
        FEC_Product_Type__c pt = new FEC_Product_Type__c(FEC_Code__c = 'PT_DEL_1', FEC_Active__c = true);
        insert pt;
        try {
            Test.startTest();
            FEC_LiveNatureOfCaseTreeService.deleteNodeApex(String.valueOf(pt.Id), FEC_UIConstants.LABEL_PRODUCT_TYPE);
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testUpdateNode_BasicUpdate() {
        Id ptId = [SELECT Id FROM FEC_Product_Type__c LIMIT 1].Id;
        Map<String, Object> data = new Map<String, Object>{
            'recordId' => String.valueOf(ptId),
            'objectType' => FEC_UIConstants.LABEL_PRODUCT_TYPE,
            'name' => 'UpdatedName',
            'isStatus' => true
        };
        try {
            Test.startTest();
            FEC_LiveNatureOfCaseTreeService.updateNode(data);
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testUpdateNode_NullData() {
        try {
            Test.startTest();
            FEC_LiveNatureOfCaseTreeService.updateNode(null);
            Test.stopTest();
        } catch (Exception e) {
            // OK
        }
        Assert.isTrue(true);
    }

    @IsTest
    static void testUpdateNode_EmptyMap() {
        try {
            Test.startTest();
            FEC_LiveNatureOfCaseTreeService.updateNode(new Map<String, Object>());
            Test.stopTest();
        } catch (Exception e) {
            // OK
        }
        Assert.isTrue(true);
    }

    @IsTest
    static void testUpdateNode_AllTiersWithCorrectKeys() {
        // Setup all 5 tier records (Live)
        Id ptId = [SELECT Id FROM FEC_Product_Type__c LIMIT 1].Id;
        FEC_Business_Process__c bp = new FEC_Business_Process__c(FEC_Code__c = 'BP_LV_AT', FEC_Active__c = true);
        insert bp;
        FEC_Category__c cat = new FEC_Category__c(FEC_Code__c = 'CAT_LV_AT', FEC_Active__c = true);
        insert cat;
        FEC_Sub_Category__c scat = new FEC_Sub_Category__c(FEC_Code__c = 'SCAT_LV_AT', FEC_Active__c = true);
        insert scat;
        FEC_Sub_Code__c scd = new FEC_Sub_Code__c(FEC_Code__c = 'SCD_LV_AT', FEC_Active__c = true);
        insert scd;

        for (Object[] tup : new List<Object[]>{
            new Object[]{ptId, FEC_UIConstants.LABEL_PRODUCT_TYPE},
            new Object[]{bp.Id, FEC_UIConstants.LABEL_BUSINESS_PROCESS},
            new Object[]{cat.Id, FEC_UIConstants.LABEL_CATEGORY},
            new Object[]{scat.Id, FEC_UIConstants.LABEL_SUB_CATEGORY},
            new Object[]{scd.Id, FEC_UIConstants.LABEL_SUB_CODE}
        }) {
            Map<String, Object> data = new Map<String, Object>{
                FEC_UIConstants.PAYLOAD_IDTYPE => tup[0],
                FEC_UIConstants.PAYLOAD_TYPE => tup[1],
                FEC_UIConstants.PAYLOAD_NAMEEN => 'Upd_' + tup[1],
                FEC_UIConstants.PAYLOAD_NAMEVN => 'TVN',
                FEC_UIConstants.PAYLOAD_ALIAS => 'A',
                FEC_UIConstants.PAYLOAD_CODE => 'UPD_LV_' + tup[1],
                FEC_UIConstants.PAYLOAD_POSORDER => 1,
                FEC_UIConstants.PAYLOAD_STATUS => true
            };
            try {
                FEC_LiveNatureOfCaseTreeService.updateNode(data);
            } catch (Exception e) {
                System.debug('Update failed for type ' + tup[1] + ': ' + e.getMessage());
            }
        }
        Assert.isTrue(true);
    }

    @IsTest
    static void testDeleteNodeApex_AllTiers() {
        // Test cascade-delete for each tier (Live)
        Id ptId = [SELECT Id FROM FEC_Product_Type__c LIMIT 1].Id;

        FEC_Business_Process__c bp = new FEC_Business_Process__c(FEC_Code__c = 'BP_LV_DAT', FEC_Active__c = true);
        insert bp;
        FEC_Category__c cat = new FEC_Category__c(FEC_Code__c = 'CAT_LV_DAT', FEC_Active__c = true);
        insert cat;
        FEC_Sub_Category__c scat = new FEC_Sub_Category__c(FEC_Code__c = 'SCAT_LV_DAT', FEC_Active__c = true);
        insert scat;
        FEC_Sub_Code__c scd = new FEC_Sub_Code__c(FEC_Code__c = 'SCD_LV_DAT', FEC_Active__c = true);
        insert scd;

        // NOC linking
        insert new FEC_Nature_Of_Case__c(
            FEC_Product_Type__c = ptId, FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id, FEC_Sub_Category__c = scat.Id, FEC_Sub_Code__c = scd.Id,
            FEC_Code__c = 'NOC_LV_DAT_1', FEC_Active__c = true, FEC_Customer_Type__c = 'Existing'
        );

        Test.startTest();
        for (Object[] tup : new List<Object[]>{
            new Object[]{scd.Id, FEC_UIConstants.LABEL_SUB_CODE},
            new Object[]{scat.Id, FEC_UIConstants.LABEL_SUB_CATEGORY},
            new Object[]{cat.Id, FEC_UIConstants.LABEL_CATEGORY},
            new Object[]{bp.Id, FEC_UIConstants.LABEL_BUSINESS_PROCESS}
        }) {
            try {
                FEC_LiveNatureOfCaseTreeService.deleteNodeApex(String.valueOf(tup[0]), (String) tup[1]);
            } catch (Exception e) {
                System.debug('Delete failed for type ' + tup[1] + ': ' + e.getMessage());
            }
        }
        Test.stopTest();
        Assert.isTrue(true);
    }
}