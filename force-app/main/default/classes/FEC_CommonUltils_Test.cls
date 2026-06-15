@IsTest
private class FEC_CommonUltils_Test {

    @TestSetup
    static void setupData() {
        insert new FEC_Channel__c(
            Name = FEC_ConstantCommon.SYSTEM_SOURCE_ICOLLECT,
            FEC_Code__c = FEC_ConstantCommon.SYSTEM_SOURCE_ICOLLECT,
            FEC_Channel_ID__c = FEC_ConstantCommon.SYSTEM_SOURCE_ICOLLECT,
            FEC_Channel_Vietnamese_name__c = FEC_ConstantCommon.SYSTEM_SOURCE_ICOLLECT,
            FEC_Channel_Status__c = true,
            FEC_Get_Nature_Of_Case__c = true
        );
    }

    @IsTest
    static void testNormalizeChannelInput_stripsQuotesAndWhitespace() {
        System.assertEquals(
            'iCollect',
            FEC_CommonUltils.normalizeChannelInput(' "iCollect" ')
        );
        System.assertEquals(null, FEC_CommonUltils.normalizeChannelInput('   '));
    }

    @IsTest
    static void testIsNatureOfCaseChannelAllowed_commaDelimitedTokens() {
        FEC_CommonUltils.resetActiveChannelCacheForTest();
        String stored = 'CSM,Vymo,iCollect,FEMobile';
        System.assertEquals(true, FEC_CommonUltils.isNatureOfCaseChannelAllowed(stored, 'iCollect'));
        System.assertEquals(true, FEC_CommonUltils.isNatureOfCaseChannelAllowed(null, 'iCollect'));
        System.assertEquals(false, FEC_CommonUltils.isNatureOfCaseChannelAllowed(stored, 'Unknown'));
        // Repeated calls for same request channel must reuse cached match keys (no N+1 SOQL).
        for (Integer i = 0; i < 120; i++) {
            System.assertEquals(
                true,
                FEC_CommonUltils.isNatureOfCaseChannelAllowed(stored, 'iCollect')
            );
        }
    }

    @IsTest
    static void testBuildNatureOfCaseChannelFilterClause_containsTokenMatch() {
        FEC_CommonUltils.resetActiveChannelCacheForTest();
        String clause = FEC_CommonUltils.buildNatureOfCaseChannelFilterClause(
            'FEC_Channel__c',
            FEC_ConstantCommon.SYSTEM_SOURCE_ICOLLECT
        );
        System.assert(clause.contains('FEC_Channel__c'));
        System.assert(clause.contains('OR'));
    }

    @IsTest
    static void testMapCheckExistUserCode2ToSocialStatus() {
        System.assertEquals(
            FEC_ConstantCommon.SOCIAL_STATUS_YES,
            FEC_CommonUltils.mapCheckExistUserCode2ToSocialStatus(
                FEC_ConstantCommon.CHECK_EXIST_USER_CODE_EXISTS
            )
        );
        System.assertEquals(
            FEC_ConstantCommon.SOCIAL_STATUS_NO,
            FEC_CommonUltils.mapCheckExistUserCode2ToSocialStatus(
                FEC_ConstantCommon.CHECK_EXIST_USER_CODE_NOT_EXISTS
            )
        );
        System.assertEquals(
            FEC_ConstantCommon.STR_EMPTY,
            FEC_CommonUltils.mapCheckExistUserCode2ToSocialStatus(null)
        );
    }

    @IsTest
    static void testMapCode2ToStatus() {
        System.assertEquals(
            '1',
            FEC_CommonUltils.mapCode2ToStatus(
                FEC_ConstantCommon.CHECK_EXIST_USER_CODE_EXISTS
            )
        );
        System.assertEquals(
            '2',
            FEC_CommonUltils.mapCode2ToStatus(
                FEC_ConstantCommon.CHECK_EXIST_USER_CODE_NOT_EXISTS
            )
        );
    }

    @IsTest
    static void testGetActiveChannelIds_includesActiveChannel() {
        FEC_CommonUltils.resetActiveChannelCacheForTest();
        Set<String> ids = FEC_CommonUltils.getActiveChannelIds();
        System.assert(ids.contains(FEC_ConstantCommon.SYSTEM_SOURCE_ICOLLECT.toUpperCase()));
    }

    @IsTest
    static void testIsActiveChannelSupported() {
        FEC_CommonUltils.resetActiveChannelCacheForTest();
        System.assertEquals(
            true,
            FEC_CommonUltils.isActiveChannelSupported(FEC_ConstantCommon.SYSTEM_SOURCE_ICOLLECT)
        );
        System.assertEquals(false, FEC_CommonUltils.isActiveChannelSupported('NotAChannel'));
    }

    @IsTest
    static void testFormatTransferCallRequestDateTime() {
        Datetime dt = Datetime.newInstanceGmt(2026, 5, 25, 6, 52, 33);
        String formatted = FEC_CommonUltils.formatTransferCallRequestDateTime(dt);
        System.assert(formatted.contains('20260525T065233'));
        System.assert(formatted.endsWith(' GMT'));
    }

    @IsTest
    static void testPicklistLabelFromFecNameVn() {
        System.assertEquals('Request', FEC_CommonUltils.picklistLabelFromFecNameVn(' Request '));
        System.assertEquals('', FEC_CommonUltils.picklistLabelFromFecNameVn(null));
    }

    @IsTest
    static void testSerializeSafeAndTruncateForLog() {
        Map<String, Object> payload = new Map<String, Object>{ 'Code' => '1' };
        System.assert(FEC_CommonUltils.serializeSafe(payload).contains('Code'));
        System.assertEquals(
            'abc...',
            FEC_CommonUltils.truncateForLog('abcdef', 3, '...')
        );
    }

    @IsTest
    static void testParseAmountSafe() {
        System.assertEquals(2400, FEC_CommonUltils.parseAmountSafe('2,400'));
        System.assertEquals(1234.56, FEC_CommonUltils.parseAmountSafe('1.234,56'));
        System.assertEquals(null, FEC_CommonUltils.parseAmountSafe(null));
    }

    @IsTest
    static void testUtilityHelpers_coverage() {
        System.assertEquals('', FEC_CommonUltils.defaultToEmpty((String) null));
        System.assertEquals(true, FEC_CommonUltils.isLengthValid('abc', 5));
        System.assertEquals('NGUYEN VAN A', FEC_CommonUltils.toUpperNoVietnameseAccent('Nguyễn Văn A'));
        System.assert(FEC_CommonUltils.buildDatetimeForAPI().contains('T'));
        System.assert(FEC_CommonUltils.buildUnsupportedChannelMessage('Bad').contains('Bad'));
        System.assertNotEquals(null, FEC_CommonUltils.normalizePhone('0901234567'));
        System.assertEquals('&lt;a&gt;', FEC_CommonUltils.escapeXml('<a>'));
        System.assertNotEquals(null, FEC_CommonUltils.generateTransactionUUID());
        System.assertEquals('CC/CD', FEC_CommonUltils.getNationalIdFormat('079195234035'));
        System.assertEquals(true, FEC_CommonUltils.isCccd('079195234035'));
        System.assertEquals(
            FEC_ConstantCommon.STAGE_CHANGE_TEAM_USER_GROUP_CP,
            FEC_CommonUltils.normalizeTeamUserGroupParam('CP')
        );
        System.assertEquals(2, FEC_CommonUltils.parseSearchResultNationalIds('A;B').size());
        System.assert(FEC_CommonUltils.calculateReducingEMI(1000000, 12, 0.01) > 0);
        System.assert(FEC_CommonUltils.roundUpToThousand(1501) >= 2000);
        System.assertEquals('abc123', FEC_CommonUltils.cleanNonWordCharacters('abc-123!'));
        System.assertEquals('%iCollect%', FEC_CommonUltils.buildNatureOfCaseChannelLikePattern('iCollect'));
    }
}