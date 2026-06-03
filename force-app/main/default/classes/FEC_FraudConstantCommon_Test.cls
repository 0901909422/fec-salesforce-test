@IsTest
private class FEC_FraudConstantCommon_Test {

    @IsTest
    static void test_constants() {
        // Verify key constants are accessible
        System.assertEquals('vi', FEC_FraudConstantCommon.LANG_VI);
        System.assertEquals(5000000, FEC_FraudConstantCommon.START_NUMBER_CASE_SFT);
        System.assertEquals(1000, FEC_FraudConstantCommon.LOCATION_PAGE_SIZE);
        System.assertEquals(2000, FEC_FraudConstantCommon.LOCATION_OFFSET);
        System.assertEquals('FIMA', FEC_FraudConstantCommon.DEFAULT_CHANNEL_INTEGRATION_CODE);
        System.assertEquals('PEGACSM', FEC_FraudConstantCommon.SYSTEM_CHANNEL);
        System.assertEquals(200, FEC_FraudConstantCommon.SUCCESSFULL);
        System.assertEquals(500, FEC_FraudConstantCommon.SERVER_ERROR);
        System.assertEquals(120000, FEC_FraudConstantCommon.REQUEST_TIMEOUT);
        System.assertEquals('dd/MM/yyyy HH:mm:ss', FEC_FraudConstantCommon.DATETIME_FORMAT_DDMMYYYHHMMSS);
    }

    @IsTest
    static void test_IntegrationFieldType() {
        FEC_FraudConstantCommon.IntegrationFieldType ft = new FEC_FraudConstantCommon.IntegrationFieldType();
        System.assertEquals('file', ft.TYPE_FILE);
        System.assertEquals('text', ft.TYPE_TEXT);
        System.assertEquals('string', ft.TYPE_STRING);
        System.assertEquals('number', ft.TYPE_NUMBER);
        System.assertEquals('date', ft.TYPE_DATE);
        System.assertEquals('datetime', ft.TYPE_DATETIME);
        System.assertEquals('boolean', ft.TYPE_BOOLEAN);
        System.assertEquals('object', ft.TYPE_OBJECT);
        System.assertEquals('array', ft.TYPE_ARRAY);
        System.assertEquals('multi', ft.TYPE_MULTI);
        System.assertEquals('list', ft.TYPE_LIST);
        System.assertEquals('picklist', ft.TYPE_PICKLIST);
    }

    @IsTest
    static void test_IntegrationLabelFieldType() {
        FEC_FraudConstantCommon.IntegrationLabelFieldType lft = new FEC_FraudConstantCommon.IntegrationLabelFieldType();
        System.assertEquals('FILE', lft.LABEL_TYPE_FILE);
        System.assertEquals('TEXT', lft.LABEL_TYPE_TEXT);
        System.assertEquals('STRING', lft.LABEL_TYPE_STRING);
        System.assertEquals('NUMBER', lft.LABEL_TYPE_NUMBER);
        System.assertEquals('DATE', lft.LABEL_TYPE_DATE);
        System.assertEquals('DATETIME', lft.LABEL_TYPE_DATETIME);
        System.assertEquals('BOOLEAN', lft.LABEL_TYPE_BOOLEAN);
        System.assertEquals('OBJECT', lft.LABEL_TYPE_OBJECT);
        System.assertEquals('ARRAY', lft.LABEL_TYPE_ARRAY);
        System.assertEquals('MULTI', lft.LABEL_TYPE_MULTI);
        System.assertEquals('LIST', lft.LABEL_TYPE_LIST);
        System.assertEquals('PICKLIST', lft.LABEL_TYPE_PICKLIST);
    }

    @IsTest
    static void test_IntegrationPayloadField() {
        FEC_FraudConstantCommon.IntegrationPayloadField pf = new FEC_FraudConstantCommon.IntegrationPayloadField();
        System.assertEquals('Channel', pf.CHANNEL);
        System.assertEquals('CaseType', pf.CASE_TYPE);
        System.assertEquals('ProductType', pf.PRODUCT_TYPE);
        System.assertEquals('Category', pf.CATEGORY);
        System.assertEquals('SubCategory', pf.SUBCATEGORY);
        System.assertEquals('SubCode', pf.SUBCODE);
        System.assertEquals('FraudCaseId', pf.FRAUD_CASEID);
        System.assertEquals('ServiceCaseId', pf.SERVICE_CASEID);
        System.assertEquals('ChannelIntegrationCode', pf.CHANNEL_INTEGRATION_CODE);
    }

    @IsTest
    static void test_IntegrationMappingField() {
        FEC_FraudConstantCommon.IntegrationMappingField mf = new FEC_FraudConstantCommon.IntegrationMappingField();
        System.assertEquals('header', mf.SOURCE_HEADER);
        System.assertEquals('details', mf.SOURCE_DETAILS);
        System.assertEquals('productLine', mf.SOURCE_TYPE_PRODUCT);
        System.assertEquals('CaseType', mf.SOURCE_TYPE_CASE);
        System.assertEquals('category', mf.SOURCE_TYPE_CATEGORY);
        System.assertEquals('Response', mf.NODE_RESPONSE);
        System.assertEquals('true', mf.NODE_TRUE);
        System.assertEquals('false', mf.NODE_FALSE);
    }

    @IsTest
    static void test_IntegrationField() {
        FEC_FraudConstantCommon.IntegrationField f = new FEC_FraudConstantCommon.IntegrationField();
        System.assertEquals('FH-', f.CASEFH);
        System.assertEquals('BU-', f.CASEBU);
        System.assertEquals('TK-', f.CASETK);
        System.assertEquals('SFT-', f.CASESFT);
        System.assertEquals('S-', f.CASE_SERVICE);
        System.assertEquals('UIC', f.UIC);
        System.assertEquals('Phone', f.PHONE_FIELD);
        System.assertEquals('NationalIDs', f.NATIONS_FIELD);
        System.assertEquals('NationalID', f.NATION_FIELD);
        System.assertEquals('AccountNumber', f.ACCOUNT_NUMBER_FIELD);
    }

    @IsTest
    static void test_statusConstants() {
        System.assertEquals('Synced', FEC_FraudConstantCommon.CONFIG_SYNC_STATUS_SYNCED);
        System.assertEquals('Updated', FEC_FraudConstantCommon.CONFIG_SYNC_STATUS_UPDATE);
        System.assertEquals('New', FEC_FraudConstantCommon.CONFIG_SYNC_STATUS_NEW);
        System.assertEquals('Deleted', FEC_FraudConstantCommon.CONFIG_SYNC_STATUS_DELETED);
        System.assertEquals('Resolved-Completed', FEC_FraudConstantCommon.CASE_STATUS_RESOLVED_COMPLETED);
        System.assertEquals('Resolved-Cancelled', FEC_FraudConstantCommon.CASE_STATUS_RESOLVED_CANCELLED);
    }
}
