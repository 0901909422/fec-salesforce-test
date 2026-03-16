import { LightningElement, wire, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import {
  IsConsoleNavigation,
  getFocusedTabInfo,
  closeTab,
} from "lightning/platformWorkspaceApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import createInteractionManual from "@salesforce/apex/FEC_CreateInteractionManualHandler.createInteractionManual";
import { CHANNEL_OPTIONS, SUB_CHANNEL_MAP } from "c/fec_CommonConst";

export default class Fec_CreateCaseInListView extends NavigationMixin(
  LightningElement,
) {
  @api recordId;
  isShowModal = true;
  channelOptions = CHANNEL_OPTIONS;
  subChannelOptions = [];

  selectedChannel;
  selectedSubChannel;

  @wire(IsConsoleNavigation) isConsoleNavigation;

  /* -----------------------------
   EVENT HANDLERS
  ------------------------------ */

  handleChannelChange(event) {
    this.selectedChannel = event.detail.value;
    // clear error
    event.target.setCustomValidity("");
    event.target.reportValidity();
    this.subChannelOptions = SUB_CHANNEL_MAP[this.selectedChannel] || [];

    this.selectedSubChannel = null;
  }

  handleSubChannelChange(event) {
    this.selectedSubChannel = event.detail.value;
    // clear error
    event.target.setCustomValidity("");
    event.target.reportValidity();
  }

  /* -----------------------------
   ACTION
  ------------------------------ */
  async handleNext() {
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

  async closeTab() {
    if (!this.isConsoleNavigation) return;
    const { tabId } = await getFocusedTabInfo();
    await closeTab(tabId);
  }
}
