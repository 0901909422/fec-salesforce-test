@IsTest
private class FEC_InteFraudCaseDetailController_Test {

    /* ----------------------------------------------------------
     * Test Data Factory
     * ---------------------------------------------------------- */
    private static void createTestData() {

        // Root FH case
        FEC_Integration_Case__c fh = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'FH-001',
            FEC_Case_Status__c = 'Open',
            FEC_Category__c = 'Fraud',
            FEC_Sub_Code__c = 'CC01'
        );
        insert fh;

        // BU case
        FEC_Integration_Case__c bu = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'BU-001',
            FEC_Parent_CaseID__c = 'FH-001',
            FEC_Case_Status__c = 'In Progress',
            FEC_Sub_Code__c = 'CC02'
        );
        insert bu;

        // TK case
        FEC_Integration_Case__c tk = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'TK-001',
            FEC_Parent_CaseID__c = 'BU-001',
            FEC_Service_Case_ID__c = 'SV-1001',
            FEC_Case_Status__c = 'Pending',
            FEC_Investigation_Conclusion__c = 'Waiting for review'
        );
        insert tk;

        // Info for TK
        insert new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = tk.Id,
            FEC_Info_ID__c = 'TaskName',
            FEC_Info_Value__c = 'Verify Transaction'
        );

        insert new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = tk.Id,
            FEC_Info_ID__c = 'Deadline',
            FEC_Info_Value__c = '2026-01-30'
        );

        // File-type info
        insert new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = tk.Id,
            FEC_Info_ID__c = 'ApproDoc',
            FEC_Info_Value__c = 'evidence.pdf|123|abc'
        );

        // Master data for file detection
        insert new FEC_Master_Data_Integration__c(
            FEC_Source_Id__c = 'ApproDoc',
            FEC_Source_Field_Type__c = 'file'
        );
    }

    /* ----------------------------------------------------------
     * POSITIVE TEST – Full hierarchy
     * ---------------------------------------------------------- */
    @IsTest
    static void testGetFraudCaseDetail_Success() {

        createTestData();

        Test.startTest();
        Map<String, Object> result =
            FEC_IntegrationFraudCaseDetailController.getFraudCaseDetail('FH-001');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result must not be null');

        List<Object> hierarchy = (List<Object>) result.get('hierarchy');
        List<Object> tasks     = (List<Object>) result.get('tasks');

        System.assertEquals(3, hierarchy.size(),
            'Hierarchy should contain FH + BU + TK');

        System.assertEquals(1, tasks.size(),
            'Only TK cases should appear in task list');

        Map<String, Object> task = (Map<String, Object>) tasks[0];

        System.assertEquals('TK-001', task.get('TaskId'));
        System.assertEquals('Verify Transaction', task.get('TaskName'));
        System.assertEquals('Pending', task.get('Status'));
        System.assertNotEquals(null, task.get('FraudTaskUrl'));

        // Validate hierarchy info parsing
        Map<String, Object> tkNode =
            (Map<String, Object>) hierarchy[2];

        List<Map<String, String>> infos =
            (List<Map<String, String>>) tkNode.get('Infos');

        Boolean foundFile = false;
        for (Map<String, String> info : infos) {
            if (info.get('id') == 'ApproDoc') {
                foundFile = true;
                System.assertEquals('file', info.get('fileType'));
                System.assertEquals('evidence.pdf', info.get('fileName'));
            }
        }

        System.assert(foundFile,
            'File-type info record should be processed');
    }

    /* ----------------------------------------------------------
     * NEGATIVE TEST – Blank caseId
     * ---------------------------------------------------------- */
    @IsTest
    static void testGetFraudCaseDetail_BlankCaseId() {

        Test.startTest();
        Boolean exceptionThrown = false;

        try {
            FEC_IntegrationFraudCaseDetailController.getFraudCaseDetail(null);
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'AuraHandledException must be thrown when caseId is blank'
        );
    }

    /* ----------------------------------------------------------
     * NEGATIVE TEST – Root not found
     * ---------------------------------------------------------- */
    @IsTest
    static void testGetFraudCaseDetail_RootNotFound() {

        // Guaranteed-unique value
        String nonExistingCaseId = 'FH-' + String.valueOf(Crypto.getRandomInteger());

        Test.startTest();
        Boolean exceptionThrown = false;

        try {
            FEC_IntegrationFraudCaseDetailController.getFraudCaseDetail(nonExistingCaseId);
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'AuraHandledException must be thrown when root case is not found'
        );
    }
}