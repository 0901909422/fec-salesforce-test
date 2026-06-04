@IsTest
private class FEC_FraudConstantCommon_Test {

    @IsTest
    static void test_StaticConstants() {
        System.assertNotEquals(null, FEC_FraudConstantCommon.LANG_VI);
        System.assertNotEquals(null, FEC_FraudConstantCommon.START_NUMBER_CASE_SFT);
        System.assertNotEquals(null, FEC_FraudConstantCommon.SET_ENPOINT_FRAUD_HEALTH);
        System.assertNotEquals(null, FEC_FraudConstantCommon.SET_ENPOINT_FRAUD_SERVICE);
        System.assertNotEquals(null, FEC_FraudConstantCommon.FRAUD_X_API_KEY);
        System.assertNotEquals(null, FEC_FraudConstantCommon.FRAUD_CASE_SERVICE_NAME);
        System.assertNotEquals(null, FEC_FraudConstantCommon.FRAUD_CASE_CANCEL_NAME);
        System.assertNotEquals(null, FEC_FraudConstantCommon.FRAUD_CASE_CREATE_NAME);
        System.assertNotEquals(null, FEC_FraudConstantCommon.FRAUD_CASE_UPDATE_NAME);
        System.assertNotEquals(null, FEC_FraudConstantCommon.LOCATION_PAGE_SIZE);
        System.assertNotEquals(null, FEC_FraudConstantCommon.LOCATION_OFFSET);
        System.assertNotEquals(null, FEC_FraudConstantCommon.NUMBER_MAX_LENGTH);
        System.assertNotEquals(null, FEC_FraudConstantCommon.CATEGORY_KEY);
        System.assertNotEquals(null, FEC_FraudConstantCommon.SUBCATEGORY_KEY);
        System.assertNotEquals(null, FEC_FraudConstantCommon.SUBCODE_KEY);
        System.assertNotEquals(null, FEC_FraudConstantCommon.NEW_STATUS);
        System.assertNotEquals(null, FEC_FraudConstantCommon.CANCELED);
        System.assertNotEquals(null, FEC_FraudConstantCommon.INFO_NATION_ID);
        System.assertNotEquals(null, FEC_FraudConstantCommon.INFO_PHONE_NUMBER);
        System.assertNotEquals(null, FEC_FraudConstantCommon.INFO_ACCOUNT_NUMBER);
    }

    @IsTest
    static void test_IntegrationFieldType() {
        FEC_FraudConstantCommon.IntegrationFieldType t = new FEC_FraudConstantCommon.IntegrationFieldType();
        System.assertEquals('file', t.TYPE_FILE);
        System.assertNotEquals(null, t.TYPE_TEXT);
        System.assertNotEquals(null, t.TYPE_STRING);
    }

    @IsTest
    static void test_IntegrationField() {
        FEC_FraudConstantCommon.IntegrationField f = new FEC_FraudConstantCommon.IntegrationField();
        System.assertNotEquals(null, f);
    }

    @IsTest
    static void test_IntegrationLabelFieldType() {
        FEC_FraudConstantCommon.IntegrationLabelFieldType l = new FEC_FraudConstantCommon.IntegrationLabelFieldType();
        System.assertEquals('FILE', l.LABEL_TYPE_FILE);
    }

    @IsTest
    static void test_IntegrationMappingField() {
        FEC_FraudConstantCommon.IntegrationMappingField m = new FEC_FraudConstantCommon.IntegrationMappingField();
        System.assertNotEquals(null, m);
    }

    @IsTest
    static void test_IntegrationPayloadField() {
        FEC_FraudConstantCommon.IntegrationPayloadField p = new FEC_FraudConstantCommon.IntegrationPayloadField();
        System.assertNotEquals(null, p);
        System.assertEquals('Channel', p.CHANNEL);
        System.assertEquals('CaseType', p.CASE_TYPE);
    }
}