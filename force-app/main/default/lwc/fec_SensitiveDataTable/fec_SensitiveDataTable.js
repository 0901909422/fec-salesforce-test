import { LightningElement, api, track } from "lwc";
import getSensitiveData from "@salesforce/apex/FEC_InteractionInforHandler.getSensitiveData";
import { NavigationMixin } from "lightning/navigation";
import {
  getFocusedTabInfo,
  openSubtab,
  setTabLabel,
  setTabIcon,
} from "lightning/platformWorkspaceApi";

import { urlCmpWithRecordId } from "c/fec_CommonUtils";

const COLUMNS = [
  { label: "Section", fieldName: "FEC_Section__c" },
  { label: "Field Name", fieldName: "Name" },
  {
    label: "User",
    fieldName: "FEC_User__c",
  },
  {
    label: "User Role",
    fieldName: "FEC_User_Role__c",
  },
  {
    label: "Case ID",
    fieldName: "caseUrl",
    type: "url",
    typeAttributes: {
      label: { fieldName: "caseIdText" },
      target: "_self",
    },
  },
  {
    label: "Date Time",
    fieldName: "formattedDate",
  },
];

export default class Fec_SensitiveDataTable extends NavigationMixin(
  LightningElement,
) {
  @api recordId;

  @track rows = [];
  columns = COLUMNS;
  total = 0;
  connectedCallback() {
    this.fetchSensitiveData();
  }

  fetchSensitiveData() {
    getSensitiveData({ recordId: this.recordId })
      .then((data) => {
        console.log("Fetched sensitive data:", data);

        this.rows = data.map((row) => {
          const { caseUrl, caseIdText } = this.parseAnchor(row.FEC_Case_ID__c);

          return {
            ...row,
            caseUrl,
            caseIdText,
            formattedDate: this.formatDate(row.CreatedDate),
          };
        });

        this.total = data.length;
      })
      .catch((error) => {
        console.error("Error fetching sensitive data:", error);
      });
  }

  get showViewAll() {
    return this.total > 0;
  }

  async handleViewAll() {
    console.log("handleViewAll");
    const focusedTab = await getFocusedTabInfo();
    console.log("focusedTab:", JSON.stringify(focusedTab));

    const subtabId = await openSubtab(focusedTab.tabId, {
      url: urlCmpWithRecordId("fec_SensitiveDataViewAll", this.recordId),
      focus: true,
    });
    await setTabLabel(subtabId, "Sensitive Data - View All");
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

  parseAnchor(html) {
    if (!html) return { caseUrl: "", caseIdText: "" };

    const doc = new DOMParser().parseFromString(html, "text/html");
    const a = doc.querySelector("a");

    return {
      caseUrl: a?.getAttribute("href") || "",
      caseIdText: a?.textContent || "",
    };
  }
}