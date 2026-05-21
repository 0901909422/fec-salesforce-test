import { LightningElement, api, track } from "lwc";
import getRouteToTeamOptions from "@salesforce/apex/FEC_ScopedStageChangeRoutingService.getRouteToTeamOptions";
import FEC_Action_Label from "@salesforce/label/c.FEC_Action_Label";
import FEC_Team_Label from "@salesforce/label/c.FEC_Team_Label";
import FEC_Queue_Label from "@salesforce/label/c.FEC_Queue_Label";
import FEC_Decision_Label from "@salesforce/label/c.FEC_Decision_Label";
import FEC_Choose_Decision_Label from "@salesforce/label/c.FEC_Choose_Decision_Label";
import FEC_Sub_Decision_Label from "@salesforce/label/c.FEC_Sub_Decision_Label";
import FEC_Choose_Sub_Decision_Label from "@salesforce/label/c.FEC_Choose_Sub_Decision_Label";
import FEC_Choose_Team_Placeholder from "@salesforce/label/c.FEC_Choose_Team_Placeholder";

function extractStageNumber(stageName) {
  if (!stageName || typeof stageName !== "string") {
    return null;
  }
  const m = stageName.match(/stage\s*(\d+)/i);
  return m ? parseInt(m[1], 10) : null;
}

/**
 * Routing Action cho Document Request / Original MRC Return — Stage 2+ chọn Team từ FEC_Stage_Change__c.
 */
export default class Fec_ScopedStageChangeRoutingAction extends LightningElement {
  @api recordId;
  @api isEdit;
  @api actionValue;
  @api routingActionOptions = [];
  @api isRoutingActionDisabled;
  @api stageName;
  @api routeToActionId;
  /** Case đã submit lần đầu (FEC_Is_Submited__c) — bắt buộc mới hiện chọn Team Stage 2+. */
  @api isSubmited;

  @api showRouteTo;
  @api readOnlyTeam;
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

  @track allOptions = [];
  @track selectedTeam = "";
  @track selectedStageChangeId = "";
  /** Stage 2+ Route to: tránh flash Team/Queue read-only trước khi Apex trả combobox options. */
  @track _teamOptionsResolved = false;

  labels = {
    actionLabel: FEC_Action_Label,
    teamLabel: FEC_Team_Label,
    queueLabel: FEC_Queue_Label,
    decisionLabel: FEC_Decision_Label,
    chooseDecisionLabel: FEC_Choose_Decision_Label,
    subDecisionLabel: FEC_Sub_Decision_Label,
    chooseSubDecisionLabel: FEC_Choose_Sub_Decision_Label,
    chooseTeamPlaceholder: FEC_Choose_Team_Placeholder,
  };

  get stageNumber() {
    return extractStageNumber(this.stageName);
  }

  /** Stage 2+, đã submit, Route to → sẽ load combobox Team từ FEC_Stage_Change__c. */
  get expectsTeamSelection() {
    return (
      this.showRouteTo === true &&
      this.isSubmited === true &&
      this.stageNumber != null &&
      this.stageNumber >= 2 &&
      !!this.recordId &&
      !!this.routeToActionId
    );
  }

  /** Stage 2+, đã submit (qua Stage 1), Route to → combobox Team/Queue */
  get showTeamSelection() {
    return this.expectsTeamSelection && this.allOptions.length > 0;
  }

  get showTeamOptionsLoading() {
    return this.expectsTeamSelection && !this._teamOptionsResolved;
  }

  /** Stage 1 hoặc sau khi load xong mà không có Team selectable → read-only. */
  get showRouteToReadOnly() {
    if (!this.showRouteTo || this.showTeamSelection) {
      return false;
    }
    if (this.expectsTeamSelection) {
      return this._teamOptionsResolved;
    }
    return true;
  }

  get teamComboboxOptions() {
    const seen = new Set();
    return this.allOptions
      .filter((o) => {
        if (!o.team || seen.has(o.team)) {
          return false;
        }
        seen.add(o.team);
        return true;
      })
      .map((o) => ({ label: o.team, value: o.team }));
  }

  get optionsForSelectedTeam() {
    if (!this.selectedTeam) {
      return [];
    }
    return this.allOptions.filter((o) => o.team === this.selectedTeam);
  }

  /** Queue label từ FEC_Stage_Change__c — cập nhật khi đổi Team (không chọn Queue thủ công). */
  get selectedQueueDisplayLabel() {
    const opts = this.optionsForSelectedTeam;
    if (!opts.length) {
      return "";
    }
    const labels = [
      ...new Set(
        opts
          .map((o) => o.queueLabel || o.queueDeveloperName || "")
          .filter(Boolean),
      ),
    ];
    return labels.join(", ");
  }

  @api
  getRoutingActionSelect() {
    return this.template.querySelector('lightning-select[data-id="routing-action"]');
  }

  @api
  reportRoutingValidity() {
    const actionEl = this.getRoutingActionSelect();
    let valid = actionEl ? actionEl.reportValidity() : true;
    if (this.showTeamSelection) {
      const teamEl = this.template.querySelector('[data-id="route-team"]');
      if (teamEl) {
        valid = teamEl.reportValidity() && valid;
      }
      if (this.selectedTeam && !this.selectedStageChangeId) {
        valid = false;
      }
    }
    return valid;
  }

  @api
  getSubmitParams() {
    const selected = this.allOptions.find(
      (o) => o.stageChangeId === this.selectedStageChangeId,
    );
    return {
      selectedStageChangeId: this.selectedStageChangeId || null,
      queueId: selected?.queueValue || null,
      team: this.selectedTeam || null,
    };
  }

  @api
  getSelectedQueueId() {
    return this.getSubmitParams().queueId;
  }

  connectedCallback() {
    this._maybeLoadTeamOptions();
  }

  renderedCallback() {
    this._maybeLoadTeamOptions();
  }

  _maybeLoadTeamOptions() {
    if (!this.expectsTeamSelection) {
      this._teamOptionsResolved = false;
      this.allOptions = [];
      this._optionsLoadedFor = null;
      return;
    }
    if (this._optionsLoadedFor === this._optionsLoadKey) {
      return;
    }
    this._optionsLoadedFor = this._optionsLoadKey;
    this._teamOptionsResolved = false;
    this.allOptions = [];
    this.selectedTeam = "";
    this.selectedStageChangeId = "";
    getRouteToTeamOptions({
      caseId: this.recordId,
      routeToActionId: this.routeToActionId,
    })
      .then((data) => {
        this.allOptions = data || [];
        if (this.allOptions.length === 1) {
          this._applySelection(this.allOptions[0]);
        }
        this._notifySelectionChange();
      })
      .catch((err) => {
        console.error("[fec_ScopedStageChangeRoutingAction]", err);
        this.allOptions = [];
      })
      .finally(() => {
        this._teamOptionsResolved = true;
      });
  }

  get _optionsLoadKey() {
    return `${this.recordId}|${this.routeToActionId}|${this.stageName}|${this.showRouteTo}|${this.isSubmited}`;
  }

  _applySelection(opt) {
    if (!opt) {
      return;
    }
    this.selectedTeam = opt.team || "";
    this.selectedStageChangeId = opt.stageChangeId || "";
  }

  _syncQueueFromTeam() {
    const opts = this.optionsForSelectedTeam;
    if (opts.length === 0) {
      this.selectedStageChangeId = "";
      return;
    }
    // Một Team thường map một Queue; nhiều bản ghi → lấy bản ghi đầu (cùng queue label).
    this.selectedStageChangeId = opts[0].stageChangeId || "";
  }

  _notifySelectionChange() {
    const params = this.getSubmitParams();
    this.dispatchEvent(
      new CustomEvent("routingselectionchange", {
        detail: params,
        bubbles: true,
        composed: true,
      }),
    );
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

  handleTeamChange(event) {
    this.selectedTeam = event.detail.value;
    this._syncQueueFromTeam();
    this._notifySelectionChange();
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

  _optionsLoadedFor;
}
