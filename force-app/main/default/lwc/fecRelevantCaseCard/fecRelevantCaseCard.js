import { LightningElement, api, wire } from "lwc";
import getRelevantCases from "@salesforce/apex/FEC_InteractionInforHandler.getRelevantCases";
import getRelevantCasesViewAllCount from "@salesforce/apex/FEC_InteractionInforHandler.getRelevantCasesViewAllCount";
// import getSubCategory from "@salesforce/apex/FEC_InteractionInforHandler.getSubCategory";
// import getSubCode from "@salesforce/apex/FEC_InteractionInforHandler.getSubCode";
import { NavigationMixin } from "lightning/navigation";
import {
  getFocusedTabInfo,
  openSubtab,
  setTabLabel,
  setTabIcon,
} from "lightning/platformWorkspaceApi";

const COLUMNS = [
  {
    label: "Case ID",
    fieldName: "caseUrl",
    type: "url",
    typeAttributes: {
      label: { fieldName: "caseIdText" },
      target: "_self",
    },
  },
  { label: "Case Status", fieldName: "FEC_Case_Status__c" },
  {
    label: "Sub Category",
    fieldName: "subCategoryName",
  },
  {
    label: "Sub Code",
    fieldName: "subCodeName",
  },
];

export default class FecRelevantCaseCard extends NavigationMixin(
  LightningElement,
) {
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

  formatDate(dateString) {
    if (!dateString) return "";
    const d = new Date(dateString);
    return d.toLocaleString("en-GB", {
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    });
  }

  async handleViewAll() {
    console.log("View All Relevant Cases clicked");
    const focusedTab = await getFocusedTabInfo();
    console.log("focusedTab:", JSON.stringify(focusedTab));

    const subtabId = await openSubtab(focusedTab.tabId, {
      url: `/lightning/cmp/c__fec_RelevantCaseListViewAll?c__recordId=${this.recordId}`,
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
