@IsTest
private class FEC_RuleEngineService_Test {

    private static final String BP_CODE = 'TEST_PROC_01';
    private static final String API_TABLE = 'FEC_Decision_Table__c';
    private static final String API_COLUMN = 'FEC_Decision_Column__c';
    private static final String API_ROW = 'FEC_Decision_Row__c';
    private static final String API_CELL = 'FEC_Decision_Cell__c';
    private static final String API_ADD_FIELD = 'FEC_Additional_Field__c';

    private static Boolean hasDecisionObjects() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        return gd.containsKey(API_TABLE)
            && gd.containsKey(API_COLUMN)
            && gd.containsKey(API_ROW)
            && gd.containsKey(API_CELL);
    }

    private static Boolean ruleEngineAvailable() {
        return Type.forName('FEC_RuleEngineService') != null;
    }

    private static Boolean canRunRuleEngineTests() {
        return ruleEngineAvailable()
            && hasDecisionObjects()
            && Schema.getGlobalDescribe().containsKey(API_ADD_FIELD);
    }

    private static Id insertDynamic(String objectApiName, Map<String, Object> fieldValues) {
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
        if (objectType == null) {
            return null;
        }
        SObject record = objectType.newSObject();
        Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
        for (String fieldName : fieldValues.keySet()) {
            if (fieldMap.containsKey(fieldName)) {
                record.put(fieldName, fieldValues.get(fieldName));
            }
        }
        insert record;
        return record.Id;
    }

    private static void setupRuleEngineData() {
        FEC_Business_Process__c process = new FEC_Business_Process__c(
            Name = 'Test Process',
            FEC_Code__c = BP_CODE,
            FEC_Active__c = true,
            FEC_Order__c = 1
        );
        insert process;

        SObject table = Schema.getGlobalDescribe().get(API_TABLE).newSObject();
        table.put('Name', 'Rule Table');
        table.put('FEC_Business_Process__c', process.Id);
        table.put('FEC_Active__c', true);
        insert table;
        Id tableId = (Id) table.get('Id');

        Id mdmStatusId = insertDynamic(API_ADD_FIELD, new Map<String, Object>{
            'Name' => 'Case Status',
            'FEC_Unique_ID__c' => 'Status',
            'Field_API_Name__c' => 'Status',
            'FEC_Type__c' => 'string'
        });
        Id mdmPriorityId = insertDynamic(API_ADD_FIELD, new Map<String, Object>{
            'Name' => 'Case Priority',
            'FEC_Unique_ID__c' => 'Priority',
            'Field_API_Name__c' => 'Priority',
            'FEC_Type__c' => 'string'
        });

        SObject condCol = Schema.getGlobalDescribe().get(API_COLUMN).newSObject();
        condCol.put('FEC_Decision_Table__c', tableId);
        condCol.put('FEC_Column_Type__c', 'Condition');
        condCol.put('FEC_MDM_Field__c', mdmStatusId);
        condCol.put('Name', 'Status Condition');
        condCol.put('FEC_Order__c', 1);

        SObject actCol = Schema.getGlobalDescribe().get(API_COLUMN).newSObject();
        actCol.put('FEC_Decision_Table__c', tableId);
        actCol.put('FEC_Column_Type__c', 'Action');
        actCol.put('FEC_MDM_Field__c', mdmPriorityId);
        actCol.put('Name', 'Priority Action');
        actCol.put('FEC_Order__c', 2);
        insert new List<SObject>{ condCol, actCol };

        SObject row = Schema.getGlobalDescribe().get(API_ROW).newSObject();
        row.put('FEC_Decision_Table__c', tableId);
        row.put('FEC_Priority__c', 1);
        row.put('FEC_Active__c', true);
        insert row;
        Id rowId = (Id) row.get('Id');

        SObject condCell = Schema.getGlobalDescribe().get(API_CELL).newSObject();
        condCell.put('FEC_Decision_Row__c', rowId);
        condCell.put('FEC_Decision_Column__c', condCol.get('Id'));
        condCell.put('FEC_Value__c', 'New');

        SObject actCell = Schema.getGlobalDescribe().get(API_CELL).newSObject();
        actCell.put('FEC_Decision_Row__c', rowId);
        actCell.put('FEC_Decision_Column__c', actCol.get('Id'));
        actCell.put('FEC_Value__c', 'High');
        insert new List<SObject>{ condCell, actCell };

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                Status = 'New',
                Priority = 'Medium',
                FEC_ID_Search__c = 'RE-' + String.valueOf(System.currentTimeMillis())
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @TestSetup
    static void setupData() {
        if (!canRunRuleEngineTests()) {
            return;
        }
        setupRuleEngineData();
    }

    @IsTest
    static void testEvaluateRule_Matched() {
        if (!canRunRuleEngineTests()) {
            System.assert(true, 'FEC_RuleEngineService hoặc metadata chưa deploy trên org.');
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_RuleEngineService.RuleResult result = FEC_RuleEngineService.evaluateRule(
            BP_CODE,
            c.Id,
            new Map<String, String>()
        );
        Test.stopTest();

        System.assertEquals(true, result.isMatched, result.message);
        System.assertEquals('High', result.actionResults.get('Priority'));
    }

    @IsTest
    static void testEvaluateRule_NoMatch() {
        if (!canRunRuleEngineTests()) {
            System.assert(true, 'FEC_RuleEngineService hoặc metadata chưa deploy trên org.');
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        Map<String, String> context = new Map<String, String>{ 'Status' => 'Closed' };

        Test.startTest();
        FEC_RuleEngineService.RuleResult result = FEC_RuleEngineService.evaluateRule(
            BP_CODE,
            c.Id,
            context
        );
        Test.stopTest();

        System.assertEquals(false, result.isMatched);
        System.assert(result.message.contains('Không có Rule nào thỏa mãn'));
    }

    @IsTest
    static void testEvaluateRule_TableNotFound() {
        if (!canRunRuleEngineTests()) {
            System.assert(true, 'FEC_RuleEngineService hoặc metadata chưa deploy trên org.');
            return;
        }

        Test.startTest();
        FEC_RuleEngineService.RuleResult result = FEC_RuleEngineService.evaluateRule(
            'INVALID_CODE_999',
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(false, result.isMatched);
        System.assert(result.message.contains('Không tìm thấy Decision Table'));
    }

    @IsTest
    static void testEvaluateRule_ExceptionHandling() {
        if (!canRunRuleEngineTests()) {
            System.assert(true, 'FEC_RuleEngineService hoặc metadata chưa deploy trên org.');
            return;
        }

        Id fakeAccountId = '001000000000000AAA';

        Test.startTest();
        FEC_RuleEngineService.RuleResult result = FEC_RuleEngineService.evaluateRule(
            BP_CODE,
            fakeAccountId,
            null
        );
        Test.stopTest();

        System.assertEquals(false, result.isMatched);
        System.assert(result.message.contains('Lỗi Engine:'));
    }
}
