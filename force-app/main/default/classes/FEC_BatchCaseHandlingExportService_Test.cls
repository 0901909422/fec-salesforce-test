@IsTest
private class FEC_BatchCaseHandlingExportService_Test {

    @TestSetup
    static void setup() {
        List<User> admins = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        if (!admins.isEmpty()) {
            FEC_TestDataFactory.assignPermissionSets(admins[0].Id, new List<String>{
                'RD_IT_User_Customer_360',
                'RD_IT_User_Interaction_Case_Service_Case'
            });
        }

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

    // 15/06/2026 14:30 linhdev - Phone Update export: Original/Updated Info Phone Number
    @IsTest
    static void testMapCaseToExportRow_phoneUpdateInfoFields() {
        FEC_CaseTriggerHandler.isExecuting = true;
        Case phoneCase;
        try {
            phoneCase = new Case(
                Subject = 'Phone Update Export Case',
                FEC_ID_Search__c = 'BCH-EXP-PHONE',
                FEC_Original_Info_Phone_Number__c = '0901234567',
                FEC_Updated_Info_Phone_Number__c = '0987654323'
            );
            insert phoneCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Id caseId = phoneCase.Id;
        String soql =
            'SELECT ' +
            String.join(FEC_BatchCaseHandlingExportService.buildCaseExportSelectFields(), ',') +
            ' FROM Case WHERE Id = :caseId';
        Case fullCase = Database.query(soql);

        Test.startTest();
        FEC_BatchCaseHandlingExportRow row = FEC_BatchCaseHandlingExportService.mapCaseToExportRow(fullCase);
        Test.stopTest();

        System.assertEquals('0901234567', row.originalInfoPhoneNumber);
        System.assertEquals('0987654323', row.updatedInfoPhoneNumber);
    }

    @IsTest
    static void testBuildCaseExportSelectFields_includesPhoneUpdateInfoFields() {
        Test.startTest();
        List<String> fields = FEC_BatchCaseHandlingExportService.buildCaseExportSelectFields();
        Test.stopTest();

        System.assert(fields.contains('FEC_Original_Info_Phone_Number__c'));
        System.assert(fields.contains('FEC_Updated_Info_Phone_Number__c'));
    }

    // 15/06/2026 linhdev - Address Update export: Updated = Case + Parent khác null; Original = parent record
    @IsTest
    static void testEnrichExportRows_addressUpdateInfoFields() {
        Case exportCase = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'BCH-EXP-001' LIMIT 1];
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = exportCase.Id,
            FEC_Customer_Name__c = 'Address Export Customer',
            FEC_CIF_Number__c = 'CIF-ADDR-EXP'
        );
        insert hist;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = exportCase.Id,
                FEC_Account_or_Contract__c = hist.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Address_Info__c original = new FEC_Address_Info__c(
            Name = 'Original Current',
            FEC_Customer_History__c = hist.Id,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT,
            FEC_Building__c = 'Old Tower',
            FEC_Number__c = '10',
            FEC_Street__c = 'Old Street',
            FEC_Mailing_Address__c = false
        );
        insert original;

        insert new FEC_Address_Info__c(
            Name = 'Updated Current',
            FEC_Case__c = exportCase.Id,
            FEC_Customer_History__c = hist.Id,
            FEC_Parent_Address__c = original.Id,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT,
            FEC_Building__c = 'fec',
            FEC_Number__c = '111',
            FEC_Street__c = 'cong hoa',
            FEC_Mailing_Address__c = true
        );

        FEC_BatchCaseHandlingExportRow row = new FEC_BatchCaseHandlingExportRow();
        row.caseId = exportCase.Id;

        User admin = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        System.runAs(admin) {
            Test.startTest();
            FEC_BatchCaseHandlingExportService.enrichExportRows(new List<FEC_BatchCaseHandlingExportRow>{ row });
            Test.stopTest();

            System.assertEquals(FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT, row.updatedInfoAddressType);
        System.assert(row.updatedInfoAddress.contains('cong hoa'));
        System.assertEquals('true', row.updatedInfoMailingAddress);
        System.assertEquals(FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT, row.originalInfoAddressType);
        System.assert(row.originalInfoAddress.contains('Old Street'));
            System.assertEquals('false', row.originalInfoMailingAddress);
        }
    }

    @IsTest
    static void testEnrichExportRows_addressUpdateInfoFields_skipsNullParent() {
        Case exportCase = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'BCH-EXP-001' LIMIT 1];
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = exportCase.Id,
            FEC_Customer_Name__c = 'Address Export Customer Null Parent',
            FEC_CIF_Number__c = 'CIF-ADDR-EXP-NULL'
        );
        insert hist;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = exportCase.Id,
                FEC_Account_or_Contract__c = hist.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_Address_Info__c(
            Name = 'Updated Without Parent',
            FEC_Case__c = exportCase.Id,
            FEC_Customer_History__c = hist.Id,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT,
            FEC_Building__c = 'fec',
            FEC_Number__c = '111',
            FEC_Street__c = 'cong hoa',
            FEC_Mailing_Address__c = true
        );

        FEC_BatchCaseHandlingExportRow row = new FEC_BatchCaseHandlingExportRow();
        row.caseId = exportCase.Id;

        Test.startTest();
        FEC_BatchCaseHandlingExportService.enrichExportRows(new List<FEC_BatchCaseHandlingExportRow>{ row });
        Test.stopTest();

        System.assert(String.isBlank(row.updatedInfoAddressType));
        System.assert(String.isBlank(row.updatedInfoAddress));
        System.assert(String.isBlank(row.updatedInfoMailingAddress));
        System.assert(String.isBlank(row.originalInfoAddressType));
        System.assert(String.isBlank(row.originalInfoAddress));
        System.assert(String.isBlank(row.originalInfoMailingAddress));
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

    // 24/06/2026 linhdev - Refund Request (Loan) export (RefundLoanTemp1_PM Level Case info)
    @IsTest
    static void testMapEnrichExportRows_refundLoanInfoFields() {
        if (Schema.getGlobalDescribe().get('FEC_Case_Refund_Details__c') == null) {
            System.assert(true, 'Skipped: FEC_Case_Refund_Details__c not on org.');
            return;
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        Case refundCase;
        try {
            refundCase = new Case(
                Subject = 'Refund Loan Export Case',
                FEC_ID_Search__c = 'BCH-EXP-REFUND',
                FEC_Refund_Amount__c = 500000,
                FEC_Beneficiary_Name__c = 'NGUYEN THI NGOC HUONG',
                FEC_Beneficiary_Account__c = '553313',
                FEC_Bank_Name_Noaccent__c = 'ACB',
                FEC_Bank_Branch_Name_Noaccent__c = 'CN BA THANG HAI',
                FEC_Province_City__c = 'Thành phố Hồ Chí Minh'
            );
            insert refundCase;
            insert new FEC_Case_Refund_Details__c(
                FEC_Case__c = refundCase.Id,
                FEC_Receipt_Date__c = Date.today(),
                FEC_Receipt_Amount__c = 650000,
                FEC_Transaction_Number__c = '46622',
                FEC_Payment_Channel__c = 'pb'
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Id caseId = refundCase.Id;
        String soql =
            'SELECT ' +
            String.join(FEC_BatchCaseHandlingExportService.buildCaseExportSelectFields(), ',') +
            ' FROM Case WHERE Id = :caseId';
        Case fullCase = Database.query(soql);

        Test.startTest();
        FEC_BatchCaseHandlingExportRow row = FEC_BatchCaseHandlingExportService.mapCaseToExportRow(fullCase);
        FEC_BatchCaseHandlingExportService.enrichExportRows(new List<FEC_BatchCaseHandlingExportRow>{ row });
        Test.stopTest();

        System.assertEquals('500000', row.refundAmount);
        System.assertEquals('NGUYEN THI NGOC HUONG', row.beneficiaryName);
        System.assertEquals('553313', row.beneficiaryAccount);
        System.assertEquals('ACB', row.bankName);
        System.assertEquals('CN BA THANG HAI', row.bankBranch);
        System.assertEquals('Thành phố Hồ Chí Minh', row.provinceCity);
        System.assertEquals('650000', row.receiptAmount);
        System.assertEquals('46622', row.transactionNo);
        System.assertEquals('pb', row.paymentChannel);
        System.assert(String.isNotBlank(row.receiptDate));
    }

    // 24/06/2026 linhdev - export account/card block, Card Replacement, Point Redemption, MRC Return, Address
    @IsTest
    static void testMapEnrichExportRows_templateSpecificFields() {
        FEC_CaseTriggerHandler.isExecuting = true;
        Case exportCase;
        try {
            exportCase = new Case(
                Subject = 'BCH Template Fields Export',
                FEC_ID_Search__c = 'BCH-EXP-TPL'
            );
            insert exportCase;

            FEC_Customer_History__c hist = new FEC_Customer_History__c(
                Name = 'BCH Export Hist',
                FEC_Case__c = exportCase.Id,
                FEC_Customer_Name__c = 'Hist Customer',
                FEC_Account_Status__c = 'Active',
                FEC_Plastic_ID__c = 'PLASTIC-001',
                FEC_Credit_Limit__c = 5000000,
                FEC_Block_Code_1__c = 'A',
                FEC_Block_Code_2__c = 'B',
                FEC_Block_Code__c = 'C',
                FEC_Days_Past_Due__c = 3,
                FEC_Available_Points__c = 1200,
                FEC_MRC_Zone__c = 'Zone-A',
                FEC_Area__c = 'Area-1',
                FEC_Plate_Number__c = '51A-12345',
                FEC_MRC_Status__c = 'Delivered',
                FEC_Status_ID__c = 'ST-01',
                FEC_ID__c = 'MRC-ID-01',
                FEC_Remark__c = 'MRC remark',
                FEC_Modified_Date__c = Date.today(),
                FEC_Delivery_Date__c = Date.today().addDays(-2),
                FEC_Received_Date__c = Date.today().addDays(-1),
                FEC_Original_MRC_Receiver__c = 'Receiver A'
            );
            insert hist;

            exportCase.FEC_Account_or_Contract__c = hist.Id;
            exportCase.FEC_Card_Replacement_Reason__c = 'Bị mất/ đánh cắp';
            exportCase.FEC_New_Block_Code_Card_Replace__c = 'L';
            exportCase.FEC_Redeemed_Points__c = '500';
            exportCase.FEC_Customer_Confirmation__c = 'Customer received MRC';
            update exportCase;

            insert new FEC_Address_Info__c(
                FEC_Case__c = exportCase.Id,
                FEC_Customer_History__c = hist.Id,
                FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT,
                FEC_Street__c = 'Standard Street',
                FEC_Number__c = '123'
            );
            insert new FEC_Address_Info__c(
                FEC_Case__c = exportCase.Id,
                FEC_Customer_History__c = hist.Id,
                FEC_Address_Type__c = FEC_ConstantCommon.CONTRACT_CLOSURE_ADDRESS_TYPE_TEMPORARY,
                FEC_Street__c = 'Temporary Street',
                FEC_Number__c = '456'
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Id caseId = exportCase.Id;
        String soql =
            'SELECT ' +
            String.join(FEC_BatchCaseHandlingExportService.buildCaseExportSelectFields(), ',') +
            ' FROM Case WHERE Id = :caseId';
        Case fullCase = Database.query(soql);

        Test.startTest();
        FEC_BatchCaseHandlingExportRow row = FEC_BatchCaseHandlingExportService.mapCaseToExportRow(fullCase);
        FEC_BatchCaseHandlingExportService.enrichExportRows(new List<FEC_BatchCaseHandlingExportRow>{ row });
        Test.stopTest();

        System.assertEquals('Active', row.accountStatus);
        System.assertEquals('PLASTIC-001', row.plasticId);
        System.assertEquals('5000000', row.creditLimit);
        System.assertEquals('A', row.blockCode1);
        System.assertEquals('B', row.blockCode2);
        System.assertEquals('C', row.blockCode);
        System.assertEquals('3', row.daysPastDue);
        System.assertEquals('1200', row.availablePoints);
        System.assertEquals('Bị mất/ đánh cắp', row.cardReplacementReason);
        System.assertEquals('L', row.newBlockCodeCardReplace);
        System.assertEquals('500', row.redeemedPoints);
        System.assertEquals('Zone-A', row.mrcZone);
        System.assertEquals('Area-1', row.mrcArea);
        System.assertEquals('51A-12345', row.plateNumber);
        System.assertEquals('Delivered', row.mrcStatus);
        System.assertEquals('ST-01', row.mrcStatusId);
        System.assertEquals('MRC-ID-01', row.mrcId);
        System.assertEquals('MRC remark', row.mrcRemark);
        System.assertEquals('Receiver A', row.mrcReceiver);
        System.assertEquals('Customer received MRC', row.customerConfirmation);
        System.assert(row.closureAddress.contains('Standard Street'));
        System.assert(row.temporaryAddress.contains('Temporary Street'));
    }
}
