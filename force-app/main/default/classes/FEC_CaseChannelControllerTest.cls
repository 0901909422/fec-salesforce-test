/**
 * @description Unit tests for FEC_CaseChannelController.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM
 */
@IsTest
private class FEC_CaseChannelControllerTest {

    @testSetup
    static void setupData() {
        FEC_Case_Channel__c ch = new FEC_Case_Channel__c(
            Name = 'TestCaseCh',
            FEC_Code__c = 'CC_TEST_001',
            FEC_Channel_Status__c = true,
            FEC_Self_Service_Flag__c = false,
            FEC_Status__c = true
        );
        insert ch;
    }

    @IsTest
    static void testGetCaseChannels_ReturnsList() {
        Test.startTest();
        List<FEC_Case_Channel__c> result = FEC_CaseChannelController.getCaseChannels();
        Test.stopTest();
        Assert.isFalse(result.isEmpty(), 'Phải có channel record từ setup');
    }

    @IsTest
    static void testSaveCaseChannel_Insert() {
        Map<String, Object> req = new Map<String, Object>{
            'Name' => 'NewCh',
            'FEC_Code__c' => 'CC_NEW_001',
            'FEC_Channel_Status__c' => true,
            'FEC_Self_Service_Flag__c' => false,
            'FEC_Status__c' => true,
            'FEC_Name_VN__c' => 'Tên VN',
            'FEC_Alias__c' => 'Alias'
        };

        Test.startTest();
        Id newId = FEC_CaseChannelController.saveCaseChannel(req);
        Test.stopTest();

        Assert.isNotNull(newId, 'Phải return Id');
        FEC_Case_Channel__c rec = [SELECT Process_Change_Status__c FROM FEC_Case_Channel__c WHERE Id = :newId];
        Assert.areEqual('New', rec.Process_Change_Status__c, 'Status = New cho insert');
    }

    @IsTest
    static void testSaveCaseChannel_Update() {
        FEC_Case_Channel__c existing = [SELECT Id FROM FEC_Case_Channel__c LIMIT 1];
        Map<String, Object> req = new Map<String, Object>{
            'Id' => existing.Id,
            'Name' => 'Updated'
        };

        Test.startTest();
        Id updatedId = FEC_CaseChannelController.saveCaseChannel(req);
        Test.stopTest();

        Assert.areEqual(existing.Id, updatedId);
        FEC_Case_Channel__c rec = [SELECT Name, Process_Change_Status__c FROM FEC_Case_Channel__c WHERE Id = :existing.Id];
        Assert.areEqual('Updated', rec.Name);
        Assert.areEqual('Update', rec.Process_Change_Status__c, 'Status = Update cho update');
    }

    @IsTest
    static void testDeleteCaseChannel_Success() {
        Id chId = [SELECT Id FROM FEC_Case_Channel__c LIMIT 1].Id;

        Test.startTest();
        FEC_CaseChannelController.deleteCaseChannel(chId);
        Test.stopTest();

        Integer remaining = [SELECT COUNT() FROM FEC_Case_Channel__c WHERE Id = :chId];
        Assert.areEqual(0, remaining);
    }

    @IsTest
    static void testDeleteCaseChannel_NullThrows() {
        Boolean caught = false;
        try {
            FEC_CaseChannelController.deleteCaseChannel(null);
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught, 'null Id phải throw');
    }
}