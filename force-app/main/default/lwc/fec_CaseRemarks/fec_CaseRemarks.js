import { LightningElement, api, track } from "lwc";

import getRemarklst from "@salesforce/apex/FEC_CaseRemarkController.getRemarklst";
import createRemark from "@salesforce/apex/FEC_CaseRemarkController.createRemark";
import submitRemark from "@salesforce/apex/FEC_CaseRemarkController.submitRemark";

import { formatDate } from "c/fec_CommonUtils";

export default class Fec_CaseRemarks extends LightningElement {
  @api caseId;

  @track remarklst = [];

  remarkColumnlst = [
    { label: "Case Remarks", fieldName: "FEC_Case_Remarks__c" },
    { label: "Stage Name", fieldName: "FEC_Stage_Name__c" },
    { label: "User", fieldName: "FEC_User__c" },
    { label: "User Role", fieldName: "FEC_User_Role__c" },
    { label: "Created Date", fieldName: "CreatedDate" }
  ];

  loadRemarklst = false;

  connectedCallback() {
    getRemarklst({ caseId: this.caseId })
      .then((res) => {
        this.remarklst = res.map((item) => ({
          ...item,
          CreatedDate: formatDate(item.CreatedDate)
        }));

        this.loadRemarklst = true;
      })
      .catch((err) => {
        console.log("🚀 ~ Fec_CaseRemarks ~ connectedCallback ~ err:", err);
      })
      .finally(() => {});
  }

  @api validate() {
    const textarea = this.template.querySelector("lightning-textarea");

    if (!textarea || !textarea.value) {
      return false;
    }

    return true;
  }

  @api async createRemark() {
    const textarea = this.template.querySelector("lightning-textarea");

    let result;
    if (textarea) {
      result = await createRemark({
        remark: textarea.value,
        caseId: this.caseId
      });
    }

    return result;
  }

  @api async submitRemark() {
    await submitRemark({ caseId: this.caseId });
  }
}