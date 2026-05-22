//PhongBT 18/05/26: Document Request sử dụng cục routing action mới
// Routing Team/Queue từ FEC_Stage_Change__c theo Sub-Code (bảng nghiệp vụ RL04/RC04).

const TEAM_CP = "CP";
const TEAM_OM = "OM";
const TEAM_SP = "SP";

/** Sub-code → FEC_Stage_Change__c.FEC_Team_User_Group__c */
const SUB_CODE_TEAM_MAP = {
  "RC04.01": TEAM_CP,
  "RL04.01": TEAM_CP,
  "RL04.04": TEAM_CP,
  "RC04.04": TEAM_OM,
  "RC04.03": TEAM_SP,
  "RC04.02": TEAM_SP,
  "RL04.02": TEAM_SP,
  "RL04.03": TEAM_SP,
};

const CONDITIONAL_DELIVERY_SUB_CODES = new Set(["RL04.02", "RL04.03"]);

const FIELD_DELIVERY_OPTION = "FEC_Delivery_Option_2__c";
const FIELD_DOCUMENT_TYPE = "FEC_Document_Type__c";
const OBJ_CASE = "Case";
const OBJ_ADDITIONAL_INFO = "FEC_Additional_Info__c";

function normalizeText(value) {
  if (value == null) return "";
  return String(value)
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

/** Multiselect picklist: "Email;Văn phòng" */
function deliveryTokens(deliveryOptionRaw) {
  const raw = normalizeText(deliveryOptionRaw);
  if (!raw) return [];
  return raw
    .split(/[;,]/)
    .map((t) => t.trim())
    .filter(Boolean);
}

/**
 * RL04.02 / RL04.03: Văn phòng | Địa chỉ OR (Email + Có mộc).
 */
export function matchesDocumentRequestDeliveryCondition(
  deliveryOptionRaw,
  documentTypeRaw
) {
  const tokens = deliveryTokens(deliveryOptionRaw);
  if (
    tokens.some((t) => t === "van phong" || t === "dia chi") ||
    tokens.some((t) => t.includes("van phong") || t.includes("dia chi"))
  ) {
    return true;
  }
  const docType = normalizeText(documentTypeRaw);
  if (tokens.some((t) => t === "email") && docType === "co moc") {
    return true;
  }
  return false;
}

export function resolveDocumentRequestStageChangeTeam(subCodeCode) {
  if (!subCodeCode) return null;
  return SUB_CODE_TEAM_MAP[subCodeCode] ?? null;
}

/** Sub-code có mapping team (dùng để hiện section Routing Action). */
export function isDocumentRequestRoutingSubCode(subCodeCode) {
  return resolveDocumentRequestStageChangeTeam(subCodeCode) != null;
}

/** RL04.02/RL04.03: Route To chỉ khi delivery + hình thức văn bản đúng điều kiện. */
export function isDocumentRequestDeliveryEligible(
  subCodeCode,
  deliveryOptionRaw,
  documentTypeRaw
) {
  if (!isDocumentRequestRoutingSubCode(subCodeCode)) {
    return false;
  }
  if (CONDITIONAL_DELIVERY_SUB_CODES.has(subCodeCode)) {
    return matchesDocumentRequestDeliveryCondition(
      deliveryOptionRaw,
      documentTypeRaw
    );
  }
  return true;
}

export function isDocumentRequestStageChangeRoutingSubCode(
  subCodeCode,
  deliveryOptionRaw,
  documentTypeRaw
) {
  return isDocumentRequestDeliveryEligible(
    subCodeCode,
    deliveryOptionRaw,
    documentTypeRaw
  );
}

/** Chuỗi dùng cho routing (multiselect có thể là mảng). */
export function formatRoutingFieldValue(value) {
  if (value == null) {
    return "";
  }
  if (Array.isArray(value)) {
    return value
      .map((v) => String(v ?? "").trim())
      .filter(Boolean)
      .join(";");
  }
  return String(value).trim();
}

/**
 * Ghi value vào mọi field cùng apiName trong sectionlst (trước khi đọc routing).
 */
export function setBusinessFieldValue(business, apiName, rawValue, objectName) {
  const value = formatRoutingFieldValue(rawValue);
  let updated = false;
  for (const section of business?.sectionlst ?? []) {
    for (const sub of section.subSectionlst ?? []) {
      for (const obj of sub.objlst ?? []) {
        if (objectName && obj.name !== objectName) {
          continue;
        }
        const f = obj.fieldlst?.find((x) => x.apiName === apiName);
        if (f == null) {
          continue;
        }
        f.value = value;
        if (!f.isDate) {
          f.displayValue = value;
        }
        f.readonlyDisplayValue = f.masked ? f.value : f.displayValue;
        updated = true;
      }
    }
  }
  return updated;
}

/**
 * Lấy giá trị field từ business.sectionlst (giống getFieldValue trong fecDocumentRequestPdfData).
 */
export function getBusinessFieldValue(business, objectName, apiName) {
  for (const section of business?.sectionlst ?? []) {
    for (const sub of section.subSectionlst ?? []) {
      for (const obj of sub.objlst ?? []) {
        if (obj.name !== objectName) continue;
        const f = obj.fieldlst?.find((x) => x.apiName === apiName);
        if (f != null) {
          return formatRoutingFieldValue(f.value);
        }
      }
    }
  }
  return "";
}

export function getDocumentRequestRoutingContext(business, options = {}) {
  const subCodeCode = business?.subCodeCode;
  const deliveryOption =
    formatRoutingFieldValue(options.deliveryOption) ||
    getBusinessFieldValue(business, OBJ_CASE, FIELD_DELIVERY_OPTION) ||
    getBusinessFieldValue(business, OBJ_ADDITIONAL_INFO, FIELD_DELIVERY_OPTION);
  const documentType =
    formatRoutingFieldValue(options.documentType) ||
    getBusinessFieldValue(business, OBJ_ADDITIONAL_INFO, FIELD_DOCUMENT_TYPE) ||
    getBusinessFieldValue(business, OBJ_CASE, FIELD_DOCUMENT_TYPE);

  const team = resolveDocumentRequestStageChangeTeam(subCodeCode);
  const subCodeSupported = isDocumentRequestRoutingSubCode(subCodeCode);
  const deliveryEligible = isDocumentRequestDeliveryEligible(
    subCodeCode,
    deliveryOption,
    documentType
  );

  return {
    subCodeCode,
    deliveryOption,
    documentType,
    team,
    subCodeSupported,
    deliveryEligible,
    eligible: deliveryEligible,
  };
}