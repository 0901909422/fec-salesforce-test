/**
 * RL16 RD Payment routing rules (assessment-driven queue at PM stage).
 */
public without sharing class FEC_RdPaymentRoutingHelper {
  /**
   * RL16: assessment → CC/SP/CP chỉ áp dụng tại stage PM; stage CC/CP lấy queue từ Stage Change.
   */
  public static Boolean isRdPaymentAssessmentDrivenAtPmStage(Case c) {
    if (c == null) {
      return false;
    }
    if (String.isBlank(c.FEC_RD_Payment_Contract_Assessment__c)) {
      return false;
    }
    String subCode = c.FEC_SubCode__r?.FEC_Code__c;
    if (
      !FEC_ConstantCommon.SUB_CODE_RD_PAYMENT_ASSESSMENT_1.equals(subCode) &&
      !FEC_ConstantCommon.SUB_CODE_RD_PAYMENT_ASSESSMENT_2.equals(subCode)
    ) {
      return false;
    }
    String stageName = c.FEC_Current_Case_Stage__r?.Name;
    return String.isNotBlank(stageName) &&
      stageName.toUpperCase().contains('PM');
  }
}
