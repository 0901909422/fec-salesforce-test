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

export default class FecRelevantInteractionCard extends NavigationMixin(
  LightningElement,
) {
  @api recordId;

  interactions = [];
  total = 0;

  @wire(getRelevantInteractions, { recordId: "$recordId" })
  wiredData({ data }) {
    if (data) {
      console.log("relevant interactions data:", data);
      this.interactions = data.map((i) => ({
        ...i,
        formattedCreatedOn: this.formatDate(i.FEC_Created_On__c),
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
    return this.total >= 5;
  }

  toggle(event) {
    console.log("toggle called");
    console.log(event.currentTarget.dataset.id);
    const id = event.currentTarget.dataset.id;
    this.interactions = this.interactions.map((i) =>
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
    console.log("View All Relevant Interactions clicked");
    const focusedTab = await getFocusedTabInfo();
    console.log("focusedTab:", JSON.stringify(focusedTab));

    const subtabId = await openSubtab(focusedTab.tabId, {
      url: `/lightning/cmp/c__fec_RelevantInteractionListViewAll?c__recordId=${this.recordId}`,
      focus: true,
    });
    await setTabLabel(subtabId, "Relevant Interactions - View All");
    await setTabIcon(subtabId, "standard:case", "Cases");
  }
}