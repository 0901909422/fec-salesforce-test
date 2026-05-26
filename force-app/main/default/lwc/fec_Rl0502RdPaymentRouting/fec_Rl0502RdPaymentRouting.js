/**
 * RL05.02 — RD Payment assessment → Route to + Team/Queue (chỉ RL05.02 Stage 2+).
 * Không dùng cho RL16 / RL05.01 / RL05.03.
 */
import {
  isRdPaymentCloseWithoutStatement,
  isRdPaymentCannotClose,
  RD_ASSESSMENT_CLOSE_WITH_STATEMENT,
  resolveRdPaymentAssessmentApiValue,
} from "c/fec_RdPaymentRoutingUtils";
import { findRouteToActionId } from "c/fec_ScopedStageChangeRouting";
import {
  isCurrentCaseStageTeamPm,
  shouldPreferScopedRoutingFromStage2,
} from "c/fec_CaseBussinessScopedRoutingIntegration";
import getRouteToOptionForTeam from "@salesforce/apex/FEC_ScopedStageChangeRoutingService.getRouteToOptionForTeam";
import getRouteToTeamOptions from "@salesforce/apex/FEC_ScopedStageChangeRoutingService.getRouteToTeamOptions";

const ACTION_ROUTE_TO = "Route to";
const FIELD_ASSESSMENT = "FEC_RD_Payment_Contract_Assessment__c";

/** RL05.02 — ma trận assessment → Team / Queue (hardcode). */
const RL0502_RD_PAYMENT_ROUTING_RULES = [
  {
    id: "CLOSE_WITHOUT_STATEMENT",
    matches: isRl0502CloseWithoutStatement,
    team: "CP",
    queueDeveloperName: "FEC_DQ_Contract_Processing",
    queueLabel: "DQ - Contract Processing",
  },
  {
    id: "CANNOT_CLOSE",
    matches: isRl0502CannotClose,
    team: "SP",
    queueDeveloperName: "FEC_DQ_CS_Support",
    queueLabel: "DQ - CS Support",
  },
  {
    id: "CLOSE_WITH_STATEMENT",
    matches: isRl0502CloseWithStatement,
    team: "CC",
    queueDeveloperName: "FEC_DQ_CS_Customer_Care",
    queueLabel: "DQ - CS Customer Care",
  },
];

function isRl0502SubCode(business) {
  if (business?.mrcRl05Ui?.isReturnSubCode === true) {
    return true;
  }
  return String(business?.subCodeCode ?? "")
    .toUpperCase()
    .includes("RL05.02");
}

function getAssessmentPicklistOptions(host) {
  return host.business?.picklistOptionsMap?.Case?.[FIELD_ASSESSMENT];
}

function isRl0502CloseWithoutStatement(assessmentVal, picklistOptions) {
  if (isRdPaymentCloseWithoutStatement(assessmentVal, picklistOptions)) {
    return true;
  }
  const raw = String(assessmentVal ?? "").trim().toLowerCase();
  if (!raw) {
    return false;
  }
  return (
    raw.includes("không cần tờ trình") ||
    raw.includes("khong can to trinh") ||
    raw.includes("without statement") ||
    (raw.includes("có thể đóng") && raw.includes("không cần"))
  );
}

function isRl0502CannotClose(assessmentVal, picklistOptions) {
  if (isRdPaymentCannotClose(assessmentVal, picklistOptions)) {
    return true;
  }
  const raw = String(assessmentVal ?? "").trim().toLowerCase();
  if (!raw) {
    return false;
  }
  return (
    raw.includes("không thể đóng") ||
    raw.includes("khong the dong") ||
    raw.includes("cannot close")
  );
}

function isRl0502CloseWithStatement(assessmentVal, picklistOptions) {
  if (
    resolveRdPaymentAssessmentApiValue(assessmentVal, picklistOptions) ===
    RD_ASSESSMENT_CLOSE_WITH_STATEMENT
  ) {
    return true;
  }
  const raw = String(assessmentVal ?? "").trim().toLowerCase();
  if (!raw) {
    return false;
  }
  return (
    raw.includes("với tờ trình") ||
    raw.includes("voi to trinh") ||
    raw.includes("with statement") ||
    (raw.includes("có thể đóng") && raw.includes("với"))
  );
}

function resolveRl0502RoutingRule(assessmentVal, picklistOptions) {
  if (!assessmentVal) {
    return null;
  }
  return (
    RL0502_RD_PAYMENT_ROUTING_RULES.find((rule) =>
      rule.matches(assessmentVal, picklistOptions),
    ) || null
  );
}

/** RL05.02 + Stage 2+ (Scoped routing). */
export function isRl0502RdPaymentRoutingEligible(host) {
  if (!host?.isEdit || !host?.business) {
    return false;
  }
  if (!isRl0502SubCode(host.business)) {
    return false;
  }
  return shouldPreferScopedRoutingFromStage2(host) === true;
}

/** Khóa combobox Team khi stage hiện tại = PM và assessment thuộc ma trận RL05.02. */
export function isRl0502RdPaymentRouteToLocked(host) {
  if (!isRl0502RdPaymentRoutingEligible(host)) {
    return false;
  }
  if (!isCurrentCaseStageTeamPm(host)) {
    return false;
  }
  const assessmentVal = host._getCaseFieldValue?.(FIELD_ASSESSMENT);
  if (!assessmentVal) {
    return false;
  }
  return !!resolveRl0502RoutingRule(
    assessmentVal,
    getAssessmentPicklistOptions(host),
  );
}

function applyRl0502HardcodedTeamQueue(host, rule, queueValue) {
  host.business = {
    ...host.business,
    nextTeam: rule.team,
    nextQueue: {
      label: rule.queueLabel,
      value: queueValue ?? host.business?.nextQueue?.value ?? null,
      developerName: rule.queueDeveloperName,
    },
  };
  host.business = { ...host.business };
}

function buildRoutingOpt(apexOpt, rule) {
  return {
    stageChangeId: apexOpt?.stageChangeId || null,
    team: rule.team,
    queueDeveloperName: rule.queueDeveloperName,
    queueLabel: apexOpt?.queueLabel || rule.queueLabel,
    queueValue: apexOpt?.queueValue || null,
  };
}

async function resolveStageChangeOptForTeam(host, teamUserGroup) {
  const teamTrim = String(teamUserGroup ?? "").trim().toUpperCase();
  const routeToActionId =
    findRouteToActionId(host.business?.routingActionlst) || null;
  const baseParams = {
    caseId: host.recordId,
    teamUserGroup: teamTrim,
    routeToActionId,
  };
  try {
    let opt = await getRouteToOptionForTeam(baseParams);
    if (opt?.stageChangeId) {
      return opt;
    }
    const allOpts = await getRouteToTeamOptions({
      caseId: host.recordId,
      routeToActionId,
    });
    return (
      (allOpts || []).find(
        (o) => String(o.team ?? "").trim().toUpperCase() === teamTrim,
      ) || null
    );
  } catch (err) {
    console.error("[RL05.02 RD Payment] resolveStageChangeOptForTeam", err);
    return null;
  }
}

function publishRl0502RouteToTeamMessage(host, routingOpt) {
  if (typeof host._publishRl0502RouteToTeamSelection !== "function") {
    return;
  }
  host._publishRl0502RouteToTeamSelection({
    team: routingOpt.team,
    queueLabel: routingOpt.queueLabel,
    queueDeveloperName: routingOpt.queueDeveloperName,
    stageChangeId: routingOpt.stageChangeId || null,
    lockSelection: isRl0502RdPaymentRouteToLocked(host),
  });
}

async function syncRl0502ScopedRoutingChild(host, routingOpt) {
  const rule = RL0502_RD_PAYMENT_ROUTING_RULES.find(
    (r) => r.team === routingOpt.team,
  );
  if (rule) {
    applyRl0502HardcodedTeamQueue(host, rule, routingOpt.queueValue);
  }
  publishRl0502RouteToTeamMessage(host, routingOpt);

  for (let attempt = 0; attempt < 16; attempt += 1) {
    const cmp = host.template?.querySelector(
      "c-fec_-scoped-stage-change-routing-action",
    );
    if (cmp?.selectRouteToTeamForRl0502) {
      const applied = cmp.selectRouteToTeamForRl0502(routingOpt.team);
      if (applied) {
        host._scopedRoutingSelection = cmp.getSubmitParams?.() || {
          selectedStageChangeId: routingOpt.stageChangeId || null,
          team: routingOpt.team,
          queueId: routingOpt.queueValue || null,
        };
        return;
      }
    }
    await new Promise((resolve) => {
      window.setTimeout(resolve, 80);
    });
  }
}

/**
 * RL05.02 Stage 2+: assessment → Route to + Team/Queue theo ma trận rule.
 * @returns {Promise<boolean>}
 */
export async function applyRl0502RdPaymentAssessmentRouting(host, assessmentVal) {
  if (!isRl0502RdPaymentRoutingEligible(host)) {
    return false;
  }
  const picklistOptions = getAssessmentPicklistOptions(host);
  const rule = resolveRl0502RoutingRule(assessmentVal, picklistOptions);
  if (!rule) {
    return false;
  }

  host._setActionValueByCode?.(ACTION_ROUTE_TO);

  const apexOpt = await resolveStageChangeOptForTeam(host, rule.team);
  const routingOpt = buildRoutingOpt(apexOpt, rule);
  publishRl0502RouteToTeamMessage(host, routingOpt);
  await syncRl0502ScopedRoutingChild(host, routingOpt);

  return true;
}
