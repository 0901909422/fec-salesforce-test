import { LightningElement, api } from 'lwc';

export default class CustomDblclickCell extends LightningElement {
    @api value;
    @api fieldName;
    @api selectedType;
    @api isExpanded = false;

    // Single click → toggle Application History
    handleClick(event) {
        this.dispatchEvent(new CustomEvent('showhistory', {
            detail: { value: this.value, fieldName: this.fieldName },
            bubbles: true,
            composed: true
        }));
    }

    // Double click → create history (navigate to case)
    handleDblClick(event) {
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