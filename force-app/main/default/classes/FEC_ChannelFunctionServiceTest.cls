@IsTest
private class FEC_ChannelFunctionServiceTest {
    @IsTest
    static void testIsFunctionAllowedGetCSCaseStatusWhenUpdateFlagEnabled() {
        FEC_Channel__c ch = new FEC_Channel__c(
            Name = 'Vtiger',
            FEC_Code__c = 'VTIGER',
            FEC_Channel_ID__c = 'CH-VTIGER',
            FEC_Channel_Vietnamese_name__c = 'Vtiger VN',
            FEC_Channel_Status__c = true,
            FEC_Update_Case_Status__c = true,
            FEC_Get_Nature_Of_Case__c = false,
            FEC_Cancel_Case__c = false
        );
        insert ch;

        Test.startTest();
        Boolean allowed = FEC_ChannelFunctionService.isFunctionAllowed(
            'CH-VTIGER',
            FEC_ConstantCommon.MY_CASE_FUNCTION_GET_CS_CASE_STATUS
        );
        Boolean allowedByName = FEC_ChannelFunctionService.isFunctionAllowed(
            'Vtiger',
            'Get_CSCase_Status'
        );
        Test.stopTest();

        System.assertEquals(true, allowed, 'Channel ID + FEC_Update_Case_Status__c.');
        System.assertEquals(true, allowedByName, 'Channel Name resolves the same record.');
    }

    @IsTest
    static void testIsFunctionAllowedByChannelIdCancelCase() {
        FEC_Channel__c ch = new FEC_Channel__c(
            Name = 'test2',
            FEC_Code__c = 'FEMOBILE',
            FEC_Channel_ID__c = 'FEMobile',
            FEC_Channel_Vietnamese_name__c = 'Mobile VN',
            FEC_Channel_Status__c = true,
            FEC_Cancel_Case__c = true,
            FEC_Update_Case_Status__c = false,
            FEC_Get_Nature_Of_Case__c = false,
            FEC_Self_Service_Flag__c = false
        );
        insert ch;

        Test.startTest();
        Boolean byId = FEC_ChannelFunctionService.isFunctionAllowed('FEMobile', 'CancelCSCase');
        Boolean byLabel = FEC_ChannelFunctionService.isFunctionAllowed('FEMobile', 'Cancel_CS_Case');
        Test.stopTest();

        System.assertEquals(true, byId, 'Channel ID + FEC_Cancel_Case__c.');
        System.assertEquals(true, byLabel, 'Cancel_CS_Case normalizes to CancelCSCase.');
    }

    @IsTest
    static void testCancelCaseFalseWhenCheckboxOff() {
        FEC_Channel__c ch = new FEC_Channel__c(
            Name = 'MobileOnly',
            FEC_Code__c = 'FEMOBILE2',
            FEC_Channel_ID__c = 'FEMobile2',
            FEC_Channel_Vietnamese_name__c = 'Mobile Only VN',
            FEC_Channel_Status__c = true,
            FEC_Cancel_Case__c = false,
            FEC_Get_Nature_Of_Case__c = false,
            FEC_Update_Case_Status__c = false,
            FEC_Self_Service_Flag__c = false
        );
        insert ch;

        System.assertEquals(
            false,
            FEC_ChannelFunctionService.isFunctionAllowed('FEMobile2', 'CancelCSCase'),
            'FEC_Cancel_Case__c false must return false.'
        );
    }

    @IsTest
    static void testIsFunctionAllowedFalseWhenNoMatchingNocOrUnknownFunction() {
        FEC_Channel__c ch = new FEC_Channel__c(
            Name = 'Zalo',
            FEC_Code__c = 'ZALO',
            FEC_Channel_ID__c = 'CH-ZALO',
            FEC_Channel_Vietnamese_name__c = 'Zalo VN',
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
    static void testGetCSMasterDataByCodeWhenNatureOfCaseFlagEnabled() {
        FEC_Channel__c ch = new FEC_Channel__c(
            Name = 'ApiCh',
            FEC_Code__c = 'APICH',
            FEC_Channel_ID__c = 'CH-API',
            FEC_Channel_Vietnamese_name__c = 'API Channel VN',
            FEC_Channel_Status__c = true,
            FEC_Get_Nature_Of_Case__c = true,
            FEC_Update_Case_Status__c = false,
            FEC_Cancel_Case__c = false
        );
        insert ch;

        System.assertEquals(
            true,
            FEC_ChannelFunctionService.isFunctionAllowed('ApiCh', 'GetCSMasterDataByCode'),
            'GetCSMasterDataByCode maps to FEC_Get_Nature_Of_Case__c.'
        );
    }
}
