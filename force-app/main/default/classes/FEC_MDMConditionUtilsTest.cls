/**
 * @description Unit tests for FEC_MDMConditionUtils — pure utility functions.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM | Decision Engine
 */
@IsTest
private class FEC_MDMConditionUtilsTest {

    @IsTest
    static void testIsFieldReference_True() {
        Assert.isTrue(FEC_MDMConditionUtils.isFieldReference('FIELD(Name)'), 'Should detect FIELD(...)');
    }

    @IsTest
    static void testIsFieldReference_False() {
        Assert.isFalse(FEC_MDMConditionUtils.isFieldReference('plainvalue'));
        Assert.isFalse(FEC_MDMConditionUtils.isFieldReference(null));
        Assert.isFalse(FEC_MDMConditionUtils.isFieldReference(''));
    }

    @IsTest
    static void testExtractFieldRefLabel() {
        String result = FEC_MDMConditionUtils.extractFieldRefLabel('FIELD(Status)');
        Assert.areEqual('Status', result);
    }

    @IsTest
    static void testExtractFieldRefLabel_NotRef() {
        String result = FEC_MDMConditionUtils.extractFieldRefLabel('plainvalue');
        Assert.isNull(result);
    }

    @IsTest
    static void testResolveConditionValue_Plain() {
        Map<String, Object> caseData = new Map<String, Object>{ 'status' => 'Open' };
        String result = FEC_MDMConditionUtils.resolveConditionValue('Open', caseData);
        Assert.areEqual('Open', result, 'Plain value returned as-is');
    }

    @IsTest
    static void testResolveConditionValue_FieldRef() {
        Map<String, Object> caseData = new Map<String, Object>{ 'status' => 'Open' };
        String result = FEC_MDMConditionUtils.resolveConditionValue('FIELD(Status)', caseData);
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetGlobalDescribeCached() {
        Map<String, Schema.SObjectType> gd = FEC_MDMConditionUtils.getGlobalDescribeCached();
        Assert.isNotNull(gd);
        Assert.isTrue(gd.containsKey('account') || gd.containsKey('Account'), 'gd phải có Account');
    }

    @IsTest
    static void testResolveFieldDataType_StandardField() {
        String dt = FEC_MDMConditionUtils.resolveFieldDataType('Account', 'Name');
        Assert.isNotNull(dt);
    }

    @IsTest
    static void testResolveFieldDataType_NonExistentObject() {
        String dt = FEC_MDMConditionUtils.resolveFieldDataType('NonExistentObject__c', 'Name');
        // returns null or default
        Assert.isTrue(dt == null || String.isNotBlank(dt));
    }

    @IsTest
    static void testEvaluateCondition_EqualsTrue() {
        Assert.isTrue(FEC_MDMConditionUtils.evaluateCondition('A', '=', 'A', null));
    }

    @IsTest
    static void testEvaluateCondition_EqualsFalse() {
        Assert.isFalse(FEC_MDMConditionUtils.evaluateCondition('A', '=', 'B', null));
    }

    @IsTest
    static void testEvaluateCondition_NotEqual() {
        Assert.isTrue(FEC_MDMConditionUtils.evaluateCondition('A', '!=', 'B', null));
        Assert.isFalse(FEC_MDMConditionUtils.evaluateCondition('A', '!=', 'A', null));
    }

    @IsTest
    static void testEvaluateCondition_NumericGreater() {
        Assert.isTrue(FEC_MDMConditionUtils.evaluateCondition('100', '>', '50', null));
        Assert.isFalse(FEC_MDMConditionUtils.evaluateCondition('30', '>', '50', null));
    }

    @IsTest
    static void testEvaluateCondition_NumericLess() {
        Assert.isTrue(FEC_MDMConditionUtils.evaluateCondition('30', '<', '50', null));
    }

    @IsTest
    static void testEvaluateCondition_GreaterEqual() {
        Assert.isTrue(FEC_MDMConditionUtils.evaluateCondition('50', '>=', '50', null));
        Assert.isTrue(FEC_MDMConditionUtils.evaluateCondition('51', '>=', '50', null));
        Assert.isFalse(FEC_MDMConditionUtils.evaluateCondition('49', '>=', '50', null));
    }

    @IsTest
    static void testEvaluateCondition_LessEqual() {
        Assert.isTrue(FEC_MDMConditionUtils.evaluateCondition('50', '<=', '50', null));
        Assert.isTrue(FEC_MDMConditionUtils.evaluateCondition('49', '<=', '50', null));
        Assert.isFalse(FEC_MDMConditionUtils.evaluateCondition('51', '<=', '50', null));
    }

    @IsTest
    static void testEvaluateCondition_NullActual() {
        // null actual + any operator → false (or special handling)
        Boolean result = FEC_MDMConditionUtils.evaluateCondition(null, '=', 'X', null);
        Assert.isFalse(result);
    }

    @IsTest
    static void testApplyExpression_Empty() {
        String result = FEC_MDMConditionUtils.applyExpression(null, 'value');
        Assert.areEqual('value', result, 'null expression returns value as-is');
    }

    @IsTest
    static void testExtractNumber_Valid() {
        // Pattern: extract numeric param after comma in FUNC(..., N)
        Integer result = FEC_MDMConditionUtils.extractNumber('LEFT(value, 30)');
        Assert.areEqual(30, result);
    }

    @IsTest
    static void testExtractNumber_NoNumber() {
        Integer result = FEC_MDMConditionUtils.extractNumber('LEFT(value)');
        // No comma+number pattern → null
        Assert.isNull(result);
    }

    @IsTest
    static void testCompareNumeric() {
        Assert.areEqual(0, FEC_MDMConditionUtils.compareNumeric('5', '5'));
        Assert.isTrue(FEC_MDMConditionUtils.compareNumeric('10', '5') > 0);
        Assert.isTrue(FEC_MDMConditionUtils.compareNumeric('5', '10') < 0);
    }

    @IsTest
    static void testIsInList_Found() {
        Assert.isTrue(FEC_MDMConditionUtils.isInList('B', 'A,B,C'));
    }

    @IsTest
    static void testIsInList_NotFound() {
        Assert.isFalse(FEC_MDMConditionUtils.isInList('X', 'A,B,C'));
    }

    @IsTest
    static void testEvaluateBetween_InRange() {
        Assert.isTrue(FEC_MDMConditionUtils.evaluateBetween('5', '1,10'));
    }

    @IsTest
    static void testEvaluateBetween_OutOfRange() {
        Assert.isFalse(FEC_MDMConditionUtils.evaluateBetween('15', '1,10'));
    }
}