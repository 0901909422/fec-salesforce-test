import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getCardLockUnlockUiContext from '@salesforce/apex/FEC_CardClosureRefundController.getCardLockUnlockUiContext';
import blockCard from '@salesforce/apex/FEC_CardClosureRefundController.blockCard';
import FEC_MSG_Card_Block_Success from '@salesforce/label/c.FEC_MSG_Card_Block_Success';
import FEC_MSG_Card_Block_Fail_Disable from '@salesforce/label/c.FEC_MSG_Card_Block_Fail_Disable';
import FEC_MSG_Card_Block_Fail_Retry from '@salesforce/label/c.FEC_MSG_Card_Block_Fail_Retry';
import FEC_MSG_Card_Block_Confirm_Title from '@salesforce/label/c.FEC_MSG_Card_Block_Confirm_Title';
import FEC_MSG_Card_Block_Confirm_Body from '@salesforce/label/c.FEC_MSG_Card_Block_Confirm_Body';
import FEC_LBL_Pending_Disbursement_Section from '@salesforce/label/c.FEC_LBL_Pending_Disbursement_Section';
import FEC_Application_ID_Label from '@salesforce/label/c.FEC_Application_ID_Label';
import FEC_LBL_Pending_Disbursement_Application_Status from '@salesforce/label/c.FEC_LBL_Pending_Disbursement_Application_Status';
import FEC_LBL_Pending_Disbursement_Disbursed_Amount from '@salesforce/label/c.FEC_LBL_Pending_Disbursement_Disbursed_Amount';
import FEC_LBL_Pending_Disbursement_Approval_Date from '@salesforce/label/c.FEC_LBL_Pending_Disbursement_Approval_Date';
import FEC_LBL_Pending_Disbursement_Disbursement_Status from '@salesforce/label/c.FEC_LBL_Pending_Disbursement_Disbursement_Status';
import FEC_LBL_Pending_Disbursement_CS_Decision from '@salesforce/label/c.FEC_LBL_Pending_Disbursement_CS_Decision';
import FEC_MSG_Card_Block_Beneficiary_Required from '@salesforce/label/c.FEC_MSG_Card_Block_Beneficiary_Required';
import FEC_MSG_Param_Required from '@salesforce/label/c.FEC_MSG_Param_Required';
import { STR_EMPTY, RESULT_ERROR, RESULT_SUCCESS } from 'c/fec_CommonConst';

export default class Fec_CardClosureRefundForm extends NavigationMixin(LightningElement) {

    _recordId;

    @api
    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.loadUiContext();
        }
    }

    get recordId() {
        return this._recordId;
    }

    @track uiContext = null;
    @track uiContextLoading = false;
    @track showConfirmModal = false;
    @track isSubmitting = false;
    @track resultMessage = STR_EMPTY;
    @track resultClass = STR_EMPTY;
    @track beneficiaryNameLocal = STR_EMPTY;
    @track beneficiaryAccountLocal = STR_EMPTY;
    @track bankNameLocal = STR_EMPTY;
    @track bankBranchLocal = STR_EMPTY;
    @track provinceCityLocal = STR_EMPTY;

    customLabel = {
        confirmTitle: FEC_MSG_Card_Block_Confirm_Title,
        confirmBody: FEC_MSG_Card_Block_Confirm_Body,
        pendingSection: FEC_LBL_Pending_Disbursement_Section,
        blockCard: FEC_MSG_Card_Block_Confirm_Title,
        pendingDisbursementApplicationId: FEC_Application_ID_Label,
        pendingDisbursementApplicationStatus: FEC_LBL_Pending_Disbursement_Application_Status,
        pendingDisbursementDisbursedAmount: FEC_LBL_Pending_Disbursement_Disbursed_Amount,
        pendingDisbursementApprovalDate: FEC_LBL_Pending_Disbursement_Approval_Date,
        pendingDisbursementStatus: FEC_LBL_Pending_Disbursement_Disbursement_Status,
        pendingDisbursementCsDecision: FEC_LBL_Pending_Disbursement_CS_Decision
    };

    pendingColumns = [
        { label: this.customLabel.pendingDisbursementApplicationId, fieldName: 'applicationId', type: 'text' },
        { label: this.customLabel.pendingDisbursementApplicationStatus, fieldName: 'applicationStatus', type: 'text' },
        { label: this.customLabel.pendingDisbursementDisbursedAmount, fieldName: 'disbursedAmountDisplay', type: 'text' },
        { label: this.customLabel.pendingDisbursementApprovalDate, fieldName: 'approvalDateDisplay', type: 'text' },
        { label: this.customLabel.pendingDisbursementStatus, fieldName: 'disbursementStatus', type: 'text' },
        { label: this.customLabel.pendingDisbursementCsDecision, fieldName: 'csDecision', type: 'text' }
    ];

    refundFieldKeys = ['beneficiaryNameLocal', 'beneficiaryAccountLocal', 'bankNameLocal', 'bankBranchLocal', 'provinceCityLocal'];

    loadUiContext() {
        if (!this.recordId) {
            return Promise.resolve();
        }
        this.uiContextLoading = true;
        return getCardLockUnlockUiContext({ caseId: this.recordId })
            .then((ctx) => {
                this.uiContext = ctx;
                if (ctx) {
                    this.beneficiaryNameLocal = ctx.beneficiaryName || STR_EMPTY;
                    this.beneficiaryAccountLocal = ctx.beneficiaryAccount || STR_EMPTY;
                    this.bankNameLocal = ctx.bankName || STR_EMPTY;
                    this.bankBranchLocal = ctx.bankBranch || STR_EMPTY;
                    this.provinceCityLocal = ctx.provinceCity || STR_EMPTY;
                }
            })
            .catch(() => {
                this.uiContext = null;
            })
            .finally(() => {
                this.uiContextLoading = false;
            });
    }

    get showBlockCardButton() {
        return this.uiContext && this.uiContext.showBlockCardButton === true;
    }

    get showRefundSection() {
        return this.uiContext && this.uiContext.requireRefundFields === true;
    }

    get pendingRowData() {
        if (!this.uiContext) {
            return [];
        }
        const c = this.uiContext;
        return [
            {
                id: 'pd1',
                applicationId: c.pendingApplicationId || STR_EMPTY,
                applicationStatus: c.pendingApplicationStatus || STR_EMPTY,
                disbursedAmountDisplay: this.formatCurrency(c.pendingDisbursedAmount),
                approvalDateDisplay: this.formatDateIso(c.pendingDisbursementApprovalDate),
                disbursementStatus: c.pendingDisbursementStatus || STR_EMPTY,
                csDecision: c.pendingCsDecision || STR_EMPTY
            }
        ];
    }

    formatCurrency(value) {
        if (value === null || value === undefined || value === STR_EMPTY) {
            return STR_EMPTY;
        }
        return new Intl.NumberFormat('vi-VN').format(Number(value));
    }

    formatDateIso(value) {
        if (!value) {
            return STR_EMPTY;
        }
        const s = typeof value === 'string' ? value : String(value);
        const parts = s.split('-');
        if (parts.length >= 3) {
            return `${parts[2]}/${parts[1]}/${parts[0]}`;
        }
        return s;
    }

    handleRefundFieldChange(event) {
        const key = event.target.name;
        if (this.refundFieldKeys.includes(key)) {
            this[key] = event.target.value;
        }
    }

    refundFieldsValid() {
        return this.refundFieldKeys.every((k) => String(this[k] || STR_EMPTY).trim() !== STR_EMPTY);
    }

    handleBlockCardClick() {
        if (!this.showBlockCardButton || this.isSubmitting) {
            return;
        }
        if (!this.recordId) {
            this.resultMessage = FEC_MSG_Param_Required.replace('{0}', 'Case Id');
            this.resultClass = RESULT_ERROR;
            return;
        }
        if (this.showRefundSection && !this.refundFieldsValid()) {
            this.resultMessage = FEC_MSG_Card_Block_Beneficiary_Required;
            this.resultClass = RESULT_ERROR;
            return;
        }
        this.showConfirmModal = true;
    }

    handleConfirmNo() {
        this.showConfirmModal = false;
    }

    handleConfirmYes() {
        this.showConfirmModal = false;
        this.callBlockCard();
    }

    navigateToCaseView() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Case',
                actionName: 'view'
            }
        });
    }

    callBlockCard() {
        if (!this.recordId) {
            this.resultMessage = FEC_MSG_Param_Required.replace('{0}', 'Case Id');
            this.resultClass = RESULT_ERROR;
            return;
        }
        this.isSubmitting = true;
        blockCard({
            caseId: this.recordId,
            beneficiaryName: this.beneficiaryNameLocal,
            beneficiaryAccount: this.beneficiaryAccountLocal,
            bankName: this.bankNameLocal,
            bankBranch: this.bankBranchLocal,
            provinceCity: this.provinceCityLocal
        })
            .then((res) => {
                if (res && res.success) {
                    this.resultMessage = FEC_MSG_Card_Block_Success;
                    this.resultClass = RESULT_SUCCESS;
                    window.setTimeout(() => {
                        this.navigateToCaseView();
                    }, 500);
                    return;
                }
                if (res && res.hideBlockCardAfterAction === true) {
                    this.resultMessage = FEC_MSG_Card_Block_Fail_Disable;
                    this.resultClass = RESULT_ERROR;
                    window.setTimeout(() => {
                        this.navigateToCaseView();
                    }, 500);
                    return;
                }
                if (res && res.errorMessage) {
                    this.resultMessage = res.errorMessage;
                } else {
                    this.resultMessage = FEC_MSG_Card_Block_Fail_Retry;
                }
                this.resultClass = RESULT_ERROR;
            })
            .catch(() => {
                this.resultMessage = FEC_MSG_Card_Block_Fail_Retry;
                this.resultClass = RESULT_ERROR;
            })
            .finally(() => {
                this.isSubmitting = false;
                this.loadUiContext();
            });
    }
}