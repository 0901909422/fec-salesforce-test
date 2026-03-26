/****************************************************************************************
 * File Name    : fec_IPPClosureHandling.js
 * Description  : Parent - Dynamic LWC loader for IPP Closure (Closure section).
 *                Loads fec_IPPClosureForm. See dynamic-lwc-model.
 ****************************************************************************************/

import { LightningElement, api } from 'lwc';

const ALLOWED_LWC_IMPORTS = {
    'fec_IPPClosureForm': () => import('c/fec_IPPClosureForm')
};

const DEFAULT_IPP_CLOSURE_LWC = 'fec_IPPClosureForm';

export default class Fec_IPPClosureHandling extends LightningElement {

    @api recordId;

    dynamicComponent;

    async connectedCallback() {
        try {
            const lwcName = DEFAULT_IPP_CLOSURE_LWC;
            if (lwcName && ALLOWED_LWC_IMPORTS[lwcName]) {
                const module = await ALLOWED_LWC_IMPORTS[lwcName]();
                this.dynamicComponent = module.default;
            }
        } catch (err) {
            console.error('Error loading dynamic component', err);
        }
    }

    get showChild() {
        return this.dynamicComponent != null;
    }
}
