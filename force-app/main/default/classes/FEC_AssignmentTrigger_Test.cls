@IsTest
private class FEC_AssignmentTrigger_Test {
    private static User createUser(String aliasPrefix) {
        Profile p = [SELECT Id FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
        String unique = String.valueOf(Datetime.now().getTime());
        return new User(
            Alias = aliasPrefix,
            Email = aliasPrefix + unique + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            ProfileId = p.Id,
            UserName = aliasPrefix + '.' + unique + '@example.com'
        );
    }

    @IsTest
    static void testAfterUpdate_RoutingOwnerChanged_UpdatesCaseAssignmentUsers() {
        User owner1 = createUser('as1');
        User owner2 = createUser('as2');
        insert new List<User>{ owner1, owner2 };

        Case c = new Case(Subject = 'Assignment Trigger Routing', Status = 'Open');
        insert c;

        FEC_Assignment__c assignment = new FEC_Assignment__c(
            FEC_Assignment_Name__c = 'Routing Trigger Assignment',
            FEC_Case__c = c.Id,
            FEC_Assignment_Type__c = FEC_ConstantCommon.ASSIGNMENT_TYPE_ROUTING,
            FEC_Assignment_Owner__c = owner1.Id
        );
        insert assignment;

        Test.startTest();
        assignment.FEC_Assignment_Owner__c = owner2.Id;
        update assignment;
        Test.stopTest();

        Case updatedCase = [SELECT FEC_Assignment_Users__c FROM Case WHERE Id = :c.Id LIMIT 1];
        System.assertEquals(String.valueOf(owner2.Id), updatedCase.FEC_Assignment_Users__c);
    }

    @IsTest
    static void testAfterUpdate_NonRoutingOwnerChanged_ClearsCaseAssignmentUsers() {
        User owner1 = createUser('bs1');
        User owner2 = createUser('bs2');
        insert new List<User>{ owner1, owner2 };

        Case c = new Case(Subject = 'Assignment Trigger General', Status = 'Open');
        insert c;
        update new Case(Id = c.Id, FEC_Assignment_Users__c = 'seed-user');

        FEC_Assignment__c assignment = new FEC_Assignment__c(
            FEC_Assignment_Name__c = 'General Trigger Assignment',
            FEC_Case__c = c.Id,
            FEC_Assignment_Type__c = 'General',
            FEC_Assignment_Owner__c = owner1.Id
        );
        insert assignment;

        Test.startTest();
        assignment.FEC_Assignment_Owner__c = owner2.Id;
        update assignment;
        Test.stopTest();

        Case updatedCase = [SELECT FEC_Assignment_Users__c FROM Case WHERE Id = :c.Id LIMIT 1];
        System.assertEquals(null, updatedCase.FEC_Assignment_Users__c);
    }
}
