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
const LWC_MRC_DELIVERY = "fec_ContractClosureForm";
const SECTION_NAME_CASE_INFORMATION = "Case Information";
const SUBSECTION_NAME_PROPERTY_INFO = "Property Info";
const MRC_RETURN_FORM = "fec_MrcReturnCaseForm";

const ACTION_ROUTE_TO = "Route to";
const ACTION_REJECT = "Reject";
const ACTION_CANCEL = "Cancel";

export function getMrcRl05Ui(business) {
  return business?.mrcRl05Ui || null;
}

export function isMrcRl05Branch(business) {
  const ctx = getMrcRl05Ui(business);
  if (ctx?.isRl05Branch === true) {
    return true;
  }
  const subCodeUpper = String(business?.subCodeCode ?? STR_EMPTY).toUpperCase();
  const isRl05OnBusiness =
    subCodeUpper.includes("RL05") ||
    String(business?.subCategoryCode ?? STR_EMPTY)
      .toUpperCase()
      .includes("RL05");
  return isRl05OnBusiness;
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
          return typeof v === "string" ? v.trim() : (v ?? STR_EMPTY);
        }
      }
    }
  }
  return STR_EMPTY;
}

export function showMrcRl0502DupBanner(business) {
  const ctx = getMrcRl05Ui(business);
  if (ctx?.showMrcDupBanner !== true) {
    return false;
  }
  const v = business?.mrcRl0502DuplicateOpenCaseId;
  return typeof v === "string" && v.length >= 15;
}

function isMrcRl05PhotoSubCodeFromBusiness(business) {
  const code = String(business?.subCodeCode ?? STR_EMPTY).toUpperCase();
  return code.includes("RL05.01") || code.includes("RL05.03");
}

function shouldShowMrcDeliveryForm(ctx, business, handlingOptionValue) {
  if (isMrcRl05PhotoSubCodeFromBusiness(business)) {
    return true;
  }
  if (!ctx || ctx.showDeliveryForm !== true) {
    return false;
  }
  if (
    ctx.dupCaseOnly === true &&
    handlingOptionValue !== MRC_OPT_CANCEL_PREVIOUS
  ) {
    return false;
  }
  if (
    ctx.isReturnSubCode &&
    showMrcRl0502DupBanner(business) &&
    getCaseFieldValue(business, FIELD_MRC_CUSTOMER_CONFIRMATION) ===
      MRC_CONF_NOT_RECEIVED &&
    !handlingOptionValue
  ) {
    return false;
  }
  return true;
}

function normalizeMasterDataLwcEntry(entry) {
  if (typeof entry === "string") {
    return { componentName: entry };
  }
  const o = entry || {};
  return { componentName: o.componentName };
}

/** Chèn fec_MrcReturnCaseForm vào Case Information khi RL05 (nếu master data chưa có). */
export function ensureMrcReturnCaseFormInBusiness(business) {
  if (!isMrcRl05Branch(business) || !business?.sectionlst) {
    return business;
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
  const exists = section.componentlst.some((entry) => {
    const meta = normalizeMasterDataLwcEntry(entry);
    return meta.componentName === MRC_RETURN_FORM;
  });
  if (!exists) {
    section.componentlst.unshift({
      componentName: MRC_RETURN_FORM,
      order: 0,
      fieldLayout: 12,
      subSectionName: null,
      fecMasterDataSettingIsEdit: true,
    });
  }
  return business;
}

export function applyMrcRl0502DupFieldLayout(business, handlingOptionValue) {
  if (!business?.sectionlst) {
    return { business, handlingOptionValue, rebuildSections: false };
  }

  const ctx = getMrcRl05Ui(business);
  const showDup = showMrcRl0502DupBanner(business);
  const confVal = getCaseFieldValue(business, FIELD_MRC_CUSTOMER_CONFIRMATION);
  const showDupInline =
    showDup &&
    ctx?.showCustomerConfirmation === true &&
    (confVal === MRC_CONF_NOT_RECEIVED || !confVal);
  const showDupStandalone = showDup && ctx?.dupCaseOnly === true;
  let nextHandling = handlingOptionValue;

  business.sectionlst.forEach((section) => {
    if (section.name === SECTION_NAME_CASE_INFORMATION) {
      section.showMrcRl0502DupStandalone = showDupStandalone;
    }
    section.subSectionlst?.forEach((sub) => {
      sub.objlst?.forEach((obj) => {
        obj.fieldlst?.forEach((field) => {
          if (field.apiName === FIELD_MRC_HANDLING_OPTION) {
            field.isHidden = showDup;
            if (showDup && !nextHandling && field.value) {
              nextHandling = field.value;
            }
          }
          if (field.apiName === FIELD_MRC_CUSTOMER_CONFIRMATION) {
            field.showMrcDupInline = showDupInline;
            field.isHidden = ctx?.showCustomerConfirmation === false;
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

  if (!showDup) {
    nextHandling = STR_EMPTY;
  }

  const visibility = applyMrcRl05SectionVisibility(business, nextHandling);
  return {
    business: { ...visibility.business },
    handlingOptionValue: nextHandling,
    rebuildSections: visibility.rebuildSections,
  };
}

export function applyMrcRl05SectionVisibility(business, handlingOptionValue) {
  const ctx = getMrcRl05Ui(business);
  if ((!ctx?.isRl05Branch && !isMrcRl05Branch(business)) || !business?.sectionlst) {
    return { business, rebuildSections: false };
  }

  const showDelivery = shouldShowMrcDeliveryForm(
    ctx,
    business,
    handlingOptionValue,
  );
  const hidePropertyInfo =
    ctx?.hidePropertyInfo === true || isMrcRl05PhotoSubCodeFromBusiness(business);
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
        hide = ctx?.hideMrcInfoLwc === true;
      } else if (name === LWC_MRC_DELIVERY) {
        hide = !showDelivery;
      } else if (name === MRC_RETURN_FORM) {
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
        hide = ctx?.hideMrcInfoLwc === true;
      } else if (dyn.componentName === LWC_MRC_DELIVERY) {
        hide = !showDelivery;
      } else if (dyn.componentName === MRC_RETURN_FORM) {
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

export function getMrcReturnAutoRoutingActionCode(business, isEdit) {
  const ctx = getMrcRl05Ui(business);
  if (!ctx?.isReturnSubCode || !isEdit) {
    return null;
  }
  if (ctx.autoRouteReject === true) {
    return ACTION_REJECT;
  }
  if (ctx.autoRoutePayment === true || ctx.autoRouteCp === true) {
    return ACTION_ROUTE_TO;
  }
  const conf = getCaseFieldValue(business, FIELD_MRC_CUSTOMER_CONFIRMATION);
  if (conf === MRC_CONF_RECEIVED) {
    return ACTION_CANCEL;
  }
  return null;
}

export function validateMrcReturnCase(business, handlingOptionValue) {
  if (showMrcRl0502DupBanner(business) && !handlingOptionValue) {
    return false;
  }
  return true;
}

export function isMrcReturnTrackedField(fieldName) {
  return (
    fieldName === FIELD_MRC_CUSTOMER_CONFIRMATION ||
    fieldName === FIELD_MRC_HANDLING_OPTION
  );
}
