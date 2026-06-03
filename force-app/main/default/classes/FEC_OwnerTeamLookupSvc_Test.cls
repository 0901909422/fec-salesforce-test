@IsTest
private class FEC_OwnerTeamLookupSvc_Test {

    @TestSetup
    static void setupData() {
        // Tạo Queue mẫu
        Group testQueue = new Group(
            Name = 'Test Queue', 
            Type = 'Queue', 
            DeveloperName = 'Test_Queue_Dev'
        );
        insert testQueue;

        // Tạo Team
        FEC_Team__c team = new FEC_Team__c(Name = 'Team Alpha');
        insert team;

        // Tạo cấu hình Team-Queue
        FEC_Team_Queue__c tq = new FEC_Team_Queue__c(
            FEC_Queue_Name__c = 'Test_Queue_Dev',
            Team__c = team.Id,
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
    }

    @IsTest
    static void testGetByOwnerIds_Success() {
        User u = [SELECT Id FROM User WHERE UserName LIKE 'test_%' LIMIT 1];
        Group q = [SELECT Id FROM Group WHERE DeveloperName = 'Test_Queue_Dev' LIMIT 1];

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

        Test.startTest();
        Map<Id, String> res = FEC_OwnerTeamLookupSvc.getByOwnerIds(new Set<Id>{u2.Id});
        Test.stopTest();

        // Service vẫn trả key owner (value null) khi không resolve được team
        System.assert(
            String.isBlank(res.get(u2.Id)),
            'User không cấu hình Main Queue không được map Team.'
        );
    }
}