@IsTest
private class FEC_CreateInteractionManualHandler_Test {

    private static final String PSG_INBOUND = 'FEC_PSG_CS_CS_Inbound_Specialist';
    private static final String PSG_OUTBOUND = 'FEC_PSG_CS_CS_Outbound_Specialist';

    private static User adminUser() {
        return [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = TRUE
            LIMIT 1
        ];
    }

    private static User createStandardUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String suffix = String.valueOf(System.currentTimeMillis()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User u = new User(
            Alias = 'cimt',
            Email = 'createinteraction.test@fecredit.test.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'CreateInteractionTest',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'createinteraction.test.' + suffix + '@test.invalid'
        );
        insert u;
        return u;
    }

    private static void assignPermissionSetGroup(Id userId, String psgDeveloperName) {
        PermissionSetGroup psg = [
            SELECT Id
            FROM PermissionSetGroup
            WHERE DeveloperName = :psgDeveloperName
            LIMIT 1
        ];
        insert new PermissionSetAssignment(
            AssigneeId = userId,
            PermissionSetGroupId = psg.Id
        );
    }

    private static User findUserWithPsg(String psgDeveloperName) {
        List<PermissionSetAssignment> assignments = [
            SELECT AssigneeId
            FROM PermissionSetAssignment
            WHERE PermissionSetGroup.DeveloperName = :psgDeveloperName
            LIMIT 1
        ];
        return assignments.isEmpty() ? null : new User(Id = assignments[0].AssigneeId);
    }

    @IsTest
    static void testCreateInteractionManual_Success() {
        String channel = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;
        String subChannel = FEC_ConstantCommon.CHANNEL_INBOUND_SUBCHANNEL_NAME;

        Test.startTest();
        FEC_CreateInteractionManualHandler.CreateInteractionManualResponse response =
            FEC_CreateInteractionManualHandler.createInteractionManual(channel, subChannel);
        Test.stopTest();

        System.assertNotEquals(null, response.caseId, 'CaseId không được null.');
        System.assertNotEquals(null, response.caseNo, 'CaseNo không được null.');
        System.assertNotEquals(null, response.linkId, 'LinkId không được null.');

        Case createdCase = [
            SELECT FEC_Channel__c, FEC_Interaction_Subchannel__c, FEC_Link_ID__c
            FROM Case
            WHERE Id = :response.caseId
        ];
        System.assertEquals(channel, createdCase.FEC_Channel__c, 'Channel phải khớp với tham số truyền vào.');
        System.assertEquals(subChannel, createdCase.FEC_Interaction_Subchannel__c, 'SubChannel phải khớp với tham số truyền vào.');
        System.assertEquals(createdCase.FEC_Link_ID__c, response.linkId, 'LinkId phải khớp FEC_Link_ID__c.');
        if (String.isNotBlank(createdCase.FEC_Link_ID__c) && createdCase.FEC_Link_ID__c.contains('>')) {
            System.assertEquals(
                createdCase.FEC_Link_ID__c.substringBetween('>', '</'),
                response.caseNo,
                'CaseNo phải được parse từ LinkId.'
            );
        }
    }

    @IsTest
    static void testCreateInteractionManual_NullValues() {
        Test.startTest();
        FEC_CreateInteractionManualHandler.CreateInteractionManualResponse response =
            FEC_CreateInteractionManualHandler.createInteractionManual(null, null);
        Test.stopTest();

        System.assertNotEquals(null, response.caseId, 'Case vẫn nên được tạo ngay cả khi channel null.');
    }

    @IsTest
    static void testHasChannelPermission_BlankChannel() {
        System.assertEquals(false, FEC_CreateInteractionManualHandler.hasChannelPermission(null),
            'null channel phải trả false.');
        System.assertEquals(false, FEC_CreateInteractionManualHandler.hasChannelPermission(''),
            'blank channel phải trả false.');
        System.assertEquals(false, FEC_CreateInteractionManualHandler.hasChannelPermission('   '),
            'whitespace channel phải trả false.');
    }

    @IsTest
    static void testHasChannelPermission_NoPsgAssignment() {
        User testUser = createStandardUser();
        System.runAs(testUser) {
            System.assertEquals(false,
                FEC_CreateInteractionManualHandler.hasChannelPermission(FEC_ConstantCommon.CHANNEL_INBOUND_NAME),
                'User không có PSG phải trả false.');
        }
    }

    @IsTest
    static void testHasChannelPermission_InboundMatch() {
        User testUser = createStandardUser();
        User runAsUser = testUser;

        try {
            System.runAs(adminUser()) {
                assignPermissionSetGroup(testUser.Id, PSG_INBOUND);
            }
        } catch (DmlException ex) {
            runAsUser = findUserWithPsg(PSG_INBOUND);
            System.assertNotEquals(null, runAsUser,
                'Không gán được PSG Inbound và không tìm thấy user có PSG trong org.');
        }

        System.runAs(runAsUser) {
            System.assertEquals(true,
                FEC_CreateInteractionManualHandler.hasChannelPermission(FEC_ConstantCommon.CHANNEL_INBOUND_NAME),
                'User có PSG Inbound phải có quyền channel Inbound.');
            System.assertEquals(true,
                FEC_CreateInteractionManualHandler.hasChannelPermission('inbound'),
                'So khớp channel không phân biệt hoa thường.');
        }
    }

    @IsTest
    static void testHasChannelPermission_NoMatch() {
        User testUser = createStandardUser();
        User runAsUser = testUser;

        try {
            System.runAs(adminUser()) {
                assignPermissionSetGroup(testUser.Id, PSG_OUTBOUND);
            }
        } catch (DmlException ex) {
            runAsUser = findUserWithPsg(PSG_OUTBOUND);
            System.assertNotEquals(null, runAsUser,
                'Không gán được PSG Outbound và không tìm thấy user có PSG trong org.');
        }

        System.runAs(runAsUser) {
            System.assertEquals(false,
                FEC_CreateInteractionManualHandler.hasChannelPermission(FEC_ConstantCommon.CHANNEL_INBOUND_NAME),
                'User chỉ có PSG Outbound không được quyền channel Inbound.');
        }
    }
}
