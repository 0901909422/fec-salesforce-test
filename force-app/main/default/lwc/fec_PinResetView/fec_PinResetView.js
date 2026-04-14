import { LightningElement, track, api, wire } from "lwc";
import { publish, MessageContext } from "lightning/messageService";
import CASE_NOC from "@salesforce/messageChannel/FEC_Case_NOC__c";
import getCardInfo from "@salesforce/apex/FEC_PinResetHandler.getCardInfo";
import resetPin from "@salesforce/apex/FEC_PinResetHandler.resetPin";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import FEC_Reset_Pin_Confirm_Msg from "@salesforce/label/c.FEC_Reset_Pin_Confirm_Msg";
import FEC_Reset_PIN_Title from "@salesforce/label/c.FEC_Reset_PIN_Title";
import FEC_Yes_Btn from "@salesforce/label/c.FEC_Yes_Btn";
import FEC_No_Btn from "@salesforce/label/c.FEC_No_Btn";
import FEC_Card_Number_Required_MSG from "@salesforce/label/c.FEC_Card_Number_Required_MSG";
import FEC_CIF_Number_Required_MSG from "@salesforce/label/c.FEC_CIF_Number_Required_MSG";

import FEC_RESET_PIN_SUCCESS from "@salesforce/label/c.FEC_RESET_PIN_SUCCESS";
import FEC_RESET_PIN_ERROR from "@salesforce/label/c.FEC_RESET_PIN_ERROR";
import FEC_RESET_PIN_FAILED from "@salesforce/label/c.FEC_RESET_PIN_FAILED";

import {
  ERROR_MODAL_TITLE,
  SUCCESS_MODAL_TITLE,
  SUCCESS_TOAST_TYPE,
  ERROR_TOAST_TYPE,
} from "c/fec_CommonConst";

export default class Fec_PinResetView extends LightningElement {
  @api recordId;

  cardNumber;
  cifNumber;
  nationalId;
  mobile;
  processActionCount = 0;
  successReset = false;
  // showRetry = false;
  // showFailed = false;
  isOpen = false;

  label = {
    FEC_Reset_Pin_Confirm_Msg,
    FEC_Reset_PIN_Title,
    FEC_Yes_Btn,
    FEC_No_Btn,
    FEC_Card_Number_Required_MSG,
    FEC_CIF_Number_Required_MSG,
    FEC_RESET_PIN_SUCCESS,
    FEC_RESET_PIN_ERROR,
    FEC_RESET_PIN_FAILED,
  };
  // ================= INIT =================

  @wire(MessageContext)
  messageContext;

  connectedCallback() {
    this.loadCardInfo();
  }

  loadCardInfo() {
    return getCardInfo({ customerCaseId: this.recordId })
      .then((res) => {
        this.nationalId = res.nationalId;
        this.mobile = res.mobile;
        this.processActionCount = res.processActionCount;
      })
      .catch((err) => {
        this.showToast("Error", err.body.message, "error");
      });
  }

  // ================= UI =================
  handleVerificationChange(event) {
    this.verificationValue = event.detail.value;
  }

  handleCallbackChange(event) {
    this.callbackValue = event.detail.value;
  }

  handleResetPin() {
    this.openModal();
  }

  get isInvisibleButton() {
    return this.successReset || this.processActionCount >= 3;
  }

  get isShowSuccessMessage() {
    return this.successReset;
  }

  get isShowRetryMessage() {
    return (
      this.processActionCount > 0 &&
      this.processActionCount < 3 &&
      !this.successReset
    );
  }

  get isShowFailedMessage() {
    return this.processActionCount >= 3 && !this.successReset;
  }
  // ================= MODAL =================
  openModal() {
    this.isOpen = true;
  }

  close() {
    this.isOpen = false;
  }

  handleCloseModal() {
    this.close();
  }

  handleConfirmReset() {
    this.isLoading = true;

    // publish(this.messageContext, CASE_NOC, {
    //   type: "PIN_RESET_CONFIRMED",
    //   caseId: this.recordId,
    // });

    resetPin({
      caseId: this.recordId,
      nationalId: this.nationalId,
      mobile: this.mobile,
    })
      .then((res) => {
        console.log("🔄 API RESPONSE:", JSON.stringify(res));
        if (res.RespCode != "1") {
          this.showToast(SUCCESS_MODAL_TITLE, res.RespDesc, SUCCESS_TOAST_TYPE);

          // ✅ only mark success locally
          this.successReset = res.isSuccess;

          return this.loadCardInfo(); // 👈 WAIT for fresh data
        } else {
          throw new Error(res.RespDesc || res.errorMessage);
        }
      })
      .then(() => {
        publish(this.messageContext, CASE_NOC, {
          type: "PIN_RESET_SUCCESS",
          caseId: this.recordId,
        });
      })
      .catch((err) => {
        this.showToast(ERROR_MODAL_TITLE, err.message, ERROR_TOAST_TYPE);
      })
      .finally(() => {
        this.close();
        this.isLoading = false;
      });
  }

  // ================= TOAST =================
  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant,
      }),
    );
  }
}
