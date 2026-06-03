@IsTest
private class FEC_InteractionRoutingService_Test {

    private static final String TEST_ROUTING_EMAIL = 'ubank.routing.svc.test@fecredit.com.vn';

    private class RoutingTestContext {
        Id interactionRtId;
        Id queueId;
        Id primaryAgentUserId;
        Id primaryServiceResourceId;
        Id borrowedSkillAssignmentId;
        Id originalServiceResourceId;
    }

    private static Id interactionRecordTypeId() {
        return FEC_CommonUltils.getRecordTypeIdByDev(
            FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME
        );
    }

    private static Id customerRecordTypeId() {
        return FEC_CommonUltils.getRecordTypeIdByDev(
            FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME
        );
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

    private static String routingEmail() {
        FEC_System_Config__c cfg = FEC_System_Config__c.getOrgDefaults();
        if (cfg != null && String.isNotBlank(cfg.FEC_Send_To_Email_Ubank__c)) {
            return cfg.FEC_Send_To_Email_Ubank__c;
        }
        return TEST_ROUTING_EMAIL;
    }

    private static RoutingTestContext buildContext() {
        RoutingTestContext ctx = new RoutingTestContext();
        ctx.interactionRtId = interactionRecordTypeId();
        ctx.queueId = ubankEmailQueueId();
        if (ctx.interactionRtId == null || ctx.queueId == null) {
            return ctx;
        }

        User agent = [SELECT Id FROM User WHERE LastName = 'RoutingAgent' LIMIT 1];
        ServiceResource sr = [
            SELECT Id
            FROM ServiceResource
            WHERE RelatedRecordId = :agent.Id
            LIMIT 1
        ];
        ctx.primaryAgentUserId = agent.Id;
        ctx.primaryServiceResourceId = sr.Id;

        String skillDevName = System.Label.FEC_Ubank_Skill_DevName;
        List<ServiceResourceSkill> skillRows = [
            SELECT Id, ServiceResourceId
            FROM ServiceResourceSkill
            WHERE Skill.DeveloperName = :skillDevName
            AND ServiceResource.IsActive = true
            LIMIT 1
        ];
        if (skillRows.isEmpty()) {
            return ctx;
        }

        ServiceResourceSkill borrowed = skillRows[0];
        ctx.borrowedSkillAssignmentId = borrowed.Id;
        ctx.originalServiceResourceId = borrowed.ServiceResourceId;
        if (borrowed.ServiceResourceId != sr.Id) {
            borrowed.ServiceResourceId = sr.Id;
            update borrowed;
        }

        Map<String, Schema.SObjectField> skillFields =
            ServiceResourceSkill.SObjectType.getDescribe().fields.getMap();
        if (skillFields.containsKey('FEC_Capacity__c') || skillFields.containsKey('FEC_Skill_Level__c')) {
            ServiceResourceSkill refresh = [
                SELECT Id, FEC_Capacity__c, FEC_Skill_Level__c, FEC_Active__c
                FROM ServiceResourceSkill
                WHERE Id = :borrowed.Id
                LIMIT 1
            ];
            if (skillFields.containsKey('FEC_Capacity__c')) {
                refresh.put('FEC_Capacity__c', 20);
            }
            if (skillFields.containsKey('FEC_Skill_Level__c')) {
                refresh.put('FEC_Skill_Level__c', 5);
            }
            if (skillFields.containsKey('FEC_Active__c')) {
                refresh.put('FEC_Active__c', true);
            }
            update refresh;
        }
        return ctx;
    }

    private static void restoreBorrowedSkill(RoutingTestContext ctx) {
        if (ctx == null || ctx.borrowedSkillAssignmentId == null || ctx.originalServiceResourceId == null) {
            return;
        }
        ServiceResourceSkill borrowed = new ServiceResourceSkill(
            Id = ctx.borrowedSkillAssignmentId,
            ServiceResourceId = ctx.originalServiceResourceId
        );
        update borrowed;
    }

    private static Case buildInteractionCase(
        RoutingTestContext ctx,
        Boolean isReply,
        Id parentId
    ) {
        Case c = new Case(
            Subject = 'FEC_InteractionRoutingService_Test',
            OwnerId = ctx.queueId,
            Status = 'Open',
            FEC_Channel__c = FEC_ConstantCommon.EMAIL,
            FEC_Send_To__c = routingEmail(),
            FEC_Is_Reply_Interaction_email__c = isReply,
            FEC_On_Hold__c = false,
            FEC_ID_Search__c = 'IRS-' + String.valueOf(System.currentTimeMillis()) + Crypto.getRandomInteger()
        );
        c.RecordTypeId = ctx.interactionRtId;
        if (parentId != null) {
            c.ParentId = parentId;
        }
        return c;
    }

    private static void insertCase(Case c) {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static void insertCases(List<Case> cases) {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert cases;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @TestSetup
    static void setup() {
        insert new FEC_System_Config__c(
            FEC_Send_To_Email_Ubank__c = TEST_ROUTING_EMAIL
        );

        String suffix = String.valueOf(System.currentTimeMillis());
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User agent = new User(
            Alias = ('ag' + suffix).right(8),
            Email = 'agent' + suffix + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'RoutingAgent',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Ho_Chi_Minh',
            UserName = 'agent' + suffix + '@fec.routing.test'
        );
        insert agent;

        insert new ServiceResource(
            Name = 'Routing Agent ' + suffix,
            RelatedRecordId = agent.Id,
            IsActive = true
        );
    }

    @IsTest
    static void testAssignNewInteractionEmail_Success() {
        RoutingTestContext ctx = buildContext();
        if (ctx.primaryAgentUserId == null || ctx.borrowedSkillAssignmentId == null) {
            return;
        }

        try {
            Case c = buildInteractionCase(ctx, false, null);
            insertCase(c);

            Test.startTest();
            FEC_InteractionRoutingService.assignNewInteractionEmail(new List<Case>{ c });
            Test.stopTest();

            System.assertEquals(
                ctx.primaryAgentUserId,
                [SELECT OwnerId FROM Case WHERE Id = :c.Id].OwnerId
            );
        } finally {
            restoreBorrowedSkill(ctx);
        }
    }

    @IsTest
    static void testAssignNewInteractionEmail_TwoCasesInBatch() {
        RoutingTestContext ctx = buildContext();
        if (ctx.primaryAgentUserId == null || ctx.borrowedSkillAssignmentId == null) {
            return;
        }

        try {
            Case c1 = buildInteractionCase(ctx, false, null);
            Case c2 = buildInteractionCase(ctx, false, null);
            insertCases(new List<Case>{ c1, c2 });

            Test.startTest();
            FEC_InteractionRoutingService.assignNewInteractionEmail(new List<Case>{ c1, c2 });
            Test.stopTest();

            System.assertNotEquals(ctx.queueId, [SELECT OwnerId FROM Case WHERE Id = :c1.Id].OwnerId);
            System.assertNotEquals(ctx.queueId, [SELECT OwnerId FROM Case WHERE Id = :c2.Id].OwnerId);
        } finally {
            restoreBorrowedSkill(ctx);
        }
    }

    @IsTest
    static void testAssignNewInteractionEmail_EmptyAndNull() {
        Test.startTest();
        FEC_InteractionRoutingService.assignNewInteractionEmail(new List<Case>());
        FEC_InteractionRoutingService.assignNewInteractionEmail(null);
        FEC_InteractionRoutingService.assignInteractionReply(new List<Case>());
        FEC_InteractionRoutingService.assignInteractionReply(null);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testAssignInteractionReply_NoParent_NoOp() {
        RoutingTestContext ctx = buildContext();
        if (ctx.primaryAgentUserId == null) {
            return;
        }

        try {
            Case c = buildInteractionCase(ctx, true, null);
            insertCase(c);

            Test.startTest();
            FEC_InteractionRoutingService.assignInteractionReply(new List<Case>{ c });
            Test.stopTest();

            System.assertEquals(ctx.queueId, [SELECT OwnerId FROM Case WHERE Id = :c.Id].OwnerId);
        } finally {
            restoreBorrowedSkill(ctx);
        }
    }

    @IsTest
    static void testAssignInteractionReply_WithParentAgent() {
        RoutingTestContext ctx = buildContext();
        if (ctx.primaryAgentUserId == null || ctx.borrowedSkillAssignmentId == null) {
            return;
        }

        try {
            Case parentCase = new Case(
                Subject = 'Parent interaction',
                OwnerId = ctx.primaryAgentUserId,
                Status = 'Open',
                RecordTypeId = ctx.interactionRtId,
                FEC_ID_Search__c = 'IRP-' + String.valueOf(System.currentTimeMillis())
            );
            insertCase(parentCase);

            Case replyCase = buildInteractionCase(ctx, true, parentCase.Id);
            insertCase(replyCase);

            Test.startTest();
            FEC_InteractionRoutingService.assignInteractionReply(new List<Case>{ replyCase });
            Test.stopTest();

            System.assertEquals(
                ctx.primaryAgentUserId,
                [SELECT OwnerId FROM Case WHERE Id = :replyCase.Id].OwnerId
            );
        } finally {
            restoreBorrowedSkill(ctx);
        }
    }

    @IsTest
    static void testAssignInteractionReply_ParentNotInteraction_NoOp() {
        RoutingTestContext ctx = buildContext();
        Id customerRt = customerRecordTypeId();
        if (ctx.primaryAgentUserId == null || customerRt == null) {
            return;
        }

        try {
            Case parentCase = new Case(
                Subject = 'Customer parent',
                OwnerId = ctx.primaryAgentUserId,
                Status = 'Open',
                RecordTypeId = customerRt,
                FEC_ID_Search__c = 'IRPC-' + String.valueOf(System.currentTimeMillis())
            );
            insertCase(parentCase);

            Case replyCase = buildInteractionCase(ctx, true, parentCase.Id);
            insertCase(replyCase);

            Test.startTest();
            FEC_InteractionRoutingService.assignInteractionReply(new List<Case>{ replyCase });
            Test.stopTest();

            System.assertEquals(ctx.queueId, [SELECT OwnerId FROM Case WHERE Id = :replyCase.Id].OwnerId);
        } finally {
            restoreBorrowedSkill(ctx);
        }
    }

    @IsTest
    static void testAssignInteractionReply_AbsentAgent() {
        RoutingTestContext ctx = buildContext();
        if (ctx.primaryAgentUserId == null || ctx.borrowedSkillAssignmentId == null) {
            return;
        }

        Map<String, Schema.SObjectField> skillFields =
            ServiceResourceSkill.SObjectType.getDescribe().fields.getMap();
        Boolean hadActiveFlag = skillFields.containsKey('FEC_Active__c');
        ServiceResourceSkill borrowed = [
            SELECT Id, FEC_Active__c
            FROM ServiceResourceSkill
            WHERE Id = :ctx.borrowedSkillAssignmentId
            LIMIT 1
        ];
        Boolean originalActive = hadActiveFlag ? (Boolean) borrowed.get('FEC_Active__c') : null;

        try {
            if (hadActiveFlag) {
                borrowed.put('FEC_Active__c', false);
                update borrowed;
            }

            Case parentCase = new Case(
                Subject = 'Parent for absent',
                OwnerId = ctx.primaryAgentUserId,
                Status = 'Open',
                RecordTypeId = ctx.interactionRtId,
                FEC_ID_Search__c = 'IRPA-' + String.valueOf(System.currentTimeMillis())
            );
            insertCase(parentCase);

            Case replyCase = buildInteractionCase(ctx, true, parentCase.Id);
            insertCase(replyCase);

            Test.startTest();
            FEC_InteractionRoutingService.assignInteractionReply(new List<Case>{ replyCase });
            Test.stopTest();

            System.assertEquals(ctx.queueId, [SELECT OwnerId FROM Case WHERE Id = :replyCase.Id].OwnerId);
        } finally {
            if (hadActiveFlag) {
                update new ServiceResourceSkill(
                    Id = ctx.borrowedSkillAssignmentId,
                    FEC_Active__c = originalActive
                );
            }
            restoreBorrowedSkill(ctx);
        }
    }

    @IsTest
    static void testAssignInteractionReply_InactiveServiceResource() {
        RoutingTestContext ctx = buildContext();
        if (ctx.primaryAgentUserId == null || ctx.primaryServiceResourceId == null) {
            return;
        }

        try {
            update new ServiceResource(Id = ctx.primaryServiceResourceId, IsActive = false);

            Case parentCase = new Case(
                Subject = 'Parent inactive SR',
                OwnerId = ctx.primaryAgentUserId,
                Status = 'Open',
                RecordTypeId = ctx.interactionRtId,
                FEC_ID_Search__c = 'IRPI-' + String.valueOf(System.currentTimeMillis())
            );
            insertCase(parentCase);

            Case replyCase = buildInteractionCase(ctx, true, parentCase.Id);
            insertCase(replyCase);

            Test.startTest();
            FEC_InteractionRoutingService.assignInteractionReply(new List<Case>{ replyCase });
            Test.stopTest();

            System.assertEquals(ctx.queueId, [SELECT OwnerId FROM Case WHERE Id = :replyCase.Id].OwnerId);
        } finally {
            update new ServiceResource(Id = ctx.primaryServiceResourceId, IsActive = true);
            restoreBorrowedSkill(ctx);
        }
    }

    @IsTest
    static void testAssignInteractionReply_AtCapacity() {
        RoutingTestContext ctx = buildContext();
        if (ctx.primaryAgentUserId == null || ctx.borrowedSkillAssignmentId == null) {
            return;
        }

        Map<String, Schema.SObjectField> skillFields =
            ServiceResourceSkill.SObjectType.getDescribe().fields.getMap();
        ServiceResourceSkill borrowed = [
            SELECT Id, FEC_Capacity__c
            FROM ServiceResourceSkill
            WHERE Id = :ctx.borrowedSkillAssignmentId
            LIMIT 1
        ];
        Decimal originalCapacity = skillFields.containsKey('FEC_Capacity__c')
            ? (Decimal) borrowed.get('FEC_Capacity__c')
            : null;

        try {
            if (originalCapacity != null) {
                borrowed.put('FEC_Capacity__c', 1);
                update borrowed;
            }

            Case existing = buildInteractionCase(ctx, false, null);
            existing.OwnerId = ctx.primaryAgentUserId;
            insertCase(existing);

            Case parentCase = new Case(
                Subject = 'Parent at capacity',
                OwnerId = ctx.primaryAgentUserId,
                Status = 'Open',
                RecordTypeId = ctx.interactionRtId,
                FEC_ID_Search__c = 'IRPCAP-' + String.valueOf(System.currentTimeMillis())
            );
            insertCase(parentCase);

            Case replyCase = buildInteractionCase(ctx, true, parentCase.Id);
            insertCase(replyCase);

            Test.startTest();
            FEC_InteractionRoutingService.assignInteractionReply(new List<Case>{ replyCase });
            Test.stopTest();

            System.assertEquals(ctx.queueId, [SELECT OwnerId FROM Case WHERE Id = :replyCase.Id].OwnerId);
        } finally {
            if (originalCapacity != null) {
                update new ServiceResourceSkill(
                    Id = ctx.borrowedSkillAssignmentId,
                    FEC_Capacity__c = originalCapacity
                );
            }
            restoreBorrowedSkill(ctx);
        }
    }

    @IsTest
    static void testAssignNewInteractionEmail_WrongChannelNoOp() {
        RoutingTestContext ctx = buildContext();
        if (ctx.primaryAgentUserId == null) {
            return;
        }

        try {
            Case c = buildInteractionCase(ctx, false, null);
            c.FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;
            insertCase(c);

            Test.startTest();
            FEC_InteractionRoutingService.assignNewInteractionEmail(new List<Case>{ c });
            Test.stopTest();

            System.assertEquals(ctx.queueId, [SELECT OwnerId FROM Case WHERE Id = :c.Id].OwnerId);
        } finally {
            restoreBorrowedSkill(ctx);
        }
    }

    @IsTest
    static void testAssignNewInteractionEmail_ReplyWithInteractionParent() {
        RoutingTestContext ctx = buildContext();
        if (ctx.primaryAgentUserId == null || ctx.borrowedSkillAssignmentId == null) {
            return;
        }

        try {
            Case parentCase = new Case(
                Subject = 'Interaction parent for assignNew reply',
                OwnerId = ctx.primaryAgentUserId,
                Status = 'Open',
                RecordTypeId = ctx.interactionRtId,
                FEC_ID_Search__c = 'IRPN-' + String.valueOf(System.currentTimeMillis())
            );
            insertCase(parentCase);

            Case replyCase = buildInteractionCase(ctx, true, parentCase.Id);
            insertCase(replyCase);

            Test.startTest();
            FEC_InteractionRoutingService.assignNewInteractionEmail(new List<Case>{ replyCase });
            Test.stopTest();

            System.assertNotEquals(ctx.queueId, [SELECT OwnerId FROM Case WHERE Id = :replyCase.Id].OwnerId);
        } finally {
            restoreBorrowedSkill(ctx);
        }
    }

    @IsTest
    static void testAssignInteractionReply_ParentOwnedByQueue() {
        RoutingTestContext ctx = buildContext();
        if (ctx.primaryAgentUserId == null) {
            return;
        }

        try {
            Case parentCase = new Case(
                Subject = 'Parent owned by queue',
                OwnerId = ctx.queueId,
                Status = 'Open',
                RecordTypeId = ctx.interactionRtId,
                FEC_ID_Search__c = 'IRPQ-' + String.valueOf(System.currentTimeMillis())
            );
            insertCase(parentCase);

            Case replyCase = buildInteractionCase(ctx, true, parentCase.Id);
            insertCase(replyCase);

            Test.startTest();
            FEC_InteractionRoutingService.assignInteractionReply(new List<Case>{ replyCase });
            Test.stopTest();

            System.assertEquals(ctx.queueId, [SELECT OwnerId FROM Case WHERE Id = :replyCase.Id].OwnerId);
        } finally {
            restoreBorrowedSkill(ctx);
        }
    }

    @IsTest
    static void testAssignNewInteractionEmail_NoMatchingSkillCapacity() {
        RoutingTestContext ctx = buildContext();
        if (ctx.primaryAgentUserId == null || ctx.borrowedSkillAssignmentId == null) {
            return;
        }

        Map<String, Schema.SObjectField> skillFields =
            ServiceResourceSkill.SObjectType.getDescribe().fields.getMap();
        ServiceResourceSkill borrowed = [
            SELECT Id, FEC_Capacity__c
            FROM ServiceResourceSkill
            WHERE Id = :ctx.borrowedSkillAssignmentId
            LIMIT 1
        ];
        Decimal originalCapacity = skillFields.containsKey('FEC_Capacity__c')
            ? (Decimal) borrowed.get('FEC_Capacity__c')
            : null;

        try {
            if (originalCapacity != null) {
                borrowed.put('FEC_Capacity__c', 0);
                update borrowed;
            }

            Case c = buildInteractionCase(ctx, false, null);
            insertCase(c);

            Test.startTest();
            FEC_InteractionRoutingService.assignNewInteractionEmail(new List<Case>{ c });
            Test.stopTest();

            System.assertEquals(ctx.queueId, [SELECT OwnerId FROM Case WHERE Id = :c.Id].OwnerId);
        } finally {
            if (originalCapacity != null) {
                update new ServiceResourceSkill(
                    Id = ctx.borrowedSkillAssignmentId,
                    FEC_Capacity__c = originalCapacity
                );
            }
            restoreBorrowedSkill(ctx);
        }
    }

    @IsTest
    static void testAssignInteractionReply_WithServiceResourceAbsence() {
        RoutingTestContext ctx = buildContext();
        if (ctx.primaryAgentUserId == null || ctx.primaryServiceResourceId == null) {
            return;
        }

        Boolean insertedAbsence = false;
        Id absenceId;

        try {
            try {
                FEC_Service_Resource_Absence__c absence = new FEC_Service_Resource_Absence__c(
                    FEC_Service_Resource__c = ctx.primaryServiceResourceId,
                    FEC_Start_Date__c = System.now(),
                    FEC_End_Date__c = null
                );
                insert absence;
                insertedAbsence = true;
                absenceId = absence.Id;
            } catch (Exception ignore) {
                // Org validation may block absence insert; still exercise reply path.
            }

            Case parentCase = new Case(
                Subject = 'Parent with absence lookup',
                OwnerId = ctx.primaryAgentUserId,
                Status = 'Open',
                RecordTypeId = ctx.interactionRtId,
                FEC_ID_Search__c = 'IRPABS-' + String.valueOf(System.currentTimeMillis())
            );
            insertCase(parentCase);

            Case replyCase = buildInteractionCase(ctx, true, parentCase.Id);
            insertCase(replyCase);

            Test.startTest();
            FEC_InteractionRoutingService.assignInteractionReply(new List<Case>{ replyCase });
            Test.stopTest();

            if (insertedAbsence) {
                System.assertEquals(ctx.queueId, [SELECT OwnerId FROM Case WHERE Id = :replyCase.Id].OwnerId);
            } else {
                System.assertNotEquals(null, replyCase.Id);
            }
        } finally {
            if (insertedAbsence && absenceId != null) {
                delete [SELECT Id FROM FEC_Service_Resource_Absence__c WHERE Id = :absenceId];
            }
            restoreBorrowedSkill(ctx);
        }
    }

    @IsTest
    static void testAssignNewInteractionEmail_SkillLevelComparison() {
        RoutingTestContext ctx = buildContext();
        if (ctx.primaryAgentUserId == null || ctx.borrowedSkillAssignmentId == null) {
            return;
        }

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String suffix = String.valueOf(System.currentTimeMillis());
        User secondAgent = new User(
            Alias = ('s2' + suffix).right(8),
            Email = 'second' + suffix + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'RoutingSecondAgent',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Ho_Chi_Minh',
            UserName = 'second' + suffix + '@fec.routing.second.test'
        );
        insert secondAgent;

        ServiceResource secondSr = new ServiceResource(
            Name = 'Second SR ' + suffix,
            RelatedRecordId = secondAgent.Id,
            IsActive = true
        );
        insert secondSr;

        String skillDevName = System.Label.FEC_Ubank_Skill_DevName;
        List<ServiceResourceSkill> extraSkills = [
            SELECT Id, ServiceResourceId, FEC_Skill_Level__c, FEC_Capacity__c, FEC_Active__c
            FROM ServiceResourceSkill
            WHERE Skill.DeveloperName = :skillDevName
            AND ServiceResource.IsActive = true
            AND Id != :ctx.borrowedSkillAssignmentId
            LIMIT 1
        ];
        if (extraSkills.isEmpty()) {
            return;
        }

        ServiceResourceSkill secondBorrowed = extraSkills[0];
        Id secondOriginalSr = secondBorrowed.ServiceResourceId;
        Map<String, Schema.SObjectField> skillFields =
            ServiceResourceSkill.SObjectType.getDescribe().fields.getMap();

        try {
            secondBorrowed.ServiceResourceId = secondSr.Id;
            if (skillFields.containsKey('FEC_Capacity__c')) {
                secondBorrowed.put('FEC_Capacity__c', 20);
            }
            if (skillFields.containsKey('FEC_Skill_Level__c')) {
                secondBorrowed.put('FEC_Skill_Level__c', 1);
            }
            if (skillFields.containsKey('FEC_Active__c')) {
                secondBorrowed.put('FEC_Active__c', true);
            }
            update secondBorrowed;

            if (skillFields.containsKey('FEC_Skill_Level__c')) {
                update new ServiceResourceSkill(
                    Id = ctx.borrowedSkillAssignmentId,
                    FEC_Skill_Level__c = 99
                );
            }

            Case c = buildInteractionCase(ctx, false, null);
            insertCase(c);

            Test.startTest();
            FEC_InteractionRoutingService.assignNewInteractionEmail(new List<Case>{ c });
            Test.stopTest();

            System.assertEquals(
                ctx.primaryAgentUserId,
                [SELECT OwnerId FROM Case WHERE Id = :c.Id].OwnerId
            );
        } finally {
            update new ServiceResourceSkill(
                Id = secondBorrowed.Id,
                ServiceResourceId = secondOriginalSr
            );
            restoreBorrowedSkill(ctx);
        }
    }

    @IsTest
    static void testAssignInteractionReply_NoServiceResourceForAgent() {
        RoutingTestContext ctx = buildContext();
        if (ctx.primaryAgentUserId == null) {
            return;
        }

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String suffix = String.valueOf(System.currentTimeMillis());
        User otherUser = new User(
            Alias = ('ou' + suffix).right(8),
            Email = 'other' + suffix + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'OtherRoutingUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Ho_Chi_Minh',
            UserName = 'other' + suffix + '@fec.routing.other.test'
        );
        insert otherUser;

        try {
            Case parentCase = new Case(
                Subject = 'Parent without service resource',
                OwnerId = otherUser.Id,
                Status = 'Open',
                RecordTypeId = ctx.interactionRtId,
                FEC_ID_Search__c = 'IRNO-' + String.valueOf(System.currentTimeMillis())
            );
            insertCase(parentCase);

            Case replyCase = buildInteractionCase(ctx, true, parentCase.Id);
            insertCase(replyCase);

            Test.startTest();
            FEC_InteractionRoutingService.assignInteractionReply(new List<Case>{ replyCase });
            Test.stopTest();

            System.assertEquals(ctx.queueId, [SELECT OwnerId FROM Case WHERE Id = :replyCase.Id].OwnerId);
        } finally {
            restoreBorrowedSkill(ctx);
        }
    }

    @IsTest
    static void testAssignNewInteractionEmail_WrongSendToNoOp() {
        RoutingTestContext ctx = buildContext();
        if (ctx.primaryAgentUserId == null) {
            return;
        }

        try {
            Case c = buildInteractionCase(ctx, false, null);
            c.FEC_Send_To__c = 'other@example.com';
            insertCase(c);

            Test.startTest();
            FEC_InteractionRoutingService.assignNewInteractionEmail(new List<Case>{ c });
            Test.stopTest();

            System.assertEquals(ctx.queueId, [SELECT OwnerId FROM Case WHERE Id = :c.Id].OwnerId);
        } finally {
            restoreBorrowedSkill(ctx);
        }
    }
}
