import { LightningElement, api } from 'lwc';

const ALLOWED_LWC_IMPORTS = {
    'fec_CardLockUnlockForm': () => import('c/fec_CardLockUnlockForm')
};

const DEFAULT_CARD_LOCK_UNLOCK_LWC = 'fec_CardLockUnlockForm';

export default class Fec_CardLockUnlockHandling extends LightningElement {

    @api recordId;

    dynamicComponent;

    async connectedCallback() {
        try {
            const lwcName = DEFAULT_CARD_LOCK_UNLOCK_LWC;
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