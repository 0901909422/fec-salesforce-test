import { LightningElement, api } from 'lwc';

export default class CustomDblclickCell extends LightningElement {
    @api value; // e.g., AccountNumber / ContractNumber / UserId
    @api fieldName;
    @api selectedType;
    handleDblClick(event) {
        // Mimic lightning-datatable rowaction payload so parent handler continues to work
        const detail = {
            action: {
                name: 'create_history',
                label: { fieldName: this.fieldName },
                type: this.selectedType
            },
            row: this.value
        };
        this.dispatchEvent(new CustomEvent('rowaction', { detail, bubbles: true, composed: true }));
    }
}