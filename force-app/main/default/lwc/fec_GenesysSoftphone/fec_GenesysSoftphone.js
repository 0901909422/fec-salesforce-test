/** * Controller xử lý logic Softphone và giao tiếp với IWS Host qua postMessage
* @created      : 2025/12/29 long.nguyen.50
*/
import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import createInteraction from "@salesforce/apex/FEC_CreateInteractionGenesys.createInteraction";

import { subscribe, MessageContext } from "lightning/messageService";
import GENESYS_CHANNEL from "@salesforce/messageChannel/GenesysCall__c";

export default class fec_genesysSoftphone extends NavigationMixin(
  LightningElement,
) {
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
    this.setupPostMessageListener();
  }

  subscribeLMS() {
    this.subscription = subscribe(
      this.messageContext,
      GENESYS_CHANNEL,
      (message) => {
        if (message.action === "MAKE_CALL") {
          this.handleMakeCall(message.payload.number);
        }
      },
    );
  }

  disconnectedCallback() {
    window.removeEventListener("message", this.handlePostMessage.bind(this));
  }

  get IframeSrc() {
    const strUrl = window.location.origin + "/apex/IWS_Host";
    return strUrl;
  }

  setupPostMessageListener() {
    window.addEventListener("message", this.handlePostMessage.bind(this));
  }

  handlePostMessage(event) {
    const message = event.data;
    if (message.source === "genesys_host" && message.eventType) {
      const { eventType, data } = message;
      this.processGenesysEvent(eventType, data);
    }
  }

  processGenesysEvent(eventType, data) {
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

    const genesysResponse = {
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

    createInteraction({ request: genesysResponse })
    .then((result) => {
        if (result && result.isSuccess && result.recordId) {
            this.currentInteractionCaseId = result.recordId;
            console.info(`Đã tạo case: ${result.recordId}`);
            this.navigateToRecord(result.recordId);
        } else {
            console.warn(result?.message || 'Create interaction failed.');
        }
    })
    .catch((error) => {
        let errorMessage = 'Unexpected error occurred.';
        
        if (error?.body) {
            errorMessage = Array.isArray(error.body)
                ? error.body.map(e => e.message).join(', ')
                : error.body.message;
        } else if (error?.message) {
            errorMessage = error.message;
        }

        console.error(errorMessage);
    });
  }

  handleWrapup(wrapupData) {
    console.info(
		`Wrap-up - Đã gửi dữ liệu Wrap-up (${wrapupData?.BusinessResult || ''})`
	);
    this.currentInteractionCaseId = null;
  }

  navigateToRecord(recordId) {
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
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  sendEventToGenesys(strAction, objPayload) {
    const iframe = this.template.querySelector(".iws-iframe");

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
    }
  }

  handleCallClick() {
    const inputFields = this.template.querySelector(".fec-phone-input");
    const strPhoneNumber = inputFields ? inputFields.value : "";

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
    this.sendEventToGenesys("READY", {});
  }

  handleMakeCall(phoneNumber) {
    this.sendEventToGenesys("MAKE_CALL", {
      number: phoneNumber,
      params: null,
    });
  }
}