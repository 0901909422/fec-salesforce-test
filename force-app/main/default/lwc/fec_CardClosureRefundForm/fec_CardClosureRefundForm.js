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
import FEC_MSG_No_Pending_Disbursement from '@salesforce/label/c.FEC_MSG_No_Pending_Disbursement';
import FEC_MSG_Param_Required from '@salesforce/label/c.FEC_MSG_Param_Required';
import { STR_EMPTY, RESULT_ERROR, RESULT_SUCCESS } from 'c/fec_CommonConst';

const SUB_CODE_RC16_01 = 'RC16.01';

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

    @api isEdit;

    @api subCodeCode;

    @track uiContext = null;
    @track uiContextLoading = false;
    @track showConfirmModal = false;
    @track isSubmitting = false;
    @track resultMessage = STR_EMPTY;
    @track resultClass = STR_EMPTY;
    @track formLocked = false;

    @api
    validateForSubmit() {
        return true;
    }

    @api
    saveDraftIfApplicable() {
        return Promise.resolve();
    }

    @api
    saveForSubmitIfApplicable() {
        return Promise.resolve();
    }

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
        pendingDisbursementCsDecision: FEC_LBL_Pending_Disbursement_CS_Decision,
        noPendingDisbursement: FEC_MSG_No_Pending_Disbursement
    };

    pendingColumns = [
        { label: this.customLabel.pendingDisbursementApplicationId, fieldName: 'applicationId', type: 'text' },
        { label: this.customLabel.pendingDisbursementApplicationStatus, fieldName: 'applicationStatus', type: 'text' },
        { label: this.customLabel.pendingDisbursementDisbursedAmount, fieldName: 'disbursedAmountDisplay', type: 'text' },
        { label: this.customLabel.pendingDisbursementApprovalDate, fieldName: 'approvalDateDisplay', type: 'text' },
        { label: this.customLabel.pendingDisbursementStatus, fieldName: 'disbursementStatus', type: 'text' },
        { label: this.customLabel.pendingDisbursementCsDecision, fieldName: 'csDecision', type: 'text' }
    ];

    loadUiContext() {
        if (!this.recordId) {
            return Promise.resolve();
        }
        this.uiContextLoading = true;
        return getCardLockUnlockUiContext({ caseId: this.recordId })
            .then((ctx) => {
                this.uiContext = ctx;
            })
            .catch(() => {
                this.uiContext = null;
            })
            .finally(() => {
                this.uiContextLoading = false;
            });
    }

    get showBlockCardButton() {
        if (!this.uiContext) {
            return false;
        }
        const ctx = this.uiContext;
        const parentCode = this.subCodeCode != null ? String(this.subCodeCode).trim() : STR_EMPTY;
        const hideBySubCode = parentCode !== STR_EMPTY
            ? SUB_CODE_RC16_01 === parentCode
            : ctx.hideBlockCardBySubCode === true;
        const cardBlocked = ctx.cardBlocked === true;
        return !hideBySubCode && ctx.attemptsExhausted !== true && !cardBlocked;
    }

    get blockCardLocked() {
        return this.isSubmitting || this.formLocked || this.isEdit === false;
    }

    get hasPendingDisbursementData() {
        const ctx = this.uiContext;
        if (!ctx) {
            return false;
        }
        if (ctx.pendingApplicationId) {
            return true;
        }
        if (ctx.pendingApplicationStatus) {
            return true;
        }
        if (ctx.pendingDisbursementStatus) {
            return true;
        }
        if (ctx.pendingCsDecision) {
            return true;
        }
        if (ctx.pendingDisbursementApprovalDate != null && ctx.pendingDisbursementApprovalDate !== undefined) {
            return true;
        }
        if (ctx.pendingDisbursedAmount != null && ctx.pendingDisbursedAmount !== undefined) {
            return true;
        }
        return false;
    }

    get showPendingDisbursementTable() {
        return !this.uiContextLoading && this.uiContext && this.hasPendingDisbursementData;
    }

    get showNoPendingDisbursementMessage() {
        return !this.uiContextLoading && this.uiContext && !this.hasPendingDisbursementData;
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

    handleBlockCardClick() {
        if (!this.showBlockCardButton || this.isSubmitting || this.isEdit === false) {
            return;
        }
        if (!this.recordId) {
            this.resultMessage = FEC_MSG_Param_Required.replace('{0}', 'Case Id');
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
        if (this.isEdit === false) {
            return;
        }
        if (!this.recordId) {
            this.resultMessage = FEC_MSG_Param_Required.replace('{0}', 'Case Id');
            this.resultClass = RESULT_ERROR;
            return;
        }
        this.isSubmitting = true;
        blockCard({ caseId: this.recordId })
            .then((res) => {
                if (res && res.success) {
                    this.formLocked = true;
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