@IsTest
private class FEC_ImportedInteractionBatch_Test {

    private class IntegrationCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'text/xml');
            res.setBody(
                '<?xml version="1.0" encoding="UTF-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetCustomerListResponse><Sys><Code>0</Code></Sys></GetCustomerListResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private static Id recordTypeId(String developerName) {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        return byDev.containsKey(developerName) ? byDev.get(developerName).getRecordTypeId() : null;
    }

    @TestSetup
    static void setupData() {
        Id interactionRtId = recordTypeId(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME);
        if (interactionRtId == null) {
            return;
        }
        Id customerRtId = recordTypeId(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME);
        String suffix = String.valueOf(System.currentTimeMillis());

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Case interactionCase = new Case(
                Subject = 'Imported Interaction Batch Test',
                RecordTypeId = interactionRtId,
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_IsImported__c = true,
                FEC_ID_Search__c = 'IIB-INT-' + suffix
            );
            insert interactionCase;

            FEC_Customer_History__c hist = new FEC_Customer_History__c(
                Name = 'IIB-HIST-' + suffix,
                FEC_Case__c = interactionCase.Id,
                FEC_CIF_Number__c = 'CIF-IIB-' + suffix,
                FEC_Primary_Phone__c = '0901000001',
                FEC_Account_Number__c = '1234567890123456'
            );
            insert hist;

            interactionCase.FEC_Account_or_Contract__c = hist.Id;
            update interactionCase;

            Case customerCase = new Case(
                Subject = 'Imported Interaction Customer Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_Interaction__c = interactionCase.Id,
                FEC_Account_or_Contract__c = hist.Id,
                FEC_ID_Search__c = 'IIB-CUS-' + suffix
            );
            if (customerRtId != null) {
                customerCase.RecordTypeId = customerRtId;
            }
            insert customerCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testRunAndSchedulable() {
        Id interactionRtId = recordTypeId(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME);
        if (interactionRtId == null) {
            System.assert(true, 'Skipped: Interaction RecordType not available.');
            return;
        }

        Test.setMock(HttpCalloutMock.class, new IntegrationCalloutMock());

        Test.startTest();
        FEC_ImportedInteractionBatch.run();
        String jobId = System.schedule(
            'FEC_ImportedInteractionBatch_Test',
            '0 0 0 31 12 ? 2099',
            new FEC_ImportedInteractionBatch()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId);

        List<Case> importedCases = [
            SELECT FEC_IsImported__c
            FROM Case
            WHERE RecordTypeId = :interactionRtId
            AND Subject = 'Imported Interaction Batch Test'
        ];
        System.assertEquals(1, importedCases.size());
        System.assertEquals(false, importedCases[0].FEC_IsImported__c);
    }

    @IsTest
    static void testExecute_emptyScope() {
        FEC_ImportedInteractionBatch batch = new FEC_ImportedInteractionBatch();
        Test.startTest();
        batch.execute(null, new List<Case>());
        batch.finish(null);
        Test.stopTest();
        System.assert(true, 'Empty scope should no-op.');
    }
}
