import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";

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

import blockCard from '@salesforce/apex/FEC_CardLockUnLockController.blockCard';

export default class Fec_CardBlock extends LightningElement {
    @api recordId;

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

    get isShowBtn() {
        return !this.isSuccess && (this.blockCardCount < 3);
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