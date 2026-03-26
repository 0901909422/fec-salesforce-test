import { LightningElement, api, track } from "lwc";
import getRecordTypeName from "@salesforce/apex/FEC_InteractionInforHandler.getRecordTypeName";

import {
  RECORD_TYPE_INTERACTION,
  RECORD_TYPE_CUSTOMER_CASE,
} from "c/fec_CommonConst";

export default class Fec_AccountOrContractPicklistContainer extends LightningElement {
  @api recordId;
  @track recordTypeDevName;

  async connectedCallback() {
    await this.init();
  }

  async init() {
    try {
      console.log("recordId", this.recordId);
      this.recordTypeDevName = await getRecordTypeName({
        recordId: this.recordId,
      });
      console.log(this.recordTypeDevName);
    } catch (e) {
      console.error("Init picklist container error:", e);
    }
  }

  get isInteraction() {
    return this.recordTypeDevName === RECORD_TYPE_INTERACTION;
  }

  get isCustomerCase() {
    return this.recordTypeDevName === RECORD_TYPE_CUSTOMER_CASE;
  }

  // optional: handle refresh from child
  handleRefresh() {
    // nếu cần reload gì thêm thì xử lý ở đây
    console.log("Picklist container refreshed");
  }
}
