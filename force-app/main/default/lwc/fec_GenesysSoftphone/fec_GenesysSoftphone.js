/** * Controller xử lý logic Softphone và giao tiếp với IWS Host qua postMessage
* @created      : 2025/12/29 long.nguyen.50
*/
import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import createInteraction from "@salesforce/apex/FEC_CreateInteractionGenesys.createInteraction";
import createEmailInteraction from "@salesforce/apex/FEC_CreateInteractionGenesys.createEmailInteraction";
import executeRoutingAssignments from "@salesforce/apex/FEC_InteractionRoutingController.executeRoutingAssignments";

import { subscribe, MessageContext } from "lightning/messageService";
import GENESYS_CHANNEL from "@salesforce/messageChannel/GenesysCall__c";
import { FEC_GENESYS_CONST } from './fec_genesysUtils';

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
    executeRoutingAssignments();
  }

  subscribeLMS() {
    this.subscription = subscribe(
      this.messageContext,
      GENESYS_CHANNEL,
      (message) => {
        if (message.action === FEC_GENESYS_CONST.ACTION_MAKE_CALL) {
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
    if (message.source === FEC_GENESYS_CONST.SOURCE_GENESYS_HOST && message.eventType) {
      const { eventType, data } = message;
      this.processGenesysEvent(eventType, data);
    }
  }

  processGenesysEvent(eventType, data) {
    switch (eventType) {
      case FEC_GENESYS_CONST.EVENT_INBOUND:
      case FEC_GENESYS_CONST.EVENT_OUTBOUND:
        this.handleNewInteraction(eventType, data);
        break;
      case FEC_GENESYS_CONST.EVENT_EMAIL:
        this.handleEmailInteraction(data);
        break;
      case FEC_GENESYS_CONST.EVENT_WRAPUP:
        this.handleWrapup(data);
        break;
      default:
        console.warn(
          `[fec_genesysSoftphone] Event ${eventType} is not implemented.`
        );
    }
  }

  handleNewInteraction(eventType, callData) {

    const genesysResposnse = {
      type: eventType,
      phoneNumber: callData.DNIS || callData.ANI,
      genesysInteractionID: callData.GenesysInteractionID,
      nationalId: callData.NationalID,
      cardAccountNum: callData.CardAccountNum,
      contractNum: callData.ContractNum,
      agentID: callData.agentID,
      campaignName: callData.campaignName,
      method: FEC_GENESYS_CONST.CHANNEL_GENESYS
    };

    createInteraction({ request: genesysResposnse })
      .then((result) => {
        if (result.isSuccess) {
          this.currentInteractionCaseId = result.recordId;
          this.navigateToRecord(result.recordId);
        } else {
          console.warn(`warning ${result.message}.`);
        }
      })
      .catch((error) => {
        const strErrorMessage = error.body ? error.body.message : error.message;
        console.warn(`error ${strErrorMessage}.`);
      });
  }

  handleWrapup(wrapupData) {
    this.currentInteractionCaseId = null;
  }

  handleEmailInteraction(emailData) {
    const request = {
      fromEmail: emailData.From,
      sendTo: emailData.sendTo || 'dichvukhachhang@fecredit.com.vn',
      genesysInteractionID: emailData.GenesysInteractionID,
      phoneNum: emailData.PhoneNum,
      nationalID: emailData.NationalID,
      contractNum: emailData.ContractNum,
      cardAccountNum: emailData.CardAccountNum,
      agentID: emailData.AgentID,
      subject: emailData.Subject || emailData.subject || ''
    };

    createEmailInteraction({ request })
      .then((result) => {
        if (result.isSuccess) {
          this.currentInteractionCaseId = result.recordId;
          this.navigateToRecord(result.recordId);
        } else {
          console.warn(`[Email] warning: ${result.message}`);
        }
      })
      .catch((error) => {
        const msg = error.body ? error.body.message : error.message;
        console.warn(`[Email] error: ${msg}`);
      });
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

  sendEventToGenesys(strAction, objPayload) {
    const iframe = this.template.querySelector(".iws-iframe");

    const vfOrigin = window.location.origin.replace(
      ".sandbox.lightning.force.com",
      "--c.sandbox.vf.force.com",
    );

    if (iframe && iframe.contentWindow) {
      const message = {
        source: FEC_GENESYS_CONST.SOURCE_LWC_TO_GENESYS,
        action: strAction,
        data: objPayload,
      };
      iframe.contentWindow.postMessage(message, vfOrigin);
    }
  }

  handleMakeCall(phoneNumber) {
    this.sendEventToGenesys(FEC_GENESYS_CONST.ACTION_MAKE_CALL, {
      number: phoneNumber,
      params: null,
    });
  }
}