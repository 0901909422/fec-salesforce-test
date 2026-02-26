import { LightningElement, api, wire } from "lwc";
import getRelevantCases from "@salesforce/apex/FEC_InteractionInforHandler.getRelevantCases";
import getRelevantCasesViewAllCount from "@salesforce/apex/FEC_InteractionInforHandler.getRelevantCasesViewAllCount";
import { NavigationMixin } from "lightning/navigation";
import {
  getFocusedTabInfo,
  openSubtab,
  setTabLabel,
  setTabIcon,
} from "lightning/platformWorkspaceApi";

//============================== Labels ==============================
import FEC_RELEVANT_CASES_LABEL from "@salesforce/label/c.FEC_Relevant_Cases_Label";
import FEC_CASE_ID_LABEL from "@salesforce/label/c.FEC_Case_ID_Label";
import FEC_CASE_STATUS_LABEL from "@salesforce/label/c.FEC_Case_Status_Label";
import FEC_SUB_CATEGORY_LABEL from "@salesforce/label/c.FEC_Sub_Category_Label";
import FEC_SUB_CODE_LABEL from "@salesforce/label/c.FEC_Sub_Code_Label";
import FEC_VIEW_ALL_BTN_LABEL from "@salesforce/label/c.FEC_View_All_Btn_Label";

import { urlCmpWithRecordId } from "c/fec_CommonUtils";

const COLUMNS = [
  {
    label: FEC_CASE_ID_LABEL,
    fieldName: "caseUrl",
    type: "url",
    typeAttributes: {
      label: { fieldName: "caseIdText" },
      target: "_self",
    },
  },
  { label: FEC_CASE_STATUS_LABEL, fieldName: "FEC_Case_Status__c" },
  {
    label: FEC_SUB_CATEGORY_LABEL,
    fieldName: "subCategoryName",
  },
  {
    label: FEC_SUB_CODE_LABEL,
    fieldName: "subCodeName",
  },
];

export default class FecRelevantCaseCard extends NavigationMixin(
  LightningElement,
) {
  labels = {
    caseList: FEC_RELEVANT_CASES_LABEL,
    viewAllBtn: FEC_VIEW_ALL_BTN_LABEL,
  };

  @api recordId;
  columns = COLUMNS;
  cases = [];
  total = 0;

  @wire(getRelevantCases, { recordId: "$recordId" })
  wiredData({ data }) {
    if (data) {
      console.log("relevant cases raw data:", data);
      this.cases = data.map((c) => ({
        ...c,
        caseUrl: `/${c.Id}`,
        caseIdText: this.getPlainCaseId(c.FEC_Case_ID__c),
        subCategoryName: c.FEC_SubCategory__r?.FEC_Name_VN__c,
        subCategoryCode: c.FEC_SubCategory__r?.FEC_Code__c,
        subCodeName: c.FEC_SubCode__r?.FEC_Name_VN__c,
        subCodeCode: c.FEC_SubCode__r?.FEC_Code__c,
      }));
      console.log("relevant cases data:", this.cases);
    }
  }

  @wire(getRelevantCasesViewAllCount, { recordId: "$recordId" })
  wiredRelevantCasesViewAllCount({ data, error }) {
    if (data !== undefined) {
      console.log("relevant cases view all count:", data);
      this.total = data;
    } else if (error) {
      console.error("Error loading case total:", error);
    }
  }

  get showViewAll() {
    return this.total > 0;
  }

  toggle(event) {
    console.log("toggle called");
    console.log(event.currentTarget.dataset.id);
    const id = event.currentTarget.dataset.id;
    this.cases = this.cases.map((i) =>
      i.Id === id ? { ...i, open: !i.open } : i,
    );
  }

  async handleViewAll() {
    console.log("View All Relevant Cases clicked");
    const focusedTab = await getFocusedTabInfo();
    console.log("focusedTab:", JSON.stringify(focusedTab));

    const subtabId = await openSubtab(focusedTab.tabId, {
      url: urlCmpWithRecordId("fec_RelevantCaseListViewAll", this.recordId),
      focus: true,
    });
    await setTabLabel(subtabId, "Relevant Cases - View All");
    await setTabIcon(subtabId, "standard:case", "Cases");
  }

  // ===== Utils =====
  getPlainCaseId(htmlString) {
    if (!htmlString) return "";
    const div = document.createElement("div");
    div.innerHTML = htmlString;
    return div.textContent || div.innerText || "";
  }
}
