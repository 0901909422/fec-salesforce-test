import { LightningElement, api } from 'lwc';

/**
 * fec_chathubStatus
 * Component to display agent status dropdown and handle status change events.
 * @created    : 2025/12/03 long.nguyen.50
 * @modified   : 
 */
export default class FecChathubStatus extends LightningElement {
    @api options = []; // Input options (label/value)
    @api value = '';   // Current selected value

    get isHidden() {
        return this.options.length === 0;
    }

    // Xử lý sự kiện thay đổi trạng thái và bắn event lên component cha
    handleChange(event) {
        // Comment: Bắn event để component cha (fec_chathubContainer) gửi postMessage tới Iframe
        this.dispatchEvent(new CustomEvent('statuschange', {
            detail: { value: event.detail.value }
        }));
    }
}