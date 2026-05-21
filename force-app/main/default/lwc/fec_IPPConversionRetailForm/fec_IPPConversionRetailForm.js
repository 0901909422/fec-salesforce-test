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
import getConvertActionStatus from '@salesforce/apex/FEC_IPPConversionController.getConvertActionStatus';
import FEC_MSG_IPP_Conversion_Success from '@salesforce/label/c.FEC_MSG_IPP_Conversion_Success';
import FEC_MSG_IPP_Conversion_Fail_Retry from '@salesforce/label/c.FEC_MSG_IPP_Conversion_Fail_Retry';
import FEC_MSG_IPP_Noti_10 from '@salesforce/label/c.FEC_MSG_IPP_Noti_10';
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
import FEC_BCH_PageSize from '@salesforce/label/c.FEC_BCH_PageSize';
import FEC_Go_to_page_label from '@salesforce/label/c.FEC_Go_to_page_label';
import FEC_Go_Button_Label from '@salesforce/label/c.FEC_Go_Button_Label';
import FEC_Btn_Previous from '@salesforce/label/c.FEC_Btn_Previous';
import FEC_Btn_Next from '@salesforce/label/c.FEC_Btn_Next';
import { STR_EMPTY, FORM_STATE_LOADING, FORM_STATE_NONE, FORM_STATE_HAS_DATA } from 'c/fec_CommonConst';
import { formatToDDMMYYYY } from 'c/fec_CommonUtils';

const IPP_RETAIL_PAGE_SIZE_OPTIONS = [10, 20, 30, 40, 50];

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

    @api isEdit;

    get isReadOnly() {
        return this.isEdit === false;
    }

    get convertButtonDisabled() {
        return this.isReadOnly || this.convertLoading || this.convertSucceeded || this.convertDisabled;
    }

    get datatableMaxRowSelection() {
        return this.isReadOnly ? 0 : 1;
    }

    @track transactions = [];
    @track pagedTransactions = [];
    @track currentPage = 1;
    @track tableKey = 0;
    @track selectedTransactionId = null;
    @track details = null;
    @track tenorOptions = [];
    @track selectedTenor = null;
    @track tenorBlockReady = false;
    @track isLoading = false;
    @track detailsLoading = false;
    @track convertLoading = false;
    @track convertDisabled = false;
    @track convertSucceeded = false;
    @track showNoti08 = false;
    @track showNoti09 = false;
    @track showNoti10 = false;
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

    pageSize = 20;

    goToPageValue = 1;

    paginationLabels = {
        pageSizeLabel: FEC_BCH_PageSize,
        goToPageLabel: FEC_Go_to_page_label,
        goBtnLabel: FEC_Go_Button_Label,
        prevLabel: FEC_Btn_Previous,
        nextLabel: FEC_Btn_Next
    };

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
        this.loadConvertActionStatus();
    }

    loadConvertActionStatus() {
        if (!this.recordId) {
            return;
        }
        getConvertActionStatus({ caseId: this.recordId })
            .then((res) => {
                const actionCount = res?.actionCount != null ? Number(res.actionCount) : null;
                if (actionCount != null) {
                    this.retryCount = actionCount;
                }
                this.convertDisabled = !(res?.canConvert !== false);
                if (actionCount != null && Number(actionCount) === -1) {
                    this.convertSucceeded = true;
                    this.showNoti08 = true;
                } else if (actionCount != null && actionCount >= CONST.MAX_RETRY) {
                    this.showNoti10 = true;
                }
            })
            .catch(() => {
            });
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
                this.selectedTransactionId = null;
                this.details = null;
                this.selectedTenor = null;
                this.tenorBlockReady = false;
                if (this.transactions.length === 0) {
                    this.state = FORM_STATE_NONE;
                } else {
                    this.state = FORM_STATE_HAS_DATA;
                }
                this.currentPage = 1;
                this.goToPageValue = 1;
                this._rebuildPagedTransactions();
                this._bumpTableKey();
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
        const pageIds = new Set(
            (this.pagedTransactions || []).map((t) => String(t.transactionId))
        );
        if (selectedRows.length === 1) {
            this.selectedTransactionId = selectedRows[0].transactionId;
            this.details = null;
            this.selectedTenor = null;
            this.tenorBlockReady = false;
            return;
        }
        if (selectedRows.length === 0) {
            if (
                this.selectedTransactionId &&
                !pageIds.has(String(this.selectedTransactionId))
            ) {
                return;
            }
            this.selectedTransactionId = null;
            this.details = null;
            this.selectedTenor = null;
            this.tenorBlockReady = false;
        }
    }

    get selectedRowIds() {
        return this.selectedTransactionId ? [String(this.selectedTransactionId)] : [];
    }

    get datatableRenderKey() {
        return 'ipp-retail-tx-' + String(this.tableKey || 0);
    }

    get totalPages() {
        const len = (this.transactions || []).length;
        if (!len) {
            return 1;
        }
        return Math.ceil(len / this.pageSize);
    }

    get showPagination() {
        return (this.transactions || []).length > 0;
    }

    get pageSizeStr() {
        return String(this.pageSize);
    }

    get pageSizeOptions() {
        return IPP_RETAIL_PAGE_SIZE_OPTIONS.map((size) => ({
            label: String(size),
            value: String(size)
        }));
    }

    get disablePaginationPrevPage() {
        return this.currentPage <= 1;
    }

    get disablePaginationNextPage() {
        return this.currentPage >= this.totalPages;
    }

    _rebuildPagedTransactions() {
        const all = this.transactions || [];
        if (!all.length) {
            this.pagedTransactions = [];
            return;
        }
        const tp = Math.ceil(all.length / this.pageSize);
        const safePage = Math.min(Math.max(1, this.currentPage), Math.max(1, tp));
        if (this.currentPage !== safePage) {
            this.currentPage = safePage;
        }
        const start = (this.currentPage - 1) * this.pageSize;
        this.pagedTransactions = all.slice(start, start + this.pageSize);
        this.goToPageValue = this.currentPage;
    }

    _bumpTableKey() {
        this.tableKey = (this.tableKey || 0) + 1;
    }

    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.detail.value, 10);
        this.currentPage = 1;
        this.goToPageValue = 1;
        this._rebuildPagedTransactions();
        this._bumpTableKey();
    }

    handlePrevPage() {
        if (this.disablePaginationPrevPage) {
            return;
        }
        this.currentPage -= 1;
        this.goToPageValue = this.currentPage;
        this._rebuildPagedTransactions();
        this._bumpTableKey();
    }

    handleNextPage() {
        if (this.disablePaginationNextPage) {
            return;
        }
        this.currentPage += 1;
        this.goToPageValue = this.currentPage;
        this._rebuildPagedTransactions();
        this._bumpTableKey();
    }

    handleGoToPageInput(event) {
        this.goToPageValue = parseInt(event.detail.value, 10);
    }

    handleGoToPage() {
        let targetPage = this.goToPageValue;
        if (!targetPage || isNaN(targetPage)) {
            targetPage = 1;
        }
        if (targetPage < 1) {
            targetPage = 1;
        }
        if (targetPage > this.totalPages) {
            targetPage = this.totalPages;
        }
        if (this.currentPage === targetPage) {
            return;
        }
        this.currentPage = targetPage;
        this.goToPageValue = targetPage;
        this._rebuildPagedTransactions();
        this._bumpTableKey();
    }

    handleCheckIPPDetails() {
        if (this.isReadOnly) {
            return;
        }
        if (!this.selectedTransactionId) {
            this.showToast(FEC_Toast_Warning, FEC_Toast_Validation_Message, CONST.VARIANT_WARNING);
            return;
        }
        this.tenorBlockReady = false;
        this.detailsLoading = true;
        this.details = null;
        checkIPPDetails({ caseId: this.recordId, transactionId: this.selectedTransactionId })
            .then((res) => {
                if (res && res.errorMessage) {
                    this.showToast(FEC_Toast_Error, res.errorMessage, CONST.VARIANT_ERROR);
                    return;
                }
                this.tenorBlockReady = false;
                this.details = res;
                this.tenorOptions = (res.tenorOptions || []).map(t => ({ label: String(t), value: String(t) }));
                this.selectedTenor = this.tenorOptions.length > 0 ? this.tenorOptions[0].value : null;
                Promise.resolve().then(() => {
                    this.tenorBlockReady = true;
                });
            })
            .catch((err) => {
                this.showToast(FEC_Toast_Error, err?.body?.message || err?.message || FEC_Toast_Error_Generic, CONST.VARIANT_ERROR);
            })
            .finally(() => {
                this.detailsLoading = false;
            });
    }

    handleConvertIPP() {
        if (this.isReadOnly) {
            return;
        }
        if (!this.selectedTransactionId || !this.selectedTenor) {
            this.showToast(FEC_Toast_Warning, FEC_Toast_Validation_Message, CONST.VARIANT_WARNING);
            return;
        }
        this.showConfirmModal = true;
    }

    handleConfirmYes() {
        this.showConfirmModal = false;
        if (this.isReadOnly) {
            return;
        }
        this.doConvert();
    }

    handleConfirmNo() {
        this.showConfirmModal = false;
    }

    doConvert() {
        if (this.isReadOnly) {
            return;
        }
        this.convertLoading = true;
        this.clearConvertMessages();
        convertIPP({
            caseId: this.recordId,
            transactionId: this.selectedTransactionId,
            tenor: this.selectedTenor != null && this.selectedTenor !== STR_EMPTY
                ? parseInt(this.selectedTenor, 10)
                : null
        })
            .then((res) => {
                if (res && res.success) {
                    this.convertSucceeded = true;
                    this.convertDisabled = true;
                    this.showNoti08 = true;
                    this.navigateToCase();
                } else {
                    const actionCount = res?.actionCount != null ? Number(res.actionCount) : null;
                    this.retryCount = actionCount != null ? actionCount : (this.retryCount + 1);
                    if (res?.maxRetriesExceeded === true || this.retryCount >= CONST.MAX_RETRY) {
                        this.convertDisabled = true;
                        this.showNoti10 = true;
                        window.setTimeout(() => {
                            this.navigateToCase();
                        }, 2000);
                    } else {
                        this.showNoti09 = true;
                    }
                }
            })
            .catch((err) => {
                this.retryCount += 1;
                if (this.retryCount >= CONST.MAX_RETRY) {
                    this.convertDisabled = true;
                    this.showNoti10 = true;
                    window.setTimeout(() => {
                        this.navigateToCase();
                    }, 2000);
                } else {
                    this.showNoti09 = true;
                }
            })
            .finally(() => {
                this.convertLoading = false;
            });
    }

    handleTenorChange(event) {
        if (this.isReadOnly) {
            return;
        }
        const v = event.detail.value;
        this.selectedTenor = v != null && v !== STR_EMPTY ? String(v) : null;
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
        if (this.isReadOnly) {
            return;
        }
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
        if (this.isReadOnly) {
            return;
        }
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
                    this.convertSucceeded = true;
                    this.convertDisabled = true;
                    this.showNoti08 = true;
                    this.showManualEntry = false;
                    this.navigateToCase();
                } else {
                    const actionCount = res?.actionCount != null ? Number(res.actionCount) : null;
                    if (actionCount != null) {
                        this.retryCount = actionCount;
                    }
                    if (res?.maxRetriesExceeded === true || (actionCount != null && actionCount >= CONST.MAX_RETRY)) {
                        this.convertDisabled = true;
                        this.showNoti10 = true;
                        this.showManualEntry = false;
                        window.setTimeout(() => {
                            this.navigateToCase();
                        }, 2000);
                    } else {
                        this.showNoti09 = true;
                    }
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

    clearConvertMessages() {
        this.showNoti08 = false;
        this.showNoti09 = false;
        this.showNoti10 = false;
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

    get showNoti09BelowButton() {
        return this.showNoti09 && !this.showNoti10;
    }

    get showNoti10BelowButton() {
        return this.showNoti10;
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

    get noti08Message() {
        return FEC_MSG_IPP_Conversion_Success;
    }

    get noti09Message() {
        return FEC_MSG_IPP_Conversion_Fail_Retry;
    }

    get noti10Message() {
        return FEC_MSG_IPP_Noti_10;
    }
}