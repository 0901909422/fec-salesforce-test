@IsTest
private class FEC_IntegSearchFraudCaseController_Test {

    /* ------------------------------------------------------------------
     * Test Data Factory
     * ------------------------------------------------------------------ */
    private static void createTestData() {

        List<FEC_Integration_Case__c> cases = new List<FEC_Integration_Case__c>();

        // FH Case
        FEC_Integration_Case__c fh = new FEC_Integration_Case__c(
            Name = 'Fraud Handling Case',
            FEC_CaseID__c = 'FH-10001',
            FEC_Service_Case_ID__c = 'SV-10001',
            FEC_Case_Status__c = 'Open',
            FEC_Category__c = 'Fraud'
        );
        cases.add(fh);

        // BU under FH
        FEC_Integration_Case__c bu = new FEC_Integration_Case__c(
            Name = 'Business Unit Case',
            FEC_CaseID__c = 'BU-20001',
            FEC_Parent_CaseID__c = 'FH-10001',
            FEC_Case_Status__c = 'In Progress'
        );
        cases.add(bu);

        // TK under BU
        FEC_Integration_Case__c tk = new FEC_Integration_Case__c(
            Name = 'Task Case',
            FEC_CaseID__c = 'TK-30001',
            FEC_Parent_CaseID__c = 'BU-20001',
            FEC_Case_Status__c = 'Completed'
        );
        cases.add(tk);

        insert cases;

        // ---------------- Additional Info ----------------
        List<FEC_Integration_Case_Info__c> infos = new List<FEC_Integration_Case_Info__c>();

        infos.add(new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = tk.Id,
            FEC_Info_ID__c = 'AccountNumber',
            FEC_Info_Value__c = '123456789'
        ));

        infos.add(new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = fh.Id,
            FEC_Info_ID__c = 'nationalId',
            FEC_Info_Value__c = 'VN999999'
        ));

        infos.add(new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = fh.Id,
            FEC_Info_ID__c = 'phoneNumber',
            FEC_Info_Value__c = '0909123456'
        ));

        insert infos;
    }

    /* ------------------------------------------------------------------
     * searchFraudCases – basic search
     * ------------------------------------------------------------------ */
    @IsTest
    static void testSearchFraudCases_basic() {

        createTestData();

        Test.startTest();
        Map<String, Object> result =
            FEC_IntegrationSearchFraudCaseController.searchFraudCases(
                'FH-10001',     // fraudCaseId
                null,           // nationalId
                null,           // phone
                null,           // applicationId
                null,           // contractNumber
                null,           // accountNumber
                1,              // pageNumber
                10,             // pageSize
                'CreatedDate',  // sortBy
                'DESC'          // sortDirection
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(true, result.containsKey('total'));
        System.assertEquals(true, result.containsKey('pageRecords'));

        Integer total = (Integer) result.get('total');
        List<Map<String,Object>> rows =
            (List<Map<String,Object>>) result.get('pageRecords');

        System.assert(total > 0, 'Should return records');
        System.assert(rows.size() > 0, 'Page records should not be empty');
    }

    /* ------------------------------------------------------------------
     * searchFraudCases – filter by AdditionalInfo
     * ------------------------------------------------------------------ */
    @IsTest
    static void testSearchFraudCases_additionalInfoFilter() {

        createTestData();

        Test.startTest();
        Map<String, Object> result =
            FEC_IntegrationSearchFraudCaseController.searchFraudCases(
                null,
                'VN999',        // nationalId
                null,
                null,
                null,
                null,
                1,
                10,
                null,
                null
            );
        Test.stopTest();

        Integer total = (Integer) result.get('total');
        System.assertEquals(1, total, 'Should match FH case via nationalId');
    }

    /* ------------------------------------------------------------------
     * getFraudSubCases – valid FH
     * ------------------------------------------------------------------ */
    @IsTest
static void testGetFraudSubCases_success() {

    createTestData();

    Test.startTest();
    Map<String,Object> result =
        FEC_IntegrationSearchFraudCaseController.getFraudSubCases('FH-10001');
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(true, result.containsKey('pageRecords'));
    System.assertEquals(true, result.containsKey('total'));

    Integer total = (Integer) result.get('total');
    List<Map<String,Object>> records =
        (List<Map<String,Object>>) result.get('pageRecords');

    System.assertEquals(1, total, 'Should return 1 TK case');
    System.assertEquals(
        'TK-30001',
        (String) records[0].get('FEC_CaseID__c'),
        'Returned TK case ID mismatch'
    );
}

    /* ------------------------------------------------------------------
     * getFraudSubCases – blank input
     * ------------------------------------------------------------------ */
    @IsTest
    static void testGetFraudSubCases_blank() {

        Test.startTest();
        Map<String,Object> result =
            FEC_IntegrationSearchFraudCaseController.getFraudSubCases(null);
        Test.stopTest();

        System.assertEquals(0, (Integer) result.get('total'));
    }
}