import { LightningElement, api, track } from "lwc";

import getRemarklst from "@salesforce/apex/FEC_CaseRemarkController.getRemarklst";
import createRemark from "@salesforce/apex/FEC_CaseRemarkController.createRemark";
import submitRemark from "@salesforce/apex/FEC_CaseRemarkController.submitRemark";

import { formatDate } from "c/fec_CommonUtils";

export default class Fec_CaseRemarks extends LightningElement {
  @api caseId;

  _isEdit = false;
  @api get isEdit() {
    return this._isEdit;
  }
  set isEdit(value) {
    const prev = this._isEdit;
    this._isEdit = Boolean(value);
    // Khi chuyển sang edit (vd: Execute sau Submit) → refetch để không còn autofill draft cũ
    if (this._isEdit && !prev) {
      this.loadRemarks();
    }
  }

  @track remarklst = [];
  @track draftRemarkValue = "";

  remarkColumnlst = [
    { label: "Case Remarks", fieldName: "FEC_Case_Remarks__c" },
    { label: "Stage Name", fieldName: "FEC_Stage_Name__c" },
    { label: "User", fieldName: "FEC_User__c" },
    { label: "User Role", fieldName: "FEC_User_Role__c" },
    { label: "Created Date", fieldName: "CreatedDate" }
  ];

  loadRemarklst = false;

  connectedCallback() {
    this.loadRemarks();
  }

  /** Gọi lại getRemarklst (sau Submit + Execute để lấy dữ liệu mới, không draft cũ). */
  @api refresh() {
    this.loadRemarks();
  }

  loadRemarks() {
    if (!this.caseId) return;
    getRemarklst({ caseId: this.caseId })
      .then((res) => {
        const draftItems = res.filter((item) => !item.Id);
        const latestDraft =
          draftItems.length > 0 ? draftItems[draftItems.length - 1] : null;
        this.draftRemarkValue = latestDraft
          ? latestDraft.FEC_Case_Remarks__c || ''
          : '';

        this.remarklst = res
          .filter((item) => item.Id)
          .map((item) => ({
            ...item,
            CreatedDate: formatDate(item.CreatedDate),
          }));

        this.loadRemarklst = true;
      })
      .catch((err) => {
        console.log("🚀 ~ Fec_CaseRemarks ~ loadRemarks ~ err:", err);
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
    const remarkText =
      (textarea && textarea.value) || this.draftRemarkValue || "";

    let result;
    if (this.caseId && remarkText !== undefined) {
      result = await createRemark({
        remark: remarkText,
        caseId: this.caseId
      });
    }

    return result;
  }

  @api async submitRemark() {
    await submitRemark({ caseId: this.caseId });
  }

  handleRemarkInput(e) {
    this.draftRemarkValue = e.target.value;
  }
}