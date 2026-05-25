/**
 * MRC Return (RL05) — logic tách khỏi fec_CaseBussiness.
 * FECREDIT_CSM_2025_KH-1269 / Batch 7
 */
import { STR_EMPTY } from "c/fec_CommonConst";

export const FIELD_MRC_CUSTOMER_CONFIRMATION = "FEC_Customer_Confirmation__c";
export const FIELD_MRC_HANDLING_OPTION = "FEC_MRC_Request_Handling_Option__c";
export const MRC_OPT_CANCEL_PREVIOUS =
  "Cancel previous request, create new request";
export const MRC_OPT_CANCEL_NEW =
  "Cancel new request, continue previous request handling";
export const MRC_CONF_NOT_RECEIVED = "Customer has not received MRC";
export const MRC_CONF_RECEIVED = "Customer received MRC";

const LWC_MRC_INFO = "fec_MRC";
const LWC_MRC_DELIVERY = "fec_MrcDeliveryForm";
const LWC_CONTRACT_CLOSURE = "fec_ContractClosureForm";
const FIELD_DELIVERY_OPTION = "FEC_Delivery_Option_2__c";
const SECTION_NAME_CASE_INFORMATION = "Case Information";
const SUBSECTION_NAME_PROPERTY_INFO = "Property Info";
const MRC_RETURN_PANEL = "fec_MrcReturnPanel";

const ACTION_ROUTE_TO = "Route to";
const ACTION_REJECT = "Reject";
const ACTION_CANCEL = "Cancel";

export function getMrcRl05Ui(business) {
  return business?.mrcRl05Ui || null;
}

function inferRl05FromStageName(stageName) {
  const upper = String(stageName ?? STR_EMPTY).toUpperCase();
  if (!upper.includes("RL05")) {
    return { subCodeCode: STR_EMPTY, subCategoryCode: STR_EMPTY };
  }
  let subCodeCode = "RL05";
  if (upper.includes("RL05.02")) {
    subCodeCode = "RL05.02";
  } else if (upper.includes("RL05.03")) {
    subCodeCode = "RL05.03";
  } else if (upper.includes("RL05.01")) {
    subCodeCode = "RL05.01";
  }
  return { subCodeCode, subCategoryCode: "RL05" };
}

/** Sub-Code RL05 đã resolve — dùng cho routing khi NOC/stage chưa kịp sync subCodeCode. */
export function resolveMrcReturnSubCodeCode(business) {
  const code = String(business?.subCodeCode ?? STR_EMPTY).toUpperCase();
  if (code.includes("RL05.01")) {
    return "RL05.01";
  }
  if (code.includes("RL05.02")) {
    return "RL05.02";
  }
  if (code.includes("RL05.03")) {
    return "RL05.03";
  }
  const ctx = getMrcRl05Ui(business);
  if (ctx?.isReturnSubCode === true) {
    return "RL05.02";
  }
  if (ctx?.isPhotoSubCode === true) {
    const fromStage = inferRl05FromStageName(business?.stageName);
    if (fromStage.subCodeCode.includes("RL05.03")) {
      return "RL05.03";
    }
    if (fromStage.subCodeCode.includes("RL05.01")) {
      return "RL05.01";
    }
    if (code.includes("RL05.03") || code.includes("GỬI MẪU") || code.includes("BIÊN NHẬN")) {
      return "RL05.03";
    }
    return "RL05.01";
  }
  const fromStage = inferRl05FromStageName(business?.stageName);
  if (fromStage.subCodeCode.includes("RL05.0")) {
    return fromStage.subCodeCode;
  }
  return code;
}

export function shouldActivateMrcReturnRouting(business) {
  const subCode = resolveMrcReturnSubCodeCode(business);
  const upper = String(subCode ?? STR_EMPTY).toUpperCase();
  return (
    upper.includes("RL05.01") ||
    upper.includes("RL05.02") ||
    upper.includes("RL05.03")
  );
}

/** Case Information bị chặn (Product Code ≠ TW) — chỉ hiện banner lỗi, không panel/routing. */
export function isMrcRl05CaseInformationBlocked(business) {
  if (business?.mrcRl05CaseInfoBlocked === true) {
    return true;
  }
  if (business?.mrcRl05CaseInfoWarningOnly === true) {
    return false;
  }
  return !!business?.sectionlst?.some(
    (section) =>
      section.name === SECTION_NAME_CASE_INFORMATION &&
      (section.hasError || section.error?.label),
  );
}

export function isMrcRl05Branch(business) {
  const ctx = getMrcRl05Ui(business);
  if (ctx?.isRl05Branch === true) {
    return true;
  }
  const subCodeUpper = String(business?.subCodeCode ?? STR_EMPTY).toUpperCase();
  if (
    subCodeUpper.includes("RL05") ||
    String(business?.subCategoryCode ?? STR_EMPTY)
      .toUpperCase()
      .includes("RL05")
  ) {
    return true;
  }
  const fromStage = inferRl05FromStageName(business?.stageName);
  return (
    fromStage.subCodeCode.includes("RL05") ||
    fromStage.subCategoryCode.includes("RL05")
  );
}

export function getCaseFieldValue(business, apiName) {
  const sections = business?.sectionlst ?? [];
  for (const section of sections) {
    for (const sub of section.subSectionlst ?? []) {
      for (const obj of sub.objlst ?? []) {
        if (obj.name !== "Case") continue;
        const f = obj.fieldlst?.find((x) => x.apiName === apiName);
        if (f != null) {
          const v = f.value;
          if (Array.isArray(v)) {
            return v
              .map((item) => String(item ?? STR_EMPTY).trim())
              .filter(Boolean)
              .join(";");
          }
          return typeof v === "string" ? v.trim() : (v ?? STR_EMPTY);
        }
      }
    }
  }
  return STR_EMPTY;
}

function hasMrcRl0502DuplicateCaseId(business) {
  const v = String(business?.mrcRl0502DuplicateOpenCaseId ?? STR_EMPTY).trim();
  return v.length >= 15;
}

export function isMrcNotReceivedConfirmation(value) {
  const normalized = String(value ?? STR_EMPTY).trim().toLowerCase();
  if (!normalized) {
    return false;
  }
  return (
    normalized === MRC_CONF_NOT_RECEIVED.toLowerCase() ||
    normalized.includes("not received") ||
    normalized.includes("chua nhan") ||
    normalized.includes("chua xac nhan") ||
    normalized.includes("chưa nhận") ||
    normalized.includes("chưa xác nhận")
  );
}

export function resolveMrcCustomerConfirmation(business, override) {
  if (override != null && String(override).trim()) {
    return String(override).trim();
  }
  const draft =
    typeof business?.mrcCustomerConfirmationDraft === "string"
      ? business.mrcCustomerConfirmationDraft.trim()
      : STR_EMPTY;
  if (draft) {
    return draft;
  }
  return getCaseFieldValue(business, FIELD_MRC_CUSTOMER_CONFIRMATION);
}

export function isMrcReceivedConfirmation(value) {
  const normalized = String(value ?? STR_EMPTY).trim().toLowerCase();
  if (!normalized) {
    return false;
  }
  if (isMrcNotReceivedConfirmation(value)) {
    return false;
  }
  return (
    normalized === MRC_CONF_RECEIVED.toLowerCase() ||
    (normalized.includes("received") && !normalized.includes("not received")) ||
    normalized.includes("đã nhận") ||
    normalized.includes("đã xác nhận")
  );
}

function requiresHandlingOptionBeforeDelivery(ctx, business, confVal) {
  if (!ctx?.isReturnSubCode) {
    return false;
  }
  if (ctx.dupCaseOnly === true && showMrcRl0502DupBanner(business)) {
    return true;
  }
  return isMrcNotReceivedConfirmation(confVal);
}

export function showMrcRl0502DupBanner(business) {
  if (!hasMrcRl0502DuplicateCaseId(business)) {
    return false;
  }
  const ctx = getMrcRl05Ui(business);
  if (ctx?.showMrcDupBanner === false) {
    return false;
  }
  return true;
}

function isMrcRl0502ReturnBusiness(business) {
  const ctx = getMrcRl05Ui(business);
  if (ctx?.isReturnSubCode === true) {
    return true;
  }
  const subCode = resolveMrcReturnSubCodeCode(business);
  return String(subCode ?? STR_EMPTY).toUpperCase().includes("RL05.02");
}

/** Hiện Noti-11 + radio: RL05.02 + đã chọn "chưa xác nhận MRC". */
export function shouldShowMrcHandlingRadio(business, confirmationOverride) {
  if (!isMrcRl0502ReturnBusiness(business)) {
    return false;
  }
  const ctx = getMrcRl05Ui(business);
  if (ctx?.autoRouteReject === true) {
    return false;
  }
  const confVal = resolveMrcCustomerConfirmation(business, confirmationOverride);
  return isMrcNotReceivedConfirmation(confVal);
}

function isMrcRl05PhotoSubCodeFromBusiness(business) {
  const code = String(business?.subCodeCode ?? STR_EMPTY).toUpperCase();
  return code.includes("RL05.01") || code.includes("RL05.03");
}

function shouldShowMrcDeliveryForm(
  ctx,
  business,
  handlingOptionValue,
  customerConfirmationOverride,
) {
  if (isMrcRl05PhotoSubCodeFromBusiness(business)) {
    return true;
  }
  if (!ctx) {
    const code = String(business?.subCodeCode ?? STR_EMPTY).toUpperCase();
    return code.includes("RL05.02");
  }

  const confVal =
    customerConfirmationOverride != null &&
    String(customerConfirmationOverride).trim() !== STR_EMPTY
      ? String(customerConfirmationOverride).trim()
      : getCaseFieldValue(business, FIELD_MRC_CUSTOMER_CONFIRMATION);

  if (
    ctx?.showCustomerConfirmation === true &&
    isMrcReceivedConfirmation(confVal)
  ) {
    return false;
  }

  if (
    requiresHandlingOptionBeforeDelivery(ctx, business, confVal)
  ) {
    return handlingOptionValue === MRC_OPT_CANCEL_PREVIOUS;
  }

  if (ctx?.showDeliveryForm !== true) {
    return false;
  }
  return true;
}

export function shouldShowMrcReturnDelivery(
  ctx,
  business,
  handlingOptionValue,
  customerConfirmationValue,
) {
  return shouldShowMrcDeliveryForm(
    ctx,
    business,
    handlingOptionValue,
    customerConfirmationValue,
  );
}

function hasMrcReturnPanelInBusiness(business) {
  const section = business?.sectionlst?.find(
    (s) => s.name === SECTION_NAME_CASE_INFORMATION,
  );
  if (!section?.componentlst?.length) {
    return false;
  }
  return section.componentlst.some((entry) => {
    const meta = normalizeMasterDataLwcEntry(entry);
    return (
      meta.componentName === MRC_RETURN_PANEL ||
      meta.componentName === "fec_MrcReturnCaseForm"
    );
  });
}

function normalizeMasterDataLwcEntry(entry) {
  if (typeof entry === "string") {
    return { componentName: entry };
  }
  const o = entry || {};
  return { componentName: o.componentName };
}

/** Ẩn panel MRC khi Case Information bị chặn validation. */
export function stripMrcReturnPanelWhenBlocked(business) {
  if (!isMrcRl05CaseInformationBlocked(business) || !business?.sectionlst) {
    return business;
  }
  business.sectionlst.forEach((section) => {
    if (section.name !== SECTION_NAME_CASE_INFORMATION) {
      return;
    }
    if (Array.isArray(section.componentlst)) {
      section.componentlst = section.componentlst.filter((entry) => {
        const meta = normalizeMasterDataLwcEntry(entry);
        return (
          meta.componentName !== MRC_RETURN_PANEL &&
          meta.componentName !== "fec_MrcReturnCaseForm"
        );
      });
    }
    (section.resolvedComponentlst || []).forEach((dyn) => {
      if (
        dyn?.componentName === MRC_RETURN_PANEL ||
        dyn?.componentName === "fec_MrcReturnCaseForm"
      ) {
        dyn._hideForMrcRl05 = true;
      }
    });
  });
  return business;
}

/** Chèn fec_MrcReturnPanel vào Case Information khi RL05 (nếu master data chưa có). */
export function ensureMrcReturnCaseFormInBusiness(business) {
  if (
    !isMrcRl05Branch(business) ||
    !business?.sectionlst ||
    isMrcRl05CaseInformationBlocked(business)
  ) {
    return stripMrcReturnPanelWhenBlocked(business);
  }
  const section = business.sectionlst.find(
    (s) => s.name === SECTION_NAME_CASE_INFORMATION,
  );
  if (!section) {
    return business;
  }
  if (!section.componentlst) {
    section.componentlst = [];
  }
  const legacyNames = new Set([MRC_RETURN_PANEL, "fec_MrcReturnCaseForm"]);
  const exists = section.componentlst.some((entry) => {
    const meta = normalizeMasterDataLwcEntry(entry);
    return legacyNames.has(meta.componentName);
  });
  if (!exists) {
    section.componentlst.unshift({
      componentName: MRC_RETURN_PANEL,
      order: 0,
      fieldLayout: 12,
      subSectionName: null,
      fecMasterDataSettingIsEdit: true,
    });
  }
  return business;
}

export function applyMrcRl0502DupFieldLayout(
  business,
  handlingOptionValue,
  customerConfirmation,
) {
  if (!business?.sectionlst) {
    return { business, handlingOptionValue, rebuildSections: false };
  }

  const ctx = getMrcRl05Ui(business);
  const confVal = resolveMrcCustomerConfirmation(business, customerConfirmation);
  const showDup = showMrcRl0502DupBanner(business);
  const showDupInline = false;
  const showDupStandalone = false;
  const usePanel = isMrcRl05Branch(business);
  let nextHandling = handlingOptionValue;

  business.sectionlst.forEach((section) => {
    if (section.name === SECTION_NAME_CASE_INFORMATION) {
      section.showMrcRl0502DupStandalone = showDupStandalone;
    }
    section.subSectionlst?.forEach((sub) => {
      sub.objlst?.forEach((obj) => {
        obj.fieldlst?.forEach((field) => {
          if (field.apiName === FIELD_MRC_HANDLING_OPTION) {
            field.isHidden = ctx?.isReturnSubCode === true;
            if (ctx?.isReturnSubCode !== true) {
              field.isHidden = true;
            }
            if (showDup && !nextHandling && field.value) {
              nextHandling = field.value;
            }
          }
          if (field.apiName === FIELD_MRC_CUSTOMER_CONFIRMATION) {
            field.showMrcDupInline = showDupInline;
            field.isHidden =
              ctx?.isReturnSubCode !== true ||
              usePanel === true ||
              ctx?.showCustomerConfirmation !== true;
          }
          if (field.apiName === "FEC_Contract_Processing_Assessment_Type__c") {
            if (ctx?.isReturnSubCode) {
              field.isHidden = true;
            }
          }
        });
      });
    });
  });

  const needsHandlingRadio = shouldShowMrcHandlingRadio(business, confVal);

  if (!needsHandlingRadio) {
    nextHandling = STR_EMPTY;
  } else if (!nextHandling) {
    const saved = String(business?.mrcHandlingOptionSaved ?? STR_EMPTY).trim();
    if (saved) {
      nextHandling = saved;
    }
  }

  const visibility = applyMrcRl05SectionVisibility(
    business,
    nextHandling,
    confVal,
  );
  return {
    business: { ...visibility.business },
    handlingOptionValue: nextHandling,
    rebuildSections: visibility.rebuildSections,
  };
}

export function applyMrcRl05SectionVisibility(
  business,
  handlingOptionValue,
  customerConfirmation,
) {
  const ctx = getMrcRl05Ui(business);
  if ((!ctx?.isRl05Branch && !isMrcRl05Branch(business)) || !business?.sectionlst) {
    return { business, rebuildSections: false };
  }

  const confVal = resolveMrcCustomerConfirmation(business, customerConfirmation);
  const showDelivery = shouldShowMrcDeliveryForm(
    ctx,
    business,
    handlingOptionValue,
    confVal,
  );
  const hidePropertyInfo = ctx?.hidePropertyInfo === true;
  const panelMounted = hasMrcReturnPanelInBusiness(business);
  const panelShowsDelivery =
    panelMounted &&
    shouldShowMrcDeliveryForm(ctx, business, handlingOptionValue, confVal);
  let changed = false;

  business.sectionlst.forEach((section) => {
    if (section.name !== SECTION_NAME_CASE_INFORMATION) {
      return;
    }
    section.subSectionlst?.forEach((sub) => {
      const hideSub =
        hidePropertyInfo === true &&
        sub.name === SUBSECTION_NAME_PROPERTY_INFO;
      if (sub._hideForMrcRl05 !== hideSub || sub.hideForMrcRl05 !== hideSub) {
        sub._hideForMrcRl05 = hideSub;
        sub.hideForMrcRl05 = hideSub;
        changed = true;
      }
      if (hideSub) {
        sub.objlst?.forEach((obj) => {
          obj.fieldlst?.forEach((field) => {
            if (!field.isHidden) {
              field.isHidden = true;
              changed = true;
            }
          });
        });
      }
    });
    (section.componentlst || []).forEach((entry) => {
      const meta = normalizeMasterDataLwcEntry(entry);
      const name = meta.componentName;
      let hide = false;
      if (name === LWC_MRC_INFO) {
        hide =
          ctx?.hideMrcInfoLwc === true ||
          ctx?.isRl05Branch === true ||
          isMrcRl05Branch(business);
      } else if (name === LWC_MRC_DELIVERY || name === LWC_CONTRACT_CLOSURE) {
        hide = panelShowsDelivery === true;
      } else if (
        name === MRC_RETURN_PANEL ||
        name === "fec_MrcReturnCaseForm"
      ) {
        hide = false;
      }
      if (entry._hideForMrcRl05 !== hide) {
        entry._hideForMrcRl05 = hide;
        changed = true;
      }
    });
    (section.resolvedComponentlst || []).forEach((dyn) => {
      let hide = false;
      if (dyn.componentName === LWC_MRC_INFO) {
        hide =
          ctx?.hideMrcInfoLwc === true ||
          ctx?.isRl05Branch === true ||
          isMrcRl05Branch(business);
      } else if (
        dyn.componentName === LWC_MRC_DELIVERY ||
        dyn.componentName === LWC_CONTRACT_CLOSURE
      ) {
        hide = panelShowsDelivery === true;
      } else if (
        dyn.componentName === MRC_RETURN_PANEL ||
        dyn.componentName === "fec_MrcReturnCaseForm"
      ) {
        hide = false;
      }
      if (dyn._hideForMrcRl05 !== hide) {
        dyn._hideForMrcRl05 = hide;
        changed = true;
      }
    });
  });

  return { business, rebuildSections: changed };
}

export function getMrcReturnAutoRoutingActionCode(
  business,
  isEdit,
  customerConfirmationValue,
) {
  const ctx = getMrcRl05Ui(business);
  if (!ctx?.isReturnSubCode || !isEdit) {
    return null;
  }
  const draft =
    typeof business?.mrcCustomerConfirmationDraft === "string"
      ? business.mrcCustomerConfirmationDraft.trim()
      : STR_EMPTY;
  const conf =
    (typeof customerConfirmationValue === "string"
      ? customerConfirmationValue.trim()
      : STR_EMPTY) ||
    draft ||
    getCaseFieldValue(business, FIELD_MRC_CUSTOMER_CONFIRMATION);
  if (isMrcReceivedConfirmation(conf)) {
    return ACTION_CANCEL;
  }
  if (ctx.autoRouteReject === true) {
    return ACTION_REJECT;
  }
  if (ctx.autoRoutePayment === true || ctx.autoRouteCp === true) {
    return ACTION_ROUTE_TO;
  }
  return null;
}

export function validateMrcReturnCase(
  business,
  handlingOptionValue,
  customerConfirmation,
) {
  if (shouldShowMrcHandlingRadio(business, customerConfirmation)) {
    return Boolean(handlingOptionValue);
  }
  return true;
}

export function isMrcReturnTrackedField(fieldName) {
  return (
    fieldName === FIELD_MRC_CUSTOMER_CONFIRMATION ||
    fieldName === FIELD_MRC_HANDLING_OPTION
  );
}