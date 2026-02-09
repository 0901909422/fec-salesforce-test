import { LightningElement, api, track } from "lwc";
import getInteractionHighlightData from "@salesforce/apex/FEC_InteractionHighlightController.getInteractionHighlightData";
import logSensitiveAccess from "@salesforce/apex/FEC_InteractionHighlightController.logSensitiveAccess";
import { loadStyle } from "lightning/platformResourceLoader";
import COMMON_STYLES from "@salesforce/resourceUrl/FEC_CommonCss";
import ICONS from "@salesforce/resourceUrl/FEC_Icon_Face";

//=========================== Labels ===========================
import FEC_CUSTOMER_INFORMATION from "@salesforce/label/c.FEC_Customer_Information_Label";

import FEC_CUSTOMER_NAME from "@salesforce/label/c.FEC_Customer_Name_Label";

import FEC_GENDER from "@salesforce/label/c.FEC_Gender_Label";

import FEC_DOD from "@salesforce/label/c.FEC_Date_of_Birth_Label";

import FEC_NATIONAL_ID from "@salesforce/label/c.FEC_National_ID_Passport_ID_Label";

import FEC_PRIMARY_PHONE from "@salesforce/label/c.FEC_Primary_Phone_Label";

import FEC_EMAIL from "@salesforce/label/c.FEC_Email_Label";

import FEC_INTERACTION_INFORMATION from "@salesforce/label/c.FEC_Interaction_Information_Label";

import FEC_INTERACTION_ID from "@salesforce/label/c.FEC_Interaction_ID";

import FEC_INTERACTION_CHANNEL from "@salesforce/label/c.FEC_Interaction_Channel_Label";

import FEC_INTERACTION_SUB_CHANNEL from "@salesforce/label/c.FEC_Interaction_Sub_Channel_Label";

import FEC_INTERACTION_STATUS from "@salesforce/label/c.FEC_Interaction_Status_Label";

import FEC_INTERACTION_LAST_UPDATED_BY from "@salesforce/label/c.FEC_Last_Updated_By_Label";

import FEC_INTERACTION_LAST_UPDATED_ON from "@salesforce/label/c.FEC_Last_Updated_On_Label";

export default class Fec_InteractionHighlight extends LightningElement {
  //=========================== Labels ===========================
  label = {
    customerInformation: FEC_CUSTOMER_INFORMATION,
    customerName: FEC_CUSTOMER_NAME,
    gender: FEC_GENDER,
    dateOfBirth: FEC_DOD,
    nationalId: FEC_NATIONAL_ID,
    primaryPhone: FEC_PRIMARY_PHONE,
    email: FEC_EMAIL,
    interactionInformation: FEC_INTERACTION_INFORMATION,
    interactionId: FEC_INTERACTION_ID,
    interactionChannel: FEC_INTERACTION_CHANNEL,
    interactionSubChannel: FEC_INTERACTION_SUB_CHANNEL,
    interactionStatus: FEC_INTERACTION_STATUS,
    lastUpdatedBy: FEC_INTERACTION_LAST_UPDATED_BY,
    lastUpdatedOn: FEC_INTERACTION_LAST_UPDATED_ON,
  };
  @api recordId;
  @api data; // Expose data for parent component access
  @track isLoaded = false;
  @track isPhoneMasked = true;
  @track isNationalIdMasked = true;

  connectedCallback() {
    this.loadStyles();
    this.loadData();
  }

  loadStyles() {
    loadStyle(this, COMMON_STYLES).catch(() => {});
  }

  loadData() {
    if (!this.recordId) {
      this.isLoaded = true;
      return;
    }

    this.isLoaded = false;
    getInteractionHighlightData({ caseId: this.recordId })
      .then((result) => {
        this.data = result || {};
        // Dispatch event to notify parent component
        this.dispatchEvent(
          new CustomEvent("dataupdate", {
            detail: { data: this.data },
          }),
        );
      })
      .catch(() => {
        this.data = {};
      })
      .finally(() => {
        this.isLoaded = true;
      });
  }

  get iconUrl() {
    if (!this.data?.customerCategory || !ICONS) return "";

    const iconMap = {
      "Suspected Fraud": "suspected_fraud.svg",
      Media: "media_angry.svg",
      "Serious Complaint": "serious_complaint.svg",
      VIP: "vip.svg",
      Unhappy: "unhappy.svg",
      Neutral: "neutral.svg",
    };

    const iconName = iconMap[this.data.customerCategory] || "neutral.svg";
    return iconName ? `${ICONS}/${iconName}` : "";
  }

  get categoryLabel() {
    return this.data?.customerCategory || "Neutral";
  }

  get customerName() {
    return this.data?.customerName || "";
  }

  get maskedNationalId() {
    const nationalId = this.data?.nationalId;
    if (!nationalId) return "";
    if (this.isNationalIdMasked) {
      return this.data?.nationalIdMasked ?? nationalId;
    }
    return nationalId;
  }

  get gender() {
    return this.data?.gender || "";
  }

  get dateOfBirth() {
    if (!this.data?.dateOfBirth) return "";
    const d = new Date(this.data.dateOfBirth);
    return `${String(d.getDate()).padStart(2, "0")}/${String(
      d.getMonth() + 1,
    ).padStart(2, "0")}/${d.getFullYear()}`;
  }

  get maskedPhone() {
    const phone = this.data?.primaryPhone;
    if (!phone) return "";

    if (this.isPhoneMasked) {
      if (phone.length < 7) return phone;
      const first4 = phone.substring(0, 4);
      const last3 = phone.substring(phone.length - 3);
      const middle = "*".repeat(Math.max(0, phone.length - 7));
      return `${first4}${middle}${last3}`;
    }
    return phone;
  }

  get email() {
    return this.data?.email || "";
  }

  get interactionId() {
    const value = this.data?.interactionId || "";
    if (!value && this.data?.caseId && this.data?.interactionIdSearch) {
      return `<a href="/${this.data.caseId}" target="_self">${this.data.interactionIdSearch}</a>`;
    }
    return value;
  }

  get interactionStatus() {
    return this.data?.interactionStatus || "";
  }

  get interactionChannel() {
    return this.data?.interactionChannel || "";
  }

  get interactionSubStatus() {
    return this.data?.interactionSubStatus || "";
  }

  get lastUpdatedOn() {
    if (!this.data?.lastUpdatedOn) return "";
    const d = new Date(this.data.lastUpdatedOn);
    return `${String(d.getDate()).padStart(2, "0")}/${String(
      d.getMonth() + 1,
    ).padStart(2, "0")}/${d.getFullYear()}, ${String(d.getHours()).padStart(
      2,
      "0",
    )}:${String(d.getMinutes()).padStart(2, "0")}`;
  }

  get lastUpdatedBy() {
    return this.data?.lastUpdatedBy || "";
  }

  get customerSegment() {
    return this.data?.customerSegment || "";
  }

  get externalInteractionId() {
    return this.data?.externalInteractionId || "";
  }

  get interactionCreatedOn() {
    if (!this.data?.interactionCreatedOn && !this.data?.createdDate) return "";
    const dateValue = this.data?.interactionCreatedOn || this.data?.createdDate;
    const d = new Date(dateValue);
    return `${String(d.getDate()).padStart(2, "0")}/${String(
      d.getMonth() + 1,
    ).padStart(2, "0")}/${d.getFullYear()}, ${String(d.getHours()).padStart(
      2,
      "0",
    )}:${String(d.getMinutes()).padStart(2, "0")}`;
  }

  // Khi masked: mắt đóng (hide). Khi nhìn thấy: mắt mở (preview).
  get eyeIcon() {
    return this.isPhoneMasked ? "utility:hide" : "utility:preview";
  }

  get nationalIdEyeIcon() {
    return this.isNationalIdMasked ? "utility:hide" : "utility:preview";
  }

  handleTogglePhone() {
    const wasMasked = this.isPhoneMasked;
    this.isPhoneMasked = !this.isPhoneMasked;

    // Log khi unmask (chuyển từ masked sang unmasked)
    if (wasMasked && !this.isPhoneMasked && this.recordId) {
      logSensitiveAccess({
        fieldName: "Primary Phone",
        caseId: this.recordId,
      }).catch((error) => {
        console.error(
          "Error logging sensitive access for Primary Phone:",
          error,
        );
      });
    }
  }

  handleToggleNationalId() {
    const wasMasked = this.isNationalIdMasked;
    this.isNationalIdMasked = !this.isNationalIdMasked;

    // Log khi unmask (chuyển từ masked sang unmasked)
    if (wasMasked && !this.isNationalIdMasked && this.recordId) {
      logSensitiveAccess({
        fieldName: "National ID/ Passport ID",
        caseId: this.recordId,
      }).catch((error) => {
        console.error(
          "Error logging sensitive access for National ID/ Passport ID:",
          error,
        );
      });
    }
  }

  handleImageError(event) {
    event.target.style.display = "none";
  }
}
