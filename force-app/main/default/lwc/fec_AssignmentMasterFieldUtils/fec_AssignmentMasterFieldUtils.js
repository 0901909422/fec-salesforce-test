import { findPicklistOptionByRaw } from "c/fec_CommonUtils";

const MDS_TYPE_ASSIGNMENT = "Assignment";
const STR_EMPTY = "";

function syncFieldValueFromDom(caseBusiness, objectApiName, fieldApiName, field) {
  if (!caseBusiness?.template) {
    return field?.value;
  }
  const selectors = [
    `lightning-input-field[data-obj-name="${objectApiName}"][data-field="${fieldApiName}"]`,
    `lightning-input-field[data-field="${fieldApiName}"]`,
    `lightning-input[data-field="${fieldApiName}"]`,
  ];
  for (const sel of selectors) {
    const els = caseBusiness.template.querySelectorAll(sel);
    for (const el of els) {
      const raw = el?.value ?? el?.detail?.value;
      if (raw != null && String(raw).trim() !== STR_EMPTY) {
        return raw;
      }
    }
  }
  return field?.value;
}

function normalizePicklistValue(caseBusiness, objectApiName, fieldApiName, raw) {
  if (raw == null || String(raw).trim() === STR_EMPTY) {
    return null;
  }
  let val = String(raw).trim();
  const options =
    caseBusiness.business?.picklistOptionsMap?.[objectApiName]?.[fieldApiName];
  if (options?.length) {
    const found = findPicklistOptionByRaw(options, val);
    if (found) {
      val = found.value;
    }
  }
  return val;
}

/**
 * Collect editable Assignment master-data fields for Submit Assignment payload.
 * @param {HTMLElement} caseBusiness - fec_CaseBussiness component instance
 * @returns {string} JSON array of { objectApiName, fieldApiName, value }
 */
export function collectAssignmentMasterFieldPayload(caseBusiness) {
  const items = [];
  const sections = caseBusiness?.business?.sectionlst;
  if (!sections?.length) {
    return JSON.stringify(items);
  }

  for (const section of sections) {
    for (const sub of section.subSectionlst ?? []) {
      for (const obj of sub.objlst ?? []) {
        for (const field of obj.fieldlst ?? []) {
          if (field.mdsType !== MDS_TYPE_ASSIGNMENT) {
            continue;
          }
          if (
            field.editable !== true ||
            field.isHidden === true ||
            field.hidden === true
          ) {
            continue;
          }
          const objectApiName = obj.name;
          const fieldApiName = field.apiName;
          let raw = syncFieldValueFromDom(
            caseBusiness,
            objectApiName,
            fieldApiName,
            field,
          );
          const value = normalizePicklistValue(
            caseBusiness,
            objectApiName,
            fieldApiName,
            raw,
          );
          items.push({
            objectApiName,
            fieldApiName,
            value: value == null ? "" : String(value),
          });
        }
      }
    }
  }
  return JSON.stringify(items);
}
