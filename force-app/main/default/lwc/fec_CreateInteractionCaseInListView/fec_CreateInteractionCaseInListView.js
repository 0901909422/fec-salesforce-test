import { LightningElement, wire, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import {
  IsConsoleNavigation,
  getFocusedTabInfo,
  closeTab,
  openTab,
} from "lightning/platformWorkspaceApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import createInteractionManual from "@salesforce/apex/FEC_CreateInteractionManualHandler.createInteractionManual";
import getCurrentUserProfileName from '@salesforce/apex/FEC_SearchController.getCurrentUserProfileName';
import { CHANNEL_OPTIONS, SUB_CHANNEL_MAP, PROFILE_RELEVANT_DEPTS } from "c/fec_CommonConst";

//==================== LABELS ====================
import FEC_CREATE_INTERACTION_LABEL from "@salesforce/label/c.FEC_Create_Interaction_In_List_View_Label";
import FEC_Interaction_Information_Label from "@salesforce/label/c.FEC_Interaction_Information_Label";
import FEC_INTERACTION_CHANNEL_LABEL from "@salesforce/label/c.FEC_Interaction_Channel_Label";
import FEC_INTERACTION_SUB_CHANNEL_LABEL from "@salesforce/label/c.FEC_Interaction_Sub_Channel_Label";
import CANCEL_BUTTON_LABEL from "@salesforce/label/c.Cancel";
import NEXT_BUTTON_LABEL from "@salesforce/label/c.FEC_Next_Btn_Label";
import FEC_Complete_field_msg from "@salesforce/label/c.FEC_Complete_field_msg";
import FEC_Create_Interaction_Failed_MSG from "@salesforce/label/c.FEC_Create_Interaction_Failed_MSG";
import FEC_Interaction_Title_Label from "@salesforce/label/c.FEC_Interaction_Title_Label";
import FEC_Create_Successfully_MSG from "@salesforce/label/c.FEC_Create_Successfully_MSG";
import FEC_No_Permission_Msg from '@salesforce/label/c.FEC_No_Permission_Msg';

export default class Fec_CreateCaseInListView extends NavigationMixin(
  LightningElement,
) {
  @api recordId;

  isShowModal = true;
  isLoading = false;
  _userProfile;

  channelOptions = CHANNEL_OPTIONS;
  subChannelOptions = [];

  selectedChannel;
  selectedSubChannel;

  @wire(IsConsoleNavigation) isConsoleNavigation;
  @wire(getCurrentUserProfileName)
  wiredProfile({ data }) {
    if (data) this._userProfile = data;
  }

  currentTabId;
  newCaseId;
  get isConsole() {
    return this.isConsoleNavigation?.data === true;
  }

  labels = {
    createInteraction: FEC_CREATE_INTERACTION_LABEL,
    channel: FEC_INTERACTION_CHANNEL_LABEL,
    subChannel: FEC_INTERACTION_SUB_CHANNEL_LABEL,
    interactionInformation: FEC_Interaction_Information_Label,
    next: NEXT_BUTTON_LABEL,
    cancel: CANCEL_BUTTON_LABEL,
  };

  async connectedCallback() {
    try {
      const { tabId } = await getFocusedTabInfo();
      this.currentTabId = tabId;
    } catch (e) {}
    // Check profile on every mount (wire is cached, connectedCallback always runs)
    try {
      const profile = await getCurrentUserProfileName();
      this._userProfile = profile;
      if (profile === PROFILE_RELEVANT_DEPTS) {
        this.isShowModal = false;
        this.dispatchEvent(new ShowToastEvent({ title: 'Lỗi', message: FEC_No_Permission_Msg, variant: 'error' }));
        // Get current tab BEFORE navigating
        let tabToClose = this.currentTabId;
        if (!tabToClose) {
          try { const { tabId } = await getFocusedTabInfo(); tabToClose = tabId; } catch(e) {}
        }
        this[NavigationMixin.Navigate]({
          type: 'standard__objectPage',
          attributes: { objectApiName: 'Case', actionName: 'list' }
        });
        setTimeout(async () => {
          try { if (tabToClose) await closeTab(tabToClose); } catch(e) {}
        }, 3000);
      }
    } catch(e) {}
  }

  async handleCloseTab() {
    if (!this.isConsoleNavigation) return;
    const { tabId } = await getFocusedTabInfo();
    await closeTab(tabId);
  }
  /* -----------------------------
     EVENT HANDLERS
  ------------------------------ */

  handleChannelChange(event) {
    this.selectedChannel = event.detail.value;

    event.target.setCustomValidity("");
    event.target.reportValidity();

    this.subChannelOptions = SUB_CHANNEL_MAP[this.selectedChannel] || [];
    this.selectedSubChannel = null;
  }

  handleSubChannelChange(event) {
    this.selectedSubChannel = event.detail.value;

    event.target.setCustomValidity("");
    event.target.reportValidity();
  }

  /* -----------------------------
     ACTION
  ------------------------------ */

  async handleNext() {
    if (this.isLoading) return;

    const fields = this.template.querySelectorAll("lightning-combobox");
    let isValid = true;

    fields.forEach((field) => {
      if (!field.value) {
        field.setCustomValidity(FEC_Complete_field_msg);
        isValid = false;
      } else {
        field.setCustomValidity("");
      }
      field.reportValidity();
    });

    if (!isValid) return;

    this.isLoading = true;

    try {
      const result = await createInteractionManual({
        channel: this.selectedChannel,
        subChannel: this.selectedSubChannel,
      });

      const newCaseId = result.caseId;
      const caseNo = result.caseNo;
      this.showToast(
        "Success",
        `${FEC_Interaction_Title_Label} ${caseNo} ${FEC_Create_Successfully_MSG}`,
        "success",
      );
      this.isShowModal = false;
      this.newCaseId = newCaseId;
      await this.handleClose();
    } catch (error) {
      this.showToast(
        "Error",
        error?.body?.message || FEC_Create_Interaction_Failed_MSG,
        "error",
      );
    } finally {
      this.isLoading = false;
    }
  }

  /* -----------------------------
     NAVIGATION (FIXED)
  ------------------------------ */

  async handleClose() {
    this.isShowModal = false;

    let tabToClose = this.currentTabId;
    if (!tabToClose) {
      try {
        const { tabId } = await getFocusedTabInfo();
        tabToClose = tabId;
      } catch (e) {}
    }

    this[NavigationMixin.Navigate]({
      type: "standard__objectPage",
      attributes: {
        objectApiName: "Case",
        actionName: "list",
      },
    });

    await new Promise((resolve) => setTimeout(resolve, 2000));

    await openTab({
      recordId: this.newCaseId,
      focus: true,
    });

    setTimeout(async () => {
      if (tabToClose) {
        await closeTab(tabToClose);
      }
    }, 1000);
  }

  /* -----------------------------
     CLOSE HANDLERS
  ------------------------------ */

  async handleCloseButton() {
    this.isShowModal = false;

    this[NavigationMixin.Navigate]({
      type: "standard__objectPage",
      attributes: {
        objectApiName: "Case",
        actionName: "list",
      },
    });

    await this.handleCloseTab();
  }

  /* -----------------------------
     UTIL
  ------------------------------ */

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  _showNoPermissionToast() {
    this.dispatchEvent(new ShowToastEvent({ title: 'Lỗi', message: FEC_No_Permission_Msg, variant: 'error' }));
  }
}