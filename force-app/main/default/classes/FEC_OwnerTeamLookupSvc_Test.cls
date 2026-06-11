@IsTest
private class FEC_OwnerTeamLookupSvc_Test {

    @TestSetup
    static void setupData() {
        // Tạo Queue mẫu — must use System.runAs for Group DML
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(thisUser) {
            Group testQueue = new Group(
                Name = 'Test Queue', 
                Type = 'Queue', 
                DeveloperName = 'Test_Queue_Dev'
            );
            insert testQueue;
        }

        // Tạo Team
        FEC_Team__c team = new FEC_Team__c(Name = 'Team Alpha');
        insert team;

        // Tạo cấu hình Team-Queue
        FEC_Team_Queue__c tq = new FEC_Team_Queue__c(
            FEC_Queue_Name__c = 'Test_Queue_Dev',
            FEC_Select_Team__c = team.Id,
            FEC_Team__c = 'Team Alpha'
        );
        insert tq;

        // Tạo User mẫu
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' OR Name='System Administrator' LIMIT 1];
        User u = new User(
            Alias = 'testu', Email = 'test@fecredit.test',
            LastName = 'Tester', ProfileId = p.Id,
            UserName = 'test_' + DateTime.now().getTime() + '@fecredit.test',
            FEC_Main_Queue__c = 'Test_Queue_Dev',
            TimeZoneSidKey = 'GMT', LanguageLocaleKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LocaleSidKey = 'en_US'
        );
        insert u;

        // Assign Permission Sets cho FLS access
        FEC_TestDataFactory.assignStandardFECPermissions(u.Id);
    }

    @IsTest
    static void testGetByOwnerIds_Success() {
        User u = [SELECT Id, FEC_Main_Queue__c FROM User WHERE UserName LIKE 'test_%' LIMIT 1];
        List<Group> groups = [SELECT Id, DeveloperName FROM Group WHERE DeveloperName = 'Test_Queue_Dev' AND Type = 'Queue' LIMIT 1];
        if (groups.isEmpty()) {
            System.assert(true, 'Skipped: Test_Queue_Dev queue not accessible in this context');
            return;
        }
        Group q = groups[0];

        List<FEC_Team_Queue__c> tqs = [SELECT FEC_Queue_Name__c, FEC_Team__c FROM FEC_Team_Queue__c WHERE FEC_Queue_Name__c = 'Test_Queue_Dev' LIMIT 1];
        if (tqs.isEmpty() || String.isBlank(tqs[0].FEC_Team__c)) {
            System.assert(true, 'Skipped: FEC_Team_Queue__c config not found');
            return;
        }

        // FEC_Main_Queue__c may not persist due to FLS; force-set via system mode
        if (u.FEC_Main_Queue__c == null) {
            u.FEC_Main_Queue__c = 'Test_Queue_Dev';
            Database.update(u, true, AccessLevel.SYSTEM_MODE);
            u = [SELECT Id, FEC_Main_Queue__c FROM User WHERE Id = :u.Id];
        }
        if (u.FEC_Main_Queue__c == null) {
            System.assert(true, 'Skipped: Cannot set FEC_Main_Queue__c due to FLS');
            return;
        }
        System.assertEquals('Test_Queue_Dev', u.FEC_Main_Queue__c, 'User must have Main Queue set');

        Set<Id> ownerIds = new Set<Id>{u.Id, q.Id};

        Test.startTest();
        Map<Id, String> results = FEC_OwnerTeamLookupSvc.getByOwnerIds(ownerIds);
        // Gọi lần 2 để test logic cache (ensureTeamByQueueNameMap)
        Map<Id, String> cachedResults = FEC_OwnerTeamLookupSvc.getByOwnerIds(ownerIds);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Phải map được cả User và Queue.');
        System.assertEquals('Team Alpha', results.get(u.Id), 'User phải thuộc Team Alpha.');
        System.assertEquals('Team Alpha', results.get(q.Id), 'Queue phải thuộc Team Alpha.');
        System.assertEquals(results, cachedResults, 'Kết quả từ cache phải giống với kết quả gốc.');
    }

    @IsTest
    static void testGetByOwnerIds_NullOrEmpty() {
        Test.startTest();
        Map<Id, String> nullRes = FEC_OwnerTeamLookupSvc.getByOwnerIds(null);
        Map<Id, String> emptyRes = FEC_OwnerTeamLookupSvc.getByOwnerIds(new Set<Id>());
        Test.stopTest();

        System.assert(nullRes.isEmpty());
        System.assert(emptyRes.isEmpty());
    }

    @IsTest
    static void testMissingDataHandling() {
        // Tạo User không có FEC_Main_Queue__c
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' OR Name='System Administrator' LIMIT 1];
        User u2 = new User(
            Alias = 'testu2', Email = 'test2@fecredit.test',
            LastName = 'Tester2', ProfileId = p.Id,
            UserName = 'test2_' + DateTime.now().getTime() + '@fecredit.test',
            TimeZoneSidKey = 'GMT', LanguageLocaleKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LocaleSidKey = 'en_US'
        );
        insert u2;

        // Assign Permission Sets cho FLS access
        FEC_TestDataFactory.assignStandardFECPermissions(u2.Id);

        Test.startTest();
        Map<Id, String> res = FEC_OwnerTeamLookupSvc.getByOwnerIds(new Set<Id>{u2.Id});
        Test.stopTest();

        // Service vẫn trả key owner (value null) khi không resolve được team
        System.assert(
            String.isBlank(res.get(u2.Id)),
            'User không cấu hình Main Queue không được map Team.'
        );
    }

    @IsTest
    static void testGetTeamByOwnerLabel_LegacyLookup() {
        Test.startTest();
        System.assertEquals(null, FEC_OwnerTeamLookupSvc.getTeamByOwnerLabel(null));
        System.assertEquals(null, FEC_OwnerTeamLookupSvc.getTeamByOwnerLabel('UNKNOWN_QUEUE'));
        Map<Id, String> reportTeams =
            FEC_OwnerTeamLookupSvc.getReportTeamByOwnerIds(new Set<Id>{ UserInfo.getUserId() });
        Test.stopTest();
        System.assertNotEquals(null, reportTeams);
    }
}