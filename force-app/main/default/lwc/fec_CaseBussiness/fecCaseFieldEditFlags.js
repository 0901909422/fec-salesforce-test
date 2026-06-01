/**
 * Editable/readonly field Case Business — master data Apex + chế độ section.
 */

/** @returns {{ editable: boolean, readonly: boolean }} */
export function resolveFieldEditFlags(field, { sectionEditable, forceReadonly }) {
  const masterEditable = field.masterDataEditable === true;
  if (forceReadonly || !sectionEditable) {
    return { editable: false, readonly: true };
  }
  return { editable: masterEditable, readonly: !masterEditable };
}

/**
 * @param {object} host - fec_CaseBussiness (this)
 * @returns {{ editable: boolean, readonly: boolean }}
 */
export function resolveCaseFieldEditFlags(host, field, sectionName, subSectionName) {
  return resolveFieldEditFlags(field, {
    sectionEditable: host._isSectionFieldsEditable(sectionName),
    forceReadonly:
      host._isStage1RevertMasterReadonly() ||
      host._isGsrStage3PropertyInfoFieldReadonly(subSectionName) ||
      host._isUpdatedInfoReadonlyWhenHasAssignment(subSectionName) ||
      host._isMrcRl05MasterDataFieldLocked(field.apiName, subSectionName),
  });
}
