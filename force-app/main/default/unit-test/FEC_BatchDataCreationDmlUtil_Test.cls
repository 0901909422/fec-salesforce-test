@IsTest
private class FEC_BatchDataCreationDmlUtil_Test {

    private static ServiceResource createServiceResource() {
        String suffix = String.valueOf(System.currentTimeMillis());
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User agent = new User(
            Alias = ('bd' + suffix).right(8),
            Email = 'batchdml' + suffix + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'BatchDmlUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Ho_Chi_Minh',
            UserName = 'batchdml' + suffix + '@fec.test'
        );
        insert agent;

        ServiceResource sr = new ServiceResource(
            Name = 'Batch DML SR ' + suffix,
            RelatedRecordId = agent.Id,
            IsActive = true
        );
        insert sr;
        return sr;
    }

    @IsTest
    static void testInsertAbsenceRows_nullAndEmpty() {
        Test.startTest();
        Database.SaveResult[] nullResult = FEC_BatchDataCreationDmlUtil.insertAbsenceRows(null);
        Database.SaveResult[] emptyResult = FEC_BatchDataCreationDmlUtil.insertAbsenceRows(
            new List<FEC_Service_Resource_Absence__c>()
        );
        Test.stopTest();

        System.assertEquals(0, nullResult.size(), 'Null input should return empty save results.');
        System.assertEquals(0, emptyResult.size(), 'Empty input should return empty save results.');
    }

    @IsTest
    static void testInsertAbsenceRows_partialSuccess() {
        ServiceResource sr = createServiceResource();
        Datetime startTime = System.now().addMinutes(5);

        FEC_Service_Resource_Absence__c validRow = new FEC_Service_Resource_Absence__c(
            FEC_Service_Resource__c = sr.Id,
            FEC_Start_Date__c = startTime,
            FEC_End_Date__c = startTime.addHours(1)
        );
        // Invalid by validation rule: end date earlier than start date.
        FEC_Service_Resource_Absence__c invalidRow = new FEC_Service_Resource_Absence__c(
            FEC_Service_Resource__c = sr.Id,
            FEC_Start_Date__c = startTime,
            FEC_End_Date__c = startTime.addHours(-1)
        );

        Test.startTest();
        Database.SaveResult[] results = FEC_BatchDataCreationDmlUtil.insertAbsenceRows(
            new List<FEC_Service_Resource_Absence__c>{ validRow, invalidRow }
        );
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return one SaveResult per input row.');
        System.assertEquals(true, results[0].isSuccess(), 'Valid row should insert successfully.');
        System.assertEquals(false, results[1].isSuccess(), 'Invalid row should fail with allOrNone=false.');
    }
}
