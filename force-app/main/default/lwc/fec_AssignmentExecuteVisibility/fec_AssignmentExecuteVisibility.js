import { LightningElement, api, wire } from "lwc";
import canExecute from "@salesforce/apex/FEC_AssignmentExecuteService.canExecuteAssignment";
import { updateRecord } from "lightning/uiRecordApi";
export default class Fec_AssignmentExecuteVisibility extends LightningElement {
  @api recordId;

  @wire(canExecute, { caseId: "$recordId" })
  wiredResult({ data, error }) {
    if (data !== undefined) {
      this.updateField(data);
    }
  }

  async updateField(value) {
    const fields = {
      Id: this.recordId,
      FEC_Can_Execute_Assignment__c: value,
    };

    try {
      await updateRecord({ fields });
    } catch (e) {
      console.error(e);
    }
  }
}