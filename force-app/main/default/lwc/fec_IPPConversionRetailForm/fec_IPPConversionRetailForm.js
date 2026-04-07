/****************************************************************************************
 * File Name    : fec_IPPConversionRetailForm.js
 * Description  : RC34.01 – Chuyển đổi IPP Retail: eligible transactions, Check IPP Details, Convert IPP, retry 3, manual entry.
 ****************************************************************************************/

import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getEligibleTransactions from '@salesforce/apex/FEC_IPPConversionController.getEligibleTransactions';
import checkIPPDetails from '@salesforce/apex/FEC_IPPConversionController.checkIPPDetails';
import convertIPP from '@salesforce/apex/FEC_IPPConversionController.convertIPP';
import convertIPPManualRetail from '@salesforce/apex/FEC_IPPConversionController.convertIPPManualRetail';
import FEC_MSG_IPP_Conversion_Success from '@salesforce/label/c.FEC_MSG_IPP_Conversion_Success';
import FEC_MSG_IPP_Conversion_Fail_Retry from '@salesforce/label/c.FEC_MSG_IPP_Conversion_Fail_Retry';
import FEC_MSG_IPP_Conversion_Fail_Disable from '@salesforce/label/c.FEC_MSG_IPP_Conversion_Fail_Disable';
import FEC_MSG_IPP_No_Eligible_Transactions from '@salesforce/label/c.FEC_MSG_IPP_No_Eligible_Transactions';
import FEC_MSG_IPP_AddIpp_Default_Failed from '@salesforce/label/c.FEC_MSG_IPP_AddIpp_Default_Failed';
import FEC_LBL_IPP_Retail_UI from '@salesforce/label/c.FEC_LBL_IPP_Retail_UI';
import FEC_Button_Close from '@salesforce/label/c.FEC_Button_Close';
import Loading from '@salesforce/label/c.Loading';
import FEC_Toast_Error from '@salesforce/label/c.FEC_Toast_Error';
import FEC_Toast_Warning from '@salesforce/label/c.FEC_Toast_Warning';
import FEC_Success_Title from '@salesforce/label/c.FEC_Success_Title';
import FEC_Toast_Error_Generic from '@salesforce/label/c.FEC_Toast_Error_Generic';
import FEC_Toast_Validation_Message from '@salesforce/label/c.FEC_Toast_Validation_Message';
import FEC_MSG_Param_Required from '@salesforce/label/c.FEC_MSG_Param_Required';
import { STR_EMPTY, FORM_STATE_LOADING, FORM_STATE_NONE, FORM_STATE_HAS_DATA } from 'c/fec_CommonConst';
import { formatToDDMMYYYY } from 'c/fec_CommonUtils';

function parseIppRetailUiBundled(raw) {
    const p = (raw || STR_EMPTY).split('##');
    return {
        unbilledHeading: p[0] || STR_EMPTY,
        btnCheckDetails: p[1] || STR_EMPTY,
        btnConvert: p[2] || STR_EMPTY,
        modalTitle: p[3] || STR_EMPTY,
        modalBody: p[4] || STR_EMPTY,
        plSuccess: p[5] || STR_EMPTY,
        plOther: p[6] || STR_EMPTY,
        plYes: p[7] || STR_EMPTY,
        plNo: p[8] || STR_EMPTY,
        plCustomer: p[9] || STR_EMPTY
    };
}

const IPP_RETAIL_UI = parseIppRetailUiBundled(FEC_LBL_IPP_Retail_UI);

const CONST = {
    MAX_RETRY: 3,
    VARIANT_ERROR: 'error',
    VARIANT_SUCCESS: 'success',
    VARIANT_WARNING: 'warning',
    SPIN_CONVERTING: 'Converting',
    LBL_TENOR: 'Tenor',
    LBL_INTEREST: 'Interest',
    LBL_CONVERSION_FEE: 'Conversion Fee',
    LBL_EMI: 'EMI',
    COL_TRX_CODE: 'Transaction Code',
    COL_EFF_DATE: 'Effective Date',
    COL_TRX_PLAN: 'Transaction Plan',
    COL_TRX_AMT: 'Transaction Amount',
    COL_POST_DATE: 'Post Date',
    COL_AUTH_CODE: 'Authorization Code',
    COL_MERCHANT: 'Merchant Description',
    CASE_ID_PARAM: 'Case Id'
};

export default class Fec_IPPConversionRetailForm extends NavigationMixin(LightningElement) {

    @api recordId;

    @track transactions = [];
    @track selectedTransactionId = null;
    @track details = null;
    @track tenorOptions = [];
    @track selectedTenor = null;
    @track isLoading = false;
    @track detailsLoading = false;
    @track convertLoading = false;
    @track convertDisabled = false;
    @track retryCount = 0;
    @track showConfirmModal = false;
    @track showManualEntry = false;
    @track manualAmount = null;
    @track manualTenor = null;
    @track manualInterestRate = null;
    @track manualFee = null;
    @track manualVerificationInfo = null;
    @track manualCallback = null;
    @track manualCardType2 = null;
    @track manualStatementDate = null;
    @track manualDueDate = null;
    @track manualTransactionDate = null;
    @track manualTransactionAmount = null;
    @track manualApprovalCode = null;
    @track manualTransactionPlan = null;
    @track manualInstallmentAmount = null;
    @track manualInstallmentTerm = null;
    @track manualConversionInterest = null;
    @track manualSubmitLoading = false;

    ippRetailUi = IPP_RETAIL_UI;

    verificationInfoOptions = [
        { label: IPP_RETAIL_UI.plSuccess, value: IPP_RETAIL_UI.plSuccess },
        { label: IPP_RETAIL_UI.plOther, value: IPP_RETAIL_UI.plOther }
    ];
    callbackOptions = [
        { label: IPP_RETAIL_UI.plYes, value: IPP_RETAIL_UI.plYes },
        { label: IPP_RETAIL_UI.plNo, value: IPP_RETAIL_UI.plNo }
    ];
    cardType2Options = [
        { label: IPP_RETAIL_UI.plCustomer, value: IPP_RETAIL_UI.plCustomer },
        { label: IPP_RETAIL_UI.plOther, value: IPP_RETAIL_UI.plOther }
    ];

    state = FORM_STATE_LOADING;

    transactionColumns = [
        { label: CONST.COL_TRX_CODE, fieldName: 'transactionCode', type: 'text' },
        { label: CONST.COL_EFF_DATE, fieldName: 'effectiveDateStr', type: 'text' },
        { label: CONST.COL_TRX_PLAN, fieldName: 'transactionPlan', type: 'text' },
        { label: CONST.COL_TRX_AMT, fieldName: 'amountDisplay', type: 'text' },
        { label: CONST.COL_POST_DATE, fieldName: 'postingDateStr', type: 'text' },
        { label: CONST.COL_AUTH_CODE, fieldName: 'authorizationCode', type: 'text' },
        { label: CONST.COL_MERCHANT, fieldName: 'merchant', type: 'text' }
    ];

    lblTenor = CONST.LBL_TENOR;
    lblInterest = CONST.LBL_INTEREST;
    lblConversionFee = CONST.LBL_CONVERSION_FEE;
    lblEmi = CONST.LBL_EMI;
    lblSpinnerLoading = Loading;
    lblSpinnerDetails = Loading;
    lblSpinnerConverting = CONST.SPIN_CONVERTING;
    lblClose = FEC_Button_Close;

    connectedCallback() {
        this.loadEligibleTransactions();
    }

    loadEligibleTransactions() {
        if (!this.recordId) {
            this.state = FORM_STATE_NONE;
            return;
        }
        this.isLoading = true;
        getEligibleTransactions({ caseId: this.recordId })
            .then((data) => {
                this.transactions = (data || []).map(t => ({
                    ...t,
                    amountDisplay: t.amount != null ? this.formatAmount(t.amount) : STR_EMPTY,
                    effectiveDateStr: formatToDDMMYYYY(t.effectiveDateStr) || t.effectiveDateStr || STR_EMPTY,
                    postingDateStr: formatToDDMMYYYY(t.postingDateStr) || t.postingDateStr || STR_EMPTY
                }));
                if (this.transactions.length === 0) {
                    this.state = FORM_STATE_NONE;
                } else {
                    this.state = FORM_STATE_HAS_DATA;
                }
            })
            .catch((err) => {
                this.state = FORM_STATE_NONE;
                this.showToast(FEC_Toast_Error, err?.body?.message || err?.message || FEC_Toast_Error_Generic, CONST.VARIANT_ERROR);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows || [];
        this.selectedTransactionId = selectedRows.length === 1 ? selectedRows[0].transactionId : null;
        this.details = null;
        this.selectedTenor = null;
    }

    handleCheckIPPDetails() {
        if (!this.selectedTransactionId) {
            this.showToast(FEC_Toast_Warning, FEC_Toast_Validation_Message, CONST.VARIANT_WARNING);
            return;
        }
        this.detailsLoading = true;
        this.details = null;
        checkIPPDetails({ caseId: this.recordId, transactionId: this.selectedTransactionId })
            .then((res) => {
                if (res && res.errorMessage) {
                    this.showToast(FEC_Toast_Error, res.errorMessage, CONST.VARIANT_ERROR);
                    return;
                }
                this.details = res;
                this.tenorOptions = (res.tenorOptions || []).map(t => ({ label: String(t), value: t }));
                this.selectedTenor = this.tenorOptions.length > 0 ? this.tenorOptions[0].value : null;
            })
            .catch((err) => {
                this.showToast(FEC_Toast_Error, err?.body?.message || err?.message || FEC_Toast_Error_Generic, CONST.VARIANT_ERROR);
            })
            .finally(() => {
                this.detailsLoading = false;
            });
    }

    handleConvertIPP() {
        if (!this.selectedTransactionId || !this.selectedTenor) {
            this.showToast(FEC_Toast_Warning, FEC_Toast_Validation_Message, CONST.VARIANT_WARNING);
            return;
        }
        this.showConfirmModal = true;
    }

    handleConfirmYes() {
        this.showConfirmModal = false;
        this.doConvert();
    }

    handleConfirmNo() {
        this.showConfirmModal = false;
    }

    doConvert() {
        this.convertLoading = true;
        convertIPP({
            caseId: this.recordId,
            transactionId: this.selectedTransactionId,
            tenor: this.selectedTenor
        })
            .then((res) => {
                if (res && res.success) {
                    this.showToast(FEC_Success_Title, FEC_MSG_IPP_Conversion_Success, CONST.VARIANT_SUCCESS);
                    this.navigateToCase();
                } else {
                    this.retryCount += 1;
                    if (this.retryCount >= CONST.MAX_RETRY) {
                        this.convertDisabled = true;
                        this.showToast(FEC_Toast_Error, FEC_MSG_IPP_Conversion_Fail_Disable, CONST.VARIANT_ERROR);
                        this.navigateToCase();
                    } else {
                        this.showToast(FEC_Toast_Error, res?.errorMessage || FEC_MSG_IPP_Conversion_Fail_Retry, CONST.VARIANT_ERROR);
                    }
                }
            })
            .catch((err) => {
                this.retryCount += 1;
                if (this.retryCount >= CONST.MAX_RETRY) {
                    this.convertDisabled = true;
                    this.showToast(FEC_Toast_Error, FEC_MSG_IPP_Conversion_Fail_Disable, CONST.VARIANT_ERROR);
                    this.navigateToCase();
                } else {
                    this.showToast(FEC_Toast_Error, err?.body?.message || err?.message || FEC_MSG_IPP_Conversion_Fail_Retry, CONST.VARIANT_ERROR);
                }
            })
            .finally(() => {
                this.convertLoading = false;
            });
    }

    handleTenorChange(event) {
        this.selectedTenor = event.detail.value ? parseInt(event.detail.value, 10) : null;
    }

    navigateToCase() {
        if (!this.recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Case',
                actionName: 'view'
            }
        });
    }

    resetManualEntryFields() {
        this.manualVerificationInfo = null;
        this.manualCallback = null;
        this.manualCardType2 = null;
        this.manualStatementDate = null;
        this.manualDueDate = null;
        this.manualTransactionDate = null;
        this.manualTransactionAmount = null;
        this.manualApprovalCode = null;
        this.manualTransactionPlan = null;
        this.manualInstallmentAmount = null;
        this.manualInstallmentTerm = null;
        this.manualConversionInterest = null;
    }

    handleShowManualEntry() {
        this.resetManualEntryFields();
        this.showManualEntry = true;
    }

    handleManualEntryCancel() {
        this.showManualEntry = false;
        this.resetManualEntryFields();
    }

    handleManualVerificationInfoChange(event) { this.manualVerificationInfo = event.detail.value; }
    handleManualCallbackChange(event) { this.manualCallback = event.detail.value; }
    handleManualCardType2Change(event) { this.manualCardType2 = event.detail.value; }
    handleManualStatementDateChange(event) { this.manualStatementDate = event.detail.value; }
    handleManualDueDateChange(event) { this.manualDueDate = event.detail.value; }
    handleManualTransactionDateChange(event) { this.manualTransactionDate = event.detail.value; }
    handleManualTransactionAmountChange(event) {
        const v = event.detail.value;
        this.manualTransactionAmount = v !== STR_EMPTY && v != null ? parseFloat(v, 10) : null;
    }
    handleManualApprovalCodeChange(event) { this.manualApprovalCode = event.detail.value; }
    handleManualTransactionPlanChange(event) { this.manualTransactionPlan = event.detail.value; }
    handleManualInstallmentAmountChange(event) {
        const v = event.detail.value;
        this.manualInstallmentAmount = v !== STR_EMPTY && v != null ? parseFloat(v, 10) : null;
    }
    handleManualInstallmentTermChange(event) {
        const v = event.detail.value;
        this.manualInstallmentTerm = v !== STR_EMPTY && v != null ? parseInt(v, 10) : null;
    }
    get displayConversionInterest() {
        return this.manualConversionInterest != null && this.manualConversionInterest !== STR_EMPTY
            ? String(this.manualConversionInterest) + '%'
            : STR_EMPTY;
    }
    handleManualConversionInterestChange(event) {
        const raw = event.detail.value;
        if (raw === CONST.EMPTY || raw == null) {
            this.manualConversionInterest = null;
            return;
        }
        const s = String(raw).replace(/%/g, STR_EMPTY).trim();
        const num = parseFloat(s, 10);
        this.manualConversionInterest = isNaN(num) ? null : num;
    }

    handleManualEntrySubmit() {
        const allFields = [
            this.manualVerificationInfo,
            this.manualCallback,
            this.manualCardType2,
            this.manualStatementDate,
            this.manualDueDate,
            this.manualTransactionDate,
            this.manualTransactionAmount,
            this.manualApprovalCode,
            this.manualTransactionPlan,
            this.manualInstallmentAmount,
            this.manualInstallmentTerm,
            this.manualConversionInterest
        ];
        if (allFields.some(f => f === undefined || f === null || f === STR_EMPTY)) {
            this.showToast(FEC_Toast_Warning, FEC_Toast_Validation_Message, CONST.VARIANT_WARNING);
            return;
        }
        if (!this.recordId) {
            this.showToast(FEC_Toast_Error, FEC_MSG_Param_Required.replace('{0}', CONST.CASE_ID_PARAM), CONST.VARIANT_ERROR);
            return;
        }
        this.manualSubmitLoading = true;
        convertIPPManualRetail({
            caseId: this.recordId,
            verificationInfo: this.manualVerificationInfo,
            callback: this.manualCallback,
            cardType2: this.manualCardType2,
            statementDateStr: this.manualStatementDate,
            dueDateStr: this.manualDueDate,
            transactionDateStr: this.manualTransactionDate,
            transactionAmount: this.manualTransactionAmount,
            approvalCode: this.manualApprovalCode,
            transactionPlan: this.manualTransactionPlan,
            installmentAmount: this.manualInstallmentAmount,
            installmentTerm: this.manualInstallmentTerm,
            conversionInterestRate: this.manualConversionInterest
        })
            .then((res) => {
                if (res && res.success) {
                    this.showToast(FEC_Success_Title, FEC_MSG_IPP_Conversion_Success, CONST.VARIANT_SUCCESS);
                    this.showManualEntry = false;
                    this.navigateToCase();
                } else {
                    this.showToast(FEC_Toast_Error, res?.errorMessage || FEC_MSG_IPP_AddIpp_Default_Failed, CONST.VARIANT_ERROR);
                }
            })
            .catch((err) => {
                this.showToast(FEC_Toast_Error, err?.body?.message || err?.message || FEC_Toast_Error_Generic, CONST.VARIANT_ERROR);
            })
            .finally(() => {
                this.manualSubmitLoading = false;
            });
    }

    formatAmount(val) {
        if (val == null) return STR_EMPTY;
        return new Intl.NumberFormat('vi-VN').format(val);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get hasNoEligibleTransactions() {
        return this.state === FORM_STATE_NONE && !this.isLoading;
    }

    get hasEligibleTransactions() {
        return this.state === FORM_STATE_HAS_DATA && this.transactions.length > 0;
    }

    get showCheckDetailsButton() {
        return this.state === FORM_STATE_HAS_DATA && this.selectedTransactionId;
    }

    get showDetailsSection() {
        return this.details != null && !this.details.errorMessage;
    }

    get showConvertButton() {
        return this.showDetailsSection && this.selectedTenor != null && !this.convertDisabled;
    }

    get detailsInterestDisplay() {
        return this.details && this.details.interestRate != null ? this.details.interestRate + '%' : STR_EMPTY;
    }

    get detailsFeeDisplay() {
        return this.details && this.details.fee != null ? this.formatAmount(this.details.fee) : STR_EMPTY;
    }

    get detailsEmiDisplay() {
        return this.details && this.details.emi != null ? this.formatAmount(this.details.emi) : STR_EMPTY;
    }

    get noEligibleMessage() {
        return FEC_MSG_IPP_No_Eligible_Transactions;
    }
}