// fec_SendNotification.js
import LightningModal from 'lightning/modal';
import { api } from 'lwc';

export default class Fec_SkipModal extends LightningModal {
    @api content;

    handleCancel() {
        this.close('cancel');
    }

    handleConfirm() {
        this.close('confirm');
    }
}