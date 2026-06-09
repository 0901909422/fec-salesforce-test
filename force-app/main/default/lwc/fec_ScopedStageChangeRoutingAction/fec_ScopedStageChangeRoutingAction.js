import { LightningElement, api, track, wire } from "lwc";
import {
  subscribe,
  unsubscribe,
  MessageContext,
  APPLICATION_SCOPE,
} from "lightning/messageService";
import ROUTE_TO_TEAM_SELECTION from "@salesforce/messageChannel/FEC_Route_To_Team_Selection__c";
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

function scopedActionDebug(label, payload) {
  console.log(`[RD-Payment-Scoped][ScopedAction] ${label}`, payload ?? "");
}

function normalizeTeamCode(value) {
  return String(value ?? "")
    .trim()
    .toUpperCase();
}

const ACTION_ROUTE_TO = "Route to";
/** Chỉ message / API từ fec_Rl0502RdPaymentRouting mới được auto-chọn Team. */
const ROUTE_TO_TEAM_SOURCE_RL0502 = "RL05.02";

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
  /** RD Payment assessment (Stage 2+): khóa chọn Team — hiển thị read-only. */
  @api lockRouteToTeamSelection = false;

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
  /** Selection ép từ parent (vd RD Payment assessment) — giữ sau khi reload options. */
  _pendingForcedSelection = null;
  /** Team chờ apply sau khi getRouteToTeamOptions load — chỉ RL05.02. */
  _pendingRouteToTeamCode = null;
  _pendingRouteToTeamSource = null;
  _routeToTeamSubscription = null;

  @wire(MessageContext)
  messageContext;

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

  /** Stage 2+, đã submit (qua Stage 1), Route to → combobox Team/Queue (trừ khi bị khóa). */
  get showTeamSelection() {
    return (
      this.expectsTeamSelection &&
      this.allOptions.length > 0 &&
      !this.lockRouteToTeamSelection &&
      !this._pendingForcedSelection
    );
  }

  get showTeamOptionsLoading() {
    if (
      this.lockRouteToTeamSelection &&
      this.showRouteTo &&
      !this._hasLockedRouteToDisplay
    ) {
      return true;
    }
    return this.expectsTeamSelection && !this._teamOptionsResolved;
  }

  get _hasLockedRouteToDisplay() {
    return !!(
      this.readOnlyTeam ||
      this._pendingForcedSelection?.team ||
      this.selectedTeam
    );
  }

  /** Team label — ưu tiên selection ép (RL05.02 / RD Payment) rồi mới parent readOnlyTeam. */
  get effectiveRouteToTeamDisplayLabel() {
    const forced = this._pendingForcedSelection;
    if (forced?.team) {
      return forced.team;
    }
    if (this.selectedTeam) {
      return this.selectedTeam;
    }
    return this.readOnlyTeam || "";
  }

  /** Queue label — ưu tiên FEC_Stage_Change__c.FEC_Next_Queue__c (Group.Name) từ selection ép. */
  get effectiveRouteToQueueDisplayLabel() {
    const forced = this._pendingForcedSelection;
    if (forced?.queueDeveloperName || forced?.queueLabel) {
      return forced.queueLabel || forced.queueDeveloperName || "";
    }
    return this.routeToQueueDisplayLabel || "";
  }

  /** Stage 1, RD Payment locked, hoặc sau load xong không có Team selectable → read-only. */
  get showRouteToReadOnly() {
    if (!this.showRouteTo || this.showTeamSelection) {
      return false;
    }
    if (this.lockRouteToTeamSelection && this._hasLockedRouteToDisplay) {
      return true;
    }
    if (this.lockRouteToTeamSelection) {
      return false;
    }
    if (this._pendingForcedSelection) {
      return this._hasLockedRouteToDisplay;
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
    } else if (
      this.lockRouteToTeamSelection &&
      this.showRouteTo &&
      !this._pendingForcedSelection?.stageChangeId &&
      !this.selectedStageChangeId
    ) {
      valid = false;
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

  /**
   * Áp dụng Team/Queue/Stage Change từ FEC_Stage_Change__c (vd RD Payment assessment).
   * Gọi sau khi parent resolve Apex — có thể trước hoặc sau khi load combobox options.
   */
  @api
  clearForcedRoutingSelection() {
    scopedActionDebug("clearForcedRoutingSelection");
    this._pendingForcedSelection = null;
  }

  @api
  applyRoutingSelection(opt) {
    scopedActionDebug("applyRoutingSelection", opt);
    if (!opt?.stageChangeId) {
      scopedActionDebug("applyRoutingSelection:skip-no-stageChangeId");
      return;
    }
    this._pendingForcedSelection = opt;
    this._mergeForcedOptionIntoAllOptions(opt);
    this._applySelection(opt);
    this._teamOptionsResolved = true;
    this._notifySelectionChange();
    this._logUiState("after-applyRoutingSelection");
  }

  /**
   * RL05.02 only — auto-chọn Team trên Route to (không dùng cho RL16 / Document Request).
   * @returns {boolean}
   */
  @api
  selectRouteToTeamForRl0502(teamCode) {
    const code = normalizeTeamCode(teamCode);
    if (!code) {
      return false;
    }
    scopedActionDebug("selectRouteToTeamForRl0502", { teamCode: code });
    return this._applyRl0502TeamSelection({ team: code });
  }

  _findOptionForTeam(teamCode) {
    const code = normalizeTeamCode(teamCode);
    if (!code || !Array.isArray(this.allOptions) || !this.allOptions.length) {
      return null;
    }
    return (
      this.allOptions.find((o) => normalizeTeamCode(o.team) === code) ||
      null
    );
  }

  _applyRl0502TeamSelection(opt) {
    const teamCode = normalizeTeamCode(opt?.team);
    if (!teamCode) {
      return false;
    }
    let match = null;
    if (opt?.stageChangeId) {
      match =
        this.allOptions.find((o) => o.stageChangeId === opt.stageChangeId) ||
        opt;
    }
    if (!match?.stageChangeId) {
      match = this._findOptionForTeam(teamCode);
    }
    if (!match?.stageChangeId) {
      this._pendingRouteToTeamCode = teamCode;
      this._pendingRouteToTeamSource = ROUTE_TO_TEAM_SOURCE_RL0502;
      return false;
    }
    const merged = {
      ...match,
      team: match.team || teamCode,
      queueLabel: opt?.queueLabel || match.queueLabel,
      queueDeveloperName:
        opt?.queueDeveloperName || match.queueDeveloperName,
      queueValue: opt?.queueValue ?? match.queueValue,
    };
    this._pendingRouteToTeamCode = null;
    this._pendingRouteToTeamSource = null;
    this._pendingForcedSelection = merged;
    this._mergeForcedOptionIntoAllOptions(merged);
    this._applySelection(merged);
    return true;
  }

  _applyPendingRouteToTeamIfAny() {
    if (
      !this._pendingRouteToTeamCode ||
      this._pendingRouteToTeamSource !== ROUTE_TO_TEAM_SOURCE_RL0502
    ) {
      return;
    }
    const code = this._pendingRouteToTeamCode;
    if (this._applyRl0502TeamSelection({ team: code })) {
      this._notifySelectionChange();
      this._logUiState("after-pending-rl0502-route-to-team");
    }
  }

  _handleRouteToTeamSelectionMessage(message) {
    const payload = message ?? {};
    if (payload.source !== ROUTE_TO_TEAM_SOURCE_RL0502) {
      return;
    }
    if (
      payload.caseId &&
      this.recordId &&
      payload.caseId !== this.recordId
    ) {
      return;
    }
    const actionCode = String(payload.actionCode ?? ACTION_ROUTE_TO).trim();
    if (actionCode && actionCode !== ACTION_ROUTE_TO) {
      return;
    }
    const team = payload.team;
    if (!team) {
      return;
    }
    scopedActionDebug("rl0502-route-to-team-message:received", payload);
    this._applyRl0502TeamSelection({
      team,
      queueLabel: payload.queueLabel,
      queueDeveloperName: payload.queueDeveloperName,
      queueValue: payload.queueValue,
      stageChangeId: payload.stageChangeId,
    });
    if (this.selectedTeam) {
      this._notifySelectionChange();
    }
  }

  _subscribeRouteToTeamSelection() {
    if (this._routeToTeamSubscription || !this.messageContext) {
      return;
    }
    this._routeToTeamSubscription = subscribe(
      this.messageContext,
      ROUTE_TO_TEAM_SELECTION,
      (message) => this._handleRouteToTeamSelectionMessage(message),
      { scope: APPLICATION_SCOPE },
    );
  }

  _logUiState(trigger) {
    scopedActionDebug(`ui-state:${trigger}`, {
      lockRouteToTeamSelection: this.lockRouteToTeamSelection,
      showRouteTo: this.showRouteTo,
      expectsTeamSelection: this.expectsTeamSelection,
      showTeamSelection: this.showTeamSelection,
      showRouteToReadOnly: this.showRouteToReadOnly,
      showTeamOptionsLoading: this.showTeamOptionsLoading,
      readOnlyTeam: this.readOnlyTeam,
      routeToQueueDisplayLabel: this.routeToQueueDisplayLabel,
      selectedTeam: this.selectedTeam,
      selectedStageChangeId: this.selectedStageChangeId,
      allOptionsCount: this.allOptions?.length ?? 0,
      hasPendingForced: !!this._pendingForcedSelection,
    });
  }

  _mergeForcedOptionIntoAllOptions(opt) {
    const exists = (this.allOptions || []).some(
      (o) => o.stageChangeId === opt.stageChangeId,
    );
    if (!exists) {
      this.allOptions = [...(this.allOptions || []), opt];
    }
  }

  _applyPendingForcedSelectionIfAny() {
    const opt = this._pendingForcedSelection;
    if (!opt?.stageChangeId) {
      return;
    }
    this._mergeForcedOptionIntoAllOptions(opt);
    this._applySelection(opt);
    this._notifySelectionChange();
  }

  connectedCallback() {
    this._subscribeRouteToTeamSelection();
    this._maybeLoadTeamOptions();
  }

  disconnectedCallback() {
    if (this._routeToTeamSubscription) {
      unsubscribe(this._routeToTeamSubscription);
      this._routeToTeamSubscription = null;
    }
  }

  renderedCallback() {
    this._subscribeRouteToTeamSelection();
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
    if (!this._pendingForcedSelection) {
      this.selectedTeam = "";
      this.selectedStageChangeId = "";
    }
    scopedActionDebug("loadTeamOptions:start", {
      caseId: this.recordId,
      routeToActionId: this.routeToActionId,
      lockRouteToTeamSelection: this.lockRouteToTeamSelection,
      loadKey: this._optionsLoadKey,
    });
    getRouteToTeamOptions({
      caseId: this.recordId,
      routeToActionId: this.routeToActionId,
    })
      .then((data) => {
        this.allOptions = data || [];
        if (this._pendingForcedSelection) {
          this._applyPendingForcedSelectionIfAny();
        } else if (
          this._pendingRouteToTeamCode &&
          this._pendingRouteToTeamSource === ROUTE_TO_TEAM_SOURCE_RL0502
        ) {
          this._applyPendingRouteToTeamIfAny();
        } else if (this.allOptions.length === 1) {
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
        this._logUiState("after-loadTeamOptions");
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
    scopedActionDebug("handleTeamChange", {
      value: event.detail.value,
      lockRouteToTeamSelection: this.lockRouteToTeamSelection,
    });
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
