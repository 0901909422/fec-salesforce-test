public with sharing class FEC_PaymentHistoryValidationService {

  public class PaymentHistoryRequestValidationResult {
    @AuraEnabled
    public Boolean allowed { get; set; }
    @AuraEnabled
    public String message { get; set; }
    @AuraEnabled
    public String infoMessage { get; set; }
  }

  private static final String SUB_CODE_RL0402_REPAYMENT_SCHEDULE = 'RL04.02';
  private static final String SUB_CODE_RL0403_PAYMENT_HISTORY = 'RL04.03';
  private static final String SUB_CODE_RC0404_CARD_CLOSE_CERTIFICATE = 'RC04.04';
  private static final String CONTRACT_STATUS_CLOSED = 'Closed';
  private static final String CONTRACT_STATUS_ACTIVE = 'Active';
  private static final String ACCOUNT_STATUS_T1_8 = '8';
  private static final String ACCOUNT_STATUS_T1_9 = '9';
  private static final String CARD_BLOCK_CODE_C = 'C';

  /**
   * RC04.04 — Giấy xác nhận đóng thẻ: gợi ý infoMessage khi
   * Account Status (T-1) in (8,9) OR (not in (8,9) AND ít nhất một: Block Code = C, IPP Principal T-1 = 0, OTB >= Credit Limit).
   *
   * Field mapping:
   *   Account Status : FEC_Customer_History__c.FEC_Account_Status__c
   *   Block Code     : FEC_Customer_History__c.FEC_Block_Code__c
   *   IPP Principal  : FEC_Statement__c.FEC_IPP_Principal__c  (kỳ sao kê gần nhất của Customer History)
   *   OTB            : FEC_Customer_History__c.FEC_OTB__c
   *   Card Limit     : FEC_Customer_History__c.FEC_Credit_Limit__c
   */
  private static String buildRc0404InfoMessageIfEligible(Id customerHistoryId) {
    if (customerHistoryId == null) {
      return null;
    }
    List<FEC_Customer_History__c> rows = [
      SELECT
        FEC_Account_Status__c,
        FEC_Block_Code__c,
        FEC_OTB__c,
        FEC_Credit_Limit__c
      FROM FEC_Customer_History__c
      WHERE Id = :customerHistoryId
      LIMIT 1
    ];
    if (rows.isEmpty()) {
      return null;
    }
    FEC_Customer_History__c h = rows[0];

    String acctStatus = String.isBlank(h.FEC_Account_Status__c)
      ? FEC_ConstantCommon.STR_EMPTY
      : h.FEC_Account_Status__c.trim();
    Boolean statusEightOrNine =
      ACCOUNT_STATUS_T1_8.equals(acctStatus) || ACCOUNT_STATUS_T1_9.equals(acctStatus);

    String block = String.isBlank(h.FEC_Block_Code__c)
      ? FEC_ConstantCommon.STR_EMPTY
      : h.FEC_Block_Code__c.trim();
    Boolean blockCodeC = CARD_BLOCK_CODE_C.equals(block);

    Decimal otb = h.FEC_OTB__c;
    Decimal limitAmt = h.FEC_Credit_Limit__c;
    Boolean otbGteLimit =
      otb != null && limitAmt != null && otb >= limitAmt;

    Boolean ippPrincipalZero = false;
    List<FEC_Statement__c> stmtRows = [
      SELECT FEC_IPP_Principal__c
      FROM FEC_Statement__c
      WHERE
        FEC_Customer_History__c = :customerHistoryId
        AND FEC_Statement_Date__c != NULL
      ORDER BY FEC_Statement_Date__c DESC, CreatedDate DESC
      LIMIT 1
    ];
    if (!stmtRows.isEmpty() && stmtRows[0].FEC_IPP_Principal__c != null) {
      ippPrincipalZero = stmtRows[0].FEC_IPP_Principal__c == 0;
    }

    if (statusEightOrNine || (!statusEightOrNine && (blockCodeC || ippPrincipalZero || otbGteLimit))) {
      return System.Label.FEC_MSG_Can_Create_Card_Close_Certificate;
    }
    return null;
  }

  /**
   * RL04.02: chặn chỉ khi Contract Status = Closed (thông báo lịch trả nợ).
   * RL04.03: Closed hoặc Active với COUNT FEC_Payment_History__c theo Customer History below 7 (thông báo lịch sử thanh toán).
   * RC04.04: không chặn; trả infoMessage khi đủ điều kiện gợi ý giấy xác nhận đóng thẻ.
   */
  @AuraEnabled
  public static PaymentHistoryRequestValidationResult validatePaymentHistoryRequestForSubCode(
    String caseId,
    String subCodeId
  ) {
    PaymentHistoryRequestValidationResult result = new PaymentHistoryRequestValidationResult();
    result.allowed = true;
    result.message = null;
    result.infoMessage = null;

    if (String.isBlank(caseId) || String.isBlank(subCodeId)) {
      return result;
    }

    List<FEC_Sub_Code__c> subRows = [
      SELECT FEC_Code__c
      FROM FEC_Sub_Code__c
      WHERE Id = :subCodeId
      LIMIT 1
    ];
    if (subRows.isEmpty()) {
      return result;
    }
    String codeRaw = subRows[0].FEC_Code__c;
    String code = String.isBlank(codeRaw) ? FEC_ConstantCommon.STR_EMPTY : codeRaw.trim();
    Boolean isRl0402 = SUB_CODE_RL0402_REPAYMENT_SCHEDULE.equalsIgnoreCase(code);
    Boolean isRl0403 = SUB_CODE_RL0403_PAYMENT_HISTORY.equalsIgnoreCase(code);
    Boolean isRc0404 = SUB_CODE_RC0404_CARD_CLOSE_CERTIFICATE.equalsIgnoreCase(code);

    List<Case> cases = [
      SELECT FEC_Account_or_Contract__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    Id customerHistoryId =
      (!cases.isEmpty() && cases[0].FEC_Account_or_Contract__c != null)
        ? cases[0].FEC_Account_or_Contract__c
        : null;

    if (isRc0404) {
      result.infoMessage = buildRc0404InfoMessageIfEligible(customerHistoryId);
      return result;
    }

    if (!isRl0402 && !isRl0403) {
      return result;
    }

    if (isRl0402) {
      if (customerHistoryId == null) {
        return result;
      }
      List<FEC_Customer_History__c> histories0402 = [
        SELECT FEC_Contract_Status__c
        FROM FEC_Customer_History__c
        WHERE Id = :customerHistoryId
        LIMIT 1
      ];
      if (histories0402.isEmpty()) {
        return result;
      }
      if (CONTRACT_STATUS_CLOSED.equals(histories0402[0].FEC_Contract_Status__c)) {
        result.allowed = false;
        result.message = System.Label.FEC_MSG_Cannot_Request_Repayment_Schedule;
      }
      return result;
    }

    // RL04.03 — payment history request
    if (cases.isEmpty() || cases[0].FEC_Account_or_Contract__c == null) {
      result.allowed = false;
      result.message = System.Label.FEC_MSG_Cannot_Request_Payment_History;
      return result;
    }

    List<FEC_Customer_History__c> histories = [
      SELECT Id, FEC_Contract_Status__c
      FROM FEC_Customer_History__c
      WHERE Id = :cases[0].FEC_Account_or_Contract__c
      LIMIT 1
    ];
    if (histories.isEmpty()) {
      result.allowed = false;
      result.message = System.Label.FEC_MSG_Cannot_Request_Payment_History;
      return result;
    }

    String contractStatus = histories[0].FEC_Contract_Status__c;
    if (CONTRACT_STATUS_CLOSED.equals(contractStatus)) {
      result.allowed = false;
      result.message = System.Label.FEC_MSG_Cannot_Request_Payment_History;
      return result;
    }

    if (CONTRACT_STATUS_ACTIVE.equals(contractStatus)) {
      Integer paymentCount = [
        SELECT COUNT()
        FROM FEC_Payment_History__c
        WHERE FEC_Customer_History__c = :histories[0].Id
      ];
      if (paymentCount < 7) {
        result.allowed = false;
        result.message = System.Label.FEC_MSG_Cannot_Request_Payment_History;
        return result;
      }
    }

    return result;
  }

  public static Boolean hasValidationMessage(String caseId, String subCodeId) {
    PaymentHistoryRequestValidationResult validation =
      validatePaymentHistoryRequestForSubCode(caseId, subCodeId);
    return String.isNotBlank(validation.message) || String.isNotBlank(validation.infoMessage);
  }
}
