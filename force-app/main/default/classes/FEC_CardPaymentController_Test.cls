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
                '<BaseRate>12.5</BaseRate><CloseFeelIndicator>Y</CloseFeelIndicator>' +
                '<CloseFeelIndicatorAmount>100000</CloseFeelIndicatorAmount>' +
                '<PlanPaymentAmount>500000</PlanPaymentAmount>' +
                '<AccruedInterest>30000</AccruedInterest><PerDiem>2000</PerDiem>' +
                '<DeferredInterest>10000</DeferredInterest><AccruedInt>4000</AccruedInt>' +
                '</CardPlan>' +
                '<CardPlan><RecordNumber>REC01</RecordNumber><PlanNumber>PLAN01</PlanNumber></CardPlan>' +
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

    private class TotalsFourApisMock implements HttpCalloutMock {
        private Integer callSeq = 0;

        public HttpResponse respond(HttpRequest req) {
            callSeq++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (callSeq == 1) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                    '<soapenv:Body><cif:GetCardPaymentInfoResponse xmlns:cif="' + CIF_NS + '">' +
                    '<Sys><Code>1</Code></Sys>' +
                    '<PaymentInfo><FullPaymentAmount>15000000</FullPaymentAmount></PaymentInfo>' +
                    '</cif:GetCardPaymentInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
            } else if (callSeq == 2) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                    '<soapenv:Body>' +
                    '<cif:GetCardBasicInfoResponse xmlns:cif="' + CIF_NS + '">' +
                    '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                    '<CardBasicInfo><MainCard><LoanBalance>3000000</LoanBalance></MainCard></CardBasicInfo>' +
                    '</cif:GetCardBasicInfoResponse>' +
                    '</soapenv:Body></soapenv:Envelope>'
                );
            } else if (callSeq == 3) {
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
            List<Map<String, Object>> result1 = FEC_CardPaymentController.loadCardPaymentInfo(c.Id);
            List<Map<String, Object>> result2 = FEC_CardPaymentController.getCardPaymentRecords(String.valueOf(c.Id));
            Test.stopTest();

            System.assertNotEquals(null, result1);
            System.assert(result1.size() >= 2);
            FEC_Card_Payment__c checkInserted = [
                SELECT FEC_Close_Fee__c FROM FEC_Card_Payment__c WHERE FEC_Rec__c = 'REC02' LIMIT 1
            ];
            System.assertEquals(2.00, checkInserted.FEC_Close_Fee__c);
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
            FEC_Card_Payment__c paymentRow = [SELECT Id FROM FEC_Card_Payment__c LIMIT 1];
            paymentRow.FEC_Full_Payment_Amount__c = 12000000;
            paymentRow.FEC_Loan_Balance__c = 2000000;
            update paymentRow;

            Test.startTest();
            FEC_CardPaymentController.CardPaymentTotalsDTO totals =
                FEC_CardPaymentController.loadCardPaymentTotals(c.Id);
            FEC_CardPaymentController.CardPaymentTotalsDTO totalsWrapper =
                FEC_CardPaymentController.getCardPaymentTotals(String.valueOf(c.Id));
            Test.stopTest();

            System.assertNotEquals(null, totals);
            System.assertEquals(12000000, totals.fullPaymentAmount);
            System.assertEquals(1000000, totals.totalCurrentBalance);
            System.assertEquals(50000, totals.totalCloseFeeAmount);
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
    static void testLoadCardPaymentTotals_CallFourApisSequential() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            delete [SELECT Id FROM FEC_Card_Payment__c];
            Test.setMock(HttpCalloutMock.class, new TotalsFourApisMock());

            Test.startTest();
            FEC_CardPaymentController.CardPaymentTotalsDTO totals =
                FEC_CardPaymentController.loadCardPaymentTotals(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, totals);
            System.assertEquals(15000000, totals.fullPaymentAmount);
            System.assertEquals(3000000, totals.loanBalance);
            System.assertEquals(7400600, totals.fullPaymentWithoutIPP);
            System.assertEquals(7599400, totals.fullIPPPaymentAmount);
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
}
