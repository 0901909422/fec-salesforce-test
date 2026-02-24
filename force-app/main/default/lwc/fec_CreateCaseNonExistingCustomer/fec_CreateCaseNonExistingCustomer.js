import { LightningElement, track, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
export default class Fec_CreateCaseNonExistingCustomer extends NavigationMixin(
  LightningElement,
) {
  @api recordId;
  @track customerName = "";
  @track identityNo = "";
  @track showError = false; // demo giống hình

  handleNameChange(event) {
    this.customerName = event.target.value;
  }

  handleIdentityChange(event) {
    this.identityNo = event.target.value;
  }

  handleCreateCase() {
    // demo validate
    if (!this.customerName || !this.identityNo) {
      this.showError = true;
      return;
    }

    this.showError = false;

    // TODO: gọi Apex create Case
    console.log("Create Case:", {
      customerName: this.customerName,
      identityNo: this.identityNo,
    });

    this[NavigationMixin.Navigate]({
      type: "standard__component",
      attributes: {
        componentName: "c__fec_InteractionCreateCase",
      },
      state: {
        c__recordId: this.recordId,
        c__customerName: this.customerName,
        c__identityNo: this.identityNo,
      },
    });
  }
}
