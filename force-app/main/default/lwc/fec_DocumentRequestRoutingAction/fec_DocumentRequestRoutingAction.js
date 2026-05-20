import { LightningElement, api } from "lwc";
import FEC_Action_Label from "@salesforce/label/c.FEC_Action_Label";
import FEC_Team_Label from "@salesforce/label/c.FEC_Team_Label";
import FEC_Queue_Label from "@salesforce/label/c.FEC_Queue_Label";
import FEC_Decision_Label from "@salesforce/label/c.FEC_Decision_Label";
import FEC_Choose_Decision_Label from "@salesforce/label/c.FEC_Choose_Decision_Label";
import FEC_Sub_Decision_Label from "@salesforce/label/c.FEC_Sub_Decision_Label";
import FEC_Choose_Sub_Decision_Label from "@salesforce/label/c.FEC_Choose_Sub_Decision_Label";

//PhongBT 18/05/26: Document Request sử dụng cục routing action mới
export default class Fec_DocumentRequestRoutingAction extends LightningElement {
  @api isEdit;
  @api actionValue;
  @api routingActionOptions = [];
  @api isRoutingActionDisabled;
  @api showRouteTo;
  @api nextTeam;
  @api routeToQueueDisplayLabel;
  @api showRevert;
  @api revertDecisionDisplayLabel;
  @api showTransfer;
  @api showUpdate;
  @api decisionValue;
  @api subDecisionValue;
  @api decisionOptions = [];
  @api subDecisionOptions = [];
  @api decisionUpdateOptions = [];
  @api isSubDecisionOptionsDisplay;

  labels = {
    actionLabel: FEC_Action_Label,
    teamLabel: FEC_Team_Label,
    queueLabel: FEC_Queue_Label,
    decisionLabel: FEC_Decision_Label,
    chooseDecisionLabel: FEC_Choose_Decision_Label,
    subDecisionLabel: FEC_Sub_Decision_Label,
    chooseSubDecisionLabel: FEC_Choose_Sub_Decision_Label,
  };

  //PhongBT 18/05/26: Document Request sử dụng cục routing action mới
  @api
  getRoutingActionSelect() {
    return this.template.querySelector('lightning-select[data-id="routing-action"]');
  }

  //PhongBT 18/05/26: Document Request sử dụng cục routing action mới
  @api
  reportRoutingValidity() {
    const el = this.getRoutingActionSelect();
    return el ? el.reportValidity() : true;
  }

  handleActionChange(event) {
    this.dispatchEvent(
      new CustomEvent("actionchange", {
        detail: { value: event.detail.value },
        bubbles: true,
        composed: true,
      }),
    );
  }

  handleFieldChange(event) {
    this.dispatchEvent(
      new CustomEvent("routingfieldchange", {
        detail: {
          fieldName: event.target.name,
          value: event.detail.value,
        },
        bubbles: true,
        composed: true,
      }),
    );
  }
}
