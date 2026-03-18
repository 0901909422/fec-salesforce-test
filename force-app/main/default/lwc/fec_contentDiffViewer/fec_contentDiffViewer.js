import { LightningElement, api } from 'lwc';

export default class Fec_contentDiffViewer extends LightningElement {
    @api oldValue = '';
    @api newValue = '';
    @api changedBy = '';
    @api changedDate = '';

    _oldRendered = false;
    _newRendered = false;

    renderedCallback() {
        if (!this._oldRendered) {
            const oldContainer = this.template.querySelector('.dv-panel-old');
            if (oldContainer) {
                oldContainer.innerHTML = this.oldValue || '<em>Empty</em>';
                this._oldRendered = true;
            }
        }
        if (!this._newRendered) {
            const newContainer = this.template.querySelector('.dv-panel-new');
            if (newContainer) {
                newContainer.innerHTML = this.newValue || '<em>Empty</em>';
                this._newRendered = true;
            }
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}