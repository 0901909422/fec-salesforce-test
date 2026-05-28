import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import FEC_Error_Title from '@salesforce/label/c.FEC_Error_Title';
import FEC_Success_Title from '@salesforce/label/c.FEC_Success_Title';
import FEC_MSG_ContractClosure_Delivery_Invalid from '@salesforce/label/c.FEC_MSG_ContractClosure_Delivery_Invalid';
import FEC_Termination_Loading_Alt from '@salesforce/label/c.FEC_Termination_Loading_Alt';
import FEC_LBL_ContractClosure_Delivery_Option from '@salesforce/label/c.FEC_LBL_ContractClosure_Delivery_Option';
import FEC_Placeholder_ContractClosure_Select_Delivery from '@salesforce/label/c.FEC_Placeholder_ContractClosure_Select_Delivery';
import FEC_Toast_Save_Success from '@salesforce/label/c.FEC_Toast_Save_Success';

import getInitData from '@salesforce/apex/FEC_ContractClosureController.getInitData';
import validateForComplete from '@salesforce/apex/FEC_ContractClosureController.validateForComplete';
import saveForm from '@salesforce/apex/FEC_ContractClosureController.saveForm';
import saveFormDraft from '@salesforce/apex/FEC_ContractClosureController.saveFormDraft';

import { STR_EMPTY, CONTRACT_CLOSURE_DELIVERY_VALUE_POS_DEFAULT } from 'c/fec_CommonConst';

const CC_MSG_LOAD_FAILED = 'Load failed';

/**
 * IL10.03 — Delivery Option chỉ POS (tách khỏi fec_ContractClosureForm).
 */
export default class Fec_Il10DeliveryForm extends LightningElement {
    @api recordId;
    @api isEdit;

    loading = true;
    loadError;
    deliveryOptions = [];
    savedDeliveryOption = STR_EMPTY;
    deliveryPosSelected = false;
    resolvedPosValue;

    wiredInitResult;
    lastValidationMessages = [];
    showValidateBanner = false;

    customLabel = {
        errorTitle: FEC_Error_Title,
        successTitle: FEC_Success_Title,
        loadingAlt: FEC_Termination_Loading_Alt,
        deliveryOption: FEC_LBL_ContractClosure_Delivery_Option,
        placeholderDelivery: FEC_Placeholder_ContractClosure_Select_Delivery,
        toastSaveSuccess: FEC_Toast_Save_Success
    };

    validationLabels = {
        deliveryRequired: FEC_MSG_ContractClosure_Delivery_Invalid
    };

    get isClosureEditable() {
        return this.isEdit !== false;
    }

    get closureFieldsReadonly() {
        return this.isEdit === false;
    }

    get closureFieldRequired() {
        return this.isClosureEditable;
    }

    get deliveryPicklistOptions() {
        const pv = this.resolvedPosValue;
        if (!pv) {
            return [];
        }
        return [{ label: this.labelPos, value: pv }];
    }

    get selectedDeliveryValues() {
        if (this.deliveryPosSelected && this.resolvedPosValue) {
            return [this.resolvedPosValue];
        }
        return [];
    }

    get validationMessageItems() {
        return (this.lastValidationMessages || []).map((text, index) => ({
            key: 'v' + index,
            text
        }));
    }

    get labelPos() {
        const o = this.pickDeliveryMeta('POS');
        return o ? o.label : CONTRACT_CLOSURE_DELIVERY_VALUE_POS_DEFAULT;
    }

    @wire(getInitData, { caseId: '$recordId' })
    wiredInit(result) {
        this.wiredInitResult = result;
        this.loading = false;
        const { data, error } = result;
        if (data) {
            if (!data.success) {
                this.loadError = data.errorMessage || CC_MSG_LOAD_FAILED;
                return;
            }
            this.loadError = undefined;
            this.deliveryOptions = data.deliveryOptions || [];
            this.savedDeliveryOption = data.savedDeliveryOption || STR_EMPTY;
            this.resolveDeliveryMeta();
            this.applySavedDelivery();
            this._emitDeliveryChange();
        } else if (error) {
            this.loadError = error.body ? error.body.message : String(error);
        }
    }

    resolveDeliveryMeta() {
        const posO = this.pickDeliveryMeta('POS');
        this.resolvedPosValue = posO ? posO.value : null;
    }

    pickDeliveryMeta(kind) {
        const opts = this.deliveryOptions || [];
        if (kind === 'POS') {
            return opts.find(
                (o) =>
                    /^pos$/i.test((o.label || STR_EMPTY).trim()) ||
                    /^pos$/i.test((o.value || STR_EMPTY).trim()) ||
                    /^rl05_pos$/i.test((o.value || STR_EMPTY).trim())
            );
        }
        return undefined;
    }

    applySavedDelivery() {
        this.deliveryPosSelected = false;
        const s = this.savedDeliveryOption;
        if (!s || !this.resolvedPosValue) {
            return;
        }
        const parts = s.split(';').map((x) => x.trim()).filter(Boolean);
        this.deliveryPosSelected = parts.includes(this.resolvedPosValue);
    }

    handlePicklistChange(event) {
        if (this.closureFieldsReadonly) {
            return;
        }
        const ids = event.detail && event.detail.ids ? [...event.detail.ids] : [];
        const pv = this.resolvedPosValue;
        this.deliveryPosSelected = !!(pv && ids.includes(pv));
        this._emitDeliveryChange();
    }

    _emitDeliveryChange() {
        this.dispatchEvent(
            new CustomEvent('deliveryoptionchange', {
                bubbles: true,
                composed: true,
                detail: {
                    deliveryOptionCombined: this.buildPayload().deliveryOptionCombined || STR_EMPTY
                }
            })
        );
    }

    buildPayload() {
        const parts = [];
        if (this.deliveryPosSelected && this.resolvedPosValue) {
            parts.push(this.resolvedPosValue);
        }
        return {
            deliveryOptionCombined: parts.join(';'),
            deliveryEmailSelected: false,
            deliveryAddressSelected: false,
            deliveryOfficeSelected: false,
            deliveryPosSelected: this.deliveryPosSelected,
            useExistingEmail: false,
            emailDeliveryChannel: STR_EMPTY,
            temporaryEmail: STR_EMPTY,
            recipientName: STR_EMPTY,
            recipientPhone: STR_EMPTY,
            selectedAddressId: STR_EMPTY,
            temporaryAddressDisplay: STR_EMPTY
        };
    }

    assertDeliveryPicklistValid() {
        const el = this.template.querySelector('[data-fec-field="deliveryPicklist"]');
        let ok = true;
        if (el && typeof el.checkValidity === 'function') {
            ok = el.checkValidity();
        } else {
            ok = this.deliveryPosSelected === true;
        }
        if (!ok && this.isClosureEditable) {
            this.showToast(this.customLabel.errorTitle, this.validationLabels.deliveryRequired, 'error');
        }
        return ok;
    }

    @api
    getDeliveryOptionForRouting() {
        return this.buildPayload().deliveryOptionCombined || STR_EMPTY;
    }

    @api
    validateForSubmit() {
        if (!this.isClosureEditable || this.loading || this.loadError) {
            return !this.loadError;
        }
        return this.assertDeliveryPicklistValid();
    }

    @api
    async validateBeforeComplete() {
        this.showValidateBanner = false;
        this.lastValidationMessages = [];
        if (!this.isClosureEditable) {
            return { valid: true, messages: [] };
        }
        if (!this.assertDeliveryPicklistValid()) {
            return { valid: false, messages: [] };
        }
        const payload = this.buildPayload();
        try {
            const r = await validateForComplete({
                caseId: this.recordId,
                payloadJson: JSON.stringify(payload)
            });
            if (!r.valid) {
                this.lastValidationMessages = r.messages || [];
                this.showValidateBanner = true;
            }
            return r;
        } catch (e) {
            const msg = e.body && e.body.message ? e.body.message : String(e);
            this.lastValidationMessages = [msg];
            this.showValidateBanner = true;
            return { valid: false, messages: [msg] };
        }
    }

    @api
    async saveToCase() {
        if (!this.isClosureEditable) {
            return { valid: true, messages: [] };
        }
        if (!this.assertDeliveryPicklistValid()) {
            return { valid: false, messages: [] };
        }
        const payload = this.buildPayload();
        try {
            const r = await saveForm({
                caseId: this.recordId,
                payloadJson: JSON.stringify(payload)
            });
            if (!r.valid) {
                this.lastValidationMessages = r.messages || [];
                this.showValidateBanner = true;
            } else {
                this.savedDeliveryOption = payload.deliveryOptionCombined || STR_EMPTY;
                this.deliveryPosSelected = payload.deliveryPosSelected === true;
                try {
                    if (this.wiredInitResult) {
                        await refreshApex(this.wiredInitResult);
                    }
                } catch (ignore) {
                    /* refresh optional */
                }
                this.showToast(this.customLabel.successTitle, this.customLabel.toastSaveSuccess, 'success');
            }
            return r;
        } catch (e) {
            const msg = this.handleError(e);
            this.showToast(this.customLabel.errorTitle, msg, 'error');
            return { valid: false, messages: [msg] };
        }
    }

    @api
    async saveDraftIfApplicable() {
        if (!this.isClosureEditable || this.loading || this.loadError) {
            return { valid: true, messages: [] };
        }
        if (!this.deliveryPosSelected) {
            return { valid: true, messages: [] };
        }
        const payload = this.buildPayload();
        try {
            const r = await saveFormDraft({
                caseId: this.recordId,
                payloadJson: JSON.stringify(payload)
            });
            if (!r.valid) {
                this.lastValidationMessages = r.messages || [];
                this.showValidateBanner = true;
                const msgs = r.messages || [];
                const m = msgs.length > 0 ? msgs.join(', ') : this.customLabel.errorTitle;
                this.showToast(this.customLabel.errorTitle, m, 'error');
            } else {
                this.savedDeliveryOption = payload.deliveryOptionCombined || STR_EMPTY;
                this.deliveryPosSelected = payload.deliveryPosSelected === true;
                try {
                    if (this.wiredInitResult) {
                        await refreshApex(this.wiredInitResult);
                    }
                } catch (ignore) {
                    /* refresh optional */
                }
            }
            return r;
        } catch (e) {
            const msg = this.handleError(e);
            this.showToast(this.customLabel.errorTitle, msg, 'error');
            return { valid: false, messages: [msg] };
        }
    }

    handleError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (typeof error?.body?.message === 'string') {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return String(error);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant: variant || 'info'
            })
        );
    }
}
