import { LightningElement, api } from 'lwc';
import { mask } from 'c/fec_CommonUtils';
import revealNationalId from '@salesforce/apex/FEC_SearchController.revealNationalId';

export default class MaskedToggleCell extends LightningElement {
  @api value; // raw cell value passed by lightning-datatable
  @api rowKeyValue; // optional: unique key of the row for accessibility/testability

  @api caseId;
  @api fieldLabel;

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
      return mask(v, 3, 3);
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

  async handleToggle() {
    this.isMasked = !this.isMasked;
    if (this.caseId && !this.isMasked) {
      try {
        await revealNationalId({ recordId: this.caseId, fieldLabel: this.fieldLabel });
      }
      catch (error) {
        console.error('Error revealing national ID:', error);
      }
    }
  }
}