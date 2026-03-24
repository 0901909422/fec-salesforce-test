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

import { ERROR_MODAL_TITLE,
  SUCCESS_MODAL_TITLE,
  SUCCESS_TOAST_TYPE,
  ERROR_TOAST_TYPE} from "c/fec_CommonConst";

export default class Fec_PinResetView extends LightningElement {
  @api recordId;

  cardNumber;
  cifNumber;
  processActionCount = 0;

  isOpen = false;

  label = {
    FEC_Reset_Pin_Confirm_Msg,
    FEC_Reset_PIN_Title,
    FEC_Yes_Btn,
    FEC_No_Btn,
    FEC_Card_Number_Required_MSG,
    FEC_CIF_Number_Required_MSG
  };
  // ================= INIT =================
  connectedCallback() {
    this.loadCardInfo();
  }

  loadCardInfo() {
    getCardInfo({ customerCaseId: this.recordId })
      .then((res) => {
        this.cardNumber = res.cardNumber;
        this.cifNumber = res.cifNumber;
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

  get isDisable() {
    return this.processActionCount >= 3;
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

    if (
      this.cardNumber === null ||
      this.cardNumber === undefined ||
      this.cardNumber === ""
    ) {
      this.showToast(ERROR_MODAL_TITLE, this.label.FEC_Card_Number_Required_MSG, ERROR_TOAST_TYPE);
      this.close();
      return;
    }

    if (
      this.cifNumber === null ||
      this.cifNumber === undefined ||
      this.cardNumber === ""
    ) {
      this.showToast(ERROR_MODAL_TITLE, this.label.FEC_CIF_Number_Required_MSG, ERROR_MODAL_TITLE);
      this.close();
      return;
    }

    resetPin({
      caseId: this.recordId,
      cardNumber: this.cardNumber,
      cifNumber: this.cifNumber,
    })
      .then((res) => {
        if (res.isSuccess) {
          this.showToast(SUCCESS_MODAL_TITLE, res.RespDesc, SUCCESS_TOAST_TYPE);
        } else {
          this.showToast(ERROR_MODAL_TITLE, res.RespDesc || res.errorMessage, ERROR_MODAL_TITLE);
        }
      })
      .catch((err) => {
        this.showToast(ERROR_MODAL_TITLE, err.body?.message, ERROR_MODAL_TITLE);
      })
      .finally(() => {
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
