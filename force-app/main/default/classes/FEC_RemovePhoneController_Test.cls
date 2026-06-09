@IsTest
private class FEC_RemovePhoneController_Test {

    private static final String MOCK_XML_SUCCESS =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
        'xmlns:pc="http://fecredit.com.vn/PhoneCheckWS">' +
        '  <soapenv:Body>' +
        '    <pc:GetRemovablePhoneStatusResponse>' +
        '      <Sys>' +
        '        <TransID>TXN12345</TransID>' +
        '        <DateTime>2026-03-11T10:00:00</DateTime>' +
        '        <Code>1</Code>' +
        '        <Description>Success</Description>' +
        '      </Sys>' +
        '      <Item>' +
        '        <CustomerName>User A</CustomerName>' +
        '        <ContractNumber>CNT001</ContractNumber>' +
        '        <Status>Active</Status>' +
        '      </Item>' +
        '    </pc:GetRemovablePhoneStatusResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    private class MockHttpResponseGenerator implements HttpCalloutMock {
        Integer statusCode;
        String body;
        MockHttpResponseGenerator(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            res.setHeader('Content-Type', 'text/xml');
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        if (String.isBlank(apiSetting.FEC_Endpoint__c)) {
            apiSetting.FEC_Endpoint__c = 'https://mock-api.fecredit.com.vn';
            upsert apiSetting;
        }

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                Subject = 'RemovePhone Test',
                Status = 'New',
                FEC_ID_Search__c = 'RP-' + String.valueOf(System.currentTimeMillis())
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testCheckEligibility_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_SUCCESS));

        Test.startTest();
        FEC_RemovePhoneController.CheckEligibilityResultDTO result =
            FEC_RemovePhoneController.checkEligibility('0901234567');
        Test.stopTest();

        System.assertEquals(
            true,
            result.success,
            'checkEligibility failed: ' + String.valueOf(result.errorMessage)
        );
        System.assertEquals(1, result.rows.size());
        System.assertEquals('User A', result.rows[0].customerName);
        System.assertEquals('CNT001', result.rows[0].contractNumber);
    }

    @IsTest
    static void testSaveRemovePhoneSelections() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        List<FEC_RemovePhoneController.RemovePhoneRowSaveDTO> rows =
            new List<FEC_RemovePhoneController.RemovePhoneRowSaveDTO>();
        FEC_RemovePhoneController.RemovePhoneRowSaveDTO row =
            new FEC_RemovePhoneController.RemovePhoneRowSaveDTO();
        row.customerName = 'User A';
        row.contractNumber = 'CNT001';
        row.checkRemovePhone = true;
        rows.add(row);

        String rowsJson = JSON.serialize(rows);

        Test.startTest();
        FEC_RemovePhoneController.saveRemovePhoneSelections(c.Id, '0901234567', rowsJson);
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM FEC_Contract_List_for_Remove_Phone__c WHERE FEC_Case__c = :c.Id]
        );
    }

    @IsTest
    static void testLoadRemovePhoneDraft() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        insert new FEC_Contract_List_for_Remove_Phone__c(
            FEC_Case__c = c.Id,
            FEC_Removed_Phone_Number__c = '0901234567',
            FEC_Customer_Name__c = 'User A'
        );

        Test.startTest();
        FEC_RemovePhoneController.RemovePhoneDraftDTO draft =
            FEC_RemovePhoneController.loadRemovePhoneDraft(c.Id);
        Test.stopTest();

        System.assertEquals('0901234567', draft.phone);
        System.assertEquals(1, draft.rows.size());
    }

    @IsTest
    static void testValidation_ErrorCases() {
        Test.startTest();
        FEC_RemovePhoneController.CheckEligibilityResultDTO result =
            FEC_RemovePhoneController.checkEligibility('invalid-phone');
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertNotEquals(null, result.errorMessage);
    }
}
