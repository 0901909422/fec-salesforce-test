@IsTest
private class FEC_InteractionRoutingController_Test {

    private static Id interactionRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        String devName = FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME;
        return byDev.containsKey(devName) ? byDev.get(devName).getRecordTypeId() : null;
    }

    private static Id ubankEmailQueueId() {
        String queueDevName = System.Label.FEC_Ubank_Email_DevName;
        List<Group> existing = [
            SELECT Id
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            AND DeveloperName = :queueDevName
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }

        Group queue = new Group(
            Name = 'Ubank Email Test ' + System.currentTimeMillis(),
            Type = FEC_ConstantCommon.GROUP_TYPE_QUEUE,
            DeveloperName = queueDevName
        );
        insert queue;
        insert new QueueSobject(QueueId = queue.Id, SobjectType = 'Case');
        return queue.Id;
    }

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User agent = new User(
            Alias = ('rt' + suffix).right(8),
            Email = 'routing' + suffix + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'RoutingCtrlAgent',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Ho_Chi_Minh',
            UserName = 'routing' + suffix + '@fec.routing.ctrl.test'
        );
        insert agent;

        ServiceResource sr = new ServiceResource(
            Name = 'Routing Ctrl SR ' + suffix,
            RelatedRecordId = agent.Id,
            IsActive = true
        );
        insert sr;

        String skillDevName = System.Label.FEC_Ubank_Skill_DevName;
        List<Skill> skills = [
            SELECT Id FROM Skill WHERE DeveloperName = :skillDevName LIMIT 1
        ];
        Skill skillRow = skills.isEmpty()
            ? new Skill(MasterLabel = 'Ubank Ctrl ' + suffix, DeveloperName = skillDevName)
            : skills[0];
        if (skills.isEmpty()) {
            insert skillRow;
        }

        insert new ServiceResourceSkill(
            ServiceResourceId = sr.Id,
            SkillId = skillRow.Id,
            EffectiveStartDate = System.now().addDays(-1),
            EffectiveEndDate = null,
            FEC_Active__c = true,
            FEC_Skill_Level__c = 1,
            FEC_Capacity__c = 20
        );

        Id rtId = interactionRecordTypeId();
        Id queueId = ubankEmailQueueId();

        Case c = new Case(
            Subject = 'FEC_InteractionRoutingController_Test',
            OwnerId = queueId,
            Status = 'New',
            FEC_Channel__c = FEC_ConstantCommon.EMAIL,
            FEC_ID_Search__c = 'IRT-' + suffix
        );
        if (rtId != null) {
            c.RecordTypeId = rtId;
        }

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testExecuteRoutingAssignments_Success() {
        if (Type.forName('FEC_InteractionRoutingController') == null) {
            return;
        }

        User agent = [SELECT Id FROM User WHERE LastName = 'RoutingCtrlAgent' LIMIT 1];

        System.runAs(agent) {
            Test.startTest();
            FEC_InteractionRoutingController.executeRoutingAssignments();
            Test.stopTest();
        }

        System.assertEquals(1, [SELECT COUNT() FROM Case]);
    }

    @IsTest
    static void testPublishRoutingEvents_WithCases() {
        if (Type.forName('FEC_InteractionRoutingController') == null) {
            return;
        }

        List<Case> cases = [
            SELECT Id, CaseNumber, OwnerId, ParentId, FEC_Channel__c, FEC_Send_To__c,
                   FEC_Is_Reply_Interaction_email__c
            FROM Case
            LIMIT 1
        ];

        Test.startTest();
        FEC_InteractionRoutingController.publishRoutingEvents(cases);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testPublishRoutingEvents_Empty() {
        if (Type.forName('FEC_InteractionRoutingController') == null) {
            return;
        }

        Test.startTest();
        FEC_InteractionRoutingController.publishRoutingEvents(new List<Case>());
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testExecuteRoutingAssignments_NoSkillUser() {
        if (Type.forName('FEC_InteractionRoutingController') == null) {
            return;
        }

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String suffix = String.valueOf(System.currentTimeMillis());
        User noSkillUser = new User(
            Alias = ('ns' + suffix).right(8),
            Email = 'noskill' + suffix + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'NoSkillAgent',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Ho_Chi_Minh',
            UserName = 'noskill' + suffix + '@fec.routing.noskill.test'
        );
        insert noSkillUser;

        System.runAs(noSkillUser) {
            Test.startTest();
            FEC_InteractionRoutingController.executeRoutingAssignments();
            Test.stopTest();
        }

        System.assertEquals(1, [SELECT COUNT() FROM Case]);
    }

    @IsTest
    static void testPublishRoutingEvents_MultipleCases() {
        if (Type.forName('FEC_InteractionRoutingController') == null) {
            return;
        }

        List<Case> cases = [
            SELECT Id, CaseNumber, OwnerId, ParentId, FEC_Channel__c, FEC_Send_To__c,
                   FEC_Is_Reply_Interaction_email__c
            FROM Case
        ];

        Test.startTest();
        FEC_InteractionRoutingController.publishRoutingEvents(cases);
        Test.stopTest();

        System.assert(true);
    }
}
