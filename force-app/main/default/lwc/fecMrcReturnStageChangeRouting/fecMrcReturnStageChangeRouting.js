/**
 * MRC Return RL05 — auto Team/Queue Route to từ FEC_Stage_Change__c (Stage 1 read-only).
 */
import {
  MRC_OPT_CANCEL_PREVIOUS,
  isMrcNotReceivedConfirmation,
  getCaseFieldValue,
  resolveMrcReturnSubCodeCode,
} from "c/fecMrcReturnCaseLogic";

const TEAM_CP = "CP";
const TEAM_SP = "SP";
const TEAM_F2F = "F2F";
const TEAM_PM = "PM";

const FIELD_DELIVERY_OPTION = "FEC_Delivery_Option_2__c";
const FIELD_CUSTOMER_CONFIRMATION = "FEC_Customer_Confirmation__c";
const FIELD_HANDLING_OPTION = "FEC_MRC_Request_Handling_Option__c";
const OBJ_CASE = "Case";

function formatRoutingFieldValue(value) {
  if (value == null) {
    return "";
  }
  if (Array.isArray(value)) {
    return value
      .map((item) => String(item ?? "").trim())
      .filter(Boolean)
      .join(";");
  }
  return String(value).trim();
}

function resolveDeliveryOption(business, deliveryOptionOverride) {
  const override = formatRoutingFieldValue(deliveryOptionOverride);
  if (override) {
    return override;
  }
  return formatRoutingFieldValue(
    getCaseFieldValue(business, FIELD_DELIVERY_OPTION),
  );
}

function resolveCustomerConfirmation(business, customerConfirmationValue) {
  const override = formatRoutingFieldValue(customerConfirmationValue);
  if (override) {
    return override;
  }
  const draft = formatRoutingFieldValue(business?.mrcCustomerConfirmationDraft);
  if (draft) {
    return draft;
  }
  const saved = formatRoutingFieldValue(business?.mrcCustomerConfirmationSaved);
  if (saved) {
    return saved;
  }
  return getCaseFieldValue(business, FIELD_CUSTOMER_CONFIRMATION);
}

function resolveHandlingOption(business, handlingOptionValue) {
  const override = formatRoutingFieldValue(handlingOptionValue);
  if (override) {
    return override;
  }
  const saved = formatRoutingFieldValue(business?.mrcHandlingOptionSaved);
  if (saved) {
    return saved;
  }
  return getCaseFieldValue(business, FIELD_HANDLING_OPTION);
}

function normalizeText(value) {
  if (value == null) {
    return "";
  }
  return String(value)
    .trim()
    .toLowerCase()
    .replace(/đ/g, "d")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function deliveryTokens(deliveryOptionRaw) {
  const raw = normalizeText(deliveryOptionRaw);
  if (!raw) {
    return [];
  }
  return raw
    .split(/[;,]/)
    .map((t) => t.trim())
    .filter(Boolean);
}

function includesAddress(tokens) {
  return tokens.some(
    (t) => t.includes("dia chi") || t === "address" || t.includes("address"),
  );
}

function includesOffice(tokens) {
  return tokens.some(
    (t) => t.includes("van phong") || t === "office" || t.includes("office"),
  );
}

function includesPos(tokens) {
  return tokens.some(
    (t) =>
      t === "pos" ||
      t.includes("pos") ||
      t === "rl05_pos" ||
      t.includes("rl05_pos"),
  );
}

function includesEmail(tokens) {
  return tokens.some((t) => t === "email" || t.includes("email"));
}

/** RL05.01 — Địa chỉ | Văn phòng | POS → CP */
export function matchesRl0501Delivery(deliveryOptionRaw) {
  const tokens = deliveryTokens(deliveryOptionRaw);
  return includesAddress(tokens) || includesOffice(tokens) || includesPos(tokens);
}

/** RL05.03 — Địa chỉ | POS | Email → SP */
export function matchesRl0503DeliveryAddressOrPos(deliveryOptionRaw) {
  const tokens = deliveryTokens(deliveryOptionRaw);
  return includesAddress(tokens) || includesPos(tokens) || includesEmail(tokens);
}

/** RL05.03 — chỉ Văn phòng → F2F */
export function matchesRl0503DeliveryOfficeOnly(deliveryOptionRaw) {
  const tokens = deliveryTokens(deliveryOptionRaw);
  return includesOffice(tokens) && !includesAddress(tokens) && !includesPos(tokens);
}

function resolveRl0502FlowTeam(ctx) {
  if (ctx?.autoRoutePayment === true) {
    return TEAM_PM;
  }
  if (ctx?.autoRouteCp === true) {
    return TEAM_CP;
  }
  const flow = String(ctx?.processingFlow ?? "")
    .trim()
    .toUpperCase();
  if (flow === "PAYMENT_SUPPORT") {
    return TEAM_PM;
  }
  if (flow === "CP_SUPPORT") {
    return TEAM_CP;
  }
  return null;
}

function isMrcCancelPreviousOption(value) {
  const normalized = String(value ?? "")
    .trim()
    .toLowerCase();
  if (!normalized) {
    return false;
  }
  return (
    normalized === MRC_OPT_CANCEL_PREVIOUS.toLowerCase() ||
    normalized.includes("cancel previous") ||
    normalized.includes("huy yeu cau cu") ||
    normalized.includes("hủy yêu cầu cũ")
  );
}

function resolveRl0502DeliveryCpTeam(deliveryOption) {
  return matchesRl0501Delivery(deliveryOption) ? TEAM_CP : null;
}

function isRl0502SubCode(subCodeCode) {
  return String(subCodeCode ?? "")
    .toUpperCase()
    .includes("RL05.02");
}

function isRl0501SubCode(subCodeCode) {
  return String(subCodeCode ?? "")
    .toUpperCase()
    .includes("RL05.01");
}

function isRl0503SubCode(subCodeCode) {
  return String(subCodeCode ?? "")
    .toUpperCase()
    .includes("RL05.03");
}

export function isMrcReturnRoutingSubCode(subCodeCode) {
  const upper = String(subCodeCode ?? "").toUpperCase();
  return (
    upper.includes("RL05.01") ||
    upper.includes("RL05.02") ||
    upper.includes("RL05.03")
  );
}

function hasMrcDupBannerFromBusiness(business, ctx) {
  if (ctx?.showMrcDupBanner === true) {
    return true;
  }
  const dupId = String(business?.mrcRl0502DuplicateOpenCaseId ?? "").trim();
  return dupId.length >= 15;
}

function inferRl0502Scenario(business, ctx) {
  const subCode = resolveMrcReturnSubCodeCode(business);
  const isReturn =
    ctx?.isReturnSubCode === true || isRl0502SubCode(subCode);
  if (!isReturn) {
    return null;
  }
  if (ctx?.rl05Scenario) {
    return ctx.rl05Scenario;
  }
  const cond1 = hasMrcDupBannerFromBusiness(business, ctx);
  const cond2 = ctx?.meetsCondition2 === true;
  if (cond1 && cond2) {
    return "TH1";
  }
  if (cond1) {
    return "TH2";
  }
  if (cond2) {
    return "TH3";
  }
  return "TH4";
}

function resolveRl0502TeamFromInputs(
  rl05Scenario,
  flowTeam,
  deliveryOption,
  option2Selected,
  notReceived,
) {
  const deliveryTeam = resolveRl0502DeliveryCpTeam(deliveryOption);

  if (rl05Scenario === "TH1") {
    if (notReceived && option2Selected) {
      if (deliveryTeam) {
        return { teamCode: deliveryTeam, scenario: "IV-1-DELIVERY" };
      }
      if (flowTeam) {
        return { teamCode: flowTeam, scenario: "IV-1" };
      }
    }
    return null;
  }

  if (rl05Scenario === "TH2") {
    if (option2Selected || notReceived) {
      if (flowTeam) {
        return { teamCode: flowTeam, scenario: "IV-2" };
      }
      if (deliveryTeam) {
        return { teamCode: deliveryTeam, scenario: "IV-2-DELIVERY" };
      }
    }
    return null;
  }

  if (rl05Scenario === "TH3") {
    if (option2Selected && deliveryTeam) {
      return { teamCode: deliveryTeam, scenario: "IV-3-DELIVERY" };
    }
    if (notReceived && flowTeam) {
      return { teamCode: flowTeam, scenario: "IV-3" };
    }
    return null;
  }

  if (rl05Scenario === "TH4") {
    if (deliveryTeam) {
      return { teamCode: flowTeam || TEAM_CP, scenario: "TH4" };
    }
    return null;
  }

  return null;
}

/**
 * @returns {{ eligible: boolean, team: string|null, teamCode: string|null, scenario: string|null, deliveryOption: string }}
 */
export function getMrcReturnRoutingContext(
  business,
  handlingOptionValue,
  customerConfirmationValue,
  deliveryOptionOverride,
) {
  const subCodeCode = resolveMrcReturnSubCodeCode(business);
  const ctx = business?.mrcRl05Ui;
  const deliveryOption = resolveDeliveryOption(
    business,
    deliveryOptionOverride,
  );
  const confirmation = resolveCustomerConfirmation(
    business,
    customerConfirmationValue,
  );
  const handlingOption = resolveHandlingOption(
    business,
    handlingOptionValue,
  );
  const option2Selected = isMrcCancelPreviousOption(handlingOption);
  const notReceived = isMrcNotReceivedConfirmation(confirmation);

  function buildEligible(teamCode, scenario) {
    const code = String(teamCode ?? "").trim().toUpperCase();
    return {
      eligible: true,
      team: code,
      teamCode: code,
      scenario,
      deliveryOption,
    };
  }

  function buildIneligible() {
    return {
      eligible: false,
      team: null,
      teamCode: null,
      scenario: null,
      deliveryOption,
    };
  }

  if (isRl0501SubCode(subCodeCode)) {
    if (matchesRl0501Delivery(deliveryOption)) {
      return buildEligible(TEAM_CP, "I");
    }
    return buildIneligible();
  }

  if (isRl0503SubCode(subCodeCode)) {
    if (matchesRl0503DeliveryOfficeOnly(deliveryOption)) {
      return buildEligible(TEAM_F2F, "III");
    }
    if (matchesRl0503DeliveryAddressOrPos(deliveryOption)) {
      return buildEligible(TEAM_SP, "II");
    }
    return buildIneligible();
  }

  if (!isRl0502SubCode(subCodeCode)) {
    return buildIneligible();
  }

  const rl05Scenario = inferRl0502Scenario(business, ctx);
  const flowTeam = resolveRl0502FlowTeam(ctx);

  const resolved = resolveRl0502TeamFromInputs(
    rl05Scenario,
    flowTeam,
    deliveryOption,
    option2Selected,
    notReceived,
  );
  if (resolved?.teamCode) {
    return buildEligible(resolved.teamCode, resolved.scenario);
  }

  if (flowTeam && (ctx?.autoRouteCp === true || ctx?.autoRoutePayment === true)) {
    const needsHandling =
      ctx?.dupCaseOnly === true ||
      hasMrcDupBannerFromBusiness(business, ctx) ||
      ctx?.showHandlingRadioOnNotReceived === true;
    if (!needsHandling || isMrcCancelPreviousOption(handlingOption)) {
      return buildEligible(flowTeam, rl05Scenario || "FLOW");
    }
    if (matchesRl0501Delivery(deliveryOption)) {
      return buildEligible(flowTeam, "DELIVERY-FLOW");
    }
  }

  if (option2Selected && resolveRl0502DeliveryCpTeam(deliveryOption)) {
    return buildEligible(TEAM_CP, "OPTION2-DELIVERY-FALLBACK");
  }

  return buildIneligible();
}

export function getBusinessFieldValue(business, objectName, apiName) {
  return getCaseFieldValue(business, apiName);
}

export { FIELD_DELIVERY_OPTION, OBJ_CASE };