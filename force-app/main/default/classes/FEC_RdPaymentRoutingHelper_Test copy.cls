@IsTest
private class FEC_RdPaymentRoutingHelper_Test {

    private static Case buildCase(
        String assessment,
        String subCode,
        String stageName
    ) {
        FEC_Sub_Code__c sub = new FEC_Sub_Code__c(FEC_Code__c = subCode);
        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(Name = stageName);
        Case c = new Case(
            FEC_RD_Payment_Contract_Assessment__c = assessment,
            FEC_SubCode__c = sub.Id
        );
        c.FEC_SubCode__r = sub;
        c.FEC_Current_Case_Stage__r = stage;
        return c;
    }

    @IsTest
    static void testNullCase_returnsFalse() {
        System.assertEquals(
            false,
            FEC_RdPaymentRoutingHelper.isRdPaymentAssessmentDrivenAtPmStage(null)
        );
    }

    @IsTest
    static void testBlankAssessment_returnsFalse() {
        Case c = buildCase(
            null,
            FEC_ConstantCommon.SUB_CODE_RD_PAYMENT_ASSESSMENT_1,
            'PM Stage'
        );
        System.assertEquals(
            false,
            FEC_RdPaymentRoutingHelper.isRdPaymentAssessmentDrivenAtPmStage(c)
        );
        c.FEC_RD_Payment_Contract_Assessment__c = '   ';
        System.assertEquals(
            false,
            FEC_RdPaymentRoutingHelper.isRdPaymentAssessmentDrivenAtPmStage(c)
        );
    }

    @IsTest
    static void testNonRdPaymentSubCode_returnsFalse() {
        Case c = buildCase('Contract OK', 'RC99.01', 'PM Stage');
        System.assertEquals(
            false,
            FEC_RdPaymentRoutingHelper.isRdPaymentAssessmentDrivenAtPmStage(c)
        );
    }

    @IsTest
    static void testAssessment1AtPmStage_returnsTrue() {
        Case c = buildCase(
            'Approved',
            FEC_ConstantCommon.SUB_CODE_RD_PAYMENT_ASSESSMENT_1,
            'RD Payment PM'
        );
        System.assertEquals(
            true,
            FEC_RdPaymentRoutingHelper.isRdPaymentAssessmentDrivenAtPmStage(c)
        );
    }

    @IsTest
    static void testAssessment2AtPmStage_returnsTrue() {
        Case c = buildCase(
            'Rejected',
            FEC_ConstantCommon.SUB_CODE_RD_PAYMENT_ASSESSMENT_2,
            'Stage pm handling'
        );
        System.assertEquals(
            true,
            FEC_RdPaymentRoutingHelper.isRdPaymentAssessmentDrivenAtPmStage(c)
        );
    }

    @IsTest
    static void testNonPmStage_returnsFalse() {
        Case c = buildCase(
            'Approved',
            FEC_ConstantCommon.SUB_CODE_RD_PAYMENT_ASSESSMENT_1,
            'Customer Care Stage'
        );
        System.assertEquals(
            false,
            FEC_RdPaymentRoutingHelper.isRdPaymentAssessmentDrivenAtPmStage(c)
        );
    }

    @IsTest
    static void testBlankStageName_returnsFalse() {
        Case c = buildCase(
            'Approved',
            FEC_ConstantCommon.SUB_CODE_RD_PAYMENT_ASSESSMENT_1,
            null
        );
        System.assertEquals(
            false,
            FEC_RdPaymentRoutingHelper.isRdPaymentAssessmentDrivenAtPmStage(c)
        );
    }

    @IsTest
    static void testMissingSubCodeRelationship_returnsFalse() {
        Case c = new Case(FEC_RD_Payment_Contract_Assessment__c = 'Approved');
        c.FEC_Current_Case_Stage__r = new FEC_Case_Stage__c(Name = 'PM');
        System.assertEquals(
            false,
            FEC_RdPaymentRoutingHelper.isRdPaymentAssessmentDrivenAtPmStage(c)
        );
    }
}
