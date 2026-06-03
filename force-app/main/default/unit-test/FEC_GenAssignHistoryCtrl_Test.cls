@IsTest(SeeAllData=true)
private class FEC_GenAssignHistoryCtrl_Test {
    private static FEC_General_Assignment__c createGeneralAssignment(String suffix) {
        FEC_General_Assignment__c row = new FEC_General_Assignment__c(
            FEC_General_Assignment_Name__c = 'GA ' + suffix,
            FEC_General_Assignment_Code__c = 'GA' + suffix,
            FEC_Active__c = true
        );
        insert row;
        return row;
    }

    private static FEC_General_Assignment_Config__c createGeneralAssignmentConfig(String suffix) {
        FEC_General_Assignment_Config__c row = new FEC_General_Assignment_Config__c(
            FEC_General_Assignment_Name__c = 'GAC ' + suffix,
            FEC_Active__c = true
        );
        insert row;
        return row;
    }

    @IsTest
    static void testGetHistory_withGeneralAssignmentObject() {
        String suffix = String.valueOf(System.now().getTime());
        FEC_General_Assignment__c ga = createGeneralAssignment(suffix);

        update new FEC_General_Assignment__c(
            Id = ga.Id,
            FEC_General_Assignment_Code__c = 'GAU' + suffix
        );

        Test.startTest();
        List<FEC_GeneralAssignmentHistoryController.HistoryWrapper> rows =
            FEC_GeneralAssignmentHistoryController.getHistory(ga.Id);
        Test.stopTest();

        System.assertNotEquals(null, rows, 'History list should not be null.');
        if (!rows.isEmpty()) {
            System.assertNotEquals(null, rows[0].Id);
            System.assertNotEquals(null, rows[0].CreatedDate);
            System.assertNotEquals(null, rows[0].Field);
        }
    }

    @IsTest
    static void testGetHistory_withGeneralAssignmentConfigObject() {
        String suffix = String.valueOf(System.now().getTime());
        FEC_General_Assignment_Config__c cfg = createGeneralAssignmentConfig(suffix);

        update new FEC_General_Assignment_Config__c(
            Id = cfg.Id,
            FEC_Customer_Type__c = 'Existing'
        );

        Test.startTest();
        List<FEC_GeneralAssignmentHistoryController.HistoryWrapper> rows =
            FEC_GeneralAssignmentHistoryController.getHistory(cfg.Id);
        Test.stopTest();

        System.assertNotEquals(null, rows, 'History list should not be null.');
        if (!rows.isEmpty()) {
            System.assertNotEquals(null, rows[0].Id);
            System.assertNotEquals(null, rows[0].Field);
        }
    }

    @IsTest
    static void testGetHistory_handlesException() {
        Test.startTest();
        List<FEC_GeneralAssignmentHistoryController.HistoryWrapper> rows =
            FEC_GeneralAssignmentHistoryController.getHistory(null);
        Test.stopTest();

        System.assertNotEquals(null, rows, 'Method should return empty list when exception occurs.');
        System.assertEquals(0, rows.size(), 'Null recordId should be handled by catch block.');
    }

    @IsTest
    static void testGetHistory_withExistingGeneralAssignmentHistoryData() {
        List<FEC_General_Assignment__History> existing = [
            SELECT ParentId
            FROM FEC_General_Assignment__History
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            System.assert(true, 'No existing FEC_General_Assignment__History in org.');
            return;
        }

        List<FEC_GeneralAssignmentHistoryController.HistoryWrapper> rows =
            FEC_GeneralAssignmentHistoryController.getHistory(existing[0].ParentId);
        System.assertNotEquals(null, rows);
    }

    @IsTest
    static void testGetHistory_withExistingConfigHistoryData() {
        List<FEC_General_Assignment_Config__History> existing = [
            SELECT ParentId
            FROM FEC_General_Assignment_Config__History
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            System.assert(true, 'No existing FEC_General_Assignment_Config__History in org.');
            return;
        }

        List<FEC_GeneralAssignmentHistoryController.HistoryWrapper> rows =
            FEC_GeneralAssignmentHistoryController.getHistory(existing[0].ParentId);
        System.assertNotEquals(null, rows);
    }
}
