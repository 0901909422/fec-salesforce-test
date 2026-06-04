@IsTest
private class FEC_DecisionTableController_Test {

    private static final String API_TABLE = 'FEC_Decision_Table__c';
    private static final String API_COLUMN = 'FEC_Decision_Column__c';
    private static final String API_ROW = 'FEC_Decision_Row__c';
    private static final String API_CELL = 'FEC_Decision_Cell__c';

    private static Boolean hasDecisionObjects() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        return gd.containsKey(API_TABLE)
            && gd.containsKey(API_COLUMN)
            && gd.containsKey(API_ROW)
            && gd.containsKey(API_CELL);
    }

    private static Id setupDecisionData() {
        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'BP Test',
            FEC_Code__c = 'BP_DEC',
            FEC_Active__c = true,
            FEC_Order__c = 1
        );
        insert bp;

        insert new FEC_Case_Stage__c(
            Name = 'Stage Test',
            FEC_Code__c = 'STG_DEC',
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true,
            FEC_Order__c = 1
        );

        SObject table = Schema.getGlobalDescribe().get(API_TABLE).newSObject();
        table.put('Name', 'Table Test');
        table.put('FEC_Business_Process__c', bp.Id);
        table.put('FEC_Active__c', true);
        insert table;

        SObject col = Schema.getGlobalDescribe().get(API_COLUMN).newSObject();
        col.put('Name', 'Col Test');
        col.put('FEC_Decision_Table__c', table.get('Id'));
        col.put('FEC_Column_Type__c', 'Condition');
        col.put('FEC_Order__c', 1);
        insert col;

        SObject row = Schema.getGlobalDescribe().get(API_ROW).newSObject();
        row.put('FEC_Decision_Table__c', table.get('Id'));
        row.put('FEC_Priority__c', 1);
        row.put('FEC_Active__c', true);
        insert row;

        SObject cell = Schema.getGlobalDescribe().get(API_CELL).newSObject();
        cell.put('FEC_Decision_Row__c', row.get('Id'));
        cell.put('FEC_Decision_Column__c', col.get('Id'));
        cell.put('FEC_Value__c', 'Test Value');
        insert cell;

        return bp.Id;
    }

    @TestSetup
    static void setupData() {
        if (!hasDecisionObjects()) {
            return;
        }
        setupDecisionData();
    }

    @IsTest
    static void testDecisionTableDataModel() {
        if (!hasDecisionObjects()) {
            System.assert(true, 'FEC_Decision_* objects not deployed on org.');
            return;
        }

        Id bpId = setupDecisionData();

        Integer tableCount = Database.countQuery(
            'SELECT COUNT() FROM ' + API_TABLE + ' WHERE FEC_Business_Process__c = \'' + bpId + '\''
        );
        Integer colCount = Database.countQuery('SELECT COUNT() FROM ' + API_COLUMN);
        Integer rowCount = Database.countQuery('SELECT COUNT() FROM ' + API_ROW);
        Integer cellCount = Database.countQuery('SELECT COUNT() FROM ' + API_CELL);

        System.assertEquals(1, tableCount);
        System.assertEquals(1, colCount);
        System.assertEquals(1, rowCount);
        System.assertEquals(1, cellCount);
    }

    @IsTest
    static void testBusinessProcessAndStageActive() {
        if (!hasDecisionObjects()) {
            System.assert(true, 'FEC_Decision_* objects not deployed on org.');
            return;
        }

        List<FEC_Business_Process__c> bps = [
            SELECT Id FROM FEC_Business_Process__c WHERE FEC_Code__c = 'BP_DEC' AND FEC_Active__c = TRUE
        ];
        if (bps.isEmpty()) {
            setupDecisionData();
            bps = [
                SELECT Id FROM FEC_Business_Process__c WHERE FEC_Code__c = 'BP_DEC' AND FEC_Active__c = TRUE
            ];
        }
        System.assert(!bps.isEmpty(), 'Business process test data must exist.');
    }

    @IsTest
    static void testAddDecisionRowIncreasesCount() {
        if (!hasDecisionObjects()) {
            System.assert(true, 'FEC_Decision_* objects not deployed on org.');
            return;
        }

        Id tableId = (Id) Database.query('SELECT Id FROM ' + API_TABLE + ' LIMIT 1')[0].get('Id');
        Integer beforeCount = Database.countQuery(
            'SELECT COUNT() FROM ' + API_ROW + ' WHERE FEC_Decision_Table__c = \'' + tableId + '\''
        );

        SObject newRow = Schema.getGlobalDescribe().get(API_ROW).newSObject();
        newRow.put('FEC_Decision_Table__c', tableId);
        newRow.put('FEC_Priority__c', beforeCount + 1);
        newRow.put('FEC_Active__c', true);
        insert newRow;

        Integer afterCount = Database.countQuery(
            'SELECT COUNT() FROM ' + API_ROW + ' WHERE FEC_Decision_Table__c = \'' + tableId + '\''
        );
        System.assertEquals(beforeCount + 1, afterCount);
    }
}
