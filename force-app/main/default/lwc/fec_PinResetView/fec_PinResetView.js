import { LightningElement, track, api } from "lwc";
import getCardInfo from "@salesforce/apex/FEC_PinResetHandler.getCardInfo";
import resetPin from "@salesforce/apex/FEC_PinResetHandler.resetPin";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class Fec_PinResetView extends LightningElement {
  @api recordId;

  @track verificationValue = "success";
  @track callbackValue = "yes";

  cardNumber;
  cifNumber;
  processActionCount = 0;

  isOpen = false;

  verificationOptions = [
    { label: "Thành công", value: "success" },
    { label: "Thất bại", value: "fail" },
  ];

  callbackOptions = [
    { label: "Có", value: "yes" },
    { label: "Không", value: "no" },
  ];

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
      this.showToast("Error", "Card number is required", "error");
      this.close();
      return;
    }

    if (
      this.cifNumber === null ||
      this.cifNumber === undefined ||
      this.cardNumber === ""
    ) {
      this.showToast("Error", "CIF number is required", "error");
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
          this.showToast("Success", res.RespDesc, "success");
        } else {
          this.showToast("Error", res.RespDesc || res.errorMessage, "error");
        }
      })
      .catch((err) => {
        this.showToast("Error", err.body?.message, "error");
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
