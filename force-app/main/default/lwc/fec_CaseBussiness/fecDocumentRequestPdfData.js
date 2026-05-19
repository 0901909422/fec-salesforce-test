/**
 * fecDocumentRequestPdfData.js
 * Utility: build PDF template data cho Document Request từ business object.
 * Mỗi template (LSTT, TBCV_LTN) có hàm riêng map field business → key PDF placeholder.
 *
 * Cách lấy field:
 *   getFieldValue(business, objectName, apiName)
 *   → duyệt business.sectionlst > subSectionlst > objlst > fieldlst
 *   → trả về field.value (hoặc '' nếu không tìm thấy)
 */

const SUB_CODE_RL0402 = 'RL04.02';
const SUB_CODE_RL0403 = 'RL04.03';

/**
 * Lấy giá trị field từ business object theo objectName + apiName.
 * Duyệt toàn bộ sectionlst → subSectionlst → objlst → fieldlst.
 */
function getFieldValue(business, objectName, apiName) {
  for (const section of business?.sectionlst ?? []) {
    for (const sub of section.subSectionlst ?? []) {
      for (const obj of sub.objlst ?? []) {
        if (obj.name !== objectName) continue;
        const f = obj.fieldlst?.find((x) => x.apiName === apiName);
        if (f != null) {
          const v = f.value;
          return typeof v === 'string' ? v.trim() : (v ?? '');
        }
      }
    }
  }
  return '';
}

/**
 * LSTT — Lịch Sử Thanh Toán (RL04.03)
 *
 * Placeholder          | Object                    | Field API Name
 * ---------------------|---------------------------|----------------------------------
 * CurrentDay           | (computed)                | new Date().getDate()
 * CurrentMonth         | (computed)                | new Date().getMonth() + 1
 * CurrentYear          | (computed)                | new Date().getFullYear()
 * ContractNumber       | FEC_Customer_History__c   | FEC_Contract_Number__c
 * NationalID           | FEC_Customer_History__c   | FEC_National_ID_Passport_ID__c
 * FullName             | FEC_Customer_History__c   | FEC_Customer_Name__c
 * logoUrl              | (static)                  | /resource/Logo
 * _rows                | FEC_Payment_History__c    | Apex FEC_PaymentHistoryValidationService.getPaymentHistoryRows
 *                      |                           | (WHERE FEC_Customer_History__c = Case.FEC_Account_or_Contract__c)
 *
 * _rows[] — mỗi phần tử (map 1 dòng bảng PDF LSTT):
 * Row key (PDF)   | Object                  | Field API Name           | Cột PDF / Ghi chú
 * ----------------|-------------------------|--------------------------|------------------------------------------
 * RemovalNote     | FEC_Payment_History__c  | FEC_Payment_No__c        | Số thứ tự
 * BankAddress     | FEC_Payment_History__c  | FEC_Payment_Date__c      | Ngày Khách hàng thanh toán (format dd/MM/yyyy)
 * PaymentAmount   | FEC_Payment_History__c  | FEC_Payment_Amount__c    | Số tiền Khách hàng thanh toán (FormatCurrency)
 *
 * @param {Object} business - business object từ getByCase
 * @param {Array}  paymentRows - kết quả từ Apex getPaymentHistoryRows
 */
function buildLsttData(business, paymentRows) {
  const now = new Date();
  return {
    CurrentDay: now.getDate(),
    CurrentMonth: now.getMonth() + 1,
    CurrentYear: now.getFullYear(),
    // FEC_Customer_History__c.FEC_Contract_Number__c
    ContractNumber: getFieldValue(business, 'FEC_Customer_History__c', 'FEC_Contract_Number__c'),
    // FEC_Customer_History__c.FEC_National_ID_Passport_ID__c
    NationalID: getFieldValue(business, 'FEC_Customer_History__c', 'FEC_National_ID_Passport_ID__c'),
    // FEC_Customer_History__c.FEC_Customer_Name__c
    FullName: getFieldValue(business, 'FEC_Customer_History__c', 'FEC_Customer_Name__c'),
    logoUrl: '/resource/Logo',
    // FEC_Payment_History__c — query bởi Apex theo Case.FEC_Account_or_Contract__c
    _rows: paymentRows || []
  };
}

/**
 * TBCV_LTN — Thông Báo Cho Vay / Lịch Trả Nợ (RL04.02)
 *
 * Placeholder          | Object                    | Field API Name
 * ---------------------|---------------------------|----------------------------------
 * ContractNumber       | FEC_Customer_History__c   | FEC_Contract_Number__c
 * CustomerName         | FEC_Customer_History__c   | FEC_Customer_Name__c
 * CustomerAddress      | Case                      | FEC_Customer_Address__c
 * NationalID           | FEC_Customer_History__c   | FEC_National_ID_Passport_ID__c
 * DateOfIssue          | Case                      | FEC_Date_Of_Issue__c
 * PlaceOfIssue         | Case                      | FEC_Place_Of_Issue__c
 * TotalLoanAmount      | FEC_Customer_History__c   | FEC_Total_Balance__c
 * LoanAmountInVNText   | (TODO)                    | Chuyển số → chữ tiếng Việt — tạm để trống
 * MonthlyRate          | FEC_Customer_History__c   | FEC_Monthly_Rate__c
 * YearlyRate           | FEC_Customer_History__c   | FEC_Yearly_Rate__c
 * MaturityDate2        | FEC_Customer_History__c   | FEC_Expiry_Date__c
 * _rows                | FEC_Repayment_Schedule__c | Apex FEC_PaymentHistoryValidationService.getRepaymentScheduleRows
 *                      |                           | (WHERE FEC_Customer_History__c = Case.FEC_Account_or_Contract__c)
 *
 * _rows[] — mỗi phần tử (map 1 dòng bảng PDF TBCV_LTN):
 * Row key (PDF)      | Object                     | Field API Name              | Cột PDF / Ghi chú
 * -------------------|----------------------------|-----------------------------|------------------------------------------
 * InstallmentDueDate | FEC_Repayment_Schedule__c  | FEC_Installment_Due_Date__c | Ngày đến hạn trả nợ (format dd/MM/yyyy)
 * Principal          | FEC_Repayment_Schedule__c  | FEC_Principal__c            | Nợ gốc phải trả (FormatCurrency)
 * Interest           | FEC_Repayment_Schedule__c  | FEC_Interest__c             | Lãi phải trả (FormatCurrency)
 * ClosingPrincipal   | FEC_Repayment_Schedule__c  | FEC_Closing_Principal__c    | Nợ gốc còn lại (FormatCurrency)
 * RepaymentFees      | FEC_Repayment_Schedule__c  | FEC_Repayment_Fee__c        | Phí dịch vụ thu hộ phải trả (FormatCurrency)
 * InstallmentAmount  | FEC_Repayment_Schedule__c  | FEC_Installment_Amount__c   | Tổng số tiền phải trả trong tháng (FormatCurrency)
 *
 * @param {Object} business       - business object từ getByCase
 * @param {Array}  _paymentRows   - (không dùng cho template này)
 * @param {Array}  repaymentRows  - kết quả từ Apex getRepaymentScheduleRows
 */
function buildTbcvLtnData(business, _paymentRows, repaymentRows) {
  return {
    // FEC_Customer_History__c.FEC_Contract_Number__c
    ContractNumber: getFieldValue(business, 'FEC_Customer_History__c', 'FEC_Contract_Number__c'),
    // FEC_Customer_History__c.FEC_Customer_Name__c
    CustomerName: getFieldValue(business, 'FEC_Customer_History__c', 'FEC_Customer_Name__c'),
    // Case.FEC_Customer_Address__c
    CustomerAddress: getFieldValue(business, 'Case', 'FEC_Customer_Address__c'),
    // FEC_Customer_History__c.FEC_National_ID_Passport_ID__c
    NationalID: getFieldValue(business, 'FEC_Customer_History__c', 'FEC_National_ID_Passport_ID__c'),
    // Case.FEC_Date_Of_Issue__c
    DateOfIssue: getFieldValue(business, 'Case', 'FEC_Date_Of_Issue__c'),
    // Case.FEC_Place_Of_Issue__c
    PlaceOfIssue: getFieldValue(business, 'Case', 'FEC_Place_Of_Issue__c'),
    // FEC_Customer_History__c.FEC_Total_Balance__c
    TotalLoanAmount: getFieldValue(business, 'FEC_Customer_History__c', 'FEC_Total_Balance__c'),
    // TODO: cần convert TotalLoanAmount sang chữ tiếng Việt
    LoanAmountInVNText: '',
    // FEC_Customer_History__c.FEC_Monthly_Rate__c
    MonthlyRate: getFieldValue(business, 'FEC_Customer_History__c', 'FEC_Monthly_Rate__c'),
    // FEC_Customer_History__c.FEC_Yearly_Rate__c
    YearlyRate: getFieldValue(business, 'FEC_Customer_History__c', 'FEC_Yearly_Rate__c'),
    // FEC_Customer_History__c.FEC_Expiry_Date__c
    MaturityDate2: getFieldValue(business, 'FEC_Customer_History__c', 'FEC_Expiry_Date__c'),
    // FEC_Repayment_Schedule__c — query bởi Apex theo Case.FEC_Account_or_Contract__c
    _rows: repaymentRows || []
  };
}

const PDF_CONFIG_MAP = {
  [SUB_CODE_RL0403]: { templateCode: 'LSTT', buildData: buildLsttData, needsPaymentRows: true, needsRepaymentRows: false },
  [SUB_CODE_RL0402]: { templateCode: 'TBCV_LTN', buildData: buildTbcvLtnData, needsPaymentRows: false, needsRepaymentRows: true }
};

/**
 * Trả config cho sub-code (templateCode + cờ needsPaymentRows).
 * Trả null nếu sub-code không match RL04.02/RL04.03.
 */
export function getPdfConfigForSubCode(subCodeCode) {
  return PDF_CONFIG_MAP[subCodeCode] || null;
}

/**
 * Build { templateCode, data } với dữ liệu thực.
 *
 * @param {string} subCodeCode  - business.subCodeCode (e.g. 'RL04.02')
 * @param {Object} business        - business object từ getByCase (chứa sectionlst)
 * @param {Array}  paymentRows     - kết quả từ Apex getPaymentHistoryRows (cho LSTT)
 * @param {Array}  repaymentRows   - kết quả từ Apex getRepaymentScheduleRows (cho TBCV_LTN)
 * @returns {{ templateCode: string, data: Object } | null}
 */
export function buildPdfDataForSubCode(subCodeCode, business, paymentRows, repaymentRows) {
  const config = PDF_CONFIG_MAP[subCodeCode];
  if (!config) return null;
  return {
    templateCode: config.templateCode,
    data: config.buildData(business, paymentRows, repaymentRows)
  };
}