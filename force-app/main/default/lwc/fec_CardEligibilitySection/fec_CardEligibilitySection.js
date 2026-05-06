/***************************************************************************************
 * File Name    : fec_CardEligibilitySection.js
 * Author       : Antigravity
 * Date         : 2026-04-15
 * Description  : LWC controller for Card Eligibility Section.
 *                - Top-up/ E-voucher Eligibility  → API CheckAccountEligibility
 *                - Fast Cash/ IPP Eligibility      → API CheckEligibility (SOAP)
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
 * 1.0      2026-04-15     Antigravity         Create
 ***************************************************************************************/
import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import { refreshApex } from '@salesforce/apex';
import COMMON_STYLES from '@salesforce/resourceUrl/FEC_CommonCss';

import LBL_CARD_SECTION from '@salesforce/label/c.FEC_CardEligibility_Section_Title';
import LBL_BTN_TOPUP from '@salesforce/label/c.FEC_CardEligibility_Btn_TopUp';
import LBL_BTN_IPP from '@salesforce/label/c.FEC_CardEligibility_Btn_IPP';
import LBL_AVAIL_CREDIT from '@salesforce/label/c.FEC_CardEligibility_Lbl_Available_Credit_Limit';
import LBL_REASON from '@salesforce/label/c.FEC_CardEligibility_Lbl_Reason';
import LBL_FAST_CASH_STATUS from '@salesforce/label/c.FEC_CardEligibility_Lbl_Fast_Cash_Status';
import LBL_IPP_STATUS from '@salesforce/label/c.FEC_CardEligibility_Lbl_IPP_Status';
import LBL_LIMIT from '@salesforce/label/c.FEC_CardEligibility_Lbl_Limit';
import LBL_ERROR_CODE from '@salesforce/label/c.FEC_CardEligibility_Lbl_Error_Code';
import LBL_DESCRIPTION from '@salesforce/label/c.FEC_CardEligibility_Lbl_Description';
import LBL_LOADING from '@salesforce/label/c.FEC_Lbl_Loading';
import LBL_TOAST_SUCCESS from '@salesforce/label/c.FEC_Toast_Success';
import LBL_TOAST_ERROR from '@salesforce/label/c.FEC_Toast_Error';
import LBL_TOAST_WARNING from '@salesforce/label/c.FEC_Toast_Warning';
import LBL_TOPUP_SUCCESS from '@salesforce/label/c.FEC_CardEligibility_TopUp_Load_Success';
import LBL_IPP_SUCCESS from '@salesforce/label/c.FEC_CardEligibility_IPP_Load_Success';
import LBL_NO_ACCOUNT from '@salesforce/label/c.FEC_CardEligibility_No_Account_Warning';
import LBL_REQ_FAILED_HTTP from '@salesforce/label/c.FEC_CardEligibility_Request_Failed_Http';
import LBL_REQ_FAILED_UNKNOWN from '@salesforce/label/c.FEC_CardEligibility_Request_Failed_Http_Unknown';
import LBL_UNKNOWN_ERR from '@salesforce/label/c.FEC_CardEligibility_Unknown_Error';
import LBL_UNEXPECTED_ERR from '@salesforce/label/c.FEC_CardEligibility_Unexpected_Error';
import COL_TENURE from '@salesforce/label/c.FEC_CardEligibility_IPP_Col_Tenure';
import COL_RATE from '@salesforce/label/c.FEC_CardEligibility_IPP_Col_Rate';
import COL_REG_RATE from '@salesforce/label/c.FEC_CardEligibility_IPP_Col_Registration_Rate';
import COL_MONTHLY from '@salesforce/label/c.FEC_CardEligibility_IPP_Col_Monthly_Installment';
import COL_CONV_FEE from '@salesforce/label/c.FEC_CardEligibility_IPP_Col_Conversion_Fee';

// Apex methods
import checkTopUpEligibility from '@salesforce/apex/FEC_CardEligibilityController.checkTopUpEligibility';
import checkIPPEligibility   from '@salesforce/apex/FEC_CardEligibilityController.checkIPPEligibility';
import resolveAccountNumberFromCase from '@salesforce/apex/FEC_CardEligibilityController.resolveAccountNumberFromCase';
import loadCardEligibilityFromCustomerHistory from '@salesforce/apex/FEC_CardEligibilityController.loadCardEligibilityFromCustomerHistory';

// Column config for IPP Eligibility table (labels from Custom Labels)
const IPP_COLUMNS = [
    { label: COL_TENURE, fieldName: 'tenure', type: 'text', sortable: true, cellAlign: 'center', width: '100px' },
    { label: COL_RATE, fieldName: 'rate', type: 'text', sortable: true, cellAlign: 'right', width: '100px' },
    { label: COL_REG_RATE, fieldName: 'registrationRate', type: 'text', sortable: false, cellAlign: 'right', width: '150px' },
    {
        label: COL_MONTHLY,
        fieldName: 'monthlyInstallment',
        type: 'currency',
        sortable: false,
        cellAlign: 'right',
        width: '175px',
        typeAttributes: { maximumFractionDigits: 0, currencyDisplayAs: 'code' }
    },
    {
        label: COL_CONV_FEE,
        fieldName: 'conversionFee',
        type: 'currency',
        sortable: false,
        cellAlign: 'right',
        width: '150px',
        typeAttributes: { maximumFractionDigits: 0, currencyDisplayAs: 'code' }
    }
];

export default class Fec_CardEligibilitySection extends LightningElement {

    cardSectionTitle = LBL_CARD_SECTION;
    topUpBtnLabel = LBL_BTN_TOPUP;
    ippBtnLabel = LBL_BTN_IPP;
    lblAvailableCreditLimit = LBL_AVAIL_CREDIT;
    lblReason = LBL_REASON;
    lblFastCashStatus = LBL_FAST_CASH_STATUS;
    lblIppStatus = LBL_IPP_STATUS;
    lblLimit = LBL_LIMIT;
    lblErrorCode = LBL_ERROR_CODE;
    lblDescription = LBL_DESCRIPTION;
    lblLoadingAlt = LBL_LOADING;

    // =========================================================================
    // PUBLIC API
    // =========================================================================
    @api recordId;

    // =========================================================================
    // PRIVATE STATE
    // =========================================================================
    @track isExpanded   = true;
    @track topUpResult  = null;
    @track ippResult    = null;

    isTopUpLoading = false;
    isIPPLoading   = false;

    topUpCallDone = false;
    ippCallDone   = false;

    /** NONE | SUCCESS | ERROR — giống syncStatus trên fec_CommonRecordDetailSection (Main Info) */
    @track topUpSyncStatus = 'NONE';
    @track ippSyncStatus = 'NONE';

    ippColumns  = IPP_COLUMNS;
    accountNumber = null;

    /** Tham chiếu wire để refreshApex sau khi lưu DB */
    _wiredCardEligibility;

    connectedCallback() {
        loadStyle(this, COMMON_STYLES).catch((e) => {
            console.error('[CardEligibility] FEC_CommonCss load error', e);
        });
    }

    /**
     * Khi đổi Case (recordId): xóa state; wire loadCardEligibility sẽ nạp lại từ DB.
     */
    updatedCallback(changedProps) {
        if (!changedProps.has('recordId')) {
            return;
        }
        if (this.recordId == null) {
            this._clearEligibilityDisplay();
            return;
        }
        const prevId = changedProps.get('recordId');
        if (prevId != null && prevId !== this.recordId) {
            this._resetEligibilityStateForNewAccount();
        }
    }

    // =========================================================================
    // WIRE: snapshot Card eligibility từ CH (Case.FEC_Account_or_Contract__c)
    // =========================================================================
    @wire(loadCardEligibilityFromCustomerHistory, { caseId: '$recordId' })
    wiredCardEligibility(value) {
        this._wiredCardEligibility = value;
        const { data, error } = value;
        if (error) {
            console.error('[CardEligibility] loadCardEligibilityFromCustomerHistory:', JSON.stringify(error));
            return;
        }
        if (data !== undefined) {
            this._applyBundleFromDatabase(data);
        }
    }

    // =========================================================================
    // WIRE: Account number from Case + Customer History (Apex; supports both CH lookups on Case)
    // =========================================================================
    @wire(resolveAccountNumberFromCase, { caseId: '$recordId' })
    wiredAccountNumber({ error, data }) {
        const prevAcct = this.accountNumber;

        if (error) {
            this.accountNumber = null;
            console.error('[CardEligibility] resolveAccountNumberFromCase:', JSON.stringify(error));
            this._clearEligibilityDisplay();
            return;
        }

        let nextAcct = null;
        if (data != null && String(data).trim() !== '') {
            nextAcct = String(data).trim();
        }

        if (prevAcct && nextAcct && prevAcct !== nextAcct) {
            this._resetEligibilityStateForNewAccount();
        }

        this.accountNumber = nextAcct;

        if (!this.accountNumber && this._wiredCardEligibility) {
            refreshApex(this._wiredCardEligibility);
            return;
        }

        if (prevAcct && nextAcct && prevAcct !== nextAcct && this._wiredCardEligibility) {
            this._resetEligibilityStateForNewAccount();
            refreshApex(this._wiredCardEligibility);
        }
    }

    // =========================================================================
    // COMPUTED PROPERTIES
    // =========================================================================
    get sectionIconName() {
        return this.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get topUpShowSyncSuccess() {
        return this.topUpSyncStatus === 'SUCCESS';
    }

    get topUpShowSyncError() {
        return this.topUpSyncStatus === 'ERROR';
    }

    get ippShowSyncSuccess() {
        return this.ippSyncStatus === 'SUCCESS';
    }

    get ippShowSyncError() {
        return this.ippSyncStatus === 'ERROR';
    }

    get showIPPTable() {
        return (
            this.ippResult &&
            this.ippResult.ippStatus === 'Eligible' &&
            Array.isArray(this.ippResult.tenorList) &&
            this.ippResult.tenorList.length > 0
        );
    }

    /**
     * Flatten tenorList for the paging component
     * Adds a stable 'id' key required by lightning-datatable internals
     */
    get ippTenorData() {
        if (!this.ippResult || !this.ippResult.tenorList) return [];
        return this.ippResult.tenorList.map((row, idx) => ({
            id:                 row.id || idx + 1,
            tenure:             row.tenure,
            rate:               row.rate,
            registrationRate:   row.registrationRate || '—',
            monthlyInstallment: row.monthlyInstallment,
            conversionFee:      row.conversionFee
        }));
    }

    // =========================================================================
    // EVENT HANDLERS
    // =========================================================================

    /** Toggle section open / closed */
    toggleSection() {
        this.isExpanded = !this.isExpanded;
    }

    /**
     * Button: Top-up / E-voucher Eligibility
     * Triggers CheckAccountEligibility API
     */
    async handleTopUpClick() {
        if (!this._validateAccountNumber()) return;

        this.isTopUpLoading = true;
        this.topUpSyncStatus = 'NONE';

        try {
            const result = await checkTopUpEligibility({
                caseId: this.recordId,
                accountNumber: this.accountNumber
            });

            this.topUpResult = result;
            this.topUpCallDone = true;

            const httpOk = this._isHttp200Success(result?.httpStatus);

            if (result && httpOk) {
                this.topUpSyncStatus = 'SUCCESS';
                this._showToast(LBL_TOAST_SUCCESS, LBL_TOPUP_SUCCESS, 'success');
            } else if (result) {
                this.topUpSyncStatus = 'ERROR';
                if (!httpOk) {
                    const msg =
                        result.errorMessage || this._httpFailureMessage(result.httpStatus);
                    this._showToast(LBL_TOAST_ERROR, msg, 'error');
                }
            }
        } catch (err) {
            console.error('[CardEligibility] Top-up API error:', JSON.stringify(err));
            this.topUpSyncStatus = 'ERROR';
            this._showToast(LBL_TOAST_ERROR, this._extractErrorMsg(err), 'error');
        } finally {
            this.isTopUpLoading = false;
        }
    }

    /**
     * Button: Fast Cash / IPP Eligibility
     * Triggers CheckEligibility SOAP API
     */
    async handleIPPClick() {
        if (!this._validateAccountNumber()) return;

        this.isIPPLoading = true;
        this.ippSyncStatus = 'NONE';

        try {
            const result = await checkIPPEligibility({
                caseId: this.recordId,
                accountNumber: this.accountNumber
            });

            this.ippResult = result;
            this.ippCallDone = true;

            const httpOk = this._isHttp200Success(result?.httpStatus);

            if (result && httpOk) {
                this.ippSyncStatus = 'SUCCESS';
                this._showToast(LBL_TOAST_SUCCESS, LBL_IPP_SUCCESS, 'success');
            } else if (result) {
                this.ippSyncStatus = 'ERROR';
                if (!httpOk) {
                    const msg =
                        result.errorMessage || this._httpFailureMessage(result.httpStatus);
                    this._showToast(LBL_TOAST_ERROR, msg, 'error');
                }
            }
        } catch (err) {
            console.error('[CardEligibility] IPP API error:', JSON.stringify(err));
            this.ippSyncStatus = 'ERROR';
            this._showToast(LBL_TOAST_ERROR, this._extractErrorMsg(err), 'error');
        } finally {
            this.isIPPLoading = false;
        }
    }

    // =========================================================================
    // PRIVATE HELPERS
    // =========================================================================

    /** Transport success: HTTP 200 only (SOAP/business flags may differ). */
    _isHttp200Success(httpStatus) {
        return Number(httpStatus) === 200;
    }

    _resetEligibilityStateForNewAccount() {
        this.topUpResult = null;
        this.ippResult = null;
        this.topUpCallDone = false;
        this.ippCallDone = false;
        this.topUpSyncStatus = 'NONE';
        this.ippSyncStatus = 'NONE';
    }

    _clearEligibilityDisplay() {
        this.topUpResult = null;
        this.ippResult = null;
        this.topUpCallDone = false;
        this.ippCallDone = false;
        this.topUpSyncStatus = 'NONE';
        this.ippSyncStatus = 'NONE';
    }

    /**
     * Ánh xạ bundle từ Apex (đọc CH) lên state + icon sync.
     */
    _applyBundleFromDatabase(bundle) {
        if (!bundle) {
            return;
        }
        this.topUpResult = bundle.topUpResult ?? null;
        this.ippResult = bundle.ippResult ?? null;
        this.topUpCallDone = !!this.topUpResult;
        this.ippCallDone = !!this.ippResult;
        // Chỉ SUCCESS/ERROR sau khi bấm nút (API); dữ liệu load từ DB không hiện icon sync
        this.topUpSyncStatus = 'NONE';
        this.ippSyncStatus = 'NONE';
    }

    /**
     * Validate that account number is present before calling API.
     * @returns {boolean} true if valid, false otherwise
     */
    _validateAccountNumber() {
        if (!this.accountNumber) {
            this._showToast(LBL_TOAST_WARNING, LBL_NO_ACCOUNT, 'warning');
            return false;
        }
        return true;
    }

    /** Show SLDS toast notification */
    _showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }

    /** Extract readable error message from LWC/Apex error object */
    _extractErrorMsg(error) {
        if (!error) return LBL_UNKNOWN_ERR;
        if (Array.isArray(error?.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        if (typeof error?.body?.message === 'string') {
            return error.body.message;
        }
        if (typeof error?.message === 'string') {
            return error.message;
        }
        return LBL_UNEXPECTED_ERR;
    }

    _httpFailureMessage(httpStatus) {
        if (httpStatus === null || httpStatus === undefined) {
            return LBL_REQ_FAILED_UNKNOWN;
        }
        return LBL_REQ_FAILED_HTTP.replace('{0}', String(httpStatus));
    }
}
