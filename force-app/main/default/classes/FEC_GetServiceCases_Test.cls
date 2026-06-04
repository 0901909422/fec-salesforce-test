@IsTest
private class FEC_GetServiceCases_Test {

    @TestSetup
    static void setupData() {
        Schema.RecordTypeInfo rtInfo = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME);
        if (rtInfo == null) {
            return;
        }
        Id rtId = rtInfo.getRecordTypeId();
        String suffix = String.valueOf(System.currentTimeMillis());

        // FEC_Case_Status__c is formula (FEC_Final_Status__c); set Status only.
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new List<Case>{
                new Case(
                    Subject = 'FEC_GetServiceCases_Test Pending',
                    RecordTypeId = rtId,
                    Status = FEC_ConstantCommon.CASE_STATUS_NEW,
                    FEC_ID_Search__c = 'PEND-' + suffix
                ),
                new Case(
                    Subject = 'FEC_GetServiceCases_Test Closed',
                    RecordTypeId = rtId,
                    Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
                    FEC_ID_Search__c = 'CLSD-' + suffix
                )
            };
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testGetPendingServiceCases() {
        List<Case> pendingCases = [
            SELECT FEC_ID_Search__c
            FROM Case
            WHERE Subject = 'FEC_GetServiceCases_Test Pending'
            LIMIT 1
        ];
        if (pendingCases.isEmpty()) {
            return;
        }
        Case pendingCase = pendingCases[0];

        User runUser = [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = true
            LIMIT 1
        ];

        System.runAs(runUser) {
            Test.startTest();
            List<FEC_GetServiceCases.PendingCaseRow> results =
                FEC_GetServiceCases.getPendingServiceCases();
            Test.stopTest();

            System.assertNotEquals(null, results, 'Danh sách không được null.');
            Boolean found = false;
            for (FEC_GetServiceCases.PendingCaseRow row : results) {
                if (row.caseIdText == pendingCase.FEC_ID_Search__c) {
                    found = true;
                    break;
                }
            }
            System.assertEquals(true, found, 'Phải tìm thấy Case Pending trong danh sách.');
        }
    }

    @IsTest
    static void testGetClosedServiceCases() {
        List<Case> closedCases = [
            SELECT FEC_ID_Search__c
            FROM Case
            WHERE Subject = 'FEC_GetServiceCases_Test Closed'
            LIMIT 1
        ];
        if (closedCases.isEmpty()) {
            return;
        }
        Case closedCase = closedCases[0];

        User runUser = [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = true
            LIMIT 1
        ];

        System.runAs(runUser) {
            Test.startTest();
            List<FEC_GetServiceCases.ClosedCaseRow> results =
                FEC_GetServiceCases.getClosedServiceCases();
            Test.stopTest();

            System.assertNotEquals(null, results, 'Danh sách không được null.');
            Boolean found = false;
            for (FEC_GetServiceCases.ClosedCaseRow row : results) {
                if (row.caseIdText == closedCase.FEC_ID_Search__c) {
                    found = true;
                    break;
                }
            }
            System.assertEquals(true, found, 'Phải tìm thấy Case Closed trong danh sách.');
        }
    }

    @IsTest
    static void testGetCaseFieldHelpTexts() {
        Test.startTest();
        Map<String, String> helpTexts = FEC_GetServiceCases.getCaseFieldHelpTexts();
        Test.stopTest();

        // Đảm bảo không ném lỗi khi chạy logic lấy HelpText
        System.assertNotEquals(null, helpTexts, 'Map help text không được null.');
    }
}