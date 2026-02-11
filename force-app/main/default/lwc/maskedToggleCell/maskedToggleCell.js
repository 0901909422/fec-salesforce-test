import { LightningElement, api } from 'lwc';

export default class MaskedToggleCell extends LightningElement {
  @api value; // raw cell value passed by lightning-datatable
  @api rowKeyValue; // optional: unique key of the row for accessibility/testability

  isMasked = true;

  get isDisplay() {
    return this.value != null && this.value != undefined && this.value !== '';
  }

  get rawValue() {
    return this.value === null || this.value === undefined ? '' : String(this.value);
  }

  get displayValue() {
    const v = this.rawValue;
    if (this.isMasked) {
      // Mask rules:
      // - 9 characters: keep first 3 and last 3, mask middle 3 (e.g., ABC***XYZ)
      // - 12 characters: keep first 6 and last 3, mask middle 3 (e.g., 062789***321)
      if (v.length === 9) {
        return v.slice(0, 3) + '***' + v.slice(6);
      }
      if (v.length === 12) {
        return v.slice(0, 6) + '***' + v.slice(9);
      }
      // Other lengths: display as-is per current requirement
      return v;
    }
    return v;
  }

  get buttonIcon() {
    // utility:hide when masked (default), utility:preview when showing
    return this.isMasked ? 'utility:hide' : 'utility:preview';
  }

  get buttonAltText() {
    return this.isMasked ? 'Show' : 'Hide';
  }

  handleToggle() {
    this.isMasked = !this.isMasked;
  }
}