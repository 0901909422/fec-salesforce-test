import { LightningElement, track, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import FEC_Customer_Name_Label from "@salesforce/label/c.FEC_Customer_Name_Label";
import FEC_National_ID_Passport_ID_Label from "@salesforce/label/c.FEC_National_ID_Passport_ID_Label";
import FEC_MSG_Input_Required from "@salesforce/label/c.FEC_MSG_Input_Required";
import FEC_Create_Case_Btn_Label from "@salesforce/label/c.FEC_Create_Case_Btn_Label";

export default class Fec_CreateCaseNonExistingCustomer extends NavigationMixin(
  LightningElement,
) {
  @api recordId;
  @track customerName = "";
  @track identityNo = "";
  @track showError = false; // demo giống hình

  customLabel = {
    customerName: FEC_Customer_Name_Label,
    nationalIdPassportId: FEC_National_ID_Passport_ID_Label,
    inputRequired: FEC_MSG_Input_Required,
    createCaseBtn: FEC_Create_Case_Btn_Label,
  }

  handleNameChange(event) {
    this.customerName = event.target.value;
  }

  handleIdentityChange(event) {
    this.identityNo = event.target.value;
  }

  handleCreateCase(message) {
    if (message.caseId !== this.recordId) {
      return;
    }
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