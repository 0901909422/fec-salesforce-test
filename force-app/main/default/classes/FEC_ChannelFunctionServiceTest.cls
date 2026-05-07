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
        Test.stopTest();

        System.assertEquals(true, allowed, 'Must return true when NOC contains channel and the requested flag is enabled.');
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
        Boolean unknownFn = FEC_ChannelFunctionService.isFunctionAllowed('Zalo', 'Cancel_Case');
        Test.stopTest();

        System.assertEquals(false, noNoc, 'Must return false if no Nature of Case contains the channel.');
        System.assertEquals(false, unknownFn, 'Must return false for unknown function names.');
    }
}
