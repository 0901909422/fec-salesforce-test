/** * Controller xử lý logic Softphone và giao tiếp với IWS Host qua postMessage
 * @created      : 2025/12/29 long.nguyen.50
 */
import { LightningElement, track, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import createInteractionCase from "@salesforce/apex/FEC_CreateCaseHanlder.createInteractionCase";
import createInteraction from "@salesforce/apex/FEC_CreateInteractionGenesys.createInteraction";

import { subscribe, MessageContext } from "lightning/messageService";
import GENESYS_CHANNEL from "@salesforce/messageChannel/GenesysCall__c";

export default class fec_genesysSoftphone extends NavigationMixin(
  LightningElement,
) {
  @track callStatus = "Đang khởi tạo IWS...";
  @track callerNumber = "";
  currentInteractionCaseId = null;

  /** ===== LMS ===== */
  messageContext;
  subscription;

  /* ================= MESSAGE CONTEXT ================= */

  @wire(MessageContext)
  wiredMessageContext(context) {
    if (context && !this.subscription) {
      this.messageContext = context;
      this.subscribeLMS();
    }
  }

  connectedCallback() {
    console.log(
      "[fec_genesysSoftphone] connectedCallback: Initializing component...",
    );
    this.setupPostMessageListener();
  }

  subscribeLMS() {
    this.subscription = subscribe(
      this.messageContext,
      GENESYS_CHANNEL,
      (message) => {
        console.log(
          "[fec_genesysSoftphone] LMS message:",
          JSON.stringify(message),
        );

        if (message.action === "MAKE_CALL") {
          this.handleMakeCall(message.payload.number);
        }
      },
    );
  }

  disconnectedCallback() {
    console.log(
      "[fec_genesysSoftphone] disconnectedCallback: Removing event listener...",
    );
    window.removeEventListener("message", this.handlePostMessage.bind(this));
  }

  get IframeSrc() {
    const strUrl = window.location.origin + "/apex/IWS_Host";
    console.log("[fec_genesysSoftphone] IframeSrc generated:", strUrl);
    return strUrl;
  }

  setupPostMessageListener() {
    console.log(
      "[fec_genesysSoftphone] setupPostMessageListener: Adding window listener...",
    );
    window.addEventListener("message", this.handlePostMessage.bind(this));
    this.callStatus = "Đã tải Host. Đang chờ kết nối IWS...";
  }

  handlePostMessage(event) {
    // Log toàn bộ message nhận được để tracking tín hiệu Genesys
    console.log(
      `[fec_genesysSoftphone] handlePostMessage received event:`,
      event,
    );

    const message = event.data;
    if (message.source === "genesys_host" && message.eventType) {
      const { eventType, data } = message;
      console.log(
        `[fec_genesysSoftphone] Processing Genesys event: ${eventType}`,
        JSON.stringify(data),
      );

      this.callStatus = `Sự kiện: ${eventType}`;
      this.processGenesysEvent(eventType, data);
    } else {
      console.log(
        "[fec_genesysSoftphone] handlePostMessage: Ignore message from other sources.",
      );
    }
  }

  processGenesysEvent(eventType, data) {
    console.log(`[fec_genesysSoftphone] Routing event: ${eventType}`);
    switch (eventType) {
      case "InboundRinging":
      case "OutboundEstablished":
        this.handleNewInteraction(eventType, data);
        break;
      case "WrapupCall":
        this.handleWrapup(data);
        break;
      default:
        console.warn(
          `[fec_genesysSoftphone] Event ${eventType} is not implemented.`,
        );
    }
  }

  handleNewInteraction(eventType, callData) {
    console.log(
      "[fec_genesysSoftphone] handleNewInteraction: Preparing DTO for Apex...",
      JSON.stringify(callData),
    );

    const genesysResposnse = {
      type: eventType,
      phoneNumber: callData.DNIS || callData.ANI,
      genesysInteractionID: callData.GenesysInteractionID,
      nationalId: callData.NationalID,
      cardAccountNum: callData.CardAccountNum,
      contractNum: callData.ContractNum,
      agentID: callData.agentID,
      campaignName: callData.campaignName,
      method: "Genesys",
    };

    console.log(
      "[fec_genesysSoftphone] Calling FEC_CreateInteractionGenesys.createInteraction with:",
      JSON.stringify(genesysResposnse),
    );

    createInteraction({ request: genesysResposnse })
      .then((result) => {
        console.log("[fec_genesysSoftphone] Result:", JSON.stringify(result));

        if (result.isSuccess) {
          this.currentInteractionCaseId = result.recordId;
          this.showToast(
            "Thành công",
            `Đã tạo Case: ${result.recordId || ""}`,
            "success",
          );
          this.navigateToRecord(result.recordId);
        } else {
          this.showToast("Cảnh báo", result.message, "warning");
        }
      })
      .catch((error) => {
        const strErrorMessage = error.body ? error.body.message : error.message;
        console.error("[fec_genesysSoftphone] Error:", strErrorMessage);
        this.showToast("Lỗi hệ thống", strErrorMessage, "error");
      });
  }

  handleWrapup(wrapupData) {
    console.log(
      "[fec_genesysSoftphone] handleWrapup: Resetting interaction state.",
      JSON.stringify(wrapupData),
    );
    this.showToast(
      "Wrap-up",
      `Đã gửi dữ liệu Wrap-up (${wrapupData.BusinessResult})`,
      "info",
    );
    this.currentInteractionCaseId = null;
  }

  navigateToRecord(recordId) {
    console.log(`[fec_genesysSoftphone] Navigating to record: ${recordId}`);
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: recordId,
        objectApiName: "Case",
        actionName: "view",
      },
    });
  }

  showToast(title, message, variant) {
    console.log(
      `[fec_genesysSoftphone] showToast: [${variant.toUpperCase()}] ${title} - ${message}`,
    );
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  sendEventToGenesys(strAction, objPayload) {
    const iframe = this.template.querySelector(".iws-iframe");
    console.log(
      `[fec_genesysSoftphone] sendEventToGenesys: Requesting action ${strAction}`,
      JSON.stringify(objPayload),
    );

    // Chuyển đổi từ lightning.force.com sang vf.force.com
    const vfOrigin = window.location.origin.replace(
      ".sandbox.lightning.force.com",
      "--c.sandbox.vf.force.com",
    );

    if (iframe && iframe.contentWindow) {
      const message = {
        source: "lwc_to_genesys",
        action: strAction,
        data: objPayload,
      };
      iframe.contentWindow.postMessage(message, vfOrigin);
      console.log(
        "[fec_genesysSoftphone] sendEventToGenesys: Message sent successfully.",
      );
    } else {
      console.error(
        "[fec_genesysSoftphone] sendEventToGenesys: Error - IWS Iframe not ready.",
      );
    }
  }

  handleCallClick() {
    const inputFields = this.template.querySelector(".fec-phone-input");
    const strPhoneNumber = inputFields ? inputFields.value : "";

    console.log(
      `[fec_genesysSoftphone] handleCallClick: User triggered call to ${strPhoneNumber}`,
    );

    if (strPhoneNumber) {
      this.handleMakeCall(strPhoneNumber);
    } else {
      this.showToast(
        "Thông báo",
        "Vui lòng nhập số điện thoại để thực hiện cuộc gọi.",
        "warning",
      );
    }
  }

  handleSetReady() {
    console.log(
      "[fec_genesysSoftphone] handleSetReady: Agent clicked Ready button.",
    );
    this.sendEventToGenesys("READY", {});
  }

  handleMakeCall(phoneNumber) {
    console.log(
      `[fec_genesysSoftphone] handleMakeCall: Dialing number ${phoneNumber}`,
    );
    this.sendEventToGenesys("MAKE_CALL", {
      number: phoneNumber,
      params: null,
    });
  }
}