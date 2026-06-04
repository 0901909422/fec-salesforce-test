/**
 * @description Bug condition exploration test for FEC_NatureOfCaseTreeBuilder.
 * Tests 3 bug groups: NullPointerException on null relationships,
 * inactive node handling, and unsorted children.
 * 
 * **Validates: Requirements 1.1, 1.2, 1.5**
 * 
 * EXPECTED: These tests FAIL on unfixed code — failure confirms bugs exist.
 */
@isTest
private class FEC_NatureOfCaseTreeBuilderBugTest {

    @testSetup
    static void setupData() {
        // ── Bug Condition 3 — Sort test data ──
        // Create a Product Type for sort testing
        FEC_MDM_Product_Type__c ptSort = new FEC_MDM_Product_Type__c(
            Name = 'PT Sort',
            FEC_Code__c = 'PT_SORT',
            FEC_Alias__c = 'PTS',
            FEC_Name_VN__c = 'Loại SP Sort',
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        insert ptSort;

        // Create 3 Business Processes with PosOrder 3, 1, 2 (intentionally unsorted)
        FEC_MDM_Business_Process__c bp1 = new FEC_MDM_Business_Process__c(
            Name = 'BP Three',
            FEC_Code__c = 'BP_THREE',
            FEC_Alias__c = 'BP3',
            FEC_Name_VN__c = 'QT Ba',
            FEC_Order__c = 3,
            FEC_Active__c = true
        );
        FEC_MDM_Business_Process__c bp2 = new FEC_MDM_Business_Process__c(
            Name = 'BP One',
            FEC_Code__c = 'BP_ONE',
            FEC_Alias__c = 'BP1',
            FEC_Name_VN__c = 'QT Mot',
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        FEC_MDM_Business_Process__c bp3 = new FEC_MDM_Business_Process__c(
            Name = 'BP Two',
            FEC_Code__c = 'BP_TWO',
            FEC_Alias__c = 'BP2',
            FEC_Name_VN__c = 'QT Hai',
            FEC_Order__c = 2,
            FEC_Active__c = true
        );
        insert new List<FEC_MDM_Business_Process__c>{ bp1, bp2, bp3 };

        // Create NOC records linking PT to each BP (for sort test)
        List<FEC_MDM_Nature_Of_Case__c> sortNocs = new List<FEC_MDM_Nature_Of_Case__c>();
        sortNocs.add(new FEC_MDM_Nature_Of_Case__c(
            Name = 'NOC_SORT_1',
            FEC_Product_Type__c = ptSort.Id,
            FEC_Business_Process__c = bp1.Id,
            FEC_Customer_Type__c = 'Existing'
        ));
        sortNocs.add(new FEC_MDM_Nature_Of_Case__c(
            Name = 'NOC_SORT_2',
            FEC_Product_Type__c = ptSort.Id,
            FEC_Business_Process__c = bp2.Id,
            FEC_Customer_Type__c = 'Existing'
        ));
        sortNocs.add(new FEC_MDM_Nature_Of_Case__c(
            Name = 'NOC_SORT_3',
            FEC_Product_Type__c = ptSort.Id,
            FEC_Business_Process__c = bp3.Id,
            FEC_Customer_Type__c = 'Existing'
        ));
        insert sortNocs;

        // ── Bug Condition 1 — Null relationship test data ──
        // Create valid lookup records for constructing in-memory NOC with partial relationships
        FEC_MDM_Product_Type__c ptValid = new FEC_MDM_Product_Type__c(
            Name = 'PT Valid',
            FEC_Code__c = 'PT_VALID',
            FEC_Alias__c = 'PTV',
            FEC_Name_VN__c = 'Loại SP Hợp lệ',
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        insert ptValid;

        FEC_MDM_Business_Process__c bpValid = new FEC_MDM_Business_Process__c(
            Name = 'BP Valid',
            FEC_Code__c = 'BP_VALID',
            FEC_Alias__c = 'BPV',
            FEC_Name_VN__c = 'QT Hợp lệ',
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        insert bpValid;

        FEC_MDM_Category__c catValid = new FEC_MDM_Category__c(
            Name = 'CAT Valid',
            FEC_Code__c = 'CAT_VALID',
            FEC_Alias__c = 'CATV',
            FEC_Name_VN__c = 'DM Hợp lệ',
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        insert catValid;

        FEC_MDM_Sub_Category__c scatValid = new FEC_MDM_Sub_Category__c(
            Name = 'SCAT Valid',
            FEC_Code__c = 'SCAT_VALID',
            FEC_Alias__c = 'SCATV',
            FEC_Name_VN__c = 'PDM Hợp lệ',
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        insert scatValid;

        FEC_MDM_Sub_Code__c scodeValid = new FEC_MDM_Sub_Code__c(
            Name = 'SCODE Valid',
            FEC_Code__c = 'SCODE_VALID',
            FEC_Alias__c = 'SCODEV',
            FEC_Name_VN__c = 'Mã phụ Hợp lệ',
            FEC_Order__c = 1,
            FEC_Active__c = true
        );
        insert scodeValid;

        // Create a full NOC record for null-relationship tests (will be queried with partial fields)
        FEC_MDM_Nature_Of_Case__c nocFull = new FEC_MDM_Nature_Of_Case__c(
            Name = 'NOC_FULL',
            FEC_Product_Type__c = ptValid.Id,
            FEC_Business_Process__c = bpValid.Id,
            FEC_Category__c = catValid.Id,
            FEC_Sub_Category__c = scatValid.Id,
            FEC_Sub_Code__c = scodeValid.Id,
            FEC_Customer_Type__c = 'Existing'
        );
        insert nocFull;

        // ── Bug Condition 2 — Inactive node test data ──
        FEC_MDM_Product_Type__c ptInactive = new FEC_MDM_Product_Type__c(
            Name = 'PT Inactive',
            FEC_Code__c = 'PT_INACTIVE',
            FEC_Alias__c = 'PTI',
            FEC_Name_VN__c = 'Loại SP Inactive',
            FEC_Order__c = 99,
            FEC_Active__c = false
        );
        insert ptInactive;

        FEC_MDM_Business_Process__c bpInactive = new FEC_MDM_Business_Process__c(
            Name = 'BP Inactive',
            FEC_Code__c = 'BP_INACTIVE',
            FEC_Alias__c = 'BPI',
            FEC_Name_VN__c = 'QT Inactive',
            FEC_Order__c = 99,
            FEC_Active__c = false
        );
        insert bpInactive;

        FEC_MDM_Nature_Of_Case__c nocInactivePT = new FEC_MDM_Nature_Of_Case__c(
            Name = 'NOC_INACTIVE_PT',
            FEC_Product_Type__c = ptInactive.Id,
            FEC_Business_Process__c = bpValid.Id,
            FEC_Customer_Type__c = 'Existing'
        );
        insert nocInactivePT;

        FEC_MDM_Nature_Of_Case__c nocInactiveBP = new FEC_MDM_Nature_Of_Case__c(
            Name = 'NOC_INACTIVE_BP',
            FEC_Product_Type__c = ptValid.Id,
            FEC_Business_Process__c = bpInactive.Id,
            FEC_Customer_Type__c = 'Existing'
        );
        insert nocInactiveBP;
    }

    /**
     * @description Bug Condition 1 — NullPointerException when FEC_Product_Type__r is null.
     * Simulates FLS strip scenario: lookup ID is set but relationship fields are null.
     * On unfixed code: should crash with NullPointerException or skip unsafely.
     * On fixed code: should skip record safely, no crash, return empty tree.
     * 
     * **Validates: Requirements 1.1**
     */
    @isTest
    static void testNullProductTypeRelationship() {
        // Get a real PT Id to set on the lookup field
        FEC_MDM_Product_Type__c pt = [SELECT Id FROM FEC_MDM_Product_Type__c WHERE FEC_Code__c = 'PT_VALID' LIMIT 1];

        // Construct in-memory NOC with lookup ID set but NO relationship query
        // This simulates FLS strip: FEC_Product_Type__c has value, FEC_Product_Type__r is null
        FEC_MDM_Nature_Of_Case__c noc = new FEC_MDM_Nature_Of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Customer_Type__c = 'Existing'
        );

        Test.startTest();
        List<FEC_NatureOfCaseTreeItem> result = FEC_NatureOfCaseTreeBuilder.buildTree(
            new List<FEC_MDM_Nature_Of_Case__c>{ noc }
        );
        Test.stopTest();

        // Expected behavior after fix: no crash, record skipped safely
        Assert.isNotNull(result, 'buildTree should not return null when PT relationship is null');
        Assert.areEqual(0, result.size(), 'Tree should be empty when PT relationship is null — record should be skipped');
    }

    /**
     * @description Bug Condition 1 — NullPointerException when FEC_Business_Process__r is null.
     * NOC has valid PT (queried with relationship) but BP lookup set without relationship.
     * On unfixed code: should crash or skip entire record unsafely.
     * On fixed code: should create PT node only, skip BP processing safely.
     * 
     * **Validates: Requirements 1.2**
     */
    @isTest
    static void testNullBusinessProcessRelationship() {
        // Query NOC with full PT relationship but construct in-memory with null BP relationship
        FEC_MDM_Nature_Of_Case__c nocQueried = [
            SELECT Id,
                   FEC_Product_Type__c,
                   FEC_Product_Type__r.FEC_Code__c,
                   FEC_Product_Type__r.FEC_Alias__c,
                   FEC_Product_Type__r.FEC_Name_VN__c,
                   FEC_Product_Type__r.FEC_Order__c,
                   FEC_Product_Type__r.FEC_Active__c,
                   FEC_Product_Type__r.Process_Change_Status__c,
                   FEC_Product_Type__r.Name,
                   FEC_Business_Process__c,
                   FEC_Customer_Type__c
            FROM FEC_MDM_Nature_Of_Case__c
            WHERE Name = 'NOC_FULL'
            LIMIT 1
        ];

        // Build an in-memory NOC: copy PT relationship (valid) but leave BP relationship null
        FEC_MDM_Nature_Of_Case__c noc = new FEC_MDM_Nature_Of_Case__c();
        noc.Id = nocQueried.Id;
        noc.FEC_Customer_Type__c = nocQueried.FEC_Customer_Type__c;
        noc.FEC_Product_Type__c = nocQueried.FEC_Product_Type__c;
        // Copy PT relationship via putSObject so productTypeCode is not null
        noc.putSObject('FEC_Product_Type__r', nocQueried.FEC_Product_Type__r);
        // Set BP lookup ID but do NOT set relationship — simulates FLS strip
        noc.FEC_Business_Process__c = nocQueried.FEC_Business_Process__c;
        // FEC_Business_Process__r is null

        Test.startTest();
        List<FEC_NatureOfCaseTreeItem> result = FEC_NatureOfCaseTreeBuilder.buildTree(
            new List<FEC_MDM_Nature_Of_Case__c>{ noc }
        );
        Test.stopTest();

        Assert.isNotNull(result, 'buildTree should not return null when BP relationship is null');
        Assert.areEqual(1, result.size(), 'Tree should have 1 PT root node even when BP relationship is null');
    }

    /**
     * @description Bug Condition 1 — NullPointerException when FEC_Category__r is null.
     * NOC has valid PT + BP but Category lookup set without relationship.
     * On unfixed code: should crash or skip unsafely.
     * On fixed code: should create PT + BP nodes, skip CAT processing safely.
     * 
     * **Validates: Requirements 1.2**
     */
    @isTest
    static void testNullCategoryRelationship() {
        FEC_MDM_Nature_Of_Case__c nocQueried = [
            SELECT Id,
                   FEC_Product_Type__c,
                   FEC_Product_Type__r.FEC_Code__c,
                   FEC_Product_Type__r.FEC_Alias__c,
                   FEC_Product_Type__r.FEC_Name_VN__c,
                   FEC_Product_Type__r.FEC_Order__c,
                   FEC_Product_Type__r.FEC_Active__c,
                   FEC_Product_Type__r.Process_Change_Status__c,
                   FEC_Product_Type__r.Name,
                   FEC_Business_Process__c,
                   FEC_Business_Process__r.FEC_Code__c,
                   FEC_Business_Process__r.FEC_Alias__c,
                   FEC_Business_Process__r.FEC_Name_VN__c,
                   FEC_Business_Process__r.FEC_Order__c,
                   FEC_Business_Process__r.FEC_Active__c,
                   FEC_Business_Process__r.Process_Change_Status__c,
                   FEC_Business_Process__r.Name,
                   FEC_Category__c,
                   FEC_Customer_Type__c
            FROM FEC_MDM_Nature_Of_Case__c
            WHERE Name = 'NOC_FULL'
            LIMIT 1
        ];

        FEC_MDM_Nature_Of_Case__c noc = new FEC_MDM_Nature_Of_Case__c();
        noc.Id = nocQueried.Id;
        noc.FEC_Customer_Type__c = nocQueried.FEC_Customer_Type__c;
        noc.FEC_Product_Type__c = nocQueried.FEC_Product_Type__c;
        noc.putSObject('FEC_Product_Type__r', nocQueried.FEC_Product_Type__r);
        noc.FEC_Business_Process__c = nocQueried.FEC_Business_Process__c;
        noc.putSObject('FEC_Business_Process__r', nocQueried.FEC_Business_Process__r);
        // Set CAT lookup ID but do NOT set relationship
        noc.FEC_Category__c = nocQueried.FEC_Category__c;

        Test.startTest();
        List<FEC_NatureOfCaseTreeItem> result = FEC_NatureOfCaseTreeBuilder.buildTree(
            new List<FEC_MDM_Nature_Of_Case__c>{ noc }
        );
        Test.stopTest();

        Assert.isNotNull(result, 'buildTree should not return null when CAT relationship is null');
        Assert.areEqual(1, result.size(), 'Tree should have 1 PT root node when CAT relationship is null');
        Assert.isNotNull(result[0].items, 'PT node should have items list');
    }

    /**
     * @description Bug Condition 1 — NullPointerException when FEC_Sub_Category__r is null.
     * NOC has valid PT + BP + CAT but Sub Category lookup set without relationship.
     * On unfixed code: should crash or skip unsafely.
     * On fixed code: should create PT + BP + CAT nodes, skip SCAT processing safely.
     * 
     * **Validates: Requirements 1.2**
     */
    @isTest
    static void testNullSubCategoryRelationship() {
        FEC_MDM_Nature_Of_Case__c nocQueried = [
            SELECT Id,
                   FEC_Product_Type__c,
                   FEC_Product_Type__r.FEC_Code__c,
                   FEC_Product_Type__r.FEC_Alias__c,
                   FEC_Product_Type__r.FEC_Name_VN__c,
                   FEC_Product_Type__r.FEC_Order__c,
                   FEC_Product_Type__r.FEC_Active__c,
                   FEC_Product_Type__r.Process_Change_Status__c,
                   FEC_Product_Type__r.Name,
                   FEC_Business_Process__c,
                   FEC_Business_Process__r.FEC_Code__c,
                   FEC_Business_Process__r.FEC_Alias__c,
                   FEC_Business_Process__r.FEC_Name_VN__c,
                   FEC_Business_Process__r.FEC_Order__c,
                   FEC_Business_Process__r.FEC_Active__c,
                   FEC_Business_Process__r.Process_Change_Status__c,
                   FEC_Business_Process__r.Name,
                   FEC_Category__c,
                   FEC_Category__r.FEC_Code__c,
                   FEC_Category__r.FEC_Alias__c,
                   FEC_Category__r.FEC_Name_VN__c,
                   FEC_Category__r.FEC_Order__c,
                   FEC_Category__r.FEC_Active__c,
                   FEC_Category__r.Process_Change_Status__c,
                   FEC_Category__r.Name,
                   FEC_Sub_Category__c,
                   FEC_Customer_Type__c
            FROM FEC_MDM_Nature_Of_Case__c
            WHERE Name = 'NOC_FULL'
            LIMIT 1
        ];

        FEC_MDM_Nature_Of_Case__c noc = new FEC_MDM_Nature_Of_Case__c();
        noc.Id = nocQueried.Id;
        noc.FEC_Customer_Type__c = nocQueried.FEC_Customer_Type__c;
        noc.FEC_Product_Type__c = nocQueried.FEC_Product_Type__c;
        noc.putSObject('FEC_Product_Type__r', nocQueried.FEC_Product_Type__r);
        noc.FEC_Business_Process__c = nocQueried.FEC_Business_Process__c;
        noc.putSObject('FEC_Business_Process__r', nocQueried.FEC_Business_Process__r);
        noc.FEC_Category__c = nocQueried.FEC_Category__c;
        noc.putSObject('FEC_Category__r', nocQueried.FEC_Category__r);
        // Set SCAT lookup ID but do NOT set relationship
        noc.FEC_Sub_Category__c = nocQueried.FEC_Sub_Category__c;

        Test.startTest();
        List<FEC_NatureOfCaseTreeItem> result = FEC_NatureOfCaseTreeBuilder.buildTree(
            new List<FEC_MDM_Nature_Of_Case__c>{ noc }
        );
        Test.stopTest();

        Assert.isNotNull(result, 'buildTree should not return null when SCAT relationship is null');
        Assert.areEqual(1, result.size(), 'Tree should have 1 PT root node when SCAT relationship is null');
    }

    /**
     * @description Bug Condition 1 — NullPointerException when FEC_Sub_Code__r is null.
     * NOC has valid PT + BP + CAT + SCAT but Sub Code lookup set without relationship.
     * On unfixed code: should crash or skip unsafely.
     * On fixed code: should create PT + BP + CAT + SCAT nodes, skip SCODE processing safely.
     * 
     * **Validates: Requirements 1.2**
     */
    @isTest
    static void testNullSubCodeRelationship() {
        FEC_MDM_Nature_Of_Case__c nocQueried = [
            SELECT Id,
                   FEC_Product_Type__c,
                   FEC_Product_Type__r.FEC_Code__c,
                   FEC_Product_Type__r.FEC_Alias__c,
                   FEC_Product_Type__r.FEC_Name_VN__c,
                   FEC_Product_Type__r.FEC_Order__c,
                   FEC_Product_Type__r.FEC_Active__c,
                   FEC_Product_Type__r.Process_Change_Status__c,
                   FEC_Product_Type__r.Name,
                   FEC_Business_Process__c,
                   FEC_Business_Process__r.FEC_Code__c,
                   FEC_Business_Process__r.FEC_Alias__c,
                   FEC_Business_Process__r.FEC_Name_VN__c,
                   FEC_Business_Process__r.FEC_Order__c,
                   FEC_Business_Process__r.FEC_Active__c,
                   FEC_Business_Process__r.Process_Change_Status__c,
                   FEC_Business_Process__r.Name,
                   FEC_Category__c,
                   FEC_Category__r.FEC_Code__c,
                   FEC_Category__r.FEC_Alias__c,
                   FEC_Category__r.FEC_Name_VN__c,
                   FEC_Category__r.FEC_Order__c,
                   FEC_Category__r.FEC_Active__c,
                   FEC_Category__r.Process_Change_Status__c,
                   FEC_Category__r.Name,
                   FEC_Sub_Category__c,
                   FEC_Sub_Category__r.FEC_Code__c,
                   FEC_Sub_Category__r.FEC_Alias__c,
                   FEC_Sub_Category__r.FEC_Name_VN__c,
                   FEC_Sub_Category__r.FEC_Order__c,
                   FEC_Sub_Category__r.FEC_Active__c,
                   FEC_Sub_Category__r.Process_Change_Status__c,
                   FEC_Sub_Category__r.Name,
                   FEC_Sub_Code__c,
                   FEC_Customer_Type__c
            FROM FEC_MDM_Nature_Of_Case__c
            WHERE Name = 'NOC_FULL'
            LIMIT 1
        ];

        FEC_MDM_Nature_Of_Case__c noc = new FEC_MDM_Nature_Of_Case__c();
        noc.Id = nocQueried.Id;
        noc.FEC_Customer_Type__c = nocQueried.FEC_Customer_Type__c;
        noc.FEC_Product_Type__c = nocQueried.FEC_Product_Type__c;
        noc.putSObject('FEC_Product_Type__r', nocQueried.FEC_Product_Type__r);
        noc.FEC_Business_Process__c = nocQueried.FEC_Business_Process__c;
        noc.putSObject('FEC_Business_Process__r', nocQueried.FEC_Business_Process__r);
        noc.FEC_Category__c = nocQueried.FEC_Category__c;
        noc.putSObject('FEC_Category__r', nocQueried.FEC_Category__r);
        noc.FEC_Sub_Category__c = nocQueried.FEC_Sub_Category__c;
        noc.putSObject('FEC_Sub_Category__r', nocQueried.FEC_Sub_Category__r);
        // Set SCODE lookup ID but do NOT set relationship
        noc.FEC_Sub_Code__c = nocQueried.FEC_Sub_Code__c;

        Test.startTest();
        List<FEC_NatureOfCaseTreeItem> result = FEC_NatureOfCaseTreeBuilder.buildTree(
            new List<FEC_MDM_Nature_Of_Case__c>{ noc }
        );
        Test.stopTest();

        Assert.isNotNull(result, 'buildTree should not return null when SCODE relationship is null');
        Assert.areEqual(1, result.size(), 'Tree should have 1 PT root node when SCODE relationship is null');
    }

    /**
     * @description Bug Condition 3 — Children not sorted by FEC_Order__c.
     * Creates 3 BP nodes with PosOrder 3, 1, 2 under one PT.
     * On unfixed code: children follow Map iteration order (not sorted by PosOrder).
     * On fixed code: children sorted ASC by PosOrder (1, 2, 3), null last.
     * 
     * **Validates: Requirements 1.5**
     */
    @isTest
    static void testChildrenSortedByPosOrder() {
        // Query NOC records with full relationships for the sort test data
        List<FEC_MDM_Nature_Of_Case__c> nocList = [
            SELECT Id, Name,
                   FEC_Product_Type__c,
                   FEC_Product_Type__r.FEC_Code__c,
                   FEC_Product_Type__r.FEC_Alias__c,
                   FEC_Product_Type__r.FEC_Name_VN__c,
                   FEC_Product_Type__r.FEC_Order__c,
                   FEC_Product_Type__r.FEC_Active__c,
                   FEC_Product_Type__r.Process_Change_Status__c,
                   FEC_Product_Type__r.Name,
                   FEC_Business_Process__c,
                   FEC_Business_Process__r.FEC_Code__c,
                   FEC_Business_Process__r.FEC_Alias__c,
                   FEC_Business_Process__r.FEC_Name_VN__c,
                   FEC_Business_Process__r.FEC_Order__c,
                   FEC_Business_Process__r.FEC_Active__c,
                   FEC_Business_Process__r.Process_Change_Status__c,
                   FEC_Business_Process__r.Name,
                   FEC_Category__c,
                   FEC_Category__r.FEC_Code__c,
                   FEC_Sub_Category__c,
                   FEC_Sub_Category__r.FEC_Code__c,
                   FEC_Sub_Code__c,
                   FEC_Sub_Code__r.FEC_Code__c,
                   FEC_Customer_Type__c,
                   FEC_User_Group__c
            FROM FEC_MDM_Nature_Of_Case__c
            WHERE Name LIKE 'NOC_SORT_%'
            ORDER BY FEC_Business_Process__r.FEC_Order__c ASC
        ];

        Assert.areEqual(3, nocList.size(), 'Should have 3 sort test NOC records');

        Test.startTest();
        List<FEC_NatureOfCaseTreeItem> result = FEC_NatureOfCaseTreeBuilder.buildTree(nocList);
        Test.stopTest();

        Assert.isNotNull(result, 'buildTree should return non-null result');
        Assert.areEqual(1, result.size(), 'Should have exactly 1 PT root node');

        FEC_NatureOfCaseTreeItem ptNode = result[0];
        Assert.isNotNull(ptNode.items, 'PT node should have children items');
        Assert.areEqual(3, ptNode.items.size(), 'PT node should have 3 BP children');

        // Verify children are sorted by PosOrder ASC: 1, 2, 3
        Assert.areEqual(1, ptNode.items[0].PosOrder, 'First child should have PosOrder 1 (BP_ONE)');
        Assert.areEqual(2, ptNode.items[1].PosOrder, 'Second child should have PosOrder 2 (BP_TWO)');
        Assert.areEqual(3, ptNode.items[2].PosOrder, 'Third child should have PosOrder 3 (BP_THREE)');
    }
}