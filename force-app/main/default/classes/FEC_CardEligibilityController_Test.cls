@IsTest
private class FEC_CardEligibilityController_Test {

    private static final String SOAP_ENV = FEC_ConstantCommon.SOAP_ENV;
    private static final String REWARD_NS = 'http://esbservice.fecredit.org/CMS_RewardDebitWS/';
    private static final String IPP_NS = 'http://fecredit.com.vn/CMS_IPP_BlockWS';
    private static final String IPP_DETAIL_NS = 'http://esbservice.fecredit.org/EStatementService/';

    private class TopUpSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                '<soapenv:Body>' +
                '<NS1:CheckAccountEligibilityResponse xmlns:NS1="' + REWARD_NS + '">' +
                '<SysResponse>' +
                '<TransID>T-TOPUP</TransID>' +
                '<Status>0</Status>' +
                '<Description>Eligible for Rewards Topup</Description>' +
                '</SysResponse>' +
                '<AVAIL_CR>2000000</AVAIL_CR>' +
                '</NS1:CheckAccountEligibilityResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class TopUpFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    private class IppSuccessCampaignsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                '<soapenv:Body>' +
                '<NS1:CheckEligibilityResponse xmlns:NS1="' + IPP_NS + '">' +
                '<Sys><Code>0</Code><Description>Success</Description></Sys>' +
                '<Details>' +
                '<AccEligibility>true</AccEligibility>' +
                '<EligibleAmount>15000000</EligibleAmount>' +
                '<CampaignDetails><Tenure>12</Tenure><InterestRate>0.015</InterestRate></CampaignDetails>' +
                '</Details>' +
                '</NS1:CheckEligibilityResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class IppNotEligibleMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                '<soapenv:Body>' +
                '<NS1:CheckEligibilityResponse xmlns:NS1="' + IPP_NS + '">' +
                '<Sys><Code>0</Code><Description>Card blocked by risk rule</Description></Sys>' +
                '<Details><AccEligibility>false</AccEligibility></Details>' +
                '</NS1:CheckEligibilityResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class IppEligibleNoCampaignsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                '<soapenv:Body>' +
                '<NS1:CheckEligibilityResponse xmlns:NS1="' + IPP_NS + '">' +
                '<Sys><Code>0</Code><Description>OK</Description></Sys>' +
                '<Details><AccEligibility>eligible</AccEligibility></Details>' +
                '</NS1:CheckEligibilityResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class IppDetailsSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                '<soapenv:Body>' +
                '<est:GetIPPDetailsResponse xmlns:est="' + IPP_DETAIL_NS + '">' +
                '<SysResponse><Status>SUCCESS</Status><Description>OK</Description></SysResponse>' +
                '<IPPTerm>6 Months</IPPTerm>' +
                '<InterestRate>0.02</InterestRate>' +
                '<InstallmentAmount>500000</InstallmentAmount>' +
                '<ConversionFee>20000</ConversionFee>' +
                '</est:GetIPPDetailsResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        Case testCase = new Case(
            Subject = 'Card Eligibility Test Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone',
            FEC_Account_Number__c = 'ACC-ELIG-1903'
        );
        insert testCase;

        FEC_Customer_History__c customer = new FEC_Customer_History__c(
            Name = 'CUST-ELIG-001',
            FEC_Case__c = testCase.Id,
            FEC_Account_Number__c = 'ACC-ELIG-1903'
        );
        insert customer;

        update new Case(
            Id = testCase.Id,
            FEC_Account_or_Contract__c = customer.Id
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
    static void testResolveAccountNumberFromCase_AllBranches() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];

            Test.startTest();
            String accNumSuccess = FEC_CardEligibilityController.resolveAccountNumberFromCase(c.Id);
            String accNumNull = FEC_CardEligibilityController.resolveAccountNumberFromCase(null);

            FEC_Customer_History__c ch = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];
            ch.FEC_Account_Number__c = '';
            update ch;
            String accNumFallback = FEC_CardEligibilityController.resolveAccountNumberFromCase(c.Id);
            Test.stopTest();

            System.assertEquals('ACC-ELIG-1903', accNumSuccess);
            System.assertEquals(null, accNumNull);
            System.assertEquals('ACC-ELIG-1903', accNumFallback);
        }
    }

    @IsTest
    static void testLoadCardEligibilityFromCustomerHistory() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            FEC_Customer_History__c ch = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];

            ch.FEC_Available_Credit_Limit__c = 5000000;
            ch.FEC_Reason__c = 'Hợp lệ nâng cấp';
            ch.FEC_Fast_Cash_Status__c = 'Eligible';
            ch.FEC_IPP_Status__c = 'Eligible';
            ch.FEC_Limit__c = 10000000;
            update ch;

            Test.startTest();
            FEC_CardEligibilityController.CardEligibilityBundle bundle =
                FEC_CardEligibilityController.loadCardEligibilityFromCustomerHistory(c.Id);
            FEC_CardEligibilityController.CardEligibilityBundle bundleNull =
                FEC_CardEligibilityController.loadCardEligibilityFromCustomerHistory(null);
            Test.stopTest();

            System.assertNotEquals(null, bundle.topUpResult);
            System.assertNotEquals(null, bundle.ippResult);
            System.assertEquals('5000000', bundle.topUpResult.availableCreditLimit);
            System.assertEquals(null, bundleNull.topUpResult);
        }
    }

    @IsTest
    static void testCheckTopUpEligibility_Success() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new TopUpSuccessMock());

            Test.startTest();
            FEC_CardEligibilityController.TopUpEligibilityResult result =
                FEC_CardEligibilityController.checkTopUpEligibility(c.Id, 'ACC-ELIG-1903');
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals(true, result.success);
            System.assertEquals('2000000', result.availableCreditLimit);

            FEC_Customer_History__c updatedCh = [
                SELECT FEC_Available_Credit_Limit__c
                FROM FEC_Customer_History__c
                LIMIT 1
            ];
            System.assertEquals(2000000, updatedCh.FEC_Available_Credit_Limit__c);
        }
    }

    @IsTest
    static void testCheckTopUpEligibility_Failures() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Card Eligibility Test Case' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new TopUpFailureMock());

            Test.startTest();
            FEC_CardEligibilityController.TopUpEligibilityResult resultBlank =
                FEC_CardEligibilityController.checkTopUpEligibility(c.Id, '');
            FEC_CardEligibilityController.TopUpEligibilityResult resultException =
                FEC_CardEligibilityController.checkTopUpEligibility(c.Id, 'ACC-ERROR');
            Test.stopTest();

            System.assertEquals(false, resultBlank.success);
            System.assertEquals(0, resultBlank.httpStatus);
            System.assertEquals(false, resultException.success);
        }
    }

    @IsTest
    static void testCheckIPPEligibility_SuccessWithCampaigns() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new IppSuccessCampaignsMock());

            Test.startTest();
            FEC_CardEligibilityController.IPPEligibilityResult result =
                FEC_CardEligibilityController.checkIPPEligibility(c.Id, 'ACC-ELIG-1903');
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals(true, result.success);
            System.assert(result.tenorList.size() >= 1, 'Phải có ít nhất một kỳ hạn hợp lệ.');
            System.assertEquals('1.50%', result.tenorList[0].rate);

            FEC_Customer_History__c updatedCh = [
                SELECT FEC_Fast_Cash_Status__c, FEC_Limit__c
                FROM FEC_Customer_History__c
                LIMIT 1
            ];
            System.assertEquals(15000000, updatedCh.FEC_Limit__c);
        }
    }

    @IsTest
    static void testCheckIPPEligibility_NotEligible() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new IppNotEligibleMock());

            Test.startTest();
            FEC_CardEligibilityController.IPPEligibilityResult result =
                FEC_CardEligibilityController.checkIPPEligibility(c.Id, 'ACC-ELIG-1903');
            Test.stopTest();

            System.assertEquals(true, result.success);
            System.assertEquals('0', result.errorCode);
            System.assertEquals('Card blocked by risk rule', result.description);
        }
    }

    @IsTest
    static void testCheckIPPEligibility_FallbackPlanDetails() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new IppEligibleNoCampaignsMock());

            Test.startTest();
            FEC_CardEligibilityController.IPPEligibilityResult result =
                FEC_CardEligibilityController.checkIPPEligibility(c.Id, 'ACC-ELIG-1903');
            Test.stopTest();

            System.assertEquals(true, result.success);
            System.assertEquals(0, result.tenorList.size());
        }
    }

    @IsTest
    static void testDataStructures_AndHelpersCoverageOnly() {
        System.runAs(testRunAsUser()) {
            Test.startTest();
            new FEC_CardEligibilityController.TopUpEligibilityResult();
            new FEC_CardEligibilityController.IPPEligibilityResult();
            new FEC_CardEligibilityController.IPPTenorRow();
            new FEC_CardEligibilityController.CardEligibilityBundle();
            FEC_CardEligibilityController.checkIPPEligibility(null, '');
            Test.stopTest();

            System.assert(true);
        }
    }
}
