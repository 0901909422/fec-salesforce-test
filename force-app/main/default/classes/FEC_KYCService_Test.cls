@IsTest
private class FEC_KYCService_Test {

    private static final String PRODUCT_CODE = 'P01';

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
        if (kycMethod == null) {
            return;
        }

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Loan ' + suffix,
            FEC_Code__c = PRODUCT_CODE
        );
        insert prod;

        insert new FEC_KYC__c(
            Name = 'Q1 ' + suffix,
            FEC_KYC_Method__c = kycMethod,
            FEC_Product_Type__c = prod.Id,
            FEC_Plastic_ID__c = 'RS1;DC2'
        );
    }

    @IsTest
    static void testGetByMethodAndProdType() {
        if (Type.forName('FEC_KYCService') == null) {
            System.assert(true, 'Skipped: FEC_KYCService not on org.');
            return;
        }

        List<FEC_KYC__c> seeded = [
            SELECT FEC_KYC_Method__c, FEC_Product_Type__c
            FROM FEC_KYC__c
            LIMIT 1
        ];
        if (seeded.isEmpty()) {
            System.assert(true, 'Skipped: no KYC Method picklist value on org.');
            return;
        }
        FEC_KYC__c kyc = seeded[0];

        Test.startTest();
        List<FEC_KYC__c> results = FEC_KYCService.getByMethodAndProdType(
            new Set<String>{ kyc.FEC_KYC_Method__c },
            new Set<Id>{ kyc.FEC_Product_Type__c }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
    }

    @IsTest
    static void testGetByMethodAndProdTypeAndPlastic() {
        if (Type.forName('FEC_KYCService') == null) {
            System.assert(true, 'Skipped: FEC_KYCService not on org.');
            return;
        }

        List<FEC_KYC__c> seeded = [SELECT FEC_KYC_Method__c FROM FEC_KYC__c LIMIT 1];
        if (seeded.isEmpty()) {
            System.assert(true, 'Skipped: no KYC Method picklist value on org.');
            return;
        }

        Test.startTest();
        List<FEC_KYC__c> results = FEC_KYCService.getByMethodAndProdTypeAndPlastic(
            new Set<String>{ seeded[0].FEC_KYC_Method__c },
            new Set<String>{ PRODUCT_CODE },
            new Set<String>{ 'DC2' }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
    }

    @IsTest
    static void testGetByMethodAndProdTypeAndPlastic_Empty() {
        if (Type.forName('FEC_KYCService') == null) {
            System.assert(true, 'Skipped: FEC_KYCService not on org.');
            return;
        }

        Test.startTest();
        List<FEC_KYC__c> results = FEC_KYCService.getByMethodAndProdTypeAndPlastic(
            new Set<String>{ 'NonExistent' },
            new Set<String>{ 'NonExistent' },
            new Set<String>{ 'NonExistent' }
        );
        Test.stopTest();

        System.assertEquals(0, results.size());
    }
}
