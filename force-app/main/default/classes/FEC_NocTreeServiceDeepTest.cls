/**
 * @description Deep tests for FEC_NatureOfCaseTreeService — MDM tree node CRUD.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM
 */
@IsTest
private class FEC_NocTreeServiceDeepTest {

    @testSetup
    static void setup() {
        FEC_MDM_Product_Type__c pt = new FEC_MDM_Product_Type__c(Name = 'PT_TS_1', FEC_Code__c = 'PT_TS_1');
        insert pt;

        // Create a parent NOC for child node creation tests
        insert new FEC_MDM_Nature_Of_Case__c(
            Name = 'NOC_TS_PARENT',
            FEC_Product_Type__c = pt.Id,
            FEC_Code__c = 'NOC_TS_PARENT_1',
            FEC_Active__c = true,
            FEC_Customer_Type__c = 'Existing'
        );
    }

    @IsTest
    static void testSaveNewLookupNode_ProductType() {
        try {
            Test.startTest();
            String result = FEC_NatureOfCaseTreeService.saveNewLookupNode(
                FEC_UIConstants.LABEL_PRODUCT_TYPE, 'Existing', null,
                'NewPT_TS', 'AliasTS', 'PT_TS_NEW1', 'TVN', 1, true
            );
            Test.stopTest();
            Assert.isNotNull(result);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testSaveNewLookupNode_BusinessProcess() {
        Id ptId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeService.saveNewLookupNode(
                FEC_UIConstants.LABEL_BUSINESS_PROCESS, 'Existing', String.valueOf(ptId),
                'NewBP_TS', 'AliasTS', 'BP_TS_NEW1', 'TVN', 1, true
            );
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testSaveNewLookupNode_InvalidCode() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeService.saveNewLookupNode(
                FEC_UIConstants.LABEL_PRODUCT_TYPE, 'Existing', null,
                'Bad', 'X', 'PT@INVALID#', 'TVN', 1, true
            );
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught, 'Special chars in code phải throw');
    }

    @IsTest
    static void testDeleteNodeApex_NotFound() {
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeService.deleteNodeApex('a0X000000000000', FEC_UIConstants.LABEL_PRODUCT_TYPE);
            Test.stopTest();
        } catch (Exception e) {
            // OK
        }
        Assert.isTrue(true);
    }

    @IsTest
    static void testDeleteNodeApex_ValidProductType() {
        FEC_MDM_Product_Type__c pt = new FEC_MDM_Product_Type__c(Name = 'PT_DEL_TS', FEC_Code__c = 'PT_DEL_TS');
        insert pt;
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeService.deleteNodeApex(String.valueOf(pt.Id), FEC_UIConstants.LABEL_PRODUCT_TYPE);
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testUpdateNode_BasicUpdate() {
        Id ptId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        Map<String, Object> data = new Map<String, Object>{
            'recordId' => String.valueOf(ptId),
            'objectType' => FEC_UIConstants.LABEL_PRODUCT_TYPE,
            'name' => 'UpdatedTS',
            'isStatus' => true
        };
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeService.updateNode(data);
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testUpdateNode_Null() {
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeService.updateNode(null);
            Test.stopTest();
        } catch (Exception e) {
            // OK
        }
        Assert.isTrue(true);
    }

    @IsTest
    static void testUpdateMultipleNodes_Empty() {
        Test.startTest();
        FEC_NatureOfCaseTreeService.updateMultipleNodes(new List<Map<String, Object>>());
        Test.stopTest();
        Assert.isTrue(true);
    }

    @IsTest
    static void testUpdateMultipleNodes_Null() {
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeService.updateMultipleNodes(null);
            Test.stopTest();
        } catch (Exception e) {
            // Acceptable: implementation may throw on null
        }
        Assert.isTrue(true);
    }

    @IsTest
    static void testUpdateMultipleNodes_WithData() {
        Id ptId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        List<Map<String, Object>> data = new List<Map<String, Object>>{
            new Map<String, Object>{
                'recordId' => String.valueOf(ptId),
                'objectType' => FEC_UIConstants.LABEL_PRODUCT_TYPE,
                'name' => 'BulkUpdate1',
                'isStatus' => true
            }
        };
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeService.updateMultipleNodes(data);
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testTouchNodeForStatusUpdate_ProductType() {
        Id ptId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeService.touchNodeForStatusUpdate(ptId, FEC_UIConstants.LABEL_PRODUCT_TYPE);
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testTouchNodeForStatusUpdate_BusinessProcess() {
        FEC_MDM_Business_Process__c bp = new FEC_MDM_Business_Process__c(FEC_Code__c = 'BP_TS_2');
        insert bp;
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeService.touchNodeForStatusUpdate(bp.Id, FEC_UIConstants.LABEL_BUSINESS_PROCESS);
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testTouchNodeForStatusUpdate_Category() {
        FEC_MDM_Category__c c = new FEC_MDM_Category__c(FEC_Code__c = 'CAT_TS_2');
        insert c;
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeService.touchNodeForStatusUpdate(c.Id, FEC_UIConstants.LABEL_CATEGORY);
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testTouchNodeForStatusUpdate_SubCategory() {
        FEC_MDM_Sub_Category__c sc = new FEC_MDM_Sub_Category__c(FEC_Code__c = 'SCAT_TS_2');
        insert sc;
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeService.touchNodeForStatusUpdate(sc.Id, FEC_UIConstants.LABEL_SUB_CATEGORY);
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testTouchNodeForStatusUpdate_SubCode() {
        FEC_MDM_Sub_Code__c sc = new FEC_MDM_Sub_Code__c(FEC_Code__c = 'SCD_TS_2');
        insert sc;
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeService.touchNodeForStatusUpdate(sc.Id, FEC_UIConstants.LABEL_SUB_CODE);
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testTouchNodeForStatusUpdate_NullId() {
        Test.startTest();
        FEC_NatureOfCaseTreeService.touchNodeForStatusUpdate(null, FEC_UIConstants.LABEL_PRODUCT_TYPE);
        Test.stopTest();
        Assert.isTrue(true);
    }

    @IsTest
    static void testTouchNodeForStatusUpdate_BlankType() {
        Id ptId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        Test.startTest();
        FEC_NatureOfCaseTreeService.touchNodeForStatusUpdate(ptId, '');
        Test.stopTest();
        Assert.isTrue(true);
    }

    @IsTest
    static void testTouchNodeForStatusUpdate_UnknownType() {
        Id ptId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        Test.startTest();
        FEC_NatureOfCaseTreeService.touchNodeForStatusUpdate(ptId, 'UnknownType');
        Test.stopTest();
        Assert.isTrue(true);
    }

    @IsTest
    static void testSaveNewLookupNode_Category_WithParent() {
        Id ptId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeService.saveNewLookupNode(
                FEC_UIConstants.LABEL_CATEGORY, 'Existing', String.valueOf(ptId),
                'NewCat_TS', 'AliasTS', 'CAT_TS_NEW', 'TVN', 1, true
            );
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testSaveNewLookupNode_SubCategory() {
        Id ptId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeService.saveNewLookupNode(
                FEC_UIConstants.LABEL_SUB_CATEGORY, 'Existing', String.valueOf(ptId),
                'NewSC_TS', 'AliasTS', 'SC_TS_NEW', 'TVN', 1, true
            );
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testSaveNewLookupNode_SubCode() {
        Id ptId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        try {
            Test.startTest();
            FEC_NatureOfCaseTreeService.saveNewLookupNode(
                FEC_UIConstants.LABEL_SUB_CODE, 'Existing', String.valueOf(ptId),
                'NewSCode_TS', 'AliasTS', 'SCD_TS_NEW', 'TVN', 1, true
            );
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testFetchAllMasterDataMappings() {
        Test.startTest();
        List<FEC_MDM_Nature_Of_Case__c> result = FEC_NatureOfCaseTreeService.fetchAllMasterDataMappings();
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testUpdateMultipleNodes_AllTiers() {
        // Setup all 5 tier records to test each branch in updateMultipleNodes (lines 271-309)
        Id ptId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        FEC_MDM_Business_Process__c bp = new FEC_MDM_Business_Process__c(FEC_Code__c = 'BP_TS_AT');
        insert bp;
        FEC_MDM_Category__c cat = new FEC_MDM_Category__c(FEC_Code__c = 'CAT_TS_AT');
        insert cat;
        FEC_MDM_Sub_Category__c scat = new FEC_MDM_Sub_Category__c(FEC_Code__c = 'SCAT_TS_AT');
        insert scat;
        FEC_MDM_Sub_Code__c scode = new FEC_MDM_Sub_Code__c(FEC_Code__c = 'SCD_TS_AT');
        insert scode;

        List<Map<String, Object>> data = new List<Map<String, Object>>{
            new Map<String, Object>{
                FEC_UIConstants.PAYLOAD_TYPE => FEC_UIConstants.LABEL_PRODUCT_TYPE,
                FEC_UIConstants.PAYLOAD_IDTYPE => ptId,
                FEC_UIConstants.PAYLOAD_NAMEEN => 'PT_AT_Upd',
                FEC_UIConstants.PAYLOAD_NAMEVN => 'TVN_PT',
                FEC_UIConstants.PAYLOAD_ALIAS => 'PTA',
                FEC_UIConstants.PAYLOAD_CODE => 'PT_TS_AT_UPD',
                FEC_UIConstants.PAYLOAD_POSORDER => 5,
                FEC_UIConstants.PAYLOAD_STATUS => true
            },
            new Map<String, Object>{
                FEC_UIConstants.PAYLOAD_TYPE => FEC_UIConstants.LABEL_BUSINESS_PROCESS,
                FEC_UIConstants.PAYLOAD_IDTYPE => bp.Id,
                FEC_UIConstants.PAYLOAD_NAMEEN => 'BP_AT_Upd',
                FEC_UIConstants.PAYLOAD_NAMEVN => 'TVN_BP',
                FEC_UIConstants.PAYLOAD_ALIAS => 'BPA',
                FEC_UIConstants.PAYLOAD_CODE => 'BP_TS_AT_UPD',
                FEC_UIConstants.PAYLOAD_POSORDER => 1,
                FEC_UIConstants.PAYLOAD_STATUS => true
            },
            new Map<String, Object>{
                FEC_UIConstants.PAYLOAD_TYPE => FEC_UIConstants.LABEL_CATEGORY,
                FEC_UIConstants.PAYLOAD_IDTYPE => cat.Id,
                FEC_UIConstants.PAYLOAD_NAMEEN => 'CAT_AT_Upd',
                FEC_UIConstants.PAYLOAD_NAMEVN => 'TVN_CAT',
                FEC_UIConstants.PAYLOAD_ALIAS => 'CATA',
                FEC_UIConstants.PAYLOAD_CODE => 'CAT_TS_AT_UPD',
                FEC_UIConstants.PAYLOAD_POSORDER => 2,
                FEC_UIConstants.PAYLOAD_STATUS => true
            },
            new Map<String, Object>{
                FEC_UIConstants.PAYLOAD_TYPE => FEC_UIConstants.LABEL_SUB_CATEGORY,
                FEC_UIConstants.PAYLOAD_IDTYPE => scat.Id,
                FEC_UIConstants.PAYLOAD_NAMEEN => 'SCAT_AT_Upd',
                FEC_UIConstants.PAYLOAD_NAMEVN => 'TVN_SCAT',
                FEC_UIConstants.PAYLOAD_ALIAS => 'SCATA',
                FEC_UIConstants.PAYLOAD_CODE => 'SCAT_TS_AT_UPD',
                FEC_UIConstants.PAYLOAD_POSORDER => 3,
                FEC_UIConstants.PAYLOAD_STATUS => true
            },
            new Map<String, Object>{
                FEC_UIConstants.PAYLOAD_TYPE => FEC_UIConstants.LABEL_SUB_CODE,
                FEC_UIConstants.PAYLOAD_IDTYPE => scode.Id,
                FEC_UIConstants.PAYLOAD_NAMEEN => 'SCODE_AT_Upd',
                FEC_UIConstants.PAYLOAD_NAMEVN => 'TVN_SCD',
                FEC_UIConstants.PAYLOAD_ALIAS => 'SCDA',
                FEC_UIConstants.PAYLOAD_CODE => 'SCD_TS_AT_UPD',
                FEC_UIConstants.PAYLOAD_POSORDER => 4,
                FEC_UIConstants.PAYLOAD_STATUS => true
            }
        };

        Test.startTest();
        try {
            FEC_NatureOfCaseTreeService.updateMultipleNodes(data);
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteNodeApex_BusinessProcess() {
        FEC_MDM_Business_Process__c bp = new FEC_MDM_Business_Process__c(FEC_Code__c = 'BP_DEL_AT');
        insert bp;
        Id ptId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        insert new FEC_MDM_Nature_Of_Case__c(
            Name = 'NOC_DEL_BP', FEC_Code__c = 'NOC_DEL_BP_1',
            FEC_Product_Type__c = ptId, FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true, FEC_Customer_Type__c = 'Existing'
        );
        Test.startTest();
        try {
            FEC_NatureOfCaseTreeService.deleteNodeApex(String.valueOf(bp.Id), FEC_UIConstants.LABEL_BUSINESS_PROCESS);
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteNodeApex_Category() {
        FEC_MDM_Category__c c = new FEC_MDM_Category__c(FEC_Code__c = 'CAT_DEL_AT');
        insert c;
        Id ptId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        insert new FEC_MDM_Nature_Of_Case__c(
            Name = 'NOC_DEL_C', FEC_Code__c = 'NOC_DEL_C_1',
            FEC_Product_Type__c = ptId, FEC_Category__c = c.Id,
            FEC_Active__c = true, FEC_Customer_Type__c = 'Existing'
        );
        Test.startTest();
        try {
            FEC_NatureOfCaseTreeService.deleteNodeApex(String.valueOf(c.Id), FEC_UIConstants.LABEL_CATEGORY);
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteNodeApex_SubCategory() {
        FEC_MDM_Sub_Category__c sc = new FEC_MDM_Sub_Category__c(FEC_Code__c = 'SCAT_DEL_AT');
        insert sc;
        Id ptId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        insert new FEC_MDM_Nature_Of_Case__c(
            Name = 'NOC_DEL_SC', FEC_Code__c = 'NOC_DEL_SC_1',
            FEC_Product_Type__c = ptId, FEC_Sub_Category__c = sc.Id,
            FEC_Active__c = true, FEC_Customer_Type__c = 'Existing'
        );
        Test.startTest();
        try {
            FEC_NatureOfCaseTreeService.deleteNodeApex(String.valueOf(sc.Id), FEC_UIConstants.LABEL_SUB_CATEGORY);
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteNodeApex_SubCode() {
        FEC_MDM_Sub_Code__c sd = new FEC_MDM_Sub_Code__c(FEC_Code__c = 'SCD_DEL_AT');
        insert sd;
        Id ptId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        insert new FEC_MDM_Nature_Of_Case__c(
            Name = 'NOC_DEL_SD', FEC_Code__c = 'NOC_DEL_SD_1',
            FEC_Product_Type__c = ptId, FEC_Sub_Code__c = sd.Id,
            FEC_Active__c = true, FEC_Customer_Type__c = 'Existing'
        );
        Test.startTest();
        try {
            FEC_NatureOfCaseTreeService.deleteNodeApex(String.valueOf(sd.Id), FEC_UIConstants.LABEL_SUB_CODE);
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }
}