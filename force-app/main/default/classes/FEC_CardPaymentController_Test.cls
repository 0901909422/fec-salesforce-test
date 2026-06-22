@IsTest
private class FEC_CardPaymentController_Test {

    private static final String SOAP_ENV = FEC_ConstantCommon.SOAP_ENV;
    private static final String CIF_NS = 'http://fecredit.com.vn/CIF_CardInfo';

    private class CardPlanSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                '<soapenv:Body>' +
                '<cif:GetCardPlanInfoResponse xmlns:cif="' + CIF_NS + '">' +
                '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                '<CardPlanInfo><CardPlans>' +
                '<CardPlan>' +
                '<RecordNumber>REC02</RecordNumber><PlanNumber>PLAN02</PlanNumber>' +
                '<REFNumber>REF999</REFNumber><PlanOpenDate>2026-05-20</PlanOpenDate>' +
                '<BeginDate>2026-05-20</BeginDate><PlanCurrentBalance>5000000</PlanCurrentBalance>' +
                '<BaseRate>12.5</BaseRate><CloseFeeIndicator>Y</CloseFeeIndicator>' +
                '<CloseFeeIndicatorAmount>100000</CloseFeeIndicatorAmount>' +
                '<PlanPaymentAmount>500000</PlanPaymentAmount>' +
                '<AccruedInterest>30000</AccruedInterest><PerDiem>2000</PerDiem>' +
                '<DeferredInterest>10000</DeferredInterest><AccruedInt>4000</AccruedInt>' +
                '</CardPlan>' +
                '</CardPlans></CardPlanInfo>' +
                '</cif:GetCardPlanInfoResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class CardPlanEmptyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                '<soapenv:Body>' +
                '<cif:GetCardPlanInfoResponse xmlns:cif="' + CIF_NS + '">' +
                '<Sys><Code>1</Code></Sys><CardPlanInfo><CardPlans></CardPlans></CardPlanInfo>' +
                '</cif:GetCardPlanInfoResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class BasicInfoOnlyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                '<soapenv:Body>' +
                '<cif:GetCardBasicInfoResponse xmlns:cif="' + CIF_NS + '">' +
                '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                '<CardBasicInfo><MainCard><LoanBalance>3000000</LoanBalance></MainCard></CardBasicInfo>' +
                '</cif:GetCardBasicInfoResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class TotalsThreeApisMock implements HttpCalloutMock {
        private Integer callSeq = 0;

        public HttpResponse respond(HttpRequest req) {
            callSeq++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (callSeq == 1) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                    '<soapenv:Body>' +
                    '<cif:GetCardBasicInfoResponse xmlns:cif="' + CIF_NS + '">' +
                    '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                    '<CardBasicInfo><MainCard><LoanBalance>3000000</LoanBalance></MainCard></CardBasicInfo>' +
                    '</cif:GetCardBasicInfoResponse>' +
                    '</soapenv:Body></soapenv:Envelope>'
                );
            } else if (callSeq == 2) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                    '<soapenv:Body>' +
                    '<WSResponse xmlns:v2="http://fecredit.com.vn/cms/ws/v2">' +
                    '<Sys><Code>1</Code></Sys>' +
                    '<M_CMS_EMEA_ACCOUNT_INQ><VMX_ROOT><VMX_MSGOUT>' +
                    '<ACCT_BS_OUTPUT>' +
                    '<CURR_BAL>10000000</CURR_BAL>' +
                    '<AMT_MEMO_DB>500000</AMT_MEMO_DB><AMT_MEMO_CR>200000</AMT_MEMO_CR>' +
                    '</ACCT_BS_OUTPUT></VMX_MSGOUT></VMX_ROOT></M_CMS_EMEA_ACCOUNT_INQ>' +
                    '</WSResponse></soapenv:Body></soapenv:Envelope>'
                );
            } else {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                    '<soapenv:Body><cif:GetCardPlanInfoResponse xmlns:cif="' + CIF_NS + '">' +
                    '<Sys><Code>1</Code></Sys><CardPlanInfo><CardPlans>' +
                    '<CardPlan><PlanNumber>001</PlanNumber>' +
                    '<DeferredInterest>100000</DeferredInterest>' +
                    '<AccruedInterest>50000</AccruedInterest><PerDiem>10000</PerDiem>' +
                    '</CardPlan></CardPlans></CardPlanInfo>' +
                    '</cif:GetCardPlanInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
            }
            return res;
        }
    }

    private class ZeroBalanceApisMock implements HttpCalloutMock {
        private Integer callSeq = 0;

        public HttpResponse respond(HttpRequest req) {
            callSeq++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (callSeq == 1) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                    '<soapenv:Body>' +
                    '<cif:GetCardBasicInfoResponse xmlns:cif="' + CIF_NS + '">' +
                    '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                    '<CardBasicInfo><MainCard><LoanBalance>0</LoanBalance></MainCard></CardBasicInfo>' +
                    '</cif:GetCardBasicInfoResponse>' +
                    '</soapenv:Body></soapenv:Envelope>'
                );
            } else if (callSeq == 2) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                    '<soapenv:Body>' +
                    '<WSResponse xmlns:v2="http://fecredit.com.vn/cms/ws/v2">' +
                    '<Sys><Code>1</Code></Sys>' +
                    '<M_CMS_EMEA_ACCOUNT_INQ><VMX_ROOT><VMX_MSGOUT>' +
                    '<ACCT_BS_OUTPUT>' +
                    '<CURR_BAL>0</CURR_BAL>' +
                    '<AMT_MEMO_DB>0</AMT_MEMO_DB><AMT_MEMO_CR>0</AMT_MEMO_CR>' +
                    '</ACCT_BS_OUTPUT></VMX_MSGOUT></VMX_ROOT></M_CMS_EMEA_ACCOUNT_INQ>' +
                    '</WSResponse></soapenv:Body></soapenv:Envelope>'
                );
            } else {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                    '<soapenv:Body><cif:GetCardPlanInfoResponse xmlns:cif="' + CIF_NS + '">' +
                    '<Sys><Code>1</Code></Sys><CardPlanInfo><CardPlans>' +
                    '<CardPlan><RecordNumber>001</RecordNumber><PlanNumber>60008</PlanNumber>' +
                    '<PlanCurrentBalance>0</PlanCurrentBalance>' +
                    '</CardPlan><CardPlan><RecordNumber>002</RecordNumber><PlanNumber>60001</PlanNumber>' +
                    '<PlanCurrentBalance>0</PlanCurrentBalance>' +
                    '</CardPlan></CardPlans></CardPlanInfo>' +
                    '</cif:GetCardPlanInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
            }
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        insert new FEC_API_Setting__c(
            FEC_Endpoint__c = 'https://api-gateway.fecredit.com.vn',
            FEC_Call_Mock__c = false
        );

        Case c = new Case(
            Subject = 'Card Payment Core Test Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone',
            FEC_Account_Number__c = 'ACC-PAY-1903'
        );
        insert c;

        FEC_Customer_History__c customer = new FEC_Customer_History__c(
            Name = 'CUST-PAYMENT-001',
            FEC_Case__c = c.Id,
            FEC_Account_Number__c = 'ACC-PAY-1903'
        );
        insert customer;

        update new Case(
            Id = c.Id,
            FEC_Account_or_Contract__c = customer.Id
        );

        insert new FEC_Card_Payment__c(
            FEC_Customer_History__c = customer.Id,
            FEC_Rec__c = 'REC01',
            FEC_Plan__c = 'PLAN01',
            FEC_Current_Balance__c = 1000000,
            FEC_Close_Fee_Amount__c = 50000,
            FEC_Plan_Payment_Amount__c = 200000,
            FEC_Accrued_Interest__c = 15000,
            FEC_IPP_Accrued_Interest__c = 5000,
            FEC_Per_Diem__c = 1000,
            FEC_Deferred_Interest__c = 0
        );
    }

    private static User testRunAsUser() {
        List<User> admins = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        return admins.isEmpty() ? new User(Id = UserInfo.getUserId()) : admins[0];
    }

    @IsTest
    static void testLoadCardPaymentInfo_Success() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new CardPlanSuccessMock());

            Test.startTest();
            FEC_GetCardPlanInfo.CardPlanResult planResult =
                FEC_GetCardPlanInfo.getCardPlanInfo('ACC-PAY-1903');
            List<Map<String, Object>> result1 = FEC_CardPaymentController.loadCardPaymentInfo(c.Id);
            List<Map<String, Object>> result2 = FEC_CardPaymentController.getCardPaymentRecords(String.valueOf(c.Id));
            Test.stopTest();

            System.assertEquals(1, planResult.plans.size(), 'Mock GetCardPlanInfo phải trả 1 plan mới.');
            System.assertNotEquals(null, result1);
            System.assert(result1.size() >= 2, 'Phải có bản ghi setup REC01 và plan mới REC02.');
            System.assertEquals(
                1,
                [SELECT COUNT() FROM FEC_Card_Payment__c WHERE FEC_Rec__c = 'REC02'],
                'API phải upsert plan REC02 vào database.'
            );
            FEC_Card_Payment__c checkInserted = [
                SELECT FEC_Close_Fee__c FROM FEC_Card_Payment__c WHERE FEC_Rec__c = 'REC02' LIMIT 1
            ];
            System.assertEquals(1.00, checkInserted.FEC_Close_Fee__c);
            System.assertNotEquals(null, result2);
        }
    }

    @IsTest
    static void testLoadCardPaymentInfo_MockOnFlow() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            apiSetting.FEC_Call_Mock__c = true;
            update apiSetting;

            Test.startTest();
            List<Map<String, Object>> result = FEC_CardPaymentController.loadCardPaymentInfo(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, result);
        }
    }

    @IsTest
    static void testLoadCardPaymentTotals_AggregateSevenFlow() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new TotalsThreeApisMock());

            Test.startTest();
            FEC_CardPaymentController.CardPaymentTotalsDTO totals =
                FEC_CardPaymentController.loadCardPaymentTotals(c.Id);
            FEC_CardPaymentController.CardPaymentTotalsDTO totalsWrapper =
                FEC_CardPaymentController.getCardPaymentTotals(String.valueOf(c.Id));
            Test.stopTest();

            System.assertNotEquals(null, totals);
            System.assertEquals(10366000, totals.fullPaymentAmount);
            System.assertEquals(3000000, totals.loanBalance);
            System.assertEquals(1000000, totals.totalCurrentBalance);
            System.assertEquals(50000, totals.totalCloseFeeAmount);
            // Runtime: 1,000,000 + 15,000 + 1,000 + 50,000 (IPP = 0 khi chưa vào cửa sổ 4 ngày)
            System.assertEquals(1066000, totals.totalPlanPaymentAmount);
            System.assertNotEquals(null, totalsWrapper);
        }
    }

    @IsTest
    static void testGetCardBasicInfo_CalloutParse() {
        System.runAs(testRunAsUser()) {
            Test.setMock(HttpCalloutMock.class, new BasicInfoOnlyMock());
            Test.startTest();
            FEC_GetCardBasicInfo.ResponseWrapper res = FEC_GetCardBasicInfo.callGetCardBasicInfo(
                'TXN-BASIC',
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                'ACC-PAY-1903'
            );
            Test.stopTest();
            System.assertEquals(3000000, res.CardBasicInfo.MainCard.LoanBalance);
        }
    }

    @IsTest
    static void testLoadCardPaymentTotals_CallThreeApisSequential() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            delete [SELECT Id FROM FEC_Card_Payment__c];
            Test.setMock(HttpCalloutMock.class, new TotalsThreeApisMock());

            Test.startTest();
            FEC_CardPaymentController.CardPaymentTotalsDTO totals =
                FEC_CardPaymentController.loadCardPaymentTotals(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, totals);
            System.assertEquals(10300000, totals.fullPaymentAmount);
            System.assertEquals(3000000, totals.loanBalance);
            System.assertEquals(7400600, totals.fullPaymentWithoutIPP);
            System.assertEquals(2899400, totals.fullIPPPaymentAmount);
        }
    }

    @IsTest
    static void testLoadCardPaymentInfo_EdgeCasesAndExceptions() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];

            Test.startTest();
            try {
                FEC_CardPaymentController.loadCardPaymentInfo(null);
                System.assert(false, 'Expected AuraHandledException');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e.getMessage());
            }

            try {
                FEC_CardPaymentController.loadCardPaymentTotals(null);
                System.assert(false, 'Expected AuraHandledException');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e.getMessage());
            }

            c.FEC_Account_or_Contract__c = null;
            update c;
            FEC_CardPaymentController.CardPaymentTotalsDTO totalsNoHistory =
                FEC_CardPaymentController.loadCardPaymentTotals(c.Id);
            System.assertEquals(0, totalsNoHistory.fullPaymentAmount);

            Test.setMock(HttpCalloutMock.class, new CardPlanEmptyMock());
            List<Map<String, Object>> resException = FEC_CardPaymentController.loadCardPaymentInfo(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, resException);
        }
    }

    @IsTest
    static void testDataStructures_CoverageOnly() {
        Test.startTest();
        FEC_CardPaymentController.CardPaymentTotalsDTO dto = new FEC_CardPaymentController.CardPaymentTotalsDTO();
        dto.fullPaymentAmount = 10;
        dto.totalDeferredInterest = 110;
        Test.stopTest();
        System.assertEquals(10, dto.fullPaymentAmount);
        System.assertEquals(110, dto.totalDeferredInterest);
    }

    @IsTest
    static void testCalculatePlanPaymentAmountFromRecord_ShowIppAccruedInterest() {
        FEC_Card_Payment__c payment = new FEC_Card_Payment__c(
            FEC_Current_Balance__c = 27281279,
            FEC_Accrued_Interest__c = 0,
            FEC_Per_Diem__c = 0,
            FEC_Deferred_Interest__c = 0,
            FEC_IPP_Accrued_Interest__c = 1250391,
            FEC_Close_Fee_Amount__c = 2182502.32,
            FEC_Plan_Payment_Amount__c = 29463781.32
        );

        Decimal withoutIpp = FEC_CardPaymentController.calculatePlanPaymentAmountFromRecord(payment, false);
        Decimal withIpp = FEC_CardPaymentController.calculatePlanPaymentAmountFromRecord(payment, true);

        System.assertEquals(29463781.32, withoutIpp, 'Ngoài cửa sổ 4 ngày không cộng IPP Accrued Interest.');
        System.assertEquals(30714172.32, withIpp, 'Trong cửa sổ 4 ngày phải cộng IPP Accrued Interest.');
    }

    @IsTest
    static void testCalculatePlanPaymentAmount_FromCardPlan() {
        FEC_GetCardPlanInfo.CardPlan plan = new FEC_GetCardPlanInfo.CardPlan();
        plan.currentBalance = 27281279;
        plan.accruedInterest = 0;
        plan.perDiem = 0;
        plan.deferredInterest = 0;
        plan.additionalAccruedInt = 1250391;
        plan.closeFeeAmount = 2182502.32;

        Decimal withoutIpp = FEC_CardPaymentController.calculatePlanPaymentAmount(plan, false);
        Decimal withIpp = FEC_CardPaymentController.calculatePlanPaymentAmount(plan, true);

        System.assertEquals(29463781.32, withoutIpp);
        System.assertEquals(30714172.32, withIpp);
    }

    @IsTest
    static void testLoadCardPaymentInfo_RuntimePlanPaymentAmount() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            FEC_Customer_History__c customer = [
                SELECT Id
                FROM FEC_Customer_History__c
                WHERE FEC_Case__c = :c.Id
                LIMIT 1
            ];
            customer.FEC_Next_Statement_Date__c = Date.today().addDays(1);
            update customer;

            delete [SELECT Id FROM FEC_Card_Payment__c];
            insert new FEC_Card_Payment__c(
                FEC_Customer_History__c = customer.Id,
                FEC_Rec__c = '001',
                FEC_Plan__c = '95103',
                FEC_Current_Balance__c = 27281279,
                FEC_IPP_Accrued_Interest__c = 1250391,
                FEC_Close_Fee_Amount__c = 2182502.32,
                FEC_Plan_Payment_Amount__c = 29463781.32
            );

            Test.startTest();
            List<Map<String, Object>> records = FEC_CardPaymentController.loadCardPaymentInfo(c.Id);
            Test.stopTest();

            System.assertEquals(1, records.size());
            System.assertEquals(
                30714172.32,
                (Decimal) records[0].get('FEC_Plan_Payment_Amount__c'),
                'UI phải dùng Plan Payment Amount tính runtime, không dùng giá trị stale trong DB.'
            );
            System.assertEquals(
                1250391,
                (Decimal) records[0].get('FEC_IPP_Accrued_Interest__c'),
                'IPP Accrued Interest phải hiển thị khi trong cửa sổ 4 ngày.'
            );
        }
    }

    @IsTest
    static void testLoadCardPaymentInfo_RuntimePlanPaymentAmount_OutsideIppWindow() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            FEC_Customer_History__c customer = [
                SELECT Id
                FROM FEC_Customer_History__c
                WHERE FEC_Case__c = :c.Id
                LIMIT 1
            ];
            customer.FEC_Next_Statement_Date__c = Date.today().addDays(10);
            update customer;

            delete [SELECT Id FROM FEC_Card_Payment__c];
            insert new FEC_Card_Payment__c(
                FEC_Customer_History__c = customer.Id,
                FEC_Rec__c = '001',
                FEC_Plan__c = '95103',
                FEC_Current_Balance__c = 27281279,
                FEC_IPP_Accrued_Interest__c = 1250391,
                FEC_Close_Fee_Amount__c = 2182502.32,
                FEC_Plan_Payment_Amount__c = 29463781.32
            );

            Test.startTest();
            List<Map<String, Object>> records = FEC_CardPaymentController.loadCardPaymentInfo(c.Id);
            Test.stopTest();

            System.assertEquals(1, records.size());
            System.assertEquals(
                29463781.32,
                (Decimal) records[0].get('FEC_Plan_Payment_Amount__c'),
                'Ngoài cửa sổ 4 ngày không cộng IPP vào Plan Payment Amount.'
            );
            System.assertEquals(null, records[0].get('FEC_IPP_Accrued_Interest__c'));
        }
    }

    @IsTest
    static void testLoadCardPaymentTotals_RuntimePlanPaymentAmount() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            FEC_Customer_History__c customer = [
                SELECT Id
                FROM FEC_Customer_History__c
                WHERE FEC_Case__c = :c.Id
                LIMIT 1
            ];
            customer.FEC_Next_Statement_Date__c = Date.today().addDays(1);
            update customer;

            delete [SELECT Id FROM FEC_Card_Payment__c];
            insert new List<FEC_Card_Payment__c>{
                new FEC_Card_Payment__c(
                    FEC_Customer_History__c = customer.Id,
                    FEC_Rec__c = '001',
                    FEC_Plan__c = '95103',
                    FEC_Current_Balance__c = 27281279,
                    FEC_IPP_Accrued_Interest__c = 1250391,
                    FEC_Close_Fee_Amount__c = 2182502.32,
                    FEC_Plan_Payment_Amount__c = 29463781.32
                ),
                new FEC_Card_Payment__c(
                    FEC_Customer_History__c = customer.Id,
                    FEC_Rec__c = '002',
                    FEC_Plan__c = '85103',
                    FEC_Current_Balance__c = 4257664,
                    FEC_Plan_Payment_Amount__c = 4257664
                )
            };

            Test.setMock(HttpCalloutMock.class, new TotalsThreeApisMock());

            Test.startTest();
            FEC_CardPaymentController.CardPaymentTotalsDTO totals =
                FEC_CardPaymentController.loadCardPaymentTotals(c.Id);
            Test.stopTest();

            System.assertEquals(34971836.32, totals.totalPlanPaymentAmount);
            System.assertEquals(1250391, totals.totalIPPAccruedInterest);
        }
    }

    @IsTest
    static void testLoadCardPaymentInfo_Acc0001500100007890040_RuntimeTotal() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            FEC_Customer_History__c customer = [
                SELECT Id
                FROM FEC_Customer_History__c
                WHERE FEC_Case__c = :c.Id
                LIMIT 1
            ];
            customer.FEC_Next_Statement_Date__c = Date.today().addDays(4);
            update customer;

            delete [SELECT Id FROM FEC_Card_Payment__c];
            insert new List<FEC_Card_Payment__c>{
                new FEC_Card_Payment__c(
                    FEC_Customer_History__c = customer.Id,
                    FEC_Rec__c = '003',
                    FEC_Plan__c = '60001',
                    FEC_Plan_Payment_Amount__c = 0
                ),
                new FEC_Card_Payment__c(
                    FEC_Customer_History__c = customer.Id,
                    FEC_Rec__c = '002',
                    FEC_Plan__c = '85103',
                    FEC_Plan_Payment_Amount__c = 0
                ),
                new FEC_Card_Payment__c(
                    FEC_Customer_History__c = customer.Id,
                    FEC_Rec__c = '001',
                    FEC_Plan__c = '95103',
                    FEC_Current_Balance__c = 46493704,
                    FEC_IPP_Accrued_Interest__c = 968617,
                    FEC_Close_Fee_Amount__c = 3719496.32,
                    FEC_Plan_Payment_Amount__c = 50213200.32
                )
            };

            Test.setMock(HttpCalloutMock.class, new CardPlanEmptyMock());

            Test.startTest();
            List<Map<String, Object>> records = FEC_CardPaymentController.loadCardPaymentInfo(c.Id);
            Test.stopTest();

            Decimal ippPlanAmount = null;
            Decimal ippAccruedInterest = null;
            for (Map<String, Object> row : records) {
                if (row.get('FEC_Rec__c') == '001') {
                    ippPlanAmount = (Decimal) row.get('FEC_Plan_Payment_Amount__c');
                    ippAccruedInterest = (Decimal) row.get('FEC_IPP_Accrued_Interest__c');
                }
            }

            System.assertEquals(51181817.32, ippPlanAmount);
            System.assertEquals(968617, ippAccruedInterest);
        }
    }

    @IsTest
    static void testLoadCardPaymentTotals_Acc0001500100007890040_RuntimeTotal() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            FEC_Customer_History__c customer = [
                SELECT Id
                FROM FEC_Customer_History__c
                WHERE FEC_Case__c = :c.Id
                LIMIT 1
            ];
            customer.FEC_Next_Statement_Date__c = Date.today().addDays(4);
            update customer;

            delete [SELECT Id FROM FEC_Card_Payment__c];
            insert new FEC_Card_Payment__c(
                FEC_Customer_History__c = customer.Id,
                FEC_Rec__c = '001',
                FEC_Plan__c = '95103',
                FEC_Current_Balance__c = 46493704,
                FEC_IPP_Accrued_Interest__c = 968617,
                FEC_Close_Fee_Amount__c = 3719496.32,
                FEC_Plan_Payment_Amount__c = 50213200.32
            );

            Test.setMock(HttpCalloutMock.class, new TotalsThreeApisMock());

            Test.startTest();
            FEC_CardPaymentController.CardPaymentTotalsDTO totals =
                FEC_CardPaymentController.loadCardPaymentTotals(c.Id);
            Test.stopTest();

            System.assertEquals(51181817.32, totals.totalPlanPaymentAmount);
            System.assertEquals(968617, totals.totalIPPAccruedInterest);
        }
    }

    @IsTest
    static void testLoadCardPaymentTotals_AllZeroWithRecords_ReturnsSummary() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            FEC_Customer_History__c customer = [
                SELECT Id
                FROM FEC_Customer_History__c
                WHERE FEC_Case__c = :c.Id
                LIMIT 1
            ];

            delete [SELECT Id FROM FEC_Card_Payment__c];
            insert new List<FEC_Card_Payment__c>{
                new FEC_Card_Payment__c(
                    FEC_Customer_History__c = customer.Id,
                    FEC_Rec__c = '002',
                    FEC_Plan__c = '60001',
                    FEC_Current_Balance__c = 0,
                    FEC_Plan_Payment_Amount__c = 0
                ),
                new FEC_Card_Payment__c(
                    FEC_Customer_History__c = customer.Id,
                    FEC_Rec__c = '001',
                    FEC_Plan__c = '60008',
                    FEC_Current_Balance__c = 0,
                    FEC_Plan_Payment_Amount__c = 0
                )
            };

            Test.setMock(HttpCalloutMock.class, new ZeroBalanceApisMock());

            Test.startTest();
            FEC_CardPaymentController.CardPaymentTotalsDTO totals =
                FEC_CardPaymentController.loadCardPaymentTotals(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, totals);
            System.assertEquals(0, totals.fullPaymentAmount);
            System.assertEquals(0, totals.loanBalance);
            System.assertEquals(0, totals.totalCurrentBalance);
            System.assertEquals(0, totals.totalPlanPaymentAmount);
        }
    }

    @IsTest
    static void testLoadCardPaymentTotals_AllZeroWithoutRecords_Throws() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            delete [SELECT Id FROM FEC_Card_Payment__c];
            Test.setMock(HttpCalloutMock.class, new ZeroBalanceApisMock());

            Test.startTest();
            try {
                FEC_CardPaymentController.loadCardPaymentTotals(c.Id);
                System.assert(false, 'Expected AuraHandledException when all-zero and no card payment records.');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e.getMessage());
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testShouldTreatAllZeroTotalsAsApiFailure() {
        FEC_CardPaymentController.CardPaymentTotalsDTO zeroDto = new FEC_CardPaymentController.CardPaymentTotalsDTO();
        System.assertEquals(true, FEC_CardPaymentController.isAllCardPaymentTotalsZero(zeroDto));

        FEC_Customer_History__c customer = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];
        System.assertEquals(true, FEC_CardPaymentController.hasCardPaymentRecords(customer.Id));
        System.assertEquals(
            false,
            FEC_CardPaymentController.shouldTreatAllZeroTotalsAsApiFailure(customer.Id, zeroDto)
        );
    }
}
