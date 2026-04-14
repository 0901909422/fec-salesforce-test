import { LightningElement, track, api } from "lwc";
import getCardInfo from "@salesforce/apex/FEC_PinResetHandler.getCardInfo";
import resetPin from "@salesforce/apex/FEC_PinResetHandler.resetPin";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import FEC_Reset_Pin_Confirm_Msg from "@salesforce/label/c.FEC_Reset_Pin_Confirm_Msg";
import FEC_Reset_PIN_Title from "@salesforce/label/c.FEC_Reset_PIN_Title";
import FEC_Yes_Btn from "@salesforce/label/c.FEC_Yes_Btn";
import FEC_No_Btn from "@salesforce/label/c.FEC_No_Btn";
import FEC_Card_Number_Required_MSG from "@salesforce/label/c.FEC_Card_Number_Required_MSG";
import FEC_CIF_Number_Required_MSG from "@salesforce/label/c.FEC_CIF_Number_Required_MSG";

import {
  ERROR_MODAL_TITLE,
  SUCCESS_MODAL_TITLE,
  SUCCESS_TOAST_TYPE,
  ERROR_TOAST_TYPE,
} from "c/fec_CommonConst";

import FEC_RESET_PIN_SUCCESS from "@salesforce/label/c.FEC_RESET_PIN_SUCCESS";
import FEC_RESET_PIN_ERROR from "@salesforce/label/c.FEC_RESET_PIN_ERROR";
import FEC_RESET_PIN_FAILED from "@salesforce/label/c.FEC_RESET_PIN_FAILED";

export default class Fec_PinResetView extends LightningElement {
  @api recordId;

  cardNumber;
  cifNumber;
  nationalId;
  mobile;
  processActionCount = 0;
  successReset = false;
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
  connectedCallback() {
    this.loadCardInfo();
  }

  loadCardInfo() {
    getCardInfo({ customerCaseId: this.recordId })
      .then((res) => {
        console.log("res: ", JSON.stringify(res));
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

  get hiddenButton() {
    return Boolean(this.successReset || this.processActionCount >= 3);
  }

  get message() {
    if (this.successReset) {
      return this.label.FEC_RESET_PIN_SUCCESS;
    }

    if (this.processActionCount >= 3) {
      return this.label.FEC_RESET_PIN_FAILED;
    }

    if (this.processActionCount > 0) {
      return this.label.FEC_RESET_PIN_ERROR;
    }

    return null;
  }

  get messageClass() {
    if (this.successReset) {
      return "slds-text-color_success slds-m-top_medium";
    }

    if (this.processActionCount >= 3) {
      return "slds-text-color_error slds-m-top_medium";
    }

    if (this.processActionCount > 0) {
      return "slds-text-color_error slds-m-top_medium";
    }

    return "";
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

    resetPin({
      caseId: this.recordId,
      nationalId: this.nationalId,
      mobile: this.mobile,
    })
      .then((res) => {
        console.log("res from api: ", JSON.stringify(res));
        if (res.RespCode != "1") {
          this.showToast(SUCCESS_MODAL_TITLE, res.RespDesc, SUCCESS_TOAST_TYPE);
          this.successReset = true;
        } else {
          this.showToast(
            ERROR_MODAL_TITLE,
            res.RespDesc || res.errorMessage,
            ERROR_MODAL_TITLE,
          );
        }
      })
      .catch((err) => {
        this.showToast(ERROR_MODAL_TITLE, err.body?.message, ERROR_TOAST_TYPE);
      })
      .finally(() => {
        this.loadCardInfo();
        this.close();
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
