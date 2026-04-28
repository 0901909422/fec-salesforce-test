import { LightningElement, wire } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import { CloseActionScreenEvent } from "lightning/actions";
import IS_MODE_EDIT from '@salesforce/messageChannel/FEC_Case_Mode__c';
import {
  setMode,
} from "c/fec_CustomerCaseModeStore";
export default class Fec_CustomerCaseExecuteAction extends LightningElement {
  @wire(MessageContext)
  messageContext;

  async connectedCallback() {
    try {
      await this.handlePublishMessageChanel();
    } catch (e) {
      console.log('>>>error: ', e);
    } finally {
      this.dispatchEvent(new CloseActionScreenEvent());
    }
  }

  async handlePublishMessageChanel() {
    const payload = {
      isModeEdit: true
    };
    setMode(true);
    publish(this.messageContext, IS_MODE_EDIT, payload);
  }

}