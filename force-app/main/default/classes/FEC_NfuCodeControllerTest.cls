/**
 * @description Unit tests for FEC_NfuCodeController + FEC_SeedNfuCodes.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM
 */
@IsTest
private class FEC_NfuCodeControllerTest {

    @IsTest
    static void testSeedNfuCodes_FreshOrgInsertsAll() {
        // Clean state
        delete [SELECT Id FROM FEC_MDM_NFU_Code__c];

        Test.startTest();
        Integer inserted = FEC_NfuCodeController.seedNfuCodes();
        Test.stopTest();

        Assert.areEqual(20, inserted, 'Expected 20 NFU codes inserted');
        Integer total = [SELECT COUNT() FROM FEC_MDM_NFU_Code__c];
        Assert.areEqual(20, total, '20 records persisted');
    }

    @IsTest
    static void testSeedNfuCodes_AlreadyPopulatedReturnsZero() {
        // Pre-insert 1 record
        insert new FEC_MDM_NFU_Code__c(Name = 'EXISTING_CODE', FEC_Active__c = true);

        Test.startTest();
        Integer inserted = FEC_NfuCodeController.seedNfuCodes();
        Test.stopTest();

        Assert.areEqual(0, inserted, 'Should return 0 when codes already exist');
    }

    @IsTest
    static void testGetAllNfuCodes_ReturnsList() {
        insert new FEC_MDM_NFU_Code__c(Name = 'TEST_CODE', FEC_Reason_VN__c = 'Lý do test', FEC_Active__c = true);

        Test.startTest();
        List<FEC_MDM_NFU_Code__c> codes = FEC_NfuCodeController.getAllNfuCodes();
        Test.stopTest();

        Assert.isFalse(codes.isEmpty(), 'List không được rỗng');
        Assert.isTrue(codes.size() >= 1, 'Phải có ít nhất 1 record');
    }

    @IsTest
    static void testSaveNfuCode_Insert() {
        Test.startTest();
        Id newId = FEC_NfuCodeController.saveNfuCode('NEW_CODE_001', 'Test reason VN', true, null);
        Test.stopTest();

        Assert.isNotNull(newId, 'Phải return Id mới');
        FEC_MDM_NFU_Code__c rec = [SELECT Name, FEC_Reason_VN__c, FEC_Active__c FROM FEC_MDM_NFU_Code__c WHERE Id = :newId];
        Assert.areEqual('NEW_CODE_001', rec.Name, 'Name correct');
        Assert.areEqual('Test reason VN', rec.FEC_Reason_VN__c, 'Reason correct');
        Assert.isTrue(rec.FEC_Active__c, 'Active=true');
    }

    @IsTest
    static void testSaveNfuCode_Update() {
        FEC_MDM_NFU_Code__c rec = new FEC_MDM_NFU_Code__c(Name = 'OLD', FEC_Active__c = true);
        insert rec;

        Test.startTest();
        Id updatedId = FEC_NfuCodeController.saveNfuCode('UPDATED', 'New reason', false, rec.Id);
        Test.stopTest();

        Assert.areEqual(rec.Id, updatedId, 'Id phải giữ nguyên');
        FEC_MDM_NFU_Code__c reloaded = [SELECT Name, FEC_Reason_VN__c, FEC_Active__c FROM FEC_MDM_NFU_Code__c WHERE Id = :rec.Id];
        Assert.areEqual('UPDATED', reloaded.Name);
        Assert.areEqual('New reason', reloaded.FEC_Reason_VN__c);
        Assert.isFalse(reloaded.FEC_Active__c);
    }

    @IsTest
    static void testSaveNfuCode_NullActiveDefaultsTrue() {
        Test.startTest();
        Id newId = FEC_NfuCodeController.saveNfuCode('NULL_ACTIVE', 'Reason', null, null);
        Test.stopTest();

        FEC_MDM_NFU_Code__c rec = [SELECT FEC_Active__c FROM FEC_MDM_NFU_Code__c WHERE Id = :newId];
        Assert.isTrue(rec.FEC_Active__c, 'null active phải default = true');
    }

    @IsTest
    static void testDeleteNfuCode_Success() {
        FEC_MDM_NFU_Code__c rec = new FEC_MDM_NFU_Code__c(Name = 'TO_DELETE', FEC_Active__c = true);
        insert rec;

        Test.startTest();
        FEC_NfuCodeController.deleteNfuCode(rec.Id);
        Test.stopTest();

        Integer remaining = [SELECT COUNT() FROM FEC_MDM_NFU_Code__c WHERE Id = :rec.Id];
        Assert.areEqual(0, remaining, 'Record phải bị xoá');
    }

    @IsTest
    static void testDeleteNfuCode_NullThrows() {
        Boolean caught = false;
        try {
            FEC_NfuCodeController.deleteNfuCode(null);
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught, 'null Id phải throw');
    }

    // ════════════════════════════════════════════════════════
    // FEC_SeedNfuCodes (one-time seed class)
    // ════════════════════════════════════════════════════════
    @IsTest
    static void testSeedNfuCodesRun() {
        // SeedNfuCodes.run() deletes all existing then inserts 20
        delete [SELECT Id FROM FEC_MDM_NFU_Code__c];

        Test.startTest();
        FEC_SeedNfuCodes.run();
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM FEC_MDM_NFU_Code__c];
        Assert.areEqual(20, count, 'Phải insert đủ 20 NFU codes');
    }
}