@IsTest
private class FEC_CaseBusinessUtils_Test {

    @IsTest
    static void testIsConditionValid_trueString() {
        System.assertEquals(true, FEC_CaseBusinessUtils.isConditionValid('true'));
    }

    @IsTest
    static void testIsConditionValid_falseString() {
        System.assertEquals(false, FEC_CaseBusinessUtils.isConditionValid('false'));
    }

    @IsTest
    static void testIsConditionValid_blankInputs() {
        System.assertEquals(false, FEC_CaseBusinessUtils.isConditionValid(null));
        System.assertEquals(false, FEC_CaseBusinessUtils.isConditionValid(''));
        System.assertEquals(false, FEC_CaseBusinessUtils.isConditionValid('   '));
    }

    @IsTest
    static void testIsConditionValid_invalidValue() {
        System.assertEquals(false, FEC_CaseBusinessUtils.isConditionValid('TRUE'));
        System.assertEquals(false, FEC_CaseBusinessUtils.isConditionValid('abc'));
    }
}
