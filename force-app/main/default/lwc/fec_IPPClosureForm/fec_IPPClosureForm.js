/****************************************************************************************
 * File Name    : fec_IPPClosureForm.js
 * Description  : IPP Closure – Case Information: list eligible IPPs, single-select, Noti-11/Noti-12 validation.
 ****************************************************************************************/

import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getEligibleIPPsForClosure from '@salesforce/apex/FEC_IPPClosureController.getEligibleIPPsForClosure';
import saveSelectedIPPToCase from '@salesforce/apex/FEC_IPPClosureController.saveSelectedIPPToCase';
import FEC_MSG_IPP_Closure_Select_One from '@salesforce/label/c.FEC_MSG_IPP_Closure_Select_One';
import FEC_MSG_IPP_Closure_No_Eligible from '@salesforce/label/c.FEC_MSG_IPP_Closure_No_Eligible';
import LBL_LOADING from '@salesforce/label/c.Loading';
import FEC_SPINNER_SAVING from '@salesforce/label/c.FEC_Spinner_Saving';
import FEC_LBL_IPP_Closure_Back_To_Case from '@salesforce/label/c.FEC_LBL_IPP_Closure_Back_To_Case';
import FEC_LBL_IPP_Closure_Complete from '@salesforce/label/c.FEC_LBL_IPP_Closure_Complete';
import FEC_LBL_IPP_Closure_Heading from '@salesforce/label/c.FEC_LBL_IPP_Closure_Heading';
import FEC_LBL_IPP_Closure_Col_IppRecordNo from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppRecordNo';
import FEC_LBL_IPP_Closure_Col_IppPlan from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppPlan';
import FEC_LBL_IPP_Closure_Col_IppOpenDate from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppOpenDate';
import FEC_LBL_IPP_Closure_Col_IppFirstDueDate from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppFirstDueDate';
import FEC_LBL_IPP_Closure_Col_IppMatureDate from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppMatureDate';
import FEC_LBL_IPP_Closure_Col_IppBalance from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppBalance';
import FEC_LBL_IPP_Closure_Col_IppCurrentBalance from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppCurrentBalance';
import FEC_LBL_IPP_Closure_Col_IppInterestRate from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppInterestRate';
import FEC_LBL_IPP_Closure_Col_IppTerm from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppTerm';
import FEC_LBL_IPP_Closure_Col_IppInsurance from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppInsurance';
import FEC_LBL_IPP_Closure_Col_IppCurrentTerm from '@salesforce/label/c.FEC_LBL_IPP_Closure_Col_IppCurrentTerm';
import FEC_Success_Title from '@salesforce/label/c.FEC_Success_Title';
import FEC_Toast_Error from '@salesforce/label/c.FEC_Toast_Error';
import FEC_Toast_Save_Success from '@salesforce/label/c.FEC_Toast_Save_Success';
import FEC_Toast_Save_Error from '@salesforce/label/c.FEC_Toast_Save_Error';
import FEC_Toast_Error_Generic from '@salesforce/label/c.FEC_Toast_Error_Generic';
import { formatToDDMMYYYY } from 'c/fec_CommonUtils';
import { STR_EMPTY } from 'c/fec_CommonConst';

const STATE_LOADING = 'LOADING';
const STATE_NONE = 'NONE';
const STATE_HAS_DATA = 'HAS_DATA';

export default class Fec_IPPClosureForm extends NavigationMixin(LightningElement) {

    @api recordId;

    @track ippList = [];
    @track selectedIppId = null;
    @track isLoading = false;
    @track completeLoading = false;
    @track showNoti11 = false;

    state = STATE_LOADING;

    labelLoading = LBL_LOADING;
    labelSaving = FEC_SPINNER_SAVING;
    labelBackToCase = FEC_LBL_IPP_Closure_Back_To_Case;
    labelComplete = FEC_LBL_IPP_Closure_Complete;
    headingText = FEC_LBL_IPP_Closure_Heading;

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
        { label: FEC_LBL_IPP_Closure_Col_IppInsurance, fieldName: 'ippInsuranceDisplay', type: 'text', cellAttributes: { alignment: 'right' } },
        { label: FEC_LBL_IPP_Closure_Col_IppCurrentTerm, fieldName: 'ippCurrentTermDisplay', type: 'text' }
    ];

    connectedCallback() {
        this.loadEligibleIPPs();
    }

    loadEligibleIPPs() {
        if (!this.recordId) {
            this.state = STATE_NONE;
            return;
        }
        this.isLoading = true;
        this.ippList = [];
        this.selectedIppId = null;
        this.showNoti11 = false;
        getEligibleIPPsForClosure({ caseId: this.recordId })
            .then((data) => {
                const rows = (data || []).map(row => this.mapRowToDisplay(row));
                this.ippList = rows;
                if (rows.length === 0) {
                    this.state = STATE_NONE;
                } else {
                    this.state = STATE_HAS_DATA;
                }
            })
            .catch((err) => {
                this.state = STATE_NONE;
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
            ippInsuranceDisplay: this.formatCurrency(row.ippInsurance),
            ippCurrentTermDisplay: row.ippCurrentTerm != null ? String(row.ippCurrentTerm) : STR_EMPTY
        };
    }

    formatCurrency(val) {
        if (val == null) return STR_EMPTY;
        return 'VND ' + new Intl.NumberFormat('vi-VN').format(val);
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows || [];
        this.selectedIppId = selectedRows.length === 1 ? selectedRows[0].Id : null;
        this.showNoti11 = false;
    }

    handleCompleteCase() {
        if (!this.selectedIppId) {
            this.showNoti11 = true;
            return;
        }
        this.showNoti11 = false;
        this.completeLoading = true;
        saveSelectedIPPToCase({ caseId: this.recordId, ippId: this.selectedIppId })
            .then((success) => {
                if (success) {
                    this.showToast(FEC_Success_Title, FEC_Toast_Save_Success, 'success');
                    //this.navigateToCase();
                } else {
                    this.showToast(FEC_Toast_Error, FEC_Toast_Save_Error, 'error');
                }
            })
            .catch((err) => {
                this.showToast(FEC_Toast_Error, err?.body?.message || err?.message || FEC_Toast_Error_Generic, 'error');
            })
            .finally(() => {
                this.completeLoading = false;
            });
    }

    // handleBackToCase() {
    //     this.navigateToCase();
    // }

    // navigateToCase() {
    //     if (!this.recordId) return;
    //     this[NavigationMixin.Navigate]({
    //         type: 'standard__recordPage',
    //         attributes: {
    //             recordId: this.recordId,
    //             objectApiName: 'Case',
    //             actionName: 'view'
    //         }
    //     });
    // }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get hasNoEligibleIPPs() {
        return this.state === STATE_NONE && !this.isLoading;
    }

    get hasEligibleIPPs() {
        return this.state === STATE_HAS_DATA && this.ippList.length > 0;
    }

    get noti11Message() {
        return FEC_MSG_IPP_Closure_Select_One;
    }

    get noti12Message() {
        return FEC_MSG_IPP_Closure_No_Eligible;
    }
}
