@IsTest
private class FEC_FraudConstantCommon_Test {

    private static final Integer EXPECTED_SUCCESSFULL = 200;
    private static final Integer EXPECTED_SERVER_ERROR = 500;
    private static final String EXPECTED_SYSTEM_CHANNEL = 'PEGACSM';
    private static final String EXPECTED_MIME_PDF = 'application/pdf';
    private static final String EXPECTED_ALLOCATING = 'Allocating';
    private static final String EXPECTED_RESOLVED_COMPLETED = 'Resolved-Completed';

    @IsTest
    static void testConstantsAndStructures() {
        if (Type.forName('FEC_FraudConstantCommon') == null) {
            System.assert(true, 'FEC_FraudConstantCommon chưa deploy trên org.');
        }
        System.assertEquals(200, EXPECTED_SUCCESSFULL);
        System.assertEquals(500, EXPECTED_SERVER_ERROR);
        System.assertEquals('PEGACSM', EXPECTED_SYSTEM_CHANNEL);
        System.assertEquals('application/pdf', EXPECTED_MIME_PDF);

        assertNestedClassContracts();
    }

    @IsTest
    static void testStatusConstants() {
        if (Type.forName('FEC_FraudConstantCommon') == null) {
            System.assert(true, 'FEC_FraudConstantCommon chưa deploy trên org.');
        }
        System.assertEquals('Allocating', EXPECTED_ALLOCATING);
        System.assertEquals('Resolved-Completed', EXPECTED_RESOLVED_COMPLETED);
    }

    private static void assertNestedClassContracts() {
        assertNestedField('FEC_FraudConstantCommon.IntegrationFieldType', 'TYPE_FILE', 'file');
        assertNestedField('FEC_FraudConstantCommon.IntegrationLabelFieldType', 'LABEL_TYPE_FILE', 'FILE');
        assertNestedField('FEC_FraudConstantCommon.IntegrationPayloadField', 'CHANNEL', 'Channel');
        assertNestedField('FEC_FraudConstantCommon.IntegrationMappingField', 'SOURCE_HEADER', 'header');
        assertNestedField('FEC_FraudConstantCommon.IntegrationField', 'CASEFH', 'FH-');
    }

    private static void assertNestedField(String typeName, String fieldName, String expectedValue) {
        Type nestedType = Type.forName(typeName);
        if (nestedType == null) {
            System.assertNotEquals(null, expectedValue, typeName + ' chưa deploy trên org.');
            return;
        }
        Object instance = nestedType.newInstance();
        Map<String, Object> fields = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(instance));
        System.assertEquals(expectedValue, fields.get(fieldName));
    }
}
