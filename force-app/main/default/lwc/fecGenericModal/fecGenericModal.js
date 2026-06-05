import { LightningElement, api } from 'lwc';

export default class FecGenericModal extends LightningElement {
    @api title = '';
    @api size = 'medium'; // small, medium, large

    get modalClass() {
        return `slds-modal slds-fade-in-open slds-modal_${this.size}`;
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}