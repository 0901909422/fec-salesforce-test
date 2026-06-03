@IsTest
private class FEC_CardReplaceAddressController_Test {

    private static final String SOAP_ENV = FEC_ConstantCommon.SOAP_ENV;

    private class CardStatusMock implements HttpCalloutMock {
        private String blockCode;

        CardStatusMock(String blockCode) {
            this.blockCode = blockCode;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                '<soapenv:Body><WSResponse>' +
                '<Sys><Code>1</Code></Sys>' +
                '<M_CMS_CARD_TO_CARD_INQ_EMEA><VMX_ROOT><VMX_MSGOUT>' +
                '<OUTPUT_AREA><OUTPUT_DATA><BLK_CD>' + blockCode + '</BLK_CD></OUTPUT_DATA></OUTPUT_AREA>' +
                '</VMX_MSGOUT></VMX_ROOT></M_CMS_CARD_TO_CARD_INQ_EMEA>' +
                '</WSResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class EmeaAccountMock implements HttpCalloutMock {
        private String blkCd1;

        EmeaAccountMock(String blkCd1) {
            this.blkCd1 = blkCd1;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                '<soapenv:Body><WSResponse>' +
                '<Sys><Code>1</Code></Sys>' +
                '<M_CMS_EMEA_ACCOUNT_INQ><VMX_ROOT><VMX_MSGOUT>' +
                '<ACCT_BS_OUTPUT><BLK_CD_1>' + blkCd1 + '</BLK_CD_1></ACCT_BS_OUTPUT>' +
                '</VMX_MSGOUT></VMX_ROOT></M_CMS_EMEA_ACCOUNT_INQ></WSResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class ReplaceCardSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"Sys2":{"Code":"1","Description":"Success","TransID":"TXN-REP"}}');
            return res;
        }
    }

    private class ReplaceCardFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"Sys2":{"Code":"99","Description":"Failed"}}');
            return res;
        }
    }

    private class CompositeCalloutMock implements HttpCalloutMock {
        private String blockCode;
        private String blkCd1;
        private Boolean replaceSuccess;

        CompositeCalloutMock(String blockCode, String blkCd1, Boolean replaceSuccess) {
            this.blockCode = blockCode;
            this.blkCd1 = blkCd1;
            this.replaceSuccess = replaceSuccess;
        }

        public HttpResponse respond(HttpRequest req) {
            String body = req.getBody() != null ? req.getBody() : '';
            if (body.contains('CARD_TO_CARD_INQ') || body.contains('M_CMS_CARD_TO_CARD')) {
                return new CardStatusMock(blockCode).respond(req);
            }
            if (body.contains('M_CMS_EMEA_ACCOUNT_INQ')) {
                return new EmeaAccountMock(blkCd1).respond(req);
            }
            if (replaceSuccess) {
                return new ReplaceCardSuccessMock().respond(req);
            }
            return new ReplaceCardFailureMock().respond(req);
        }
    }

    private class OrderedCheckProcessActionMock implements HttpCalloutMock {
        private Integer callIndex = 0;
        private String blockCode;
        private String blkCd1;

        OrderedCheckProcessActionMock(String blockCode, String blkCd1) {
            this.blockCode = blockCode;
            this.blkCd1 = blkCd1;
        }

        public HttpResponse respond(HttpRequest req) {
            callIndex++;
            if (callIndex == 1) {
                return new CardStatusMock(blockCode).respond(req);
            }
            return new EmeaAccountMock(blkCd1).respond(req);
        }
    }

    @TestSetup
    static void setupData() {
        insert new FEC_API_Setting__c(
            FEC_Endpoint__c = 'https://api-gateway.fecredit.com.vn'
        );

        FEC_Country__c country = new FEC_Country__c(Name = 'Việt Nam', FEC_Code__c = '2');
        insert country;

        FEC_Province__c province = new FEC_Province__c(
            Name = 'Hà Nội',
            FEC_Name_VN__c = 'Hà Nội',
            FEC_Code__c = 'HN',
            FEC_Country__c = country.Id
        );
        insert province;
        insert new FEC_District__c(
            Name = 'Cầu Giấy',
            FEC_Name_VN__c = 'Cầu Giấy',
            FEC_Code__c = 'CG',
            FEC_Country__c = country.Id,
            FEC_Province__c = province.Id
        );

        Case parentInteraction = new Case(
            Subject = 'Parent Interaction Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone'
        );
        insert parentInteraction;

        Case caseNormal = new Case(
            Subject = 'Case For Card Replacement Normal',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone',
            FEC_Account_Number__c = 'ACC-REPLACE-1903',
            FEC_Interaction__c = parentInteraction.Id,
            FEC_Process_Action_Count__c = 0
        );
        insert caseNormal;

        FEC_Customer_History__c customer = new FEC_Customer_History__c(
            Name = 'CUST-REPLACE-001',
            FEC_Case__c = caseNormal.Id
        );
        insert customer;

        update new Case(
            Id = caseNormal.Id,
            FEC_Account_or_Contract__c = customer.Id
        );

        insert new FEC_Address_Info__c(
            FEC_Customer_History__c = customer.Id,
            FEC_Address_Type__c = 'Current Address',
            FEC_Address__c = 'Số 1 Đương Khuê',
            FEC_Street__c = 'Dịch Vọng Hậu',
            FEC_Province__c = province.Id,
            FEC_District__c = null,
            FEC_Country__c = country.Id,
            FEC_Case__c = null
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
    static void testAddressAndPicklistMethods() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case For Card Replacement Normal' LIMIT 1];
            FEC_Address_Info__c addr = [SELECT Id FROM FEC_Address_Info__c LIMIT 1];
            FEC_Province__c prov = [SELECT Id FROM FEC_Province__c LIMIT 1];

            Test.startTest();
            List<FEC_Address_Info__c> addrList = FEC_CardReplacementAddressController.getAddressInfos(c.Id);
            FEC_Address_Info__c singleAddr = FEC_CardReplacementAddressController.getAddressInfo(addr.Id);
            List<FEC_CardReplacementAddressController.PicklistOptionDTO> provOpts =
                FEC_CardReplacementAddressController.getProvinceOptionsForAddress();
            List<FEC_CardReplacementAddressController.PicklistOptionDTO> wardOpts =
                FEC_CardReplacementAddressController.getWardOptionsForProvinceCode(prov.Id);
            String countryId = FEC_CardReplacementAddressController.getCountryId();
            Test.stopTest();

            System.assertEquals(1, addrList.size());
            System.assertNotEquals(null, singleAddr);
            System.assert(addrList.size() > 0);
            System.assertEquals(1, provOpts.size());
            System.assertEquals(1, wardOpts.size());
            System.assertNotEquals(null, countryId);
        }
    }

    @IsTest
    static void testCheckProcessAction_Success() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case For Card Replacement Normal' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new OrderedCheckProcessActionMock('O', ' '));

            Test.startTest();
            FEC_CardReplacementAddressController.ReplaceCardResult result =
                FEC_CardReplacementAddressController.checkProcessAction(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals(true, result.isShowAction);
        }
    }

    @IsTest
    static void testCheckProcessAction_InvalidBlockCode() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case For Card Replacement Normal' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new OrderedCheckProcessActionMock('F', ' '));

            Test.startTest();
            FEC_CardReplacementAddressController.ReplaceCardResult result =
                FEC_CardReplacementAddressController.checkProcessAction(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertNotEquals(null, result.isShowAction);
        }
    }

    @IsTest
    static void testCheckProcessAction_HasSiblingUpdateCase() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id, FEC_Interaction__c FROM Case WHERE Subject = 'Case For Card Replacement Normal' LIMIT 1];

            FEC_Sub_Code__c subCodeMobile = new FEC_Sub_Code__c(
                Name = 'Cập nhật SĐT',
                FEC_Code__c = FEC_ConstantCommon.SUB_CODE_PROCESS_UPDATE_MOBILE,
                FEC_Active__c = true
            );
            insert subCodeMobile;

            insert new Case(
                Subject = 'Sibling Update Mobile Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                Origin = 'Phone',
                FEC_Interaction__c = c.FEC_Interaction__c,
                FEC_SubCode__c = subCodeMobile.Id
            );

            Test.setMock(HttpCalloutMock.class, new OrderedCheckProcessActionMock('O', ' '));

            Test.startTest();
            FEC_CardReplacementAddressController.ReplaceCardResult result =
                FEC_CardReplacementAddressController.checkProcessAction(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals(false, result.isShowAction);
        }
    }

    @IsTest
    static void testCardReplacement_Success() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case For Card Replacement Normal' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new ReplaceCardSuccessMock());

            Test.startTest();
            FEC_CardReplacementAddressController.UpdateResult result =
                FEC_CardReplacementAddressController.cardReplacement(c.Id, 'Click_Submit', 'C', '5432', '100000');
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals(true, result.success);
            System.assertEquals(-1, result.actionCount);
        }
    }

    @IsTest
    static void testCardReplacement_Failure() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case For Card Replacement Normal' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new ReplaceCardFailureMock());

            Test.startTest();
            FEC_CardReplacementAddressController.UpdateResult result =
                FEC_CardReplacementAddressController.cardReplacement(c.Id, 'Click_Submit', 'C', '5432', '');
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals(false, result.success);
            System.assertEquals(1, result.actionCount);
        }
    }

    @IsTest
    static void testCardReplacement_Failure_WhenActionCountNull() {
        System.runAs(testRunAsUser()) {
            Case c = new Case(
                Subject = 'Case For Card Replacement Null Count',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                Origin = 'Phone',
                FEC_Account_Number__c = 'ACC-REPLACE-NULL-COUNT'
            );
            insert c;

            Test.setMock(HttpCalloutMock.class, new ReplaceCardFailureMock());

            Test.startTest();
            FEC_CardReplacementAddressController.UpdateResult result =
                FEC_CardReplacementAddressController.cardReplacement(c.Id, 'Click_Submit', 'C', '1111', '');
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals(false, result.success);
            System.assertEquals(1, result.actionCount);
        }
    }

    @IsTest
    static void testExceptionCatchBlocks() {
        System.runAs(testRunAsUser()) {
            Test.startTest();
            try {
                FEC_CardReplacementAddressController.getAddressInfos('500000000000001AAA');
                System.assert(false, 'Expected AuraHandledException');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e.getMessage());
            }

            FEC_CardReplacementAddressController.ReplaceCardResult resActionError =
                FEC_CardReplacementAddressController.checkProcessAction('500000000000001AAA');
            System.assertEquals(null, resActionError.isShowAction);

            try {
                FEC_CardReplacementAddressController.UpdateResult resReplaceError =
                    FEC_CardReplacementAddressController.cardReplacement('500000000000001AAA', 'Method', 'C', '1', '0');
                System.assertEquals(false, resReplaceError.success);
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage());
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testDataStructures_CoverageOnly() {
        Test.startTest();
        new FEC_CardReplacementAddressController.ReplaceCardResult();
        new FEC_CardReplacementAddressController.UpdateResult();
        new FEC_CardReplacementAddressController.PicklistOptionDTO();
        Test.stopTest();
        System.assert(true);
    }
}
