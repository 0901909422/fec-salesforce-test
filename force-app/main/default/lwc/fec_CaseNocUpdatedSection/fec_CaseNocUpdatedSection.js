/**
 * fec_CaseNocUpdatedSection
 *
 * Child component hiển thị "Updated Information" section trong fec_CaseEditNOC.
 * Được render khi isSubmited = true và Case chưa có Auto-Routing Assignment.
 *
 * @api props nhận từ parent (fec_CaseEditNOC):
 *   - productTypeId    : String  — Product Type gốc (disabled, không cho sửa)
 *   - categoryId       : String  — Pre-populated Category ID
 *   - subCategoryId    : String  — Pre-populated Sub-Category ID
 *   - subCodeId        : String  — Pre-populated Sub-Code ID
 *   - isEditable       : Boolean — true khi modeEditCase=true hoặc VIEW_MODE_HANDLING
 *   - productTypeOptions, categoryOptions, subCategoryOptions, subCodeOptions : String (JSON)
 *
 * Events fire lên parent:
 *   - nocupdatedcategorychange    : { detail: { categoryId } }
 *   - nocupdatedsubcategorychange : { detail: { subCategoryId } }
 *   - nocupdatedsubcodechange     : { detail: { subCodeId, natureOfCaseId } }
 */
import { LightningElement, api, track } from "lwc";
import getNatureOfCase from "@salesforce/apex/FEC_CaseEditNOCController.getNatureOfCase";

export default class Fec_CaseNocUpdatedSection extends LightningElement {
  // ─── @api props từ parent ────────────────────────────────────────────────
  @api productTypeId;
  @api isEditable = false;
  @api productTypeName;
  @api categoryName;
  @api subCategoryName;
  @api subCodeName;

  // Options dưới dạng JSON string để tránh vấn đề reactivity khi truyền array qua @api
  @api productTypeOptions = "[]";
  @api categoryOptions = "[]";
  @api subCategoryOptions = "[]";
  @api subCodeOptions = "[]";

  // Pre-populated values — dùng setter để sync vào internal state khi parent truyền xuống
  _categoryId;
  _subCategoryId;
  _subCodeId;

  @api
  get categoryId() {
    return this._categoryId;
  }
  set categoryId(val) {
    this._categoryId = val;
  }

  @api
  get subCategoryId() {
    return this._subCategoryId;
  }
  set subCategoryId(val) {
    this._subCategoryId = val;
  }

  @api
  get subCodeId() {
    return this._subCodeId;
  }
  set subCodeId(val) {
    this._subCodeId = val;
  }

  // ─── Getters: disable logic ───────────────────────────────────────────────
  // Product Type luôn disabled (không cho sửa)
  get disableProductType() {
    return true;
  }

  // Category disabled khi không ở edit mode
  get disableCategory() {
    return !this.isEditable;
  }

  // Sub-Category disabled khi không ở edit mode hoặc chưa chọn Category
  get disableSubCategory() {
    return !this.isEditable || !this._categoryId;
  }

  // Sub-Code disabled khi không ở edit mode hoặc chưa chọn Sub-Category
  get disableSubCode() {
    return !this.isEditable || !this._subCategoryId;
  }

  // ─── Getters: parse JSON options ─────────────────────────────────────────
  _optionsWithDisplayName(optionsJson, value, displayName) {
    let list = [];
    try {
      list = JSON.parse(optionsJson || "[]");
    } catch (e) {
      list = [];
    }
    if (!value || !displayName || list.some((item) => item.value === value)) {
      return JSON.stringify(list);
    }
    return JSON.stringify([...list, { label: displayName, value, helpText: null }]);
  }

  get formattedProductTypeOption() {
    return this._optionsWithDisplayName(
      this.productTypeOptions,
      this.productTypeId,
      this.productTypeName
    );
  }

  get formattedCategoryOption() {
    return this._optionsWithDisplayName(
      this.categoryOptions,
      this._categoryId,
      this.categoryName
    );
  }

  get formattedSubCategoryOption() {
    return this._optionsWithDisplayName(
      this.subCategoryOptions,
      this._subCategoryId,
      this.subCategoryName
    );
  }

  get formattedSubCodeOption() {
    return this._optionsWithDisplayName(
      this.subCodeOptions,
      this._subCodeId,
      this.subCodeName
    );
  }

  // ─── Handlers: Category ──────────────────────────────────────────────────
  handleChangeCategory(e) {
    this._categoryId = e.detail.value;
    // Cascade reset: xóa Sub-Category và Sub-Code khi Category thay đổi
    this._subCategoryId = null;
    this._subCodeId = null;

    this.dispatchEvent(
      new CustomEvent("nocupdatedcategorychange", {
        detail: { categoryId: this._categoryId }
      })
    );
  }

  handleRemoveCategory() {
    this._categoryId = null;
    this._subCategoryId = null;
    this._subCodeId = null;

    this.dispatchEvent(
      new CustomEvent("nocupdatedcategorychange", {
        detail: { categoryId: null }
      })
    );
  }

  // ─── Handlers: Sub-Category ───────────────────────────────────────────────
  handleChangeSubCategory(e) {
    this._subCategoryId = e.detail.value;
    // Cascade reset: xóa Sub-Code khi Sub-Category thay đổi
    this._subCodeId = null;

    this.dispatchEvent(
      new CustomEvent("nocupdatedsubcategorychange", {
        detail: { subCategoryId: this._subCategoryId }
      })
    );
  }

  handleRemoveSubCategory() {
    this._subCategoryId = null;
    this._subCodeId = null;

    this.dispatchEvent(
      new CustomEvent("nocupdatedsubcategorychange", {
        detail: { subCategoryId: null }
      })
    );
  }

  // ─── Handlers: Sub-Code ───────────────────────────────────────────────────
  handleChangeSubCode(e) {
    this._subCodeId = e.detail.value;

    if (this._subCodeId) {
      // Gọi getNatureOfCase để lấy natureOfCaseId trước khi fire event lên parent
      getNatureOfCase({
        productTypeId: this.productTypeId,
        categoryId: this._categoryId,
        subCategoryId: this._subCategoryId,
        subCodeId: this._subCodeId
      })
        .then((result) => {
          this.dispatchEvent(
            new CustomEvent("nocupdatedsubcodechange", {
              detail: {
                subCodeId: this._subCodeId,
                natureOfCaseId: result?.Id ?? null
              }
            })
          );
        })
        .catch((error) => {
          console.error("fec_CaseNocUpdatedSection ~ getNatureOfCase ~ error:", error);
          // Vẫn fire event với natureOfCaseId = null để không block flow
          this.dispatchEvent(
            new CustomEvent("nocupdatedsubcodechange", {
              detail: {
                subCodeId: this._subCodeId,
                natureOfCaseId: null
              }
            })
          );
        });
    }
  }

  handleRemoveSubCode() {
    this._subCodeId = null;

    this.dispatchEvent(
      new CustomEvent("nocupdatedsubcodechange", {
        detail: { subCodeId: null, natureOfCaseId: null }
      })
    );
  }
}