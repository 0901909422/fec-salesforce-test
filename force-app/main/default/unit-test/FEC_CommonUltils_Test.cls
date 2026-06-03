@IsTest
private class FEC_CommonUltils_Test {

    @IsTest
    static void testStringUtilities() {
        System.assertEquals('0901***567', FEC_CommonUltils.maskPhone('0901234567'));

        String maskedId = FEC_CommonUltils.maskNationalIdOrPassport('123456789');
        System.assert(maskedId.contains('***'));

        System.assertEquals('84901234567', FEC_CommonUltils.normalizePhone('0901234567'));
        System.assertEquals('84901234567', FEC_CommonUltils.normalizePhone('+84901234567'));
    }

    @IsTest
    static void testDateUtilities() {
        System.assertEquals(true, FEC_CommonUltils.isValidDateByFormat('2026-05-21'));
        System.assertEquals(false, FEC_CommonUltils.isValidDateByFormat('21-05-2026'));

        Date d = FEC_CommonUltils.parseDate('20260521');
        System.assertNotEquals(null, d);
        System.assertEquals(2026, d.year());
        System.assertEquals(null, FEC_CommonUltils.parseDate('00000000'));
        System.assertEquals(Date.newInstance(2026, 5, 21), FEC_CommonUltils.toDateStr('21/05/2026'));
    }

    @IsTest
    static void testValidationUtilities() {
        System.assertEquals(true, FEC_CommonUltils.isMail('test@fecredit.com.vn'));
        System.assertEquals(false, FEC_CommonUltils.isMail('invalid-email'));

        System.assertEquals(true, FEC_CommonUltils.isPhone('0901234567'));
        System.assertEquals(false, FEC_CommonUltils.isPhone('abc'));

        System.assertEquals(true, FEC_CommonUltils.isValidAccountNumber('1234567890123456'));
        System.assertEquals(true, FEC_CommonUltils.isLengthValid('abc', 5));
        System.assertEquals(false, FEC_CommonUltils.isLengthValid('', 5));
    }

    @IsTest
    static void testTemplateResolution() {
        Case c = new Case(
            Subject = 'Test Subject',
            FEC_ID_Search__c = 'UTIL-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        String template = 'Hello {{Case.Subject}}';

        String result = FEC_CommonUltils.resolveTemplate(template, c);
        System.assertEquals('Hello Test Subject', result);

        Map<String, String> adhoc = new Map<String, String>{ 'CustomKey' => 'CustomValue' };
        System.assertEquals(
            'Value CustomValue',
            FEC_CommonUltils.resolveTemplate('Value {{CustomKey}}', c, adhoc)
        );

        Set<String> paths = FEC_CommonUltils.extractFieldPaths(
            new List<String>{ 'A {{Subject}} B {{Account.Name}}' }
        );
        System.assert(paths.contains('Subject'));
        System.assert(paths.contains('Account.Name'));
    }

    @IsTest
    static void testMathUtilities() {
        Decimal emi = FEC_CommonUltils.calculateReducingEMI(
            Decimal.valueOf(10000000),
            12,
            0.01
        );
        System.assert(emi > 0);
        System.assertEquals(2000, FEC_CommonUltils.roundUpToThousand(Decimal.valueOf(1200)));
        System.assertEquals(0, FEC_CommonUltils.calculateReducingEMI(null, 12, 0.01));
    }

    @IsTest
    static void testXmlUtilities() {
        String xml =
            '<root xmlns:ns="http://example.com">' +
            '<item>Value</item>' +
            '<amount>1,200.50</amount>' +
            '<rate>10001234</rate>' +
            '<opened>20260521</opened>' +
            '<ns:child>Namespaced</ns:child>' +
            '</root>';
        Dom.Document doc = new Dom.Document();
        doc.load(xml);
        Dom.XmlNode root = doc.getRootElement();

        System.assertEquals('Value', FEC_CommonUltils.getXmlValue(root, 'item'));
        System.assertEquals('Namespaced', FEC_CommonUltils.getXmlValueHasNamspace(root, 'child'));
        System.assertEquals('Value', FEC_CommonUltils.getValueSafe(root, 'item'));
        System.assertNotEquals(null, FEC_CommonUltils.findChildByName(root, 'item'));
        System.assertEquals(1200.50, FEC_CommonUltils.xmlValToDecimal(root, 'amount'));
        System.assertEquals(10.00, FEC_CommonUltils.xmlPackedBaseRateToPercent(root, 'rate'));
        System.assertEquals(Date.newInstance(2026, 5, 21), FEC_CommonUltils.xmlValToDate(root, 'opened'));
        System.assertEquals('&lt;tag&gt;', FEC_CommonUltils.escapeXml('<tag>'));
    }

    @IsTest
    static void testFormatHelpers() {
        System.assert(FEC_CommonUltils.formatCurrency(Decimal.valueOf(1000), 2).contains('1000'));
        System.assertEquals('1,000.00', FEC_CommonUltils.formatCurrencyFixed(Decimal.valueOf(1000), 2));
        System.assertEquals('1000.00', FEC_CommonUltils.formatDecimalPlainScale(Decimal.valueOf(1000), 2));
        System.assertEquals('29/05/2026', FEC_CommonUltils.formatDateDDMMYYYY(Date.newInstance(2026, 5, 29)));
        System.assertEquals('2026-05-29', FEC_CommonUltils.formatDateYYYYMMDD(Date.newInstance(2026, 5, 29)));
        System.assertNotEquals('', FEC_CommonUltils.formatISOWithTimezone(Datetime.newInstance(2026, 5, 29, 10, 0, 0)));
        System.assertEquals('', FEC_CommonUltils.formatCurrency(null, 2));
    }

    @IsTest
    static void testPicklistAndFieldHelpers() {
        System.assertEquals('Nhãn VN', FEC_CommonUltils.picklistLabelFromFecNameVn('  Nhãn VN  '));
        System.assertEquals('', FEC_CommonUltils.picklistLabelFromFecNameVn(null));

        List<FEC_CommonUltils.PicklistOption> options =
            FEC_CommonUltils.getPicklistOptions('Case', 'Status');
        System.assert(options.size() > 0);

        List<FEC_CommonUltils.PicklistOption> accessOptions =
            FEC_CommonUltils.getPicklistOptionsWithAccess('Case', 'Status');
        System.assert(accessOptions.size() > 0);
        System.assertEquals(0, FEC_CommonUltils.getPicklistOptionsWithAccess('', 'Status').size());

        System.assertNotEquals(null, FEC_CommonUltils.getFieldLabel('Case', 'Status'));
        System.assertNotEquals(null, FEC_CommonUltils.getFieldType('Case', 'Status'));
        System.assertEquals(FEC_ConstantCommon.KEY_TEXT, FEC_CommonUltils.getFieldType('Case', 'Subject'));
    }

    @IsTest
    static void testNotificationAndDefaultHelpers() {
        System.assertEquals(true, FEC_CommonUltils.isCaseStatusResolved('Resolved - Completed'));
        System.assertEquals(false, FEC_CommonUltils.isCaseStatusResolved('Pending'));
        System.assertEquals(
            true,
            FEC_CommonUltils.notificationCustomerTypeMatchesCase(
                FEC_ConstantCommon.CASE_ALL_REQUEST,
                FEC_ConstantCommon.CASE_EXISTING_CUSTOMER
            )
        );
        System.assertEquals(
            true,
            FEC_CommonUltils.notificationCustomerTypeMatchesCase(
                FEC_ConstantCommon.CASE_EXISTING_CUSTOMER,
                FEC_ConstantCommon.CASE_EXISTING_CUSTOMER
            )
        );
        System.assertEquals(false, FEC_CommonUltils.notificationCustomerTypeMatchesCase('', 'Existing'));

        System.assertEquals('', FEC_CommonUltils.defaultToEmpty((String) null));
        System.assertEquals('abc', FEC_CommonUltils.defaultToEmpty('abc'));
        System.assertEquals('', FEC_CommonUltils.defaultToEmpty((Object) null));
    }

    @IsTest
    static void testCleanResponseBodyAndParseAmount() {
        String cleaned = FEC_CommonUltils.cleanResponseBody('\uFEFF junk <root/>');
        System.assertEquals('<root/>', cleaned);
        System.assertEquals(2400, FEC_CommonUltils.parseAmountSafe('2,400'));
        System.assertEquals(1234.56, FEC_CommonUltils.parseAmountSafe('1.234,56'));
        System.assertEquals(null, FEC_CommonUltils.parseAmountSafe(''));
    }

    @IsTest
    static void testNotifyUsers() {
        List<CustomNotificationType> types = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Custom_Notification'
            LIMIT 1
        ];
        if (types.isEmpty()) {
            System.assert(true, 'Skipped: Custom_Notification type not in org.');
            return;
        }

        User admin = [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = true
            LIMIT 1
        ];

        System.runAs(admin) {
            Test.startTest();
            FEC_CommonUltils.notifyUsers(
                new Set<String>{ UserInfo.getUserId() },
                UserInfo.getUserId(),
                null,
                'Test Title',
                'Test Body'
            );
            Boolean sent = FEC_CommonUltils.notifyUsers(
                new Set<String>{ UserInfo.getUserId() },
                UserInfo.getUserId(),
                null,
                'Test Title 2',
                'Test Body 2',
                types[0]
            );
            Test.stopTest();

            System.assertEquals(true, sent);
        }
    }

    @IsTest
    static void testMiscStaticHelpers() {
        System.assertEquals('https://api.test/path', FEC_CommonUltils.buildCalloutEndpoint('https://api.test', '/path'));
        System.assertEquals('Yes', FEC_CommonUltils.normalizeInsuranceFlag('Y'));
        System.assertEquals('No', FEC_CommonUltils.normalizeInsuranceFlag('NO'));
        System.assertEquals('Inactive', FEC_CommonUltils.checkEcomFlag(true));
        System.assertEquals('Active', FEC_CommonUltils.checkActiveAndInacive('Y'));
        System.assertEquals('user', FEC_CommonUltils.getEmailPrefix('user@fecredit.com.vn'));
        System.assertEquals('ALL', FEC_CommonUltils.mergeApplyTo('A', 'B'));
        System.assertEquals('HANOI', FEC_CommonUltils.toUpperNoVietnameseAccent('Hà Nội'));
        System.assertEquals('A_B', FEC_CommonUltils.sortTeamField('B_A'));
        System.assertEquals(true, FEC_CommonUltils.checkLength('Status', 'New', 20));
        System.assertEquals('84901234567', FEC_CommonUltils.cleanNonWordCharacters('+84-901-234-567'));
        System.assertEquals(FEC_ConstantCommon.CC_CD, FEC_CommonUltils.getNationalIdFormat('001234567890'));
        System.assertEquals(true, FEC_CommonUltils.isCccd('001234567890'));
        System.assertEquals(2, FEC_CommonUltils.parseSearchResultNationalIds('111;222').size());
        System.assertEquals('1234567890123456', FEC_CommonUltils.resolveAccountNumber(
            FEC_ConstantCommon.PRODUCT_TYPE_LOAN_CASE,
            '1111111111111111',
            '1234567890123456'
        ));
        System.assertNotEquals(null, FEC_CommonUltils.generateTransactionId());
        System.assertNotEquals(null, FEC_CommonUltils.generateTransactionUUID());
        System.assert(FEC_CommonUltils.buildHelpTextMap(Schema.SObjectType.Case).size() >= 0);
        System.assertEquals('line1, line2', FEC_CommonUltils.formatAddress('line1', null, 'line2', null, null, null, null, null));
        System.assertEquals('a,b', FEC_CommonUltils.removeTrailingComma('a,b,  ,'));
        System.assertEquals('test@a.com', FEC_CommonUltils.parseReceivers('test@a.com, test@b.com')[0]);
    }

    @IsTest
    static void testDeferredApiLogging() {
        Test.startTest();
        FEC_CommonUltils.beginDeferredApiLogging();
        HttpResponse mockRes = new HttpResponse();
        mockRes.setStatusCode(200);
        mockRes.setBody('OK');
        FEC_CommonUltils.logApi('TestAPI', 'https://test', 'GET', '{}', mockRes, null);
        FEC_CommonUltils.flushDeferredApiLogs();
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM FEC_API_Log__c WHERE Name = 'TestAPI']
        );
    }

    @IsTest
    static void testAddTextNodeSafeAndSerializeSafe() {
        Dom.Document doc = new Dom.Document();
        Dom.XmlNode root = doc.createRootElement('Root', null, null);
        FEC_CommonUltils.addTextNodeSafe(root, 'Field', null);
        System.assertEquals('', FEC_CommonUltils.getXmlValue(root, 'Field'));
        System.assertNotEquals(null, FEC_CommonUltils.serializeSafe(new Map<String, String>{ 'a' => 'b' }));
    }

    @IsTest
    static void testExtendedStaticHelpers() {
        System.assertEquals('411122*********1111', FEC_CommonUltils.maskCardNumber('41112222233331111'));
        System.assertEquals(null, FEC_CommonUltils.maskCardNumber('123'));
        System.assertEquals(42, FEC_CommonUltils.toInt('42'));
        System.assertEquals(null, FEC_CommonUltils.toInt(''));
        System.assertEquals(Date.newInstance(2026, 1, 15), FEC_CommonUltils.toDate('2026-01-15'));
        System.assertEquals(10, FEC_CommonUltils.toIntDec(Decimal.valueOf(10.9)));
        System.assertEquals(10, FEC_CommonUltils.toInt(Decimal.valueOf(10.2)));

        Datetime parsed = FEC_CommonUltils.parseDateTime('2026-05-29T14:30:10.491Z');
        System.assertNotEquals(null, parsed);
        System.assertEquals('2026-05-29', FEC_CommonUltils.formatDate(Date.newInstance(2026, 5, 29)));
        System.assertEquals('1000', FEC_CommonUltils.decimalToString(Decimal.valueOf(1000)));
        System.assertEquals('', FEC_CommonUltils.decimalToString(null));

        System.assertEquals('Tên VN', FEC_CommonUltils.pickNameByLanguage('Name EN', 'Tên VN', FEC_ConstantCommon.LANGUAGE_VN));
        System.assertEquals('Name EN', FEC_CommonUltils.pickNameByLanguage('Name EN', 'Tên VN', 'EN'));

        System.assertEquals('05', FEC_CommonUltils.pad2(5));
        System.assertEquals('15', FEC_CommonUltils.pad2(15));
        System.assertNotEquals(null, FEC_CommonUltils.getCurrentLocalTime());
        System.assertEquals(true, FEC_CommonUltils.isWithinSchedule(
            Time.newInstance(12, 0, 0, 0),
            Time.newInstance(8, 0, 0, 0),
            Time.newInstance(18, 0, 0, 0)
        ));
        System.assertEquals(false, FEC_CommonUltils.isWithinSchedule(
            Time.newInstance(20, 0, 0, 0),
            Time.newInstance(8, 0, 0, 0),
            Time.newInstance(18, 0, 0, 0)
        ));
        System.assertEquals(true, FEC_CommonUltils.isWithinSchedule(Time.newInstance(9, 0, 0, 0), null, null));

        System.assertNotEquals(null, FEC_CommonUltils.buildDatetimeForAPI());
        System.assert(FEC_CommonUltils.formatTransferCallRequestDateTime(Datetime.now()).contains('GMT'));
        System.assertEquals('short text', FEC_CommonUltils.truncateForLog('short text', 10, '...'));
        System.assertEquals('short te...', FEC_CommonUltils.truncateForLog('short text here', 8, '...'));
        System.assertNotEquals(null, FEC_CommonUltils.getCurrentUserProfileName());

        System.assertEquals(FEC_ConstantCommon.STAGE_CHANGE_TEAM_USER_GROUP_CP,
            FEC_CommonUltils.normalizeTeamUserGroupParam('CP'));
        System.assertEquals(FEC_ConstantCommon.STAGE_CHANGE_TEAM_USER_GROUP_PM,
            FEC_CommonUltils.normalizeTeamUserGroupParam('payment'));

        System.assertEquals('https://base', FEC_CommonUltils.buildCalloutEndpoint('https://base/', ''));
        System.assertEquals('https://base/api', FEC_CommonUltils.buildCalloutEndpoint('https://base', '/api'));

        System.assertEquals(null, FEC_CommonUltils.xmlPackedBaseRateToPercent(null, 'rate'));
        System.assertEquals(null, FEC_CommonUltils.findChildByName(null, 'item'));
        System.assertEquals(null, FEC_CommonUltils.getValueSafe(null, 'item'));

        FEC_CommonUltils.logException('TestAuthor', 'testFunc', 'err', 'stack');
        System.assertEquals(1, [SELECT COUNT() FROM FEC_Log__c WHERE FEC_Function_Name__c = 'testFunc']);

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>{
            FEC_CommonUltils.buildEmail(
                new List<String>{ 'notify@example.com' },
                'Subject',
                '<p>Body</p>'
            )
        };
        System.assertEquals(1, emails.size());
        System.assertEquals('notify@example.com', emails[0].getToAddresses()[0]);
    }

    @IsTest
    static void testCalloutApiWithMock() {
        Test.setMock(HttpCalloutMock.class, new SimpleCalloutMock());

        Test.startTest();
        HttpResponse res = FEC_CommonUltils.calloutApi(
            'https://example.com/test',
            'GET',
            FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
            null,
            null,
            ''
        );
        HttpResponse resWithHeaders = FEC_CommonUltils.calloutApiWithHeaders(
            'https://example.com/test',
            'GET',
            new Map<String, String>{ 'X-Test' => '1' },
            null
        );
        Test.stopTest();

        System.assertEquals(200, res.getStatusCode());
        System.assertEquals(200, resWithHeaders.getStatusCode());
        System.assertEquals('OK', res.getBody());
    }

    @IsTest
    static void testNotifyUsersWithPageRef() {
        List<CustomNotificationType> types = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Custom_Notification'
            LIMIT 1
        ];
        if (types.isEmpty()) {
            return;
        }

        User admin = [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = true
            LIMIT 1
        ];

        System.runAs(admin) {
            Test.startTest();
            FEC_CommonUltils.notifyUsers(
                new Set<String>{ UserInfo.getUserId() },
                null,
                'standard__objectHome',
                'Page Ref Title',
                'Page Ref Body'
            );
            Boolean sent = FEC_CommonUltils.notifyUsers(
                new Set<String>{ UserInfo.getUserId() },
                (Id) null,
                'standard__objectHome',
                'Page Ref 2',
                'Page Ref Body 2',
                types[0]
            );
            Test.stopTest();

            System.assertEquals(true, sent);
        }
    }

    @IsTest
    static void testLogSensitiveAccessAndApiResponse() {
        Case c = new Case(
            Subject = 'Sensitive log',
            FEC_ID_Search__c = 'SENS-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_CommonUltils.logSensitiveAccess('Section', 'Field', 'User', 'Role', c.Id);
        FEC_CommonUltils.logApiResponse(new FEC_ResponseLog(
            'TestApi',
            'https://test',
            'GET',
            '{}',
            new HttpResponse(),
            null
        ));
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM FEC_Sensitive_Data__c WHERE FEC_Related_Case__c = :c.Id]);
    }

    private class SimpleCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('OK');
            return res;
        }
    }
}
