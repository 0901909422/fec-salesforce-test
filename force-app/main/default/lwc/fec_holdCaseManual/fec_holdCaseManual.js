import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getNFUReasons from '@salesforce/apex/FEC_HoldCaseController.getNFUReasons';
import saveHoldCase from '@salesforce/apex/FEC_HoldCaseController.saveHoldCase';
import { getRecord, getFieldValue }  from 'lightning/uiRecordApi';

// ── Case Field Imports ────────────────────────────────────────────────────────
import FIELD_ID              from '@salesforce/schema/Case.Id';
import FIELD_PRODUCT_TYPE    from '@salesforce/schema/Case.FEC_Product_Type__c';
import FIELD_CATEGORY        from '@salesforce/schema/Case.FEC_Category__c';
import FIELD_SUB_CATEGORY    from '@salesforce/schema/Case.FEC_SubCategory__c';
import FIELD_SUB_CODE        from '@salesforce/schema/Case.FEC_SubCode__c';
import FIELD_IS_SUBMITTED    from '@salesforce/schema/Case.FEC_Is_Submited__c';
import FEC_NFU_Reason from '@salesforce/label/c.FEC_NFU_Reason';
import FEC_Hold_Case from '@salesforce/label/c.FEC_Hold_Case';
import FEC_NFU_Code from '@salesforce/label/c.FEC_NFU_Code';
import FEC_NFU_Hold_Day_Duration from '@salesforce/label/c.FEC_NFU_Hold_Day_Duration';
import FEC_Messenger_Success_Hold_Case from '@salesforce/label/c.FEC_Messenger_Success_Hold_Case';
import FEC_Error_MessageError_Hold_Case from '@salesforce/label/c.FEC_Error_MessageError_Hold_Case';
import FEC_Error_Message_Maxretris from '@salesforce/label/c.FEC_Error_Message_Maxretris';
import FEC_Show_Action_Hold_Case from '@salesforce/label/c.FEC_Show_Action_Hold_Case'; 
import FEC_Failed_To_Load_Case from '@salesforce/label/c.FEC_Failed_To_Load_Case'; 
import FEC_Failed_To_Load_NFU from '@salesforce/label/c.FEC_Failed_To_Load_NFU'; 
import FEC_Please_Select_An_NFU from '@salesforce/label/c.FEC_Please_Select_An_NFU'; 
import FEC_MSG_IPP_AddIpp_Default_Success from '@salesforce/label/c.FEC_MSG_IPP_AddIpp_Default_Success'; 
import FEC_An_Unexpected_Error from '@salesforce/label/c.FEC_An_Unexpected_Error'; 
import {
  STR_EMPTY, ERROR_TOAST_TYPE, WARNING_HOLD_CASE,
   WARNING_HOLD_TOAST, SUCCESS_MODAL_TITLE,
    RESPONSE_SUCCESS,ERROR_MODAL_TITLE
} from "c/fec_CommonConst";


// ── All fields array for getRecord ───────────────────────────────────────────
const CASE_FIELDS = [
    FIELD_ID,
    FIELD_PRODUCT_TYPE,
    FIELD_CATEGORY,
    FIELD_SUB_CATEGORY,
    FIELD_SUB_CODE,
    FIELD_IS_SUBMITTED
];

export default class Fec_holdCaseManual extends LightningElement {

    // ── Public Properties ────────────────────────────────────────────────────
    @api recordId; // Case Id from record page

    // ── Tracked State ────────────────────────────────────────────────────────
    @track selectedReason = STR_EMPTY;
    @track nfuCode = STR_EMPTY;
    @track nfuHoldDayDuration = STR_EMPTY;
    @track nfuReasonOptions = [];
    @track isLoading = false;

    
    // ── Case Record Fields ───────────────────────────────────────────────────
    @track caseNumber         = STR_EMPTY;
    @track caseAccount        = STR_EMPTY;
    @track caseProductType    = STR_EMPTY;
    @track caseCategory       = STR_EMPTY;
    @track caseSubCategory    = STR_EMPTY;
    @track caseSubCode        = STR_EMPTY;
    @track caseIsSubmitted    = false;
    @track isHoldCaseSuccess  = false;
    @track errorMessage       = STR_EMPTY;

    
    // ── Internal Map: reason value → { code, duration } ─────────────────────
    _nfuReasonMap = {}; 

    _retryCount = 0;
    _maxRetries = 3;

     customLabel = {
       nfuReason : FEC_NFU_Reason,
       HoldCase : FEC_Hold_Case,
       nfuCode : FEC_NFU_Code,
       nfuHoldDayDuration: FEC_NFU_Hold_Day_Duration,
       messengerSuccessHoldCase : FEC_Messenger_Success_Hold_Case,
       errorMessageErrorHoldCase : FEC_Error_MessageError_Hold_Case,
       errorMessageMaxretris : FEC_Error_Message_Maxretris,
       showActionHoldCase : FEC_Show_Action_Hold_Case,
       failedToLoadCase : FEC_Failed_To_Load_Case,
       failedToLoadNFU : FEC_Failed_To_Load_NFU,
       pleaseSelectAnNFU : FEC_Please_Select_An_NFU,
       mSGIPPAddIppDefaultSuccess : FEC_MSG_IPP_AddIpp_Default_Success,
       anUnexpectedError : FEC_An_Unexpected_Error
    }

    // ─────────────────────────────────────────────────────────────────────────
    // WIRE : getRecord
    // DESC : Fetch Case record fields reactively by recordId
    // ─────────────────────────────────────────────────────────────────────────
    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    wiredCase({ error, data }) {
        if (data) {
            this.caseSubCode     = getFieldValue(data, FIELD_SUB_CODE);
            console.log('SubCode:', this.caseSubCode);
            this.caseIsSubmitted = getFieldValue(data, FIELD_IS_SUBMITTED);
            if (this.caseSubCode) {
                this._loadNFUReasons();
            } else {
                this.handleCancel();
                this._showToastNotFoundCaseConfig();
            }

        } else if (error) {
            this._showToast(
                STR_EMPTY,
                this.customLabel.failedToLoadCase + (error?.body?.message ?? error),
                ERROR_TOAST_TYPE
            );
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE : _loadNFUReasons
    // DESC    : Async/await call to getNFUReasons Apex method
    //           Guarded by subCode blank check before invoking
    // ─────────────────────────────────────────────────────────────────────────
    async _loadNFUReasons() {
        // ── Guard: skip if subCode is blank ───────────────────────────────────
        if (!this.caseSubCode) {
            return;
        }

        this.isLoading = true;
        try {
            // ── Call Apex getNFUReasons with subCode ───────────────────────────
            const data = await getNFUReasons({ subCode: this.caseSubCode });
            if (data && data?.length > 0) {
                // ── Build combobox options — active configs only ───────────────────
                this.nfuReasonOptions = data
                    .filter(item => item.isActive)
                    .map(item => ({
                        label : item.nfuReasonVN || item.nfuReasonEN,
                        value : item.nfuCode
                    }));
    
                // ── Build internal map for auto-populate on selection ─────────────
                this._nfuReasonMap = {};
                data.forEach(item => {
                    this._nfuReasonMap[item.nfuCode] = {
                        nfuDuration  : item.nfuDuration,
                        holdCaseType : item.holdCaseType,
                        nfuReasonVN  : item.nfuReasonVN,
                        nfuReasonEN  : item.nfuReasonEN,
                        nfuCode      : item.nfuCode,
                        subCode      : item.subCode
                    };
                });
            } else {
                this.handleCancel();
                this._showToastNotFoundCaseConfig();
            }

        } catch (error) {
            this._showToast(
                STR_EMPTY,
                this.customLabel.failedToLoadNFU + (error?.body?.message ?? error),
                ERROR_TOAST_TYPE
            );
        } finally {
            this.isLoading = false;
        }
    }

    // ── Computed ─────────────────────────────────────────────────────────────
    get isHoldDisabled() {
        return !this.selectedReason;
    }

    // ── Handlers ─────────────────────────────────────────────────────────────

    /**
     * On NFU Reason change → auto-populate NFU Code & Hold Day Duration
     */
    handleReasonChange(event) {
        this.selectedReason = event.detail.value;

        const meta = this._nfuReasonMap[this.selectedReason];
        if (meta) {
            this.nfuCode = meta.nfuCode;
            this.nfuHoldDayDuration = meta.nfuDuration;
        } else {
            this.nfuCode = STR_EMPTY;
            this.nfuHoldDayDuration = STR_EMPTY;
        }
    }

    /**
     * Cancel → close the action screen
     */
    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    /**
     * Hold Case → call Apex to update Case status
     */
    async handleHoldCase() {
        if (!this.selectedReason) {
            this._showToast(WARNING_HOLD_CASE, this.customLabel.pleaseSelectAnNFU, WARNING_HOLD_TOAST);
            return;
        }
        this.isLoading = true;
        try {
            const response = await saveHoldCase({
                caseId       : this.recordId,
                nfuReason    : this.selectedReason,
                nfuCode      : this.nfuCode,
                holdDuration : this.nfuHoldDayDuration
            });
            this._retryCount += 1;

            if (response?.status == RESPONSE_SUCCESS) {
                this.isHoldCaseSuccess = true;
                this._showToast(this.customLabel.mSGIPPAddIppDefaultSuccess, this.customLabel.messengerSuccessHoldCase, SUCCESS_MODAL_TITLE);
                this.handleCancel();
            } else {
                
                // update retry count and show error if max retries reached
                if (this._retryCount >= this._maxRetries) {
                    this.errorMessage = this.customLabel.errorMessageErrorHoldCase;
                    // update logic
                } else {
                    this.errorMessage = this.customLabel.errorMessageMaxretris;
                    // update logic
                }
            }
           

        } catch (error) {
            const msg = error?.body?.message ?? this.customLabel.anUnexpectedError;
            this._showToast(ERROR_MODAL_TITLE, msg, ERROR_TOAST_TYPE);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Private Helpers ──────────────────────────────────────────────────────
    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _showToastNotFoundCaseConfig() {
        this._showToast( STR_EMPTY, this.customLabel.showActionHoldCase, ERROR_TOAST_TYPE);
    }
}