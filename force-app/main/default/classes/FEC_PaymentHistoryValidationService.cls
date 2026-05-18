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

  public static String getValidationMessage(String caseId, String subCodeId) {
    PaymentHistoryRequestValidationResult validation =
      validatePaymentHistoryRequestForSubCode(caseId, subCodeId);
    if (String.isNotBlank(validation.message)) {
      return validation.message;
    }
    if (String.isNotBlank(validation.infoMessage)) {
      return validation.infoMessage;
    }
    return null;
  }

  /**
   * Document Request — lấy header data cho PDF (LSTT / TBCV_LTN) theo Case.
   *
   * Nguồn dữ liệu:
   *   - Customer History: Case.FEC_Account_or_Contract__r (relationship -> FEC_Customer_History__c)
   *   - Customer Address: FEC_Address_Info__c có cùng Customer History & FEC_Address_Type__c = 'Current Address'
   *
   * Mapping key trả về tương ứng placeholder PDF (xem fecDocumentRequestPdfData.js):
   *   ContractNumber   : FEC_Customer_History__c.FEC_Contract_Number__c
   *   NationalID       : FEC_Customer_History__c.FEC_National_ID_Passport_ID__c
   *   CustomerName     : FEC_Customer_History__c.FEC_Customer_Name__c
   *   DateOfIssue      : FEC_Customer_History__c.FEC_Date_of_Issue__c (format dd/MM/yyyy)
   *   PlaceOfIssue     : FEC_Customer_History__c.FEC_Place_of_Issue__c
   *   TotalLoanAmount  : FEC_Customer_History__c.FEC_Total_Balance__c
   *   CustomerAddress  : FEC_Address_Info__c.FEC_Full_Address__c (Address Type = Current Address)
   *
   * Trả Map rỗng nếu Case không có Customer History.
   */
  @AuraEnabled
  public static Map<String, Object> getDocumentRequestPdfHeaderData(String caseId) {
    Map<String, Object> data = new Map<String, Object>();
    if (String.isBlank(caseId)) {
      return data;
    }
    List<Case> cases = [
      SELECT
        FEC_Account_or_Contract__c,
        FEC_Account_or_Contract__r.Name,
        FEC_Account_or_Contract__r.FEC_Contract_Number__c,
        FEC_Account_or_Contract__r.FEC_Account_Number__c,
        FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c,
        FEC_Account_or_Contract__r.FEC_Customer_Name__c,
        FEC_Account_or_Contract__r.FEC_Date_of_Issue__c,
        FEC_Account_or_Contract__r.FEC_Place_of_Issue__c,
        FEC_Account_or_Contract__r.FEC_Total_Balance__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    if (cases.isEmpty() || cases[0].FEC_Account_or_Contract__c == null) {
      return data;
    }
    FEC_Customer_History__c h = cases[0].FEC_Account_or_Contract__r;
    Id customerHistoryId = cases[0].FEC_Account_or_Contract__c;

    data.put('ContractNumber', h.Name);
    data.put('NationalID', h.FEC_National_ID_Passport_ID__c);
    data.put('CustomerName', h.FEC_Customer_Name__c);
    data.put('PlaceOfIssue', h.FEC_Place_of_Issue__c);
    data.put(
      'TotalLoanAmount',
      h.FEC_Total_Balance__c != null
        ? FEC_CommonUltils.formatCurrency(h.FEC_Total_Balance__c, 0)
        : FEC_ConstantCommon.STR_EMPTY
    );
    if (h.FEC_Date_of_Issue__c != null) {
      DateTime issueDt = DateTime.newInstance(
        h.FEC_Date_of_Issue__c.year(),
        h.FEC_Date_of_Issue__c.month(),
        h.FEC_Date_of_Issue__c.day()
      );
      data.put('DateOfIssue', issueDt.format('dd/MM/yyyy'));
    } else {
      data.put('DateOfIssue', FEC_ConstantCommon.STR_EMPTY);
    }

    List<FEC_Address_Info__c> addrRows = [
      SELECT FEC_Full_Address__c
      FROM FEC_Address_Info__c
      WHERE FEC_Customer_History__c = :customerHistoryId
        AND FEC_Address_Type__c = 'Current Address'
      ORDER BY LastModifiedDate DESC
      LIMIT 1
    ];
    data.put(
      'CustomerAddress',
      addrRows.isEmpty() ? FEC_ConstantCommon.STR_EMPTY : addrRows[0].FEC_Full_Address__c
    );
    return data;
  }

  @AuraEnabled
  public static List<Map<String, Object>> getPaymentHistoryRows(String caseId) {
    List<Map<String, Object>> rows = new List<Map<String, Object>>();
    if (String.isBlank(caseId)) {
      return rows;
    }
    List<Case> cases = [
      SELECT FEC_Account_or_Contract__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    if (cases.isEmpty() || cases[0].FEC_Account_or_Contract__c == null) {
      return rows;
    }
    Id customerHistoryId = cases[0].FEC_Account_or_Contract__c;
    List<FEC_Payment_History__c> payments = [
      SELECT FEC_Payment_No__c, FEC_Payment_Date__c, FEC_Payment_Amount__c
      FROM FEC_Payment_History__c
      WHERE FEC_Customer_History__c = :customerHistoryId
      ORDER BY FEC_Payment_No__c ASC
    ];
    for (FEC_Payment_History__c p : payments) {
      Map<String, Object> row = new Map<String, Object>();
      row.put('RemovalNote', p.FEC_Payment_No__c);
      row.put('BankAddress', p.FEC_Payment_Date__c != null
        ? ((DateTime) p.FEC_Payment_Date__c).format('dd/MM/yyyy') : '');
      row.put('PaymentAmount', p.FEC_Payment_Amount__c);
      rows.add(row);
    }
    return rows;
  }

  @AuraEnabled
  public static List<Map<String, Object>> getRepaymentScheduleRows(String caseId) {
    List<Map<String, Object>> rows = new List<Map<String, Object>>();
    if (String.isBlank(caseId)) {
      return rows;
    }
    List<Case> cases = [
      SELECT FEC_Account_or_Contract__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    if (cases.isEmpty() || cases[0].FEC_Account_or_Contract__c == null) {
      return rows;
    }
    Id customerHistoryId = cases[0].FEC_Account_or_Contract__c;
    List<FEC_Repayment_Schedule__c> schedules = [
      SELECT FEC_Installment_Due_Date__c, FEC_Principal__c, FEC_Interest__c,
             FEC_Closing_Principal__c, FEC_Repayment_Fee__c, FEC_Installment_Amount__c
      FROM FEC_Repayment_Schedule__c
      WHERE FEC_Customer_History__c = :customerHistoryId
      ORDER BY FEC_Installment_Due_Date__c ASC
    ];
    for (FEC_Repayment_Schedule__c s : schedules) {
      Map<String, Object> row = new Map<String, Object>();
      row.put('InstallmentDueDate', s.FEC_Installment_Due_Date__c != null
        ? ((DateTime) s.FEC_Installment_Due_Date__c).format('dd/MM/yyyy') : '');
      row.put('Principal', s.FEC_Principal__c);
      row.put('Interest', s.FEC_Interest__c);
      row.put('ClosingPrincipal', s.FEC_Closing_Principal__c);
      row.put('RepaymentFees', s.FEC_Repayment_Fee__c);
      row.put('InstallmentAmount', s.FEC_Installment_Amount__c);
      rows.add(row);
    }
    return rows;
  }
}