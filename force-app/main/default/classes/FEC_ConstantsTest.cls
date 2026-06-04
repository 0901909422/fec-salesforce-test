/**
 * @description Tests for FEC_FieldConstants and FEC_ObjectConstants — verify constants class
 *              instantiable (private constructor) + access các constant strings.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM | Common
 */
@IsTest
private class FEC_ConstantsTest {

    @IsTest
    static void testFieldConstants_Access() {
        // Truy cập 1 vài constants để cover line khai báo
        Assert.areEqual('FEC_Code__c', FEC_FieldConstants.FIELD_CODE);
        Assert.areEqual('Name', FEC_FieldConstants.FIELD_NAME);
        Assert.areEqual('FEC_Channel__c', FEC_FieldConstants.FIELD_CHANNEL);
        Assert.areEqual('FEC_Active__c', FEC_FieldConstants.FIELD_ACTIVE);
        Assert.areEqual('FEC_Order__c', FEC_FieldConstants.FIELD_FEC_ORDER);
        Assert.areEqual('FEC_Product_Type__c', FEC_FieldConstants.NOC_FIELD_PRODUCT_TYPE);
        Assert.areEqual('FEC_Nature_Of_Case__r', FEC_FieldConstants.REL_NATURE_OF_CASE);
        Assert.areEqual('Process_Change_Status__c', FEC_FieldConstants.FIELD_PROCESS_CHANGE_STATUS);
    }

    @IsTest
    static void testObjectConstants_Access() {
        // Verify object constant accessible (KHÔNG hardcode value vì có thể đổi)
        Assert.isNotNull(FEC_ObjectConstants.OBJ_MDM_PRODUCT_TYPE);
        Assert.isTrue(FEC_ObjectConstants.OBJ_MDM_PRODUCT_TYPE.contains('Product_Type'));
    }

    @IsTest
    static void testFieldConstants_PrivateConstructor() {
        // Cover private constructor — class chỉ có 1 testable line là constructor
        Test.startTest();
        FEC_FieldConstants instance = new FEC_FieldConstants();
        Test.stopTest();
        Assert.isNotNull(instance);
    }

    @IsTest
    static void testObjectConstants_PrivateConstructor() {
        Test.startTest();
        FEC_ObjectConstants instance = new FEC_ObjectConstants();
        Test.stopTest();
        Assert.isNotNull(instance);
    }
}