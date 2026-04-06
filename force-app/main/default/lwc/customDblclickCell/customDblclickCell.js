import { LightningElement, api } from 'lwc';

export default class CustomDblclickCell extends LightningElement {
    @api value;
    @api fieldName;
    @api selectedType;
    @api isExpanded = false;
    @api isAccountContractSearch = false;

    // Single click:
    // - Account/Contract Search → toggle Application History
    // - Interaction → no action
    handleClick(event) {
        if (this.isAccountContractSearch) {
            this.dispatchEvent(new CustomEvent('showhistory', {
                detail: { value: this.value, fieldName: this.fieldName },
                bubbles: true,
                composed: true
            }));
        }
    }

    // Double click:
    // - Interaction → create history/case
    // - Account/Contract Search → no action
    handleDblClick(event) {
        if (!this.isAccountContractSearch) {
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
}