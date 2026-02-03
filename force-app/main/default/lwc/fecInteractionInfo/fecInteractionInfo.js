import { LightningElement, api, track } from "lwc";
import getInteraction from "@salesforce/apex/FEC_InteractionInforHandler.getInteraction";
import getInteractionPhoneReveal from "@salesforce/apex/FEC_InteractionInforHandler.getInteractionPhoneReveal";
import updateInteractionPhone from "@salesforce/apex/FEC_InteractionInforHandler.updateInteractionPhone";
import { loadStyle } from "lightning/platformResourceLoader";
import COMMON_STYLES from "@salesforce/resourceUrl/FEC_CommonCss";

// FIELD IMPORTS
import PHONE from "@salesforce/schema/Case.FEC_Phone_Number__c";
import CHANNEL from "@salesforce/schema/Case.FEC_Channel__c";
import SUB_CHANNEL from "@salesforce/schema/Case.FEC_Interaction_Subchannel__c";
import CREATED_ON from "@salesforce/schema/Case.FEC_Created_On__c";
import CREATED_BY from "@salesforce/schema/Case.FEC_Created_by__c";
import EXTERNAL_ID from "@salesforce/schema/Case.FEC_External_Interaction_ID__c";
import LAST_UPDATED_BY from "@salesforce/schema/Case.FEC_Last_Updated_By__c";
import LAST_UPDATED_ON from "@salesforce/schema/Case.FEC_Last_Updated_On__c";


const FIELDS = [
  PHONE,
  CHANNEL,
  SUB_CHANNEL,
  CREATED_ON,
  CREATED_BY,
  EXTERNAL_ID,
  LAST_UPDATED_BY,
  LAST_UPDATED_ON
];
export default class FecInteractionInfo extends LightningElement {
  @api recordId;
  @track record;
  @track revealedPhone;
  @track isEditingPhone = false;
  @track phoneDraft;
  @api isLoaded = false;
  @track isMasked = true;
  activeSections = ["interactionInfo"];

  connectedCallback() {
    this.loadStyles();
    this.loadRecord();
  }

  // ===============================
  // LOAD STYLES
  // ===============================
  loadStyles() {
    loadStyle(this, COMMON_STYLES)
      .then(() => {
        console.log("Common styles loaded");
      })
      .catch((error) => {
        console.error("Style load error", error);
      });
  }

  // ===============================
  // LOAD RECORD (IMPERATIVE)
  // ===============================
  loadRecord() {
    if (!this.recordId) return;

    getInteraction({ recordId: this.recordId })
      .then((result) => {
        this.record = result;
        this.isLoaded = true;
      })
      .catch((error) => {
        console.error("Record load error", error);
      });
  }

  // ===============================
  // GETTERS
  // ===============================
  get maskedPhone() {
    return this.record?.FEC_Interaction_Masked_Phone__c;
  }

  get channel() {
    return this.record?.FEC_Channel__c;
  }

  get subChannel() {
    return this.record?.FEC_Interaction_Subchannel__c;
  }

  get createdOn() {
    // return this.record?.FEC_Created_On__c;

    if (!this.record?.FEC_Created_On__c) return "";

    const d = new Date(this.record?.FEC_Created_On__c);
    return d.toLocaleString("en-GB", {
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    });
  }


 get lastUpdatedOn() {
    // return this.record?.FEC_Last_Updated_On__c;

    if (!this.record?.FEC_Last_Updated_On__c) return "";

    const d = new Date(this.record?.FEC_Last_Updated_On__c);
    return d.toLocaleString("en-GB", {
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    });
  }

  get lastUpdatedBy() {
    return this.record?.FEC_Last_Updated_By__c;
  }

  get createdBy() {
    return this.record?.FEC_Created_by__c;
  }

  get externalId() {
    return this.record?.FEC_External_Interaction_ID__c;
  }

  get hasPhone() {
    return !!(
      this.record?.FEC_Phone_Number__c ||
      this.record?.FEC_Interaction_Masked_Phone__c
    );
  }

  // ===============================
  // MASKING
  // ===============================
  get displayPhone() {
    if (!this.hasPhone) return null;

    return this.isMasked
      ? this.record?.FEC_Interaction_Masked_Phone__c
      : this.revealedPhone;
  }

  get eyeIcon() {
    return this.isMasked ? "utility:preview" : "utility:hide";
  }

  handleToggleMask() {
    if (this.isMasked) {
      this.revealPhone(); // 👈 chỉ gọi khi đang masked
    } else {
      this.isMasked = true;
    }
  }

  handleEditPhone() {
    this.isEditingPhone = true;
    this.phoneDraft = "";
  }

  handlePhoneChange(event) {
    this.phoneDraft = event.target.value;
  }

  // handleSavePhone() {
  //   if (!this.phoneDraft) return;

  //   updateInteractionPhone({
  //     recordId: this.recordId,
  //     phone: this.phoneDraft,
  //   })
  //     .then(() => {
  //       // reset state
  //       this.isEditingPhone = false;
  //       this.isMasked = true;

  //       // cập nhật record local (CLONE)
  //       this.record = {
  //         ...this.record,
  //         FEC_Phone_Number__c: this.phoneDraft,
  //       };
  //     })
  //     .catch((error) => {
  //       console.error("Update phone error", error);
  //     });
  // }

  handleSavePhone() {
    if (!this.phoneDraft) return;

    updateInteractionPhone({
      recordId: this.recordId,
      phone: this.phoneDraft,
    })
      .then((maskedPhone) => {
        this.record = {
          ...this.record,
          FEC_Interaction_Masked_Phone__c: maskedPhone,
        };

        this.isEditingPhone = false;
        this.isMasked = true;
        this.phoneDraft = null;
      })
      .catch((error) => {
        console.error("Update phone error", error);
      });
  }

  // ===============================
  // REVEAL PHONE
  // ===============================
  revealPhone() {
    getInteractionPhoneReveal({ recordId: this.recordId }).then((result) => {
      this.revealedPhone = result;
      this.isMasked = false;
    });
  }
}