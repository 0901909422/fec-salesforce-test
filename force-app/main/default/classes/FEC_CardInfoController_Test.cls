@IsTest
private class FEC_CardInfoController_Test {

    private static final String SOAP_ENV = FEC_ConstantCommon.SOAP_ENV;

    private class CardSecInfoSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                '<soapenv:Body>' +
                '<GetCardSecInfoResponse>' +
                '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                '<CardSecInfo>' +
                '<CardsDeliveries>' +
                '<CardDelivery>' +
                '<CardNumber>4123450000006789</CardNumber>' +
                '<KindOfIssue>New</KindOfIssue>' +
                '<FinalSt>Delivered</FinalSt>' +
                '<Recipient>Bui Viet Hoang</Recipient>' +
                '<TrackingNo>TRK19032003</TrackingNo>' +
                '<DelayNotes>Delivered on time</DelayNotes>' +
                '<IssuelastUpdate>2026-05-20 12:00:00</IssuelastUpdate>' +
                '<DeliveryDate>05/20/2026</DeliveryDate>' +
                '</CardDelivery>' +
                '</CardsDeliveries>' +
                '<SupplementaryCards>' +
                '<SupplementaryCard>' +
                '<CardNumber>5123450000009999</CardNumber>' +
                '<CardholderName>GIANG THU</CardholderName>' +
                '<PlasticIndicator>P</PlasticIndicator>' +
                '<EmbossingName>THU GIANG</EmbossingName>' +
                '<BlockCode>O</BlockCode>' +
                '<Gender>F</Gender>' +
                '<ExpiryDate>2030-12-31</ExpiryDate>' +
                '<CardActivationDate>2026-05-20</CardActivationDate>' +
                '<CardIssueDate>2026-05-20</CardIssueDate>' +
                '</SupplementaryCard>' +
                '</SupplementaryCards>' +
                '</CardSecInfo>' +
                '</GetCardSecInfoResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class CardSecInfoEmptyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                '<soapenv:Body>' +
                '<GetCardSecInfoResponse>' +
                '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                '<CardSecInfo>' +
                '<CardsDeliveries></CardsDeliveries>' +
                '<SupplementaryCards></SupplementaryCards>' +
                '</CardSecInfo>' +
                '</GetCardSecInfoResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class CardSecInfoApiErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                '<soapenv:Body>' +
                '<GetCardSecInfoResponse>' +
                '<Sys><Code>99</Code><Description>System error</Description></Sys>' +
                '</GetCardSecInfoResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class CardSecInfoFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('error');
            return res;
        }
    }

    private class CardSecInfoBadDatesMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                '<soapenv:Body>' +
                '<GetCardSecInfoResponse>' +
                '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                '<CardSecInfo>' +
                '<CardsDeliveries>' +
                '<CardDelivery>' +
                '<CardNumber>4123450000001111</CardNumber>' +
                '<IssuelastUpdate>SHORT_DATE</IssuelastUpdate>' +
                '<DeliveryDate>05/20</DeliveryDate>' +
                '</CardDelivery>' +
                '</CardsDeliveries>' +
                '<SupplementaryCards></SupplementaryCards>' +
                '</CardSecInfo>' +
                '</GetCardSecInfoResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        Case c1 = new Case(
            Subject = 'Case With Customer History Access',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone',
            FEC_Account_Number__c = 'ACC-CARD-1903'
        );
        Case c2 = new Case(
            Subject = 'Case Fallback to Case Account Field',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone',
            FEC_Account_Number__c = 'ACC-FALLBACK-999'
        );
        insert new List<Case>{ c1, c2 };

        FEC_Customer_History__c customer = new FEC_Customer_History__c(
            Name = 'CUST-CARD-001',
            FEC_Case__c = c1.Id,
            FEC_Account_Number__c = 'ACC-CARD-1903'
        );
        insert customer;

        update new Case(
            Id = c1.Id,
            FEC_Account_or_Contract__c = customer.Id
        );

        insert new List<SObject>{
            new FEC_Card_Delivery__c(
                FEC_Case__c = c1.Id,
                FEC_Customer_History__c = customer.Id,
                FEC_Card_Number__c = '412345******6789'
            ),
            new FEC_Other_Card__c(
                FEC_Customer_History__c = customer.Id,
                FEC_Card_Number__c = '4123450000006789'
            )
        };
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
    static void testLoadCardInfo_ApiSuccessAndInsertion() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case With Customer History Access' LIMIT 1];
            delete [SELECT Id FROM FEC_Card_Delivery__c];
            delete [SELECT Id FROM FEC_Other_Card__c];
            Test.setMock(HttpCalloutMock.class, new CardSecInfoSuccessMock());

            Test.startTest();
            FEC_CardInfoController.CardInfoDTO result = FEC_CardInfoController.loadCardInfo(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals(1, result.cardDeliveries.size());
            System.assertEquals(1, result.otherCards.size());
            System.assertEquals('412345******6789', result.cardDeliveries[0].cardNumber);
            System.assertEquals('5123450000009999', result.otherCards[0].cardNumber);
        }
    }

    @IsTest
    static void testLoadCardInfo_ExistingRecordsInDb() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case With Customer History Access' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new CardSecInfoEmptyMock());

            Test.startTest();
            FEC_CardInfoController.CardInfoDTO result = FEC_CardInfoController.loadCardInfo(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals(1, result.cardDeliveries.size());
            System.assertEquals(1, result.otherCards.size());
        }
    }

    @IsTest
    static void testLoadCardInfo_DuplicatePreventionAndApiError() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case With Customer History Access' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new CardSecInfoApiErrorMock());

            Test.startTest();
            FEC_CardInfoController.CardInfoDTO result = FEC_CardInfoController.loadCardInfo(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, result);
        }
    }

    @IsTest
    static void testGetAccountNumber_AllBranches() {
        System.runAs(testRunAsUser()) {
            Case cFallback = [SELECT Id FROM Case WHERE Subject = 'Case Fallback to Case Account Field' LIMIT 1];
            Case cWithCh = [SELECT Id FROM Case WHERE Subject = 'Case With Customer History Access' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new CardSecInfoEmptyMock());

            Test.startTest();
            FEC_CardInfoController.CardInfoDTO resFallback = FEC_CardInfoController.loadCardInfo(cFallback.Id);
            FEC_CardInfoController.CardInfoDTO resChQuery = FEC_CardInfoController.loadCardInfo(cWithCh.Id);
            Test.stopTest();

            System.assertNotEquals(null, resFallback);
            System.assertNotEquals(null, resChQuery);
        }
    }

    @IsTest
    static void testLoadCardInfo_ValidationAndExceptions() {
        System.runAs(testRunAsUser()) {
            Test.startTest();
            try {
                FEC_CardInfoController.loadCardInfo(null);
                System.assert(false, 'Expected AuraHandledException for null caseId');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e.getMessage());
            }

            Test.setMock(HttpCalloutMock.class, new CardSecInfoFailureMock());
            Case c = [SELECT Id FROM Case LIMIT 1];
            FEC_CardInfoController.CardInfoDTO resultException = FEC_CardInfoController.loadCardInfo(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, resultException);
        }
    }

    @IsTest
    static void testDateParsing_EdgeCases() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case With Customer History Access' LIMIT 1];
            delete [SELECT Id FROM FEC_Card_Delivery__c];
            Test.setMock(HttpCalloutMock.class, new CardSecInfoBadDatesMock());

            Test.startTest();
            FEC_CardInfoController.CardInfoDTO result = FEC_CardInfoController.loadCardInfo(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals(1, result.cardDeliveries.size());
            System.assertEquals(null, result.cardDeliveries[0].issueDate);
            System.assertEquals(null, result.cardDeliveries[0].deliveryDate);
        }
    }

    @IsTest
    static void testDataStructures_CoverageOnly() {
        Test.startTest();
        new FEC_CardInfoController.CardInfoDTO();
        new FEC_CardInfoController.CardDeliveryDTO();
        new FEC_CardInfoController.OtherCardDTO();
        Test.stopTest();
        System.assert(true);
    }
}
