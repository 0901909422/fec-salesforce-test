import { LightningElement, api } from 'lwc';

export default class CustomDblclickCell extends LightningElement {
    @api value;
    @api fieldName;
    @api selectedType;
    @api isExpanded = false;
    @api isAccountContractSearch = false;
    clickTimer;

    // Single click:
    // - Account/Contract Search → toggle Application History
    // - Interaction → no action
    handleClick(event) {
        if (this.isAccountContractSearch) {
            window.clearTimeout(this.clickTimer);
            this.clickTimer = window.setTimeout(() => {
                this.dispatchEvent(new CustomEvent('showhistory', {
                    detail: { value: this.value, fieldName: this.fieldName },
                    bubbles: true,
                    composed: true
                }));
            }, 250);
        }
    }

    // Double click:
    // - Interaction / Account-Contract Search → create history/case
    // - On Account-Contract Search, cancel pending single-click show history
    handleDblClick(event) {
        window.clearTimeout(this.clickTimer);
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