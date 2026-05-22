import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import FEC_MRC_RL0502_Dup_Banner from "@salesforce/label/c.FEC_MRC_RL0502_Dup_Banner";
import FEC_MRC_RL0502_Dup_Opt_Cancel_New from "@salesforce/label/c.FEC_MRC_RL0502_Dup_Opt_Cancel_New";
import FEC_MRC_RL0502_Dup_Opt_Cancel_Prev from "@salesforce/label/c.FEC_MRC_RL0502_Dup_Opt_Cancel_Prev";
import { STR_EMPTY } from "c/fec_CommonConst";
import {
  FIELD_MRC_HANDLING_OPTION,
  MRC_OPT_CANCEL_NEW,
  MRC_OPT_CANCEL_PREVIOUS,
} from "c/fecMrcReturnCaseLogic";

export default class Fec_MrcReturnDupBanner extends NavigationMixin(
  LightningElement,
) {
  @api recordId;
  @api duplicateCaseId;
  @api duplicateCaseNumber;
  @api handlingOptionValue = STR_EMPTY;
  @api isEdit = false;
  @api sectionId;
  @api subSectionName;
  @api objId;
  /** standalone | inline */
  @api displayMode = "inline";

  get isReadOnly() {
    return this.isEdit === false;
  }

  get wrapperClass() {
    return this.displayMode === "standalone"
      ? "mrc-dup-standalone slds-m-top_small slds-p-horizontal_small"
      : "mrc-dup-inline slds-m-top_x-small";
  }

  get radioName() {
    return this.displayMode === "standalone"
      ? "mrcRl0502DupStandalone"
      : `mrcRl0502DupInline-${this.objId || this.recordId}`;
  }

  get mrcDupCaseNumber() {
    return String(this.duplicateCaseNumber ?? STR_EMPTY);
  }

  get mrcDupMessageBeforeLink() {
    const parts = (FEC_MRC_RL0502_Dup_Banner || STR_EMPTY).split("{0}");
    return parts[0] || STR_EMPTY;
  }

  get mrcDupMessageAfterLink() {
    const parts = (FEC_MRC_RL0502_Dup_Banner || STR_EMPTY).split("{0}");
    return parts.length > 1 ? parts.slice(1).join("{0}") : STR_EMPTY;
  }

  get mrcHandlingRadioOptions() {
    return [
      {
        label: FEC_MRC_RL0502_Dup_Opt_Cancel_New,
        value: MRC_OPT_CANCEL_NEW,
      },
      {
        label: FEC_MRC_RL0502_Dup_Opt_Cancel_Prev,
        value: MRC_OPT_CANCEL_PREVIOUS,
      },
    ];
  }

  handleOpenMrcDupCase(event) {
    event?.preventDefault?.();
    const rid = this.duplicateCaseId;
    if (!rid) {
      return;
    }
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: rid,
        objectApiName: "Case",
        actionName: "view",
      },
    });
  }

  handleMrcHandlingOptionChange(event) {
    const value = event.detail?.value ?? STR_EMPTY;
    this.dispatchEvent(
      new CustomEvent("handlingoptionchange", {
        detail: {
          value,
          fieldName: FIELD_MRC_HANDLING_OPTION,
          sectionId: this.sectionId,
          subSectionName: this.subSectionName,
          objId: this.objId,
        },
        bubbles: true,
        composed: true,
      }),
    );
  }
}