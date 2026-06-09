/**
 * @description Unit tests for FEC_Util — utility class với pure functions.
 *              Cover các method chuyển đổi type, recordtype lookup, log, exception.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM | Common
 */
@IsTest
private class FEC_UtilTest {

    @IsTest
    static void testLog_NoException() {
        // Smoke test: log() chỉ debug, không throw
        Test.startTest();
        FEC_Util.log('testMethod', 'test message');
        Test.stopTest();
        // No assertion needed — chỉ verify không throw
        Assert.isTrue(true, 'log() must not throw');
    }

    @IsTest
    static void testThrowAuraException_PropagatesMessage() {
        Boolean caught = false;
        try {
            FEC_Util.throwAuraException('myMethod', new DmlException('original error'));
        } catch (AuraHandledException e) {
            caught = true;
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Message phải có nội dung');
        }
        Assert.isTrue(caught, 'Phải catch AuraHandledException');
    }

    @IsTest
    static void testCheckDeletable_NullThrows() {
        Boolean caught = false;
        try {
            FEC_Util.checkDeletable(null);
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught, 'null SObjectType phải throw');
    }

    @IsTest
    static void testCheckDeletable_DeletableObject() {
        // Account is deletable for admin user — không throw
        FEC_Util.checkDeletable(Account.SObjectType);
        Assert.isTrue(true, 'Deletable object phải pass');
    }

    @IsTest
    static void testGetRecordTypeId_NullSobjName() {
        Id result = FEC_Util.getRecordTypeId(null, 'AnyDevName');
        Assert.isNull(result, 'null sObjName phải return null');
    }

    @IsTest
    static void testGetRecordTypeId_BlankSobjName() {
        Id result = FEC_Util.getRecordTypeId('', 'AnyDevName');
        Assert.isNull(result, 'blank sObjName phải return null');
    }

    @IsTest
    static void testGetRecordTypeId_InvalidSobjName() {
        Boolean caught = false;
        try {
            FEC_Util.getRecordTypeId('NonExistentObject__c', 'Any');
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught, 'Invalid sObjName phải throw');
    }

    @IsTest
    static void testGetRecordTypeId_NoRecordType() {
        // Object có thể không có RT → return null
        Id result = FEC_Util.getRecordTypeId('Account', 'NonExistentRecordType');
        Assert.isNull(result, 'Non-existent RT phải return null');
    }

    @IsTest
    static void testToString_Null() {
        Assert.isNull(FEC_Util.toString(null), 'null input → null');
    }

    @IsTest
    static void testToString_Blank() {
        Assert.isNull(FEC_Util.toString('   '), 'blank string → null');
    }

    @IsTest
    static void testToString_TrimmedValue() {
        Assert.areEqual('hello', FEC_Util.toString('  hello  '), 'trim whitespace');
    }

    @IsTest
    static void testToString_Number() {
        Assert.areEqual('123', FEC_Util.toString(123), 'integer → string');
    }

    @IsTest
    static void testToDecimal_Null() {
        Assert.isNull(FEC_Util.toDecimal(null), 'null → null');
    }

    @IsTest
    static void testToDecimal_ValidString() {
        Assert.areEqual(Decimal.valueOf('100.50'), FEC_Util.toDecimal('100.50'), 'parse decimal string');
    }

    @IsTest
    static void testToDecimal_ValidNumber() {
        Assert.areEqual(Decimal.valueOf('42'), FEC_Util.toDecimal(42), 'parse integer');
    }

    @IsTest
    static void testToDecimal_InvalidString() {
        Assert.isNull(FEC_Util.toDecimal('not-a-number'), 'invalid → null');
    }

    @IsTest
    static void testToDateTime_Null() {
        Assert.isNull(FEC_Util.toDateTime(null), 'null → null');
    }

    @IsTest
    static void testToDateTime_Long() {
        Long ts = DateTime.now().getTime();
        DateTime result = FEC_Util.toDateTime(ts);
        Assert.isNotNull(result, 'Long timestamp → DateTime');
    }

    @IsTest
    static void testToDateTime_InvalidString() {
        DateTime result = FEC_Util.toDateTime('garbage-input');
        Assert.isNull(result, 'invalid string → null');
    }

    @IsTest
    static void testToBoolean_Null() {
        Assert.isFalse(FEC_Util.toBoolean(null), 'null → false');
    }

    @IsTest
    static void testToBoolean_TrueVariants() {
        Assert.isTrue(FEC_Util.toBoolean('true'), '"true"');
        Assert.isTrue(FEC_Util.toBoolean('TRUE'), '"TRUE"');
        Assert.isTrue(FEC_Util.toBoolean('1'), '"1"');
        Assert.isTrue(FEC_Util.toBoolean('on'), '"on"');
        Assert.isTrue(FEC_Util.toBoolean('yes'), '"yes"');
    }

    @IsTest
    static void testToBoolean_FalseVariants() {
        Assert.isFalse(FEC_Util.toBoolean('false'), '"false"');
        Assert.isFalse(FEC_Util.toBoolean('0'), '"0"');
        Assert.isFalse(FEC_Util.toBoolean('off'), '"off"');
    }

    @IsTest
    static void testThrowCreateException() {
        Boolean caught = false;
        try {
            FEC_Util.throwCreateException('custom message');
        } catch (AuraHandledException e) {
            caught = true;
            Assert.areEqual('custom message', e.getMessage(), 'Message phải khớp');
        }
        Assert.isTrue(caught, 'Phải throw');
    }

    @IsTest
    static void testCheckIsNumber_Valid() {
        Assert.isTrue(FEC_Util.checkIsNumber('123'), 'integer string');
        Assert.isTrue(FEC_Util.checkIsNumber('123.45'), 'decimal string');
        Assert.isTrue(FEC_Util.checkIsNumber(42), 'integer');
        Assert.isTrue(FEC_Util.checkIsNumber(3.14), 'decimal');
    }

    @IsTest
    static void testCheckIsNumber_Invalid() {
        Assert.isFalse(FEC_Util.checkIsNumber(null), 'null');
        Assert.isFalse(FEC_Util.checkIsNumber(''), 'blank');
        Assert.isFalse(FEC_Util.checkIsNumber('abc'), 'non-number string');
    }

    @IsTest
    static void testGetStartOfToday() {
        DateTime result = FEC_Util.getStartOfToday();
        Assert.isNotNull(result);
        Assert.areEqual(0, result.hour(), 'hour=0');
        Assert.areEqual(0, result.minute(), 'minute=0');
    }

    @IsTest
    static void testGetEndOfToday() {
        DateTime result = FEC_Util.getEndOfToday();
        Assert.isNotNull(result);
        Assert.areEqual(23, result.hour(), 'hour=23');
        Assert.areEqual(59, result.minute(), 'minute=59');
    }

    @IsTest
    static void testGetBeforeSubstring_Found() {
        Assert.areEqual('hello', FEC_Util.getBeforeSubstring('hello world', ' world'), 'split before');
    }

    @IsTest
    static void testGetBeforeSubstring_NotFound() {
        Assert.isNull(FEC_Util.getBeforeSubstring('hello world', 'xyz'), 'not found → null');
    }

    @IsTest
    static void testGetBeforeSubstring_BlankInput() {
        Assert.areEqual('', FEC_Util.getBeforeSubstring('', 'xyz'), 'blank input → empty');
        Assert.areEqual('', FEC_Util.getBeforeSubstring(null, 'xyz'), 'null input → empty');
        Assert.areEqual('', FEC_Util.getBeforeSubstring('hello', ''), 'blank substring → empty');
    }
}