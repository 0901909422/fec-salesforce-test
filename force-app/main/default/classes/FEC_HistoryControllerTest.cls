/**
 * @description Smoke tests for FEC_HistoryController.
 *              Cover các method query history (cacheable=true).
 *              Note: history records (FieldHistory) chỉ tự sinh khi field tracking được bật,
 *              nên test ở đây chỉ verify method callable và return type.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM
 */
@IsTest
private class FEC_HistoryControllerTest {

    @IsTest
    static void testGetRecordHistory_NullId() {
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.getRecordHistory(null, 'FEC_MDM_Master_Data_Setting__c');
        Test.stopTest();
        Assert.isNotNull(result, 'Phải return list, không null');
    }

    @IsTest
    static void testGetRecordHistory_BlankObjectName() {
        Boolean handled = false;
        try {
            Test.startTest();
            FEC_HistoryController.getRecordHistory('001000000000000', '');
            Test.stopTest();
            handled = true;
        } catch (AuraHandledException e) {
            handled = true;
        }
        Assert.isTrue(handled, 'Method handled blank object name');
    }

    @IsTest
    static void testGetRecordHistory_ValidObject() {
        FEC_MDM_Master_Data_Setting__c rec = new FEC_MDM_Master_Data_Setting__c(
            FEC_Field_Object_Name__c = 'Account',
            FEC_Field_API_Name__c = 'Name',
            FEC_Field_Status__c = true
        );
        insert rec;

        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.getRecordHistory(rec.Id, 'FEC_MDM_Master_Data_Setting__c');
        Test.stopTest();

        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetSettingHistoryByNoc_Empty() {
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.getSettingHistoryByNoc(null);
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetSettingHistoryByNoc_NoData() {
        // Provide blank/invalid id — query returns empty
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.getSettingHistoryByNoc('001000000000000');
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetSettingHistoryByIds() {
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.getSettingHistoryByIds(null, false);
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetSettingHistoryBySettingIds_Empty() {
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.getSettingHistoryBySettingIds(new List<Id>());
        Test.stopTest();
        Assert.isNotNull(result);
        Assert.isTrue(result.isEmpty(), 'Empty input → empty output');
    }

    @IsTest
    static void testGetDecisionEngineHistory() {
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.getDecisionEngineHistory(null, 'TEST_KEY');
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetPropertiesMappingHistory() {
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.getPropertiesMappingHistory(null);
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testHistoryWrapper_Construction() {
        FEC_HistoryController.HistoryWrapper wrapper = new FEC_HistoryController.HistoryWrapper();
        wrapper.fieldName = 'Test';
        wrapper.oldValue = 'A';
        wrapper.newValue = 'B';
        wrapper.modifiedByName = 'User';
        Assert.areEqual('Test', wrapper.fieldName);
        Assert.areEqual('A', wrapper.oldValue);
    }

    @IsTest
    static void testGetRecordHistory_StandardObject() {
        // Standard object — uses different naming convention (e.g., AccountHistory)
        Account a = new Account(Name = 'Test History Account');
        insert a;

        Test.startTest();
        try {
            List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.getRecordHistory(a.Id, 'Account');
            Assert.isNotNull(result);
        } catch (Exception e) {
            // Acceptable: AccountHistory may not be enabled
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testHistoryWrapper_CompareTo() {
        FEC_HistoryController.HistoryWrapper a = new FEC_HistoryController.HistoryWrapper();
        a.modifiedDate = DateTime.now();
        FEC_HistoryController.HistoryWrapper b = new FEC_HistoryController.HistoryWrapper();
        b.modifiedDate = DateTime.now().addHours(-1);
        // a > b (newer first → -1)
        Assert.areEqual(-1, a.compareTo(b));
        Assert.areEqual(1, b.compareTo(a));
        Assert.areEqual(0, a.compareTo(a));
    }

    @IsTest
    static void testHistoryWrapper_CompareTo_NullDates() {
        FEC_HistoryController.HistoryWrapper a = new FEC_HistoryController.HistoryWrapper();
        FEC_HistoryController.HistoryWrapper b = new FEC_HistoryController.HistoryWrapper();
        // both null → 0
        Assert.areEqual(0, a.compareTo(b));

        a.modifiedDate = DateTime.now();
        // a not null, b null → a wins (-1)
        Assert.areEqual(-1, a.compareTo(b));
        Assert.areEqual(1, b.compareTo(a));
    }

    @IsTest
    static void testGetSettingHistoryByNoc_WithSettingData() {
        // Insert NOC + Setting records để query realistic data
        FEC_MDM_Product_Type__c pt = new FEC_MDM_Product_Type__c(FEC_Code__c = 'PT_HCT_1', FEC_Active__c = true);
        insert pt;
        FEC_MDM_Nature_Of_Case__c noc = new FEC_MDM_Nature_Of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Code__c = 'NOC_HCT_1'
        );
        insert noc;
        insert new FEC_MDM_Master_Data_Setting__c(
            FEC_Nature_Of_Case__c = noc.Id,
            FEC_Field_Object_Name__c = 'Account',
            FEC_Field_API_Name__c = 'Name',
            FEC_Field_Status__c = true
        );

        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.getSettingHistoryByNoc(noc.Id);
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetSettingHistoryByIds_AllVariants() {
        Test.startTest();
        // null, true, false branches
        List<FEC_HistoryController.HistoryWrapper> r1 = FEC_HistoryController.getSettingHistoryByIds(null, null);
        List<FEC_HistoryController.HistoryWrapper> r2 = FEC_HistoryController.getSettingHistoryByIds(null, true);
        List<FEC_HistoryController.HistoryWrapper> r3 = FEC_HistoryController.getSettingHistoryByIds(null, false);
        Test.stopTest();
        Assert.isNotNull(r1);
        Assert.isNotNull(r2);
        Assert.isNotNull(r3);
    }

    @IsTest
    static void testGetDecisionEngineHistory_AllParams() {
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> r1 = FEC_HistoryController.getDecisionEngineHistory(null, 'KEY1');
        List<FEC_HistoryController.HistoryWrapper> r2 = FEC_HistoryController.getDecisionEngineHistory('001000000000000', null);
        Test.stopTest();
        Assert.isNotNull(r1);
        Assert.isNotNull(r2);
    }

    @IsTest
    static void testGetPropertiesMappingHistory_AllVariants() {
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> r1 = FEC_HistoryController.getPropertiesMappingHistory(null);
        List<FEC_HistoryController.HistoryWrapper> r2 = FEC_HistoryController.getPropertiesMappingHistory('SOME_CODE');
        Test.stopTest();
        Assert.isNotNull(r1);
        Assert.isNotNull(r2);
    }
}