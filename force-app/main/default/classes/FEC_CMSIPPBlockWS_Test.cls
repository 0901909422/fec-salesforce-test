@isTest
public with sharing class FEC_CMSIPPBlockWS_Test {

    @isTest
    static void testSoapCalloutWithSpecDefaults() {
        Test.setMock(HttpCalloutMock.class, new FEC_CMSIPPBlockWSMock());

        Test.startTest();
        FEC_CMSIPPBlockWS.ResponseWrapper result = FEC_CMSIPPBlockWS.cmsIPPBlockWS(
            FEC_ConstantCommon.REQUESTOR_CRM,
            '72166729',
            null,
            '1500040000569722',
            2000001,
            null,
            null,
            null,
            null,
            '',
            '',
            '',
            0,
            0,
            ''
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    @isTest
    static void testSoapCalloutExplicitSpecValues() {
        Test.setMock(HttpCalloutMock.class, new FEC_CMSIPPBlockWSMock());

        Test.startTest();
        FEC_CMSIPPBlockWS.ResponseWrapper result = FEC_CMSIPPBlockWS.cmsIPPBlockWS(
            FEC_ConstantCommon.REQUESTOR_PEGA_CSM_LEGACY,
            '72166729',
            FEC_CMSIPPBlockWS.DEFAULT_DISB_CHANNEL,
            '0001500020005413937',
            5000000,
            FEC_CMSIPPBlockWS.DEFAULT_TENURE,
            true,
            FEC_CMSIPPBlockWS.DEFAULT_CAMPAIGN_NAME,
            0,
            '',
            '',
            '',
            0,
            0,
            ''
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }
}