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
 *     TotalLoanAmount, CustomerAddress.
 *
 * Lưu ý: MonthlyRate / YearlyRate / MaturityDate2 hiện để trống — chờ FEC chốt mapping.
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
 * Placeholder          | Nguồn (headerData key / computed)
 * ---------------------|----------------------------------
 * CurrentDay           | new Date().getDate()
 * CurrentMonth         | new Date().getMonth() + 1
 * CurrentYear          | new Date().getFullYear()
 * ContractNumber       | headerData.ContractNumber
 * NationalID           | headerData.NationalID
 * FullName             | headerData.CustomerName
 * logoUrl              | static '/resource/Logo'
 * _rows                | paymentRows (Apex getPaymentHistoryRows)
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
 * Placeholder          | Nguồn (headerData key / computed / TODO)
 * ---------------------|----------------------------------
 * ContractNumber       | headerData.ContractNumber
 * CustomerName         | headerData.CustomerName
 * CustomerAddress      | headerData.CustomerAddress (FEC_Address_Info__c.FEC_Full_Address__c)
 * NationalID           | headerData.NationalID
 * DateOfIssue          | headerData.DateOfIssue (dd/MM/yyyy)
 * PlaceOfIssue         | headerData.PlaceOfIssue
 * TotalLoanAmount      | headerData.TotalLoanAmount
 * LoanAmountInVNText   | TODO: convert số → chữ tiếng Việt
 * MonthlyRate          | TODO: chờ FEC chốt field
 * YearlyRate           | TODO: chờ FEC chốt field
 * MaturityDate2        | TODO: chờ FEC chốt field (FEC_Expiry_Date__c?)
 * _rows                | repaymentRows (Apex getRepaymentScheduleRows)
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
    MaturityDate2: '',
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
  return PDF_CONFIG_MAP[subCodeCode] || null;
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
  const config = PDF_CONFIG_MAP[subCodeCode];
  if (!config) return null;
  return {
    templateCode: config.templateCode,
    data: config.buildData(headerData, paymentRows, repaymentRows)
  };
}
