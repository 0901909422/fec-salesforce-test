import { LightningElement, track, api, wire } from "lwc";
import getCaseData from "@salesforce/apex/FEC_DNBHandler.getCaseNonExistingData";
import createDNB from "@salesforce/apex/FEC_DNBHandler.createDNB";

import FEC_DNB_Has_Data_Question from "@salesforce/label/c.FEC_DNB_Has_Data_Question";
import FEC_DNB_No_Data_Question from "@salesforce/label/c.FEC_DNB_No_Data_Question";

import FEC_DNB_National_Id from "@salesforce/label/c.LBL_NationalID";
import FEC_DNB_NID_Placeholder from "@salesforce/label/c.FEC_DNB_NID_Placeholder";
import FEC_DNB_NID_Error from "@salesforce/label/c.FEC_MSG_National_ID_Invalid";

import FEC_DNB_Update_Button from "@salesforce/label/c.FEC_DNB_Update_Button";
import checkDNBNonExisting from "@salesforce/apex/FEC_DNBHandler.checkDNBNonExisting";

import createNonExistingDNBRows from "@salesforce/apex/FEC_DNBHandler.createNonExistingDNBRows";
import FEC_DNB_Modal_Title from "@salesforce/label/c.FEC_DNB_Modal_Title";
import FEC_DNB_Modal_Message from "@salesforce/label/c.FEC_DNB_Modal_Message";
import FEC_RECORDS_PER_PAGE_LABEL from "@salesforce/label/c.FEC_Record_per_Page";
import FEC_GO_TO_PAGE_LABEL from "@salesforce/label/c.FEC_Go_to_page_label";
import FEC_Yes_Btn from "@salesforce/label/c.FEC_Yes_Btn";
import FEC_No_Btn from "@salesforce/label/c.FEC_No_Btn";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import getListDNBs from "@salesforce/apex/FEC_DNBHandler.getListDNBs";

import updateFieldDoNotBother from "@salesforce/apex/FEC_DNBHandler.updateFieldDoNotBother";

import updateDNBProcessCount from "@salesforce/apex/FEC_DNBHandler.updateDNBProcessCount";

import DO_NOT_BOTHER_CHANNEL from "@salesforce/messageChannel/FEC_DoNotBother__c";

import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";

import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext,
  publish,
} from "lightning/messageService";

//FECREDIT_CSM_2025_KH-1561
const STR_EMPTY = "";

export default class Fec_DoNotBotherNonExistingCustomer extends LightningElement {
  @wire(MessageContext)
  messageContext;

  subscription = null;

  isReadonlyMode = false;

  modeEditCase = false;

  errorMessage = "";

  retryCount = 0;

  maxRetry = 3;

  isMaxRetryReached = false;
  @track initialHasDNBData = null;
  labels = {
    pageSizeLabel: FEC_RECORDS_PER_PAGE_LABEL,
    goToPageLabel: FEC_GO_TO_PAGE_LABEL,
    hasDataQuestion: FEC_DNB_Has_Data_Question,
    noDataQuestion: FEC_DNB_No_Data_Question,
    updateBtn: FEC_DNB_Update_Button,
    modalTitle: FEC_DNB_Modal_Title,
    modalMessage: FEC_DNB_Modal_Message,
    yesBtn: FEC_Yes_Btn,
    noBtn: FEC_No_Btn,
    nationalIdLabel: FEC_DNB_National_Id,
    nationalIdPlaceholder: FEC_DNB_NID_Placeholder,
    nationalIdError: FEC_DNB_NID_Error,
  };

  @api recordId;
  @track selectedOption = "no";

  @track data = [];
  @track pagedData = [];

  customerName = "";
  nationalId = "";
  phoneNumber = "";
  contractId = "";
  radioOptions = [
    { label: "Không", value: "no" },
    { label: "Có", value: "yes" },
  ];
  hasDNBData = false;
  isConfirmOpen = false;
  // ===== Pagination state =====
  pageSize = 10;
  currentPage = 1;
  goToPageValue;
  isDNBUpdated = false;

  @track isCheckingDNB = false;
  @track isDNBChecked = false;
  @track hasExistingDNB = false;

  get columns() {
    return [
      {
        label: "DNB Channel",
        fieldName: "channel",
        type: "text",
      },

      {
        label: "Type",
        fieldName: "type",
        type: "text",
      },

      {
        label: "Phone/Email",
        fieldName: "contact",
        type: "contact",
      },

      {
        label: "Current Status",
        fieldName: "status",
        type: "text",
      },

      {
        label: "Action",
        fieldName: "active",
        type: "checkbox",
        checkboxLabelField: "checkboxLabel",
      },

      {
        label: "Expiry Date",
        fieldName: "expiry",
        type: "text",
      },

      {
        label: "Original Reason",
        fieldName: "originalReasonLabel",
        type: "text",
      },

      {
        label: "Update Reason",

        fieldName: this.isReadonlyMode ? "updateReasonLabel" : "updateReason",

        type: this.isReadonlyMode ? "text" : "picklist",

        headerClass: "update-reason-header",
      },

      {
        label: "Remarks",

        fieldName: "remarks",

        type: this.isReadonlyMode ? "text" : "textarea",

        disabledField: "isReadonly",

        headerClass: "remarks-header",
      },
    ];
  }

  async connectedCallback() {
    this.subscribeToMessageChannel();

    await this.loadData();

    // await this.loadDNBRecords();
  }

  disconnectedCallback() {
    unsubscribe(this.subscription);
    this.subscription = null;

    this.modeEditCase = false;
  }

  subscribeToMessageChannel() {
    this.subscription = subscribe(
      this.messageContext,
      IS_MODE_EDIT,
      (message) => this.handleModeEditMessage(message),
      { scope: APPLICATION_SCOPE },
    );
  }

  handleModeEditMessage(message) {
    if (!message || typeof message.isModeEdit === "undefined") return;

    if (message.caseId != null && message.caseId !== this.recordId) {
      return;
    }

    this.modeEditCase = message.isModeEdit;
  }

  async loadData() {
    try {
      const result = await getCaseData({ caseId: this.recordId });

      this.customerName = result.customerName;
      this.nationalId = result.nationalId;
      this.phoneNumber = result.phoneNumber;
      this.contractId = result.contractId;
      this.retryCount = result.processActionCount || 0;

      this.isMaxRetryReached = this.retryCount >= 3;
      this.modeEditCase = result.viewMode === "handling" ? true : false;
      // this.data = this.prepareData(rows);
      this.updatePagedData();
    } catch (e) {
      console.error("Load data error", e);
    }
  }

  getReasonLabel(value) {
    const option = this.getReasonOptions().find((x) => x.value === value);

    return option ? option.label : value || "";
  }

  getReasonOptions() {
    return [
      { label: "Not interested", value: "not_interested" },
      {
        label: "Receiving too many calls/ SMS/ Emails,...",
        value: "receiving_too_many_calls_sms_emails",
      },
      {
        label: "Already have a loan from another company",
        value: "already_have_a_loan_from_another_company",
      },
      {
        label: "Already being served by 1 FEC employee",
        value: "already_being_served_by_1_fec_employee",
      },
      { label: "Other reason", value: "other_reason" },
    ];
  }

  async loadDNBRecords() {
    try {
      const result = await getListDNBs({
        caseId: this.recordId,
      });

      console.log("DNB DB RECORDS:", JSON.stringify(result));

      this.hasDNBData = result?.length > 0;

      this.data = this.prepareDBData(result);

      this.updatePagedData();
    } catch (e) {
      console.error("Load DNB records error", JSON.stringify(e));
    }
  }

  async checkDNB() {
    const draftStorageKey = `fec_case_business_draft_${this.recordId}`;

    const draft = JSON.parse(localStorage.getItem(draftStorageKey)) || {};

    // tìm field phone trong draft
    const phoneKey = Object.keys(draft).find(
      (k) =>
        k.toLowerCase().includes("phone") || k.toLowerCase().includes("mobile"),
    );

    const phoneNumber = phoneKey ? draft[phoneKey] : this.phoneNumber;

    console.log("Checking DNB for NID:", this.nationalId);
    console.log("Checking DNB for Phone:", phoneNumber);

    return await checkDNBNonExisting({
      caseId: this.recordId,
      nid: this.nationalId,
      phoneNumber: phoneNumber,
    });
  }

  async handleCheckDNB() {
    /*
     * Validate NID first
     */
    if (!this._validateNationalId()) {
      return;
    }

    this.isCheckingDNB = true;

    try {
      const result = await this.checkDNB();

      console.log("DNB RESULT:", JSON.stringify(result));

      this.isDNBChecked = true;

      /*
       * API FAIL
       */
      if (!result?.success) {
        this.showToast(
          "Error",
          result?.errorMessage || "Check DNB failed",
          "error",
        );
        return;
      }

      /*
       * NO DATA FOUND
       */
      const hasData = Array.isArray(result?.result) && result.result.length > 0;

      this.hasExistingDNB = hasData;
      this.hasDNBData = hasData;

      if (this.initialHasDNBData === null) {
        this.initialHasDNBData = hasData;
      }
      /*
       * clear table
       */
      this.data = [];
      this.currentPage = 1;
      this.updatePagedData();

      if (!hasData) {
        return;
      }
    } catch (e) {
      console.error("handleCheckDNB ERROR", e);

      this.showToast(
        "Error",
        e?.body?.message || e?.message || "Unexpected error",
        "error",
      );
    } finally {
      this.isCheckingDNB = false;
    }
  }

  prepareDBData(records) {
    return (records || []).map((row) => {
      const isReadonly = !!row.updatedReason;

      return {
        id: row.id,

        channel: row.channel,

        type: row.type,

        contact: row.typeValue || "",

        maskedContact:
          row.typeValue && row.typeValue.includes("*")
            ? row.typeValue
            : this.maskContact(row.typeValue),

        isHidden: true,

        status: row.doNotBother || "Inactive",

        checkboxLabel:
          row.doNotBother === "Extend Expiry Date" ||
          row.doNotBother === "Active"
            ? "Extend Expiry Date"
            : "Active",

        expiry: row.expectedExcludeTime || "",

        active: row.action || false,

        originalReason: row.reason2 || "",

        originalReasonLabel: this.getReasonLabel(row.reason2),

        updateReason: row.updatedReason || "",

        updateReasonLabel: this.getReasonLabel(row.updatedReason),

        remarks: row.remarks || "",

        /*
         * READONLY
         */
        isReadonly,

        isReasonDisabled: !row.action || isReadonly,

        isActionDisabled:
          (!!row.typeValue && row.type === "Insert from DB") ||
          !row.typeValue ||
          isReadonly,

        hasContact: !!row.typeValue,

        reasonOptionsFormatted: this.getReasonOptions(),
      };
    });
  }
  maskContact(value) {
    if (!value) return "";

    // phone
    if (/^\d+$/.test(value)) {
      return value.slice(0, 4) + "***" + value.slice(-3);
    }

    // email
    if (value.includes("@")) {
      const [name, domain] = value.split("@");
      return name.slice(0, 2) + "***@" + domain;
    }

    return value;
  }

  // ===== Computed =====
  get totalRecords() {
    return this.data.length;
  }

  get totalPages() {
    return Math.max(1, Math.ceil(this.totalRecords / this.pageSize));
  }

  get isFirstPage() {
    return this.currentPage === 1;
  }

  get isLastPage() {
    return this.currentPage >= this.totalPages;
  }

  get pageSizeOptions() {
    return [10, 20, 30, 40, 50].map((size) => ({
      label: size.toString(),
      value: size,
    }));
  }

  get showTableSection() {
    return this.isDNBChecked && this.selectedOption === "yes";
  }

  get hasDataAtDNB() {
    if (this.initialHasDNBData !== null) {
      return this.initialHasDNBData;
    }

    return this.hasDNBData;
  }

  get formElementClass() {
    return `slds-form-element slds-form-element_stacked slds-m-top_medium  slds-grid slds-gutters slds-align-center ${
      this.nidError ? "slds-has-error" : ""
    }`;
  }
  // ===== Core Pagination =====
  updatePagedData() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.pagedData = this.data.slice(start, end);
  }

  handleTextareaChange(event) {
    const { id, field, value } = event.detail;

    this.data = this.data.map((row) =>
      row.id === id ? { ...row, [field]: value } : row,
    );

    this.refreshData();
  }
  // ===== Events =====
  // handleRadioChange(event) {
  //   this.selectedOption = event.detail.value;

  //   /*
  //    * Nếu chọn YES mà chưa có data
  //    * thì load default table
  //    */
  //   if (
  //     this.selectedOption === "yes" &&
  //     !this.hasExistingDNB &&
  //     this.data.length === 0
  //   ) {
  //     this.loadDNBRecords();
  //   }

  //   this.currentPage = 1;
  //   this.updatePagedData();
  // }

  async handleRadioChange(event) {
    this.selectedOption = event.detail.value;

    /*
     * USER CONFIRM YES
     */
    if (this.selectedOption === "yes" && this.data.length === 0) {
      try {
        /*
         * CREATE DB ROWS
         */
        await createNonExistingDNBRows({
          caseId: this.recordId,

          nid: this.nationalId,
        });

        /*
         * LOAD DB
         */
        await this.loadDNBRecords();
      } catch (e) {
        console.error("create rows error", e);

        this.showToast("Error", e?.body?.message || e?.message, "error");
      }
    }

    this.currentPage = 1;

    this.updatePagedData();
  }

  handleNextPage() {
    if (!this.isLastPage) {
      this.currentPage++;
      this.updatePagedData();
    }
  }

  handlePrevPage() {
    if (!this.isFirstPage) {
      this.currentPage--;
      this.updatePagedData();
    }
  }

  handlePageSizeChange(event) {
    this.pageSize = Number(event.detail.value);
    this.currentPage = 1;
    this.updatePagedData();
  }

  handleGoToPageInput(event) {
    this.goToPageValue = Number(event.target.value);
  }

  handleGoToPage() {
    if (
      this.goToPageValue &&
      this.goToPageValue >= 1 &&
      this.goToPageValue <= this.totalPages
    ) {
      this.currentPage = this.goToPageValue;
      this.updatePagedData();
    }
  }

  //------------------------- CUSTOM TABLE EVENTS -------------------
  handleCheckboxChange(event) {
    const { id, field, value } = event.detail;

    this.data = this.data.map((row) => {
      if (row.id !== id) return row;

      if (row.isActionDisabled) return row;

      const isExtend = row.status === "Active";

      return {
        ...row,
        [field]: value,

        isReasonDisabled: !value,

        // reset reason khi tick
        updateReason: value ? "" : "",

        // optional: flag để dùng sau
        isExtend,
      };
    });

    this.refreshData();
  }

  handlePicklistChange(event) {
    const { id, field, value } = event.detail;

    this.data = this.data.map((row) =>
      row.id === id ? { ...row, [field]: value } : row,
    );

    this.refreshData();
  }

  handleToggleContact(event) {
    const { id } = event.detail;

    this.data = this.data.map((row) =>
      row.id === id ? { ...row, isHidden: !row.isHidden } : row,
    );

    this.refreshData();
  }

  refreshData() {
    this.data = [...this.data];
    this.updatePagedData();
  }

  get isValidNationalId() {
    return (
      this.nationalId &&
      /^\d+$/.test(this.nationalId) &&
      (this.nationalId.length === 9 || this.nationalId.length === 12)
    );
  }

  // get isUpdateDisabled() {
  //   return (
  //     !this.isValidNationalId ||
  //     !this.data.some((row) => row.active) ||
  //     this.data.some((row) => row.active && !row.updateReason)
  //   );
  // }

  get isUpdateDisabled() {
    return (
      !this.data.some((row) => row.active) ||
      this.data.some(
        (row) =>
          row.active &&
          (!row.updateReason || !row.remarks || !row.remarks.trim()),
      )
    );
  }

  async handleUpdate() {
    if (this.isUpdateDisabled) {
      return;
    }

    try {
      /*
       * User selected YES
       */
      await updateFieldDoNotBother({
        caseId: this.recordId,

        selectedOption: "yes",
      });

      this.syncUIValuesBeforeReadonly();
      const payload = this.buildPayload();

      console.log("FINAL PAYLOAD:", JSON.stringify(payload));

      const result = await createDNB({
        payload: JSON.stringify(payload),
        caseId: this.recordId,
      });

      console.log("DNB RESULT =", result);

      /*
       * SUCCESS
       */
      if (Number(result?.code) === 0) {
        /*
         * Reset retry count
         */
        await updateDNBProcessCount({
          caseId: this.recordId,
          isSuccess: true,
        });

        this.syncUIValuesBeforeReadonly();

        this.isDNBUpdated = true;

        this.isReadonlyMode = true;

        this.applyReadonlyState();

        this.publishReadonlyMessage();

        this.showToast("Success", "DNB created successfully", "success");
      } else {
        /*
         * BUSINESS ERROR
         */
        let errorMessage = result?.sys?.message || "Unknown error";

        const invalidFields = (result?.result || [])
          .flatMap((item) => item?.list_invalid || [])
          .filter(Boolean)
          .join(", ");

        if (invalidFields) {
          errorMessage += ` (${invalidFields})`;
        }

        this.showToast("Failed", errorMessage, "error", "sticky");

        /*
         * Persist retry count
         */
        const retryCount = await updateDNBProcessCount({
          caseId: this.recordId,

          isSuccess: false,
        });

        this.retryCount = retryCount;
        if (retryCount < 3) {
          this.errorMessage =
            "Cập nhật thông tin khách hàng vào danh sách DNB thất bại. Vui lòng thử lại";
        } else {
          this.errorMessage =
            "Cập nhật thông tin khách hàng vào danh sách DNB thất bại.";
        }
        this.isMaxRetryReached = retryCount >= 3;
      }
    } catch (e) {
      console.error("createDNB ERROR =", e);
      const retryCount = await updateDNBProcessCount({
        caseId: this.recordId,

        isSuccess: false,
      });

      this.retryCount = retryCount;
      if (retryCount < 3) {
        this.errorMessage =
          "Cập nhật thông tin khách hàng vào danh sách DNB thất bại. Vui lòng thử lại";
      } else {
        this.errorMessage =
          "Cập nhật thông tin khách hàng vào danh sách DNB thất bại.";
      }
      this.isMaxRetryReached = retryCount >= 3;
      this.showToast(
        "System Error",
        e?.body?.message || e?.message || "Unexpected error",
        "error",
        "sticky",
      );
    }

    /*
     * Always close modal
     */

    this.close();
  }

  // handleNidChange(event) {
  //   const value = event.target.value || "";

  //   this.nationalId = value.replace(/\D/g, "");

  //   /*
  //    * reset state
  //    */
  //   this.isDNBChecked = false;
  //   this.hasExistingDNB = false;
  //   this.data = [];
  // }

  handleNidChange(event) {
    const value = event.target.value || "";

    /*
     * Only allow digits
     */
    this.nationalId = value.replace(/\D/g, "");

    /*
     * Apply validation
     */
    this._applyNationalIdValidity(false);

    /*
     * Reset state
     */
    this.isDNBChecked = false;

    this.hasExistingDNB = false;

    this.data = [];
  }

  buildPayload() {
    return this.data
      .filter((row) => row.active)
      .map((row) => ({
        dnb_id: row.id || null,
        channel: row.channel,
        reason: row.updateReason,
        remarks: row.remarks,
        full_name: this.customerName || "UNKNOWN",
        nid: this.nationalId || "000000000000",
        do_not_bother: true,
        type: this.mapType(row.channel),
        type_value:
          row.channel === "Email"
            ? row.contact
            : this.normalizePhone(row.contact),
        contract_id: this.contractId || "UNKNOWN",
      }));
  }
  mapType(channel) {
    switch (channel) {
      case "Call":
        return "PHONE";
      case "SMS":
        return "SMS";
      case "Email":
        return "EMAIL";
      default:
        return "PHONE";
    }
  }

  normalizePhone(phone) {
    if (!phone) {
      return "";
    }

    /*
     * Remove spaces/dots
     */
    let cleaned = phone.replace(/\D/g, "");

    /*
     * 0xxxxxxxxx -> 84xxxxxxxxx
     */
    if (cleaned.startsWith("0")) {
      cleaned = "84" + cleaned.substring(1);
    }

    return cleaned;
  }

  // handleNidChange(event) {
  //   const value = event.target.value;

  //   // chỉ cho nhập số
  //   const cleaned = value.replace(/\D/g, "");

  //   this.nationalId = cleaned;

  //   // validate: phải là 9 hoặc 12 số
  //   this.nidError = !(cleaned.length === 9 || cleaned.length === 12);
  // }

  applyReadonlyState() {
    this.data = this.data.map((row) => ({
      ...row,

      isReadonly: true,

      isReasonDisabled: true,

      isActionDisabled: true,
    }));

    this.updatePagedData();
  }

  publishReadonlyMessage() {
    publish(
      this.messageContext,

      DO_NOT_BOTHER_CHANNEL,

      {
        status: "SUCCESS",

        caseId: this.recordId,

        message: "DNB updated successfully",
      },
    );
  }

  // syncUIValuesBeforeReadonly() {
  //   this.data = this.data.map((row) => {
  //     /*
  //      * Only submitted rows
  //      */
  //     if (!row.active) {
  //       return row;
  //     }

  //     return {
  //       ...row,

  //       /*
  //        * Persist current UI values
  //        */
  //       originalReasonLabel: this.getReasonLabel(row.originalReason),

  //       updateReasonLabel: this.getReasonLabel(row.updateReason),

  //       remarks: row.remarks || "-",
  //     };
  //   });

  //   this.updatePagedData();
  // }

  syncUIValuesBeforeReadonly() {
    this.data = this.data.map((row) => ({
      ...row,

      originalReasonLabel: this.getReasonLabel(row.originalReason),

      updateReasonLabel: row.updateReason
        ? this.getReasonLabel(row.updateReason)
        : "",

      remarks: row.remarks || "",
    }));

    this.refreshData();
  }

  showToast(title, message, variant, mode = "dismissable") {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant,
        mode,
      }),
    );
  }
  //------------------------- MODAL EVENTS ----------------
  get isOpen() {
    return this.isConfirmOpen;
  }

  openModal() {
    this.isConfirmOpen = true;
  }

  close() {
    this.isConfirmOpen = false;
  }

  async handleCloseModal() {
    try {
      await updateFieldDoNotBother({
        caseId: this.recordId,

        selectedOption: "no",
      });
    } catch (e) {
      console.error("Update DNB flag error", e);
    }

    this.close();
  }

  get isHandlingMode() {
    return this.modeEditCase === true;
  }

  get showResultSection() {
    /*
     * REVIEW MODE
     */
    if (!this.isHandlingMode) {
      return true;
    }

    // /*
    //  * HANDLING MODE
    //  */
    // return this.isReadonlyMode;
  }

  get showUpdateButton() {
    return (
      !this.isReadonlyMode && !this.isDNBUpdated && !this.isMaxRetryReached
    );
  }

  get isActionLocked() {
    return this.isReadonlyMode || this.isDNBUpdated || this.isMaxRetryReached;
  }

  get isUpdateButtonDisabled() {
    return this.isUpdateDisabled || this.isActionLocked;
  }

  get isCheckDNBDisabled() {
    return this.isCheckingDNB;
  }

  //FECREDIT_CSM_2025_KH-1561
  _getNationalIdInputEl() {
    return (
      this.template.querySelector("[data-national-id-dnb]") ||
      this.template.querySelector('lightning-input[name="nationalId"]')
    );
  }

  //FECREDIT_CSM_2025_KH-1561
  _syncNationalIdFromInput() {
    const nidInput = this._getNationalIdInputEl();
    if (!nidInput) {
      return;
    }

    const fromInput =
      nidInput.value != null ? String(nidInput.value).trim() : STR_EMPTY;

    this.nationalId = fromInput;
  }

  //FECREDIT_CSM_2025_KH-1561
  _getNationalIdValidationError(nidValue) {
    const nid = (
      nidValue != null ? String(nidValue) : this.nationalId || STR_EMPTY
    ).trim();

    /*
     * Empty handled by required
     */
    if (!nid) {
      return null;
    }

    /*
     * Only digits
     */
    if (!/^\d+$/.test(nid)) {
      return "National ID không hợp lệ";
    }

    /*
     * Only 9 or 12 digits
     */
    if (nid.length !== 9 && nid.length !== 12) {
      return "National ID không hợp lệ";
    }

    return null;
  }

  //FECREDIT_CSM_2025_KH-1561
  _applyNationalIdValidity(reportNow) {
    const nidInput = this._getNationalIdInputEl();
    if (!nidInput) {
      return;
    }
    const nid = (this.nationalId || STR_EMPTY).trim();
    if (!nid) {
      nidInput.setCustomValidity("Vui lòng nhập National ID");
    } else {
      const err = this._getNationalIdValidationError(this.nationalId);
      nidInput.setCustomValidity(err || "");
    }
    if (reportNow) {
      nidInput.reportValidity();
    }
  }

  //FECREDIT_CSM_2025_KH-1561
  _validateNationalId() {
    this._syncNationalIdFromInput();
    this._applyNationalIdValidity(true);

    const nid = (this.nationalId || STR_EMPTY).trim();
    if (!nid) {
      return false;
    }

    const err = this._getNationalIdValidationError(this.nationalId);
    return !err;
  }

  //FECREDIT_CSM_2025_KH-1561
  @api
  validateForSubmit() {
    if (!this.isHandlingMode) {
      return true;
    }

    if (!this._getNationalIdInputEl()) {
      return false;
    }

    return this._validateNationalId();
  }
}
