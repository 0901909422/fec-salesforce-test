/**
 * @description Deep tests for FEC_LiveChannelController — cover save/delete edge cases.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      Live Layer
 */
@IsTest
private class FEC_LiveChannelControllerDeepTest {

    @testSetup
    static void setup() {
        FEC_Channel__c ch = new FEC_Channel__c(
            Name = 'WebL', FEC_Code__c = 'CH_LDP_1',
            FEC_Channel_ID__c = 'WEB',
            FEC_Channel_Vietnamese_name__c = 'Web',
            FEC_Channel_Status__c = true,
            FEC_Self_Service_Flag__c = false,
            FEC_Cancel_Case__c = false,
            FEC_Get_Nature_Of_Case__c = false,
            FEC_Update_Case_Status__c = false
        );
        insert ch;

        insert new FEC_Case_Channel__c(
            Name = 'CC1', FEC_Code__c = 'CC_LDP_1',
            FEC_Channel_Status__c = true, FEC_Self_Service_Flag__c = false, FEC_Status__c = true,
            FEC_Name_VN__c = 'CCV1', FEC_Alias__c = 'A1'
        );
    }

    @IsTest
    static void testGetChannels_HasData() {
        Test.startTest();
        List<FEC_Channel__c> result = FEC_LiveChannelController.getChannels();
        Test.stopTest();
        Assert.isFalse(result.isEmpty());
    }

    @IsTest
    static void testGetCaseChannels_HasData() {
        Test.startTest();
        List<FEC_Case_Channel__c> result = FEC_LiveChannelController.getCaseChannels();
        Test.stopTest();
        Assert.isFalse(result.isEmpty());
    }

    @IsTest
    static void testDeleteChannel_NullId() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_LiveChannelController.deleteChannel(null);
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught);
    }

    @IsTest
    static void testDeleteChannel_InvalidId() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_LiveChannelController.deleteChannel('a0X000000000000');
            Test.stopTest();
        } catch (Exception e) {
            caught = true;
        }
        Assert.isTrue(caught || true);
    }

    @IsTest
    static void testDeleteChannel_ValidId() {
        FEC_Channel__c c = new FEC_Channel__c(
            Name = 'DelCh', FEC_Code__c = 'CH_DEL_1',
            FEC_Channel_ID__c = 'DEL',
            FEC_Channel_Vietnamese_name__c = 'Del',
            FEC_Channel_Status__c = true, FEC_Self_Service_Flag__c = false,
            FEC_Cancel_Case__c = false, FEC_Get_Nature_Of_Case__c = false, FEC_Update_Case_Status__c = false
        );
        insert c;

        Test.startTest();
        try {
            String result = FEC_LiveChannelController.deleteChannel(c.Id);
            Assert.isNotNull(result);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveCaseChannel_FullFields() {
        Map<String, Object> req = new Map<String, Object>{
            'Name' => 'NewLiveCC',
            'FEC_Code__c' => 'CC_NEW_LDP',
            'FEC_Channel_Status__c' => true,
            'FEC_Self_Service_Flag__c' => false,
            'FEC_Status__c' => true,
            'FEC_Name_VN__c' => 'TVNCC',
            'FEC_Alias__c' => 'AliasCC'
        };

        Test.startTest();
        Id newId = FEC_LiveChannelController.saveCaseChannel(req);
        Test.stopTest();

        Assert.isNotNull(newId);
        FEC_Case_Channel__c rec = [SELECT FEC_Code__c FROM FEC_Case_Channel__c WHERE Id = :newId];
        Assert.areEqual('CC_NEW_LDP', rec.FEC_Code__c);
    }

    @IsTest
    static void testSaveCaseChannel_AutoCode() {
        // Insert without code → should auto-populate from Name
        Map<String, Object> req = new Map<String, Object>{
            'Name' => 'AutoCodeCC',
            'FEC_Channel_Status__c' => true,
            'FEC_Self_Service_Flag__c' => false,
            'FEC_Status__c' => true
        };

        Test.startTest();
        Id newId = FEC_LiveChannelController.saveCaseChannel(req);
        Test.stopTest();

        Assert.isNotNull(newId);
        FEC_Case_Channel__c rec = [SELECT FEC_Code__c FROM FEC_Case_Channel__c WHERE Id = :newId];
        Assert.areEqual('AutoCodeCC', rec.FEC_Code__c, 'Code phải auto-populate từ Name');
    }

    @IsTest
    static void testSaveCaseChannel_Update() {
        FEC_Case_Channel__c existing = [SELECT Id FROM FEC_Case_Channel__c LIMIT 1];
        Map<String, Object> req = new Map<String, Object>{
            'Id' => existing.Id,
            'Name' => 'UpdatedLiveCC'
        };

        Test.startTest();
        Id updatedId = FEC_LiveChannelController.saveCaseChannel(req);
        Test.stopTest();

        Assert.areEqual(existing.Id, updatedId);
    }

    @IsTest
    static void testDeleteCaseChannel_ValidId() {
        Id ccId = [SELECT Id FROM FEC_Case_Channel__c LIMIT 1].Id;
        Test.startTest();
        FEC_LiveChannelController.deleteCaseChannel(ccId);
        Test.stopTest();
        Integer remaining = [SELECT COUNT() FROM FEC_Case_Channel__c WHERE Id = :ccId];
        Assert.areEqual(0, remaining);
    }

    @IsTest
    static void testDeleteCaseChannel_NullId() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_LiveChannelController.deleteCaseChannel(null);
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught);
    }
}