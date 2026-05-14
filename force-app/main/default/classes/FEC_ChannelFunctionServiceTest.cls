@IsTest
private class FEC_ChannelFunctionServiceTest {
    @IsTest
    static void testIsFunctionAllowedTrueWhenNocContainsChannelAndFlagEnabled() {
        FEC_Channel__c ch = new FEC_Channel__c(
            Name = 'Vtiger',
            FEC_Channel_ID__c = 'CH-VTIGER',
            FEC_Channel_Status__c = true,
            FEC_Update_Case_Status__c = true,
            FEC_Get_Nature_Of_Case__c = false,
            FEC_Self_Service_Flag__c = false
        );
        insert ch;

        insert new FEC_Nature_of_Case__c(
            FEC_Channel__c = ch.Id
        );

        Test.startTest();
        Boolean allowed = FEC_ChannelFunctionService.isFunctionAllowed('Vtiger', 'Update_Case_Status');
        Boolean allowedCamel = FEC_ChannelFunctionService.isFunctionAllowed('Vtiger', 'UpdateCaseStatus');
        Test.stopTest();

        System.assertEquals(true, allowed, 'Legacy underscore form.');
        System.assertEquals(true, allowedCamel, 'CamelCase UpdateCaseStatus.');
    }

    @IsTest
    static void testIsFunctionAllowedByChannelIdCancelCase() {
        FEC_Channel__c ch = new FEC_Channel__c(
            Name = 'test2',
            FEC_Channel_ID__c = 'FEMobile',
            FEC_Channel_Status__c = true,
            FEC_Cancel_Case__c = true,
            FEC_Update_Case_Status__c = false,
            FEC_Get_Nature_Of_Case__c = false,
            FEC_Self_Service_Flag__c = false
        );
        insert ch;

        Test.startTest();
        Boolean byId = FEC_ChannelFunctionService.isFunctionAllowed('FEMobile', 'CancelCase');
        Boolean byLabel = FEC_ChannelFunctionService.isFunctionAllowed('FEMobile', 'Cancel_Case');
        Test.stopTest();

        System.assertEquals(true, byId, 'Channel ID + FEC_Cancel_Case__c; no NOC required.');
        System.assertEquals(true, byLabel, 'Cancel_Case normalizes to same capability.');
    }

    @IsTest
    static void testCancelCaseFalseWhenCheckboxOff() {
        FEC_Channel__c ch = new FEC_Channel__c(
            Name = 'MobileOnly',
            FEC_Channel_ID__c = 'FEMobile2',
            FEC_Channel_Status__c = true,
            FEC_Cancel_Case__c = false,
            FEC_Get_Nature_Of_Case__c = false,
            FEC_Update_Case_Status__c = false,
            FEC_Self_Service_Flag__c = false
        );
        insert ch;

        System.assertEquals(
            false,
            FEC_ChannelFunctionService.isFunctionAllowed('FEMobile2', 'CancelCase'),
            'FEC_Cancel_Case__c false must return false.'
        );
    }

    @IsTest
    static void testIsFunctionAllowedFalseWhenNoMatchingNocOrUnknownFunction() {
        FEC_Channel__c ch = new FEC_Channel__c(
            Name = 'Zalo',
            FEC_Channel_ID__c = 'CH-ZALO',
            FEC_Channel_Status__c = true,
            FEC_Get_Nature_Of_Case__c = true,
            FEC_Self_Service_Flag__c = true,
            FEC_Update_Case_Status__c = false
        );
        insert ch;

        Test.startTest();
        Boolean noNoc = FEC_ChannelFunctionService.isFunctionAllowed('Zalo', 'Self_Service_Flag');
        Boolean unknownFn = FEC_ChannelFunctionService.isFunctionAllowed('Zalo', 'Unknown_Feature_Xyz');
        Test.stopTest();

        System.assertEquals(false, noNoc, 'Must return false if no Nature of Case contains the channel.');
        System.assertEquals(false, unknownFn, 'Must return false for unknown function names.');
    }

    @IsTest
    static void testGetNatureOfCaseCamelCaseRequiresNoc() {
        FEC_Channel__c ch = new FEC_Channel__c(
            Name = 'ApiCh',
            FEC_Channel_ID__c = 'CH-API',
            FEC_Channel_Status__c = true,
            FEC_Get_Nature_Of_Case__c = true,
            FEC_Update_Case_Status__c = false,
            FEC_Cancel_Case__c = false,
            FEC_Self_Service_Flag__c = false
        );
        insert ch;
        insert new FEC_Nature_of_Case__c(FEC_Channel__c = ch.Id);

        System.assertEquals(
            true,
            FEC_ChannelFunctionService.isFunctionAllowed('ApiCh', 'GetNatureOfCase'),
            'GetNatureOfCase maps to FEC_Get_Nature_Of_Case__c with NOC.'
        );
    }
}
