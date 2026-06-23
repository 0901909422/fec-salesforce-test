/****************************************************************************************
 * File Name    : fec_IncorrectPaymentForm.js
 * Description  : Incorrect Payment Form (child of dynamic LWC loader) - contract input, GetLoanSecInfo, adjustments (TH1/TH2 by subcode config).
 ****************************************************************************************/

import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPaymentHistoryFromSOAP from '@salesforce/apex/FEC_IncorrectPaymentController.getPaymentHistoryFromSOAP';
import getSubCodeConfig from '@salesforce/apex/FEC_IncorrectPaymentController.getSubCodeConfig';
import getIncorrectContractOptions from '@salesforce/apex/FEC_IncorrectPaymentController.getIncorrectContractOptions';
import getPaymentMethodOptions from '@salesforce/apex/FEC_IncorrectPaymentController.getPaymentMethodOptions';
import saveAdjustment from '@salesforce/apex/FEC_IncorrectPaymentController.saveAdjustment';
import saveAdjustmentDraft from '@salesforce/apex/FEC_IncorrectPaymentController.saveAdjustmentDraft';
import saveSelectedPaymentHistory from '@salesforce/apex/FEC_IncorrectPaymentController.saveSelectedPaymentHistory';
import FEC_Toast_Error from '@salesforce/label/c.FEC_Toast_Error';
import FEC_Success_Title from '@salesforce/label/c.FEC_Success_Title';
import FEC_Toast_Validation_Title from '@salesforce/label/c.FEC_Toast_Validation_Title';
import FEC_Toast_Save_Success from '@salesforce/label/c.FEC_Toast_Save_Success';
import FEC_Toast_Save_Error from '@salesforce/label/c.FEC_Toast_Save_Error';
import FEC_Toast_Save_Error_Message from '@salesforce/label/c.FEC_Toast_Save_Error_Message';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import Loading from '@salesforce/label/c.Loading';
import FEC_Repay_Payment_No_Label from '@salesforce/label/c.FEC_Repay_Payment_No_Label';
import FEC_Repay_Payment_Date_Label from '@salesforce/label/c.FEC_Repay_Payment_Date_Label';
import FEC_Repay_Payment_Amount_Label from '@salesforce/label/c.FEC_Repay_Payment_Amount_Label';
import FEC_Repay_Particulars_Label from '@salesforce/label/c.FEC_Repay_Particulars_Label';
import FEC_Repay_Booking_Date_Label from '@salesforce/label/c.FEC_Repay_Booking_Date_Label';
import FEC_LBL_Incorrect_Contract_Number from '@salesforce/label/c.FEC_LBL_Incorrect_Contract_Number';
import FEC_LBL_Select_Contract_Number from '@salesforce/label/c.FEC_LBL_Select_Contract_Number';
import FEC_LBL_Selected_Contract_Number from '@salesforce/label/c.FEC_LBL_Selected_Contract_Number';
import FEC_LBL_Select_Payment_Method from '@salesforce/label/c.FEC_LBL_Select_Payment_Method';
import FEC_LBL_Incorrect_Contract_Hint from '@salesforce/label/c.FEC_LBL_Incorrect_Contract_Hint';
import FEC_LBL_Payment_Method from '@salesforce/label/c.FEC_LBL_Payment_Method';
import FEC_LBL_No_Payment_History_Found from '@salesforce/label/c.FEC_LBL_No_Payment_History_Found';
import FEC_LBL_Bill_Date from '@salesforce/label/c.FEC_LBL_Bill_Date';
import FEC_LBL_Bill_Amount from '@salesforce/label/c.FEC_LBL_Bill_Amount';
import FEC_LBL_Excess_Amount from '@salesforce/label/c.FEC_LBL_Excess_Amount';
import FEC_LBL_Correct_Contract from '@salesforce/label/c.FEC_LBL_Correct_Contract';
import FEC_LBL_Adjusted_Amount from '@salesforce/label/c.FEC_LBL_Adjusted_Amount';
import FEC_LBL_Remove_Row from '@salesforce/label/c.FEC_LBL_Remove_Row';
import FEC_LBL_Add_Item from '@salesforce/label/c.FEC_LBL_Add_Item';
import FEC_MSG_Adjusted_Amount_Must_Equal_Payment from '@salesforce/label/c.FEC_MSG_Adjusted_Amount_Must_Equal_Payment';
import FEC_MSG_Adjusted_Amount_Must_Equal_Excess_Amount from '@salesforce/label/c.FEC_MSG_Adjusted_Amount_Must_Equal_Excess_Amount';
import FEC_MSG_IncorrectPayment_Date_Not_After_Today from '@salesforce/label/c.FEC_MSG_IncorrectPayment_Date_Not_After_Today';
import FEC_MSG_IncorrectPayment_No_Valid_Adjustment_Row from '@salesforce/label/c.FEC_MSG_IncorrectPayment_No_Valid_Adjustment_Row';
import FEC_LBL_Payment_Method_Bank_Transfer from '@salesforce/label/c.FEC_LBL_Payment_Method_Bank_Transfer';
import FEC_LBL_Payment_Method_Other_Channels from '@salesforce/label/c.FEC_LBL_Payment_Method_Other_Channels';
import FEC_Complete_This_Field from '@salesforce/label/c.FEC_Complete_This_Field';
import { STR_EMPTY } from 'c/fec_CommonConst';

const CONST = {
    DATE_PLACEHOLDER: 'DD/MM/YYYY',
    VARIANT_ERROR: 'error',
    VARIANT_SUCCESS: 'success',
    VARIANT_WARNING: 'warning',
    ROW_SELECT: 'rowSelect',
    ROW_DESELECT: 'rowDeselect',
    DESELECT_ALL_ROWS: 'deselectAllRows',
    LOCALE_EN_US: 'en-US',
    TH1_CODES: ['RL08.01', 'RL08.02', 'RL08.03', 'RL08.04', 'RL08.08'],
    TH2_CODES: ['RL08.05', 'RL08.06', 'RL08.07'],
    DRAFT_KEY_PREFIX: 'fec-incorrect-payment-draft-',
    PAYMENT_HISTORY_PAGE_SIZE: 20,
    PAYMENT_ID_PREFIX: 'pay_'
};

export default class Fec_IncorrectPaymentForm extends LightningElement {

    _recordId;
    _hasConnected = false;
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        const prev = this._recordId;
        this._recordId = value;
        if (value && value !== prev && this._hasConnected) {
            this.loadSubCodeConfig();
        }
    }

    @api subCodeCode;

    @api isEdit;

    get isReadOnly() {
        return this.isEdit === false;
    }

    get datatableMaxRowSelection() {
        return this.isReadOnly ? 0 : 1;
    }

    @track subCode = STR_EMPTY;
    @track incorrectContract = STR_EMPTY;
    @track paymentHistory = [];
    @track selectedPaymentId = null;
    @track selectedRowIds = [];
    @track manualBillDate = null;
    @track manualBillAmount = null;
    @track paymentDate = null;
    @track excessAmount = null;
    @track th1EditableBillAmount = null;
    @track paymentMethod = STR_EMPTY;
    @track adjustments = [{ id: 1, correctContract: STR_EMPTY, adjustedAmount: null }];
    @track nextAdjustmentId = 2;
    @track isLoading = false;
    @track paymentHistoryLoading = false;
    @track configLoaded = false;
    @track paymentHistoryTableKey = 0;
    @track paymentHistoryPage = 1;
    @track incorrectContractOptionlst = [];
    @track correctContractOptionlst = [];
    @track paymentMethodOptionlst = [];
    _lastLoadedContract = STR_EMPTY;
    _pendingSelectedPaymentId = null;
    _loanContractOptionsLoaded = false;
    _loanContractOptionsLoadPromise = null;

    customLabel = {
        loading: Loading,
        incorrectContractNumber: FEC_LBL_Incorrect_Contract_Number,
        selectedContractNumber: FEC_LBL_Selected_Contract_Number,
        selectContractPlaceholder: FEC_LBL_Select_Contract_Number,
        selectPaymentMethodPlaceholder: FEC_LBL_Select_Payment_Method,
        incorrectContractHint: FEC_LBL_Incorrect_Contract_Hint,
        paymentMethod: FEC_LBL_Payment_Method,
        noPaymentHistoryFound: FEC_LBL_No_Payment_History_Found,
        billDate: FEC_LBL_Bill_Date,
        billAmount: FEC_LBL_Bill_Amount,
        paymentDate: FEC_Repay_Payment_Date_Label,
        excessAmount: FEC_LBL_Excess_Amount,
        correctContract: FEC_LBL_Correct_Contract,
        adjustedAmount: FEC_LBL_Adjusted_Amount,
        removeRow: FEC_LBL_Remove_Row,
        addItem: FEC_LBL_Add_Item,
        adjustedAmountMustEqualPayment: FEC_MSG_Adjusted_Amount_Must_Equal_Payment,
        adjustedAmountMustEqualExcessAmount: FEC_MSG_Adjusted_Amount_Must_Equal_Excess_Amount,
        incorrectPaymentDateNotAfterToday: FEC_MSG_IncorrectPayment_Date_Not_After_Today,
        datePlaceholder: CONST.DATE_PLACEHOLDER
    };

    paymentHistoryColumns = [
        { label: FEC_Repay_Payment_No_Label, fieldName: 'paymentNo', type: 'text' },
        { label: FEC_Repay_Payment_Date_Label, fieldName: 'paymentDate', type: 'text' },
        { label: FEC_Repay_Booking_Date_Label, fieldName: 'bookingDate', type: 'text' },
        { label: FEC_Repay_Payment_Amount_Label, fieldName: 'paymentAmountDisplay', type: 'text' },
        { label: FEC_Repay_Particulars_Label, fieldName: 'particulars', type: 'text' }
    ];

    get paymentMethodOptions() {
        // Return dynamic options from Apex if available, otherwise use hardcoded labels
        if (this.paymentMethodOptionlst && this.paymentMethodOptionlst.length > 0) {
            return this.paymentMethodOptionlst;
        }
        // Fallback to custom labels (now updated to match picklist values)
        return [
            { label: FEC_LBL_Payment_Method_Bank_Transfer, value: FEC_LBL_Payment_Method_Bank_Transfer },
            { label: FEC_LBL_Payment_Method_Other_Channels, value: FEC_LBL_Payment_Method_Other_Channels }
        ];
    }

    get showManualBill() {
        return !this.selectedPaymentId;
    }

    get showSelectedBillReadOnly() {
        return !!this.selectedPaymentId && this.selectedPayment != null && !this.isTh2;
    }

    get displayBillDate() {
        return this.selectedPayment ? (this.selectedPayment.paymentDate || STR_EMPTY) : STR_EMPTY;
    }

    get displayBillAmount() {
        if (!this.selectedPayment || this.selectedPayment.paymentAmount == null) return STR_EMPTY;
        return this.formatAmount(this.selectedPayment.paymentAmount);
    }

    get incorrectContractFieldLabel() {
        return this.isTh2 ? this.customLabel.selectedContractNumber : this.customLabel.incorrectContractNumber;
    }

    get th1Codes() {
        return CONST.TH1_CODES;
    }

    get th2Codes() {
        return CONST.TH2_CODES;
    }

    get effectiveSubCode() {
        const fromParent = (this.subCodeCode || STR_EMPTY).trim();
        if (fromParent) return fromParent;
        return (this.subCode || STR_EMPTY).trim();
    }

    get isTh1() {
        const code = this.effectiveSubCode;
        return code && this.th1Codes.includes(code);
    }

    get isTh2() {
        const code = this.effectiveSubCode;
        return code && this.th2Codes.includes(code);
    }

    get adjustmentAmountFieldLabel() {
        return this.customLabel.adjustedAmount;
    }

    get manualBillDateFieldLabel() {
        return this.isTh2 ? this.customLabel.paymentDate : this.customLabel.billDate;
    }

    get manualBillAmountFieldLabel() {
        return this.isTh2 ? this.customLabel.excessAmount : this.customLabel.billAmount;
    }

    get adjustedAmountNoticeMessage() {
        return this.isTh2
            ? this.customLabel.adjustedAmountMustEqualExcessAmount
            : this.customLabel.adjustedAmountMustEqualPayment;
    }

    get displayPaymentDate() {
        if (this.paymentDate) return this.paymentDate;
        return this.selectedPayment ? (this.selectedPayment.paymentDate || STR_EMPTY) : STR_EMPTY;
    }

    get maxManualBillDate() {
        const t = new Date();
        const y = t.getFullYear();
        const m = String(t.getMonth() + 1).padStart(2, '0');
        const d = String(t.getDate()).padStart(2, '0');
        return `${y}-${m}-${d}`;
    }

    _isManualBillDateAfterToday() {
        const raw = this.manualBillDate;
        if (!raw || !String(raw).trim()) {
            return false;
        }
        const s = String(raw).trim();
        return s > this.maxManualBillDate;
    }

    get showTh2Row1() {
        return this.isTh2 && !!this.selectedPaymentId;
    }

    get selectedPayment() {
        if (!this.selectedPaymentId || !this.paymentHistory.length) return null;
        const id = String(this.selectedPaymentId);
        return this.paymentHistory.find(p => String(p.id) === id) || null;
    }

    get hasPaymentHistory() {
        return this.paymentHistory && this.paymentHistory.length > 0;
    }

    // 18/06/2026 16:00 linhdev - phân trang Payment History tối đa 20 dòng/trang
    get pagedPaymentHistory() {
        const all = this.paymentHistory || [];
        const pageSize = CONST.PAYMENT_HISTORY_PAGE_SIZE;
        const start = (this.paymentHistoryPage - 1) * pageSize;
        return all.slice(start, start + pageSize);
    }

    get showPaymentHistoryPagination() {
        return (this.paymentHistory || []).length > CONST.PAYMENT_HISTORY_PAGE_SIZE;
    }

    get paymentHistoryTotalPages() {
        const total = (this.paymentHistory || []).length;
        return Math.max(1, Math.ceil(total / CONST.PAYMENT_HISTORY_PAGE_SIZE));
    }

    get paymentHistoryPageLabel() {
        return this.paymentHistoryPage + ' / ' + this.paymentHistoryTotalPages;
    }

    get isPaymentHistoryFirstPage() {
        return this.paymentHistoryPage <= 1;
    }

    get isPaymentHistoryLastPage() {
        return this.paymentHistoryPage >= this.paymentHistoryTotalPages;
    }

    get adjustmentRows() {
        const rows = this.adjustments || [];
        const baseAmountLabel = this.adjustmentAmountFieldLabel;
        const baseCorrectLabel = this.customLabel.correctContract;
        return rows.map((row, index) => ({
            ...row,
            correctContractLabel: index === 0 ? baseCorrectLabel : `${baseCorrectLabel} ${index + 1}`,
            adjustedAmountLabel: index === 0 ? baseAmountLabel : `${baseAmountLabel} ${index + 1}`
        }));
    }

    get incorrectContractTrimmed() {
        return (this.incorrectContract || STR_EMPTY).trim().length > 0;
    }

    get datatableKeyItems() {
        return [{ id: this.paymentHistoryTableKey }];
    }

    get formattedIncorrectContractOption() {
        return JSON.stringify(this.incorrectContractOptionlst || []);
    }

    get formattedCorrectContractOption() {
        return JSON.stringify(this.correctContractOptionlst || []);
    }

    connectedCallback() {
        this._hasConnected = true;
        if (this.recordId) {
            this.loadSubCodeConfig();
        }
    }

    _resetLoanContractOptionsCache() {
        this._loanContractOptionsLoaded = false;
        this._loanContractOptionsLoadPromise = null;
    }

    get draftStorageKey() {
        if (!this.recordId) return null;
        return CONST.DRAFT_KEY_PREFIX + this.recordId;
    }

    readLocalDraft() {
        const key = this.draftStorageKey;
        if (!key) return null;
        try {
            const raw = window.localStorage.getItem(key);
            if (!raw) return null;
            return JSON.parse(raw);
        } catch (e) {
            return null;
        }
    }

    writeLocalDraft() {
        const key = this.draftStorageKey;
        if (!key) return;
        const payload = {
            paymentMethod: this.paymentMethod || STR_EMPTY,
            manualBillDate: this.manualBillDate || null,
            manualBillAmount: this.manualBillAmount != null ? this.manualBillAmount : null,
            selectedPaymentId: this.selectedPaymentId != null ? String(this.selectedPaymentId) : null,
            paymentDate: this.paymentDate || null,
            excessAmount: this.excessAmount != null ? this.excessAmount : null,
            th1EditableBillAmount: this.th1EditableBillAmount != null ? this.th1EditableBillAmount : null,
            adjustments: (this.adjustments || []).map((a) => ({
                id: a.id,
                correctContract: a.correctContract || STR_EMPTY,
                adjustedAmount: a.adjustedAmount != null ? a.adjustedAmount : null
            })),
            nextAdjustmentId: this.nextAdjustmentId
        };
        try {
            window.localStorage.setItem(key, JSON.stringify(payload));
        } catch (e) {
            // no-op
        }
    }

    clearLocalDraft() {
        const key = this.draftStorageKey;
        if (!key) return;
        try {
            window.localStorage.removeItem(key);
        } catch (e) {
            // no-op
        }
    }

    applyLocalDraftIfAny() {
        const draft = this.readLocalDraft();
        if (!draft) return;
        this.paymentMethod = draft.paymentMethod != null ? draft.paymentMethod : this.paymentMethod;
        this.manualBillDate = draft.manualBillDate != null ? draft.manualBillDate : this.manualBillDate;
        this.manualBillAmount = draft.manualBillAmount != null ? draft.manualBillAmount : this.manualBillAmount;
        this.paymentDate = draft.paymentDate != null ? draft.paymentDate : this.paymentDate;
        this.excessAmount = draft.excessAmount != null ? draft.excessAmount : this.excessAmount;
        this.th1EditableBillAmount = draft.th1EditableBillAmount != null ? draft.th1EditableBillAmount : this.th1EditableBillAmount;
        if (draft.adjustments && Array.isArray(draft.adjustments) && draft.adjustments.length > 0) {
            this.adjustments = draft.adjustments.map((a, index) => ({
                id: a.id != null ? Number(a.id) : index + 1,
                correctContract: a.correctContract || STR_EMPTY,
                adjustedAmount: a.adjustedAmount != null ? a.adjustedAmount : null
            }));
        }
        if (draft.nextAdjustmentId != null) {
            this.nextAdjustmentId = Number(draft.nextAdjustmentId) || this.nextAdjustmentId;
        }
        if (draft.selectedPaymentId != null && draft.selectedPaymentId !== STR_EMPTY) {
            this._pendingSelectedPaymentId = String(draft.selectedPaymentId);
        }
    }

    loadSubCodeConfig() {
        this._resetLoanContractOptionsCache();
        this._lastLoadedContract = STR_EMPTY;
        getSubCodeConfig({ caseId: this.recordId })
            .then((data) => {
                this.subCode = data.subCode || STR_EMPTY;
                this.incorrectContract = data.incorrectContractNumber != null ? data.incorrectContractNumber : STR_EMPTY;
                this.paymentMethod = data.paymentMethod != null && data.paymentMethod !== undefined ? data.paymentMethod : STR_EMPTY;
                const rowsFromCase = data.adjustmentRows && Array.isArray(data.adjustmentRows) && data.adjustmentRows.length > 0
                    ? data.adjustmentRows
                    : null;
                if (rowsFromCase) {
                    this.adjustments = rowsFromCase.map((r, index) => ({
                        id: index + 1,
                        correctContract: r.correctContract != null && String(r.correctContract).trim()
                            ? String(r.correctContract).trim()
                            : STR_EMPTY,
                        adjustedAmount: r.adjustedAmount != null && r.adjustedAmount !== undefined ? r.adjustedAmount : null
                    }));
                    this.nextAdjustmentId = this.adjustments.length + 1;
                } else {
                    const adjRow = { id: 1, correctContract: STR_EMPTY, adjustedAmount: null };
                    if (data.correctContractNumber != null && String(data.correctContractNumber).trim()) {
                        adjRow.correctContract = String(data.correctContractNumber).trim();
                    } else if (data.inputCorrectContractNumber != null && String(data.inputCorrectContractNumber).trim()) {
                        adjRow.correctContract = String(data.inputCorrectContractNumber).trim();
                    }
                    if (data.adjustedAmount != null && data.adjustedAmount !== undefined) {
                        adjRow.adjustedAmount = data.adjustedAmount;
                    }
                    this.adjustments = [adjRow];
                    this.nextAdjustmentId = 2;
                }
                if (data.billDate != null && String(data.billDate).trim()) {
                    this.manualBillDate = String(data.billDate).trim();
                } else {
                    this.manualBillDate = null;
                }
                if (data.billAmount != null && data.billAmount !== undefined) {
                    this.manualBillAmount = data.billAmount;
                    // 08/06/2026 14:30 linhdev - TH2: khôi phục Excess Amount đã lưu trên Case
                    const loadedSubCode = (data.subCode || STR_EMPTY).trim();
                    if (loadedSubCode && this.th2Codes.includes(loadedSubCode)) {
                        this.excessAmount = data.billAmount;
                    }
                } else {
                    this.manualBillAmount = null;
                }
                if (data.selectedPaymentHistoryId != null && String(data.selectedPaymentHistoryId).trim()) {
                    this._pendingSelectedPaymentId = String(data.selectedPaymentHistoryId).trim();
                }

                const incorrectContractPromise = this.loadLoanContractOptions();
                const correctContractPromise = Promise.resolve();

                // Load payment method options
                const paymentMethodPromise = getPaymentMethodOptions()
                    .then((methodOpts) => {
                        this.paymentMethodOptionlst = methodOpts || [];
                    })
                    .catch(() => {
                        this.paymentMethodOptionlst = [];
                    });

                return Promise.all([incorrectContractPromise, correctContractPromise, paymentMethodPromise]);
            })
            .then(() => {
                this.applyLocalDraftIfAny();
                this.configLoaded = true;
                // 18/06/2026 19:30 linhdev - reload Payment History khi Case đã lưu Incorrect Contract
                this._tryLoadPaymentHistoryForSelectedContract();
            })
            .catch((err) => {
                this.configLoaded = true;
                this.subCode = STR_EMPTY;
                this.incorrectContractOptionlst = [];
                this.correctContractOptionlst = [];
                this.paymentMethodOptionlst = [];
            });
    }

    // 18/06/2026 19:30 linhdev - Case đã lưu Incorrect Contract: reload Payment History khi mở form
    _tryLoadPaymentHistoryForSelectedContract() {
        const contract = (this.incorrectContract || STR_EMPTY).trim();
        if (contract) {
            this.loadPaymentHistory();
        }
    }

    // 19/06/2026 linhdev - chọn dropdown hoặc nhập tay + blur → gọi API 24 GetLoanSecInfo
    _commitIncorrectContract(contract) {
        const trimmed = (contract || STR_EMPTY).trim();
        this.incorrectContract = trimmed;
        if (!trimmed) {
            this._clearPaymentHistoryState();
            return;
        }
        this.loadPaymentHistory();
    }

    _clearPaymentHistoryState() {
        this.paymentHistory = [];
        this.paymentHistoryTableKey += 1;
        this.paymentHistoryPage = 1;
        this.selectedPaymentId = null;
        this.selectedRowIds = [];
        this._lastLoadedContract = STR_EMPTY;
    }

    // 18/06/2026 20:00 linhdev - API 20: gọi 1 lần/case (cache + dedupe); search/filter client-side trên ComboBox
    loadLoanContractOptions(forceRefresh) {
        if (!this.recordId) {
            this.incorrectContractOptionlst = [];
            this.correctContractOptionlst = [];
            this._loanContractOptionsLoaded = false;
            return Promise.resolve();
        }
        if (!forceRefresh && this._loanContractOptionsLoaded) {
            return Promise.resolve();
        }
        if (this._loanContractOptionsLoadPromise) {
            return this._loanContractOptionsLoadPromise;
        }
        this._loanContractOptionsLoadPromise = getIncorrectContractOptions({ caseId: this.recordId })
            .then((contractOpts) => {
                const opts = contractOpts || [];
                this.incorrectContractOptionlst = opts;
                this.correctContractOptionlst = opts;
                this._loanContractOptionsLoaded = true;
            })
            .catch(() => {
                this.incorrectContractOptionlst = [];
                this.correctContractOptionlst = [];
                this._loanContractOptionsLoaded = false;
            })
            .finally(() => {
                this._loanContractOptionsLoadPromise = null;
            });
        return this._loanContractOptionsLoadPromise;
    }

    handlePaymentHistoryPrev() {
        if (this.paymentHistoryPage > 1) {
            this.paymentHistoryPage -= 1;
            this.paymentHistoryTableKey += 1;
        }
    }

    handlePaymentHistoryNext() {
        if (this.paymentHistoryPage < this.paymentHistoryTotalPages) {
            this.paymentHistoryPage += 1;
            this.paymentHistoryTableKey += 1;
        }
    }

    _isPaymentHistoryRecordId(id) {
        if (id == null || id === STR_EMPTY) {
            return false;
        }
        const s = String(id).trim();
        if (!s || s.toLowerCase().startsWith(CONST.PAYMENT_ID_PREFIX)) {
            return false;
        }
        return (s.length === 15 || s.length === 18) && /^[a-zA-Z0-9]+$/.test(s);
    }

    _persistSelectedPaymentHistory(paymentHistoryId) {
        if (!this.recordId || this.isReadOnly) {
            return Promise.resolve();
        }
        const phId = paymentHistoryId && this._isPaymentHistoryRecordId(paymentHistoryId)
            ? paymentHistoryId
            : null;
        return saveSelectedPaymentHistory({
            caseId: this.recordId,
            paymentHistoryId: phId
        }).catch(() => Promise.resolve());
    }

    _ensureSelectedPaymentPageVisible() {
        if (!this.selectedPaymentId || !(this.paymentHistory || []).length) {
            return;
        }
        const idx = this.paymentHistory.findIndex((p) => String(p.id) === String(this.selectedPaymentId));
        if (idx >= 0) {
            this.paymentHistoryPage = Math.floor(idx / CONST.PAYMENT_HISTORY_PAGE_SIZE) + 1;
        }
    }

    handleRemoveIncorrectContract() {
        const element = this.template.querySelector(
            'c-fec_-combo-box[data-id="incorrect-contract"]'
        );
        if (element) {
            element.searchKey = undefined;
        }
        this.incorrectContract = STR_EMPTY;
        this._clearPaymentHistoryState();
        this._persistSelectedPaymentHistory(null);
        this.writeLocalDraft();
    }

    handleChangeIncorrectContract(e) {
        if (!e.detail || e.detail.fromPick !== true) {
            return;
        }
        this._commitIncorrectContract(e.detail.value);
    }

    handleIncorrectContractBlurCommit(e) {
        const detail = e.detail || {};
        const v = detail.value != null ? String(detail.value).trim() : STR_EMPTY;
        this._commitIncorrectContract(v);
        this.writeLocalDraft();
    }

    loadPaymentHistory() {
        const contract = (this.incorrectContract || STR_EMPTY).trim();
        if (!contract) {
            this._clearPaymentHistoryState();
            return Promise.resolve();
        }
        if (contract === this._lastLoadedContract) {
            return Promise.resolve();
        }
        this._lastLoadedContract = contract;
        this.paymentHistoryLoading = true;
        this.selectedPaymentId = null;
        this.selectedRowIds = [];
        this.paymentHistoryPage = 1;
        return getPaymentHistoryFromSOAP({ caseId: this.recordId, contractNumber: contract })
            .then((data) => {
                this.paymentHistory = (data || []).map((p, idx) => ({
                    ...p,
                    paymentAmountDisplay: this.formatAmount(p.paymentAmount)
                }));
                if (this._pendingSelectedPaymentId != null) {
                    const pendingId = String(this._pendingSelectedPaymentId);
                    const matched = this.paymentHistory.find((p) => String(p.id) === pendingId);
                    if (matched) {
                        this.selectedPaymentId = pendingId;
                        this.selectedRowIds = [pendingId];
                        this._applySelectedPaymentBillAmounts(matched);
                        this._ensureSelectedPaymentPageVisible();
                    }
                    this._pendingSelectedPaymentId = null;
                }
                this.paymentHistoryTableKey += 1;
                this.paymentHistoryLoading = false;
            })
            .catch((err) => {
                this._clearPaymentHistoryState();
                const combo = this.template.querySelector(
                    'c-fec_-combo-box[data-id="incorrect-contract"]'
                );
                if (combo && typeof combo.resetBlurCommitState === 'function') {
                    combo.resetBlurCommitState();
                }
                this.paymentHistoryLoading = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: FEC_Toast_Error,
                    message: err.body?.message || err.message || FEC_MSG_Error_API_Label,
                    variant: CONST.VARIANT_ERROR
                }));
            });
    }

    formatAmount(val) {
        if (val == null) return STR_EMPTY;
        const n = Number(val);
        if (isNaN(n)) return String(val);
        return n.toLocaleString(CONST.LOCALE_EN_US);
    }

    _parseMoney(val) {
        if (val == null || val === STR_EMPTY) {
            return null;
        }
        const n = Number(val);
        return isNaN(n) ? null : n;
    }

    _roundMoney(val) {
        const n = this._parseMoney(val);
        if (n == null) {
            return 0;
        }
        return Math.round(n * 100) / 100;
    }

    _amountsEqual(left, right) {
        return Math.abs(this._roundMoney(left) - this._roundMoney(right)) <= 0.01;
    }

    /** Submit có thể xảy ra trước khi lightning-input blur — đọc giá trị DOM mới nhất. */
    _syncBillAndAdjustmentInputsFromDom() {
        const manualBillEl = this.template.querySelector('lightning-input[data-id="manual-bill-amount"]');
        if (manualBillEl && manualBillEl.value !== undefined && manualBillEl.value !== STR_EMPTY && manualBillEl.value !== null) {
            this.manualBillAmount = this._parseMoney(manualBillEl.value);
        }

        const excessEl = this.template.querySelector('lightning-input[data-id="excess-amount"]');
        if (excessEl && excessEl.value !== undefined && excessEl.value !== STR_EMPTY && excessEl.value !== null) {
            this.excessAmount = this._parseMoney(excessEl.value);
        }

        const rows = this.adjustments || [];
        let changed = false;
        const next = rows.map((row) => {
            const input = this.template.querySelector('lightning-input[data-id-value="' + row.id + '"]');
            if (!input) {
                return row;
            }
            const raw = input.value;
            if (raw === undefined || raw === null || raw === STR_EMPTY) {
                if (row.adjustedAmount != null) {
                    changed = true;
                    return { ...row, adjustedAmount: null };
                }
                return row;
            }
            const parsed = this._parseMoney(raw);
            if (parsed !== row.adjustedAmount) {
                changed = true;
                return { ...row, adjustedAmount: parsed };
            }
            return row;
        });
        if (changed) {
            this.adjustments = next;
        }
    }

    _applySelectedPaymentBillAmounts(row) {
        if (!row || !this.effectiveSubCode) {
            return;
        }
        if (this.th1Codes.includes(this.effectiveSubCode)) {
            this.th1EditableBillAmount = row.paymentAmount ?? null;
            this.excessAmount = null;
            return;
        }
        if (this.th2Codes.includes(this.effectiveSubCode)) {
            this.paymentDate = row.paymentDate || null;
            if (this.excessAmount == null) {
                this.excessAmount = row.paymentAmount ?? null;
            }
        }
    }

    handlePaymentRowSelect(event) {
        const config = event.detail.config || {};
        const action = config.action;
        const toggledId = config.value;
        const selectedRows = event.detail.selectedRows || [];
        let newId = null;
        if (action === CONST.ROW_SELECT && toggledId != null && toggledId !== STR_EMPTY) {
            newId = String(toggledId);
        } else if (action === CONST.ROW_DESELECT || action === CONST.DESELECT_ALL_ROWS) {
            newId = null;
        } else if (selectedRows.length > 0) {
            newId = selectedRows[0].id != null ? String(selectedRows[0].id) : null;
        }
        this.selectedPaymentId = newId;
        this.selectedRowIds = newId != null ? [newId] : [];
        if (this.selectedPaymentId) {
            const id = String(this.selectedPaymentId);
            const row = this.paymentHistory.find(p => String(p.id) === id);
            if (row) {
                this._applySelectedPaymentBillAmounts(row);
            }
        }
        if (newId == null) {
            this.resetBillStateOnDeselect();
            this._persistSelectedPaymentHistory(null);
        } else if (this._isPaymentHistoryRecordId(newId)) {
            this._persistSelectedPaymentHistory(newId);
        }
    }

    resetBillStateOnDeselect() {
        this.paymentDate = null;
        this.excessAmount = null;
        this.th1EditableBillAmount = null;
        this.manualBillDate = null;
        this.manualBillAmount = null;
    }

    handleManualBillDateChange(event) {
        const v = event.detail != null && event.detail.value !== undefined ? event.detail.value : event.target.value;
        this.manualBillDate = v || null;
    }

    handleManualBillAmountChange(event) {
        const v = event.detail != null && event.detail.value !== undefined ? event.detail.value : event.target.value;
        if (v === STR_EMPTY || v == null || v === '') {
            this.manualBillAmount = null;
            return;
        }
        const n = Number(v);
        this.manualBillAmount = isNaN(n) ? null : n;
    }

    // 08/06/2026 14:30 linhdev - Excess Amount nhập tùy ý khi chọn payment history (TH2)
    handleExcessAmountChange(event) {
        const v = event.detail != null && event.detail.value !== undefined ? event.detail.value : event.target.value;
        if (v === STR_EMPTY || v == null || v === '') {
            this.excessAmount = null;
            return;
        }
        const n = Number(v);
        this.excessAmount = isNaN(n) ? null : n;
    }

    // 08/06/2026 14:30 linhdev - TH2 dùng excessAmount (không lấy cứng paymentAmount) để validate/lưu
    _getBillAmountForSave() {
        if (this.isTh1 && this.th1EditableBillAmount != null) {
            return this.th1EditableBillAmount;
        }
        if (this.isTh2) {
            if (this.selectedPaymentId) {
                return this.excessAmount ?? null;
            }
            return this.manualBillAmount ?? null;
        }
        if (this.selectedPayment) {
            return this.selectedPayment.paymentAmount ?? null;
        }
        return this.manualBillAmount ?? null;
    }

    handlePaymentMethodChange(event) {
        this.paymentMethod = event.detail.value || STR_EMPTY;
    }

    handleAddAdjustment() {
        if (!this._loanContractOptionsLoaded) {
            this.loadLoanContractOptions();
        }
        this.adjustments = [...this.adjustments, { id: this.nextAdjustmentId, correctContract: STR_EMPTY, adjustedAmount: null }];
        this.nextAdjustmentId += 1;
    }

    handleRemoveAdjustment(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        const numId = Number(id);
        this.adjustments = this.adjustments.filter(a => a.id !== numId);
        if (this.adjustments.length === 0) {
            this.adjustments = [{ id: this.nextAdjustmentId++, correctContract: STR_EMPTY, adjustedAmount: null }];
        }
    }

    handleAdjustmentCorrectContractRemove(event) {
        const id = Number(event.currentTarget.dataset.idValue);
        const element = this.template.querySelector(
            'c-fec_-combo-box[data-id-value="' + id + '"]'
        );
        if (element) {
            element.searchKey = undefined;
        }
        const idx = this.adjustments.findIndex(a => a.id === id);
        if (idx < 0) {
            return;
        }
        const next = [...this.adjustments];
        next[idx] = { ...next[idx], correctContract: STR_EMPTY };
        this.adjustments = next;
    }

    handleAdjustmentCorrectContractChange(event) {
        if (!event.detail || event.detail.fromPick !== true) {
            return;
        }
        const id = Number(event.currentTarget.dataset.idValue);
        const idx = this.adjustments.findIndex(a => a.id === id);
        if (idx < 0) {
            return;
        }

        const next = [...this.adjustments];
        const v = event.detail != null && event.detail.value !== undefined ? event.detail.value : event.target.value;
        next[idx] = { ...next[idx], correctContract: v || STR_EMPTY };
        this.adjustments = next;
        const cmp = event.currentTarget;
        if (cmp && cmp.setCustomValidity) {
            cmp.setCustomValidity(STR_EMPTY);
            cmp.reportValidity();
        }
    }

    handleAdjustmentCorrectContractBlurCommit(event) {
        const id = Number(event.currentTarget.dataset.idValue);
        const idx = this.adjustments.findIndex(a => a.id === id);
        if (idx < 0) {
            return;
        }
        const detail = event.detail || {};
        const v = detail.value != null ? String(detail.value).trim() : STR_EMPTY;
        const next = [...this.adjustments];
        next[idx] = { ...next[idx], correctContract: v || STR_EMPTY };
        this.adjustments = next;
        const cmp = event.currentTarget;
        if (cmp && cmp.setCustomValidity) {
            cmp.setCustomValidity(STR_EMPTY);
            cmp.reportValidity();
        }
    }

    handleAdjustmentAmountChange(event) {
        const id = Number(event.currentTarget.dataset.idValue);
        const idx = this.adjustments.findIndex(a => a.id === id);
        if (idx < 0) return;
        const v = event.detail != null && event.detail.value !== undefined ? event.detail.value : event.target.value;
        let amount = null;
        if (v !== STR_EMPTY && v != null && v !== '') {
            amount = this._parseMoney(v);
        }
        const next = [...this.adjustments];
        next[idx] = { ...next[idx], adjustedAmount: amount };
        this.adjustments = next;
        const cmp = event.currentTarget;
        if (cmp && cmp.setCustomValidity) {
            cmp.setCustomValidity(STR_EMPTY);
            cmp.reportValidity();
        }
    }

    handleAdjustmentAmountBlur(event) {
        this.handleAdjustmentAmountChange(event);
    }

    validateFields(selectors) {
        let isValid = true;
        selectors.forEach((selector) => {
            const cmp = this.template.querySelector(selector);
            if (!cmp) return;
            cmp.reportValidity();
            if (!cmp.checkValidity()) {
                isValid = false;
            }
        });
        return isValid;
    }

    clearAdjustmentFieldsCustomValidity() {
        const rows = this.adjustments || [];
        rows.forEach((a) => {
            const combobox = this.template.querySelector('c-fec_-combo-box[data-id-value="' + a.id + '"]');
            const input = this.template.querySelector('lightning-input[data-id-value="' + a.id + '"]');
            if (combobox && combobox.setCustomValidity) {
                combobox.setCustomValidity(STR_EMPTY);
            }
            if (input && input.setCustomValidity) {
                input.setCustomValidity(STR_EMPTY);
            }
        });
    }

    reportIncompleteAdjustmentFields(incompleteRows) {
        const msg = FEC_Complete_This_Field;
        incompleteRows.forEach((r) => {
            const adj = this.adjustments[r.index - 1];
            if (!adj) {
                return;
            }
            const id = adj.id;
            const combobox = this.template.querySelector('c-fec_-combo-box[data-id-value="' + id + '"]');
            const input = this.template.querySelector('lightning-input[data-id-value="' + id + '"]');
            if (r.hasContract && !r.hasAmount) {
                if (combobox && combobox.setCustomValidity) {
                    combobox.setCustomValidity(STR_EMPTY);
                }
                if (input && input.setCustomValidity) {
                    input.setCustomValidity(msg);
                    input.reportValidity();
                }
            } else if (!r.hasContract && r.hasAmount) {
                if (input && input.setCustomValidity) {
                    input.setCustomValidity(STR_EMPTY);
                }
                if (combobox && combobox.setCustomValidity) {
                    combobox.setCustomValidity(msg);
                    combobox.reportValidity();
                }
            }
        });
    }

    reportFirstAdjustmentRowRequired() {
        const first = (this.adjustments && this.adjustments[0]) || null;
        if (!first) {
            return;
        }
        const id = first.id;
        const combobox = this.template.querySelector('c-fec_-combo-box[data-id-value="' + id + '"]');
        const input = this.template.querySelector('lightning-input[data-id-value="' + id + '"]');
        if (combobox && combobox.reportValidity) {
            combobox.reportValidity();
        }
        if (input && input.reportValidity) {
            input.reportValidity();
        }
    }

    _shouldRunIncorrectPaymentSave() {
        const hasPaymentMethod = !!(this.paymentMethod && String(this.paymentMethod).trim());
        const hasCompleteRow = (this.adjustments || []).some((a) => {
            const hasCorrectContract = a.correctContract && String(a.correctContract).trim();
            const hasAdjustedAmount = a.adjustedAmount != null;
            return hasCorrectContract && hasAdjustedAmount;
        });
        return hasPaymentMethod || hasCompleteRow;
    }

    _shouldRunIncorrectPaymentDraftSave() {
        const hasIncorrectContract = !!(this.incorrectContract && String(this.incorrectContract).trim());
        const hasPaymentMethod = !!(this.paymentMethod && String(this.paymentMethod).trim());
        const hasManualBillDate = !!(this.manualBillDate && String(this.manualBillDate).trim());
        const hasManualBillAmount = this.manualBillAmount != null;
        const hasSelectedPayment = !!this.selectedPayment;
        const hasAnyAdjustmentInput = (this.adjustments || []).some((a) => {
            const hasCorrectContract = !!(a.correctContract && String(a.correctContract).trim());
            const hasAdjustedAmount = a.adjustedAmount != null;
            return hasCorrectContract || hasAdjustedAmount;
        });
        return (
            hasIncorrectContract ||
            hasPaymentMethod ||
            hasManualBillDate ||
            hasManualBillAmount ||
            hasSelectedPayment ||
            hasAnyAdjustmentInput
        );
    }

    _getDraftFirstAdjustment() {
        const firstWithAnyInput = (this.adjustments || []).find((a) => {
            const hasCorrectContract = !!(a.correctContract && String(a.correctContract).trim());
            const hasAdjustedAmount = a.adjustedAmount != null;
            return hasCorrectContract || hasAdjustedAmount;
        });
        if (!firstWithAnyInput) {
            return { correctContract: null, adjustedAmount: null };
        }
        return {
            correctContract: firstWithAnyInput.correctContract || null,
            adjustedAmount: firstWithAnyInput.adjustedAmount != null ? firstWithAnyInput.adjustedAmount : null
        };
    }

    /**
     * Trả về false khi fail; object khi pass (skipApex: không gọi Apex, vẫn coi là hợp lệ).
     */
    _performClientSaveValidation() {
        this._syncBillAndAdjustmentInputsFromDom();

        if (!this.validateFields(['lightning-combobox[name="paymentMethod"]'])) {
            this.dispatchEvent(new ShowToastEvent({
                title: FEC_Toast_Validation_Title,
                message: FEC_LBL_Select_Payment_Method,
                variant: CONST.VARIANT_WARNING
            }));
            return false;
        }
        if (!(this.paymentMethod && String(this.paymentMethod).trim())) {
            const pmEl = this.template.querySelector('lightning-combobox[name="paymentMethod"]');
            if (pmEl && pmEl.reportValidity) {
                pmEl.reportValidity();
            }
            this.dispatchEvent(new ShowToastEvent({
                title: FEC_Toast_Validation_Title,
                message: FEC_LBL_Select_Payment_Method,
                variant: CONST.VARIANT_WARNING
            }));
            return false;
        }

        if (this.showManualBill) {
            if (this._isManualBillDateAfterToday()) {
                this.dispatchEvent(new ShowToastEvent({
                    title: FEC_Toast_Validation_Title,
                    message: this.customLabel.incorrectPaymentDateNotAfterToday,
                    variant: CONST.VARIANT_WARNING
                }));
                return false;
            }
            const billAmtSel = 'lightning-input[data-id="manual-bill-amount"]';
            const billAmtOk = this.validateFields([billAmtSel]);
            const billAmtMissing = this.manualBillAmount == null;
            if (!billAmtOk || billAmtMissing) {
                const billAmtEl = this.template.querySelector(billAmtSel);
                if (billAmtEl && billAmtEl.reportValidity) {
                    billAmtEl.reportValidity();
                }
                this.dispatchEvent(new ShowToastEvent({
                    title: FEC_Toast_Validation_Title,
                    message: this.manualBillAmountFieldLabel + ': ' + FEC_Complete_This_Field,
                    variant: CONST.VARIANT_WARNING
                }));
                return false;
            }
        }

        // 08/06/2026 14:30 linhdev - bắt buộc nhập Excess Amount trước khi so tổng Adjusted Amount
        if (this.showTh2Row1) {
            const excessAmtSel = 'lightning-input[data-id="excess-amount"]';
            const excessAmtOk = this.validateFields([excessAmtSel]);
            const excessAmtMissing = this.excessAmount == null;
            if (!excessAmtOk || excessAmtMissing) {
                const excessAmtEl = this.template.querySelector(excessAmtSel);
                if (excessAmtEl && excessAmtEl.reportValidity) {
                    excessAmtEl.reportValidity();
                }
                this.dispatchEvent(new ShowToastEvent({
                    title: FEC_Toast_Validation_Title,
                    message: this.customLabel.excessAmount + ': ' + FEC_Complete_This_Field,
                    variant: CONST.VARIANT_WARNING
                }));
                return false;
            }
        }

        this.clearAdjustmentFieldsCustomValidity();
        const incompleteRows = [];
        this.adjustments.forEach((a, index) => {
            const hasCorrectContract = a.correctContract && String(a.correctContract).trim();
            const hasAdjustedAmount = a.adjustedAmount != null;

            if ((hasCorrectContract && !hasAdjustedAmount) || (!hasCorrectContract && hasAdjustedAmount)) {
                incompleteRows.push({
                    index: index + 1,
                    hasContract: hasCorrectContract,
                    hasAmount: hasAdjustedAmount
                });
            }
        });

        if (incompleteRows.length > 0) {
            this.reportIncompleteAdjustmentFields(incompleteRows);
            this.dispatchEvent(new ShowToastEvent({
                title: FEC_Toast_Validation_Title,
                message: FEC_Complete_This_Field,
                variant: CONST.VARIANT_WARNING
            }));
            return false;
        }

        const valid = this.adjustments.filter((a) => {
            const hasCorrectContract = a.correctContract && String(a.correctContract).trim();
            const hasAdjustedAmount = a.adjustedAmount != null;
            return hasCorrectContract && hasAdjustedAmount;
        });

        if (valid.length === 0) {
            this.reportFirstAdjustmentRowRequired();
            this.dispatchEvent(new ShowToastEvent({
                title: FEC_Toast_Validation_Title,
                message: FEC_MSG_IncorrectPayment_No_Valid_Adjustment_Row,
                variant: CONST.VARIANT_WARNING
            }));
            return false;
        }

        const billDate = this.selectedPayment ? (this.selectedPayment.paymentDate || null) : (this.manualBillDate || null);
        const billAmount = this._getBillAmountForSave();

        const billFieldsRendered = this.showManualBill || this.selectedPaymentId;
        if (!billFieldsRendered && (billAmount == null || billAmount === 0)) {
            return { skipApex: true, valid, billDate, billAmount };
        }
        const sumAdjusted = valid.reduce(
            (sum, a) => sum + this._roundMoney(a.adjustedAmount),
            0,
        );

        if (!this._amountsEqual(sumAdjusted, billAmount)) {
            const sumMsg = this.isTh2
                ? this.customLabel.adjustedAmountMustEqualExcessAmount
                : this.customLabel.adjustedAmountMustEqualPayment;
            this.dispatchEvent(new ShowToastEvent({
                title: FEC_Toast_Validation_Title,
                message: sumMsg,
                variant: CONST.VARIANT_WARNING
            }));
            return false;
        }

        return { skipApex: false, valid, billDate, billAmount };
    }

    /**
     * Gọi từ parent (fec_CaseBussiness validate / saveOnly): khi section có dữ liệu thì chạy cùng rule với saveAdjustments.
     */
    @api validateForSubmit() {
        if (this.isReadOnly) {
            return true;
        }
        // Submit always validates; _shouldRunIncorrectPaymentSave is only for skipping Apex on empty section.
        const ctx = this._performClientSaveValidation();
        return ctx !== false;
    }

    /**
     * Gọi từ parent (Save & Close / Submit): chỉ gọi Apex khi user đã nhập dữ liệu điều chỉnh;
     * bỏ qua khi section trống để không chặn lưu Case chung.
     */
    @api saveAdjustmentsIfApplicable() {
        if (this.isReadOnly) {
            console.log('[fec_IncorrectPaymentForm] saveAdjustmentsIfApplicable: bỏ qua (isReadOnly).');
            return Promise.resolve();
        }
        if (!this._shouldRunIncorrectPaymentSave()) {
            console.log('[fec_IncorrectPaymentForm] saveAdjustmentsIfApplicable: bỏ qua — chưa có payment method và chưa có dòng điều chỉnh đủ (contract + số tiền khác 0). Không validate/toast để không chặn lưu Case khi section để trống.');
            return Promise.resolve();
        }
        return this.saveAdjustments();
    }

    @api saveDraftIfApplicable() {
        if (this.isReadOnly) {
            return Promise.resolve();
        }
        if (!this._shouldRunIncorrectPaymentDraftSave()) {
            return Promise.resolve();
        }
        this.writeLocalDraft();

        const draftFirst = this._getDraftFirstAdjustment();
        const billDate = this.selectedPayment ? (this.selectedPayment.paymentDate || null) : (this.manualBillDate || null);
        const billAmount = this._getBillAmountForSave();

        return saveAdjustmentDraft({
            caseId: this.recordId,
            incorrectContract: this.incorrectContract || STR_EMPTY,
            paymentMethod: this.paymentMethod || STR_EMPTY,
            billDate: billDate || STR_EMPTY,
            billAmount: billAmount,
            correctContract: draftFirst.correctContract,
            adjustedAmount: draftFirst.adjustedAmount
        });
    }

    @api saveAdjustments() {
        if (this.isReadOnly) {
            return Promise.reject(new Error('readonly'));
        }
        const ctx = this._performClientSaveValidation();
        if (ctx === false) {
            return Promise.reject(new Error('validation'));
        }
        if (ctx.skipApex) {
            return Promise.resolve();
        }

        const valid = ctx.valid;
        const billDate = ctx.billDate;
        const billAmount = ctx.billAmount;
        this.isLoading = true;
        const payload = valid.map(a => ({
            correctContract: (a.correctContract || STR_EMPTY).trim(),
            adjustedAmount: a.adjustedAmount
        }));

        return saveAdjustment({
            caseId: this.recordId,
            incorrectContract: this.incorrectContract || STR_EMPTY,
            paymentMethod: this.paymentMethod || STR_EMPTY,
            billDate: billDate || STR_EMPTY,
            billAmount: billAmount,
            adjustments: payload
        })
            .then(() => {
                this.isLoading = false;
                this.clearLocalDraft();
                this.dispatchEvent(new ShowToastEvent({
                    title: FEC_Success_Title,
                    message: FEC_Toast_Save_Success,
                    variant: CONST.VARIANT_SUCCESS
                }));
            })
            .catch((err) => {
                this.isLoading = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: FEC_Toast_Error,
                    message: err.body?.message || err.message || FEC_Toast_Save_Error_Message,
                    variant: CONST.VARIANT_ERROR
                }));
                return Promise.reject(err);
            });
    }
}