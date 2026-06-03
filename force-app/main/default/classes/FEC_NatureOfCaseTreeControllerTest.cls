@isTest
private class FEC_NatureOfCaseTreeControllerTest {
    @testSetup
    static void setupFull() {
        // Create Product Type
        FEC_MDM_Product_Type__c prod = new FEC_MDM_Product_Type__c(Name='Product', FEC_Code__c='P01', FEC_Alias__c='PT', FEC_Name_VN__c='SP', FEC_Order__c=1, FEC_Active__c=true);
        insert prod;
        // Create Business Process
        FEC_MDM_Business_Process__c bp = new FEC_MDM_Business_Process__c(Name='BP', FEC_Code__c='B01', FEC_Alias__c='BP', FEC_Name_VN__c='BPVN', FEC_Order__c=1, FEC_Status__c=true);
        insert bp;
        // Create Category
        FEC_MDM_Category__c cat = new FEC_MDM_Category__c(Name='Cat', FEC_Code__c='C01', FEC_Alias__c='CAT', FEC_Name_VN__c='CATVN', FEC_Order__c=1, FEC_Active__c=true);
        insert cat;
        // Create Sub Category
        FEC_MDM_Sub_Category__c scat = new FEC_MDM_Sub_Category__c(Name='SCat', FEC_Code__c='SC01', FEC_Alias__c='SCAT', FEC_Name_VN__c='SCATVN', FEC_Order__c=1, FEC_Active__c=true);
        insert scat;
        // Create Sub Code
        FEC_MDM_Sub_Code__c scode = new FEC_MDM_Sub_Code__c(Name='SCode', FEC_Code__c='SCODE01', FEC_Alias__c='SCODE', FEC_Name_VN__c='SCODEVN', FEC_Order__c=1, FEC_Active__c=true);
        insert scode;
        // Create Nature Of Case
        FEC_MDM_Nature_Of_Case__c noc = new FEC_MDM_Nature_Of_Case__c(
            Name='NOC',
            FEC_Product_Type__c=prod.Id,
            FEC_Business_Process__c=bp.Id,
            FEC_Category__c=cat.Id,
            FEC_Sub_Category__c=scat.Id,
            FEC_Sub_Code__c=scode.Id,
            FEC_Customer_Type__c='All'
        );
        insert noc;
    }

    @isTest
    static void testGetNextPosOrderAllBranches() {
        Id prodId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;

        Test.startTest();
        
        // 1. Phủ nhánh: FEC_Product_Type__c (Trả về count của Business Process + 1)
        // Kết quả mong đợi: 1 (biz) + 1 = 2
        Integer res1 = FEC_NatureOfCaseTreeController.getNextPosOrder(prodId, 'FEC_Product_Type__c');
        Assert.areEqual(2, res1);

        // 2. Phủ nhánh: FEC_Business_Process__c -> target: FEC_Category__c
        FEC_NatureOfCaseTreeController.getNextPosOrder(prodId, 'FEC_Business_Process__c');

        // 3. Phủ nhánh: FEC_Category__c -> target: FEC_Sub_Category__c
        FEC_NatureOfCaseTreeController.getNextPosOrder(prodId, 'FEC_Category__c');

        // 4. Phủ nhánh: FEC_Sub_Category__c -> target: FEC_Sub_Code__c
        FEC_NatureOfCaseTreeController.getNextPosOrder(prodId, 'FEC_Sub_Category__c');

        // 5. Phủ nhánh ELSE: target: FEC_Product_Type__c
        FEC_NatureOfCaseTreeController.getNextPosOrder(null, 'Unknown_Field');

        // 6. Phủ nhánh KHÔNG có parentId (Bỏ qua WHERE clause)
        FEC_NatureOfCaseTreeController.getNextPosOrder('', '');

        Test.stopTest();
    }

    @isTest static void testGetNatureOfCaseTreeData() {
        List<FEC_NatureOfCaseTreeItem> tree = FEC_NatureOfCaseTreeController.getNatureOfCaseTreeData();
        System.assert(!tree.isEmpty());
    }

    @isTest static void testSaveNewLookupNode_ProductType() {
        String id = FEC_NatureOfCaseTreeController.saveNewLookupNode('Product Type', 'All', null, 'NewPT', 'AliasPT', 'CodePT', 'VNPT', 2, true);
        System.assertNotEquals(null, id);
    }

    @isTest static void testSaveNewLookupNode_BusinessProcess() {
        Id prodId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        // Insert parent NOC for mapping
        FEC_MDM_Nature_Of_Case__c parentNoc = new FEC_MDM_Nature_Of_Case__c(Name='ParentNOC', FEC_Product_Type__c=prodId, FEC_Customer_Type__c='All');
        insert parentNoc;
        String id = FEC_NatureOfCaseTreeController.saveNewLookupNode('Business Process', 'All', prodId, 'NewBP', 'AliasBP', 'CodeBP', 'VNBP', 2, true);
        System.assertNotEquals(null, id);
    }

    @isTest static void testDeleteNodeApex() {
        Id prodId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        FEC_NatureOfCaseTreeController.deleteNodeApex(prodId, 'Product Type');
        // No exception = pass
    }

    @isTest static void testUpdateMultipleNodes() {
        Id prodId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        Map<String, Object> data = new Map<String, Object>{
            'type' => 'Product Type',
            'idType' => prodId,
            'NameEN' => 'UpdatedPT',
            'nameVN' => 'UpdatedVN',
            'Alias' => 'UPT',
            'Code' => 'UPT01',
            'PosOrder' => 5,
            'Status' => true
        };
        FEC_NatureOfCaseTreeController.updateMultipleNodes(new List<Map<String, Object>>{data});
        FEC_MDM_Product_Type__c updated = [SELECT Name FROM FEC_MDM_Product_Type__c WHERE Id = :prodId];
        System.assertEquals('UpdatedPT', updated.Name);
    }

    @isTest static void testUpdateNode() {
        Id prodId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        Map<String, Object> data = new Map<String, Object>{
            'id' => prodId,
            'idType' => prodId,
            'type' => 'Product Type',
            'NameEN' => 'NodePT',
            'nameVN' => 'NodeVN',
            'Alias' => 'NPT',
            'Code' => 'NPT01',
            'PosOrder' => 10,
            'Status' => false
        };
        FEC_NatureOfCaseTreeController.updateNode(data);
        FEC_MDM_Product_Type__c updated = [SELECT Name, FEC_Active__c FROM FEC_MDM_Product_Type__c WHERE Id = :prodId];
        System.assertEquals('NodePT', updated.Name);
        System.assertEquals(false, updated.FEC_Active__c);
    }

    @isTest static void testGetMasterDataMappings() {
        List<FEC_MDM_Nature_Of_Case__c> mappings = FEC_NatureOfCaseTreeService.fetchAllMasterDataMappings();
        System.assert(!mappings.isEmpty());
    }

    @isTest static void testSaveNewLookupNode_Exception() {
        Boolean caught = false;
        try {
            // Should throw because parentId is not found
            FEC_NatureOfCaseTreeController.saveNewLookupNode('Business Process', 'All', 'fakeId', 'NewBP', 'AliasBP', 'CodeBP', 'VNBP', 2, true);
        } catch (Exception e) {
            caught = true;
        }
        System.assert(caught, 'Exception should be thrown for invalid parentId');
    }
}