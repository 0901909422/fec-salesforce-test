import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import CASEID from "@salesforce/schema/FEC_Assignment__c.FEC_Case__c";
import getPhoneList from "@salesforce/apex/FEC_ClickToCallHandler.getPhoneList";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { publish, MessageContext } from "lightning/messageService";
import GENESYS_CHANNEL from "@salesforce/messageChannel/GenesysCall__c";
import COMMON_STYLES from "@salesforce/resourceUrl/FEC_CommonCss";
import { loadStyle } from "lightning/platformResourceLoader";

export default class Fec_ClickToCallQuickActionClone extends LightningElement {
  @api recordId;

  phones = [];
  caseId;

  /** 🔑 LMS context */
  messageContext;

  columns = [
    {
      label: "Phone Number",
      fieldName: "phone",
      type: "maskedContact",
      typeAttributes: {
        maskedValue: { fieldName: "maskedValue" },
        rawValue: { fieldName: "rawValue" },
        isVisible: { fieldName: "isVisible" },
        rowId: { fieldName: "id" },
      },
    },
    {
      label: "Phone Type",
      fieldName: "phoneType",
    },
    {
      type: "button",
      initialWidth: 230,
      cellAttributes: { alignment: "right" },
      typeAttributes: {
        label: "Click To Call",
        name: "call",
        variant: "brand",
      },
    },
  ];

  /* ================= MESSAGE CONTEXT ================= */

  @wire(MessageContext)
  wiredMessageContext(context) {
    if (context) {
      this.messageContext = context;
    }
  }

  connectedCallback() {
    this.loadStyles();
  }

  /* ================= DATA ================= */

  @wire(getRecord, {
    recordId: "$recordId",
    fields: [CASEID],
  })
  wiredCaseID({ data, error }) {
    if (data) {
      this.caseId = getFieldValue(data, CASEID);
      if (this.caseId) {
        this.loadPhoneList();
      }
    } else if (error) {
      this.showErrorToast("Không lấy được Case ID", "Lỗi dữ liệu");
      console.error(error);
    }
  }

  loadPhoneList() {
    getPhoneList({ caseId: this.caseId })
      .then((result) => {
        this.phones = result.map((item, index) => ({
          id: index + 1,
          phone: item.phone,
          phoneType: item.phoneType,
          rawValue: item.phone,
          maskedValue: this.maskPhone(item.phone),
          isVisible: false,
        }));
      })
      .catch((error) => {
        this.showErrorToast(
          "Đã xảy ra lỗi khi lấy danh sách số điện thoại.",
          "Lỗi tải số điện thoại",
        );
        console.error(error);
      });
  }

  /* ================= ACTION ================= */

  loadStyles() {
    loadStyle(this, COMMON_STYLES)
      .then(() => {
        console.log("Common styles loaded");
      })
      .catch((error) => {
        console.error("Style load error", error);
      });
  }

  handleRowAction(event) {
    const phone = event.detail.row.phone;
    this.handleMakeCall(phone);
  }

  handleMakeCall(phoneNumber) {
    if (!this.messageContext) {
      console.error("MessageContext not ready");
      this.showErrorToast("Hệ thống chưa sẵn sàng để gọi");
      return;
    }

    console.log(`[ClickToCall] Publishing MAKE_CALL for number ${phoneNumber}`);

    publish(this.messageContext, GENESYS_CHANNEL, {
      action: "MAKE_CALL",
      payload: {
        number: phoneNumber,
      },
    });
  }

  maskPhone(phone) {
    const cleaned = phone.replace(/\D/g, "");

    // 024 / 028
    if (cleaned.startsWith("024") || cleaned.startsWith("028")) {
      return (
        cleaned.substring(0, 3) +
        "*".repeat(cleaned.length - 6) +
        cleaned.substring(cleaned.length - 3)
      );
    }

    // 0xxxxxxxxx
    if (cleaned.startsWith("0")) {
      return (
        cleaned.substring(0, 4) + "***" + cleaned.substring(cleaned.length - 3)
      );
    }

    // 84xxxxxxxxx
    if (cleaned.startsWith("84")) {
      return (
        cleaned.substring(0, 5) + "***" + cleaned.substring(cleaned.length - 3)
      );
    }

    return (
      cleaned.substring(0, 3) + "***" + cleaned.substring(cleaned.length - 3)
    );
  }

  handleToggleMask(event) {
    const rowId = event.detail.rowId;

    this.phones = this.phones.map((row) => {
      if (row.id === rowId) {
        return {
          ...row,
          isVisible: !row.isVisible,
        };
      }

      return row;
    });
  }
  /* ================= TOAST ================= */

  showSuccessToast(message) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Thành công",
        message,
        variant: "success",
      }),
    );
  }

  showErrorToast(message, title = "Lỗi") {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant: "error",
      }),
    );
  }
}