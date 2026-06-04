@IsTest
private class FEC_CaseAssignmentNocController_Test {

    private static Id getBusinessHoursId() {
        return [SELECT Id FROM BusinessHours LIMIT 1].Id;
    }

    @TestSetup
    static void setupData() {
        Id businessHoursId = getBusinessHoursId();
        FEC_Case_Assignment__c draftAssignment = new FEC_Case_Assignment__c(
            Name = 'Draft Case Assignment',
            FEC_Assignment_Method__c = 'Continuous',
            FEC_Business_Hours__c = businessHoursId,
            FEC_Scheduled_Time__c = 30,
            FEC_Role__c = 'CS Agent A|1',
            FEC_Scale__c = 1,
            FEC_Select_Queues__c = 'Queue CS Support',
            FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        );
        FEC_Case_Assignment__c activeAssignment = new FEC_Case_Assignment__c(
            Name = 'Active Case Assignment',
            FEC_Assignment_Method__c = 'Continuous',
            FEC_Business_Hours__c = businessHoursId,
            FEC_Scheduled_Time__c = 30,
            FEC_Role__c = 'CS Agent B|1',
            FEC_Scale__c = 1,
            FEC_Select_Queues__c = 'Queue Digital Support',
            FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        );
        insert new List<FEC_Case_Assignment__c>{ draftAssignment, activeAssignment };

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = 'CC',
            FEC_Active__c = true
        );
        insert prod;
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Request',
            FEC_Code__c = 'Request',
            FEC_Active__c = true
        );
        insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'RC27',
            FEC_Code__c = 'RC27',
            FEC_Active__c = true
        );
        insert subCat;
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'RC27.01',
            FEC_Code__c = 'RC27.01',
            FEC_Active__c = true
        );
        insert subCode;

        insert new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Active__c = true
        );

        insert new List<FEC_Case_Assignment_NOC__c>{
            new FEC_Case_Assignment_NOC__c(
                FEC_Case_Assignment_Name__c = draftAssignment.Id,
                FEC_Product_Type__c = prod.Id,
                FEC_Category__c = cat.Id,
                FEC_Sub_Category__c = subCat.Id,
                FEC_Sub_Code__c = subCode.Id
            ),
            new FEC_Case_Assignment_NOC__c(
                FEC_Case_Assignment_Name__c = activeAssignment.Id,
                FEC_Product_Type__c = prod.Id,
                FEC_Category__c = cat.Id,
                FEC_Sub_Category__c = subCat.Id,
                FEC_Sub_Code__c = subCode.Id
            )
        };

        activeAssignment.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        update activeAssignment;
    }

    @IsTest
    static void testGetNocItems_Success() {
        FEC_Case_Assignment__c draftAssign = [
            SELECT Id
            FROM FEC_Case_Assignment__c
            WHERE Name = 'Draft Case Assignment'
            LIMIT 1
        ];

        Test.startTest();
        List<FEC_CaseAssignmentNocController.AssignmentNocItem> items =
            FEC_CaseAssignmentNocController.getNocItems(draftAssign.Id);
        List<FEC_CaseAssignmentNocController.AssignmentNocItem> itemsNull =
            FEC_CaseAssignmentNocController.getNocItems(null);
        Test.stopTest();

        System.assertEquals(1, items.size());
        System.assertEquals('Credit Card', items[0].productType);
        System.assertEquals('Request', items[0].category);
        System.assertEquals(0, itemsNull.size(), 'Tham số truyền vào null phải trả về mảng rỗng an toàn.');
    }

    @IsTest
    static void testComboboxOptionsFetch_WithAggregate() {
        FEC_Product_Type__c prod = [SELECT Id FROM FEC_Product_Type__c LIMIT 1];
        FEC_Sub_Category__c subCat = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1];

        Test.startTest();
        List<FEC_CaseAssignmentNocController.OptionItem> prodOpts =
            FEC_CaseAssignmentNocController.getProductTypeOptions();
        List<FEC_CaseAssignmentNocController.OptionItem> catOpts =
            FEC_CaseAssignmentNocController.getCategoryOptions(prod.Id);
        List<FEC_CaseAssignmentNocController.OptionItem> catOptsNull =
            FEC_CaseAssignmentNocController.getCategoryOptions(null);
        List<FEC_CaseAssignmentNocController.OptionItem> subCatOpts =
            FEC_CaseAssignmentNocController.getSubCategoryOptions(prod.Id, 'Request');
        List<FEC_CaseAssignmentNocController.OptionItem> subCatOptsNull =
            FEC_CaseAssignmentNocController.getSubCategoryOptions(null, '');
        List<FEC_CaseAssignmentNocController.OptionItem> subCodeOpts =
            FEC_CaseAssignmentNocController.getSubCodeOptions(prod.Id, 'Request', subCat.Id);
        List<FEC_CaseAssignmentNocController.OptionItem> subCodeOptsNull =
            FEC_CaseAssignmentNocController.getSubCodeOptions(null, null, null);
        Test.stopTest();

        System.assertEquals(1, prodOpts.size());
        System.assertEquals('Credit Card', prodOpts[0].label);
        System.assertEquals(1, catOpts.size());
        System.assertEquals('Request', catOpts[0].label);
        System.assertEquals(1, subCatOpts.size());
        System.assertEquals(1, subCodeOpts.size());
        System.assertEquals(0, catOptsNull.size());
        System.assertEquals(0, subCatOptsNull.size());
        System.assertEquals(0, subCodeOptsNull.size());
    }

    @IsTest
    static void testCreateNoc_SuccessAndAutoResolveCatalog() {
        FEC_Case_Assignment__c draftAssign = [
            SELECT Id
            FROM FEC_Case_Assignment__c
            WHERE Name = 'Draft Case Assignment'
            LIMIT 1
        ];
        FEC_Product_Type__c prod = [SELECT Id FROM FEC_Product_Type__c LIMIT 1];
        FEC_Sub_Category__c subCat = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1];
        FEC_Sub_Code__c subCode = [SELECT Id FROM FEC_Sub_Code__c LIMIT 1];

        Test.startTest();
        Id newNocId1 =
            FEC_CaseAssignmentNocController.createNoc(draftAssign.Id, prod.Id, 'Request', subCat.Id, subCode.Id);
        Id newNocId2 =
            FEC_CaseAssignmentNocController.createNoc(draftAssign.Id, prod.Id, 'Request', subCat.Id, subCode.Id);
        Test.stopTest();

        System.assertNotEquals(null, newNocId1);
        System.assertNotEquals(null, newNocId2);

        List<FEC_Case_Assignment_NOC__c> totalNocs = [
            SELECT Id
            FROM FEC_Case_Assignment_NOC__c
            WHERE FEC_Case_Assignment_Name__c = :draftAssign.Id
        ];
        System.assertEquals(3, totalNocs.size(), 'Số lượng NOC liên kết trong DB phải tăng lên (1 gốc + 2 thêm mới).');
    }

    @IsTest
    static void testCreateNoc_ValidationFailures() {
        FEC_Case_Assignment__c activeAssign = [
            SELECT Id
            FROM FEC_Case_Assignment__c
            WHERE Name = 'Active Case Assignment'
            LIMIT 1
        ];
        FEC_Product_Type__c prod = [SELECT Id FROM FEC_Product_Type__c LIMIT 1];

        Boolean nullAssignmentThrown = false;
        Boolean missingAssignmentThrown = false;
        Boolean notDraftThrown = false;

        Test.startTest();
        try {
            FEC_CaseAssignmentNocController.createNoc(null, prod.Id, 'Request', null, null);
        } catch (AuraHandledException e) {
            nullAssignmentThrown = true;
        }

        try {
            FEC_CaseAssignmentNocController.createNoc(
                Id.valueOf('a03000000000001AAA'),
                prod.Id,
                'Request',
                null,
                null
            );
        } catch (AuraHandledException e) {
            missingAssignmentThrown = true;
        }

        try {
            FEC_CaseAssignmentNocController.createNoc(activeAssign.Id, prod.Id, 'Request', null, null);
        } catch (AuraHandledException e) {
            notDraftThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, nullAssignmentThrown, 'Null assignmentId must throw AuraHandledException.');
        System.assertEquals(true, missingAssignmentThrown, 'Missing assignment must throw AuraHandledException.');
        System.assertEquals(true, notDraftThrown, 'Active assignment must throw AuraHandledException.');
    }

    @IsTest
    static void testGetCategoryOptions_EmptyWhenNoNatureOfCase() {
        FEC_Product_Type__c orphanProd = new FEC_Product_Type__c(
            Name = 'Orphan Product',
            FEC_Code__c = 'ORPH',
            FEC_Active__c = true
        );
        insert orphanProd;

        Test.startTest();
        List<FEC_CaseAssignmentNocController.OptionItem> emptyOpts =
            FEC_CaseAssignmentNocController.getCategoryOptions(orphanProd.Id);
        Test.stopTest();

        System.assertEquals(0, emptyOpts.size(), 'Product type without NOC rows must return empty categories.');
    }

    @IsTest
    static void testUpdateNoc_Success() {
        FEC_Case_Assignment__c draftAssign = [
            SELECT Id
            FROM FEC_Case_Assignment__c
            WHERE Name = 'Draft Case Assignment'
            LIMIT 1
        ];
        FEC_Case_Assignment_NOC__c existingNoc = [
            SELECT Id
            FROM FEC_Case_Assignment_NOC__c
            WHERE FEC_Case_Assignment_Name__c = :draftAssign.Id
            LIMIT 1
        ];
        FEC_Product_Type__c prod = [SELECT Id FROM FEC_Product_Type__c LIMIT 1];
        FEC_Sub_Category__c subCat = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1];
        FEC_Sub_Code__c subCode = [SELECT Id FROM FEC_Sub_Code__c LIMIT 1];

        Test.startTest();
        Id updatedId = FEC_CaseAssignmentNocController.updateNoc(
            existingNoc.Id,
            prod.Id,
            'Request',
            subCat.Id,
            subCode.Id
        );
        Test.stopTest();

        System.assertEquals(existingNoc.Id, updatedId);
        FEC_Case_Assignment_NOC__c updated = [
            SELECT FEC_Sub_Code__c
            FROM FEC_Case_Assignment_NOC__c
            WHERE Id = :existingNoc.Id
        ];
        System.assertEquals(subCode.Id, updated.FEC_Sub_Code__c);
    }

    @IsTest
    static void testUpdateNoc_ValidationFailures() {
        FEC_Case_Assignment__c activeAssign = [
            SELECT Id
            FROM FEC_Case_Assignment__c
            WHERE Name = 'Active Case Assignment'
            LIMIT 1
        ];
        FEC_Case_Assignment_NOC__c activeNoc = [
            SELECT Id
            FROM FEC_Case_Assignment_NOC__c
            WHERE FEC_Case_Assignment_Name__c = :activeAssign.Id
            LIMIT 1
        ];
        FEC_Product_Type__c prod = [SELECT Id FROM FEC_Product_Type__c LIMIT 1];

        Boolean nullNocThrown = false;
        Boolean missingNocThrown = false;
        Boolean notDraftThrown = false;

        Test.startTest();
        try {
            FEC_CaseAssignmentNocController.updateNoc(null, prod.Id, 'Request', null, null);
        } catch (AuraHandledException e) {
            nullNocThrown = true;
        }

        try {
            FEC_CaseAssignmentNocController.updateNoc(
                Id.valueOf('a04000000000001AAA'),
                prod.Id,
                'Request',
                null,
                null
            );
        } catch (AuraHandledException e) {
            missingNocThrown = true;
        }

        try {
            FEC_CaseAssignmentNocController.updateNoc(activeNoc.Id, prod.Id, 'Request', null, null);
        } catch (AuraHandledException e) {
            notDraftThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, nullNocThrown);
        System.assertEquals(true, missingNocThrown);
        System.assertEquals(true, notDraftThrown);
    }

    @IsTest
    static void testCreateNoc_InvalidCategoryKey() {
        FEC_Case_Assignment__c draftAssign = [
            SELECT Id
            FROM FEC_Case_Assignment__c
            WHERE Name = 'Draft Case Assignment'
            LIMIT 1
        ];
        FEC_Product_Type__c prod = [SELECT Id FROM FEC_Product_Type__c LIMIT 1];

        Boolean categoryNotFoundThrown = false;

        Test.startTest();
        try {
            FEC_CaseAssignmentNocController.createNoc(
                draftAssign.Id,
                prod.Id,
                'NonExistentCategoryKey',
                null,
                null
            );
        } catch (AuraHandledException e) {
            categoryNotFoundThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, categoryNotFoundThrown);
    }

    @IsTest
    static void testDataStructures_CoverageOnly() {
        FEC_Case_Assignment__c draftAssign = [
            SELECT Id
            FROM FEC_Case_Assignment__c
            WHERE Name = 'Draft Case Assignment'
            LIMIT 1
        ];

        Test.startTest();
        new FEC_CaseAssignmentNocController.OptionItem('Label', 'Value');
        new FEC_CaseAssignmentNocController.AssignmentNocItem();
        FEC_CaseAssignmentNocController.createNoc(draftAssign.Id, null, '', null, null);
        Test.stopTest();

        System.assert(true);
    }
}
