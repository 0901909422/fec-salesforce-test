@IsTest
private class FEC_BCH_PicklistTranslationCtrl_Test {

    private static Map<String, Object> parsePayload(String payload) {
        return (Map<String, Object>) JSON.deserializeUntyped(payload);
    }

    @IsTest
    static void testBuildPayloadForValidPicklistField() {
        Test.setCurrentPage(new PageReference('/apex/FEC_BCH_PicklistTranslationCtrl'));
        ApexPages.currentPage().getParameters().put('objectName', 'Case');
        ApexPages.currentPage().getParameters().put('fieldName', 'Status');

        FEC_BCH_PicklistTranslationCtrl ctrl = new FEC_BCH_PicklistTranslationCtrl();
        Map<String, Object> payload = parsePayload(ctrl.jsonPayload);

        System.assertNotEquals(null, payload, 'Payload must be valid JSON object.');
        System.assert(payload.size() > 0, 'Payload should include active picklist entries.');
        Boolean hasApiSelfMapping = false;
        for (String key : payload.keySet()) {
            if (String.valueOf(payload.get(key)) == key) {
                hasApiSelfMapping = true;
                break;
            }
        }
        System.assert(hasApiSelfMapping, 'Payload should contain at least one API value => API value mapping.');
    }

    @IsTest
    static void testBuildPayloadWithBlankParameters() {
        Test.setCurrentPage(new PageReference('/apex/FEC_BCH_PicklistTranslationCtrl'));
        ApexPages.currentPage().getParameters().put('objectName', '');
        ApexPages.currentPage().getParameters().put('fieldName', '');

        FEC_BCH_PicklistTranslationCtrl ctrl = new FEC_BCH_PicklistTranslationCtrl();
        Map<String, Object> payload = parsePayload(ctrl.jsonPayload);

        System.assertEquals(0, payload.size(), 'Blank parameters should return empty map.');
    }

    @IsTest
    static void testBuildPayloadWithInvalidObjectAndField() {
        Test.setCurrentPage(new PageReference('/apex/FEC_BCH_PicklistTranslationCtrl'));
        ApexPages.currentPage().getParameters().put('objectName', 'NoSuchObject__c');
        ApexPages.currentPage().getParameters().put('fieldName', 'Status');

        FEC_BCH_PicklistTranslationCtrl invalidObjectCtrl = new FEC_BCH_PicklistTranslationCtrl();
        Map<String, Object> objectPayload = parsePayload(invalidObjectCtrl.jsonPayload);
        System.assertEquals(0, objectPayload.size(), 'Unknown object should return empty map.');

        Test.setCurrentPage(new PageReference('/apex/FEC_BCH_PicklistTranslationCtrl'));
        ApexPages.currentPage().getParameters().put('objectName', 'Case');
        ApexPages.currentPage().getParameters().put('fieldName', 'NoSuchField__c');

        FEC_BCH_PicklistTranslationCtrl invalidFieldCtrl = new FEC_BCH_PicklistTranslationCtrl();
        Map<String, Object> fieldPayload = parsePayload(invalidFieldCtrl.jsonPayload);
        System.assertEquals(0, fieldPayload.size(), 'Unknown field should return empty map.');
    }

    @IsTest
    static void testBuildPayloadWithNonPicklistField() {
        Test.setCurrentPage(new PageReference('/apex/FEC_BCH_PicklistTranslationCtrl'));
        ApexPages.currentPage().getParameters().put('objectName', 'Case');
        ApexPages.currentPage().getParameters().put('fieldName', 'Subject');

        FEC_BCH_PicklistTranslationCtrl ctrl = new FEC_BCH_PicklistTranslationCtrl();
        Map<String, Object> payload = parsePayload(ctrl.jsonPayload);

        System.assertEquals(0, payload.size(), 'Non-picklist field should return empty map.');
    }
}
