/**
 * @description Test cho FEC_MDMHashUtil + trigger hash trên Live & MDM Master Data Setting.
 * @author DAT NGO
 * @date 2026-06-12
 */
@IsTest
private class FEC_MDMHashUtilTest {

    @IsTest
    static void testHash_LiveAndMdmSameContent_SameHash() {
        FEC_Master_Data_Setting__c live = new FEC_Master_Data_Setting__c(
            FEC_Code__c = 'HASH_T1', FEC_Section__c = 'S1', FEC_Sub_Section__c = 'Sub1',
            FEC_Field_Status__c = true, FEC_Field_Mandatory__c = false
        );
        FEC_MDM_Master_Data_Setting__c mdm = new FEC_MDM_Master_Data_Setting__c(
            FEC_Code__c = 'HASH_T1', FEC_Section__c = 'S1', FEC_Sub_Section__c = 'Sub1',
            FEC_Field_Status__c = true, FEC_Field_Mandatory__c = false
        );

        Test.startTest();
        insert live;
        insert mdm;
        Test.stopTest();

        FEC_Master_Data_Setting__c liveAfter = [SELECT FEC_Sync_Hash__c FROM FEC_Master_Data_Setting__c WHERE Id = :live.Id];
        FEC_MDM_Master_Data_Setting__c mdmAfter = [SELECT FEC_Sync_Hash__c FROM FEC_MDM_Master_Data_Setting__c WHERE Id = :mdm.Id];

        Assert.isNotNull(liveAfter.FEC_Sync_Hash__c, 'Live hash phải được set bởi trigger');
        Assert.isNotNull(mdmAfter.FEC_Sync_Hash__c, 'MDM hash phải được set bởi trigger');
        Assert.areEqual(liveAfter.FEC_Sync_Hash__c, mdmAfter.FEC_Sync_Hash__c,
            'Cùng nội dung → cùng hash');
    }

    @IsTest
    static void testHash_ChangesWhenFieldChanges() {
        FEC_MDM_Master_Data_Setting__c mdm = new FEC_MDM_Master_Data_Setting__c(
            FEC_Code__c = 'HASH_T2', FEC_Section__c = 'A'
        );
        insert mdm;
        String h1 = [SELECT FEC_Sync_Hash__c FROM FEC_MDM_Master_Data_Setting__c WHERE Id = :mdm.Id].FEC_Sync_Hash__c;

        Test.startTest();
        mdm.FEC_Section__c = 'B';
        update mdm;
        Test.stopTest();

        String h2 = [SELECT FEC_Sync_Hash__c FROM FEC_MDM_Master_Data_Setting__c WHERE Id = :mdm.Id].FEC_Sync_Hash__c;
        Assert.areNotEqual(h1, h2, 'Đổi field nghiệp vụ → hash phải đổi');
    }

    @IsTest
    static void testCompute_NullSafe() {
        FEC_MDM_Master_Data_Setting__c empty = new FEC_MDM_Master_Data_Setting__c(FEC_Code__c = 'HASH_T3');
        String h = FEC_MDMHashUtil.compute(empty);
        Assert.isNotNull(h, 'Compute không lỗi với field null');
        Assert.areEqual(32, h.length(), 'MD5 hex dài 32 ký tự');
    }
}