import submitScopedRouteToApex from "@salesforce/apex/FEC_ScopedStageChangeRoutingService.submitRouteTo";
import saveCaseNOC from "@salesforce/apex/FEC_CaseBusinessService.saveCaseNOC";
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

  return base && host._documentRequestStageChangeRoutingActive !== true;
}

/** PhongBT read-only: chỉ Stage 1 trên BP Document Request / Original MRC Return. */
export function computeShowDocumentRequestStageChangeRoutingSection(host) {
  return (
    host.isEdit === true &&
    host._documentRequestStageChangeRoutingActive === true &&
    !shouldPreferScopedRoutingFromStage2(host)
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
  if (host.showDocumentRequestStageChangeRoutingSection) {
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

  if (routeToEle && noUpdate && !hasAddressUpdate) {
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
