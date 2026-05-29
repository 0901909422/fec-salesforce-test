@isTest
public with sharing class FEC_CMSIPPBlockWS_Test {

    @isTest
    static void testSoapCalloutWithSpecDefaults() {
        Test.setMock(HttpCalloutMock.class, new FEC_CMSIPPBlockWSMock());

        Test.startTest();
        FEC_CMSIPPBlockWS.ResponseWrapper result = FEC_CMSIPPBlockWS.cmsIPPBlockWS(
            FEC_ConstantCommon.REQUESTOR_CRM,
            '1651',
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
            FEC_ConstantCommon.REQUESTOR_CRM,
            '1651',
            FEC_CMSIPPBlockWS.DEFAULT_DISB_CHANNEL,
            '1500040000569722',
            2000001,
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