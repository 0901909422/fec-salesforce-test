import { LightningElement, api } from "lwc";
import { STR_EMPTY } from "c/fec_CommonConst";
import { findPicklistOptionByRaw } from "c/fec_CommonUtils";

/**
 * Hiển thị Team/Queue Route to — khớp FEC_BlockCodeRoutingService.
 * Ưu tiên Block Code (CS D2C: OM/Day 2), sau đó Interaction RC09 (SP/DQ CS Support).
 * @author Toannd61
 */
const BLOCK_CODE_VALUES_OM_DAY2 = new Set(["F", "S", "G", "N"]);
const BLOCK_CODE1_VALUES_OM_DAY2 = new Set(["F", "G", "N"]);
const TEAM_OM_DISPLAY = "OM";
const TEAM_SP_DISPLAY = "SP";
const QUEUE_DAY_2_FALLBACK_LABEL = "Day 2 Check";
const QUEUE_DQ_CS_SUPPORT_FALLBACK_LABEL = "DQ - CS Support";

const INTERACTION_RC09_CATEGORY = "Request";
const INTERACTION_RC09_SUBCATEGORY = "RC09-Cập nhật thông tin";
const INTERACTION_RC09_SUBCODES = new Set([
  "RC09.01-Cập nhật số điện thoại",
  "RC09.02-Cập nhật địa chỉ",
]);

/** @author Toannd61 */
export default class FecBlockCodeRouteToInfo extends LightningElement {
  @api teamLabel;
  @api queueLabel;
  @api business;
  /** Map picklist (optional) — dùng để suy ra label Category/SubCode khi value là Id */
  @api picklistOptionsMap;

  _getObjectFieldHolder(objectName, apiName) {
    const sections = this.business?.sectionlst ?? [];
    for (const section of sections) {
      for (const sub of section.subSectionlst ?? []) {
        for (const obj of sub.objlst ?? []) {
          if (obj.name !== objectName) continue;
          const f = obj.fieldlst?.find((x) => x.apiName === apiName);
          if (f != null) {
            return f;
          }
        }
      }
    }
    return null;
  }

  _getCustomerHistoryFieldValue(apiName) {
    const f = this._getObjectFieldHolder("FEC_Customer_History__c", apiName);
    if (f == null) return STR_EMPTY;
    const v = f.value;
    if (v == null || v === STR_EMPTY) return STR_EMPTY;
    return typeof v === "string" ? v.trim() : String(v);
  }

  _resolvePicklistLabel(objectName, fieldApiName, rawValue) {
    if (rawValue == null || rawValue === STR_EMPTY) {
      return STR_EMPTY;
    }
    const opts =
      this.picklistOptionsMap?.[objectName]?.[fieldApiName] ??
      this.business?.picklistOptionsMap?.[objectName]?.[fieldApiName];
    const opt = findPicklistOptionByRaw(opts, rawValue);
    const label = opt?.label != null ? String(opt.label).trim() : STR_EMPTY;
    if (label) return label;
    return typeof rawValue === "string" ? rawValue.trim() : String(rawValue);
  }

  _getCaseFieldDisplay(apiName) {
    const f = this._getObjectFieldHolder("Case", apiName);
    if (f == null) return STR_EMPTY;
    const raw = f.value;
    if (raw == null || raw === STR_EMPTY) return STR_EMPTY;
    if (f.readonlyDisplayValue != null && String(f.readonlyDisplayValue).trim()) {
      return String(f.readonlyDisplayValue).trim();
    }
    return this._resolvePicklistLabel("Case", apiName, raw);
  }

  /** @author Toannd61 */
  _forcedBlockCodeFromForm() {
    const bc = this._getCustomerHistoryFieldValue("FEC_Block_Code__c");
    const bc1 = this._getCustomerHistoryFieldValue("FEC_Block_Code_1__c");
    return (
      BLOCK_CODE_VALUES_OM_DAY2.has(bc) || BLOCK_CODE1_VALUES_OM_DAY2.has(bc1)
    );
  }

  /** @author Toannd61 */
  _forcedInteractionRc09FromForm() {
    const interactionRaw = this._getObjectFieldHolder(
      "Case",
      "FEC_Interaction__c",
    )?.value;
    if (interactionRaw == null || interactionRaw === STR_EMPTY) {
      return false;
    }
    const cat = this._getCaseFieldDisplay("FEC_Category__c");
    const subCat = this._getCaseFieldDisplay("FEC_SubCategory__c");
    const subCode = this._getCaseFieldDisplay("FEC_SubCode__c");
    if (!cat) return false;
    const catOk =
      cat === INTERACTION_RC09_CATEGORY ||
      cat.toLowerCase() === INTERACTION_RC09_CATEGORY.toLowerCase();
    if (!catOk) return false;
    if (subCat !== INTERACTION_RC09_SUBCATEGORY) return false;
    return INTERACTION_RC09_SUBCODES.has(subCode);
  }

  /** @author Toannd61 */
  get displayTeam() {
    if (this._forcedBlockCodeFromForm()) {
      return TEAM_OM_DISPLAY;
    }
    if (this._forcedInteractionRc09FromForm()) {
      return TEAM_SP_DISPLAY;
    }
    return this.business?.nextTeam ?? STR_EMPTY;
  }

  /** @author Toannd61 */
  get displayQueue() {
    if (this._forcedBlockCodeFromForm()) {
      return this.business?.nextQueue?.label || QUEUE_DAY_2_FALLBACK_LABEL;
    }
    if (this._forcedInteractionRc09FromForm()) {
      return (
        this.business?.nextQueue?.label || QUEUE_DQ_CS_SUPPORT_FALLBACK_LABEL
      );
    }
    return this.business?.nextQueue?.label ?? STR_EMPTY;
  }
}
