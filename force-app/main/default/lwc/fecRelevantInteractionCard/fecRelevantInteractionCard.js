import { LightningElement, api, wire } from "lwc";
import getRelevantInteractions from "@salesforce/apex/FEC_InteractionInforHandler.getRelevantInteractions";
import getRelevantInteractionsViewAllCount from "@salesforce/apex/FEC_InteractionInforHandler.getRelevantInteractionsViewAllCount";
import { NavigationMixin } from "lightning/navigation";
import {
  getFocusedTabInfo,
  openSubtab,
  setTabLabel,
  setTabIcon,
} from "lightning/platformWorkspaceApi";

//============================== Labels ==============================
import FEC_VIEW_ALL_BTN_LABEL from "@salesforce/label/c.FEC_View_All_Btn_Label";
import FEC_RELEVANT_INTERACTION_LABEL from "@salesforce/label/c.FEC_Relevant_Interactions_Label";
import FEC_INTERACTION_ID_LABEL from "@salesforce/label/c.FEC_Interaction_ID";
import FEC_INTERACTION_CREATED_ON_LABEL from "@salesforce/label/c.FEC_Interaction_Created_On_Label";
import FEC_INTERACTION_CHANNEL_LABEL from "@salesforce/label/c.FEC_Interaction_Channel_Label";

import { formatDateTime, urlCmpWithRecordId } from 'c/fec_CommonUtils';

const COLUMNS = [
  {
    label: FEC_INTERACTION_ID_LABEL,
    fieldName: "caseUrl",
    type: "url",
    typeAttributes: {
      label: { fieldName: "caseIdText" },
      target: "_self",
    },
  },
  { label: FEC_INTERACTION_CHANNEL_LABEL, fieldName: "FEC_Channel__c" },
  {
    label: FEC_INTERACTION_CREATED_ON_LABEL,
    fieldName: "formattedCreatedOn",
  },
];

export default class FecRelevantInteractionCard extends NavigationMixin(
  LightningElement,
) {

  labels = {
    viewAllBtn: FEC_VIEW_ALL_BTN_LABEL,
    relevantInteraction: FEC_RELEVANT_INTERACTION_LABEL,
  };

  @api recordId;

  interactions = [];
  total = 0;
  columns = COLUMNS;
  @wire(getRelevantInteractions, { recordId: "$recordId" })
  wiredData({ data }) {
    if (data) {
      this.interactions = data.map((i) => ({
        ...i,
        caseUrl: `/${i.Id}`,
        caseIdText: this.getPlainCaseId(i.FEC_Interaction_ID__c),
        formattedCreatedOn: formatDateTime(i.FEC_Created_On__c),
      }));
    }
  }

  @wire(getRelevantInteractionsViewAllCount, { recordId: "$recordId" })
  wiredRelevantInteractionsViewAllCount({ data, error }) {
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
    console.log(event.currentTarget.dataset.id);
    const id = event.currentTarget.dataset.id;
    this.interactions = this.interactions.map((i) =>
      i.Id === id ? { ...i, open: !i.open } : i,
    );
  }

  async handleViewAll() {
    const focusedTab = await getFocusedTabInfo();
    console.log("focusedTab:", JSON.stringify(focusedTab));

    const subtabId = await openSubtab(focusedTab.tabId, {
      url: urlCmpWithRecordId("fec_RelevantInteractionListViewAll", this.recordId),
      focus: true,
    });
    await setTabLabel(subtabId, "Relevant Interactions - View All");
    await setTabIcon(subtabId, "standard:case", "Cases");
  }

  getPlainCaseId(htmlString) {
    if (!htmlString) return "";
    const div = document.createElement("div");
    div.innerHTML = htmlString;
    return div.textContent || div.innerText || "";
  }
}
