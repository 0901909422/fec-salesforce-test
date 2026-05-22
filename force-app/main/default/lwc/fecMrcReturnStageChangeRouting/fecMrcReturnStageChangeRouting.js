/**
 * MRC Return RL05 — auto Team/Queue Route to từ FEC_Stage_Change__c (Stage 1 read-only).
 */
import {
  MRC_OPT_CANCEL_PREVIOUS,
  isMrcNotReceivedConfirmation,
  getCaseFieldValue,
} from "c/fecMrcReturnCaseLogic";

const TEAM_CP = "CP";
const TEAM_SP = "SP";
const TEAM_F2F = "F2F";
const TEAM_PM = "PM";

const FIELD_DELIVERY_OPTION = "FEC_Delivery_Option_2__c";
const FIELD_CUSTOMER_CONFIRMATION = "FEC_Customer_Confirmation__c";
const FIELD_HANDLING_OPTION = "FEC_MRC_Request_Handling_Option__c";
const OBJ_CASE = "Case";

function normalizeText(value) {
  if (value == null) {
    return "";
  }
  return String(value)
    .trim()
    .toLowerCase()
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
  return tokens.some((t) => t.includes("dia chi"));
}

function includesOffice(tokens) {
  return tokens.some((t) => t.includes("van phong"));
}

function includesPos(tokens) {
  return tokens.some((t) => t === "pos" || t.includes("pos"));
}

/** RL05.01 — Địa chỉ | Văn phòng | POS → CP */
export function matchesRl0501Delivery(deliveryOptionRaw) {
  const tokens = deliveryTokens(deliveryOptionRaw);
  return includesAddress(tokens) || includesOffice(tokens) || includesPos(tokens);
}

/** RL05.03 — Địa chỉ | POS → SP */
export function matchesRl0503DeliveryAddressOrPos(deliveryOptionRaw) {
  const tokens = deliveryTokens(deliveryOptionRaw);
  return includesAddress(tokens) || includesPos(tokens);
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
  return null;
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

/**
 * @returns {{ eligible: boolean, team: string|null, scenario: string|null, deliveryOption: string }}
 */
export function getMrcReturnRoutingContext(
  business,
  handlingOptionValue,
  customerConfirmationValue,
  deliveryOptionOverride,
) {
  const subCodeCode = business?.subCodeCode;
  const ctx = business?.mrcRl05Ui;
  const deliveryOption =
    deliveryOptionOverride ??
    getCaseFieldValue(business, FIELD_DELIVERY_OPTION) ??
    "";
  const confirmation =
    customerConfirmationValue ??
    getCaseFieldValue(business, FIELD_CUSTOMER_CONFIRMATION);
  const handlingOption =
    handlingOptionValue ?? getCaseFieldValue(business, FIELD_HANDLING_OPTION);
  const option2Selected = handlingOption === MRC_OPT_CANCEL_PREVIOUS;
  const notReceived = isMrcNotReceivedConfirmation(confirmation);

  if (isRl0501SubCode(subCodeCode)) {
    if (matchesRl0501Delivery(deliveryOption)) {
      return {
        eligible: true,
        team: TEAM_CP,
        scenario: "I",
        deliveryOption,
      };
    }
    return { eligible: false, team: null, scenario: null, deliveryOption };
  }

  if (isRl0503SubCode(subCodeCode)) {
    if (matchesRl0503DeliveryOfficeOnly(deliveryOption)) {
      return {
        eligible: true,
        team: TEAM_F2F,
        scenario: "III",
        deliveryOption,
      };
    }
    if (matchesRl0503DeliveryAddressOrPos(deliveryOption)) {
      return {
        eligible: true,
        team: TEAM_SP,
        scenario: "II",
        deliveryOption,
      };
    }
    return { eligible: false, team: null, scenario: null, deliveryOption };
  }

  if (!isRl0502SubCode(subCodeCode)) {
    return { eligible: false, team: null, scenario: null, deliveryOption };
  }

  const rl05Scenario = ctx?.rl05Scenario;
  const flowTeam = resolveRl0502FlowTeam(ctx);

  if (rl05Scenario === "TH1") {
    if (notReceived && option2Selected && flowTeam) {
      return {
        eligible: true,
        team: flowTeam,
        scenario: "IV-1",
        deliveryOption,
      };
    }
    return { eligible: false, team: null, scenario: null, deliveryOption };
  }

  if (rl05Scenario === "TH2") {
    if (option2Selected && flowTeam) {
      return {
        eligible: true,
        team: flowTeam,
        scenario: "IV-2",
        deliveryOption,
      };
    }
    return { eligible: false, team: null, scenario: null, deliveryOption };
  }

  if (rl05Scenario === "TH3") {
    if (notReceived && flowTeam) {
      return {
        eligible: true,
        team: flowTeam,
        scenario: "IV-3",
        deliveryOption,
      };
    }
    return { eligible: false, team: null, scenario: null, deliveryOption };
  }

  if (rl05Scenario === "TH4") {
    if (matchesRl0501Delivery(deliveryOption)) {
      return {
        eligible: true,
        team: flowTeam || TEAM_CP,
        scenario: "TH4",
        deliveryOption,
      };
    }
    return { eligible: false, team: null, scenario: null, deliveryOption };
  }

  return { eligible: false, team: null, scenario: null, deliveryOption };
}

export function getBusinessFieldValue(business, objectName, apiName) {
  return getCaseFieldValue(business, apiName);
}

export { FIELD_DELIVERY_OPTION, OBJ_CASE };
