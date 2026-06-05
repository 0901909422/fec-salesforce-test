// Routing logic cho NOC Contract Closure — Sub Code RL16.02 / RL16.03
// Team/queue: FEC_RDPaymentContractAssessmentService.getRoutingConfig (Apex / FEC_ConstantCommon)

export const CASE_RD_PAYMENT_CONTRACT_ASSESSMENT  = "Case.FEC_RD_Payment_Contract_Assessment__c";
export const FIELD_RD_PAYMENT_CONTRACT_ASSESSMENT = "FEC_RD_Payment_Contract_Assessment__c";
export const SUB_CODE_RL16_02 = "RL16.02";
export const SUB_CODE_RL16_03 = "RL16.03";
export const RD_ASSESSMENT_CANNOT_CLOSE = "Cannot close contract";
export const RD_ASSESSMENT_CLOSE_WITH_STATEMENT =
  "Contract can be closed with statement";
export const RD_ASSESSMENT_CLOSE_WITHOUT_STATEMENT =
  "Contract can be closed without statement";

/** Hiển thị khi không tra được FEC_Stage_Change__c (Team + Queue). */
export const RD_PAYMENT_ROUTING_DISPLAY_DEFAULT = "default";

export function buildRdPaymentRoutingDisplayDefault() {
  return {
    nextTeam: RD_PAYMENT_ROUTING_DISPLAY_DEFAULT,
    nextQueue: {
      label: RD_PAYMENT_ROUTING_DISPLAY_DEFAULT,
      value: null,
    },
  };
}

/** assessment API value → giá trị filter FEC_Team_User_Group__c — nạp từ Apex (setRdPaymentScopedStageTeamMap). */
let _scopedStageTeamByAssessment = null;

/** Label VN (UI) → API value — khi picklistOptions chưa load hoặc onChange trả label. */
const VN_ASSESSMENT_LABEL_TO_API = {
  "Hợp đồng không thể đóng": RD_ASSESSMENT_CANNOT_CLOSE,
  "Hợp đồng có thể đóng với tờ trình": RD_ASSESSMENT_CLOSE_WITH_STATEMENT,
  "Hợp đồng có thể đóng không cần tờ trình":
    RD_ASSESSMENT_CLOSE_WITHOUT_STATEMENT,
};

/** Filter FEC_Team_User_Group__c khi Apex config chưa load — khớp FEC_ConstantCommon / FEC_RDPaymentContractAssessmentService. */
const FALLBACK_TEAM_FILTER_BY_ASSESSMENT = {
  [RD_ASSESSMENT_CANNOT_CLOSE]: "SP",
  [RD_ASSESSMENT_CLOSE_WITH_STATEMENT]: "CC",
  [RD_ASSESSMENT_CLOSE_WITHOUT_STATEMENT]: "CP",
};

export function setRdPaymentScopedStageTeamMap(map) {
  if (!map || typeof map !== "object") {
    _scopedStageTeamByAssessment = null;
    return;
  }
  _scopedStageTeamByAssessment = { ...map };
}

export function getRdPaymentScopedStageTeamMapForDebug() {
  return _scopedStageTeamByAssessment;
}

/** Kiểm tra subCodeCode thuộc RL16.02 hoặc RL16.03. */
export function isRdPaymentSubCode(subCodeCode) {
    return subCodeCode === SUB_CODE_RL16_02 || subCodeCode === SUB_CODE_RL16_03;
}

/** Số stage từ FEC_Current_Case_Stage__r.Name (vd. "... - Stage 2" → 2). */
export function extractCaseStageNumber(stageName) {
    if (!stageName || typeof stageName !== "string") {
        return null;
    }
    const m = stageName.match(/stage\s*(\d+)/i);
    return m ? parseInt(m[1], 10) : null;
}

/**
 * RL16.02/03 — stage RD Payment assessment (Stage 2 trên org; tên có thể không chứa "PM").
 * Stage 3+ → false (Team/Queue lấy từ FEC_Stage_Change__c trên DB).
 */
export function isRl16RdPaymentAssessmentStage(subCodeCode, stageName) {
    if (!isRdPaymentSubCode(subCodeCode)) {
        return false;
    }
    return extractCaseStageNumber(stageName) === 2;
}

/** RL16 assessment stage — đọc stage/sub-code từ host Case Business. */
export function isRl16RdPaymentAssessmentStageFromHost(host) {
    const stageName =
        host?._currentCaseStageName ?? host?.business?.stageName ?? "";
    return isRl16RdPaymentAssessmentStage(
        host?.business?.subCodeCode,
        stageName,
    );
}

/** Resolve assessment API value (onchange value hoặc label từ toLabel). */
export function resolveRdPaymentAssessmentApiValue(assessmentVal, picklistOptions) {
    if (!assessmentVal) {
        return null;
    }
    const knownKeys = _scopedStageTeamByAssessment
        ? Object.keys(_scopedStageTeamByAssessment)
        : [
            RD_ASSESSMENT_CANNOT_CLOSE,
            RD_ASSESSMENT_CLOSE_WITH_STATEMENT,
            RD_ASSESSMENT_CLOSE_WITHOUT_STATEMENT,
          ];
    if (knownKeys.includes(assessmentVal)) {
        return assessmentVal;
    }
    const trimmed = String(assessmentVal).trim();
    if (VN_ASSESSMENT_LABEL_TO_API[trimmed]) {
        return VN_ASSESSMENT_LABEL_TO_API[trimmed];
    }
    if (!Array.isArray(picklistOptions) || !picklistOptions.length) {
        return assessmentVal;
    }
    const byValue = picklistOptions.find((o) => o.value === assessmentVal);
    if (byValue) {
        return byValue.value;
    }
    const byLabel = picklistOptions.find(
        (o) => o.label === assessmentVal || o.label?.trim() === assessmentVal?.trim(),
    );
    return byLabel?.value ?? assessmentVal;
}

export function isRdPaymentCloseWithoutStatement(assessmentVal, picklistOptions) {
    return (
        resolveRdPaymentAssessmentApiValue(assessmentVal, picklistOptions) ===
        RD_ASSESSMENT_CLOSE_WITHOUT_STATEMENT
    );
}

/** RL16 — Action routing theo RD Payment Assessment. */
export const RD_PAYMENT_RL16_ACTION_RESOLVE = "Resolve";
export const RD_PAYMENT_RL16_ACTION_ROUTE_TO = "Route to";

/**
 * RL16.02/03: "đóng không cần tờ trình" → Resolve; các assessment khác → Route to.
 * @returns {"Resolve"|"Route to"|null}
 */
export function resolveRdPaymentRl16RoutingActionCode(
    assessmentVal,
    picklistOptions,
) {
    if (assessmentVal == null || String(assessmentVal).trim() === "") {
        return null;
    }
    if (isRdPaymentCloseWithoutStatement(assessmentVal, picklistOptions)) {
        return RD_PAYMENT_RL16_ACTION_RESOLVE;
    }
    if (resolveRdPaymentAssessmentApiValue(assessmentVal, picklistOptions)) {
        return RD_PAYMENT_RL16_ACTION_ROUTE_TO;
    }
    return null;
}

export function isRdPaymentCannotClose(assessmentVal, picklistOptions) {
    return (
        resolveRdPaymentAssessmentApiValue(assessmentVal, picklistOptions) ===
        RD_ASSESSMENT_CANNOT_CLOSE
    );
}

/** Giá trị filter FEC_Team_User_Group__c — Apex map, fallback khớp FEC_ConstantCommon. */
export function getRdPaymentScopedStageTeam(assessmentVal, picklistOptions) {
    const apiVal = resolveRdPaymentAssessmentApiValue(assessmentVal, picklistOptions);
    if (!apiVal) {
        return null;
    }
    const map = _scopedStageTeamByAssessment || FALLBACK_TEAM_FILTER_BY_ASSESSMENT;
    return map[apiVal] || FALLBACK_TEAM_FILTER_BY_ASSESSMENT[apiVal] || null;
}
