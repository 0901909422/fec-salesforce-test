import { LightningElement, wire } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import {
  IsConsoleNavigation,
  getAllTabInfo,
  openSubtab,
  openTab,
  closeTab,
  getFocusedTabInfo
} from "lightning/platformWorkspaceApi";
import { publish, MessageContext } from "lightning/messageService";
import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";
import createCustomerCaseFromCase from "@salesforce/apex/FEC_CreateCaseInteractionController.createCustomerCaseFromCase";
import createCustomerCaseFromCaseNonExistingCustomer from "@salesforce/apex/FEC_CreateCaseInteractionController.createCustomerCaseFromCaseNonExistingCustomer";
// import { getRecord, getFieldValue } from "lightning/uiRecordApi";
// import resetViewMode from "@salesforce/apex/FEC_InteractionInforHandler.resetViewMode";
// import VIEW_MODE from "@salesforce/schema/Case.FEC_Interaction_View_Mode__c";

export default class Fec_InteractionCreateCase extends NavigationMixin(
  LightningElement,
) {
  isLoading = false;
  // viewMode; // handling | review
  // _resetDone = false;
  @wire(CurrentPageReference)
  pageRef;

  @wire(IsConsoleNavigation)
  isConsoleNavigation;

  @wire(MessageContext)
  messageContext;

  // @wire(getRecord, {
  //   recordId: "$recordId",
  //   fields: [VIEW_MODE],
  // })
  // wiredViewMode({ data }) {
  //   if (data) {
  //     this.viewMode = getFieldValue(data, VIEW_MODE);
  //   }
  // }

  get recordId() {
    // Access parameters via the 'state' object
    return this.pageRef ? this.pageRef.state.c__recordId : null;
  }

  get customerName() {
    // Access parameters via the 'state' object
    return this.pageRef ? this.pageRef.state.c__customerName : null;
  }

  get identityNo() {
    // Access parameters via the 'state' object
    return this.pageRef ? this.pageRef.state.c__identityNo : null;
  }

  get isCreatedFromSearch() {
    // Access parameters via the 'state' object
    return this.pageRef ? this.pageRef.state.c__isCreatedFromSearch : null;
  }

  get isNonExistingCustomer() {
    if (this.customerName != null) {
      return true;
    } else {
      return false;
    }
  }

  async connectedCallback() {
    if (!this.recordId) {
      console.error("recordId is undefined");
      return;
    }

    this.isLoading = true;
    if (!this.isNonExistingCustomer) {
      createCustomerCaseFromCase({ caseId: this.recordId })
        .then(async (newCaseId) => {
          await this.handlePublishMessageChanel();
          this.isLoading = false;
          if (this.isConsoleNavigation) {
            const focusedTab = await getFocusedTabInfo();
            const currentTabId = focusedTab.tabId;

            if (focusedTab.parentTabId) {
              await openSubtab(focusedTab.parentTabId, {
                recordId: newCaseId,
                focus: true,
              });
            } else {
              await openTab({
                recordId: newCaseId,
                focus: true,
              });
            }

            await closeTab(currentTabId);
            // await this.handlePublishMessageChanel();
          } else {
            this[NavigationMixin.Navigate]({
              type: "standard__recordPage",
              attributes: {
                recordId: newCaseId,
                objectApiName: "Case",
                actionName: "view",
              },
            });
            // if (this.recordId) {
            //   await resetViewMode({ recordId: this.recordId, viewMode: "handling" });
            // }
          }
        })
        .catch((error) => {
          this.isLoading = false;
          console.error(error);
        });
    } else {
      createCustomerCaseFromCaseNonExistingCustomer({
        caseId: this.recordId,
        customerName: this.customerName,
        nationalPassportId: this.identityNo,
        isCreatedFromSearch: this.isCreatedFromSearch
      })
        .then(async (newCaseId) => {
          await this.handlePublishMessageChanel();
          this.isLoading = false;
          if (this.isConsoleNavigation) {
            const focusedTab = await getFocusedTabInfo();
            const currentTabId = focusedTab.tabId;

            if (focusedTab.parentTabId) {
              await openSubtab(focusedTab.parentTabId, {
                recordId: newCaseId,
                focus: true,
              });
            } else {
              await openTab({
                recordId: newCaseId,
                focus: true,
              });
            }

            await closeTab(currentTabId);
            // await this.handlePublishMessageChanel();
          } else {
            this[NavigationMixin.Navigate]({
              type: "standard__recordPage",
              attributes: {
                recordId: newCaseId,
                objectApiName: "Case",
                actionName: "view",
              },
            });
          }
          // if (this.recordId) {
          //     await resetViewMode({ recordId: this.recordId, viewMode: "handling" });
          //   }
        })
        
        .catch((error) => {
          this.isLoading = false;
          console.error(error);
        });
    }
  }

  async handlePublishMessageChanel() {
    const payload = {
      isModeEdit: true,
    };
    publish(this.messageContext, IS_MODE_EDIT, payload);
  }
}