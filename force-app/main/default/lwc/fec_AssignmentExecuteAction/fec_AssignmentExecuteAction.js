import { LightningElement, api, wire } from "lwc";
import { publish, MessageContext } from "lightning/messageService";
import { CloseActionScreenEvent } from "lightning/actions";

import ASSIGNMENT_MODE
from "@salesforce/messageChannel/FEC_Assignment_Mode__c";

export default class Fec_AssignmentExecuteAction extends LightningElement {

    @api recordId;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {

        publish(
            this.messageContext,
            ASSIGNMENT_MODE,
            {
                caseId: this.recordId,
                isEditMode: true
            }
        );

        this.dispatchEvent(
            new CloseActionScreenEvent()
        );
    }
}