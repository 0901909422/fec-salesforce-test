/****************************************************************************************
 * File Name    : fec_IPPConversionRetailForm.js
 * Description  : RC34.01 / RC34.02 – Chuyển đổi IPP: eligible transactions, Check IPP Details, Convert IPP (convertIPP), retry 3.
 ****************************************************************************************/

import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getEligibleTransactions from '@salesforce/apex/FEC_IPPConversionController.getEligibleTransactions';
import loadIppTenorOptions from '@salesforce/apex/FEC_IPPConversionController.loadIppTenorOptions';
import saveCaseIppTerm from '@salesforce/apex/FEC_IPPConversionController.saveCaseIppTerm';
import checkIPPDetails from '@salesforce/apex/FEC_IPPConversionController.checkIPPDetails';
import convertIPP from '@salesforce/apex/FEC_IPPConversionController.convertIPP';
import getConvertActionStatus from '@salesforce/apex/FEC_IPPConversionController.getConvertActionStatus';
import FEC_MSG_IPP_Conversion_Success from '@salesforce/label/c.FEC_MSG_IPP_Conversion_Success';
import FEC_MSG_IPP_Conversion_Fail_Retry from '@salesforce/label/c.FEC_MSG_IPP_Conversion_Fail_Retry';
import FEC_MSG_IPP_Noti_10 from '@salesforce/label/c.FEC_MSG_IPP_Noti_10';
import FEC_MSG_IPP_No_Eligible_Transactions from '@salesforce/label/c.FEC_MSG_IPP_No_Eligible_Transactions';
import FEC_MSG_IPP_Sync_Failed from '@salesforce/label/c.FEC_MSG_IPP_Sync_Failed';
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

const IPP_RETAIL_PAGE_SIZE_OPTIONS = [10, 20];

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
    LBL_TENOR_PLACEHOLDER: '-- Chọn Tenor --',
    LBL_INTEREST: 'Interest',
    LBL_CONVERSION_FEE: 'Conversion Fee',
    LBL_EMI: 'EMI',
    COL_TRX_CODE: 'Transaction Code',
    COL_EFF_DATE: 'Effective Date',
    COL_TRX_PLAN: 'Transaction Plan',
    COL_TRX_AMT: 'Transaction Amount',
    COL_POST_DATE: 'Post Date',
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
    @track tenorSyncError = null;
    @track showTenorSection = false;
    @track ippDetailsLoading = false;
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
        { label: CONST.COL_MERCHANT, fieldName: 'merchant', type: 'text' }
    ];

    lblTenor = CONST.LBL_TENOR;
    lblTenorPlaceholder = CONST.LBL_TENOR_PLACEHOLDER;
    lblInterest = CONST.LBL_INTEREST;
    lblConversionFee = CONST.LBL_CONVERSION_FEE;
    lblEmi = CONST.LBL_EMI;
    lblSpinnerLoading = Loading;
    lblSpinnerDetails = Loading;
    lblSpinnerConverting = CONST.SPIN_CONVERTING;
    lblClose = FEC_Button_Close;

    connectedCallback() {
        this.loadConvertActionStatus();
        if (!this.recordId) {
            return;
        }
        this.loadEligibleTransactions();
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
            return Promise.resolve();
        }
        this.isLoading = true;
        return getEligibleTransactions({ caseId: this.recordId })
            .then((data) => {
                this.transactions = (data || []).map(t => ({
                    ...t,
                    amountDisplay: t.amount != null ? this.formatAmount(t.amount) : STR_EMPTY,
                    effectiveDateStr: formatToDDMMYYYY(t.effectiveDateStr) || t.effectiveDateStr || STR_EMPTY,
                    postingDateStr: formatToDDMMYYYY(t.postingDateStr) || t.postingDateStr || STR_EMPTY
                }));
                const savedTxId = savedId ? String(savedId) : null;
                const savedStillEligible = savedTxId
                    && (this.transactions || []).some((t) => String(t.transactionId) === savedTxId);
                this.selectedTransactionId = savedStillEligible ? savedTxId : null;
                this.details = null;
                this.selectedTenor = null;
                this.tenorBlockReady = false;
                this.showTenorSection = false;
                this.tenorSyncError = null;
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
            this.showTenorSection = false;
            this.tenorSyncError = null;
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
            this.showTenorSection = false;
            this.tenorSyncError = null;
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
        this.loadTenorOptionsFromApi();
    }

    // 2026-06-16 linhdev – Service 38 GetAccountDetails: load Tenor picklist (không auto gọi Service 40)
    loadTenorOptionsFromApi() {
        this.tenorBlockReady = false;
        this.detailsLoading = true;
        this.ippDetailsLoading = false;
        this.details = null;
        this.tenorSyncError = null;
        this.showTenorSection = false;
        this.selectedTenor = null;
        loadIppTenorOptions({ caseId: this.recordId })
            .then((res) => {
                this.applyTenorOptionsResponse(res);
            })
            .catch(() => {
                this.tenorSyncError = FEC_MSG_IPP_Sync_Failed;
                this.showTenorSection = true;
            })
            .finally(() => {
                this.detailsLoading = false;
            });
    }

    // 2026-06-16 linhdev – map response API 38; chỉ pre-select Tenor nếu Case đã lưu FEC_IPP_Term__c
    applyTenorOptionsResponse(res) {
        if (res && res.errorMessage) {
            this.tenorSyncError = res.errorMessage;
            this.showTenorSection = true;
            return;
        }
        this.tenorOptions = (res.tenorOptions || []).map(t => ({ label: String(t), value: String(t) }));
        if (this.tenorOptions.length === 0) {
            this.tenorSyncError = FEC_MSG_IPP_Sync_Failed;
            this.showTenorSection = true;
            return;
        }
        this.showTenorSection = true;
        this.tenorSyncError = null;
        const savedTenor = res.savedTenor != null ? String(res.savedTenor) : null;
        this.selectedTenor = savedTenor && this.tenorOptions.some(o => o.value === savedTenor)
            ? savedTenor
            : null;
        Promise.resolve().then(() => {
            this.tenorBlockReady = true;
        });
        const hasSavedDetails = res.savedInterestRate != null
            && res.savedFee != null
            && res.savedEmi != null
            && savedTenor
            && this.selectedTenor === savedTenor;
        if (hasSavedDetails) {
            this.details = {
                interestRate: res.savedInterestRate,
                fee: res.savedFee,
                emi: res.savedEmi
            };
        } else {
            this.details = null;
        }
    }

    loadIppDetailsForSelectedTenor() {
        if (!this.selectedTransactionId || !this.selectedTenor) {
            return;
        }
        this.ippDetailsLoading = true;
        this.details = null;
        this.tenorSyncError = null;
        const tenorVal = parseInt(this.selectedTenor, 10);
        console.log('[IPPConversionRetailForm] GetIPPDetails – transactionId:', this.selectedTransactionId, 'tenor:', tenorVal, 'caseId:', this.recordId);
        // 2026-06-16 linhdev – lưu FEC_IPP_Term__c trước, sau đó Service 40 GetIPPDetails (tách DML/callout)
        saveCaseIppTerm({ caseId: this.recordId, tenor: tenorVal })
            .then(() => checkIPPDetails({
                caseId: this.recordId,
                transactionId: this.selectedTransactionId,
                tenor: tenorVal
            }))
            .then((res) => {
                if (res && res.errorMessage) {
                    this.tenorSyncError = res.errorMessage;
                    return;
                }
                this.details = res;
            })
            .catch(() => {
                this.tenorSyncError = FEC_MSG_IPP_Sync_Failed;
            })
            .finally(() => {
                this.ippDetailsLoading = false;
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
        if (!this.selectedTenor) {
            this.details = null;
            return;
        }
        // 2026-06-16 linhdev – Service 40 GetIPPDetails chỉ khi user chọn Tenor
        this.loadIppDetailsForSelectedTenor();
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
        return this.showTenorSection;
    }

    get showIppDetailsFields() {
        return this.details != null && !this.details.errorMessage && !this.tenorSyncError;
    }

    get showConvertIppButton() {
        return this.showIppDetailsFields && !this.ippDetailsLoading;
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