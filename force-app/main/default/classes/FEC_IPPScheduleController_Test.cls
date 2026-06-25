@IsTest
private class FEC_IPPScheduleController_Test {

    private static final String ACCOUNT_NUMBER = '0001500060000003';

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        Case c = new Case(
            Subject = 'FEC_IPPScheduleController_Test',
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            Status = 'New',
            FEC_ID_Search__c = 'IPPSCH-' + suffix
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c cust = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            Name = ACCOUNT_NUMBER,
            FEC_Account_Number__c = ACCOUNT_NUMBER
        );
        insert cust;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Account_or_Contract__c = cust.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_IPP__c ipp = new FEC_IPP__c(
            FEC_Customer_History__c = cust.Id,
            FEC_IPP_Record_No__c = 'REC01',
            FEC_IPP_Plan__c = 'PLAN01'
        );
        insert ipp;

        insert new FEC_IPP_Schedule__c(
            FEC_IPP__c = ipp.Id,
            FEC_IPP_Payment_No__c = 1,
            FEC_IPP_Opening_Balance__c = 1000,
            FEC_IPP_Payment_Amount__c = 100
        );

        insert new FEC_API_Setting__c(
            FEC_Call_Mock__c = true,
            FEC_Endpoint__c = 'https://test-api.fecredit.com.vn'
        );
    }

    @IsTest
    static void testGetIPPScheduleData_Success() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            System.assert(true, 'Skipped: FEC_IPPScheduleController not on org.');
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new CardSecInfoMock());

        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ipp.Id, false);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('schedules'));
        System.assert(result.containsKey('totalPaymentAmount'));
    }

    @IsTest
    static void testRefreshIPPScheduleData() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            System.assert(true, 'Skipped: FEC_IPPScheduleController not on org.');
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new CardSecInfoMock());

        Test.startTest();
        Map<String, Object> result = FEC_IPPScheduleController.refreshIPPScheduleData(ipp.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testGetIPPSchedules() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            System.assert(true, 'Skipped: FEC_IPPScheduleController not on org.');
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];

        Test.startTest();
        List<FEC_IPP_Schedule__c> schedules =
            FEC_IPPScheduleController.getIPPSchedules(ipp.Id);
        Test.stopTest();

        System.assertEquals(1, schedules.size());
    }

    @IsTest
    static void testSyncIPPScheduleFromAPI() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            System.assert(true, 'Skipped: FEC_IPPScheduleController not on org.');
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new CardSecInfoMock());

        Test.startTest();
        String reason = FEC_IPPScheduleController.syncIPPScheduleFromAPI(ipp.Id);
        Test.stopTest();

        System.assertEquals(null, reason);
    }

    @IsTest
    static void testGetIPPScheduleData_WithSalesPopulate() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new IppScheduleCombinedMock());

        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ipp.Id, false);
        Test.stopTest();

        System.assertNotEquals(null, result.get('schedules'));
        System.assert(result.containsKey('totalPaymentAmount'));
    }

    @IsTest
    static void testGetIPPScheduleData_NullIppIdThrows() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_IPPScheduleController.getIPPScheduleData(null, true);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testSyncIPPScheduleFromAPI_NullThrows() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_IPPScheduleController.syncIPPScheduleFromAPI(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testRefreshIPPScheduleData_NullThrows() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_IPPScheduleController.refreshIPPScheduleData(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testGetIPPScheduleData_SkipSalesFlag() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new CardSecInfoMock());

        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ipp.Id, true);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testGetIPPScheduleData_BlankIppIdThrows() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_IPPScheduleController.getIPPScheduleData('   ', true);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testGetIPPScheduleData_InvalidIppIdThrows() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_IPPScheduleController.getIPPScheduleData('001000000000000AAA', true);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testGetIPPScheduleData_NullSkipPopulateDefaultsFalse() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new CardSecInfoMock());

        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ipp.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('schedules'));
    }

    @IsTest
    static void testGetIPPScheduleData_ApiReturnedNoIpps() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new CardSecInfoEmptyMock());

        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ipp.Id, true);
        Test.stopTest();

        System.assertEquals('API_RETURNED_NO_IPPS', result.get('emptyScheduleReason'));
    }

    @IsTest
    static void testGetIPPScheduleData_FilterEmpty() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        ipp.FEC_IPP_Record_No__c = 'NOMATCH';
        ipp.FEC_IPP_Plan__c = 'NOMATCH';
        update ipp;

        Test.setMock(HttpCalloutMock.class, new CardSecInfoMock());
        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ipp.Id, true);
        Test.stopTest();

        System.assertEquals('FILTER_EMPTY', result.get('emptyScheduleReason'));
    }

    @IsTest
    static void testGetIPPScheduleData_FilterByPlanOnly() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        ipp.FEC_IPP_Record_No__c = 'NOMATCH';
        ipp.FEC_IPP_Plan__c = 'PLAN01';
        update ipp;

        Test.setMock(HttpCalloutMock.class, new CardSecInfoMock());
        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ipp.Id, true);
        Test.stopTest();

        System.assertNotEquals(null, result.get('schedules'));
        System.assertEquals(null, result.get('emptyScheduleReason'));
    }

    @IsTest
    static void testGetIPPScheduleData_ApiError() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new CardSecInfoErrorMock());

        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ipp.Id, true);
        Test.stopTest();

        System.assertNotEquals(null, result.get('emptyScheduleReason'));
        System.assertEquals(
            true,
            String.valueOf(result.get('emptyScheduleReason')).startsWith('API_ERROR')
        );
    }

    @IsTest
    static void testGetIPPScheduleData_WithExistingSalesInfo() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        ipp.FEC_CC_Code__c = 'CC_EXISTING';
        update ipp;

        Test.setMock(HttpCalloutMock.class, new CardSecInfoMock());
        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ipp.Id, false);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testGetIPPScheduleData_BuildResultTotals() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new CardSecInfoTwoPeriodMock());

        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ipp.Id, true);
        Test.stopTest();

        System.assertEquals(200, result.get('totalPaymentAmount'));
        List<FEC_IPP_Schedule__c> schedules =
            (List<FEC_IPP_Schedule__c>) result.get('schedules');
        System.assertEquals(2, schedules.size());
    }

    @IsTest
    static void testResolveScheduleItemsForSave_EmptyInput() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        List<FEC_GetCardSecInfo.IPP> result =
            FEC_IPPScheduleController.resolveScheduleItemsForSave(
                new List<FEC_GetCardSecInfo.IPP>(),
                null
            );
        System.assertEquals(0, result.size());
    }

    @IsTest
    static void testResolveScheduleItemsForSave_ZeroOpeningBalanceFallback() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_GetCardSecInfo.IPP zeroBal = new FEC_GetCardSecInfo.IPP();
        zeroBal.OpeningBalance = 0;
        zeroBal.PaymentAmount = 50;

        List<FEC_GetCardSecInfo.IPP> matched = new List<FEC_GetCardSecInfo.IPP>{ zeroBal };
        List<FEC_GetCardSecInfo.IPP> result =
            FEC_IPPScheduleController.resolveScheduleItemsForSave(matched, null);

        System.assertEquals(1, result.size());
        System.assertEquals(0, result[0].OpeningBalance);
    }

    @IsTest
    static void testResolveScheduleItemsForSave_TrimsByIppTerm() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        ipp.FEC_IPP_Term__c = 2;
        update ipp;

        List<FEC_GetCardSecInfo.IPP> matched = new List<FEC_GetCardSecInfo.IPP>();
        for (Integer i = 1; i <= 4; i++) {
            FEC_GetCardSecInfo.IPP item = new FEC_GetCardSecInfo.IPP();
            item.OpeningBalance = 1000 - (i * 100);
            item.PaymentAmount = 100;
            item.term = 4;
            matched.add(item);
        }

        List<FEC_GetCardSecInfo.IPP> result =
            FEC_IPPScheduleController.resolveScheduleItemsForSave(matched, ipp);

        System.assertEquals(2, result.size());
    }

    @IsTest
    static void testResolveScheduleItemsForSave_TrimsByApiTerm() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        List<FEC_GetCardSecInfo.IPP> matched = new List<FEC_GetCardSecInfo.IPP>();
        for (Integer i = 1; i <= 3; i++) {
            FEC_GetCardSecInfo.IPP item = new FEC_GetCardSecInfo.IPP();
            item.OpeningBalance = 1000 - (i * 100);
            item.PaymentAmount = 100;
            if (i == 1) {
                item.term = 2;
            }
            matched.add(item);
        }

        List<FEC_GetCardSecInfo.IPP> result =
            FEC_IPPScheduleController.resolveScheduleItemsForSave(matched, null);

        System.assertEquals(2, result.size());
    }

    @IsTest
    static void testResolveScheduleItemsForSave_NullMatched() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        List<FEC_GetCardSecInfo.IPP> result =
            FEC_IPPScheduleController.resolveScheduleItemsForSave(null, null);
        System.assertEquals(0, result.size());
    }

    @IsTest
    static void testResolveScheduleItemsForSave_NoTrimNeeded() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        List<FEC_GetCardSecInfo.IPP> matched = new List<FEC_GetCardSecInfo.IPP>();
        for (Integer i = 1; i <= 2; i++) {
            FEC_GetCardSecInfo.IPP item = new FEC_GetCardSecInfo.IPP();
            item.OpeningBalance = 1000 - (i * 100);
            item.PaymentAmount = 100;
            item.term = 5;
            matched.add(item);
        }

        List<FEC_GetCardSecInfo.IPP> result =
            FEC_IPPScheduleController.resolveScheduleItemsForSave(matched, null);
        System.assertEquals(2, result.size());
    }

    @IsTest
    static void testGetIPPScheduleData_FilterByRecordNoTrim() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        ipp.FEC_IPP_Record_No__c = ' REC01 ';
        ipp.FEC_IPP_Plan__c = 'PLAN99';
        update ipp;

        Test.setMock(HttpCalloutMock.class, new CardSecInfoMock());
        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ipp.Id, true);
        Test.stopTest();

        System.assertEquals(null, result.get('emptyScheduleReason'));
        System.assertNotEquals(null, result.get('schedules'));
    }

    @IsTest
    static void testGetIPPScheduleData_WithDsaCodeSkipsSales() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        ipp.FEC_DSA_Code__c = 'DSA_EXISTING';
        update ipp;

        Test.setMock(HttpCalloutMock.class, new CardSecInfoMock());
        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ipp.Id, false);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('ippRecord'));
    }

    @IsTest
    static void testGetIPPScheduleData_WithTsaCodeSkipsSales() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        ipp.FEC_TSA_Code__c = 'TSA_EXISTING';
        update ipp;

        Test.setMock(HttpCalloutMock.class, new CardSecInfoMock());
        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ipp.Id, false);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testGetIPPScheduleData_BuildResultMonthlyTotals() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new CardSecInfoMonthlyMock());

        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ipp.Id, true);
        Test.stopTest();

        System.assertEquals(80, result.get('totalMonthlyPrincipal'));
        System.assertEquals(20, result.get('totalMonthlyInterest'));
    }

    @IsTest
    static void testApplySalesInfoDml_UpdatesIppFields() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        FEC_SalesInfoController.SalesInfoResult sales =
            new FEC_SalesInfoController.SalesInfoResult();
        sales.isSuccess = true;
        sales.ccCode = 'CC01';
        sales.ccName = 'CC Name';
        sales.dsaCode = 'DSA01';
        sales.dsaName = 'DSA Name';
        sales.tsaCode = 'TSA01';
        sales.tsaName = 'TSA Name';

        Test.startTest();
        FEC_IPPScheduleController.applySalesInfoDml(ipp.Id, sales);
        Test.stopTest();

        FEC_IPP__c updated = [
            SELECT FEC_CC_Code__c, FEC_DSA_Code__c, FEC_TSA_Code__c
            FROM FEC_IPP__c
            WHERE Id = :ipp.Id
        ];
        System.assertEquals('CC01', updated.FEC_CC_Code__c);
        System.assertEquals('DSA01', updated.FEC_DSA_Code__c);
        System.assertEquals('TSA01', updated.FEC_TSA_Code__c);
    }

    @IsTest
    static void testApplySalesInfoDml_SkipsWhenNotSuccessful() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_IPP__c ipp = [
            SELECT Id, FEC_CC_Code__c
            FROM FEC_IPP__c
            LIMIT 1
        ];
        FEC_SalesInfoController.SalesInfoResult sales =
            new FEC_SalesInfoController.SalesInfoResult();
        sales.isSuccess = false;
        sales.ccCode = 'SKIP';

        Test.startTest();
        FEC_IPPScheduleController.applySalesInfoDml(ipp.Id, sales);
        Test.stopTest();

        FEC_IPP__c unchanged = [
            SELECT FEC_CC_Code__c
            FROM FEC_IPP__c
            WHERE Id = :ipp.Id
        ];
        System.assertEquals(ipp.FEC_CC_Code__c, unchanged.FEC_CC_Code__c);
    }

    @IsTest
    static void testGetIPPScheduleData_SyncSummaryIppNullAmounts() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new CardSecInfoSummaryOnlyMock());

        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ipp.Id, true);
        Test.stopTest();

        List<FEC_IPP_Schedule__c> schedules =
            (List<FEC_IPP_Schedule__c>) result.get('schedules');
        System.assertEquals(1, schedules.size());
        System.assertEquals(0, schedules[0].FEC_IPP_Opening_Balance__c);
        System.assertEquals(0, schedules[0].FEC_IPP_Monthly_Principal__c);
    }

    @IsTest
    static void testGetIPPScheduleData_NoAccountNumber() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_Customer_History__c ch = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];
        ch.FEC_Account_Number__c = null;
        update ch;

        FEC_IPP__c ippNoAcct = new FEC_IPP__c(
            FEC_Customer_History__c = ch.Id,
            FEC_IPP_Record_No__c = 'NOACCT',
            FEC_IPP_Plan__c = 'PLAN99'
        );
        insert ippNoAcct;

        Test.setMock(HttpCalloutMock.class, new CardSecInfoMock());
        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ippNoAcct.Id, true);
        Test.stopTest();

        System.assertEquals('NO_ACCOUNT_NUMBER', result.get('emptyScheduleReason'));
    }

    private class IppScheduleCombinedMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String body = req.getBody() != null ? req.getBody() : '';
            if (body.contains('Sales') || (req.getEndpoint() != null && req.getEndpoint().contains('Sale'))) {
                res.setHeader('Content-Type', 'application/json');
                res.setBody(
                    '{"Sys":{"Code":1},"CustomerSaleInfos":[{"CC_CODE":"CC01","CC_NAME":"CC","DSA_CODE":"DS01","DSA_NAME":"DSA","TSA_CODE":"TS01","TSA_NAME":"TSA"}]}'
                );
            } else {
                res.setHeader('Content-Type', 'text/xml');
                res.setBody(buildCardSecInfoXml('REC01', 'PLAN01'));
            }
            return res;
        }
    }

    private static String buildCardSecInfoXml(String ippRecordNo, String ippPlan) {
        return '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body><GetCardSecInfoResponse>' +
            '<Sys><Code>1</Code><Description>Success</Description></Sys>' +
            '<CardSecInfo><IPPs><IPP>' +
            '<IPPRecordNo>' + ippRecordNo + '</IPPRecordNo>' +
            '<IPPPlan>' + ippPlan + '</IPPPlan>' +
            '<Term>1</Term>' +
            '<OPENING_BALANCE_1>1000</OPENING_BALANCE_1>' +
            '<PAYMENT_AMT_1>100</PAYMENT_AMT_1>' +
            '</IPP></IPPs></CardSecInfo>' +
            '</GetCardSecInfoResponse></soapenv:Body></soapenv:Envelope>';
    }

    private class CardSecInfoMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(buildCardSecInfoXml('REC01', 'PLAN01'));
            return res;
        }
    }

    private class CardSecInfoEmptyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetCardSecInfoResponse>' +
                '<Sys><Code>1</Code></Sys>' +
                '<CardSecInfo><IPPs></IPPs></CardSecInfo>' +
                '</GetCardSecInfoResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class CardSecInfoTwoPeriodMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetCardSecInfoResponse>' +
                '<Sys><Code>1</Code><Description>Success</Description></Sys>' +
                '<CardSecInfo><IPPs><IPP>' +
                '<IPPRecordNo>REC01</IPPRecordNo><IPPPlan>PLAN01</IPPPlan>' +
                '<Term>2</Term>' +
                '<OPENING_BALANCE_1>1000</OPENING_BALANCE_1><PAYMENT_AMT_1>100</PAYMENT_AMT_1>' +
                '<OPENING_BALANCE_2>900</OPENING_BALANCE_2><PAYMENT_AMT_2>100</PAYMENT_AMT_2>' +
                '</IPP></IPPs></CardSecInfo>' +
                '</GetCardSecInfoResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class CardSecInfoSummaryOnlyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetCardSecInfoResponse>' +
                '<Sys><Code>1</Code><Description>Success</Description></Sys>' +
                '<CardSecInfo><IPPs><IPP>' +
                '<IPPRecordNo>REC01</IPPRecordNo><IPPPlan>PLAN01</IPPPlan>' +
                '<PaymentAmount>50</PaymentAmount>' +
                '</IPP></IPPs></CardSecInfo>' +
                '</GetCardSecInfoResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class CardSecInfoMonthlyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetCardSecInfoResponse>' +
                '<Sys><Code>1</Code><Description>Success</Description></Sys>' +
                '<CardSecInfo><IPPs><IPP>' +
                '<IPPRecordNo>REC01</IPPRecordNo><IPPPlan>PLAN01</IPPPlan>' +
                '<Term>1</Term>' +
                '<OPENING_BALANCE_1>1000</OPENING_BALANCE_1>' +
                '<PAYMENT_AMT_1>100</PAYMENT_AMT_1>' +
                '<MONTHLY_PRINCIPAL_1>80</MONTHLY_PRINCIPAL_1>' +
                '<MONTHLY_INTEREST_1>20</MONTHLY_INTEREST_1>' +
                '</IPP></IPPs></CardSecInfo>' +
                '</GetCardSecInfoResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class CardSecInfoErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }
}
