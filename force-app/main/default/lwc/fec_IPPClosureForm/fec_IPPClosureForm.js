/****************************************************************************************
 * File Name    : fec_IPPClosureForm.js
 * Description  : IPP Closure – Case Information: list eligible IPPs, single-select, Noti-11/Noti-12 validation.
 ****************************************************************************************/

import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getEligibleIPPsForClosure from '@salesforce/apex/FEC_IPPClosureController.getEligibleIPPsForClosure';
import saveSelectedIPPToCase from '@salesforce/apex/FEC_IPPClosureController.saveSelectedIPPToCase';
import FEC_MSG_IPP_Closure_Select_One from '@salesforce/label/c.FEC_MSG_IPP_Closure_Select_One';
import FEC_MSG_IPP_Closure_No_Eligible from '@salesforce/label/c.FEC_MSG_IPP_Closure_No_Eligible';
import LBL_LOADING from '@salesforce/label/c.Loading';
import FEC_SPINNER_SAVING from '@salesforce/label/c.FEC_Spinner_Saving';
import FEC_LBL_IPP_Closure_Col_IppRecordNo from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppRecordNo';
import FEC_LBL_IPP_Closure_Col_IppPlan from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppPlan';
import FEC_LBL_IPP_Closure_Col_IppOpenDate from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppOpenDate';
import FEC_LBL_IPP_Closure_Col_IppFirstDueDate from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppFirstDueDate';
import FEC_LBL_IPP_Closure_Col_IppMatureDate from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppMatureDate';
import FEC_LBL_IPP_Closure_Col_IppBalance from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppBalance';
import FEC_LBL_IPP_Closure_Col_IppCurrentBalance from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppCurrentBalance';
import FEC_LBL_IPP_Closure_Col_IppInterestRate from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppInterestRate';
import FEC_LBL_IPP_Closure_Col_IppTerm from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppTerm';
import FEC_LBL_IPP_Closure_Col_IppCurrentTerm from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppCurrentTerm';
import FEC_Success_Title from '@salesforce/label/c.FEC_Success_Title';
import FEC_Toast_Error from '@salesforce/label/c.FEC_Toast_Error';
import FEC_Toast_Save_Success from '@salesforce/label/c.FEC_Toast_Save_Success';
import FEC_Toast_Save_Error from '@salesforce/label/c.FEC_Toast_Save_Error';
import FEC_Toast_Error_Generic from '@salesforce/label/c.FEC_Toast_Error_Generic';
import FEC_Toast_Validation_Title from '@salesforce/label/c.FEC_Toast_Validation_Title';
import { formatToDDMMYYYY } from 'c/fec_CommonUtils';
import { STR_EMPTY } from 'c/fec_CommonConst';

const IPP_SAVE_FAILED = 'IPP_SAVE_FAILED';

export default class Fec_IPPClosureForm extends LightningElement {

    @api recordId;

    @api isEdit;

    get isReadOnly() {
        return this.isEdit === false;
    }

    get ippTableLocked() {
        return this.isReadOnly || this.savedIppToCloseOnCase != null;
    }

    get datatableMaxRowSelection() {
        return this.ippTableLocked ? 0 : 1;
    }

    @track ippList = [];
    @track selectedIppId = null;
    @track savedIppToCloseOnCase = null;
    @track isLoading = false;
    @track completeLoading = false;
    @track showNoti11 = false;
    @track showNoEligibleWarning = false;
    @track loadSucceeded = false;

    labelLoading = LBL_LOADING;
    labelSaving = FEC_SPINNER_SAVING;

    ippColumns = [
        { label: FEC_LBL_IPP_Closure_Col_IppRecordNo, fieldName: 'ippRecordNo', type: 'text', sortable: true },
        { label: FEC_LBL_IPP_Closure_Col_IppPlan, fieldName: 'ippPlan', type: 'text' },
        { label: FEC_LBL_IPP_Closure_Col_IppOpenDate, fieldName: 'ippOpenDateStr', type: 'text' },
        { label: FEC_LBL_IPP_Closure_Col_IppFirstDueDate, fieldName: 'ippFirstDueDateStr', type: 'text' },
        { label: FEC_LBL_IPP_Closure_Col_IppMatureDate, fieldName: 'ippMatureDateStr', type: 'text' },
        { label: FEC_LBL_IPP_Closure_Col_IppBalance, fieldName: 'ippBalanceDisplay', type: 'text', cellAttributes: { alignment: 'right' } },
        { label: FEC_LBL_IPP_Closure_Col_IppCurrentBalance, fieldName: 'ippCurrentBalanceDisplay', type: 'text', cellAttributes: { alignment: 'right' } },
        { label: FEC_LBL_IPP_Closure_Col_IppInterestRate, fieldName: 'ippInterestRateDisplay', type: 'text', cellAttributes: { alignment: 'right' } },
        { label: FEC_LBL_IPP_Closure_Col_IppTerm, fieldName: 'ippTermDisplay', type: 'text' },
        { label: FEC_LBL_IPP_Closure_Col_IppCurrentTerm, fieldName: 'ippCurrentTermDisplay', type: 'text' }
    ];

    connectedCallback() {
        this.loadEligibleIPPs();
    }

    loadEligibleIPPs() {
        if (!this.recordId) {
            this.loadSucceeded = false;
            this.showNoEligibleWarning = false;
            return;
        }
        this.isLoading = true;
        this.ippList = [];
        this.selectedIppId = null;
        this.savedIppToCloseOnCase = null;
        this.showNoti11 = false;
        this.loadSucceeded = false;
        this.showNoEligibleWarning = false;
        getEligibleIPPsForClosure({ caseId: this.recordId })
            .then((data) => {
                const rawRows = (data && data.rows) ? data.rows : [];
                const rows = rawRows.map(row => this.mapRowToDisplay(row));
                this.ippList = rows;
                this.showNoEligibleWarning = rows.length === 0;
                this.loadSucceeded = true;
                this.savedIppToCloseOnCase = data && data.savedIppToCloseOnCase ? data.savedIppToCloseOnCase : null;
                if (this.savedIppToCloseOnCase && rows.some((r) => r.Id === this.savedIppToCloseOnCase)) {
                    this.selectedIppId = this.savedIppToCloseOnCase;
                }
                const hasEligibleRows = rows.length > 0;
                this.dispatchEvent(new CustomEvent('fecippclosureload', { bubbles: true, composed: true, detail: {
                    noEligibleForClosure: this.showNoEligibleWarning,
                    hasEligibleRows: hasEligibleRows,
                    savedIppToCloseOnCase: this.savedIppToCloseOnCase
                } }));
            })
            .catch((err) => {
                this.loadSucceeded = false;
                this.showNoEligibleWarning = false;
                this.showToast(FEC_Toast_Error, err?.body?.message || err?.message || FEC_Toast_Error_Generic, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    mapRowToDisplay(row) {
        const openDateStr = row.ippOpenDate ? formatToDDMMYYYY(String(row.ippOpenDate)) : STR_EMPTY;
        const firstDueStr = row.ippFirstDueDate ? formatToDDMMYYYY(String(row.ippFirstDueDate)) : STR_EMPTY;
        const matureStr = row.ippMatureDate ? formatToDDMMYYYY(String(row.ippMatureDate)) : STR_EMPTY;
        const termDisplay = row.ippTerm != null ? row.ippTerm + ' months' : STR_EMPTY;
        const interestDisplay = row.ippInterestRate != null ? row.ippInterestRate + '%' : STR_EMPTY;
        return {
            Id: row.Id,
            ippRecordNo: row.ippRecordNo || STR_EMPTY,
            ippPlan: row.ippPlan || STR_EMPTY,
            ippOpenDateStr: openDateStr,
            ippFirstDueDateStr: firstDueStr,
            ippMatureDateStr: matureStr,
            ippBalanceDisplay: this.formatCurrency(row.ippBalance),
            ippCurrentBalanceDisplay: this.formatCurrency(row.ippCurrentBalance),
            ippInterestRateDisplay: interestDisplay,
            ippTermDisplay: termDisplay,
            ippCurrentTermDisplay: row.ippCurrentTerm != null ? String(row.ippCurrentTerm) : STR_EMPTY
        };
    }

    formatCurrency(val) {
        if (val == null) return STR_EMPTY;
        return 'VND ' + new Intl.NumberFormat('vi-VN').format(val);
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows || [];
        const hasSelection = selectedRows.length === 1;
        this.selectedIppId = hasSelection ? selectedRows[0].Id : null;
        this.showNoti11 = false;
        this.dispatchEvent(new CustomEvent('fecippclosureselection', { bubbles: true, composed: true, detail: { hasSelection: hasSelection } }));
    }

    /** Submit Case: bắt buộc chọn một dòng khi bảng có IPP đủ điều kiện. */
    @api validateSelectionRequiredForSubmit() {
        if (this.ippTableLocked) {
            return true;
        }
        if (this.isLoading) {
            this.showToast(FEC_Toast_Validation_Title, labelLoading, 'error');
            return false;
        }
        if (!this.loadSucceeded || !this.ippList || this.ippList.length === 0) {
            return true;
        }
        if (this.selectedIppId) {
            return true;
        }
        this.showNoti11 = true;
        this.showToast(FEC_Toast_Validation_Title, FEC_MSG_IPP_Closure_Select_One, 'error');
        return false;
    }

    /** Parent Save & Close / Submit: lưu IPP đã chọn nếu có; bỏ qua khi không có dòng hoặc chưa chọn. */
    @api saveSelectedIPPIfApplicable() {
        if (this.ippTableLocked) {
            return Promise.resolve();
        }
        const hasRows = this.ippList && this.ippList.length > 0;
        if (!hasRows || !this.selectedIppId) {
            return Promise.resolve();
        }
        return this.persistSelectedIPP();
    }

    async persistSelectedIPP() {
        this.completeLoading = true;
        try {
            const success = await saveSelectedIPPToCase({
                caseId: this.recordId,
                ippId: this.selectedIppId
            });
            if (success) {
                this.showToast(FEC_Success_Title, FEC_Toast_Save_Success, 'success');
                return;
            }
            this.showToast(FEC_Toast_Error, FEC_Toast_Save_Error, 'error');
            throw new Error(IPP_SAVE_FAILED);
        } catch (err) {
            if (err?.message !== IPP_SAVE_FAILED) {
                this.showToast(FEC_Toast_Error, err?.body?.message || err?.message || FEC_Toast_Error_Generic, 'error');
            }
            throw err;
        } finally {
            this.completeLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get showIppTableSection() {
        return this.recordId && !this.isLoading && this.loadSucceeded;
    }

    get noti11Message() {
        return FEC_MSG_IPP_Closure_Select_One;
    }

    get noti12Message() {
        return FEC_MSG_IPP_Closure_No_Eligible;
    }
}