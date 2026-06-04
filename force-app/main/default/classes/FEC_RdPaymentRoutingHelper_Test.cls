@IsTest
private class FEC_RdPaymentRoutingHelper_Test {

    private static Case buildCase(
        String assessment,
        String subCode,
        String stageName
    ) {
        String payload = '{"attributes":{"type":"Case"}'
            + ',"FEC_RD_Payment_Contract_Assessment__c":"'
            + String.escapeSingleQuotes(assessment == null ? '' : assessment) + '"'
            + ',"FEC_SubCode__r":{"FEC_Code__c":"'
            + String.escapeSingleQuotes(subCode == null ? '' : subCode) + '"}'
            + ',"FEC_Current_Case_Stage__r":{"Name":"'
            + String.escapeSingleQuotes(stageName == null ? '' : stageName) + '"}}';
        return (Case) JSON.deserialize(payload, Case.class);
    }

    @IsTest
    static void testIsRdPaymentAssessmentDrivenAtPmStage() {
        System.assertEquals(
            false,
            FEC_RdPaymentRoutingHelper.isRdPaymentAssessmentDrivenAtPmStage(null)
        );
        System.assertEquals(
            false,
            FEC_RdPaymentRoutingHelper.isRdPaymentAssessmentDrivenAtPmStage(buildCase(null, null, null))
        );
        System.assertEquals(
            false,
            FEC_RdPaymentRoutingHelper.isRdPaymentAssessmentDrivenAtPmStage(
                buildCase('High', 'OTHER', 'PM Review')
            )
        );
        System.assertEquals(
            true,
            FEC_RdPaymentRoutingHelper.isRdPaymentAssessmentDrivenAtPmStage(
                buildCase(
                    'Assessed',
                    FEC_ConstantCommon.SUB_CODE_RD_PAYMENT_ASSESSMENT_1,
                    'Stage PM'
                )
            )
        );
        System.assertEquals(
            true,
            FEC_RdPaymentRoutingHelper.isRdPaymentAssessmentDrivenAtPmStage(
                buildCase(
                    'Assessed',
                    FEC_ConstantCommon.SUB_CODE_RD_PAYMENT_ASSESSMENT_2,
                    'pm handling'
                )
            )
        );
        System.assertEquals(
            false,
            FEC_RdPaymentRoutingHelper.isRdPaymentAssessmentDrivenAtPmStage(
                buildCase(
                    'Assessed',
                    FEC_ConstantCommon.SUB_CODE_RD_PAYMENT_ASSESSMENT_1,
                    'CC Stage'
                )
            )
        );
    }
}
