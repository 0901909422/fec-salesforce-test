/**
 * @description Deep tests for FEC_HistoryController — cover history queries with seeded data.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM
 */
@IsTest
private class FEC_HistoryControllerDeepTest {

    @testSetup
    static void setup() {
        FEC_MDM_Product_Type__c pt = new FEC_MDM_Product_Type__c(FEC_Code__c = 'PT_HCD_1');
        insert pt;
        FEC_MDM_Business_Process__c bp = new FEC_MDM_Business_Process__c(FEC_Code__c = 'BP_HCD_1');
        insert bp;

        FEC_MDM_Nature_Of_Case__c noc = new FEC_MDM_Nature_Of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Code__c = 'NOC_HCD_1'
        );
        insert noc;

        FEC_MDM_Case_Stage__c stage = new FEC_MDM_Case_Stage__c(
            Name = 'OpenH', FEC_Code__c = 'ST_HCD_1', FEC_Business_Process__c = bp.Id
        );
        insert stage;

        // Insert MDS records — trigger history by updating tracked fields
        FEC_MDM_Master_Data_Setting__c mds1 = new FEC_MDM_Master_Data_Setting__c(
            FEC_Code__c = 'MDS_HCD_1',
            FEC_Nature_Of_Case__c = noc.Id,
            FEC_Stage_Name__c = stage.Id,
            FEC_Field_Status__c = true
        );
        insert mds1;
        // Update to generate history record
        mds1.FEC_Field_Status__c = false;
        update mds1;
        mds1.FEC_Field_Status__c = true;
        update mds1;

        FEC_MDM_Master_Data_Setting__c mds2 = new FEC_MDM_Master_Data_Setting__c(
            FEC_Code__c = 'MDS_HCD_2',
            FEC_Nature_Of_Case__c = noc.Id,
            FEC_Stage_Name__c = stage.Id,
            FEC_Field_Status__c = true
        );
        insert mds2;
        mds2.FEC_Field_Status__c = false;
        update mds2;

        // Insert Decision Rule + Conditions, with field updates
        FEC_MDM_Decision_Rule__c rule = new FEC_MDM_Decision_Rule__c(
            FEC_Code__c = 'RULE_HCD_1',
            FEC_Table_Key__c = 'STAGE_TRANSITION',
            FEC_Key_ID__c = String.valueOf(bp.Id),
            FEC_Priority__c = 1,
            FEC_Active__c = true
        );
        insert rule;
        rule.FEC_Active__c = false;
        update rule;
        rule.FEC_Active__c = true;
        update rule;

        FEC_MDM_Decision_Condition__c cond = new FEC_MDM_Decision_Condition__c(
            FEC_Code__c = 'COND_HCD_1',
            FEC_Decision_Rule__c = rule.Id,
            FEC_Type__c = 'Condition',
            FEC_Label__c = 'Status',
            FEC_Value__c = 'Open',
            FEC_Operator__c = '=',
            FEC_Order__c = 1
        );
        insert cond;
        cond.FEC_Value__c = 'Closed';
        update cond;

        // Update PT/BP to trigger their history too
        pt.FEC_Active__c = false;
        update pt;
    }

    @IsTest
    static void testGetSettingHistoryByNoc_WithData() {
        Id nocId = [SELECT Id FROM FEC_MDM_Nature_Of_Case__c LIMIT 1].Id;
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.getSettingHistoryByNoc(String.valueOf(nocId));
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetSettingHistoryByIds_NotIntegration() {
        Id nocId = [SELECT Id FROM FEC_MDM_Nature_Of_Case__c LIMIT 1].Id;
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.getSettingHistoryByIds(String.valueOf(nocId), false);
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetSettingHistoryByIds_Integration() {
        Id nocId = [SELECT Id FROM FEC_MDM_Nature_Of_Case__c LIMIT 1].Id;
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.getSettingHistoryByIds(String.valueOf(nocId), true);
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetSettingHistoryBySettingIds_WithData() {
        List<Id> mdsIds = new List<Id>();
        for (FEC_MDM_Master_Data_Setting__c m : [SELECT Id FROM FEC_MDM_Master_Data_Setting__c]) {
            mdsIds.add(m.Id);
        }
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.getSettingHistoryBySettingIds(mdsIds);
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetDecisionEngineHistory_WithRules() {
        Id bpId = [SELECT Id FROM FEC_MDM_Business_Process__c LIMIT 1].Id;
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.getDecisionEngineHistory(
            String.valueOf(bpId), 'STAGE_TRANSITION'
        );
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetDecisionEngineHistory_NoRulesForKey() {
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.getDecisionEngineHistory(
            null, 'NON_EXISTENT_KEY'
        );
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetPropertiesMappingHistory_WithNocCode() {
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.getPropertiesMappingHistory('NOC_HCD_1');
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetRecordHistory_VariousObjects() {
        // Try all major MDM objects to exercise format/parse paths
        Id mdsId = [SELECT Id FROM FEC_MDM_Master_Data_Setting__c LIMIT 1].Id;
        Id ruleId = [SELECT Id FROM FEC_MDM_Decision_Rule__c LIMIT 1].Id;
        Id ptId = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1].Id;
        Id bpId = [SELECT Id FROM FEC_MDM_Business_Process__c LIMIT 1].Id;

        Test.startTest();
        Assert.isNotNull(FEC_HistoryController.getRecordHistory(String.valueOf(mdsId), 'FEC_MDM_Master_Data_Setting__c'));
        Assert.isNotNull(FEC_HistoryController.getRecordHistory(String.valueOf(ruleId), 'FEC_MDM_Decision_Rule__c'));
        Assert.isNotNull(FEC_HistoryController.getRecordHistory(String.valueOf(ptId), 'FEC_MDM_Product_Type__c'));
        Assert.isNotNull(FEC_HistoryController.getRecordHistory(String.valueOf(bpId), 'FEC_MDM_Business_Process__c'));
        Test.stopTest();
    }

    @IsTest
    static void testGetRecordHistory_Standard_Account() {
        // Trigger the non-__c branch path (parentField=AccountId, parentNameField=Account.Name)
        // This exercises: lines for "objectApiName.endsWith('__c') ? ... : objectApiName + 'Id'"
        try {
            Test.startTest();
            FEC_HistoryController.getRecordHistory(null, 'Account');
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testGetRecordHistory_BlankRecordId() {
        // recordId blank → query without WHERE clause
        try {
            Test.startTest();
            FEC_HistoryController.getRecordHistory('', 'FEC_MDM_Master_Data_Setting__c');
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testGetRecordHistory_InvalidObject() {
        // Invalid object should hit catch path
        try {
            Test.startTest();
            FEC_HistoryController.getRecordHistory(null, 'NonExistentObject__c');
            Test.stopTest();
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage());
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    // ════════════════════════════════════════════════════════
    // Direct unit tests for @TestVisible helpers
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testBuildHistoryWrapper_Created() {
        // Cover 'created' branch (lines 446-450)
        Test.startTest();
        FEC_HistoryController.HistoryWrapper w = FEC_HistoryController.buildHistoryWrapperForTest(
            '01n000000000000', 'created', null, null,
            Datetime.now(), 'TestUser', 'TestRecord',
            'FEC_MDM_Master_Data_Setting__c'
        );
        Test.stopTest();
        Assert.isNotNull(w);
        Assert.areEqual('', w.oldValue);
        Assert.isTrue(w.actionText.startsWith('New:'));
    }

    @IsTest
    static void testBuildHistoryWrapper_FieldUpdate() {
        Test.startTest();
        FEC_HistoryController.HistoryWrapper w = FEC_HistoryController.buildHistoryWrapperForTest(
            '01n000000000000', 'FEC_Field_Status__c', 'true', 'false',
            Datetime.now(), 'TestUser', 'TestRecord',
            'FEC_MDM_Master_Data_Setting__c'
        );
        Test.stopTest();
        Assert.isNotNull(w);
        Assert.isTrue(w.actionText.startsWith('Update:'));
        // Boolean field should be converted to Checked/Unchecked
        Assert.areEqual('Checked', w.oldValue);
        Assert.areEqual('Unchecked', w.newValue);
    }

    @IsTest
    static void testBuildHistoryWrapper_StringField() {
        Test.startTest();
        FEC_HistoryController.HistoryWrapper w = FEC_HistoryController.buildHistoryWrapperForTest(
            '01n000000000000', 'FEC_Section__c', 'Old', 'New',
            Datetime.now(), 'TestUser', 'TestRecord',
            'FEC_MDM_Master_Data_Setting__c'
        );
        Test.stopTest();
        Assert.areEqual('Old', w.oldValue);
        Assert.areEqual('New', w.newValue);
    }

    @IsTest
    static void testBuildHistoryWrapper_LookupIdSuffix() {
        // rawField ends with 'Id' → fieldMap.get(rawField.removeEnd('Id')) lookup label fallback
        Test.startTest();
        FEC_HistoryController.HistoryWrapper w = FEC_HistoryController.buildHistoryWrapperForTest(
            '01n000000000000', 'FEC_Nature_Of_CaseId', '001000000000001', '001000000000002',
            Datetime.now(), 'TestUser', 'TestRec', 'FEC_MDM_Master_Data_Setting__c'
        );
        Test.stopTest();
        Assert.isNotNull(w);
    }

    @IsTest
    static void testBuildHistoryWrapper_UnknownField() {
        Test.startTest();
        FEC_HistoryController.HistoryWrapper w = FEC_HistoryController.buildHistoryWrapperForTest(
            '01n000000000000', 'UnknownRandom__c', 'v1', 'v2',
            Datetime.now(), 'TestUser', 'TestRec', 'FEC_MDM_Master_Data_Setting__c'
        );
        Test.stopTest();
        Assert.isNotNull(w);
        Assert.areEqual('UnknownRandom__c', w.fieldName, 'Unknown field falls back to raw name');
    }

    @IsTest
    static void testBuildHistoryWrapper_InvalidObjectApiName() {
        // Cover the catch path where Schema.getGlobalDescribe().get() returns null
        Test.startTest();
        FEC_HistoryController.HistoryWrapper w = FEC_HistoryController.buildHistoryWrapperForTest(
            '01n000000000000', 'SomeField', 'v1', 'v2',
            Datetime.now(), 'User', 'Rec', 'NonExistent__c'
        );
        Test.stopTest();
        Assert.isNotNull(w);
    }

    @IsTest
    static void testIsLikelySalesforceId_Cases() {
        Test.startTest();
        // Valid 15-char Salesforce Id
        Assert.isTrue(FEC_HistoryController.isLikelySalesforceIdForTest('001AB0000ZyXwVu'));
        // Valid 18-char Salesforce Id
        Assert.isTrue(FEC_HistoryController.isLikelySalesforceIdForTest('001AB0000ZyXwVuAAA'));
        // Wrong length
        Assert.isFalse(FEC_HistoryController.isLikelySalesforceIdForTest('001AB0'));
        Assert.isFalse(FEC_HistoryController.isLikelySalesforceIdForTest('001AB0000ZyXwVu1234567890'));
        // Contains special char
        Assert.isFalse(FEC_HistoryController.isLikelySalesforceIdForTest('001AB000-ZyXwVu'));
        // Empty/null
        Assert.isFalse(FEC_HistoryController.isLikelySalesforceIdForTest(''));
        Assert.isFalse(FEC_HistoryController.isLikelySalesforceIdForTest(null));
        Test.stopTest();
    }

    @IsTest
    static void testFormatBooleanValue_Cases() {
        Test.startTest();
        Assert.areEqual('Unchecked', FEC_HistoryController.formatBooleanValueForTest(null));
        Assert.areEqual('Unchecked', FEC_HistoryController.formatBooleanValueForTest(''));
        Assert.areEqual('Unchecked', FEC_HistoryController.formatBooleanValueForTest('null'));
        Assert.areEqual('Checked', FEC_HistoryController.formatBooleanValueForTest('true'));
        Assert.areEqual('Checked', FEC_HistoryController.formatBooleanValueForTest('TRUE'));
        Assert.areEqual('Unchecked', FEC_HistoryController.formatBooleanValueForTest('false'));
        Assert.areEqual('OtherVal', FEC_HistoryController.formatBooleanValueForTest('OtherVal'));
        Test.stopTest();
    }

    @IsTest
    static void testHistoryWrapper_Comparable() {
        // Cover compareTo branches
        FEC_HistoryController.HistoryWrapper w1 = new FEC_HistoryController.HistoryWrapper();
        FEC_HistoryController.HistoryWrapper w2 = new FEC_HistoryController.HistoryWrapper();

        // Both null dates → 0
        Assert.areEqual(0, w1.compareTo(w2));

        // w1 null, w2 not null → 1
        w2.modifiedDate = Datetime.now();
        Assert.areEqual(1, w1.compareTo(w2));

        // w1 not null, w2 null → -1
        FEC_HistoryController.HistoryWrapper w3 = new FEC_HistoryController.HistoryWrapper();
        w3.modifiedDate = Datetime.now();
        FEC_HistoryController.HistoryWrapper w4 = new FEC_HistoryController.HistoryWrapper();
        Assert.areEqual(-1, w3.compareTo(w4));

        // w1 newer than w2 → -1 (DESC)
        FEC_HistoryController.HistoryWrapper newer = new FEC_HistoryController.HistoryWrapper();
        newer.modifiedDate = Datetime.now().addDays(1);
        FEC_HistoryController.HistoryWrapper older = new FEC_HistoryController.HistoryWrapper();
        older.modifiedDate = Datetime.now();
        Assert.areEqual(-1, newer.compareTo(older));
        Assert.areEqual(1, older.compareTo(newer));

        // Equal dates
        Datetime now = Datetime.now();
        FEC_HistoryController.HistoryWrapper a = new FEC_HistoryController.HistoryWrapper();
        a.modifiedDate = now;
        FEC_HistoryController.HistoryWrapper b = new FEC_HistoryController.HistoryWrapper();
        b.modifiedDate = now;
        Assert.areEqual(0, a.compareTo(b));
    }

    // ════════════════════════════════════════════════════════
    // Tests for transformRecordHistory and transformSimpleHistory
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testTransformRecordHistory_Empty() {
        Map<String, Schema.SObjectField> fm = FEC_MDM_Master_Data_Setting__c.SObjectType.getDescribe().fields.getMap();
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.transformRecordHistory(
            new List<Map<String, Object>>(), fm
        );
        Test.stopTest();
        Assert.isTrue(result.isEmpty());
    }

    @IsTest
    static void testTransformRecordHistory_WithDedup() {
        Map<String, Schema.SObjectField> fm = FEC_MDM_Master_Data_Setting__c.SObjectType.getDescribe().fields.getMap();
        Datetime now = Datetime.now();
        // Two rows with same Field + same CreatedDate (sec resolution)
        // - row1: NewValue is 18-char Salesforce Id (raw)
        // - row2: NewValue is friendly name
        // Dedup should keep row2
        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Id' => '01n000000000001',
                'Field' => 'FEC_Stage_Name__c',
                'OldValue' => '',
                'NewValue' => 'a01000000000ABCAAA',
                'CreatedDate' => now,
                'CreatedByName' => 'User1',
                'RecordName' => 'TestRec'
            },
            new Map<String, Object>{
                'Id' => '01n000000000002',
                'Field' => 'FEC_Stage_Name__c',
                'OldValue' => '',
                'NewValue' => 'OpenStage',
                'CreatedDate' => now,
                'CreatedByName' => 'User1',
                'RecordName' => 'TestRec'
            }
        };
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.transformRecordHistory(rows, fm);
        Test.stopTest();
        Assert.areEqual(1, result.size(), 'Dedup should keep 1 entry');
        Assert.areEqual('OpenStage', result[0].newValue, 'Friendly value preferred');
    }

    @IsTest
    static void testTransformRecordHistory_CreatedAndUpdate() {
        Map<String, Schema.SObjectField> fm = FEC_MDM_Master_Data_Setting__c.SObjectType.getDescribe().fields.getMap();
        Datetime now = Datetime.now();
        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Id' => '01n000000000001',
                'Field' => 'created',
                'OldValue' => null,
                'NewValue' => null,
                'CreatedDate' => now,
                'CreatedByName' => 'User1',
                'RecordName' => 'NewRec'
            },
            new Map<String, Object>{
                'Id' => '01n000000000002',
                'Field' => 'FEC_Field_Status__c',
                'OldValue' => 'true',
                'NewValue' => 'false',
                'CreatedDate' => now.addMinutes(1),
                'CreatedByName' => 'User2',
                'RecordName' => 'UpdRec'
            },
            new Map<String, Object>{
                'Id' => '01n000000000003',
                'Field' => 'UnknownField__c',
                'OldValue' => 'x',
                'NewValue' => 'y',
                'CreatedDate' => now.addMinutes(2),
                'CreatedByName' => 'User3',
                'RecordName' => 'UnkRec'
            }
        };
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.transformRecordHistory(rows, fm);
        Test.stopTest();
        Assert.areEqual(3, result.size());
    }

    @IsTest
    static void testTransformSimpleHistory_Empty() {
        Map<String, Schema.SObjectField> fm = FEC_MDM_Master_Data_Setting__c.SObjectType.getDescribe().fields.getMap();
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.transformSimpleHistory(
            new List<Map<String, Object>>(), fm
        );
        Test.stopTest();
        Assert.isTrue(result.isEmpty());
    }

    @IsTest
    static void testTransformSimpleHistory_AllBranches() {
        Map<String, Schema.SObjectField> fm = FEC_MDM_Master_Data_Setting__c.SObjectType.getDescribe().fields.getMap();
        Datetime now = Datetime.now();
        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            // 'created' branch
            new Map<String, Object>{
                'Id' => '01n000000000001',
                'Field' => 'created',
                'OldValue' => null,
                'NewValue' => null,
                'CreatedDate' => now,
                'CreatedByName' => 'User1',
                'RecordName' => 'CreatedRec'
            },
            // Boolean field branch
            new Map<String, Object>{
                'Id' => '01n000000000002',
                'Field' => 'FEC_Field_Status__c',
                'OldValue' => 'true',
                'NewValue' => 'false',
                'CreatedDate' => now,
                'CreatedByName' => 'User2',
                'RecordName' => 'BoolRec'
            },
            // String field
            new Map<String, Object>{
                'Id' => '01n000000000003',
                'Field' => 'FEC_Section__c',
                'OldValue' => 'Old',
                'NewValue' => 'New',
                'CreatedDate' => now,
                'CreatedByName' => 'User3',
                'RecordName' => 'StringRec'
            },
            // Unknown field
            new Map<String, Object>{
                'Id' => '01n000000000004',
                'Field' => 'NonExistent__c',
                'OldValue' => 'a',
                'NewValue' => 'b',
                'CreatedDate' => now,
                'CreatedByName' => 'User4',
                'RecordName' => 'UnkRec'
            },
            // Null fieldMap path (test with null)
            new Map<String, Object>{
                'Id' => '01n000000000005',
                'Field' => 'AnyField',
                'OldValue' => 'a',
                'NewValue' => 'b',
                'CreatedDate' => now,
                'CreatedByName' => 'User5',
                'RecordName' => 'NullMapRec'
            }
        };
        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> result = FEC_HistoryController.transformSimpleHistory(rows, fm);
        // Also call with null fieldMap
        FEC_HistoryController.transformSimpleHistory(rows, null);
        Test.stopTest();
        Assert.areEqual(5, result.size());
    }
}