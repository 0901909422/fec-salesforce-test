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
    if (String.isBlank(stageName)) {
      return false;
    }
    if (stageName.toUpperCase().contains('PM')) {
      return true;
    }
    return isRl16RdPaymentAssessmentStage(subCode, stageName);
  }

  /**
   * RL16.02/03 Stage 2 — stage đánh giá RD Payment (tên org có thể không chứa "PM").
   */
  private static Boolean isRl16RdPaymentAssessmentStage(
    String subCode,
    String stageName
  ) {
    if (String.isBlank(subCode) || String.isBlank(stageName)) {
      return false;
    }
    if (
      !FEC_ConstantCommon.SUB_CODE_RD_PAYMENT_ASSESSMENT_1.equals(subCode) &&
      !FEC_ConstantCommon.SUB_CODE_RD_PAYMENT_ASSESSMENT_2.equals(subCode)
    ) {
      return false;
    }
    Matcher m = FEC_ConstantCommon.PAT_STAGE_NAME_WITH_NUMBER.matcher(
      stageName.trim()
    );
    return m.find() && Integer.valueOf(m.group(1)) == 2;
  }
}
