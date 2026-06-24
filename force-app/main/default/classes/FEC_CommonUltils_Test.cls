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
        System.assertEquals(FEC_ConstantCommon.CC_CD, FEC_CommonUltils.getNationalIdFormat('079195234035'));
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

    @IsTest
    static void testValidationPhoneEmailAndAccount() {
        System.assertEquals(false, FEC_CommonUltils.isLengthValid(null, 5));
        System.assertEquals(true, FEC_CommonUltils.isMail('user.name@example.com'));
        System.assertEquals(false, FEC_CommonUltils.isMail('bad-email'));
        System.assertEquals(null, FEC_CommonUltils.normalizeEmailForField(null));
        System.assertEquals(null, FEC_CommonUltils.normalizeEmailForField('NULL'));
        System.assertEquals(null, FEC_CommonUltils.normalizeEmailForField(' null '));
        System.assertEquals(
            'user@example.com',
            FEC_CommonUltils.normalizeEmailForField('user@example.com')
        );
        System.assertEquals(true, FEC_CommonUltils.isPhone('0901234567'));
        System.assertEquals(true, FEC_CommonUltils.isPhone('84901234567'));
        System.assertEquals(false, FEC_CommonUltils.isPhone('abc'));
        System.assertEquals(false, FEC_CommonUltils.isPhone('090123'));
        System.assertEquals('84901234567', FEC_CommonUltils.normalizePhone('+84901234567'));
        System.assertEquals('84901234567', FEC_CommonUltils.normalizePhone('0901234567'));
        System.assertEquals(true, FEC_CommonUltils.isValidAccountNumber('1234567890123456'));
        System.assertEquals(false, FEC_CommonUltils.isValidAccountNumber('123'));
        System.assertEquals(true, FEC_CommonUltils.isValidDateByFormat('2026-06-04'));
        System.assertEquals(false, FEC_CommonUltils.isValidDateByFormat('2026-13-01'));
        System.assertEquals(
            true,
            FEC_CommonUltils.isCaseStatusResolved(FEC_ConstantCommon.CASE_STATUS_PREFIX_RESOLVED + ' - Done')
        );
        System.assertEquals(false, FEC_CommonUltils.isCaseStatusResolved('Open'));
    }

    @IsTest
    static void testNotificationCustomerTypeAndDefaultToEmpty() {
        System.assertEquals(
            true,
            FEC_CommonUltils.notificationCustomerTypeMatchesCase(
                FEC_ConstantCommon.CASE_ALL_REQUEST,
                'Retail'
            )
        );
        System.assertEquals(
            true,
            FEC_CommonUltils.notificationCustomerTypeMatchesCase('Retail;Corporate', 'Retail')
        );
        System.assertEquals(false, FEC_CommonUltils.notificationCustomerTypeMatchesCase(null, 'Retail'));
        System.assertEquals('', FEC_CommonUltils.defaultToEmpty((Object) null));
        System.assertEquals('abc', FEC_CommonUltils.defaultToEmpty((Object) 'abc'));
        System.assertEquals('iCollect', FEC_CommonUltils.sanitizeChannelForMessage(' "iCollect" '));
        System.assertEquals(null, FEC_CommonUltils.buildNatureOfCaseChannelLikePattern('   '));
    }

    @IsTest
    static void testTemplatePicklistAndSchemaHelpers() {
        Case c = new Case(Subject = 'Template Case', Status = 'New');
        System.assertEquals(
            'Case: Template Case',
            FEC_CommonUltils.resolveTemplate('Case: {{Subject}}', c)
        );
        System.assertEquals(
            'adhoc',
            FEC_CommonUltils.resolveTemplate(
                '{{key}}',
                c,
                new Map<String, String>{ 'key' => 'adhoc' }
            )
        );
        System.assertEquals(
            1,
            FEC_CommonUltils.extractFieldPaths(new List<String>{ 'Hello {{Subject}}' }).size()
        );
        System.assert(FEC_CommonUltils.getPicklistOptions('Case', 'status').size() > 0);
        System.assert(FEC_CommonUltils.getPicklistOptionsWithAccess('Case', 'status').size() > 0);
        System.assertEquals(0, FEC_CommonUltils.getPicklistOptionsWithAccess('', 'Status').size());
        System.assertNotEquals(null, FEC_CommonUltils.getFieldLabel('Case', 'subject'));
        System.assertEquals('Text', FEC_CommonUltils.getFieldType('Case', 'subject'));
        System.assertEquals('Picklist', FEC_CommonUltils.getFieldType('Case', 'status'));
        System.assert(FEC_CommonUltils.buildHelpTextMap(Case.SObjectType).size() >= 0);
    }

    @IsTest
    static void testXmlDateAndConversionHelpers() {
        Dom.Document doc = new Dom.Document();
        doc.load(
            '<root>' +
            '<Amount>2,400</Amount>' +
            '<Rate>55.00</Rate>' +
            '<Packed>1000000</Packed>' +
            '<BirthDate>20260604</BirthDate>' +
            '<Child>value</Child>' +
            '</root>'
        );
        Dom.XmlNode root = doc.getRootElement();

        System.assertEquals('2,400', FEC_CommonUltils.getXmlValue(root, 'Amount'));
        System.assertEquals('value', FEC_CommonUltils.getXmlValueHasNamspace(root, 'Child'));
        System.assertEquals(2400, FEC_CommonUltils.xmlValToDecimal(root, 'Amount'));
        System.assertEquals(55.00, FEC_CommonUltils.xmlPackedBaseRateToPercent(root, 'Rate'));
        System.assertEquals(10, FEC_CommonUltils.xmlPackedBaseRateToPercent(root, 'Packed'));
        System.assertEquals(Date.newInstance(2026, 6, 4), FEC_CommonUltils.xmlValToDate(root, 'BirthDate'));
        System.assertNotEquals(null, FEC_CommonUltils.findChildByName(root, 'Child'));
        System.assertEquals('value', FEC_CommonUltils.getValueSafe(root, 'Child'));
        System.assertEquals(12, FEC_CommonUltils.toInt('12'));
        System.assertEquals(Date.newInstance(2026, 6, 4), FEC_CommonUltils.toDate('2026-06-04'));
        System.assertNotEquals(null, FEC_CommonUltils.toDatetime('2026-06-04T10:00:00'));
        System.assertEquals(Date.newInstance(2026, 6, 4), FEC_CommonUltils.parseDate('20260604'));
        System.assertEquals(Date.newInstance(2026, 6, 15), FEC_CommonUltils.parseDate('2026166'));
        System.assertEquals(null, FEC_CommonUltils.parseDate('00000000'));
        System.assertNotEquals(null, FEC_CommonUltils.parseDateTime('2026-06-04T10:00:10.491Z'));
        System.assertEquals(Date.newInstance(2026, 6, 4), FEC_CommonUltils.toDateStr('04/06/2026'));
        System.assertEquals(Date.newInstance(2026, 6, 4), FEC_CommonUltils.toDateStr('20260604'));
        System.assertEquals(5, FEC_CommonUltils.toInt(5.7));
        System.assertEquals(5, FEC_CommonUltils.toIntDec(5.2));
    }

    @IsTest
    static void testMaskingFormattingAndCurrency() {
        System.assertEquals('123456****3456', FEC_CommonUltils.maskCardNumber('12345678903456'));
        System.assertEquals('0901***567', FEC_CommonUltils.maskPhone('0901234567'));
        System.assertEquals('079******035', FEC_CommonUltils.maskNationalIdOrPassport('079195234035'));
        System.assertEquals('AB****234', FEC_CommonUltils.maskNationalIdOrPassport('AB1234234'));
        System.assert(FEC_CommonUltils.formatCurrency(1000, 2).length() > 0);
        System.assertEquals('1,000.00', FEC_CommonUltils.formatCurrencyFixed(1000, 2));
        System.assertEquals('10.50', FEC_CommonUltils.formatDecimalPlainScale(10.5, 2));
        Date d = Date.newInstance(2026, 6, 4);
        System.assert(FEC_CommonUltils.formatDate(d).length() > 0);
        System.assertEquals('04/06/2026', FEC_CommonUltils.formatDateDDMMYYYY(d));
        System.assertEquals('2026-06-04', FEC_CommonUltils.formatDateYYYYMMDD(d));
        System.assertEquals('', FEC_CommonUltils.decimalToString(null));
        System.assertEquals('2026', FEC_CommonUltils.formatTimestamp(Datetime.newInstance(2026, 6, 4, 10, 0, 0), 'yyyy'));
        System.assert(FEC_CommonUltils.formatISOWithTimezone(Datetime.now()).contains('T'));
        System.assertEquals('09', FEC_CommonUltils.pad2(9));
        System.assertEquals('10', FEC_CommonUltils.pad2(10));
        System.assertNotEquals(null, FEC_CommonUltils.generateTransactionId());
        System.assertEquals('line1, line2', FEC_CommonUltils.removeTrailingComma('line1, line2,,,'));
    }

    @IsTest
    static void testCalloutEndpointAndMockCallout() {
        System.assertEquals(
            'https://api.test/esb/path',
            FEC_CommonUltils.buildCalloutEndpoint('https://api.test', '/esb/path')
        );
        System.assertEquals('https://api.test/', FEC_CommonUltils.buildCalloutEndpoint('https://api.test/', ''));

        Test.setMock(HttpCalloutMock.class, new SimpleHttpMock(200, '{"ok":true}'));
        Test.startTest();
        HttpResponse res = FEC_CommonUltils.calloutApiWithHeaders(
            'https://example.com/test',
            'GET',
            new Map<String, String>{ 'Content-Type' => 'application/json' },
            null
        );
        Test.stopTest();
        System.assertEquals(200, res.getStatusCode());
    }

    @IsTest
    static void testApiLoggingAndDeferredLogs() {
        HttpResponse okRes = new HttpResponse();
        okRes.setStatusCode(200);
        okRes.setBody('{"ok":true}');

        FEC_CommonUltils.beginDeferredApiLogging();
        System.assertEquals(true, FEC_CommonUltils.isDeferredApiLoggingActive());
        FEC_CommonUltils.logApi('TestApi', '/test', 'GET', '{}', okRes, null);
        FEC_CommonUltils.flushDeferredApiLogs();
        System.assertEquals(false, FEC_CommonUltils.isDeferredApiLoggingActive());

        FEC_ResponseLog respLog = new FEC_ResponseLog(
            'RespApi',
            '/resp',
            'POST',
            '{}',
            okRes,
            null
        );
        FEC_CommonUltils.logApiResponse(respLog);

        System.assertEquals(
            2,
            [SELECT COUNT() FROM FEC_API_Log__c WHERE Name IN ('TestApi', 'RespApi')]
        );
    }

    @IsTest
    static void testInsuranceEcomAddressAndFlags() {
        System.assertEquals('Yes', FEC_CommonUltils.normalizeInsuranceFlag('Y'));
        System.assertEquals('No', FEC_CommonUltils.normalizeInsuranceFlag('NO'));
        System.assertEquals(null, FEC_CommonUltils.normalizeInsuranceFlag('X'));
        System.assertEquals(true, FEC_CommonUltils.parseEcomActiveFlag('yes'));
        System.assertEquals(false, FEC_CommonUltils.parseEcomActiveFlag('0'));
        System.assertEquals(null, FEC_CommonUltils.parseEcomActiveFlag(null));
        System.assertEquals('Inactive', FEC_CommonUltils.checkEcomFlag(true));
        System.assertEquals('Active', FEC_CommonUltils.checkEcomFlag(false));
        System.assertEquals('Active', FEC_CommonUltils.checkActiveAndInacive('N'));
        System.assertEquals('Inactive', FEC_CommonUltils.checkActiveAndInacive('Y'));
        System.assert(
            FEC_CommonUltils.formatAddress('Tower', '10', 'Main', 'Ward', 'Dist', 'City', 'VN', '70000')
                .contains('Tower')
        );
        System.assertEquals(true, FEC_CommonUltils.checkLength('Field', 'abc', 5));
        System.assertEquals(false, FEC_CommonUltils.checkLength('Field', 'abcdef', 5));
        System.assertEquals('<xml>ok</xml>', FEC_CommonUltils.cleanResponseBody('  <xml>ok</xml>'));
    }

    @IsTest
    static void testEmailScheduleAndLanguageHelpers() {
        System.assertEquals(2, FEC_CommonUltils.parseReceivers('a@x.com,b@y.com').size());
        Messaging.SingleEmailMessage mail = FEC_CommonUltils.buildEmail(
            new List<String>{ 'test@example.com' },
            'Subject',
            '<p>Body</p>'
        );
        System.assertEquals('Subject', mail.getSubject());
        Messaging.SingleEmailMessage mailWithSender = FEC_CommonUltils.buildEmailWithSender(
            new List<String>{ 'test@example.com' },
            'Subject',
            'Body',
            null
        );
        System.assertNotEquals(null, mailWithSender);
        FEC_CommonUltils.sendEmail(new List<String>{ 'test@example.com' }, 'Hi', 'Body');
        FEC_CommonUltils.getOrgWideEmailIdForNotification();
        FEC_CommonUltils.sendEmails(new List<Messaging.SingleEmailMessage>());
        System.assertEquals(true, FEC_CommonUltils.isWithinSchedule(Time.newInstance(10, 0, 0, 0), null, null));
        System.assertEquals(
            true,
            FEC_CommonUltils.isWithinSchedule(
                Time.newInstance(10, 0, 0, 0),
                Time.newInstance(8, 0, 0, 0),
                Time.newInstance(18, 0, 0, 0)
            )
        );
        System.assertNotEquals(null, FEC_CommonUltils.getCurrentLocalTime());
        System.assertEquals('VN Name', FEC_CommonUltils.pickNameByLanguage('EN', 'VN Name', 'VN'));
        System.assertEquals('EN', FEC_CommonUltils.pickNameByLanguage('EN', 'VN Name', 'en'));
        System.assertEquals('user', FEC_CommonUltils.getEmailPrefix('user@example.com'));
        System.assertEquals('ALL', FEC_CommonUltils.mergeApplyTo('old', 'new'));
        System.assertEquals('same', FEC_CommonUltils.mergeApplyTo('same', 'same'));
        System.assertNotEquals(null, FEC_CommonUltils.getCurrentUserProfileName());
    }

    @IsTest
    static void testNationalIdContractCardAndTeamHelpers() {
        System.assertEquals(FEC_ConstantCommon.CM_ND, FEC_CommonUltils.getNationalIdFormat('123456789'));
        System.assertEquals(FEC_ConstantCommon.PASS_PORT, FEC_CommonUltils.getNationalIdFormat('A1234567'));
        System.assertEquals(FEC_ConstantCommon.TEAM_OTHER, FEC_CommonUltils.getNationalIdFormat('XYZ'));
        System.assertEquals(FEC_ConstantCommon.TEAM_OTHER, FEC_CommonUltils.getNationalIdFormat(null));
        System.assertNotEquals(null, FEC_CommonUltils.mapApiContractStatusToPicklist('ACTIVE'));
        System.assertNotEquals(null, FEC_CommonUltils.parseDateTime(Datetime.now()));
        System.assertEquals(
            FEC_ConstantCommon.STATUS_EXPIRED,
            FEC_CommonUltils.deriveInsuranceStatus(Date.today().addDays(30), Date.today())
        );
        System.assertEquals(
            FEC_ConstantCommon.STATUS_ACTIVE,
            FEC_CommonUltils.deriveInsuranceStatus(Date.today().addDays(30), null)
        );
        System.assertEquals('Digital', FEC_CommonUltils.resolveCardType('2', null));
        System.assertEquals('Physical', FEC_CommonUltils.resolveCardType('0', null));
        System.assertEquals('Digital', FEC_CommonUltils.resolveCardType(null, 'VC1'));
        System.assertEquals('Other', FEC_CommonUltils.resolveCardType('9', 'XX1'));
        System.assertEquals('A_B', FEC_CommonUltils.sortTeamField('B_A'));
        System.assertEquals(
            FEC_ConstantCommon.STAGE_CHANGE_TEAM_USER_GROUP_PM,
            FEC_CommonUltils.normalizeTeamUserGroupParam('PM')
        );
        System.assertEquals(
            FEC_ConstantCommon.STAGE_CHANGE_TEAM_USER_GROUP_SP,
            FEC_CommonUltils.normalizeTeamUserGroupParam('CS SUPPORT')
        );
        System.assertEquals(
            'CONTRACT-1',
            FEC_CommonUltils.resolveAccountNumber(
                FEC_ConstantCommon.PRODUCT_TYPE_LOAN_CASE,
                'ACC-1',
                'CONTRACT-1'
            )
        );
        System.assertEquals('ACC-1', FEC_CommonUltils.resolveAccountNumber('Card', 'ACC-1', 'CONTRACT-1'));
        System.assertEquals('', FEC_CommonUltils.mapCode2ToStatus(99));
        System.assertEquals(0, FEC_CommonUltils.calculateReducingEMI(null, 12, 0.01));
        System.assertEquals(100, FEC_CommonUltils.calculateReducingEMI(1200, 12, 0));
        System.assertEquals(1234.56, FEC_CommonUltils.parseDecimal('1234.56'));
        System.assertEquals(100, FEC_CommonUltils.parseDecimal(100));
    }

    @IsTest
    static void testLogExceptionAndXmlNode() {
        Dom.Document doc = new Dom.Document();
        Dom.XmlNode root = doc.createRootElement('Root', null, null);
        FEC_CommonUltils.addTextNodeSafe(root, 'Name', 'Test');

        FEC_CommonUltils.logException('author', 'func', 'error', 'stack');
        System.assertEquals(1, [SELECT COUNT() FROM FEC_Log__c WHERE FEC_Function_Name__c = 'func']);
    }

    @IsTest
    static void testExtraCoverageHelpers() {
        System.assertEquals('&amp;&lt;&gt;&quot;&apos;', FEC_CommonUltils.escapeXml('&<>"\''));
        System.assertEquals(null, FEC_CommonUltils.getRecordTypeIdByDev('NonExistentRecordTypeDevName'));
        System.assertEquals(null, FEC_CommonUltils.getFieldType('FakeObject__x', 'field'));
        System.assertEquals(null, FEC_CommonUltils.getFieldLabel('FakeObject__x', 'field'));
        System.assertEquals(null, FEC_CommonUltils.parseAmountSafe('not-a-number'));
        System.assertEquals(null, FEC_CommonUltils.truncateForLog(null, 3, '...'));
        System.assertEquals('abcdef', FEC_CommonUltils.truncateForLog('abcdef', 10, '...'));

        Dom.Document soapDoc = new Dom.Document();
        Dom.XmlNode env = soapDoc.createRootElement('Envelope', 'http://schemas.xmlsoap.org/soap/envelope/', 'soap');
        env.addChildElement('Body', 'http://schemas.xmlsoap.org/soap/envelope/', 'soap');

        Test.setMock(HttpCalloutMock.class, new SimpleHttpMock(200, '<ok/>'));
        Test.startTest();
        HttpResponse soapRes = FEC_CommonUltils.calloutApi(
            'https://example.com/soap',
            'POST',
            'text/xml',
            'action',
            soapDoc,
            null
        );
        FEC_CommonUltils.calloutApi(
            'https://example.com/body',
            'POST',
            'application/json',
            null,
            null,
            '{"a":1}'
        );
        Test.stopTest();
        System.assertEquals(200, soapRes.getStatusCode());

        Case c = new Case(Subject = 'Sensitive');
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        FEC_CommonUltils.logSensitiveAccess('Section', 'Name', 'User', 'Role', c.Id);
        System.assertEquals(1, [SELECT COUNT() FROM FEC_Sensitive_Data__c WHERE FEC_Related_Case__c = :c.Id]);
    }

    private class SimpleHttpMock implements HttpCalloutMock {
        Integer code;
        String body;
        SimpleHttpMock(Integer code, String body) {
            this.code = code;
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setBody(body);
            return res;
        }
    }
}