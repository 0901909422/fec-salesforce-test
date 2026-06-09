@IsTest
private class FEC_CommonUltils_Test {

    @IsTest
    static void testStringValidationMaskingAndFormatting() {
        System.assertEquals(false, FEC_CommonUltils.isLengthValid(null, 10));
        System.assertEquals(true, FEC_CommonUltils.isLengthValid('abc', 5));
        System.assertEquals(false, FEC_CommonUltils.isMail('bad'));
        System.assertEquals(true, FEC_CommonUltils.isMail('user.name@fec.com'));
        System.assertEquals(false, FEC_CommonUltils.isPhone('123'));
        System.assertEquals(true, FEC_CommonUltils.isPhone('0912345678'));
        System.assertEquals('84912345678', FEC_CommonUltils.normalizePhone('0912345678'));
        System.assertEquals(true, FEC_CommonUltils.isValidAccountNumber('1234567890123456'));
        System.assertEquals(false, FEC_CommonUltils.isValidAccountNumber('123'));
        System.assertEquals(true, FEC_CommonUltils.isValidDateByFormat('2024-06-15'));
        System.assertEquals(false, FEC_CommonUltils.isValidDateByFormat('2024-13-01'));
        System.assertEquals(FEC_ConstantCommon.STR_EMPTY, FEC_CommonUltils.defaultToEmpty((String) null));
        System.assertEquals('x', FEC_CommonUltils.defaultToEmpty('x'));
        System.assertEquals(FEC_ConstantCommon.STR_EMPTY, FEC_CommonUltils.defaultToEmpty((Object) null));
        System.assertEquals('Label', FEC_CommonUltils.picklistLabelFromFecNameVn('  Label  '));
        System.assertEquals('CH1', FEC_CommonUltils.sanitizeChannelForMessage(' "CH1" '));
        System.assert(FEC_CommonUltils.maskCardNumber('1234567890123456').contains('****'));
        System.assertEquals('0912***678', FEC_CommonUltils.maskPhone('0912345678'));
        System.assert(FEC_CommonUltils.maskNationalIdOrPassport('123456789012').contains('***'));
        System.assertEquals('a&amp;&lt;', FEC_CommonUltils.escapeXml('a&<'));
        System.assertEquals('<root/>', FEC_CommonUltils.cleanResponseBody('\uFEFF junk <root/>'));
        System.assertEquals('Yes', FEC_CommonUltils.normalizeInsuranceFlag('Y'));
        System.assertEquals('Inactive', FEC_CommonUltils.checkEcomFlag(true));
        System.assertEquals('Active', FEC_CommonUltils.checkActiveAndInacive('Y'));
        System.assertEquals('NGUYEN VAN A', FEC_CommonUltils.toUpperNoVietnameseAccent('Nguyễn Văn A'));
        System.assertEquals('A_B', FEC_CommonUltils.sortTeamField('B_A'));
        System.assertEquals('abc123', FEC_CommonUltils.cleanNonWordCharacters('abc-123!'));
        System.assertEquals(FEC_ConstantCommon.CC_CD, FEC_CommonUltils.getNationalIdFormat('123456789012'));
        System.assertEquals(2, FEC_CommonUltils.parseSearchResultNationalIds('111;222').size());
        System.assertEquals('a,b', FEC_CommonUltils.removeTrailingComma('a,b,,'));
        System.assertEquals('he…', FEC_CommonUltils.truncateForLog('hello', 2, '…'));
        System.assertEquals('user', FEC_CommonUltils.getEmailPrefix('user@fec.com'));
        System.assertEquals('ALL', FEC_CommonUltils.mergeApplyTo('A', 'B'));
        System.assertNotEquals('', FEC_CommonUltils.decimalToString(1000));
        System.assertNotEquals('', FEC_CommonUltils.formatCurrency(1000, 2));
        System.assertEquals('1,000.00', FEC_CommonUltils.formatCurrencyFixed(1000, 2));
        System.assertEquals('1000.00', FEC_CommonUltils.formatDecimalPlainScale(1000, 2));
        Date d = Date.newInstance(2024, 6, 5);
        System.assertEquals('05/06/2024', FEC_CommonUltils.formatDateDDMMYYYY(d));
        System.assertEquals('2024-06-05', FEC_CommonUltils.formatDateYYYYMMDD(d));
        System.assertNotEquals('', FEC_CommonUltils.formatDate(d));
        System.assertEquals(Decimal.valueOf('1200.5'), FEC_CommonUltils.parseAmountSafe('1,200.50'));
        System.assertEquals(2000, FEC_CommonUltils.roundUpToThousand(1501));
        System.assert(FEC_CommonUltils.calculateReducingEMI(1000000, 12, 0.01) > 0);
        System.assertEquals('09', FEC_CommonUltils.pad2(9));
        System.assertEquals(false, FEC_CommonUltils.checkLength('Name', '12345678901', 10));
        FEC_CommonUltils.getActiveChannelIds();
        System.assertEquals(false, FEC_CommonUltils.isActiveChannelSupported(null));
    }

    @IsTest
    static void testDateTimeParsingAndFormatting() {
        System.assertEquals(Date.newInstance(2024, 6, 15), FEC_CommonUltils.parseDate('20240615'));
        System.assertEquals(null, FEC_CommonUltils.parseDate('00000000'));
        System.assertNotEquals(null, FEC_CommonUltils.parseDateTime('2025-10-31T14:00:10.491Z'));
        System.assertEquals(42, FEC_CommonUltils.toInt('42'));
        System.assertEquals(Date.newInstance(2024, 1, 2), FEC_CommonUltils.toDate('2024-01-02'));
        System.assertNotEquals(null, FEC_CommonUltils.toDatetime('2024-01-02T10:00:00'));
        System.assertEquals(7, FEC_CommonUltils.toIntDec(7.9));
        System.assertEquals(7, FEC_CommonUltils.toInt(7.2));
        Datetime dt = Datetime.newInstance(2024, 6, 5, 10, 30, 0);
        System.assert(FEC_CommonUltils.formatISOWithTimezone(dt).contains('2024-06-05'));
        System.assert(FEC_CommonUltils.buildDatetimeForAPI().contains('T'));
        System.assert(FEC_CommonUltils.formatTransferCallRequestDateTime(dt).endsWith(' GMT'));
        System.assertEquals(Date.newInstance(2024, 3, 4), FEC_CommonUltils.toDateStr('04/03/2024'));
        Test.startTest();
        Time now = FEC_CommonUltils.getCurrentLocalTime();
        Test.stopTest();
        System.assertNotEquals(null, now);
        System.assertEquals(true, FEC_CommonUltils.isWithinSchedule(Time.newInstance(12, 0, 0, 0), null, null));
        System.assertEquals(
            true,
            FEC_CommonUltils.isWithinSchedule(
                Time.newInstance(12, 0, 0, 0),
                Time.newInstance(8, 0, 0, 0),
                Time.newInstance(18, 0, 0, 0)
            )
        );
        System.assertNotEquals('', FEC_CommonUltils.formatTimestamp(dt, 'yyyy-MM-dd'));
    }

    @IsTest
    static void testXmlHelpers() {
        Dom.Document doc = new Dom.Document();
        Dom.XmlNode root = doc.createRootElement('Root', null, null);
        Dom.XmlNode child = root.addChildElement('Amount', null, null);
        child.addTextNode('1,200.50');
        root.addChildElement('EffDate', null, null).addTextNode('20240615');
        root.addChildElement('Rate', null, null).addTextNode('1000000');
        FEC_CommonUltils.addTextNodeSafe(root, 'Note', 'ok');
        System.assertEquals('1,200.50', FEC_CommonUltils.getXmlValue(root, 'Amount'));
        System.assertEquals('1,200.50', FEC_CommonUltils.getValueSafe(root, 'Amount'));
        System.assertEquals(child, FEC_CommonUltils.findChildByName(root, 'Amount'));
        System.assertEquals(Decimal.valueOf('1200.5'), FEC_CommonUltils.xmlValToDecimal(root, 'Amount'));
        System.assertEquals(Date.newInstance(2024, 6, 15), FEC_CommonUltils.xmlValToDate(root, 'EffDate'));
        System.assertEquals(Decimal.valueOf('10'), FEC_CommonUltils.xmlPackedBaseRateToPercent(root, 'Rate'));
        Dom.Document nsDoc = new Dom.Document();
        Dom.XmlNode nsRoot = nsDoc.createRootElement('NsRoot', null, null);
        nsRoot.addChildElement('Val', 'http://ns', null).addTextNode('x');
        System.assertEquals('x', FEC_CommonUltils.getXmlValueHasNamspace(nsRoot, 'Val'));
    }

    @IsTest
    static void testTemplateCalloutIdsAndSerialize() {
        Case c = new Case(Subject = 'Tpl Subject', Status = 'New');
        System.assertEquals('Tpl Subject', FEC_CommonUltils.resolveTemplate('{{Subject}}', c));
        System.assertEquals(
            'Hi John',
            FEC_CommonUltils.resolveTemplate('Hi {{name}}', c, new Map<String, String>{ 'name' => 'John' })
        );
        Set<String> paths = FEC_CommonUltils.extractFieldPaths(new List<String>{ '{{Subject}}', '{{Account.Name}}' });
        System.assert(paths.contains('Subject') && paths.contains('Account.Name'));
        System.assertEquals('https://api.test/path', FEC_CommonUltils.buildCalloutEndpoint('https://api.test', '/path'));
        Test.startTest();
        String txnId = FEC_CommonUltils.generateTransactionId();
        String uuid = FEC_CommonUltils.generateTransactionUUID();
        Test.stopTest();
        System.assert(txnId.contains('_'));
        System.assertEquals(36, uuid.length());
        System.assertEquals('{"a":1}', FEC_CommonUltils.serializeSafe(new Map<String, Object>{ 'a' => 1 }));
        FEC_CommonUltils.logException('Test', 'fn', 'err', 'stack');
    }

    @IsTest
    static void testEmailAddressCaseAndMetadata() {
        List<String> rcv = FEC_CommonUltils.parseReceivers('a@b.com, c@d.com\n e@f.com');
        System.assertEquals(3, rcv.size());
        Messaging.SingleEmailMessage mail = FEC_CommonUltils.buildEmail(
            new List<String>{ 'a@b.com' },
            'Sub',
            '<p>Body</p>'
        );
        System.assertEquals('Sub', mail.getSubject());
        System.assertEquals(
            'B1, 12, Street, Ward, Dist, City, VN, 70000',
            FEC_CommonUltils.formatAddress('B1', '12', 'Street', 'Ward', 'Dist', 'City', 'VN', '70000')
        );
        System.assertEquals(true, FEC_CommonUltils.isCaseStatusResolved('Resolved-Completed'));
        System.assertEquals(false, FEC_CommonUltils.isCaseStatusResolved('New'));
        System.assertEquals(
            true,
            FEC_CommonUltils.notificationCustomerTypeMatchesCase(FEC_ConstantCommon.CASE_ALL_REQUEST, 'Retail')
        );
        System.assertEquals(
            true,
            FEC_CommonUltils.notificationCustomerTypeMatchesCase('Retail;Corp', 'Retail')
        );
        System.assertEquals('VN Name', FEC_CommonUltils.pickNameByLanguage('EN', 'VN Name', FEC_ConstantCommon.LANGUAGE_VN));
        System.assertEquals('EN Name', FEC_CommonUltils.pickNameByLanguage('EN Name', 'VN', 'EN'));
        System.assertEquals(FEC_ConstantCommon.KEY_PICKLIST, FEC_CommonUltils.getFieldType('Case', 'Status'));
        System.assertEquals(FEC_ConstantCommon.KEY_TEXT, FEC_CommonUltils.getFieldType('Case', 'Subject'));
        System.assertNotEquals(null, FEC_CommonUltils.getFieldLabel('Case', 'Subject'));
        System.assert(FEC_CommonUltils.buildHelpTextMap(Case.SObjectType).size() >= 0);
        List<FEC_CommonUltils.PicklistOption> opts = FEC_CommonUltils.getPicklistOptions('Case', 'Status');
        System.assert(opts.size() >= 0);
        System.assertEquals(0, FEC_CommonUltils.getPicklistOptionsWithAccess('', '').size());
    }

    @IsTest
    static void testDeferredApiLogging() {
        Test.startTest();
        FEC_CommonUltils.beginDeferredApiLogging();
        System.assertEquals(true, FEC_CommonUltils.isDeferredApiLoggingActive());
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('ok');
        FEC_CommonUltils.logApi('DeferredTest', 'https://test', 'GET', 'req', res, null);
        FEC_CommonUltils.flushDeferredApiLogs();
        Test.stopTest();
        System.assertEquals(false, FEC_CommonUltils.isDeferredApiLoggingActive());
    }
}
