import { LightningElement, api, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { loadStyle } from 'lightning/platformResourceLoader';
import COMMON_STYLES from '@salesforce/resourceUrl/FEC_CommonCss';
import checkCustomerEligibility from '@salesforce/apex/FEC_CheckEligibleController.checkCustomerEligibility';

import LBL_LOAN_SECTION from '@salesforce/label/c.FEC_Lbl_CheckEligible_Loan_Section';
import LBL_TOPUP_XSELL_ELIGIBILITY from '@salesforce/label/c.FEC_Lbl_CheckEligible_TopUp_Xsell_Eligibility';
import LBL_TOPUP_XSELL_MIN from '@salesforce/label/c.FEC_Lbl_CheckEligible_TopUp_Xsell_Min';
import LBL_TOPUP_XSELL_MAX from '@salesforce/label/c.FEC_Lbl_CheckEligible_TopUp_Xsell_Max';
import LBL_STATUS_ELIGIBLE from '@salesforce/label/c.FEC_MSG_Status_Eligible';
import LBL_STATUS_NOT_ELIGIBLE from '@salesforce/label/c.FEC_MSG_Status_Not_Eligible';
import LBL_LOAD_ERROR from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import LBL_LOADING from '@salesforce/label/c.FEC_Lbl_Loading';

/** Wire lookup Account/Contract (Customer History) — đồng bộ với cách resolve trên Apex. */
const CASE_WIRE_FIELDS = ['Case.FEC_Account_or_Contract__c'];

export default class FecCheckEligibleLoanSection extends LightningElement {
    @api recordId;

    loanSectionTitle = LBL_LOAN_SECTION;
    lblTopUpXsellEligibility = LBL_TOPUP_XSELL_ELIGIBILITY;
    lblTopUpXsellMin = LBL_TOPUP_XSELL_MIN;
    lblTopUpXsellMax = LBL_TOPUP_XSELL_MAX;
    lblLoadError = LBL_LOAD_ERROR;
    lblLoadingAlt = LBL_LOADING;

    @track isExpanded = true;
    @track isLoading = false;
    @track eligibleData = null;
    @track error = false;
    @track errorMessage = '';
    @track status = '';

    _loadKey = null;

    connectedCallback() {
        loadStyle(this, COMMON_STYLES).catch((e) => {
            console.error('FEC_CommonCss load error', e);
        });
    }

    updatedCallback(changedProps) {
        if (changedProps.has('recordId')) {
            this._loadKey = null;
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: CASE_WIRE_FIELDS })
    wiredCase({ data, error }) {
        this.error = false;
        this.errorMessage = '';
        if (data) {
            this._runLoad();
        } else if (error) {
            console.error('Error loading Case for Check Eligible:', error);
            this.error = true;
            this.errorMessage = this._extractErrorMsg(error);
        }
    }

    _runLoad() {
        if (!this.recordId) {
            return;
        }
        const key = this.recordId;
        if (key === this._loadKey) {
            return;
        }
        this._loadKey = key;
        this.loadEligibility();
    }

    async loadEligibility() {
        this.isLoading = true;
        this.error = false;
        this.errorMessage = '';
        this.eligibleData = null;
        this.status = '';
        try {
            const result = await checkCustomerEligibility({ caseId: this.recordId });
            if (result) {
                this.status = result.Status != null ? String(result.Status) : '';
                this.eligibleData = result.Data || null;
                if (result.errorCode) {
                    this.error = true;
                    this.errorMessage = result.errorMessage || LBL_LOAD_ERROR;
                } else {
                    this.error = false;
                }
            } else {
                this.error = true;
                this.errorMessage = LBL_LOAD_ERROR;
            }
        } catch (err) {
            console.error('checkCustomerEligibility error:', err);
            this.error = true;
            this.errorMessage = this._extractErrorMsg(err);
        } finally {
            this.isLoading = false;
        }
    }

    _extractErrorMsg(err) {
        if (!err) {
            return LBL_LOAD_ERROR;
        }
        if (Array.isArray(err?.body)) {
            return err.body.map((e) => e.message).join(', ');
        }
        if (typeof err?.body?.message === 'string') {
            return err.body.message;
        }
        if (typeof err?.message === 'string') {
            return err.message;
        }
        return LBL_LOAD_ERROR;
    }

    toggleSection() {
        this.isExpanded = !this.isExpanded;
    }

    get iconName() {
        return this.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get placeholderDash() {
        return '-';
    }

    get displayEligibility() {
        if (this.isLoading || this.error) {
            return this.placeholderDash;
        }
        if (this.status === 'true') {
            return LBL_STATUS_ELIGIBLE;
        }
        if (this.status === 'false') {
            return LBL_STATUS_NOT_ELIGIBLE;
        }
        return this.placeholderDash;
    }

    get hasMinNumber() {
        if (this.isLoading || this.error) {
            return false;
        }
        return this._hasNumericValue(this.eligibleData?.MIN_LOAN_AMOUNT_2);
    }

    get minNumberValue() {
        return this._toSafeNumber(this.eligibleData?.MIN_LOAN_AMOUNT_2);
    }

    get hasMaxNumber() {
        if (this.isLoading || this.error) {
            return false;
        }
        return this._hasNumericValue(this.eligibleData?.MAX_LOAN_AMOUNT_2);
    }

    get maxNumberValue() {
        return this._toSafeNumber(this.eligibleData?.MAX_LOAN_AMOUNT_2);
    }

    _hasNumericValue(v) {
        if (v === null || v === undefined) {
            return false;
        }
        const s = String(v).trim();
        if (s === '') {
            return false;
        }
        const n = Number(s);
        return !Number.isNaN(n);
    }

    _toSafeNumber(v) {
        if (v === null || v === undefined) {
            return 0;
        }
        const n = Number(String(v).trim());
        return Number.isNaN(n) ? 0 : n;
    }

    get headerErrorText() {
        if (!this.error) {
            return '';
        }
        return this.errorMessage || this.lblLoadError;
    }
}
