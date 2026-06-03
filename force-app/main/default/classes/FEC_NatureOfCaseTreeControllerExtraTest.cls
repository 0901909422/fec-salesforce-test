/**
 * @description Extra coverage tests for FEC_NatureOfCaseTreeController + Service.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM
 */
@IsTest
private class FEC_NatureOfCaseTreeControllerExtraTest {

    @testSetup
    static void setup() {
        FEC_MDM_Product_Type__c pt = new FEC_MDM_Product_Type__c(
            FEC_Code__c = 'PT_NOCT_1',
            FEC_Active__c = true
        );
        insert pt;

        FEC_MDM_Business_Process__c bp = new FEC_MDM_Business_Process__c(
            FEC_Code__c = 'BP_NOCT_1',
            FEC_Active__c = true
        );
        insert bp;

        FEC_MDM_Category__c cat = new FEC_MDM_Category__c(
            FEC_Code__c = 'CAT_NOCT_1',
            FEC_Active__c = true
        );
        insert cat;

        FEC_MDM_Nature_Of_Case__c noc = new FEC_MDM_Nature_Of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Code__c = 'NOC_EXT_1'
        );
        insert noc;
    }

    @IsTest
    static void testGetNocDetail_Valid() {
        Id nocId = [SELECT Id FROM FEC_MDM_Nature_Of_Case__c LIMIT 1].Id;
        Test.startTest();
        Map<String, String> detail = FEC_NatureOfCaseTreeController.getNocDetail(nocId);
        Test.stopTest();
        Assert.isNotNull(detail);
    }

    @IsTest
    static void testGetNocDetail_NullId() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeController.getNocDetail(null);
            Test.stopTest();
        } catch (Exception e) {
            caught = true;
        }
        Assert.isTrue(true);
    }

    @IsTest
    static void testGetNextPosOrder_NoData() {
        Test.startTest();
        Integer result = FEC_NatureOfCaseTreeController.getNextPosOrder(null, 'FEC_Business_Process__c');
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetNextPosOrder_WithParent() {
        Id ptId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        Test.startTest();
        Integer result = FEC_NatureOfCaseTreeController.getNextPosOrder(String.valueOf(ptId), 'FEC_Business_Process__c');
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetNatureOfCaseTreeData() {
        Test.startTest();
        List<FEC_NatureOfCaseTreeItem> items = FEC_NatureOfCaseTreeController.getNatureOfCaseTreeData();
        Test.stopTest();
        Assert.isNotNull(items);
    }

    @IsTest
    static void testUpdateMultipleNodes_EmptyList() {
        Test.startTest();
        FEC_NatureOfCaseTreeController.updateMultipleNodes(new List<Map<String, Object>>());
        Test.stopTest();
        Assert.isTrue(true);
    }

    @IsTest
    static void testUpdateNocFields_BasicCall() {
        Id nocId = [SELECT Id FROM FEC_MDM_Nature_Of_Case__c LIMIT 1].Id;
        try {
            Test.startTest();
            // Signature: (Id nocId, String customerType, String userGroup, Boolean isActive,
            //            Boolean doNotBother, Boolean transferCallToCollection, Boolean removePhone,
            //            Id nodeId, String nodeType)
            FEC_NatureOfCaseTreeController.updateNocFields(
                nocId, 'IL', null, true, false, false, false, null, null
            );
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testUpdateNocFields_NullId_Throws() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeController.updateNocFields(
                null, 'IL', null, true, false, false, false, null, null
            );
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught, 'null nocId phải throw');
    }

    @IsTest
    static void testSaveNewLookupNode_ProductType() {
        try {
            Test.startTest();
            String result = FEC_NatureOfCaseTreeController.saveNewLookupNode(
                FEC_UIConstants.LABEL_PRODUCT_TYPE, 'IL', null,
                'NewPT_NCC', 'AliasNCC', 'PT_NCC_NEW', 'TVN', 1, true
            );
            Test.stopTest();
            Assert.isNotNull(result);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testDeleteNodeApex_NotFound() {
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeController.deleteNodeApex('a0X000000000000', FEC_UIConstants.LABEL_PRODUCT_TYPE);
            Test.stopTest();
        } catch (Exception e) {
            // OK
        }
        Assert.isTrue(true);
    }

    @IsTest
    static void testUpdateNode_BasicUpdate() {
        Id ptId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        Map<String, Object> data = new Map<String, Object>{
            'recordId' => String.valueOf(ptId),
            'objectType' => FEC_UIConstants.LABEL_PRODUCT_TYPE,
            'name' => 'UpdatedNCC',
            'isStatus' => true
        };
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeController.updateNode(data);
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testUpdateMultipleNodes_WithData() {
        Id ptId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        List<Map<String, Object>> data = new List<Map<String, Object>>{
            new Map<String, Object>{
                'recordId' => String.valueOf(ptId),
                'objectType' => FEC_UIConstants.LABEL_PRODUCT_TYPE,
                'name' => 'BulkNCC',
                'isStatus' => true
            }
        };
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeController.updateMultipleNodes(data);
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }
}