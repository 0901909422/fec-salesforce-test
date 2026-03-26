import { LightningElement, api } from 'lwc';

export default class Fec_NameLinkCell extends LightningElement {
    @api rowId;
    @api label;

    handleClick(event) {
        event.preventDefault();
        event.stopPropagation();
        this.dispatchEvent(
            new CustomEvent('namelinkclick', {
                bubbles: true,
                composed: true,
                detail: { rowId: this.rowId }
            })
        );
    }
}