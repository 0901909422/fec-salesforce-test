@IsTest
private class FEC_KYCResultService_Test {

    private static String firstActivePicklistValue(Schema.SObjectField fieldRef) {
        for (Schema.PicklistEntry entry : fieldRef.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());
        String kycMethod = firstActivePicklistValue(FEC_KYC__c.FEC_KYC_Method__c);

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'KYC Result Test ' + suffix,
            FEC_Code__c = 'LOAN' + suffix.right(4)
        );
        insert prod;

        FEC_KYC__c kyc = new FEC_KYC__c(
            Name = 'KYC Question ' + suffix,
            FEC_Product_Type__c = prod.Id,
            FEC_Plastic_ID__c = 'Others',
            FEC_KYC_Suggested_Answer__c = 'Test answer'
        );
        if (kycMethod != null) {
            kyc.FEC_KYC_Method__c = kycMethod;
        }
        insert kyc;

        Case interactionCase = new Case(
            Subject = 'FEC_KYCResultService_Test',
            Status = 'New',
            FEC_ID_Search__c = 'KYCR-' + suffix
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert interactionCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_KYC_Result__c(
            Name = 'KYC Result ' + suffix,
            FEC_Case_Interaction__c = interactionCase.Id,
            FEC_KYC__c = kyc.Id,
            FEC_Status__c = true,
            FEC_Editable__c = true,
            FEC_KYC_Product__c = prod.Name
        );
    }

    @IsTest
    static void testGetByCase() {
        if (Type.forName('FEC_KYCResultService') == null) {
            System.assert(true, 'Skipped: FEC_KYCResultService not on org.');
            return;
        }

        Case interactionCase = [SELECT Id FROM Case LIMIT 1];
        FEC_KYC_Result__c result = [
            SELECT Id
            FROM FEC_KYC_Result__c
            WHERE FEC_Case_Interaction__c = :interactionCase.Id
            LIMIT 1
        ];

        Test.startTest();
        List<FEC_KYC_Result__c> results = FEC_KYCResultService.getByCase(
            new Set<Id>{ interactionCase.Id }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(result.Id, results[0].Id);
        System.assertEquals(interactionCase.Id, results[0].FEC_Case_Interaction__c);
    }

    @IsTest
    static void testGetByCase_Empty() {
        if (Type.forName('FEC_KYCResultService') == null) {
            System.assert(true, 'Skipped: FEC_KYCResultService not on org.');
            return;
        }

        Test.startTest();
        List<FEC_KYC_Result__c> results = FEC_KYCResultService.getByCase(new Set<Id>());
        Test.stopTest();

        System.assertEquals(0, results.size());
    }
}
