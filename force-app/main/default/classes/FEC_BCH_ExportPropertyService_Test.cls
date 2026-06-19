@IsTest
private class FEC_BCH_ExportPropertyService_Test {

    private static String uniqueSuffix() {
        return String.valueOf(System.currentTimeMillis()).right(8);
    }

    @IsTest
    static void testBuildBundle_includeAllPropertiesFalse() {
        Test.startTest();
        FEC_BCH_ExportPropertyService.BulkExportPropertyBundle bundle =
            FEC_BCH_ExportPropertyService.buildBundle(
                new List<String>{ 'ANY' },
                new List<Id>(),
                false
            );
        Test.stopTest();

        System.assertNotEquals(null, bundle);
        System.assertEquals(0, bundle.columns.size());
        System.assertEquals(0, bundle.valuesByCaseId.size());
    }

    @IsTest
    static void testBuildBundle_nullAndEmptyBusinessProcessCodes() {
        Test.startTest();
        FEC_BCH_ExportPropertyService.BulkExportPropertyBundle nullCodes =
            FEC_BCH_ExportPropertyService.buildBundle(null, new List<Id>(), true);
        FEC_BCH_ExportPropertyService.BulkExportPropertyBundle emptyCodes =
            FEC_BCH_ExportPropertyService.buildBundle(
                new List<String>{ '', '  ' },
                new List<Id>(),
                true
            );
        Test.stopTest();

        System.assertEquals(0, nullCodes.columns.size());
        System.assertEquals(0, nullCodes.valuesByCaseId.size());
        System.assertEquals(0, emptyCodes.columns.size());
        System.assertEquals(0, emptyCodes.valuesByCaseId.size());
    }

    @IsTest
    static void testBuildBundle_fullPathWithCaseAndCustomerHistory() {
        String suffix = uniqueSuffix();
        String bpCode = 'EXPBP' + suffix;

        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'Export Property BP ' + suffix,
            FEC_Code__c = bpCode,
            FEC_Active__c = true
        );
        insert bp;

        // 12/06/2026 23:15 linhdev - NOC gắn vào Stage để test scope theo Business/Stage/NOC
        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true
        );
        FEC_Nature_of_Case__c otherNoc = new FEC_Nature_of_Case__c(
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true
        );
        insert new List<FEC_Nature_of_Case__c>{ noc, otherNoc };

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'Export Property Stage ' + suffix,
            FEC_Code__c = 'EXPSTG' + suffix,
            FEC_Business_Process__c = bp.Id,
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Active__c = true
        );
        insert stage;

        insert new List<FEC_Master_Data_Setting__c>{
            new FEC_Master_Data_Setting__c(
                FEC_Stage_Name__c = stage.Id,
                FEC_Nature_Of_Case__c = noc.Id,
                FEC_Sub_Section__c = FEC_ConstantCommon.PROPERTY_INFO,
                FEC_Sub_Section_Order__c = 1,
                FEC_Field_Object_Name__c = 'Case',
                FEC_Field_API_Name__c = 'Subject',
                FEC_Field_Label_Name__c = 'Subject',
                FEC_Field_Order_Display__c = 10,
                FEC_Field_Status__c = true
            ),
            new FEC_Master_Data_Setting__c(
                FEC_Stage_Name__c = stage.Id,
                FEC_Nature_Of_Case__c = noc.Id,
                FEC_Sub_Section__c = FEC_ConstantCommon.PROPERTY_INFO,
                FEC_Sub_Section_Order__c = 1,
                FEC_Field_Object_Name__c = 'FEC_Customer_History__c',
                FEC_Field_API_Name__c = 'Name',
                FEC_Field_Label_Name__c = 'Customer Name',
                FEC_Field_Order_Display__c = 20,
                FEC_Field_Status__c = true
            ),
            // 12/06/2026 23:15 linhdev - decoy: đúng Stage nhưng khác NOC -> phải bị loại
            new FEC_Master_Data_Setting__c(
                FEC_Stage_Name__c = stage.Id,
                FEC_Nature_Of_Case__c = otherNoc.Id,
                FEC_Sub_Section__c = FEC_ConstantCommon.PROPERTY_INFO,
                FEC_Field_Object_Name__c = 'Case',
                FEC_Field_API_Name__c = 'Description',
                FEC_Field_Label_Name__c = 'Description',
                FEC_Field_Order_Display__c = 3,
                FEC_Field_Status__c = true
            ),
            // 18/06/2026 linhdev - Updated Info: đúng Stage/NOC -> phải được export (COF)
            new FEC_Master_Data_Setting__c(
                FEC_Stage_Name__c = stage.Id,
                FEC_Nature_Of_Case__c = noc.Id,
                FEC_Sub_Section__c = FEC_ConstantCommon.UPDATED_INFO,
                FEC_Sub_Section_Order__c = 2,
                FEC_Field_Object_Name__c = 'Case',
                FEC_Field_API_Name__c = 'Priority',
                FEC_Field_Label_Name__c = 'Priority',
                FEC_Field_Order_Display__c = 1,
                FEC_Field_Status__c = true
            ),
            // 18/06/2026 linhdev - decoy: đúng Stage/NOC nhưng Sub Section không thuộc export property -> phải bị loại
            new FEC_Master_Data_Setting__c(
                FEC_Stage_Name__c = stage.Id,
                FEC_Nature_Of_Case__c = noc.Id,
                FEC_Sub_Section__c = FEC_ConstantCommon.ORIGINAL_INFO,
                FEC_Field_Object_Name__c = 'Case',
                FEC_Field_API_Name__c = 'Description',
                FEC_Field_Label_Name__c = 'Original Description',
                FEC_Field_Order_Display__c = 5,
                FEC_Field_Status__c = true
            )
        };

        Case testCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            testCase = new Case(
                Subject = 'Export Property Case ' + suffix,
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                Priority = 'High',
                FEC_Current_Case_Stage__c = stage.Id,
                FEC_ID_Search__c = 'EXP-' + suffix
            );
            insert testCase;

            insert new FEC_Customer_History__c(
                Name = 'CUST-' + suffix,
                FEC_Case__c = testCase.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_BCH_ExportPropertyService.BulkExportPropertyBundle bundle =
            FEC_BCH_ExportPropertyService.buildBundle(
                new List<String>{ bpCode },
                new List<Id>{ testCase.Id },
                true
            );
        Test.stopTest();

        Set<String> columnKeys = new Set<String>();
        for (FEC_BCH_ExportPropertyService.ExportPropertyColumn col : bundle.columns) {
            columnKeys.add(col.columnKey);
        }
        System.assert(columnKeys.contains('case::subject'));
        // 12/06/2026 23:15 linhdev - decoy khác NOC phải bị loại khỏi cột Property
        System.assert(!columnKeys.contains('case::description'), 'NOC khác phải bị loại');
        // 18/06/2026 linhdev - BP không phải COF: không export Updated Info
        System.assert(!columnKeys.contains('case::priority'), 'Non-COF không export Updated Info');
        System.assert(bundle.valuesByCaseId.containsKey(testCase.Id));

        Map<String, String> rowValues = bundle.valuesByCaseId.get(testCase.Id);
        System.assertEquals(
            'Export Property Case ' + suffix,
            rowValues.get('case::subject')
        );
        if (columnKeys.contains('fec_customer_history__c::name')) {
            System.assertEquals('CUST-' + suffix, rowValues.get('fec_customer_history__c::name'));
        }
    }

    @IsTest
    static void testBuildBundle_cofIncludesUpdatedInfo() {
        String suffix = uniqueSuffix();

        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = FEC_ConstantCommon.COF_GENERAL_FLOW,
            FEC_Code__c = FEC_ConstantCommon.BP_COF,
            FEC_Active__c = true
        );
        insert bp;

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true
        );
        insert noc;

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'COF Export Property Stage ' + suffix,
            FEC_Code__c = 'COFSTG' + suffix,
            FEC_Business_Process__c = bp.Id,
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Active__c = true
        );
        insert stage;

        insert new List<FEC_Master_Data_Setting__c>{
            new FEC_Master_Data_Setting__c(
                FEC_Stage_Name__c = stage.Id,
                FEC_Nature_Of_Case__c = noc.Id,
                FEC_Sub_Section__c = FEC_ConstantCommon.PROPERTY_INFO,
                FEC_Sub_Section_Order__c = 1,
                FEC_Field_Object_Name__c = 'Case',
                FEC_Field_API_Name__c = 'Subject',
                FEC_Field_Label_Name__c = 'Subject',
                FEC_Field_Order_Display__c = 10,
                FEC_Field_Status__c = true
            ),
            new FEC_Master_Data_Setting__c(
                FEC_Stage_Name__c = stage.Id,
                FEC_Nature_Of_Case__c = noc.Id,
                FEC_Sub_Section__c = FEC_ConstantCommon.UPDATED_INFO,
                FEC_Sub_Section_Order__c = 2,
                FEC_Field_Object_Name__c = 'Case',
                FEC_Field_API_Name__c = 'Priority',
                FEC_Field_Label_Name__c = 'Priority',
                FEC_Field_Order_Display__c = 1,
                FEC_Field_Status__c = true
            )
        };

        Case testCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            testCase = new Case(
                Subject = 'COF Export Property Case ' + suffix,
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                Priority = 'High',
                FEC_Current_Case_Stage__c = stage.Id,
                FEC_ID_Search__c = 'COF-EXP-' + suffix
            );
            insert testCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_BCH_ExportPropertyService.BulkExportPropertyBundle bundle =
            FEC_BCH_ExportPropertyService.buildBundle(
                new List<String>{ FEC_ConstantCommon.BP_COF, FEC_ConstantCommon.COF_GENERAL_FLOW },
                new List<Id>{ testCase.Id },
                true
            );
        Test.stopTest();

        Set<String> columnKeys = new Set<String>();
        for (FEC_BCH_ExportPropertyService.ExportPropertyColumn col : bundle.columns) {
            columnKeys.add(col.columnKey);
        }
        System.assert(columnKeys.contains('case::subject'));
        System.assert(columnKeys.contains('case::priority'), 'COF phải export Updated Info');
        System.assertEquals(2, bundle.columns.size());
        System.assertEquals('case::subject', bundle.columns[0].columnKey);
        System.assertEquals('case::priority', bundle.columns[1].columnKey);
        System.assertEquals('High', bundle.valuesByCaseId.get(testCase.Id).get('case::priority'));
    }

    @IsTest
    static void testBuildBundle_gsrExcludesUpdatedInfo() {
        String suffix = uniqueSuffix();

        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'GSR - General Flow',
            FEC_Code__c = 'GSR',
            FEC_Active__c = true
        );
        insert bp;

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true
        );
        insert noc;

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'GSR Export Property Stage ' + suffix,
            FEC_Code__c = 'GSRSTG' + suffix,
            FEC_Business_Process__c = bp.Id,
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Active__c = true
        );
        insert stage;

        insert new List<FEC_Master_Data_Setting__c>{
            new FEC_Master_Data_Setting__c(
                FEC_Stage_Name__c = stage.Id,
                FEC_Nature_Of_Case__c = noc.Id,
                FEC_Sub_Section__c = FEC_ConstantCommon.PROPERTY_INFO,
                FEC_Field_Object_Name__c = 'Case',
                FEC_Field_API_Name__c = 'Subject',
                FEC_Field_Label_Name__c = 'Subject',
                FEC_Field_Order_Display__c = 1,
                FEC_Field_Status__c = true
            ),
            new FEC_Master_Data_Setting__c(
                FEC_Stage_Name__c = stage.Id,
                FEC_Nature_Of_Case__c = noc.Id,
                FEC_Sub_Section__c = FEC_ConstantCommon.UPDATED_INFO,
                FEC_Field_Object_Name__c = 'Case',
                FEC_Field_API_Name__c = 'Priority',
                FEC_Field_Label_Name__c = 'Priority',
                FEC_Field_Order_Display__c = 2,
                FEC_Field_Status__c = true
            )
        };

        Case testCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            testCase = new Case(
                Subject = 'GSR Export Property Case ' + suffix,
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_Current_Case_Stage__c = stage.Id,
                FEC_ID_Search__c = 'GSR-EXP-' + suffix
            );
            insert testCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_BCH_ExportPropertyService.BulkExportPropertyBundle bundle =
            FEC_BCH_ExportPropertyService.buildBundle(
                new List<String>{ 'GSR' },
                new List<Id>{ testCase.Id },
                true
            );
        Test.stopTest();

        Set<String> columnKeys = new Set<String>();
        for (FEC_BCH_ExportPropertyService.ExportPropertyColumn col : bundle.columns) {
            columnKeys.add(col.columnKey);
        }
        System.assert(columnKeys.contains('case::subject'));
        System.assert(!columnKeys.contains('case::priority'), 'GSR không export Updated Info');
    }

    @IsTest
    static void testBuildBundle_caseWithoutStageReturnsEmpty() {
        Case testCase = new Case(
            Subject = 'No Stage Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN
        );
        insert testCase;

        Test.startTest();
        FEC_BCH_ExportPropertyService.BulkExportPropertyBundle bundle =
            FEC_BCH_ExportPropertyService.buildBundle(
                new List<String>{ 'COF' },
                new List<Id>{ testCase.Id },
                true
            );
        Test.stopTest();

        System.assertEquals(0, bundle.columns.size());
        System.assertEquals(0, bundle.valuesByCaseId.size());
    }
}
