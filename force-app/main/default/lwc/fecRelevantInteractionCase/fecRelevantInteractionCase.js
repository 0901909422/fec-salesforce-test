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

//============================== Lablels ==============================
import FEC_CASE_LIST_LABEL from "@salesforce/label/c.FEC_Case_List_Label";
import FEC_RELEVANT_CASES_LABEL from "@salesforce/label/c.FEC_Relevant_Cases_Label";
import FEC_RELEVANT_INTERACTION_LABEL from "@salesforce/label/c.FEC_Relevant_Interactions_Label";

import FEC_CASE_ID_LABEL from "@salesforce/label/c.FEC_Case_ID_Label";
import FEC_CASE_STATUS_LABEL from "@salesforce/label/c.FEC_Case_Status_Label";
import FEC_SUB_CATEGORY_LABEL from "@salesforce/label/c.FEC_Sub_Category_Label";
import FEC_SUB_CODE_LABEL from "@salesforce/label/c.FEC_Sub_Code_Label";
import FEC_VIEW_ALL_BTN_LABEL from "@salesforce/label/c.FEC_View_All_Btn_Label";

import { urlCmpWithRecordId } from 'c/fec_CommonUtils';
import { DIV_ELEMENT, ICON_CASE } from "c/fec_CommonConst";

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
export default class FecRelevantInteractionCase extends NavigationMixin(
  LightningElement,
) {

  labels = {
    caseList: FEC_CASE_LIST_LABEL,
    viewAllBtn: FEC_VIEW_ALL_BTN_LABEL,
  };
  @api recordId;

  caseList = [];
  total = 0;
  columns = COLUMNS;
  interactionTabLabel = FEC_RELEVANT_INTERACTION_LABEL;
  caseTabLabel = FEC_RELEVANT_CASES_LABEL;

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

  async handleViewAll() {
    const focusedTab = await getFocusedTabInfo();
    console.log("focusedTab:", JSON.stringify(focusedTab));

    const subtabId = await openSubtab(focusedTab.tabId, {
      url: urlCmpWithRecordId("fec_RelevantInteractionCaseListViewAll", this.recordId),
      focus: true,
    });
    await setTabLabel(subtabId, "Cases List - View All");
    await setTabIcon(subtabId, ICON_CASE, "Cases");
  }

  // ===== Utils =====
  getPlainCaseId(htmlString) {
    if (!htmlString) return "";
    const div = document.createElement(DIV_ELEMENT);
    div.innerHTML = htmlString;
    return div.textContent || div.innerText || "";
  }
}
