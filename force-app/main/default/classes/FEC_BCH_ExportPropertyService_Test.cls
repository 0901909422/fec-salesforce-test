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

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'Export Property Stage ' + suffix,
            FEC_Code__c = 'EXPSTG' + suffix,
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true
        );
        insert stage;

        insert new List<FEC_Master_Data_Setting__c>{
            new FEC_Master_Data_Setting__c(
                FEC_Stage_Name__c = stage.Id,
                FEC_Sub_Section__c = 'Property',
                FEC_Field_Object_Name__c = 'Case',
                FEC_Field_API_Name__c = 'Subject',
                FEC_Field_Label_Name__c = 'Subject',
                FEC_Field_Order_Display__c = 1,
                FEC_Field_Status__c = true
            ),
            new FEC_Master_Data_Setting__c(
                FEC_Stage_Name__c = stage.Id,
                FEC_Sub_Section__c = 'Property',
                FEC_Field_Object_Name__c = 'FEC_Customer_History__c',
                FEC_Field_API_Name__c = 'Name',
                FEC_Field_Label_Name__c = 'Customer Name',
                FEC_Field_Order_Display__c = 2,
                FEC_Field_Status__c = true
            )
        };

        Case testCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            testCase = new Case(
                Subject = 'Export Property Case ' + suffix,
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
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
}
