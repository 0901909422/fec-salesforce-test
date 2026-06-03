@IsTest
private class FEC_CaseChannelController_Test {

    private static final String SETUP_CODE = 'TC01';

    private static User testRunAsUser() {
        List<User> admins = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        return admins.isEmpty() ? new User(Id = UserInfo.getUserId()) : admins[0];
    }

    @TestSetup
    static void setupData() {
        insert new FEC_Case_Channel__c(
            Name = 'Test Channel',
            FEC_Code__c = SETUP_CODE,
            FEC_Channel_Status__c = true,
            FEC_Self_Service_Flag__c = false,
            FEC_Status__c = true,
            FEC_Name_VN__c = 'Kênh thử nghiệm',
            FEC_Alias__c = 'TestAlias'
        );
    }

    private static FEC_Case_Channel__c getSetupChannel() {
        return [
            SELECT Id, Name, FEC_Code__c
            FROM FEC_Case_Channel__c
            WHERE FEC_Code__c = :SETUP_CODE
            LIMIT 1
        ];
    }

    /**
     * getCaseChannels: trả về danh sách đã strip FLS, có bản ghi @TestSetup.
     */
    @IsTest
    static void testGetCaseChannels_Success() {
        System.runAs(testRunAsUser()) {
            Test.startTest();
            List<FEC_Case_Channel__c> channels = FEC_CaseChannelController.getCaseChannels();
            Test.stopTest();

            System.assertNotEquals(null, channels);
            System.assert(channels.size() >= 1);

            Boolean foundSetup = false;
            for (FEC_Case_Channel__c ch : channels) {
                if (ch.Name == 'Test Channel') {
                    foundSetup = true;
                    break;
                }
            }
            System.assert(foundSetup, 'Phải trả về bản ghi kênh từ @TestSetup.');
            System.assertEquals(1, [SELECT COUNT() FROM FEC_Case_Channel__c WHERE FEC_Code__c = :SETUP_CODE]);
        }
    }

    /**
     * saveCaseChannel: insert — Process_Change_Status__c = New.
     */
    @IsTest
    static void testSaveCaseChannel_InsertSuccess() {
        System.runAs(testRunAsUser()) {
            Map<String, Object> reqData = new Map<String, Object>{
                'Name' => 'New Channel',
                'FEC_Code__c' => 'NC01',
                'FEC_Channel_Status__c' => true,
                'FEC_Self_Service_Flag__c' => true,
                'FEC_Status__c' => true,
                'FEC_Name_VN__c' => 'Kênh mới',
                'FEC_Alias__c' => 'NewAlias'
            };

            Test.startTest();
            Id newRecordId = FEC_CaseChannelController.saveCaseChannel(reqData);
            Test.stopTest();

            System.assertNotEquals(null, newRecordId);
            FEC_Case_Channel__c inserted = [
                SELECT Name, FEC_Code__c, Process_Change_Status__c, FEC_Channel_Status__c
                FROM FEC_Case_Channel__c
                WHERE Id = :newRecordId
            ];
            System.assertEquals('New', inserted.Process_Change_Status__c);
            System.assertEquals('New Channel', inserted.Name);
            System.assertEquals('NC01', inserted.FEC_Code__c);
            System.assertEquals(true, inserted.FEC_Channel_Status__c);
        }
    }

    /**
     * saveCaseChannel: update — Process_Change_Status__c = Update.
     */
    @IsTest
    static void testSaveCaseChannel_UpdateSuccess() {
        System.runAs(testRunAsUser()) {
            FEC_Case_Channel__c existing = getSetupChannel();
            Map<String, Object> reqData = new Map<String, Object>{
                'Id' => String.valueOf(existing.Id),
                'Name' => 'Updated Channel',
                'FEC_Code__c' => 'UC01',
                'FEC_Channel_Status__c' => false,
                'FEC_Self_Service_Flag__c' => true,
                'FEC_Status__c' => false,
                'FEC_Name_VN__c' => 'Kênh cập nhật',
                'FEC_Alias__c' => 'UpdAlias'
            };

            Test.startTest();
            Id updatedId = FEC_CaseChannelController.saveCaseChannel(reqData);
            Test.stopTest();

            System.assertEquals(existing.Id, updatedId);
            FEC_Case_Channel__c updated = [
                SELECT Name, FEC_Code__c, FEC_Channel_Status__c, Process_Change_Status__c
                FROM FEC_Case_Channel__c
                WHERE Id = :updatedId
            ];
            System.assertEquals('Update', updated.Process_Change_Status__c);
            System.assertEquals('Updated Channel', updated.Name);
            System.assertEquals('UC01', updated.FEC_Code__c);
            System.assertEquals(false, updated.FEC_Channel_Status__c);
        }
    }

    /**
     * deleteCaseChannel: xóa bản ghi theo Id.
     */
    @IsTest
    static void testDeleteCaseChannel_Success() {
        System.runAs(testRunAsUser()) {
            FEC_Case_Channel__c toDelete = new FEC_Case_Channel__c(
                Name = 'Delete Me',
                FEC_Code__c = 'DEL01',
                FEC_Channel_Status__c = true,
                FEC_Status__c = true
            );
            insert toDelete;

            Test.startTest();
            FEC_CaseChannelController.deleteCaseChannel(toDelete.Id);
            Test.stopTest();

            System.assertEquals(
                0,
                [SELECT COUNT() FROM FEC_Case_Channel__c WHERE Id = :toDelete.Id]
            );
        }
    }

    /**
     * saveCaseChannel: Id sai định dạng → AuraHandledException.
     */
    @IsTest
    static void testSaveCaseChannel_InvalidIdThrows() {
        System.runAs(testRunAsUser()) {
            Boolean thrown = false;
            Test.startTest();
            try {
                FEC_CaseChannelController.saveCaseChannel(
                    new Map<String, Object>{ 'Id' => 'not-a-valid-id', 'Name' => 'Bad' }
                );
            } catch (AuraHandledException e) {
                thrown = true;
            }
            Test.stopTest();
            System.assert(thrown, 'Phải ném AuraHandledException khi Id không hợp lệ.');
        }
    }

    /**
     * deleteCaseChannel: recordId null → AuraHandledException.
     */
    @IsTest
    static void testDeleteCaseChannel_NullIdThrows() {
        System.runAs(testRunAsUser()) {
            Boolean thrown = false;
            Test.startTest();
            try {
                FEC_CaseChannelController.deleteCaseChannel(null);
            } catch (AuraHandledException e) {
                thrown = true;
            }
            Test.stopTest();
            System.assert(thrown, 'Phải ném AuraHandledException khi recordId = null.');
        }
    }
}
