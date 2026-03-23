import { LightningElement, api } from "lwc";
const ALLOWED_LWC_IMPORTS = {
  fec_PinResetView: () => import("c/fec_PinResetView"),
};

const DEFAULT_PIN_RESET_LWC = "fec_PinResetView";
export default class Fec_PinResetHandling extends LightningElement {
  @api recordId;

  dynamicComponent;

  async connectedCallback() {
    try {
      const lwcName = DEFAULT_PIN_RESET_LWC;
      if (lwcName && ALLOWED_LWC_IMPORTS[lwcName]) {
        const module = await ALLOWED_LWC_IMPORTS[lwcName]();
        this.dynamicComponent = module.default;
      }
    } catch (err) {
      console.error("Error loading dynamic component", err);
    }
  }

  get showChild() {
    return this.dynamicComponent != null;
  }
}