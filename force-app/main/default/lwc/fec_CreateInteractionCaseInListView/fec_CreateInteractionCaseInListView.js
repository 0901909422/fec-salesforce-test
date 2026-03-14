import { LightningElement, wire, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import {
  IsConsoleNavigation,
  getFocusedTabInfo,
  closeTab,
  openTab,
  refreshTab,
} from "lightning/platformWorkspaceApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import {} from "lightning/platformWorkspaceApi";
import createInteractionManual from "@salesforce/apex/FEC_CreateInteractionManualHandler.createInteractionManual";

export default class Fec_CreateCaseInListView extends NavigationMixin(
  LightningElement,
) {
  @api recordId;

  isShowModal = true;

  channelOptions = [
    { label: "Inbound", value: "Inbound" },
    { label: "Outbound", value: "Outbound" },
    { label: "Email", value: "Email" },
    { label: "Chat", value: "Chat" },
    { label: "F2F", value: "F2F" },
    { label: "Letter", value: "Letter" },
    { label: "Internal", value: "Internal" },
    { label: "External", value: "External" },
  ];

  subChannelMap = {
    Inbound: [{ label: "Inbound Call", value: "Inbound Call" }],

    Outbound: [{ label: "Outbound Call", value: "Outbound Call" }],

    Email: [
      { label: "Incoming Email", value: "Incoming Email" },
      { label: "Outgoing Email", value: "Outgoing Email" },
    ],

    Chat: [
      { label: "Facebook", value: "Facebook" },
      { label: "Zalo", value: "Zalo" },
      { label: "Website", value: "Website" },
      { label: "Mobile App", value: "Mobile App" },
    ],

    F2F: [{ label: "F2F", value: "F2F" }],

    Letter: [{ label: "Letter", value: "Letter" }],

    Internal: [
      { label: "Internal Email", value: "Internal Email" },
      { label: "iCollect", value: "iCollect" },
      { label: "iSale", value: "iSale" },
      { label: "VTiger", value: "VTiger" },
    ],

    External: [
      { label: "PR/MKT", value: "PR/MKT" },
      { label: "SBV", value: "SBV" },
      { label: "EA", value: "EA" },
      { label: "VPBank", value: "VPBank" },
      { label: "Website", value: "Website" },
      { label: "Zalo", value: "Zalo" },
      { label: "Mobile App", value: "Mobile App" },
    ],
  };

  selectedChannel;
  selectedSubChannel;
  subChannelOptions = [];

  @wire(IsConsoleNavigation) isConsoleNavigation;
  //   @wire(EnclosingTabId) enclosingTabId;

  async closeTab() {
    if (!this.isConsoleNavigation) return;
    const { tabId } = await getFocusedTabInfo();
    await closeTab(tabId);
  }

  handleChannelChange(event) {
    this.selectedChannel = event.detail.value;
    // clear error
    event.target.setCustomValidity("");
    event.target.reportValidity();
    this.subChannelOptions = this.subChannelMap[this.selectedChannel] || [];

    this.selectedSubChannel = null;
  }

  handleSubChannelChange(event) {
    this.selectedSubChannel = event.detail.value;
    // clear error
    event.target.setCustomValidity("");
    event.target.reportValidity();
  }

  async handleNext() {
    // if (!this.selectedChannel || !this.selectedSubChannel) {
    //   this.showToast(
    //     "Error",
    //     "Please select both Channel and Sub-Channel",
    //     "error",
    //   );
    //   return;
    // }

    const fields = this.template.querySelectorAll("lightning-combobox");

    let isValid = true;

    fields.forEach((field) => {
      if (!field.value) {
        field.setCustomValidity("Complete this field.");
        isValid = false;
      } else {
        field.setCustomValidity("");
      }

      field.reportValidity();
    });

    if (!isValid) {
      return;
    }

    createInteractionManual({
      channel: this.selectedChannel,
      subChannel: this.selectedSubChannel,
    })
      .then(async (result) => {
        const caseId = result.caseId;
        const linkId = result.linkId;
        const caseNo = result.caseNo;

        console.log("Case Id:", caseId);
        console.log("Link Id:", linkId);
        console.log("Case No:", caseNo);

        this.showToast(
          "Success",
          `Interaction ${caseNo} created successfully`,
          "success",
        );

        this.isShowModal = false;
        await this.closeTab();
        const recordUrl = `/lightning/r/Case/${caseId}/view`;
        window.open(recordUrl, "_self");
      })
      .catch((error) => {
        this.showToast(
          "Error",
          error?.body?.message || "Failed to create Interaction",
          "error",
        );
      });
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  async handleClose() {
    this.isShowModal = false;
    this[NavigationMixin.Navigate]({
      type: "standard__objectPage",
      attributes: {
        objectApiName: "Case",
        actionName: "list",
      },
    });
    await this.closeTab();
  }
}
