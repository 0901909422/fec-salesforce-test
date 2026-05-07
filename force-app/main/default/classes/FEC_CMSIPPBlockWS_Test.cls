@isTest
public with sharing class FEC_CMSIPPBlockWS_Test {

    @isTest
    static void testSoapCallout() {
        // Assign the mock implementation to the test context
         // Set the mock callout mode
            Test.setMock(HttpCalloutMock.class, new FEC_CMSIPPBlockWSMock());


        // This should be the class/method that performs the WebService callout
        Test.startTest();
            FEC_CMSIPPBlockWS.ResponseWrapper result = FEC_CMSIPPBlockWS.cmsIPPBlockWS(
                        'VTIGER_CL',
                        '37934499',
                        'BIDV',
                        '1500040000569722',
                        2000001,
                        1,
                        false,
                        'GNN',
                        1,
                        '67876878',
                        'Bank name',
                        'Bank branch',
                        0,
                        0,
                        'Y'
                    );
        Test.stopTest();

    }
}