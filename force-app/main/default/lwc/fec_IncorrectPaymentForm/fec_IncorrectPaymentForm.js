/****************************************************************************************
 * File Name    : fec_IncorrectPaymentForm.js
 * Description  : Incorrect Payment Form (child of dynamic LWC loader) - contract input, GetLoanSecInfo, adjustments (TH1/TH2 by subcode config).
 ****************************************************************************************/

import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPaymentHistoryFromSOAP from '@salesforce/apex/FEC_IncorrectPaymentController.getPaymentHistoryFromSOAP';
import getSubCodeConfig from '@salesforce/apex/FEC_IncorrectPaymentController.getSubCodeConfig';
import getIncorrectContractOptions from '@salesforce/apex/FEC_IncorrectPaymentController.getIncorrectContractOptions';
import getCorrectContractOptions from '@salesforce/apex/FEC_IncorrectPaymentController.getCorrectContractOptions';
import getPaymentMethodOptions from '@salesforce/apex/FEC_IncorrectPaymentController.getPaymentMethodOptions';
import saveAdjustment from '@salesforce/apex/FEC_IncorrectPaymentController.saveAdjustment';
import saveAdjustmentDraft from '@salesforce/apex/FEC_IncorrectPaymentController.saveAdjustmentDraft';
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
import FEC_MSG_IncorrectPayment_No_Valid_Adjustment_Row from '@salesforce/label/c.FEC_MSG_IncorrectPayment_No_Valid_Adjustment_Row';
import FEC_MSG_IncorrectPayment_Date_Not_After_Today from '@salesforce/label/c.FEC_MSG_IncorrectPayment_Date_Not_After_Today';
import FEC_LBL_Payment_Method_Bank_Transfer from '@salesforce/label/c.FEC_LBL_Payment_Method_Bank_Transfer';
import FEC_LBL_Payment_Method_Other_Channels from '@salesforce/label/c.FEC_LBL_Payment_Method_Other_Channels';
import FEC_Complete_This_Field from '@salesforce/label/c.FEC_Complete_This_Field';
import { STR_EMPTY } from 'c/fec_CommonConst';
import { toUpperNoVietnameseAccent } from 'c/fec_CommonUtils';

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
    DRAFT_KEY_PREFIX: 'fec-incorrect-payment-draft-'
};

export default class Fec_IncorrectPaymentForm extends LightningElement {

    @api recordId;

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
    @track incorrectContractOptionlst = [];
    @track correctContractOptionlst = [];
    @track paymentMethodOptionlst = [];
    _lastLoadedContract = STR_EMPTY;
    _pendingSelectedPaymentId = null;
    _incorrectContractHistoryLoadTimer;

    customLabel = {
        loading: Loading,
        incorrectContractNumber: FEC_LBL_Incorrect_Contract_Number,
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

    get manualBillDateLabel() {
        return this.isTh2 ? this.customLabel.paymentDate : this.customLabel.billDate;
    }

    get manualBillAmountLabel() {
        return this.isTh2 ? this.customLabel.excessAmount : this.customLabel.billAmount;
    }

    get adjustmentAmountFieldLabel() {
        return this.isTh2 ? this.customLabel.excessAmount : this.customLabel.adjustedAmount;
    }

    get displayExcessAmount() {
        if (this.excessAmount == null) return STR_EMPTY;
        return this.formatAmount(this.excessAmount);
    }

    get displayPaymentDate() {
        if (this.paymentDate) return this.paymentDate;
        return this.selectedPayment ? (this.selectedPayment.paymentDate || STR_EMPTY) : STR_EMPTY;
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

    get adjustmentRows() {
        const rows = this.adjustments || [];
        const baseAmountLabel = this.adjustmentAmountFieldLabel;
        const baseCorrectLabel = this.customLabel.correctContract;
        const optsJson = JSON.stringify(this.correctContractOptionlst || []);
        return rows.map((row, index) => {
            const cc = row.correctContract != null ? String(row.correctContract).trim() : STR_EMPTY;
            const isManual = !!(cc && !this._hasCorrectContractPicklistOption(cc));
            return {
                ...row,
                correctContractLabel: index === 0 ? baseCorrectLabel : `${baseCorrectLabel} ${index + 1}`,
                adjustedAmountLabel: index === 0 ? baseAmountLabel : `${baseAmountLabel} ${index + 1}`,
                correctContractOptionsJson: optsJson,
                isCorrectContractManualInput: isManual
            };
        });
    }

    get isIncorrectContractManualInput() {
        const v = this.incorrectContract != null ? String(this.incorrectContract).trim() : STR_EMPTY;
        if (!v) {
            return false;
        }
        return !this._hasIncorrectContractPicklistOption(v);
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

    connectedCallback() {
        if (this.recordId) this.loadSubCodeConfig();
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
            incorrectContract: this.incorrectContract || STR_EMPTY,
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
        this.incorrectContract = draft.incorrectContract != null ? draft.incorrectContract : this.incorrectContract;
        this.paymentMethod = draft.paymentMethod != null ? draft.paymentMethod : this.paymentMethod;
        this.manualBillDate = draft.manualBillDate != null ? draft.manualBillDate : this.manualBillDate;
        this._sanitizeTh1ManualBillDateIfFuture();
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
                    if (data.inputCorrectContractNumber != null && String(data.inputCorrectContractNumber).trim()) {
                        adjRow.correctContract = String(data.inputCorrectContractNumber).trim();
                    } else if (data.correctContractNumber != null && String(data.correctContractNumber).trim()) {
                        adjRow.correctContract = String(data.correctContractNumber).trim();
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
                this._sanitizeTh1ManualBillDateIfFuture();
                if (data.billAmount != null && data.billAmount !== undefined) {
                    this.manualBillAmount = data.billAmount;
                } else {
                    this.manualBillAmount = null;
                }
                
                const incorrectContractPromise = getIncorrectContractOptions({ caseId: this.recordId })
                    .then((contractOpts) => {
                        this.incorrectContractOptionlst = contractOpts || [];
                    })
                    .catch(() => {
                        this.incorrectContractOptionlst = [];
                    });
                const correctContractPromise = getCorrectContractOptions()
                    .then((pickOpts) => {
                        this.correctContractOptionlst = pickOpts || [];
                    })
                    .catch(() => {
                        this.correctContractOptionlst = [];
                    });
                
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
                if (this.incorrectContract && this.incorrectContract.trim()) {
                    Promise.resolve().then(() => this.loadPaymentHistory());
                }
            })
            .catch((err) => {
                this.configLoaded = true;
                this.subCode = STR_EMPTY;
                this.incorrectContractOptionlst = [];
                this.correctContractOptionlst = [];
                this.paymentMethodOptionlst = [];
            });
    }

    _hasIncorrectContractPicklistOption(value) {
        if (!value) {
            return false;
        }
        return (this.incorrectContractOptionlst || []).some((o) => o && o.value === value);
    }

    _hasIncorrectContractPicklistOptionByText(inputValue) {
        if (!inputValue) {
            return false;
        }
        const normalizedValue = toUpperNoVietnameseAccent(String(inputValue)).trim();
        return (this.incorrectContractOptionlst || []).some((o) => o && (toUpperNoVietnameseAccent(o.value || STR_EMPTY).trim().includes(normalizedValue) || toUpperNoVietnameseAccent(o.label || STR_EMPTY).trim().includes(normalizedValue)));
    }

    _hasCorrectContractPicklistOption(value) {
        if (!value) {
            return false;
        }
        return (this.correctContractOptionlst || []).some((o) => o && o.value === value);
    }

    _hasCorrectContractPicklistOptionByText(inputValue) {
        if (!inputValue) {
            return false;
        }
        const normalizedValue = toUpperNoVietnameseAccent(String(inputValue)).trim();
        return (this.correctContractOptionlst || []).some((o) => o && (toUpperNoVietnameseAccent(o.value || STR_EMPTY).trim().includes(normalizedValue) || toUpperNoVietnameseAccent(o.label || STR_EMPTY).trim().includes(normalizedValue)));
    }

    _clearIncorrectContractHistoryLoadTimer() {
        if (this._incorrectContractHistoryLoadTimer) {
            clearTimeout(this._incorrectContractHistoryLoadTimer);
            this._incorrectContractHistoryLoadTimer = undefined;
        }
    }

    _scheduleIncorrectContractPaymentHistoryLoad() {
        this._clearIncorrectContractHistoryLoadTimer();
        this._incorrectContractHistoryLoadTimer = setTimeout(() => {
            this._incorrectContractHistoryLoadTimer = undefined;
            const contract = (this.incorrectContract || STR_EMPTY).trim();
            if (!contract || contract === this._lastLoadedContract) {
                return;
            }
            this.loadPaymentHistory();
        }, 450);
    }

    handleIncorrectContractSearchChange(event) {
        const inputValue = event.detail != null && event.detail.value !== undefined ? event.detail.value : STR_EMPTY;
        if (!inputValue) {
            return;
        }
        if (this._hasIncorrectContractPicklistOptionByText(inputValue)) {
            return;
        }
        this.incorrectContract = String(inputValue).trim();
        this._scheduleIncorrectContractPaymentHistoryLoad();
    }

    handleIncorrectContractManualInput(event) {
        const v = event.detail != null && event.detail.value !== undefined ? event.detail.value : event.target.value;
        this.incorrectContract = v != null ? String(v) : STR_EMPTY;
        const contract = (this.incorrectContract || STR_EMPTY).trim();
        if (!contract) {
            this._clearIncorrectContractHistoryLoadTimer();
            this.paymentHistory = [];
            this.paymentHistoryTableKey += 1;
            this.selectedPaymentId = null;
            this.selectedRowIds = [];
            this._lastLoadedContract = STR_EMPTY;
            return;
        }
        this._scheduleIncorrectContractPaymentHistoryLoad();
    }

    handleIncorrectContractManualBlur() {
        this._clearIncorrectContractHistoryLoadTimer();
        const contract = (this.incorrectContract || STR_EMPTY).trim();
        if (!contract) {
            return;
        }
        if (contract === this._lastLoadedContract) {
            return;
        }
        this.loadPaymentHistory();
    }

    handleRemoveIncorrectContract() {
        this._clearIncorrectContractHistoryLoadTimer();
        const element = this.template.querySelector(
            'c-fec_-combo-box[data-id="incorrect-contract"]'
        );
        if (element) {
            element.searchKey = undefined;
        }
        this.incorrectContract = STR_EMPTY;
        this.paymentHistory = [];
        this.paymentHistoryTableKey += 1;
        this.selectedPaymentId = null;
        this.selectedRowIds = [];
        this._lastLoadedContract = STR_EMPTY;
    }

    handleChangeIncorrectContract(e) {
        this._clearIncorrectContractHistoryLoadTimer();
        this.incorrectContract = e.detail.value || STR_EMPTY;
        const contract = (this.incorrectContract || STR_EMPTY).trim();
        if (!contract) {
            this.paymentHistory = [];
            this.paymentHistoryTableKey += 1;
            this.selectedPaymentId = null;
            this.selectedRowIds = [];
            this._lastLoadedContract = STR_EMPTY;
            return;
        }
        if (contract === this._lastLoadedContract) return;
        this.loadPaymentHistory();
    }

    loadPaymentHistory() {
        const contract = (this.incorrectContract || STR_EMPTY).trim();
        if (!contract) {
            this.paymentHistory = [];
            this.paymentHistoryTableKey += 1;
            return Promise.resolve();
        }
        this.paymentHistoryLoading = true;
        this.selectedPaymentId = null;
        this.selectedRowIds = [];
        return getPaymentHistoryFromSOAP({ contractNumber: contract })
            .then((data) => {
                this.paymentHistory = (data || []).map((p, idx) => ({
                    ...p,
                    paymentAmountDisplay: this.formatAmount(p.paymentAmount)
                }));
                this._lastLoadedContract = contract;
                if (this._pendingSelectedPaymentId != null) {
                    const pendingId = String(this._pendingSelectedPaymentId);
                    const matched = this.paymentHistory.find((p) => String(p.id) === pendingId);
                    if (matched) {
                        this.selectedPaymentId = pendingId;
                        this.selectedRowIds = [pendingId];
                    }
                    this._pendingSelectedPaymentId = null;
                }
                this.paymentHistoryTableKey += 1;
                this.paymentHistoryLoading = false;
            })
            .catch((err) => {
                this.paymentHistory = [];
                this.paymentHistoryTableKey += 1;
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
            if (row && this.effectiveSubCode) {
                if (this.th2Codes.includes(this.effectiveSubCode)) {
                    this.paymentDate = row.paymentDate || null;
                    this.excessAmount = row.paymentAmount;
                    this.th1EditableBillAmount = null;
                } else if (this.th1Codes.includes(this.effectiveSubCode)) {
                    this.th1EditableBillAmount = row.paymentAmount;
                    this.paymentDate = null;
                    this.excessAmount = null;
                }
            }
        }
        if (newId == null) {
            this.resetBillStateOnDeselect();
        }
    }

    resetBillStateOnDeselect() {
        this.paymentDate = null;
        this.excessAmount = null;
        this.th1EditableBillAmount = null;
        this.manualBillDate = null;
        this.manualBillAmount = null;
        Promise.resolve().then(() => {
            this._syncTh1ManualBillDateFieldValidity();
        });
    }

    _localYyyyMmDdToday() {
        const d = new Date();
        const y = d.getFullYear();
        const m = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        return `${y}-${m}-${day}`;
    }

    _isTh1BillDateIsoAfterToday(raw) {
        if (raw == null || raw === STR_EMPTY) {
            return false;
        }
        const t = String(raw).trim();
        if (t.length < 10) {
            return false;
        }
        const head = t.substring(0, 10);
        if (!/^\d{4}-\d{2}-\d{2}$/.test(head)) {
            return false;
        }
        return head > this._localYyyyMmDdToday();
    }

    _sanitizeTh1ManualBillDateIfFuture() {
        if ((!this.isTh1 && !this.isTh2) || !this.manualBillDate) {
            return;
        }
        if (this._isTh1BillDateIsoAfterToday(this.manualBillDate)) {
            this.manualBillDate = null;
            Promise.resolve().then(() => {
                this._syncTh1ManualBillDateFieldValidity();
            });
        }
    }

    _syncTh1ManualBillDateFieldValidity() {
        const el = this.template.querySelector('lightning-input[data-id="manual-bill-date"]');
        if (!el || !el.setCustomValidity) {
            return;
        }
        if (!this.isTh1 && !this.isTh2) {
            el.setCustomValidity(STR_EMPTY);
            return;
        }
        if (this.manualBillDate && this._isTh1BillDateIsoAfterToday(this.manualBillDate)) {
            el.setCustomValidity(FEC_MSG_IncorrectPayment_Date_Not_After_Today);
        } else {
            el.setCustomValidity(STR_EMPTY);
        }
        if (el.reportValidity) {
            el.reportValidity();
        }
    }

    handleManualBillDateChange(event) {
        const v = event.detail != null && event.detail.value !== undefined ? event.detail.value : event.target.value;
        this.manualBillDate = v || null;
        Promise.resolve().then(() => {
            this._syncTh1ManualBillDateFieldValidity();
        });
    }

    handleManualBillAmountChange(event) {
        const v = event.detail != null && event.detail.value !== undefined ? event.detail.value : event.target.value;
        this.manualBillAmount = v === STR_EMPTY || v == null ? null : (Number(v) || null);
    }

    handlePaymentMethodChange(event) {
        this.paymentMethod = event.detail.value || STR_EMPTY;
    }

    handleAddAdjustment() {
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

    handleAdjustmentCorrectContractComboChange(event) {
        const id = Number(event.currentTarget.dataset.idValue);
        const idx = this.adjustments.findIndex((a) => a.id === id);
        if (idx < 0) {
            return;
        }
        const v = event.detail != null && event.detail.value !== undefined ? event.detail.value : STR_EMPTY;
        if (!v) {
            return;
        }
        const next = [...this.adjustments];
        next[idx] = { ...next[idx], correctContract: v || STR_EMPTY };
        this.adjustments = next;
        const cmp = event.currentTarget;
        if (cmp && cmp.setCustomValidity) {
            cmp.setCustomValidity(STR_EMPTY);
            if (cmp.reportValidity) {
                cmp.reportValidity();
            }
        }
    }

    handleAdjustmentCorrectContractSearchChange(event) {
        const id = Number(event.currentTarget.dataset.idValue);
        const inputValue = event.detail != null && event.detail.value !== undefined ? event.detail.value : STR_EMPTY;
        if (!inputValue) {
            return;
        }
        if (this._hasCorrectContractPicklistOptionByText(inputValue)) {
            return;
        }
        const idx = this.adjustments.findIndex((a) => a.id === id);
        if (idx < 0) {
            return;
        }
        const next = [...this.adjustments];
        next[idx] = { ...next[idx], correctContract: String(inputValue).trim() };
        this.adjustments = next;
    }

    handleAdjustmentCorrectContractManualInput(event) {
        const id = Number(event.currentTarget.dataset.idValue);
        const idx = this.adjustments.findIndex((a) => a.id === id);
        if (idx < 0) {
            return;
        }
        const v = event.detail != null && event.detail.value !== undefined ? event.detail.value : event.target.value;
        const next = [...this.adjustments];
        next[idx] = { ...next[idx], correctContract: v != null ? String(v) : STR_EMPTY };
        this.adjustments = next;
        const cmp = event.currentTarget;
        if (cmp && cmp.setCustomValidity) {
            cmp.setCustomValidity(STR_EMPTY);
            if (cmp.reportValidity) {
                cmp.reportValidity();
            }
        }
    }

    handleAdjustmentCorrectContractRemove(event) {
        const id = Number(event.currentTarget.dataset.idValue);
        if (!id) {
            return;
        }
        const idx = this.adjustments.findIndex((a) => a.id === id);
        if (idx < 0) {
            return;
        }
        const next = [...this.adjustments];
        next[idx] = { ...next[idx], correctContract: STR_EMPTY };
        this.adjustments = next;
    }

    handleAdjustmentAmountChange(event) {
        const id = Number(event.currentTarget.dataset.idValue);
        const idx = this.adjustments.findIndex(a => a.id === id);
        if (idx < 0) return;
        const v = event.detail != null && event.detail.value !== undefined ? event.detail.value : event.target.value;
        let amount = null;
        if (v !== STR_EMPTY && v != null) {
            const n = Number(v);
            if (!isNaN(n)) {
                amount = n;
            }
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
            const comboCorrect = this.template.querySelector('c-fec_-combo-box[data-id-value="' + a.id + '"]');
            const manualCorrect = this.template.querySelector('lightning-input[data-id="correct-contract-manual"][data-id-value="' + a.id + '"]');
            const input = this.template.querySelector('lightning-input[data-id-value="' + a.id + '"]:not([data-id="correct-contract-manual"])');
            if (comboCorrect && comboCorrect.setCustomValidity) {
                comboCorrect.setCustomValidity(STR_EMPTY);
            }
            if (manualCorrect && manualCorrect.setCustomValidity) {
                manualCorrect.setCustomValidity(STR_EMPTY);
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
            const comboCorrect = this.template.querySelector('c-fec_-combo-box[data-id-value="' + id + '"]');
            const manualCorrect = this.template.querySelector('lightning-input[data-id="correct-contract-manual"][data-id-value="' + id + '"]');
            const input = this.template.querySelector('lightning-input[data-id-value="' + id + '"]:not([data-id="correct-contract-manual"])');
            if (r.hasContract && !r.hasAmount) {
                if (comboCorrect && comboCorrect.setCustomValidity) {
                    comboCorrect.setCustomValidity(STR_EMPTY);
                }
                if (manualCorrect && manualCorrect.setCustomValidity) {
                    manualCorrect.setCustomValidity(STR_EMPTY);
                }
                if (input && input.setCustomValidity) {
                    input.setCustomValidity(msg);
                    input.reportValidity();
                }
            } else if (!r.hasContract && r.hasAmount) {
                if (input && input.setCustomValidity) {
                    input.setCustomValidity(STR_EMPTY);
                }
                if (manualCorrect && manualCorrect.setCustomValidity) {
                    manualCorrect.setCustomValidity(msg);
                    if (manualCorrect.reportValidity) {
                        manualCorrect.reportValidity();
                    }
                }
                if (comboCorrect && comboCorrect.setCustomValidity) {
                    comboCorrect.setCustomValidity(msg);
                    if (comboCorrect.reportValidity) {
                        comboCorrect.reportValidity();
                    }
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
        const comboCorrect = this.template.querySelector('c-fec_-combo-box[data-id-value="' + id + '"]');
        const manualCorrect = this.template.querySelector('lightning-input[data-id="correct-contract-manual"][data-id-value="' + id + '"]');
        const input = this.template.querySelector('lightning-input[data-id-value="' + id + '"]:not([data-id="correct-contract-manual"])');
        if (comboCorrect && comboCorrect.reportValidity) {
            comboCorrect.reportValidity();
        }
        if (manualCorrect && manualCorrect.reportValidity) {
            manualCorrect.reportValidity();
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
        const hasManualBillAmount = this.manualBillAmount != null && this.manualBillAmount !== 0;
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
            const billAmtSel = 'lightning-input[data-id="manual-bill-amount"]';
            const dateSel = 'lightning-input[data-id="manual-bill-date"]';
            if (this.isTh1 || this.isTh2) {
                this._syncTh1ManualBillDateFieldValidity();
                const dateOk = this.validateFields([dateSel]);
                if (!dateOk) {
                    return false;
                }
            }
            const billAmtOk = this.validateFields([billAmtSel]);
            const billAmtMissing = this.manualBillAmount == null;
            if (!billAmtOk || billAmtMissing) {
                const billAmtEl = this.template.querySelector(billAmtSel);
                if (billAmtEl && billAmtEl.reportValidity) {
                    billAmtEl.reportValidity();
                }
                this.dispatchEvent(new ShowToastEvent({
                    title: FEC_Toast_Validation_Title,
                    message: (this.isTh2 ? FEC_LBL_Excess_Amount : FEC_LBL_Bill_Amount) + ': ' + FEC_Complete_This_Field,
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
        let billAmount = null;
        if (this.isTh1 && this.th1EditableBillAmount != null) {
            billAmount = this.th1EditableBillAmount;
        } else if (this.selectedPayment) {
            billAmount = this.selectedPayment.paymentAmount ?? null;
        } else {
            billAmount = this.manualBillAmount ?? null;
        }

        const billFieldsRendered = this.showManualBill || this.selectedPaymentId;
        if (!billFieldsRendered && (billAmount == null || billAmount === 0)) {
            return { skipApex: true, valid, billDate, billAmount };
        }
        const sumAdjusted = valid.reduce((sum, a) => sum + Number(a.adjustedAmount), 0);
        const tolerance = 0.01;

        if (Math.abs(sumAdjusted - Number(billAmount)) > tolerance) {
            this.dispatchEvent(new ShowToastEvent({ 
                title: FEC_Toast_Validation_Title, 
                message: FEC_MSG_Adjusted_Amount_Must_Equal_Payment, 
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
        let billAmount = null;
        if (this.isTh1 && this.th1EditableBillAmount != null) {
            billAmount = this.th1EditableBillAmount;
        } else if (this.selectedPayment) {
            billAmount = this.selectedPayment.paymentAmount ?? null;
        } else {
            billAmount = this.manualBillAmount ?? null;
        }

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
        this._clearIncorrectContractHistoryLoadTimer();
        const ic = (this.incorrectContract || STR_EMPTY).trim();
        const syncHistory = ic && ic !== this._lastLoadedContract
            ? this.loadPaymentHistory()
            : Promise.resolve();
        return syncHistory.then(() => {
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
        });
    }
}