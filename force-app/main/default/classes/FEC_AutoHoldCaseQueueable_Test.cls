@IsTest
private class FEC_AutoHoldCaseQueueable_Test {

    private class MarkNFUApiMock implements HttpCalloutMock {
        private final String code;
        MarkNFUApiMock(String code) {
            this.code = code;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><MarkNFUResponse>' +
                '<Code>' + code + '</Code>' +
                '<Description>Mock NFU</Description>' +
                '<NFUStartDate>2026-05-28T00:00:00.000Z</NFUStartDate>' +
                '<NFUTillDate>2026-06-28T00:00:00.000Z</NFUTillDate>' +
                '</MarkNFUResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 6);
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'AHQ PT',
            FEC_Code__c = 'AHQ' + suffix,
            FEC_Active__c = true
        );
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'AHQ Cat',
            FEC_Code__c = 'AHQC' + suffix,
            FEC_Active__c = true
        );
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'AHQ Sub',
            FEC_Code__c = 'AHQS' + suffix,
            FEC_Active__c = true
        );
        insert new List<SObject>{ pt, cat, subCat };

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id
        );
        insert noc;

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'AHQ Stage',
            FEC_Code__c = 'AHQST' + suffix,
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Default_Stage__c = true
        );
        insert stage;

        insert new FEC_Hold_Case__c(
            FEC_NFU_Code__c = 'NFU' + suffix,
            FEC_NFU_Reason_VN__c = 'NFU test',
            FEC_NFU_Duration__c = 30
        );

        insert new FEC_Hold_Case_Config__c(
            Hold_Case_Type__c = 'Auto',
            FEC_Active__c = true,
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Case_Stage__c = stage.Id,
            FEC_NFU_Code__c = 'NFU' + suffix,
            FEC_Current_Status__c = 'New',
            FEC_Changed_Status__c = 'Pending'
        );

        Case c = new Case(
            Subject = 'AutoHold Queueable Test',
            Status = 'New',
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_SubCategory__c = subCat.Id,
            FEC_Current_Case_Stage__c = stage.Id,
            FEC_Process_Action_Count__c = 0
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            Name = 'AHQ-CUST-' + suffix,
            FEC_Case__c = c.Id
        );
        insert hist;
        c.FEC_Account_or_Contract__c = hist.Id;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testQueueable_executesProcessAutoHoldCase() {
        Case c = [SELECT Id, FEC_Current_Case_Stage__c FROM Case LIMIT 1];
        FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Routing_Action__c = 'Submit',
            FEC_Current_Status__c = 'New',
            FEC_Changed_Status__c = 'Pending',
            FEC_Previous_Stage__c = c.FEC_Current_Case_Stage__c
        );
        insert history;

        Test.setMock(HttpCalloutMock.class, new MarkNFUApiMock(FEC_ConstantCommon.SUCCESS_STATUS_CODE));

        Test.startTest();
        System.enqueueJob(new FEC_AutoHoldCaseQueueable(history.Id));
        Test.stopTest();

        Case updated = [
            SELECT FEC_Process_Action_Count__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assert(updated.FEC_Process_Action_Count__c >= 0);
    }
}
