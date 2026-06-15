@IsTest
private class FEC_BatchCaseHandlingExportService_Test {

    @TestSetup
    static void setup() {
        FEC_Product_Type__c productType = new FEC_Product_Type__c(
            Name = 'Export Product',
            FEC_Code__c = 'EXP-PT',
            FEC_Active__c = true
        );
        insert productType;

        FEC_Category__c category = new FEC_Category__c(
            Name = 'Export Category',
            FEC_Code__c = 'EXP-CAT',
            FEC_Active__c = true
        );
        insert category;

        FEC_Sub_Category__c subCategory = new FEC_Sub_Category__c(
            Name = 'Export Sub Category',
            FEC_Code__c = 'EXP-SC',
            FEC_Active__c = true
        );
        insert subCategory;

        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'Export Sub Code',
            FEC_Code__c = 'EXP-SUB',
            FEC_Active__c = true
        );
        insert subCode;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Case exportCase = new Case(
                Subject = 'BCH Export Service Test',
                Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
                FEC_Team__c = 'CC',
                FEC_Customer_Type__c = 'Existing',
                FEC_ID_Search__c = 'BCH-EXP-001',
                FEC_Product_Type__c = productType.Id,
                FEC_Category__c = category.Id,
                FEC_SubCategory__c = subCategory.Id,
                FEC_SubCode__c = subCode.Id,
                FEC_Customer_Name__c = 'Export Customer',
                FEC_CS_Check_Block_Limit_Date__c = Date.today(),
                FEC_CS_Check_Block_Limit_Amount__c = 1000,
                FEC_Bill_Date__c = Date.today(),
                FEC_Bill_Amount__c = 500
            );
            insert exportCase;

            FEC_Assignment__c assignment = new FEC_Assignment__c(
                FEC_Case__c = exportCase.Id,
                FEC_Assignment_Name__c = 'Export Assignment',
                FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                FEC_Assignment_Owner__c = UserInfo.getUserId()
            );
            insert assignment;

            insert new FEC_Case_Remarks__c(
                FEC_Case__c = exportCase.Id,
                FEC_Remark_Type__c = 'Case',
                FEC_Case_Remarks__c = 'Case remark for export',
                FEC_User__c = 'Tester',
                FEC_User_Role__c = 'Admin'
            );
            insert new FEC_Case_Remarks__c(
                FEC_Case__c = exportCase.Id,
                FEC_Assignment__c = assignment.Id,
                FEC_Remark_Type__c = FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT,
                FEC_Case_Remarks__c = 'Assignment remark stage 1',
                FEC_User__c = 'Tester',
                FEC_User_Role__c = 'Admin',
                FEC_Stage_Name__c = 'Stage 1 - Open'
            );
            insert new FEC_Case_Remarks__c(
                FEC_Case__c = exportCase.Id,
                FEC_Assignment__c = assignment.Id,
                FEC_Remark_Type__c = FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT,
                FEC_Case_Remarks__c = 'Assignment remark stage 2',
                FEC_User__c = 'Tester',
                FEC_User_Role__c = 'Admin',
                FEC_Stage_Name__c = 'Stage 2'
            );

            ContentVersion attachmentVersion = new ContentVersion(
                Title = 'Export Attachment',
                PathOnClient = 'export.pdf',
                VersionData = Blob.valueOf('pdf-content')
            );
            insert attachmentVersion;
            attachmentVersion = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :attachmentVersion.Id
            ];
            insert new ContentDocumentLink(
                LinkedEntityId = exportCase.Id,
                ContentDocumentId = attachmentVersion.ContentDocumentId,
                ShareType = 'V'
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testBuildCaseExportSelectFields() {
        Test.startTest();
        List<String> fields = FEC_BatchCaseHandlingExportService.buildCaseExportSelectFields();
        Test.stopTest();

        System.assert(fields.contains('Id'));
        System.assert(fields.size() > 20);
    }

    @IsTest
    static void testMapEnrichAndAttachmentFlags() {
        Case exportCase = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'BCH-EXP-001' LIMIT 1];
        Id caseId = exportCase.Id;
        String soql =
            'SELECT ' +
            String.join(FEC_BatchCaseHandlingExportService.buildCaseExportSelectFields(), ',') +
            ' FROM Case WHERE Id = :caseId';
        Case fullCase = Database.query(soql);

        Test.startTest();
        FEC_BatchCaseHandlingExportRow row = FEC_BatchCaseHandlingExportService.mapCaseToExportRow(fullCase);
        List<FEC_BatchCaseHandlingExportRow> rows = new List<FEC_BatchCaseHandlingExportRow>{ row };
        FEC_BatchCaseHandlingExportService.enrichExportRows(rows);
        FEC_BatchCaseHandlingExportService.applyVisibleAttachmentFlags(rows);
        Set<Id> caseIdsWithAttachment = FEC_BatchCaseHandlingExportService.resolveVisibleCaseIdsWithAttachments(
            new Set<Id>{ exportCase.Id }
        );
        Test.stopTest();

        System.assertEquals(exportCase.Id, row.caseId);
        System.assertEquals('Export Product', row.productType);
        System.assertEquals(true, row.hasAttachment);
        System.assert(caseIdsWithAttachment.contains(exportCase.Id));
        System.assert(String.isNotBlank(row.pendingCsSupportLabel));
        System.assert(String.isNotBlank(row.caseRemarks));
    }

    @IsTest
    static void testRemarkFilterHelpersAndNullGuards() {
        FEC_Case_Remarks__c caseRemark = new FEC_Case_Remarks__c(
            FEC_Remark_Type__c = 'Case'
        );
        FEC_Case_Remarks__c assignmentStage1 = new FEC_Case_Remarks__c(
            FEC_Remark_Type__c = FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT,
            FEC_Stage_Name__c = 'Stage 1 - Open'
        );
        FEC_Case_Remarks__c assignmentStage2 = new FEC_Case_Remarks__c(
            FEC_Remark_Type__c = FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT,
            FEC_Stage_Name__c = 'Stage 2'
        );

        Test.startTest();
        System.assertEquals(true, FEC_BatchCaseHandlingExportService.includeCaseRemarkInStrictExport(caseRemark));
        System.assertEquals(false, FEC_BatchCaseHandlingExportService.includeCaseRemarkInStrictExport(assignmentStage1));
        System.assertEquals(false, FEC_BatchCaseHandlingExportService.includeCaseRemarkInExtendedExport(assignmentStage1));
        System.assertEquals(true, FEC_BatchCaseHandlingExportService.includeCaseRemarkInExtendedExport(assignmentStage2));
        FEC_BatchCaseHandlingExportService.enrichExportRows(null);
        FEC_BatchCaseHandlingExportService.applyVisibleAttachmentFlags(null);
        FEC_BatchCaseHandlingExportService.applyVisibleAttachmentFlags(new List<FEC_BatchCaseHandlingExportRow>());
        Test.stopTest();
    }

    @IsTest
    static void testSearchBulkCasesForExport_usesExportService() {
        Test.startTest();
        FEC_BatchCaseHandlingController.BulkCaseSearchResult result =
            FEC_BatchCaseHandlingController.searchBulkCasesForExport('[]', '', 50);
        FEC_BatchCaseHandlingController.BulkCaseSearchResult selected =
            FEC_BatchCaseHandlingController.getSelectedCasesForExport(
                new List<Id>{ [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'BCH-EXP-001' LIMIT 1].Id }
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, selected);
        System.assert(selected.rows.size() > 0);
    }

    @IsTest
    static void testMapCaseToExportRow_minimalCase() {
        FEC_CaseTriggerHandler.isExecuting = true;
        Case minimalCase;
        try {
            minimalCase = new Case(
                Subject = 'Minimal Export Case',
                FEC_ID_Search__c = 'BCH-EXP-MIN'
            );
            insert minimalCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_BatchCaseHandlingExportRow row = FEC_BatchCaseHandlingExportService.mapCaseToExportRow(minimalCase);
        Test.stopTest();

        System.assertEquals(minimalCase.Id, row.caseId);
        System.assertEquals('BCH-EXP-MIN', row.caseIdSearch);
    }
}
