import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSectionData from '@salesforce/apex/FEC_RepaySchedPayHistController.getSectionData';
import FEC_Repayment_Schedule_Label from '@salesforce/label/c.FEC_Repayment_Schedule_Label';
import FEC_Payment_History_Label from '@salesforce/label/c.FEC_Payment_History_Label';
import FEC_Real_Time_Payment_Label from '@salesforce/label/c.FEC_Real_Time_Payment_Label';
import FEC_Repayment_Schedule_Payment_History_Label from '@salesforce/label/c.FEC_Repayment_Schedule_Payment_History_Label';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import FEC_Termination_Loading_Alt from '@salesforce/label/c.FEC_Termination_Loading_Alt';
import FEC_Repay_Total_Installment_Amount_Label from '@salesforce/label/c.FEC_Repay_Total_Installment_Amount_Label';
import FEC_Repay_Total_Principal_Label from '@salesforce/label/c.FEC_Repay_Total_Principal_Label';
import FEC_Repay_Total_Interest_Label from '@salesforce/label/c.FEC_Repay_Total_Interest_Label';
import FEC_Repay_Total_Payment_Amount_Label from '@salesforce/label/c.FEC_Repay_Total_Payment_Amount_Label';
import FEC_Repay_Installment_No_Label from '@salesforce/label/c.FEC_Repay_Installment_No_Label';
import FEC_Repay_Installment_Due_Date_Label from '@salesforce/label/c.FEC_Repay_Installment_Due_Date_Label';
import FEC_Repay_EMI_Label from '@salesforce/label/c.FEC_Repay_EMI_Label';
import FEC_Repay_Repayment_Fee_Label from '@salesforce/label/c.FEC_Repay_Repayment_Fee_Label';
import FEC_Repay_Installment_Amount_Label from '@salesforce/label/c.FEC_Repay_Installment_Amount_Label';
import FEC_Repay_Principal_Label from '@salesforce/label/c.FEC_Repay_Principal_Label';
import FEC_Repay_Interest_Label from '@salesforce/label/c.FEC_Repay_Interest_Label';
import FEC_Repay_Opening_Principal_Label from '@salesforce/label/c.FEC_Repay_Opening_Principal_Label';
import FEC_Repay_Closing_Principal_Label from '@salesforce/label/c.FEC_Repay_Closing_Principal_Label';
import FEC_Repay_Payment_No_Label from '@salesforce/label/c.FEC_Repay_Payment_No_Label';
import FEC_Repay_Payment_Date_Label from '@salesforce/label/c.FEC_Repay_Payment_Date_Label';
import FEC_Repay_Booking_Date_Label from '@salesforce/label/c.FEC_Repay_Booking_Date_Label';
import FEC_Repay_Payment_Amount_Label from '@salesforce/label/c.FEC_Repay_Payment_Amount_Label';
import FEC_Repay_Particulars_Label from '@salesforce/label/c.FEC_Repay_Particulars_Label';
import FEC_Repay_Payment_Channel_Label from '@salesforce/label/c.FEC_Repay_Payment_Channel_Label';
import FEC_Repay_No_Data_Label from '@salesforce/label/c.FEC_Repay_No_Data_Label';
import FEC_Repay_Refresh_Button_Label from '@salesforce/label/c.FEC_Repay_Refresh_Button_Label';
const SECTION4_EMPTY_CELL = '-';
const SECTION4_TYPE_SCHEDULE = 'Repayment Schedule';
const SECTION4_TYPE_PAYMENT = 'Payment History';

/** Ô trống / placeholder từ API (giống HYPHEN Apex). */
const isRepayEmptyCell = (value) =>
    value == null || String(value).trim() === '' || String(value).trim() === SECTION4_EMPTY_CELL;

/**
 * Bỏ dòng Payment History do max(basicPh, secPh, payments) tạo thêm: chỉ còn paymentNo.
 */
const isPaymentHistoryMeaningfulRow = (row) => {
    if (!row) return false;
    return !(
        isRepayEmptyCell(row.paymentDate) &&
        isRepayEmptyCell(row.bookingDate) &&
        isRepayEmptyCell(row.paymentAmount) &&
        isRepayEmptyCell(row.particulars) &&
        isRepayEmptyCell(row.paymentChannel)
    );
};

import { toSortDateStr } from 'c/fec_CommonUtils';

/**
 * LWC Repayment Schedule & Payment History - 4 sections:
 * Repayment Schedule, Payment History, Real-Time Payment, Repayment Schedule & Payment History
 */
export default class Fec_RepaymentSchedulePaymentHistory extends LightningElement {
    @api recordId;

    @track errorMessage;
    @track sectionData = {};
    /** Chỉ dùng cho section 4; được cập nhật khi bấm Refresh (cùng section 3). Section 1 & 2 giữ sectionData. */
    @track section4Data = { repaymentScheduleTable: [], paymentHistoryTable: [] };
    @track helpTextMap = {};
    @track isLoading = false;
    @track isRefreshingRealTime = false;
    refreshStatusMap = { realTimePayment: 'NONE' };
    pageSizeOptions = [12, 24, 36, 48];

    customLabel = {
        repaymentSchedule: FEC_Repayment_Schedule_Label,
        paymentHistory: FEC_Payment_History_Label,
        realTimePayment: FEC_Real_Time_Payment_Label,
        repaymentSchedulePaymentHistory: FEC_Repayment_Schedule_Payment_History_Label,
        msgErrorAPI: FEC_MSG_Error_API_Label,
        loadingAlt: FEC_Termination_Loading_Alt,
        totalInstallmentAmount: FEC_Repay_Total_Installment_Amount_Label,
        totalPrincipal: FEC_Repay_Total_Principal_Label,
        totalInterest: FEC_Repay_Total_Interest_Label,
        totalPaymentAmount: FEC_Repay_Total_Payment_Amount_Label,
        noData: FEC_Repay_No_Data_Label,
        refreshButton: FEC_Repay_Refresh_Button_Label,
    };

    get activeSections() {
        return [
            FEC_Repayment_Schedule_Label,
            FEC_Payment_History_Label,
            FEC_Real_Time_Payment_Label,
            FEC_Repayment_Schedule_Payment_History_Label,
        ];
    }

    get repaymentScheduleSectionName() {
        return FEC_Repayment_Schedule_Label;
    }

    get repaymentScheduleTotalInstallment() {
        const t = this.sectionData.repaymentScheduleTotals || {};
        return t.totalInstallmentAmount != null && t.totalInstallmentAmount !== '' ? t.totalInstallmentAmount : '-';
    }

    get repaymentScheduleTotalPrincipal() {
        const t = this.sectionData.repaymentScheduleTotals || {};
        return t.totalPrincipal != null && t.totalPrincipal !== '' ? t.totalPrincipal : '-';
    }

    get repaymentScheduleTotalInterest() {
        const t = this.sectionData.repaymentScheduleTotals || {};
        return t.totalInterest != null && t.totalInterest !== '' ? t.totalInterest : '-';
    }

    /* Repayment Schedule bảng – 12 dòng/trang, sort theo Installment Due Date (cũ → mới). */
    repaymentSchedulePageSize = 12;

    get repaymentSchedulePagingColumns() {
        const cols = [
            { label: FEC_Repay_Installment_No_Label, fieldName: 'installmentNo' },
            { label: FEC_Repay_Installment_Due_Date_Label, fieldName: 'dueDate' },
            { label: FEC_Repay_EMI_Label, fieldName: 'emi', cellAlign: 'right' },
            { label: FEC_Repay_Repayment_Fee_Label, fieldName: 'repaymentFee', cellAlign: 'right' },
            { label: FEC_Repay_Installment_Amount_Label, fieldName: 'installmentAmount', cellAlign: 'right' },
            { label: FEC_Repay_Principal_Label, fieldName: 'principal', cellAlign: 'right' },
            { label: FEC_Repay_Interest_Label, fieldName: 'interest', cellAlign: 'right' },
            { label: FEC_Repay_Opening_Principal_Label, fieldName: 'openingPrincipal', cellAlign: 'right' },
            { label: FEC_Repay_Closing_Principal_Label, fieldName: 'closingPrincipal', cellAlign: 'right' },
        ];
        return cols.map((c) => ({
            ...c,
            headerClass: 'repay-paging-th' + (c.cellAlign === 'right' ? ' slds-text-align_right' : ''),
        }));
    }

    get repaymentSchedulePagingRecords() {
        const data = Array.isArray(this.sectionData.repaymentScheduleTable) ? this.sectionData.repaymentScheduleTable : [];
        const sorted = [...data].sort((a, b) => {
            const sa = toSortDateStr(a?.dueDate);
            const sb = toSortDateStr(b?.dueDate);
            if (sa === sb) return 0;
            return sa < sb ? -1 : 1;
        });
        return sorted.map((row, i) => ({
            Id: 'rs-' + (row.rowIndex != null ? row.rowIndex : i + 1),
            ...row,
        }));
    }

    get hasRepaymentScheduleTableData() {
        return this.repaymentSchedulePagingRecords.length > 0;
    }

    get paymentHistorySectionName() {
        return FEC_Payment_History_Label;
    }

    get hasData() {
        return !this.errorMessage;
    }

    /* Payment History: Total Payment Amount (màu đỏ) + bảng 6 cột */
    get paymentHistoryTotalAmount() {
        const totals = this.sectionData.paymentHistoryTotals || {};
        return totals.totalPaymentAmount != null && totals.totalPaymentAmount !== '' ? totals.totalPaymentAmount : '-';
    }

    /* Payment History bảng – related-list-addresses-paging */
    paymentHistoryPageSize = 10;

    get paymentHistoryPagingColumns() {
        const cols = [
            { label: FEC_Repay_Payment_No_Label, fieldName: 'paymentNo' },
            { label: FEC_Repay_Payment_Date_Label, fieldName: 'paymentDate' },
            { label: FEC_Repay_Booking_Date_Label, fieldName: 'bookingDate' },
            { label: FEC_Repay_Payment_Amount_Label, fieldName: 'paymentAmount', cellAlign: 'right' },
            { label: FEC_Repay_Particulars_Label, fieldName: 'particulars' },
            { label: FEC_Repay_Payment_Channel_Label, fieldName: 'paymentChannel' },
        ];
        return cols.map((c) => ({
            ...c,
            headerClass: 'repay-paging-th' + (c.cellAlign === 'right' ? ' slds-text-align_right' : ''),
        }));
    }

    get paymentHistoryPagingRecords() {
        const data = Array.isArray(this.sectionData.paymentHistoryTable) ? this.sectionData.paymentHistoryTable : [];
        const toTime = (value) => {
            if (!value || value === '-') return null;
            const s = String(value).trim();
            const parts = s.split('/');
            if (parts.length === 3) {
                const d = Number(parts[0]);
                const m = Number(parts[1]);
                const y = Number(parts[2]);
                const t = new Date(y, m - 1, d).getTime();
                return Number.isNaN(t) ? null : t;
            }
            const t = Date.parse(s);
            return Number.isNaN(t) ? null : t;
        };

        const sorted = data.filter(isPaymentHistoryMeaningfulRow).sort((a, b) => {
            const ta = toTime(a?.paymentDate);
            const tb = toTime(b?.paymentDate);
            if (ta == null && tb != null) return 1;
            if (ta != null && tb == null) return -1;
            if (ta == null && tb == null) return 0;
            return ta - tb;
        });

        return sorted.map((row, i) => {
            return {
                Id: 'ph-' + i,
                ...row,
                paymentNo: i + 1,
            };
        });
    }

    get hasPaymentHistoryTableData() {
        return this.paymentHistoryPagingRecords.length > 0;
    }

    get realTimePaymentSectionName() {
        return FEC_Real_Time_Payment_Label;
    }

    /* Real-Time Payment bảng – related-list-addresses-paging */
    realTimePaymentPageSize = 10;

    get realTimePaymentPagingColumns() {
        const cols = [
            { label: FEC_Repay_Payment_Date_Label, fieldName: 'paymentDate' },
            { label: FEC_Repay_Payment_Amount_Label, fieldName: 'paymentAmount', cellAlign: 'right' },
            { label: FEC_Repay_Payment_Channel_Label, fieldName: 'paymentChannel' },
        ];
        return cols.map((c) => ({
            ...c,
            headerClass: 'repay-paging-th' + (c.cellAlign === 'right' ? ' slds-text-align_right' : ''),
        }));
    }

    get realTimePaymentPagingRecords() {
        const data = Array.isArray(this.sectionData.realTimePaymentTable) ? this.sectionData.realTimePaymentTable : [];
        return data.map((row, i) => ({
            Id: 'rt-' + (row.rowIndex != null ? row.rowIndex : i + 1),
            ...row,
        }));
    }

    get hasRealTimePaymentTableData() {
        return this.realTimePaymentPagingRecords.length > 0;
    }

    get repaymentSchedulePaymentHistorySectionName() {
        return FEC_Repayment_Schedule_Payment_History_Label;
    }

    /* Section 4: một bảng gộp Repayment Schedule + Payment History */
    section4PageSize = 10;

    get section4CombinedColumns() {
        const cols = [
            { label: FEC_Repay_Installment_No_Label, fieldName: 'installmentNo' },
            { label: FEC_Repay_Payment_No_Label, fieldName: 'paymentNo' },
            { label: FEC_Repay_Installment_Due_Date_Label, fieldName: 'dueDate' },
            { label: FEC_Repay_Opening_Principal_Label, fieldName: 'openingPrincipal', cellAlign: 'right' },
            { label: FEC_Repay_EMI_Label, fieldName: 'emi', cellAlign: 'right' },
            { label: FEC_Repay_Repayment_Fee_Label, fieldName: 'repaymentFee', cellAlign: 'right' },
            { label: FEC_Repay_Installment_Amount_Label, fieldName: 'installmentAmount', cellAlign: 'right' },
            { label: FEC_Repay_Principal_Label, fieldName: 'principal', cellAlign: 'right' },
            { label: FEC_Repay_Interest_Label, fieldName: 'interest', cellAlign: 'right' },
            { label: FEC_Repay_Closing_Principal_Label, fieldName: 'closingPrincipal', cellAlign: 'right' },
            { label: FEC_Repay_Payment_Date_Label, fieldName: 'paymentDate' },
            { label: FEC_Repay_Booking_Date_Label, fieldName: 'bookingDate' },
            { label: FEC_Repay_Payment_Amount_Label, fieldName: 'paymentAmount', cellAlign: 'right' },
            { label: FEC_Repay_Particulars_Label, fieldName: 'particulars' },
            { label: FEC_Repay_Payment_Channel_Label, fieldName: 'paymentChannel' },
        ];
        return cols.map((c) => ({
            ...c,
            headerClass: 'repay-paging-th' + (c.cellAlign === 'right' ? ' slds-text-align_right' : ''),
        }));
    }

    /* Section 4: nối 2 danh sách – mỗi bản ghi của Repayment Schedule/Payment History là 1 dòng riêng. */
    get section4CombinedRecords() {
        const scheduleList = Array.isArray(this.section4Data.repaymentScheduleTable) ? this.section4Data.repaymentScheduleTable : [];
        const paymentList = Array.isArray(this.section4Data.paymentHistoryTable) ? this.section4Data.paymentHistoryTable : [];
        const e = SECTION4_EMPTY_CELL;
        if (scheduleList.length === 0 && paymentList.length === 0) return [];

        const rows = [];

        // Add all Repayment Schedule rows first.
        for (let i = 0; i < scheduleList.length; i++) {
            const s = scheduleList[i] || {};
            const dueDateVal = (s.dueDate != null && s.dueDate !== '') ? s.dueDate : e;
            rows.push({
                Id: 's4-s-' + (i + 1),
                rowType: SECTION4_TYPE_SCHEDULE,
                installmentNo: (s.installmentNo != null && s.installmentNo !== '') ? s.installmentNo : e,
                dueDate: dueDateVal,
                openingPrincipal: (s.openingPrincipal != null && s.openingPrincipal !== '') ? s.openingPrincipal : e,
                emi: (s.emi != null && s.emi !== '') ? s.emi : e,
                repaymentFee: (s.repaymentFee != null && s.repaymentFee !== '') ? s.repaymentFee : e,
                installmentAmount: (s.installmentAmount != null && s.installmentAmount !== '') ? s.installmentAmount : e,
                principal: (s.principal != null && s.principal !== '') ? s.principal : e,
                interest: (s.interest != null && s.interest !== '') ? s.interest : e,
                closingPrincipal: (s.closingPrincipal != null && s.closingPrincipal !== '') ? s.closingPrincipal : e,
                paymentNo: e,
                paymentDate: e,
                bookingDate: e,
                paymentAmount: e,
                particulars: e,
                paymentChannel: e,
            });
        }

        for (let i = 0; i < paymentList.length; i++) {
            const p = paymentList[i] || {};
            if (!isPaymentHistoryMeaningfulRow(p)) {
                continue;
            }
            const paymentDateVal = (p.paymentDate != null && p.paymentDate !== '') ? p.paymentDate : e;
            rows.push({
                Id: 's4-p-' + (i + 1),
                rowType: SECTION4_TYPE_PAYMENT,
                installmentNo: e,
                dueDate: e,
                openingPrincipal: e,
                emi: e,
                repaymentFee: e,
                installmentAmount: e,
                principal: e,
                interest: e,
                closingPrincipal: e,
                paymentNo: (p.paymentNo != null && p.paymentNo !== '') ? String(p.paymentNo) : e,
                paymentDate: paymentDateVal,
                bookingDate: (p.bookingDate != null && p.bookingDate !== '') ? p.bookingDate : e,
                paymentAmount: (p.paymentAmount != null && p.paymentAmount !== '') ? p.paymentAmount : e,
                particulars: (p.particulars != null && p.particulars !== '') ? p.particulars : e,
                paymentChannel: (p.paymentChannel != null && p.paymentChannel !== '') ? p.paymentChannel : e,
            });
        }

        // Ưu tiên Payment Date, sau đó Installment Due Date (cũ → mới). Dòng schedule không có Payment Date → sort key phụ từ Due Date.
        // Khóa (paymentDate, dueDate) trùng: Payment History lên trên Repayment Schedule.
        rows.sort((a, b) => {
            const pA = toSortDateStr(a.paymentDate);
            const pB = toSortDateStr(b.paymentDate);
            const dA = toSortDateStr(a.dueDate);
            const dB = toSortDateStr(b.dueDate);
            if (pA !== pB) return pA < pB ? -1 : 1;
            if (dA !== dB) return dA < dB ? -1 : 1;
            if (a.rowType !== b.rowType) return a.rowType === SECTION4_TYPE_PAYMENT ? -1 : 1;
            return 0;
        });
        return rows;
    }

    get hasSection4CombinedData() {
        return this.section4CombinedRecords.length > 0;
    }

    /** Gợi ý sort: ưu tiên Payment Date, sau đó Installment Due Date (cũ → mới). */
    get section4SortedByDescription() {
        return `${FEC_Repay_Payment_Date_Label} & ${FEC_Repay_Installment_Due_Date_Label}`;
    }

    buildFieldsFromSection(sectionKey) {
        const data = this.sectionData[sectionKey];
        if (!data || !Array.isArray(data)) return [];
        return data.map((item) => ({
            label: item.label || item.name,
            value: item.value != null && item.value !== '' ? item.value : '-',
        }));
    }

    connectedCallback() {
        this.loadData();
    }

    loadData() {
        if (!this.recordId) return;
        this.isLoading = true;
        this.errorMessage = null;
        getSectionData({ caseId: this.recordId })
            .then((data) => {
                const realTime = Array.isArray(data.realTimePaymentTable) ? data.realTimePaymentTable : [];
                this.sectionData = {
                    repaymentScheduleTotals: data.repaymentScheduleTotals || {},
                    repaymentScheduleTable: data.repaymentScheduleTable || [],
                    paymentHistoryTotals: data.paymentHistoryTotals || {},
                    paymentHistoryTable: data.paymentHistoryTable || [],
                    realTimePaymentTable: realTime,
                    repaymentSchedulePaymentHistory: data.repaymentSchedulePaymentHistory || [],
                };
                this.section4Data = {
                    repaymentScheduleTable: data.repaymentScheduleTable || [],
                    paymentHistoryTable: data.paymentHistoryTable || [],
                };
                this.helpTextMap = data.helpTexts || {};
                this.errorMessage = data.errorMessage || null;
            })
            .catch((err) => {
                const msg = err?.body?.message || err?.message || 'Unknown error';
                this.errorMessage = msg;
                this.sectionData = {};
                this.section4Data = { repaymentScheduleTable: [], paymentHistoryTable: [] };
                this.helpTextMap = {};
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /* ================= SECTION REFRESH ================= */
    /** Click Refresh → chỉ refresh section 3 (Real-Time Payment) và section 4 (Repayment Schedule & Payment History). Section 1 & 2 giữ nguyên. */
    handleRealTimeRefresh() {
        if (!this.recordId) return;
        this.refreshStatusMap.realTimePayment = 'NONE';
        this.isRefreshingRealTime = true;
        getSectionData({ caseId: this.recordId })
            .then((data) => {
                const realTime = Array.isArray(data.realTimePaymentTable) ? data.realTimePaymentTable : [];
                this.sectionData = { ...this.sectionData, realTimePaymentTable: realTime };
                this.section4Data = {
                    repaymentScheduleTable: data.repaymentScheduleTable || [],
                    paymentHistoryTable: data.paymentHistoryTable || [],
                };
                this.refreshStatusMap.realTimePayment = 'SUCCESS';
                this.showToast('Success', `Refresh ${FEC_Real_Time_Payment_Label} & ${FEC_Repayment_Schedule_Payment_History_Label} successfully`, 'success');
            })
            .catch((err) => {
                this.refreshStatusMap.realTimePayment = 'ERROR';
                const msg = err?.body?.message || err?.message || 'Unknown error';
                this.showToast('Error', msg, 'error');
            })
            .finally(() => {
                this.isRefreshingRealTime = false;
            });
    }

    handleRefresh(event) {
        const section = event.detail?.section;
        if (section === FEC_Real_Time_Payment_Label) this.handleRealTimeRefresh();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}

