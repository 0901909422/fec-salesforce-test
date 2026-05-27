/**
 * fecDocumentRequestPdfData.js
 * Utility: build PDF template data cho Document Request từ header data đã query sẵn theo Case.
 * Mỗi template (LSTT, TBCV_LTN) có hàm riêng map key headerData → key PDF placeholder.
 *
 * Nguồn dữ liệu (headerData):
 *   - Apex: FEC_PaymentHistoryValidationService.getDocumentRequestPdfHeaderData(caseId)
 *     query Case → FEC_Customer_History__c (qua FEC_Account_or_Contract__c)
 *     và FEC_Address_Info__c (Address Type = Current Address) để build CustomerAddress.
 *   - Key có sẵn: ContractNumber, NationalID, CustomerName, DateOfIssue, PlaceOfIssue,
 *     TotalLoanAmount, MaturityDate2, CustomerAddress.
 *
 * Lưu ý: MonthlyRate / YearlyRate hiện để trống — chờ FEC chốt mapping.
 */

const SUB_CODE_RL0402 = 'RL04.02';
const SUB_CODE_RL0403 = 'RL04.03';

function pick(headerData, key) {
  const v = headerData?.[key];
  if (v == null) return '';
  return typeof v === 'string' ? v.trim() : v;
}

/**
 * LSTT — Lịch Sử Thanh Toán (RL04.03)
 *
 * Query: Case.FEC_Account_or_Contract__c → FEC_Customer_History__c (getDocumentRequestPdfHeaderData)
 *
 * Placeholder    | Trường nguồn (object.field)
 * ---------------|----------------------------------------------------------
 * CurrentDay     | (computed) ngày hiện tại
 * CurrentMonth   | (computed) tháng hiện tại
 * CurrentYear    | (computed) năm hiện tại
 * ContractNumber | FEC_Customer_History__c.Name
 * NationalID     | FEC_Customer_History__c.FEC_National_ID_Passport_ID__c
 * FullName       | FEC_Customer_History__c.FEC_Customer_Name__c
 * logoUrl        | (static) /resource/Logo
 * _rows          | FEC_Payment_History__c theo Customer History (getPaymentHistoryRows):
 *                  RemovalNote ← FEC_Payment_No__c,
 *                  BankAddress ← FEC_Payment_Date__c (dd/MM/yyyy),
 *                  PaymentAmount ← FEC_Payment_Amount__c
 *
 * @param {Object} headerData  - kết quả Apex getDocumentRequestPdfHeaderData
 * @param {Array}  paymentRows - kết quả Apex getPaymentHistoryRows
 */
function buildLsttData(headerData, paymentRows) {
  const now = new Date();
  return {
    CurrentDay: now.getDate(),
    CurrentMonth: now.getMonth() + 1,
    CurrentYear: now.getFullYear(),
    ContractNumber: pick(headerData, 'ContractNumber'),
    NationalID: pick(headerData, 'NationalID'),
    FullName: pick(headerData, 'CustomerName'),
    logoUrl: '/resource/Logo',
    _rows: paymentRows || []
  };
}

/**
 * TBCV_LTN — Thông Báo Cho Vay / Lịch Trả Nợ (RL04.02)
 *
 * Query header: Case.FEC_Account_or_Contract__c → FEC_Customer_History__c (getDocumentRequestPdfHeaderData)
 * Query địa chỉ: FEC_Address_Info__c (cùng Customer History, FEC_Address_Type__c = 'Current Address')
 *
 * Placeholder        | Trường nguồn (object.field)
 * -------------------|----------------------------------------------------------
 * ContractNumber     | FEC_Customer_History__c.Name
 * CustomerName       | FEC_Customer_History__c.FEC_Customer_Name__c
 * CustomerAddress    | FEC_Address_Info__c.FEC_Full_Address__c
 * NationalID         | FEC_Customer_History__c.FEC_National_ID_Passport_ID__c
 * DateOfIssue        | FEC_Customer_History__c.FEC_Date_of_Issue__c (format dd/MM/yyyy)
 * PlaceOfIssue       | FEC_Customer_History__c.FEC_Place_of_Issue__c
 * TotalLoanAmount    | FEC_Customer_History__c.FEC_Total_Balance__c (format tiền)
 * LoanAmountInVNText | TODO: convert TotalLoanAmount → chữ tiếng Việt
 * MonthlyRate        | TODO: chờ FEC chốt field
 * YearlyRate         | TODO: chờ FEC chốt field
 * MaturityDate2      | FEC_Customer_History__c.FEC_Expiry_Date__c (format dd/MM/yyyy)
 * _rows              | FEC_Repayment_Schedule__c theo Customer History (getRepaymentScheduleRows):
 *                      InstallmentDueDate ← FEC_Installment_Due_Date__c,
 *                      Principal ← FEC_Principal__c,
 *                      Interest ← FEC_Interest__c,
 *                      ClosingPrincipal ← FEC_Closing_Principal__c,
 *                      RepaymentFees ← FEC_Repayment_Fee__c,
 *                      InstallmentAmount ← FEC_Installment_Amount__c
 *
 * @param {Object} headerData     - kết quả Apex getDocumentRequestPdfHeaderData
 * @param {Array}  _paymentRows   - (không dùng cho template này)
 * @param {Array}  repaymentRows  - kết quả Apex getRepaymentScheduleRows
 */
function buildTbcvLtnData(headerData, _paymentRows, repaymentRows) {
  return {
    ContractNumber: pick(headerData, 'ContractNumber'),
    CustomerName: pick(headerData, 'CustomerName'),
    CustomerAddress: pick(headerData, 'CustomerAddress'),
    NationalID: pick(headerData, 'NationalID'),
    DateOfIssue: pick(headerData, 'DateOfIssue'),
    PlaceOfIssue: pick(headerData, 'PlaceOfIssue'),
    TotalLoanAmount: pick(headerData, 'TotalLoanAmount'),
    LoanAmountInVNText: '',
    MonthlyRate: '',
    YearlyRate: '',
    MaturityDate2: pick(headerData, 'MaturityDate2'),
    _rows: repaymentRows || []
  };
}

const PDF_CONFIG_MAP = {
  [SUB_CODE_RL0403]: { templateCode: 'LSTT', buildData: buildLsttData, needsPaymentRows: true, needsRepaymentRows: false },
  [SUB_CODE_RL0402]: { templateCode: 'TBCV_LTN', buildData: buildTbcvLtnData, needsPaymentRows: false, needsRepaymentRows: true }
};

/**
 * Trả config cho sub-code (templateCode + cờ needsPaymentRows / needsRepaymentRows).
 * Trả null nếu sub-code không match RL04.02/RL04.03.
 */
export function getPdfConfigForSubCode(subCodeCode) {
  const code = subCodeCode == null ? '' : String(subCodeCode).trim();
  return PDF_CONFIG_MAP[code] || null;
}

/**
 * Build { templateCode, data } với dữ liệu thực.
 *
 * @param {string} subCodeCode    - business.subCodeCode (e.g. 'RL04.02')
 * @param {Object} headerData     - kết quả Apex getDocumentRequestPdfHeaderData(caseId)
 * @param {Array}  paymentRows    - kết quả Apex getPaymentHistoryRows (cho LSTT)
 * @param {Array}  repaymentRows  - kết quả Apex getRepaymentScheduleRows (cho TBCV_LTN)
 * @returns {{ templateCode: string, data: Object } | null}
 */
export function buildPdfDataForSubCode(subCodeCode, headerData, paymentRows, repaymentRows) {
  const code = subCodeCode == null ? '' : String(subCodeCode).trim();
  const config = PDF_CONFIG_MAP[code];
  if (!config) return null;
  return {
    templateCode: config.templateCode,
    data: config.buildData(headerData, paymentRows, repaymentRows)
  };
}