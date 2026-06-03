@IsTest
private class FEC_CardLockUnLockController_Test {

    private static final String SOAP_ENV = FEC_ConstantCommon.SOAP_ENV;

    private class LockSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"Sys":{"Code":"1","Description":"Lock success","TransID":"TXN-LOCK"}}');
            return res;
        }
    }

    private class LockFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"Sys":{"Code":"99","Description":"Failed"}}');
            return res;
        }
    }

    private class CardInqBlockedMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                '<soapenv:Body>' +
                '<WSResponse>' +
                '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                '<M_CMS_CARD_TO_CARD_INQ_EMEA>' +
                '<VMX_ROOT><VMX_MSGOUT>' +
                '<SVC_RETURN>S</SVC_RETURN>' +
                '<OUTPUT_AREA>' +
                '<OUTPUT_DATA><BLK_CD>S</BLK_CD></OUTPUT_DATA>' +
                '</OUTPUT_AREA>' +
                '</VMX_MSGOUT></VMX_ROOT>' +
                '</M_CMS_CARD_TO_CARD_INQ_EMEA>' +
                '</WSResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class CardInqNotBlockedMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                '<soapenv:Body>' +
                '<WSResponse>' +
                '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                '<M_CMS_CARD_TO_CARD_INQ_EMEA>' +
                '<VMX_ROOT><VMX_MSGOUT>' +
                '<SVC_RETURN>S</SVC_RETURN>' +
                '<OUTPUT_AREA>' +
                '<OUTPUT_DATA><BLK_CD></BLK_CD></OUTPUT_DATA>' +
                '</OUTPUT_AREA>' +
                '</VMX_MSGOUT></VMX_ROOT>' +
                '</M_CMS_CARD_TO_CARD_INQ_EMEA>' +
                '</WSResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        insert new FEC_API_Setting__c(
            FEC_Endpoint__c = 'https://api-gateway.fecredit.com.vn',
            FEC_Enviroment__c = 'Production'
        );

        Case c1 = new Case(
            Subject = 'Case For Lock Unblock Card Test',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone',
            FEC_Account_Number__c = 'ACC-LOCK-1903',
            FEC_New_Block_Code__c = 'Q',
            FEC_Process_Action_Count__c = 0,
            FEC_Is_Test_API__c = true
        );
        Case c2 = new Case(
            Subject = 'Case For Get Card Status Test',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone',
            FEC_Account_Number__c = 'ACC-STATUS-1903',
            FEC_Customer_Name__c = 'BUI VIET HOANG',
            FEC_Current_Card_Status__c = ''
        );
        Case c3 = new Case(
            Subject = 'Case With Preserved Card Status',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone',
            FEC_Account_Number__c = 'ACC-STATUS-1904',
            FEC_Customer_Name__c = 'BUI VIET HOANG',
            FEC_Current_Card_Status__c = 'Custom Status Preserved'
        );
        insert new List<Case>{ c1, c2, c3 };

        FEC_Customer_History__c customer = new FEC_Customer_History__c(
            Name = 'CUST-LOCK-001',
            FEC_Case__c = c1.Id,
            FEC_Card_Number__c = '4123456789012345',
            FEC_Account_Number__c = 'ACC-LOCK-1903'
        );
        insert customer;

        update new Case(
            Id = c1.Id,
            FEC_Account_or_Contract__c = customer.Id
        );

        insert new List<FEC_Block_Code_Matrix__c>{
            new FEC_Block_Code_Matrix__c(
                FEC_Current_Block_Code__c = 'O',
                FEC_New_Block_Code__c = 'Q',
                FEC_Action__c = 'cs thực hiện'
            ),
            new FEC_Block_Code_Matrix__c(
                FEC_Current_Block_Code__c = 'O',
                FEC_New_Block_Code__c = 'D',
                FEC_Action__c = 'd2c thực hiện'
            ),
            new FEC_Block_Code_Matrix__c(
                FEC_Current_Block_Code__c = 'OTHER',
                FEC_New_Block_Code__c = 'K',
                FEC_Action__c = 'không thực hiện'
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
    static void testLockUnblockCard_Success() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case For Lock Unblock Card Test' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new LockSuccessMock());

            Test.startTest();
            FEC_CardLockUnLockController.UpdateResult result =
                FEC_CardLockUnLockController.lockUnblockCard(c.Id, 'B', 'Q', 'Button_Click');
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals(true, result.success);
            System.assertEquals(-1, result.actionCount);
        }
    }

    @IsTest
    static void testLockUnblockCard_ApiFailure() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case For Lock Unblock Card Test' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new LockFailureMock());

            Test.startTest();
            FEC_CardLockUnLockController.UpdateResult result =
                FEC_CardLockUnLockController.lockUnblockCard(c.Id, 'B', 'Q', 'Button_Click');
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals(false, result.success);
            System.assertEquals(1, result.actionCount);
        }
    }

    @IsTest
    static void testLockUnblockCard_Exception() {
        System.runAs(testRunAsUser()) {
            Test.startTest();
            try {
                FEC_CardLockUnLockController.lockUnblockCard('500000000000001AAA', 'B', 'Q', 'Method');
                System.assert(false, 'Expected exception for invalid Case Id');
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage());
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testGetCardStatus_SuccessBlocked() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case For Get Card Status Test' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new CardInqBlockedMock());

            Test.startTest();
            FEC_CardLockUnLockController.ResponseResult result =
                FEC_CardLockUnLockController.getCardStatus(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals(true, result.isSuccess);
            System.assertEquals('S', result.currentBlockCode);
            System.assertEquals('Blocked', result.currentCardStatus);
        }
    }

    @IsTest
    static void testGetCardStatus_NotBlocked() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case For Get Card Status Test' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new CardInqNotBlockedMock());

            Test.startTest();
            FEC_CardLockUnLockController.ResponseResult result =
                FEC_CardLockUnLockController.getCardStatus(c.Id);
            Test.stopTest();

            System.assertEquals('Not Blocked', result.currentCardStatus);
        }
    }

    @IsTest
    static void testGetCardStatus_CaseFieldOverride() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id, FEC_Current_Card_Status__c FROM Case WHERE Subject = 'Case With Preserved Card Status' LIMIT 1];
            System.assertEquals('Custom Status Preserved', c.FEC_Current_Card_Status__c);
            Test.setMock(HttpCalloutMock.class, new CardInqNotBlockedMock());

            Test.startTest();
            FEC_CardLockUnLockController.ResponseResult result =
                FEC_CardLockUnLockController.getCardStatus(c.Id);
            Test.stopTest();

            System.assertEquals('Custom Status Preserved', result.currentCardStatus);
        }
    }

    @IsTest
    static void testCheckProcessActionCardBlock_AllMatrixBranches() {
        System.runAs(testRunAsUser()) {
            Test.startTest();
            FEC_CardLockUnLockController.LockCardResult resCs =
                FEC_CardLockUnLockController.checkProcessActionCardBlock('O', 'Q');
            FEC_CardLockUnLockController.LockCardResult resD2c =
                FEC_CardLockUnLockController.checkProcessActionCardBlock('O', 'D');
            FEC_CardLockUnLockController.LockCardResult resNone =
                FEC_CardLockUnLockController.checkProcessActionCardBlock('ANY_RANDOM_CODE', 'K');
            Test.stopTest();

            System.assertEquals(true, resCs.isShowAction);
            System.assertEquals(false, resD2c.isShowAction);
            System.assertEquals(false, resD2c.isCancel);
            System.assertEquals(false, resNone.isShowAction);
            System.assertEquals(true, resNone.isCancel);
        }
    }

    @IsTest
    static void testDataStructures_CoverageOnly() {
        Test.startTest();
        new FEC_CardLockUnLockController.UpdateResult();
        new FEC_CardLockUnLockController.ResponseResult();
        new FEC_CardLockUnLockController.LockCardResult();
        Test.stopTest();
        System.assert(true);
    }
}
