@IsTest
private class FEC_IPPClosureController_Test {

    private static final String ACCOUNT_NUMBER = 'ACC123';

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        Case c = new Case(
            Subject = 'FEC_IPPClosureController_Test',
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            Status = 'New',
            FEC_ID_Search__c = 'IPP-' + suffix
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c cust = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Account_Number__c = ACCOUNT_NUMBER
        );
        insert cust;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Account_or_Contract__c = cust.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_IPP__c(
            FEC_Customer_History__c = cust.Id,
            FEC_IPP_Current_Balance__c = 1000,
            FEC_IPP_Record_No__c = 'IPP001',
            FEC_IPP_Plan__c = 'Plan A'
        );

        insert new FEC_IPP__c(
            FEC_Customer_History__c = cust.Id,
            FEC_IPP_Current_Balance__c = 0,
            FEC_IPP_Record_No__c = 'IPP002'
        );
    }

    private static User adminUser() {
        List<User> admins = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        return admins.isEmpty() ? new User(Id = UserInfo.getUserId()) : admins[0];
    }

    @IsTest
    static void testGetEligibleIPPsForClosure_Success() {
        if (Type.forName('FEC_IPPClosureController') == null) {
            System.assert(true, 'Skipped: FEC_IPPClosureController not on org.');
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_IPPClosureController.IPPClosureResultDTO result =
            FEC_IPPClosureController.getEligibleIPPsForClosure(c.Id);
        Test.stopTest();

        System.assertEquals(false, result.showNoEligibleWarning);
        System.assertEquals(1, result.rows.size(), 'Zero balance IPP phải bị loại.');
    }

    @IsTest
    static void testGetEligibleIPPsForClosure_NullCaseId() {
        if (Type.forName('FEC_IPPClosureController') == null) {
            return;
        }

        Test.startTest();
        FEC_IPPClosureController.IPPClosureResultDTO result =
            FEC_IPPClosureController.getEligibleIPPsForClosure(null);
        Test.stopTest();

        System.assertEquals(true, result.rows.isEmpty());
    }

    @IsTest
    static void testGetEligibleIPPsForClosure_WithSavedIppToClose() {
        if (Type.forName('FEC_IPPClosureController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_IPP__c ipp = [
            SELECT Id
            FROM FEC_IPP__c
            WHERE FEC_IPP_Record_No__c = 'IPP001'
            LIMIT 1
        ];

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, FEC_IPP_To_Close__c = ipp.Id);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_IPPClosureController.IPPClosureResultDTO result =
            FEC_IPPClosureController.getEligibleIPPsForClosure(c.Id);
        Test.stopTest();

        System.assertEquals(ipp.Id, result.savedIppToCloseOnCase);
        System.assertEquals(1, result.rows.size());
    }

    @IsTest
    static void testGetEligibleIPPsForClosure_ReleasedClosureCase() {
        if (Type.forName('FEC_IPPClosureController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_IPP__c ipp = [
            SELECT Id
            FROM FEC_IPP__c
            WHERE FEC_IPP_Record_No__c = 'IPP001'
            LIMIT 1
        ];

        Case closedCase = new Case(
            Subject = 'Closed IPP Case',
            Status = FEC_ConstantCommon.CASE_STATUS_CLOSED,
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_ID_Search__c = 'IPP-CL-' + System.currentTimeMillis()
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert closedCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        ipp.FEC_IPP_Closure_Case__c = closedCase.Id;
        update ipp;

        Test.startTest();
        FEC_IPPClosureController.IPPClosureResultDTO result =
            FEC_IPPClosureController.getEligibleIPPsForClosure(c.Id);
        Test.stopTest();

        System.assert(result.rows.size() > 0, 'IPP linked to closed case vẫn eligible.');
    }

    @IsTest
    static void testSaveSelectedIPPToCase_Success() {
        if (Type.forName('FEC_IPPClosureController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_IPP__c ipp = [
            SELECT Id
            FROM FEC_IPP__c
            WHERE FEC_IPP_Record_No__c = 'IPP001'
            LIMIT 1
        ];

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Test.startTest();
            Boolean success = FEC_IPPClosureController.saveSelectedIPPToCase(c.Id, ipp.Id);
            Test.stopTest();
            System.assertEquals(true, success);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Case updatedCase = [SELECT FEC_IPP_To_Close__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(ipp.Id, updatedCase.FEC_IPP_To_Close__c);
        FEC_IPP__c ippAfter = [SELECT FEC_IPP_Closure_Case__c FROM FEC_IPP__c WHERE Id = :ipp.Id];
        System.assertEquals(c.Id, ippAfter.FEC_IPP_Closure_Case__c);
    }

    @IsTest
    static void testSaveSelectedIPPToCase_NullParams() {
        if (Type.forName('FEC_IPPClosureController') == null) {
            return;
        }

        Test.startTest();
        System.assertEquals(false, FEC_IPPClosureController.saveSelectedIPPToCase(null, null));
        Test.stopTest();
    }

    @IsTest
    static void testSaveSelectedIPPToCase_Blocked() {
        if (Type.forName('FEC_IPPClosureController') == null) {
            return;
        }

        Case c1 = [SELECT Id FROM Case LIMIT 1];
        FEC_IPP__c ipp = [
            SELECT Id
            FROM FEC_IPP__c
            WHERE FEC_IPP_Record_No__c = 'IPP001'
            LIMIT 1
        ];

        Case c2 = new Case(
            Subject = 'FEC_IPPClosureController_Block',
            Status = 'Pending',
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_IPP_To_Close__c = ipp.Id,
            FEC_ID_Search__c = 'IPP-BLK-' + System.currentTimeMillis()
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c2;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        Boolean success = FEC_IPPClosureController.saveSelectedIPPToCase(c1.Id, ipp.Id);
        Test.stopTest();

        System.assertEquals(false, success);
    }

    @IsTest
    static void testSaveSelectedIPPToCase_ZeroBalanceRejected() {
        if (Type.forName('FEC_IPPClosureController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_IPP__c zeroIpp = [
            SELECT Id
            FROM FEC_IPP__c
            WHERE FEC_IPP_Record_No__c = 'IPP002'
            LIMIT 1
        ];

        Test.startTest();
        Boolean success = FEC_IPPClosureController.saveSelectedIPPToCase(c.Id, zeroIpp.Id);
        Test.stopTest();

        System.assertEquals(false, success);
    }

    @IsTest
    static void testGetEligibleIPPsForClosure_AsAdmin() {
        if (Type.forName('FEC_IPPClosureController') == null) {
            return;
        }

        System.runAs(adminUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];

            Test.startTest();
            FEC_IPPClosureController.IPPClosureResultDTO result =
                FEC_IPPClosureController.getEligibleIPPsForClosure(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, result);
        }
    }

    @IsTest
    static void testGetEligibleIPPsForClosure_NoAccountNumber() {
        if (Type.forName('FEC_IPPClosureController') == null) {
            return;
        }

        Case bareCase = new Case(
            Subject = 'No account number',
            Status = 'New',
            FEC_ID_Search__c = 'IPP-NOACC-' + System.currentTimeMillis()
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert bareCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_IPPClosureController.IPPClosureResultDTO result =
            FEC_IPPClosureController.getEligibleIPPsForClosure(bareCase.Id);
        Test.stopTest();

        System.assertEquals(true, result.showNoEligibleWarning);
        System.assertEquals(0, result.rows.size());
    }

    @IsTest
    static void testGetEligibleIPPsForClosure_DuplicateBusinessKeyFiltered() {
        if (Type.forName('FEC_IPPClosureController') == null) {
            return;
        }

        FEC_Customer_History__c cust = [
            SELECT Id FROM FEC_Customer_History__c LIMIT 1
        ];
        Case c = [SELECT Id FROM Case LIMIT 1];

        insert new FEC_IPP__c(
            FEC_Customer_History__c = cust.Id,
            FEC_IPP_Current_Balance__c = 500,
            FEC_IPP_Record_No__c = 'IPP001',
            FEC_IPP_Plan__c = 'Plan A',
            FEC_IPP_Open_Date__c = Date.today().addDays(-30)
        );

        Test.startTest();
        FEC_IPPClosureController.IPPClosureResultDTO result =
            FEC_IPPClosureController.getEligibleIPPsForClosure(c.Id);
        Test.stopTest();

        System.assertEquals(1, result.rows.size(), 'Duplicate business key IPP phải bị loại.');
    }

    @IsTest
    static void testGetEligibleIPPsForClosure_PendingLinkedClosureCaseFiltered() {
        if (Type.forName('FEC_IPPClosureController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c cust = [
            SELECT Id FROM FEC_Customer_History__c LIMIT 1
        ];

        Case pendingCase = new Case(
            Subject = 'Pending closure parent',
            Status = 'Pending',
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_ID_Search__c = 'IPP-PND-' + System.currentTimeMillis()
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert pendingCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_IPP__c blockedIpp = new FEC_IPP__c(
            FEC_Customer_History__c = cust.Id,
            FEC_IPP_Current_Balance__c = 750,
            FEC_IPP_Record_No__c = 'IPP-PND-01',
            FEC_IPP_Plan__c = 'Plan Pending',
            FEC_IPP_Closure_Case__c = pendingCase.Id
        );
        insert blockedIpp;

        Test.startTest();
        FEC_IPPClosureController.IPPClosureResultDTO result =
            FEC_IPPClosureController.getEligibleIPPsForClosure(c.Id);
        Test.stopTest();

        for (FEC_IPPClosureController.IPPClosureDTO row : result.rows) {
            System.assertNotEquals(blockedIpp.Id, row.Id, 'IPP gắn pending case khác phải bị loại.');
        }
    }

    @IsTest
    static void testGetEligibleIPPsForClosure_BlockedByOtherCaseIppToClose() {
        if (Type.forName('FEC_IPPClosureController') == null) {
            return;
        }

        Case c1 = [SELECT Id FROM Case LIMIT 1];
        FEC_IPP__c ipp = [
            SELECT Id
            FROM FEC_IPP__c
            WHERE FEC_IPP_Record_No__c = 'IPP001'
            LIMIT 1
        ];

        Case c2 = new Case(
            Subject = 'Other pending IPP selection',
            Status = 'Pending',
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_IPP_To_Close__c = ipp.Id,
            FEC_ID_Search__c = 'IPP-SEL-' + System.currentTimeMillis()
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c2;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_IPPClosureController.IPPClosureResultDTO result =
            FEC_IPPClosureController.getEligibleIPPsForClosure(c1.Id);
        Test.stopTest();

        for (FEC_IPPClosureController.IPPClosureDTO row : result.rows) {
            System.assertNotEquals(ipp.Id, row.Id);
        }
        System.assertEquals(true, result.showNoEligibleWarning || result.rows.isEmpty());
    }

    @IsTest
    static void testSaveSelectedIPPToCase_ReplacePreviousIpp() {
        if (Type.forName('FEC_IPPClosureController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c cust = [
            SELECT Id FROM FEC_Customer_History__c LIMIT 1
        ];
        FEC_IPP__c ipp1 = [
            SELECT Id
            FROM FEC_IPP__c
            WHERE FEC_IPP_Record_No__c = 'IPP001'
            LIMIT 1
        ];
        FEC_IPP__c ipp2 = new FEC_IPP__c(
            FEC_Customer_History__c = cust.Id,
            FEC_IPP_Current_Balance__c = 800,
            FEC_IPP_Record_No__c = 'IPP-REPLACE',
            FEC_IPP_Plan__c = 'Plan Replace'
        );
        insert ipp2;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, FEC_IPP_To_Close__c = ipp1.Id);
            ipp1.FEC_IPP_Closure_Case__c = c.Id;
            update ipp1;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        Boolean success = FEC_IPPClosureController.saveSelectedIPPToCase(c.Id, ipp2.Id);
        Test.stopTest();

        System.assertEquals(true, success);
        Case updatedCase = [SELECT FEC_IPP_To_Close__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(ipp2.Id, updatedCase.FEC_IPP_To_Close__c);
        FEC_IPP__c oldIpp = [SELECT FEC_IPP_Closure_Case__c FROM FEC_IPP__c WHERE Id = :ipp1.Id];
        System.assertEquals(null, oldIpp.FEC_IPP_Closure_Case__c);
        FEC_IPP__c newIpp = [SELECT FEC_IPP_Closure_Case__c FROM FEC_IPP__c WHERE Id = :ipp2.Id];
        System.assertEquals(c.Id, newIpp.FEC_IPP_Closure_Case__c);
    }

    @IsTest
    static void testSaveSelectedIPPToCase_WrongAccountOnIpp() {
        if (Type.forName('FEC_IPPClosureController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c otherCust = new FEC_Customer_History__c(
            FEC_Account_Number__c = 'OTHER-ACC-999'
        );
        insert otherCust;

        FEC_IPP__c foreignIpp = new FEC_IPP__c(
            FEC_Customer_History__c = otherCust.Id,
            FEC_IPP_Current_Balance__c = 900,
            FEC_IPP_Record_No__c = 'IPP-FOREIGN'
        );
        insert foreignIpp;

        Test.startTest();
        Boolean success = FEC_IPPClosureController.saveSelectedIPPToCase(c.Id, foreignIpp.Id);
        Test.stopTest();

        System.assertEquals(false, success);
    }

    @IsTest
    static void testSaveSelectedIPPToCase_PendingClosureOnOtherCase() {
        if (Type.forName('FEC_IPPClosureController') == null) {
            return;
        }

        Case c1 = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c cust = [
            SELECT Id FROM FEC_Customer_History__c LIMIT 1
        ];

        Case pendingCase = new Case(
            Subject = 'Pending blocks save',
            Status = 'Pending',
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_ID_Search__c = 'IPP-SAVE-' + System.currentTimeMillis()
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert pendingCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_IPP__c ipp = new FEC_IPP__c(
            FEC_Customer_History__c = cust.Id,
            FEC_IPP_Current_Balance__c = 600,
            FEC_IPP_Record_No__c = 'IPP-SAVE-BLK',
            FEC_IPP_Closure_Case__c = pendingCase.Id
        );
        insert ipp;

        Test.startTest();
        Boolean success = FEC_IPPClosureController.saveSelectedIPPToCase(c1.Id, ipp.Id);
        Test.stopTest();

        System.assertEquals(false, success);
    }
}
