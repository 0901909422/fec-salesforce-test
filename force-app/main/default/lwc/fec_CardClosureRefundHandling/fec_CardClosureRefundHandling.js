import { LightningElement, api } from 'lwc';

const ALLOWED_LWC_IMPORTS = {
    'fec_CardClosureRefundForm': () => import('c/fec_CardClosureRefundForm')
};

const DEFAULT_CARD_CLOSURE_REFUND_LWC = 'fec_CardClosureRefundForm';

export default class Fec_CardClosureRefundHandling extends LightningElement {

    @api recordId;

    dynamicComponent;

    async connectedCallback() {
        try {
            const lwcName = DEFAULT_CARD_CLOSURE_REFUND_LWC;
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