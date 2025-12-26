import { LightningElement, api } from 'lwc';
import { HISTORY_COLUMNS } from 'c/fecUtils';

export default class FecCustomerHistoryModal extends LightningElement {
    @api historyData = [];
    @api columns = [];

    columns = HISTORY_COLUMNS;

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}