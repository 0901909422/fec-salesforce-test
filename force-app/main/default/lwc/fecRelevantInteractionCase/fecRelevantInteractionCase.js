import { LightningElement, api, track, wire } from "lwc";
import getCaseList from "@salesforce/apex/FEC_InteractionInforHandler.getCaseList";
import getCaseTotal from "@salesforce/apex/FEC_InteractionInforHandler.getCaseTotal";
import { NavigationMixin } from "lightning/navigation";
import {
  getFocusedTabInfo,
  openSubtab,
  setTabLabel,
  setTabIcon,
} from "lightning/platformWorkspaceApi";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";

import ISCLOSED from "@salesforce/schema/Case.IsClosed";
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
export default class FecRelevantInteractionCase extends NavigationMixin(
  LightningElement,
) {
  @api recordId;

  caseList = [];
  total = 0;
  columns = COLUMNS;
  interactionTabLabel = "Relevant Interactions";
  caseTabLabel = "Relevant Cases";
  
  closedStatus = false;

  @wire(getRecord, {
    recordId: "$recordId",
    fields: [ISCLOSED],
  })
  wiredClosedStatus({ data, error }) {
    if (data) {
      this.closedStatus = getFieldValue(data, ISCLOSED);
    } else if (error) {
      console.error("Load error", error);
    }
  }

  @wire(getCaseList, { recordId: "$recordId" })
  wiredData({ data }) {
    console.log("wiredData - data:", data);
    if (data) {
      this.caseList = data.map((c) => ({
        ...c,
        caseUrl: `/${c.Id}`,
        caseIdText: this.getPlainCaseId(c.FEC_Case_ID__c),
        subCategoryName: c.FEC_SubCategory__r?.FEC_Name_VN__c,
        subCategoryCode: c.FEC_SubCategory__r?.FEC_Code__c,
        subCodeName: c.FEC_SubCode__r?.FEC_Name_VN__c,
        subCodeCode: c.FEC_SubCode__r?.FEC_Code__c,
      }));
      console.log("list cases data:", this.caseList);
    }
  }

  @wire(getCaseTotal, { recordId: "$recordId" })
  wiredCaseTotal({ data, error }) {
    if (data !== undefined) {
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
    this.caseList = this.caseList.map((i) =>
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
    const focusedTab = await getFocusedTabInfo();
    console.log("focusedTab:", JSON.stringify(focusedTab));

    const subtabId = await openSubtab(focusedTab.tabId, {
      // pageReference: {
      //   type: "standard__appPage",
      //   attributes: {
      //     appPageName: "FEC_View_All_Relevant_Interaction_Cases",
      //   },
      //   state: {
      //     c__recordId: this.recordId,
      //   },
      // },
      // focus: true,
      url: `/lightning/cmp/c__fec_RelevantInteractionCaseListViewAll?c__recordId=${this.recordId}`,
      focus: true,
    });
    await setTabLabel(subtabId, "Cases List - View All");
    await setTabIcon(subtabId, "standard:case", "Cases");

    // await openSubtab(focusedTab.tabId, {
    //   pageReference: {
    //     type: "standard__appPage",
    //     attributes: {
    //       appPageName: "FEC_View_All_Relevant_Interaction_Cases",
    //     },
    //     state: {
    //       recordId: this.recordId,
    //     },
    //   },
    //   focus: true,
    // });
  }

  // ===== Utils =====
  getPlainCaseId(htmlString) {
    if (!htmlString) return "";
    const div = document.createElement("div");
    div.innerHTML = htmlString;
    return div.textContent || div.innerText || "";
  }
}
