/****************************************************************************************
 * File Name    : fec_IncorrectPaymentForm.js
 * Description  : Incorrect Payment Form (child of dynamic LWC loader) - contract input, GetLoanSecInfo, adjustments (TH1/TH2 by subcode config).
 ****************************************************************************************/

import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPaymentHistoryFromSOAP from '@salesforce/apex/FEC_IncorrectPaymentController.getPaymentHistoryFromSOAP';
import getSubCodeConfig from '@salesforce/apex/FEC_IncorrectPaymentController.getSubCodeConfig';
import getIncorrectContractOptions from '@salesforce/apex/FEC_IncorrectPaymentController.getIncorrectContractOptions';
import saveAdjustment from '@salesforce/apex/FEC_IncorrectPaymentController.saveAdjustment';
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
import FEC_LBL_Incorrect_Payment_Form_Title from '@salesforce/label/c.FEC_LBL_Incorrect_Payment_Form_Title';
import FEC_LBL_Incorrect_Contract_Number from '@salesforce/label/c.FEC_LBL_Incorrect_Contract_Number';
import FEC_LBL_Select_Contract_Number from '@salesforce/label/c.FEC_LBL_Select_Contract_Number';
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
import FEC_Toast_Validation_Message from '@salesforce/label/c.FEC_Toast_Validation_Message';
import FEC_LBL_Payment_Method_Bank_Transfer from '@salesforce/label/c.FEC_LBL_Payment_Method_Bank_Transfer';
import FEC_LBL_Payment_Method_Other_Channels from '@salesforce/label/c.FEC_LBL_Payment_Method_Other_Channels';

const CONST = {
    EMPTY: '',
    DATE_PLACEHOLDER: 'DD/MM/YYYY',
    VARIANT_ERROR: 'error',
    VARIANT_SUCCESS: 'success',
    VARIANT_WARNING: 'warning',
    ROW_SELECT: 'rowSelect',
    ROW_DESELECT: 'rowDeselect',
    DESELECT_ALL_ROWS: 'deselectAllRows',
    LOCALE_EN_US: 'en-US',
    SECTION_MAIN: 'main',
    ICON_EXPAND: 'utility:chevrondown',
    ICON_COLLAPSE: 'utility:chevronright',
    TH1_CODES: ['RL08.01', 'RL08.02', 'RL08.03', 'RL08.04', 'RL08.08'],
    TH2_CODES: ['RL08.05', 'RL08.06', 'RL08.07']
};

export default class Fec_IncorrectPaymentForm extends LightningElement {

    @api recordId;

    @track subCode = CONST.EMPTY;
    @track incorrectContract = CONST.EMPTY;
    @track paymentHistory = [];
    @track selectedPaymentId = null;
    @track selectedRowIds = [];
    @track manualBillDate = null;
    @track manualBillAmount = null;
    @track paymentDate = null;
    @track excessAmount = null;
    @track th1EditableBillAmount = null;
    @track paymentMethod = CONST.EMPTY;
    @track adjustments = [{ id: 1, correctContract: CONST.EMPTY, adjustedAmount: null }];
    @track nextAdjustmentId = 2;
    @track isLoading = false;
    @track paymentHistoryLoading = false;
    @track configLoaded = false;
    @track paymentHistoryTableKey = 0;
    @track incorrectContractOptionlst = [];
    @track activeSections = [CONST.SECTION_MAIN];
    _lastLoadedContract = CONST.EMPTY;

    customLabel = {
        loading: Loading,
        sectionTitle: FEC_LBL_Incorrect_Payment_Form_Title,
        incorrectContractNumber: FEC_LBL_Incorrect_Contract_Number,
        selectContractPlaceholder: FEC_LBL_Select_Contract_Number,
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

    paymentMethodOptions = [
        { label: FEC_LBL_Payment_Method_Bank_Transfer, value: FEC_LBL_Payment_Method_Bank_Transfer },
        { label: FEC_LBL_Payment_Method_Other_Channels, value: FEC_LBL_Payment_Method_Other_Channels }
    ];

    get showManualBill() {
        if (this.selectedPaymentId) return false;
        return this.incorrectContractTrimmed || this.hasPaymentHistory;
    }

    get showSelectedBillReadOnly() {
        return !!this.selectedPaymentId && this.selectedPayment != null && !this.isTh2;
    }

    get displayBillDate() {
        return this.selectedPayment ? (this.selectedPayment.paymentDate || CONST.EMPTY) : CONST.EMPTY;
    }

    get displayBillAmount() {
        if (!this.selectedPayment || this.selectedPayment.paymentAmount == null) return CONST.EMPTY;
        return this.formatAmount(this.selectedPayment.paymentAmount);
    }

    get th1Codes() {
        return CONST.TH1_CODES;
    }

    get th2Codes() {
        return CONST.TH2_CODES;
    }

    get isTh1() {
        const code = (this.subCode || CONST.EMPTY).trim();
        return code && this.th1Codes.includes(code);
    }

    get isTh2() {
        const code = (this.subCode || CONST.EMPTY).trim();
        return code && this.th2Codes.includes(code);
    }

    get displayExcessAmount() {
        if (this.excessAmount == null) return CONST.EMPTY;
        return this.formatAmount(this.excessAmount);
    }

    get displayPaymentDate() {
        if (this.paymentDate) return this.paymentDate;
        return this.selectedPayment ? (this.selectedPayment.paymentDate || CONST.EMPTY) : CONST.EMPTY;
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
        return this.adjustments || [];
    }

    get incorrectContractTrimmed() {
        return (this.incorrectContract || CONST.EMPTY).trim().length > 0;
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

    get isMainSectionOpen() {
        return this.activeSections.includes(CONST.SECTION_MAIN);
    }

    get sectionIconName() {
        return this.isMainSectionOpen ? CONST.ICON_EXPAND : CONST.ICON_COLLAPSE;
    }

    get formSectionClass() {
        let classes = 'slds-accordion__section';
        if (this.isMainSectionOpen) {
            classes += ' slds-is-open';
        }
        return classes;
    }

    get formContentClass() {
        return this.isMainSectionOpen ? 'slds-accordion__content' : 'slds-accordion__content slds-hide';
    }

    toggleMainSection() {
        if (this.isMainSectionOpen) {
            this.activeSections = [];
        } else {
            this.activeSections = [CONST.SECTION_MAIN];
        }
    }

    loadSubCodeConfig() {
        getSubCodeConfig({ caseId: this.recordId })
            .then((data) => {
                this.subCode = data.subCode || CONST.EMPTY;
                this.incorrectContract = data.incorrectContractNumber != null ? data.incorrectContractNumber : CONST.EMPTY;
                this.paymentMethod = data.paymentMethod != null ? data.paymentMethod : CONST.EMPTY;
                return getIncorrectContractOptions({ caseId: this.recordId })
                    .then((contractOpts) => {
                        this.incorrectContractOptionlst = contractOpts || [];
                    })
                    .catch(() => {
                        this.incorrectContractOptionlst = [];
                    });
            })
            .then(() => {
                this.configLoaded = true;
                if (this.incorrectContract && this.incorrectContract.trim()) {
                    Promise.resolve().then(() => this.loadPaymentHistory());
                }
            })
            .catch((err) => {
                this.configLoaded = true;
                this.subCode = CONST.EMPTY;
                this.incorrectContractOptionlst = [];
            });
    }

    handleRemoveIncorrectContract() {
        const element = this.template.querySelector(
            'c-fec_-combo-box[data-id="incorrect-contract"]'
        );
        if (element) {
            element.searchKey = undefined;
        }
        this.incorrectContract = CONST.EMPTY;
        this.paymentHistory = [];
        this.paymentHistoryTableKey += 1;
        this.selectedPaymentId = null;
        this.selectedRowIds = [];
        this._lastLoadedContract = CONST.EMPTY;
    }

    handleChangeIncorrectContract(e) {
        this.incorrectContract = e.detail.value || CONST.EMPTY;
        const contract = (this.incorrectContract || CONST.EMPTY).trim();
        if (!contract) {
            this.paymentHistory = [];
            this.paymentHistoryTableKey += 1;
            this.selectedPaymentId = null;
            this.selectedRowIds = [];
            this._lastLoadedContract = CONST.EMPTY;
            return;
        }
        if (contract === this._lastLoadedContract) return;
        this.loadPaymentHistory();
    }

    loadPaymentHistory() {
        const contract = (this.incorrectContract || CONST.EMPTY).trim();
        if (!contract) {
            this.paymentHistory = [];
            this.paymentHistoryTableKey += 1;
            return;
        }
        this.paymentHistoryLoading = true;
        this.selectedPaymentId = null;
        this.selectedRowIds = [];
        getPaymentHistoryFromSOAP({ contractNumber: contract })
            .then((data) => {
                this.paymentHistory = (data || []).map((p, idx) => ({
                    ...p,
                    paymentAmountDisplay: this.formatAmount(p.paymentAmount)
                }));
                this._lastLoadedContract = contract;
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
        if (val == null) return CONST.EMPTY;
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
        if (action === CONST.ROW_SELECT && toggledId != null && toggledId !== CONST.EMPTY) {
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
            if (row && this.subCode) {
                if (this.th2Codes.includes(this.subCode)) {
                    this.paymentDate = row.paymentDate || null;
                    this.excessAmount = row.paymentAmount;
                    this.th1EditableBillAmount = null;
                } else if (this.th1Codes.includes(this.subCode)) {
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
    }

    handleManualBillDateChange(event) {
        this.manualBillDate = event.target.value || null;
    }

    handleManualBillAmountChange(event) {
        const v = event.target.value;
        this.manualBillAmount = v === CONST.EMPTY ? null : (Number(v) || null);
    }

    handlePaymentMethodChange(event) {
        this.paymentMethod = event.detail.value || CONST.EMPTY;
    }

    handleAddAdjustment() {
        this.adjustments = [...this.adjustments, { id: this.nextAdjustmentId, correctContract: CONST.EMPTY, adjustedAmount: null }];
        this.nextAdjustmentId += 1;
    }

    handleRemoveAdjustment(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        const numId = Number(id);
        this.adjustments = this.adjustments.filter(a => a.id !== numId);
        if (this.adjustments.length === 0) {
            this.adjustments = [{ id: this.nextAdjustmentId++, correctContract: CONST.EMPTY, adjustedAmount: null }];
        }
    }

    handleAdjustmentCorrectContractChange(event) {
        const id = Number(event.target.dataset.id);
        const idx = this.adjustments.findIndex(a => a.id === id);
        if (idx < 0) return;
        const next = [...this.adjustments];
        next[idx] = { ...next[idx], correctContract: event.target.value || CONST.EMPTY };
        this.adjustments = next;
    }

    handleAdjustmentAmountChange(event) {
        const id = Number(event.target.dataset.id);
        const idx = this.adjustments.findIndex(a => a.id === id);
        if (idx < 0) return;
        const v = event.target.value;
        const amount = v === CONST.EMPTY ? null : (Number(v) || null);
        const next = [...this.adjustments];
        next[idx] = { ...next[idx], adjustedAmount: amount };
        this.adjustments = next;
    }

    validatePaymentMethodField() {
        const paymentMethodCmp = this.template.querySelector('lightning-combobox[name="paymentMethod"]');
        if (!paymentMethodCmp) return true;
        paymentMethodCmp.reportValidity();
        return paymentMethodCmp.checkValidity();
    }

    validateManualBillAmountField() {
        const manualBillAmountCmp = this.template.querySelector('lightning-input[name="manualBillAmount"]');
        if (!manualBillAmountCmp) return true;
        manualBillAmountCmp.reportValidity();
        return manualBillAmountCmp.checkValidity();
    }

    @api saveAdjustments() {
        if (!this.validatePaymentMethodField()) {
            return Promise.reject(new Error('validation'));
        }
        const valid = this.adjustments.filter(a => (a.correctContract && String(a.correctContract).trim()) && (a.adjustedAmount != null && a.adjustedAmount !== 0));
        if (valid.length === 0) {
            this.dispatchEvent(new ShowToastEvent({ title: FEC_Toast_Validation_Title, message: FEC_Toast_Validation_Message, variant: CONST.VARIANT_WARNING }));
            return Promise.reject(new Error('validation'));
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
        if (this.showManualBill && !this.validateManualBillAmountField()) {
            return Promise.reject(new Error('validation'));
        }
        if (!billFieldsRendered && (billAmount == null || billAmount === 0)) {
            return Promise.resolve();
        }
        const sumAdjusted = valid.reduce((sum, a) => sum + Number(a.adjustedAmount), 0);
        const tolerance = 0.01;
        if (Math.abs(sumAdjusted - Number(billAmount)) > tolerance) {
            this.dispatchEvent(new ShowToastEvent({ title: FEC_Toast_Validation_Title, message: FEC_MSG_Adjusted_Amount_Must_Equal_Payment, variant: CONST.VARIANT_WARNING }));
            return Promise.reject(new Error('validation'));
        }
        this.isLoading = true;
        const payload = valid.map(a => ({ correctContract: (a.correctContract || CONST.EMPTY).trim(), adjustedAmount: a.adjustedAmount }));
        return saveAdjustment({ caseId: this.recordId, incorrectContract: this.incorrectContract || CONST.EMPTY, paymentMethod: this.paymentMethod || CONST.EMPTY, billDate: billDate || CONST.EMPTY, billAmount: billAmount, adjustments: payload })
            .then(() => {
                this.isLoading = false;
                this.dispatchEvent(new ShowToastEvent({ title: FEC_Success_Title, message: FEC_Toast_Save_Success, variant: CONST.VARIANT_SUCCESS }));
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