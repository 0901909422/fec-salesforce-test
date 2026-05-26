import submitScopedRouteToApex from "@salesforce/apex/FEC_ScopedStageChangeRoutingService.submitRouteTo";
import getRouteToOptionForTeam from "@salesforce/apex/FEC_ScopedStageChangeRoutingService.getRouteToOptionForTeam";
import getRouteToTeamOptions from "@salesforce/apex/FEC_ScopedStageChangeRoutingService.getRouteToTeamOptions";
import saveCaseNOC from "@salesforce/apex/FEC_CaseBusinessService.saveCaseNOC";
import {
  getRdPaymentScopedStageTeam,
  resolveRdPaymentAssessmentApiValue,
  buildRdPaymentRoutingDisplayDefault,
  getRdPaymentScopedStageTeamMapForDebug,
  RD_PAYMENT_ROUTING_DISPLAY_DEFAULT,
} from "c/fec_RdPaymentRoutingUtils";
import FEC_MSG_Can_Not_Find_Next_Stage from "@salesforce/label/c.FEC_MSG_Can_Not_Find_Next_Stage";
import FEC_MSG_UPDATED_INFO_NOT_UPDATED from "@salesforce/label/c.FEC_MSG_UPDATED_INFO_NOT_UPDATED";
import FEC_Error_Title from "@salesforce/label/c.FEC_Error_Title";
import FEC_Warning_Title from "@salesforce/label/c.FEC_Warning_Title";
import { checkNoUpdateInSubmit } from "c/fec_CommonUtils";
import {
  isScopedStageChangeRoutingBusinessProcess,
  findRouteToActionId,
} from "c/fec_ScopedStageChangeRouting";

const ACTION_ROUTE_TO = "Route to";

export function extractStageNumber(stageName) {
  if (!stageName || typeof stageName !== "string") {
    return null;
  }
  const m = stageName.match(/stage\s*(\d+)/i);
  return m ? parseInt(m[1], 10) : null;
}

/** Stage 2+ trên BP Scoped: luôn dùng fec_ScopedStageChangeRoutingAction, không bật PhongBT read-only. */
export function shouldPreferScopedRoutingFromStage2(host) {
  if (!isScopedStageChangeRoutingBp(host)) {
    return false;
  }
  const stageNum = extractStageNumber(host.business?.stageName);
  return stageNum != null && stageNum >= 2;
}

export function isScopedStageChangeRoutingBp(host) {
  return isScopedStageChangeRoutingBusinessProcess(host.business?.code);
}

export function computeShowScopedStageChangeRoutingSection(host) {
  const base =
    host.isEdit === true &&
    isScopedStageChangeRoutingBp(host) &&
    host.business?.hasRoutingAction === true &&
    host.isRoutingAssignmentMode !== true;

  // Stage 2+: luôn section Scoped (combobox Team), không phụ thuộc flag PhongBT.
  if (shouldPreferScopedRoutingFromStage2(host)) {
    return base;
  }

  return base && host._documentRequestStageChangeRoutingActive !== true &&
    host._mrcReturnStageChangeRoutingActive !== true;
}

/** PhongBT read-only: chỉ Stage 1 trên BP Document Request / Original MRC Return. */
export function computeShowDocumentRequestStageChangeRoutingSection(host) {
  return (
    host.isEdit === true &&
    host._documentRequestStageChangeRoutingActive === true &&
    !shouldPreferScopedRoutingFromStage2(host)
  );
}

/** MRC Return RL05 — read-only Team/Queue Stage 1 (giống Document Request). */
export function computeShowMrcReturnStageChangeRoutingSection(host) {
  return (
    host.isEdit === true &&
    host._mrcReturnStageChangeRoutingActive === true &&
    !shouldPreferScopedRoutingFromStage2(host)
  );
}

export function computeShowStage1AutoRouteToRoutingSection(host) {
  return (
    computeShowDocumentRequestStageChangeRoutingSection(host) ||
    computeShowMrcReturnStageChangeRoutingSection(host)
  );
}

export function computeRouteToActionButtonId(host) {
  return findRouteToActionId(host.business?.routingActionlst);
}

export function computeShowLegacyRoutingSectionForDisplay(host) {
  return (
    host.showLegacyRoutingSection === true &&
    !computeShowScopedStageChangeRoutingSection(host)
  );
}

function getScopedRoutingCmp(host) {
  return host.template?.querySelector(
    "c-fec_-scoped-stage-change-routing-action",
  );
}

const DEBUG_RD_PAYMENT_SCOPED = true;

function rdPaymentDebug(label, payload) {
  if (!DEBUG_RD_PAYMENT_SCOPED) {
    return;
  }
  if (payload != null && typeof payload === "object") {
    try {
      console.log(`[RD-Payment-Scoped] ${label}`, JSON.stringify(payload));
    } catch (e) {
      console.log(`[RD-Payment-Scoped] ${label}`, payload);
    }
    return;
  }
  console.log(`[RD-Payment-Scoped] ${label}`, payload ?? "");
}

/**
 * Đồng bộ ngay khi onChange RD Payment Assessment — chỉ set Route to.
 * Team/Queue hiển thị sau khi Apex tra FEC_Stage_Change__c (FEC_Team_User_Group__c, FEC_Next_Queue__c).
 */
export function applyRdPaymentAssessmentRoutingImmediate(host, assessmentVal) {
  const picklistOptions =
    host.business?.picklistOptionsMap?.Case?.FEC_RD_Payment_Contract_Assessment__c;
  const assessmentApiValue = resolveRdPaymentAssessmentApiValue(
    assessmentVal,
    picklistOptions,
  );
  const teamUserGroupFilter = getRdPaymentScopedStageTeam(assessmentVal, picklistOptions);
  const routeToActionId = computeRouteToActionButtonId(host);

  const debugPayload = {
    rawValue: assessmentVal,
    assessmentApiValue,
    teamUserGroupFilter,
    getRouteToOptionForTeam: {
      caseId: host.recordId,
      teamUserGroup: teamUserGroupFilter,
      routeToActionId: routeToActionId || null,
    },
    isScopedStage2: shouldPreferScopedRoutingFromStage2(host),
    subCode: host.business?.subCodeCode,
    stageName: host.business?.stageName,
  };
  rdPaymentDebug("picklist-change", debugPayload);

  if (!assessmentApiValue) {
    rdPaymentDebug("picklist-change:skip-no-assessment", debugPayload);
    return { applied: false, ...debugPayload };
  }

  host._setActionValueByCode?.(ACTION_ROUTE_TO);
  host.business = {
    ...host.business,
    nextTeam: null,
    nextQueue: null,
  };
  host.business = { ...host.business };

  rdPaymentDebug("picklist-change:route-to-set", {
    actionValue: host.actionValue,
    note: "Chờ Apex trả FEC_Stage_Change__c.FEC_Team_User_Group__c",
  });

  return { applied: true, ...debugPayload };
}

function applyRdPaymentRoutingDisplayDefault(host) {
  const fallback = buildRdPaymentRoutingDisplayDefault();
  host.business = {
    ...host.business,
    nextTeam: fallback.nextTeam,
    nextQueue: fallback.nextQueue,
  };
  host.business = { ...host.business };
  getScopedRoutingCmp(host)?.clearForcedRoutingSelection?.();
  rdPaymentDebug("applyRdPaymentRoutingDisplayDefault", fallback);
}

function applyStageChangeOptToBusiness(host, opt) {
  if (!opt?.stageChangeId || !opt?.team) {
    return false;
  }
  // Team ← FEC_Stage_Change__c.FEC_Team_User_Group__c (opt.team)
  // Queue ← FEC_Stage_Change__c.FEC_Next_Queue__c (opt.queueDeveloperName → Group.Name = opt.queueLabel)
  const nextQueueFromStageChange =
    opt.queueDeveloperName || opt.queueLabel
      ? {
          label: opt.queueLabel || opt.queueDeveloperName || "",
          value: opt.queueValue || null,
          developerName: opt.queueDeveloperName || null,
        }
      : null;

  host.business = {
    ...host.business,
    nextTeam: opt.team,
    nextQueue: nextQueueFromStageChange,
  };
  host.business = { ...host.business };
  return true;
}

async function fetchRdPaymentStageChangeOption(host, assessmentVal) {
  await host._fetchRdPaymentQueues?.();

  const picklistOptions =
    host.business?.picklistOptionsMap?.Case?.FEC_RD_Payment_Contract_Assessment__c;
  const assessmentApiValue = resolveRdPaymentAssessmentApiValue(
    assessmentVal,
    picklistOptions,
  );
  const teamUserGroupFilter = getRdPaymentScopedStageTeam(
    assessmentVal,
    picklistOptions,
  );

  rdPaymentDebug("fetchRdPaymentStageChangeOption:filter", {
    assessmentVal,
    assessmentApiValue,
    teamUserGroupFilter,
    scopedTeamMap: getRdPaymentScopedStageTeamMapForDebug(),
  });

  if (!teamUserGroupFilter) {
    return { opt: null, teamUserGroupFilter: null, params: null, assessmentApiValue };
  }

  const routeToActionId = computeRouteToActionButtonId(host);
  const params = {
    caseId: host.recordId,
    teamUserGroup: teamUserGroupFilter,
    routeToActionId: routeToActionId || null,
  };

  rdPaymentDebug("getRouteToOptionForTeam:REQUEST", params);
  let opt;
  try {
    opt = await getRouteToOptionForTeam(params);
  } catch (err) {
    console.error("[RD-Payment-Scoped] getRouteToOptionForTeam:ERROR", err);
    return { opt: null, teamUserGroupFilter, params };
  }

  rdPaymentDebug("getRouteToOptionForTeam:RESPONSE", opt);

  if (!opt?.stageChangeId) {
    rdPaymentDebug("getRouteToOptionForTeam:no-match-fallback", {
      ...params,
      note: "Thử getRouteToTeamOptions và lọc theo FEC_Team_User_Group__c",
    });
    try {
      const allOpts = await getRouteToTeamOptions({
        caseId: host.recordId,
        routeToActionId: routeToActionId || null,
      });
      rdPaymentDebug("getRouteToTeamOptions:RESPONSE", allOpts);
      opt =
        (allOpts || []).find((o) => o.team === teamUserGroupFilter) ||
        (allOpts || []).find(
          (o) =>
            o.team?.trim()?.toLowerCase() ===
            teamUserGroupFilter.trim().toLowerCase(),
        ) ||
        null;
      rdPaymentDebug("getRouteToOptionForTeam:fallback-match", opt);
    } catch (fallbackErr) {
      console.error(
        "[RD-Payment-Scoped] getRouteToTeamOptions:fallback-error",
        fallbackErr,
      );
    }
  }

  return { opt, teamUserGroupFilter, params };
}

async function applyRoutingSelectionToChild(host, opt, maxAttempts = 8) {
  rdPaymentDebug("applyRoutingSelectionToChild:start", {
    stageChangeId: opt?.stageChangeId,
    team: opt?.team,
    queueValue: opt?.queueValue,
    maxAttempts,
  });
  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    const cmp = getScopedRoutingCmp(host);
    rdPaymentDebug(`applyRoutingSelectionToChild:attempt-${attempt + 1}`, {
      hasCmp: !!cmp,
      hasApplyFn: !!cmp?.applyRoutingSelection,
    });
    if (cmp?.applyRoutingSelection) {
      cmp.applyRoutingSelection(opt);
      const params = cmp.getSubmitParams?.();
      if (params?.selectedStageChangeId) {
        rdPaymentDebug("applyRoutingSelectionToChild:success", params);
        return params;
      }
    }
    await new Promise((resolve) => {
      window.setTimeout(resolve, 0);
    });
  }
  const fallback = {
    selectedStageChangeId: opt.stageChangeId,
    team: opt.team,
    queueId: opt.queueValue || null,
  };
  rdPaymentDebug("applyRoutingSelectionToChild:fallback", fallback);
  return fallback;
}

/**
 * RD Payment assessment → tra FEC_Stage_Change__c:
 *   FEC_Previous_Stage__c = Case.FEC_Current_Case_Stage__c
 *   FEC_Team_User_Group__c = filter theo assessment
 * Team/Queue UI lấy từ FEC_Stage_Change__c:
 *   • Team  ← FEC_Team_User_Group__c
 *   • Queue ← FEC_Next_Queue__c (hiển thị Group.Name)
 * @returns {Promise<boolean>}
 */
export async function applyRdPaymentStageChangeRoutingFromAssessment(
  host,
  assessmentVal,
) {
  const { opt, teamUserGroupFilter } = await fetchRdPaymentStageChangeOption(
    host,
    assessmentVal,
  );

  rdPaymentDebug("applyRdPaymentStageChangeRouting:entry", {
    assessmentVal,
    teamUserGroupFilter,
    isScopedStage2: shouldPreferScopedRoutingFromStage2(host),
    stageName: host.business?.stageName,
  });

  if (!teamUserGroupFilter) {
    rdPaymentDebug("applyRdPaymentStageChangeRouting:no-team-filter", {
      assessmentVal,
      assessmentApiValue: resolveRdPaymentAssessmentApiValue(
        assessmentVal,
        host.business?.picklistOptionsMap?.Case?.FEC_RD_Payment_Contract_Assessment__c,
      ),
    });
    host._setActionValueByCode?.(ACTION_ROUTE_TO);
    applyRdPaymentRoutingDisplayDefault(host);
    return true;
  }

  host._setActionValueByCode?.(ACTION_ROUTE_TO);

  if (!opt?.stageChangeId || !opt?.team) {
    rdPaymentDebug("applyRdPaymentStageChangeRouting:no-stage-change", {
      teamUserGroupFilter,
      note: "Đã gọi getRouteToOptionForTeam — không có FEC_Stage_Change__c",
      fallback: RD_PAYMENT_ROUTING_DISPLAY_DEFAULT,
    });
    applyRdPaymentRoutingDisplayDefault(host);
    return true;
  }

  applyStageChangeOptToBusiness(host, opt);
  rdPaymentDebug("applyRdPaymentStageChangeRouting:applied", {
    stageChangeId: opt.stageChangeId,
    teamFromStageChange: opt.team,
    queueFromNextQueue: opt.queueDeveloperName,
    queueLabel: opt.queueLabel,
  });

  if (shouldPreferScopedRoutingFromStage2(host)) {
    host._scopedRoutingSelection = await applyRoutingSelectionToChild(host, opt);
  }

  rdPaymentDebug("applyRdPaymentStageChangeRouting:done", {
    nextTeam: host.business?.nextTeam,
    nextQueue: host.business?.nextQueue,
    scopedRoutingSelection: host._scopedRoutingSelection,
  });
  return true;
}

/** Stage 2+ wrapper — gọi applyRdPaymentStageChangeRoutingFromAssessment. */
export async function applyRdPaymentScopedStageRouting(host, assessmentVal) {
  if (!shouldPreferScopedRoutingFromStage2(host)) {
    return false;
  }
  return applyRdPaymentStageChangeRoutingFromAssessment(host, assessmentVal);
}

export function isScopedRouteToWithTeamSelection(host) {
  if (!computeShowScopedStageChangeRoutingSection(host)) {
    return false;
  }
  const code = host._getCurrentActionCode?.();
  if (code !== ACTION_ROUTE_TO) {
    return false;
  }
  const stageNum = extractStageNumber(host.business?.stageName);
  return (
    host.business?.isSubmited === true &&
    stageNum != null &&
    stageNum >= 2
  );
}

async function executeScopedRouteToSubmit(host) {
  const cmp = getScopedRoutingCmp(host);
  const submitParams = cmp?.getSubmitParams?.() ?? {};
  const selectedStageChangeId = submitParams.selectedStageChangeId;
  if (!selectedStageChangeId) {
    host.showToast?.(FEC_Error_Title, FEC_MSG_Can_Not_Find_Next_Stage, "error");
    return false;
  }

  let actionId;
  host.business?.routingActionlst?.forEach((item) => {
    if (item.value === ACTION_ROUTE_TO || item.code === ACTION_ROUTE_TO) {
      actionId = item.id;
    }
  });

  if (host.business?.natureOfCase) {
    await saveCaseNOC({
      caseId: host.recordId,
      natureOfCaseId: host.business.natureOfCase,
    });
  }

  await submitScopedRouteToApex({
    caseId: host.recordId,
    selectedStageChangeId,
    selectedTeam: submitParams.team || null,
    actionId,
    natureOfCaseId: host.business?.natureOfCase,
    fieldListJson: host._collectFieldListJson?.(),
  });
  return true;
}

/** Routing action select: Scoped → Document Request → legacy lightning-select. */
export function resolveRoutingActionSelectEl(host) {
  if (computeShowScopedStageChangeRoutingSection(host)) {
    return getScopedRoutingCmp(host)?.getRoutingActionSelect?.() ?? null;
  }
  if (computeShowDocumentRequestStageChangeRoutingSection(host) ||
      computeShowMrcReturnStageChangeRoutingSection(host)) {
    const child = host.template?.querySelector(
      "c-fec_-document-request-routing-action",
    );
    return child?.getRoutingActionSelect?.() ?? null;
  }
  return (
    host.template?.querySelector('lightning-select[data-id="routing-action"]') ??
    null
  );
}

/** Validate combobox Team/Action trên section Scoped (nếu đang hiển thị). */
export function validateScopedRoutingSection(host) {
  if (!computeShowScopedStageChangeRoutingSection(host)) {
    return true;
  }
  const cmp = getScopedRoutingCmp(host);
  if (cmp?.reportRoutingValidity && !cmp.reportRoutingValidity()) {
    return false;
  }
  return true;
}

/**
 * Submit Route to Stage 2+ (Scoped BP): gọi từ fec_CaseBussiness.submit() khi đủ điều kiện.
 * @returns {Promise<boolean|null>} true/false nếu đã xử lý; null = không áp dụng, tiếp tục submit gốc.
 */
export async function trySubmitScopedRouteTo(host) {
  if (!isScopedRouteToWithTeamSelection(host)) {
    return null;
  }

  if (!host.validate?.()) {
    return false;
  }
  if (host._validateIPPClosureForSubmit && !host._validateIPPClosureForSubmit()) {
    return false;
  }

  const routeToEle = resolveRoutingActionSelectEl(host);
  const noUpdate = checkNoUpdateInSubmit(
    host._getCaseFieldOriginalValue.bind(host),
    host._getCaseFieldValue.bind(host),
    host._getCheckNoUpdateInSubmitOptions(),
  );
  const cmpAddr = host._getFecUpdateAddressCmp?.();
  const hasAddressUpdate =
    cmpAddr &&
    typeof cmpAddr.hasPendingAddressUpdates === "function" &&
    cmpAddr.hasPendingAddressUpdates();

  const hasSubmitPicklistChange =
    typeof host.hasAnySubmitCasePicklistFieldChanged === "function" &&
    host.hasAnySubmitCasePicklistFieldChanged();

  if (routeToEle && noUpdate && !hasAddressUpdate && !hasSubmitPicklistChange) {
    host.showToast?.(
      FEC_Warning_Title,
      FEC_MSG_UPDATED_INFO_NOT_UPDATED,
      "warning",
    );
    return false;
  }

  if (hasAddressUpdate) {
    const res = await cmpAddr.commitPendingAddressUpdatesForProcessAction();
    if (!res?.success) {
      host.showToast?.(
        FEC_Error_Title,
        res?.errorMessage || FEC_Error_Title,
        "error",
      );
      return false;
    }
    host._refreshFecUpdateAddressAfterProcessSuccess?.();
  }

  try {
    if (
      typeof host.persistSubmitCasePicklistFieldsBeforeSubmit === "function"
    ) {
      const persistResult =
        await host.persistSubmitCasePicklistFieldsBeforeSubmit();
      if (persistResult?.success === false) {
        host.showToast?.(
          FEC_Error_Title,
          persistResult.errorMessage || FEC_Error_Title,
          "error",
        );
        return false;
      }
    }

    const ok = await executeScopedRouteToSubmit(host);
    if (ok) {
      host._notifyRemovePhoneCaseSubmitted?.();
    }
    return ok;
  } catch (err) {
    const msg =
      err?.body?.message || err?.message || FEC_MSG_Can_Not_Find_Next_Stage;
    host.showToast?.(FEC_Error_Title, msg, "error");
    return false;
  }
}
