@IsTest
private class FEC_ChannelFunctionServiceTest {
    @IsTest
    static void testVtigerCancelCSCaseAllowedWhenCancelCheckboxOn() {
        insert new FEC_Channel__c(
            Name = 'Vtiger',
            FEC_Channel_Vietnamese_name__c = 'Vtiger VN',
            FEC_Channel_ID__c = 'CH-VTIGER',
            FEC_Channel_Status__c = true,
            FEC_Cancel_Case__c = true,
            FEC_Get_Nature_Of_Case__c = false,
            FEC_Update_Case_Status__c = false
        );

        System.assertEquals(
            true,
            FEC_ChannelFunctionService.isFunctionAllowed('Vtiger', 'CancelCSCase'),
            'Cancel Case checkbox true should allow CancelCSCase.'
        );
        System.assertEquals(
            false,
            FEC_ChannelFunctionService.isFunctionAllowed('Vtiger', 'GetCSCaseStatus'),
            'Update Case Status checkbox false should deny GetCSCaseStatus.'
        );
        System.assertEquals(
            false,
            FEC_ChannelFunctionService.isFunctionAllowed('Vtiger', 'CreateCSCase'),
            'Get Nature Of Case checkbox false should deny CreateCSCase.'
        );
    }

    @IsTest
    static void testGetCSCaseStatusAllowedWhenUpdateCheckboxOn() {
        insert new FEC_Channel__c(
            Name = 'Mobile',
            FEC_Channel_Vietnamese_name__c = 'Mobile VN',
            FEC_Channel_ID__c = 'FEMobile',
            FEC_Channel_Status__c = true,
            FEC_Update_Case_Status__c = true,
            FEC_Cancel_Case__c = false,
            FEC_Get_Nature_Of_Case__c = false
        );

        System.assertEquals(
            true,
            FEC_ChannelFunctionService.isFunctionAllowed('FEMobile', 'GetCSCaseStatus')
        );
    }

    @IsTest
    static void testMasterDataAndCreateCaseUseGetNatureOfCaseCheckbox() {
        insert new FEC_Channel__c(
            Name = 'ApiCh',
            FEC_Channel_Vietnamese_name__c = 'ApiCh VN',
            FEC_Channel_ID__c = 'CH-API',
            FEC_Channel_Status__c = true,
            FEC_Get_Nature_Of_Case__c = true,
            FEC_Update_Case_Status__c = false,
            FEC_Cancel_Case__c = false
        );

        System.assertEquals(
            true,
            FEC_ChannelFunctionService.isFunctionAllowed('ApiCh', 'GetCSMasterData')
        );
        System.assertEquals(
            true,
            FEC_ChannelFunctionService.isFunctionAllowed('CH-API', 'GetCSMasterDataByCode')
        );
        System.assertEquals(
            true,
            FEC_ChannelFunctionService.isFunctionAllowed('ApiCh', 'CreateCSCase')
        );
    }

    @IsTest
    static void testFalseWhenChannelInactiveOrUnknownFunction() {
        insert new FEC_Channel__c(
            Name = 'InactiveCh',
            FEC_Channel_Vietnamese_name__c = 'Inactive VN',
            FEC_Channel_ID__c = 'CH-OFF',
            FEC_Channel_Status__c = false,
            FEC_Cancel_Case__c = true
        );

        System.assertEquals(
            false,
            FEC_ChannelFunctionService.isFunctionAllowed('CH-OFF', 'CancelCSCase'),
            'Inactive channel must return false.'
        );
        System.assertEquals(
            false,
            FEC_ChannelFunctionService.isFunctionAllowed('Missing', 'CancelCSCase'),
            'Unknown channel must return false.'
        );
        System.assertEquals(
            false,
            FEC_ChannelFunctionService.isFunctionAllowed('InactiveCh', 'UnknownApi'),
            'Unknown function must return false.'
        );
    }

    @IsTest
    static void testBlankInputsReturnFalse() {
        System.assertEquals(false, FEC_ChannelFunctionService.isFunctionAllowed(null, 'CancelCSCase'));
        System.assertEquals(false, FEC_ChannelFunctionService.isFunctionAllowed('Vtiger', null));
        System.assertEquals(false, FEC_ChannelFunctionService.isFunctionAllowed('', 'CancelCSCase'));
    }
}