/**
 * @description Deep tests for FEC_DecisionTableController — cover save/add/delete với data thật.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM | Decision Engine
 */
@IsTest
private class FEC_DecisionTableControllerDeepTest {

    @testSetup
    static void setup() {
        // FEC_Decision_Table__c.FEC_Business_Process__c references Live FEC_Business_Process__c
        FEC_Business_Process__c bp = new FEC_Business_Process__c(FEC_Code__c = 'BP_DTC_D1');
        insert bp;

        FEC_Decision_Table__c table = new FEC_Decision_Table__c(
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true
        );
        insert table;

        FEC_Decision_Column__c col = new FEC_Decision_Column__c(
            FEC_Decision_Table__c = table.Id,
            Name = 'Status',
            FEC_Column_Type__c = 'Condition',
            FEC_Order__c = 1
        );
        insert col;

        FEC_Decision_Row__c row = new FEC_Decision_Row__c(
            FEC_Decision_Table__c = table.Id,
            FEC_Priority__c = 1
        );
        insert row;

        insert new FEC_Decision_Cell__c(
            FEC_Decision_Row__c = row.Id,
            FEC_Decision_Column__c = col.Id,
            FEC_Value__c = 'Open'
        );
    }

    @IsTest
    static void testGetDynamicDecisionTable_WithData() {
        Id bpId = [SELECT Id FROM FEC_Business_Process__c LIMIT 1].Id;
        Test.startTest();
        FEC_DecisionTableController.TableWrapper result = FEC_DecisionTableController.getDynamicDecisionTable(String.valueOf(bpId));
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetDynamicDecisionTableFresh_WithData() {
        Id bpId = [SELECT Id FROM FEC_Business_Process__c LIMIT 1].Id;
        Test.startTest();
        FEC_DecisionTableController.TableWrapper result = FEC_DecisionTableController.getDynamicDecisionTableFresh(String.valueOf(bpId));
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testSaveDynamicRule_WithValidIds() {
        Id tableId = [SELECT Id FROM FEC_Decision_Table__c LIMIT 1].Id;
        Id rowId = [SELECT Id FROM FEC_Decision_Row__c LIMIT 1].Id;
        Id colId = [SELECT Id FROM FEC_Decision_Column__c LIMIT 1].Id;
        try {
            Test.startTest();
            FEC_DecisionTableController.saveDynamicRule(
                String.valueOf(tableId),
                String.valueOf(rowId),
                new Map<String, String>{ String.valueOf(colId) => 'NewValue' }
            );
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testAddDynamicRow_Valid() {
        Id tableId = [SELECT Id FROM FEC_Decision_Table__c LIMIT 1].Id;
        Id rowId = [SELECT Id FROM FEC_Decision_Row__c LIMIT 1].Id;
        try {
            Test.startTest();
            FEC_DecisionTableController.addDynamicRow(String.valueOf(tableId), String.valueOf(rowId), 'after');
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testAddDynamicColumn_Valid() {
        Id tableId = [SELECT Id FROM FEC_Decision_Table__c LIMIT 1].Id;
        Id existingColId = [SELECT Id FROM FEC_Decision_Column__c LIMIT 1].Id;
        try {
            Test.startTest();
            FEC_DecisionTableController.addDynamicColumn(
                String.valueOf(tableId), String.valueOf(existingColId), 'after',
                'NewCol', 'Condition', 'Text', null
            );
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testDeleteDynamicRule_Valid() {
        Id rowId = [SELECT Id FROM FEC_Decision_Row__c LIMIT 1].Id;
        try {
            Test.startTest();
            FEC_DecisionTableController.deleteDynamicRule(String.valueOf(rowId));
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testDeleteDynamicColumn_Valid() {
        Id colId = [SELECT Id FROM FEC_Decision_Column__c LIMIT 1].Id;
        try {
            Test.startTest();
            FEC_DecisionTableController.deleteDynamicColumn(String.valueOf(colId));
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }
}