import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import CASE_OBJECT from "@salesforce/schema/Case";
import CARD_BLOCK_REASON_FIELD from "@salesforce/schema/Case.FEC_Card_Block_Reason__c";
import ADDITIONAL_INFO_OBJECT from "@salesforce/schema/FEC_Additional_Info__c";
import VERIFY_INFORMATION_FIELD from "@salesforce/schema/FEC_Additional_Info__c.FEC_Verify_Information__c";
import CALLBACK_FIELD from "@salesforce/schema/FEC_Additional_Info__c.FEC_Callback__c";

import FEC_Yes_Btn from "@salesforce/label/c.FEC_Yes_Btn";
import FEC_No_Btn from "@salesforce/label/c.FEC_No_Btn";
import FEC_Current_Card_Status from '@salesforce/label/c.FEC_Current_Card_Status';
import FEC_Card_Block_Reason from '@salesforce/label/c.FEC_Card_Block_Reason';
import FEC_New_Block_Code from '@salesforce/label/c.FEC_New_Block_Code';
import FEC_Verify_Information from '@salesforce/label/c.FEC_Verify_Information';
import FEC_Callback from '@salesforce/label/c.FEC_Callback';
import FEC_Block_Card_Btn from '@salesforce/label/c.FEC_Block_Card_Btn';
import FEC_Block_Card_Header from '@salesforce/label/c.FEC_Block_Card_Header';
import FEC_Block_Card_Success from '@salesforce/label/c.FEC_Block_Card_Success';
import FEC_Block_Card_Failed from '@salesforce/label/c.FEC_Block_Card_Failed';
import FEC_Block_Card_Failed_Max from '@salesforce/label/c.FEC_Block_Card_Failed_Max';
import FEC_Block_Card_Confirmation_Msg from '@salesforce/label/c.FEC_Block_Card_Confirmation_Msg';
import FEC_Error_Title from "@salesforce/label/c.FEC_Error_Title";

import { 
    RECORD_TYPE_CUSTOMER_CASE_NAME,
 } from 'c/fec_CommonConst';

import blockCard from '@salesforce/apex/FEC_CardLockUnLockController.blockCard';

export default class Fec_CardBlock extends LightningElement {
    @api recordId;
    @api isEdit;

    isShowSpinner = false;
    isShowModal = false;
    isSuccess = false;
    isError = false;
    blockCardCount = 0;

    customLabel = {
        yesBtn: FEC_Yes_Btn,
        noBtn: FEC_No_Btn,
        currentCardStatus: FEC_Current_Card_Status,
        cardBlockReason: FEC_Card_Block_Reason,
        newBlockCode: FEC_New_Block_Code,
        verifyInformation: FEC_Verify_Information,
        callback: FEC_Callback,
        blockCardBtn: FEC_Block_Card_Btn,
        blockCardHeader: FEC_Block_Card_Header,
        blockCardSuccess: FEC_Block_Card_Success,
        blockCardFailed: FEC_Block_Card_Failed,
        blockCardFailedMax: FEC_Block_Card_Failed_Max,
        blockCardConfirmationMsg: FEC_Block_Card_Confirmation_Msg,
        errorTitle: FEC_Error_Title,
    };

    customerCaseRecordTypeId;
    addInfoRecordTypeMasterId;
    optionReasons;
    verifyInformationOptions;
    callbackOptions;
    cardBlockReasonValue;
    verifyInformationValue;
    callbackValue;

    mapNewBlockCode = {
        'A': 'A',
        'Không sử dụng': 'L',
        'Thẻ bị mất/ đánh cắp có phát sinh giao dịch': 'S',
    }

    get isDisabled() {
        return this.isEdit === false;
    }

    get isShowBtn() {
        return !this.isDisabled && !this.isSuccess && (this.blockCardCount < 3);
    }

    get isShowMsgRetry() {
        return !this.isSuccess && (this.blockCardCount < 3);
    }

    get newBlockCodeValue() {
        return this.mapNewBlockCode[this.cardBlockReasonValue] || '';
    }

    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    wiredCaseInfo({ error, data }) {
        if (data) {
            const recordTypes = data.recordTypeInfos;
            // Find the Record Type ID by Name
            this.customerCaseRecordTypeId = Object.keys(recordTypes).find(
                (recordTypeId) => recordTypes[recordTypeId].name === RECORD_TYPE_CUSTOMER_CASE_NAME
            );
        } else if (error) {
            console.log(error);
        }
    }

    @wire(getPicklistValues, { recordTypeId: "$customerCaseRecordTypeId", fieldApiName: CARD_BLOCK_REASON_FIELD })
    cardBlockReasonResults({ error, data }) {
        if (data) {
            this.optionReasons = data.values;
        } else if (error) {
            console.log(error);
        }
    }

    @wire(getObjectInfo, { objectApiName: ADDITIONAL_INFO_OBJECT })
    wiredAdditionalInfo({ error, data }) {
        if (data) {
            const recordTypes = data.recordTypeInfos;
            // Find the Record Type ID Master
            this.addInfoRecordTypeMasterId = Object.keys(recordTypes).find(
                (recordTypeId) => recordTypes[recordTypeId].master === true
            );
        } else if (error) {
            console.log(error);
        }
    }

    @wire(getPicklistValues, { recordTypeId: "$addInfoRecordTypeMasterId", fieldApiName: VERIFY_INFORMATION_FIELD })
    verifyInfoResults({ error, data }) {
        if (data) {
            this.verifyInformationOptions = data.values;
        } else if (error) {
            console.log(error);
        }
    }

    @wire(getPicklistValues, { recordTypeId: "$addInfoRecordTypeMasterId", fieldApiName: CALLBACK_FIELD })
    callbackResults({ error, data }) {
        if (data) {
            this.callbackOptions = data.values;
        } else if (error) {
            console.log(error);
        }
    }

    connectedCallback() {
        this.blockCardCount = 0;
    }

    handleBlockCardClick() {
        this.isShowModal = true;
    }

    handleCancelClick() {
        this.isShowModal = false;
    }

    handleConfirmClick() {
        this.isShowSpinner = true;
        blockCard({ recordId: this.recordId })
            .then((result) => {
                if (result === 'SUCCESS') {
                    this.isSuccess = true;
                } else {
                    this.blockCardCount++;
                    this.isError = true;
                }
                this.isShowModal = false;
            })
            .catch((error) => {
                console.error(error);
                this.showToast(this.customLabel.errorTitle, this.handleError(error), 'error');
            })
            .finally(() => {
                this.isShowSpinner = false;
            });
    }

    handleCardBlockReasonChange(event) {
        this.cardBlockReasonValue = event.detail.value;
    }

    handleVerifyInformationChange(event) {
        this.verifyInformationValue = event.detail.value;
    }

    handleCallbackChange(event) {
        this.callbackValue = event.detail.value;
    }

    handleError(error) {
        let msg = '';
        if (Array.isArray(error?.body)) {
            msg = error.body.map(e => e.message).join(', ');
        } else if (typeof error?.body?.message === 'string') {
            msg = error.body.message;
        }
        return msg;
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}