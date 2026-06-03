import { LightningElement, track, api, wire } from "lwc";
import FEC_RECORDS_PER_PAGE_LABEL from "@salesforce/label/c.FEC_Record_per_Page";
import FEC_GO_TO_PAGE_LABEL from "@salesforce/label/c.FEC_Go_to_page_label";
import getCaseData from "@salesforce/apex/FEC_DNBHandler.getCaseData";
import createDNB from "@salesforce/apex/FEC_DNBHandler.createDNB";
import checkDNBExisting from "@salesforce/apex/FEC_DNBHandler.checkDNBExisting";
import createExistingDNBRows from "@salesforce/apex/FEC_DNBHandler.createExistingDNBRows";
import getListDNBs from "@salesforce/apex/FEC_DNBHandler.getListDNBs";
import updateFieldDoNotBother from "@salesforce/apex/FEC_DNBHandler.updateFieldDoNotBother";
import updateDNBProcessCount from "@salesforce/apex/FEC_DNBHandler.updateDNBProcessCount";

import FEC_DNB_Has_Data_Question from "@salesforce/label/c.FEC_DNB_Has_Data_Question";
import FEC_DNB_No_Data_Question from "@salesforce/label/c.FEC_DNB_No_Data_Question";

import FEC_DNB_National_Id from "@salesforce/label/c.LBL_NationalID";
import FEC_DNB_NID_Placeholder from "@salesforce/label/c.FEC_DNB_NID_Placeholder";
import FEC_DNB_NID_Error from "@salesforce/label/c.FEC_MSG_National_ID_Invalid";

import FEC_DNB_Update_Button from "@salesforce/label/c.FEC_DNB_Update_Button";

import FEC_DNB_Modal_Title from "@salesforce/label/c.FEC_DNB_Modal_Title";
import FEC_DNB_Modal_Message from "@salesforce/label/c.FEC_DNB_Modal_Message";
import FEC_Yes_Btn from "@salesforce/label/c.FEC_Yes_Btn";
import FEC_No_Btn from "@salesforce/label/c.FEC_No_Btn";
//HieuTT74 Cập nhật ngày  18-5-2026: Bổ sung message channel để disable các combobox khi call api tạo DNB
import DO_NOT_BOTHER_CHANNEL from "@salesforce/messageChannel/FEC_DoNotBother__c";
import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";

import { ShowToastEvent } from "lightning/platformShowToastEvent";
import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext,
  publish,
} from "lightning/messageService";
export default class Fec_DoNotBotherExistingCustomer extends LightningElement {
  labels = {
    pageSizeLabel: FEC_RECORDS_PER_PAGE_LABEL,
    goToPageLabel: FEC_GO_TO_PAGE_LABEL,
    yesBtn: FEC_Yes_Btn,
    noBtn: FEC_No_Btn,
    nationalIdLabel: FEC_DNB_National_Id,
    nationalIdPlaceholder: FEC_DNB_NID_Placeholder,
    nationalIdError: FEC_DNB_NID_Error,
    hasDataQuestion: FEC_DNB_Has_Data_Question,
    noDataQuestion: FEC_DNB_No_Data_Question,
    updateBtn: FEC_DNB_Update_Button,
    modalTitle: FEC_DNB_Modal_Title,
    modalMessage: FEC_DNB_Modal_Message,
  };

  @wire(MessageContext)
  messageContext;
  subscription = null;
  @api recordId;
  @track selectedOption = "no";
  @track initialHasDNBData = null;
  @track data = [];
  @track pagedData = [];
  isReadonlyMode = false;
  customerName = "";
  nationalId = "";
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
  modeEditCase = false;
  errorMessage = "";
  retryCount = 0;

  maxRetry = 3;

  isMaxRetryReached = false;
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

  @track resultData = [];

  showResultTable = false;

  async connectedCallback() {
    this.subscribeToMessageChannel();

    await this.loadData();

    await this.initializeDNBFlow();
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
      (message) => this.handleMessage(message),
      { scope: APPLICATION_SCOPE },
    );
  }

  handleMessage(message) {
    console.log(
      "Received message on IS_MODE_EDIT channel:",
      JSON.stringify(message),
    );
    if (!message || typeof message.isModeEdit === "undefined") return;

    if (message.caseId != null && message.caseId !== this.recordId) {
      return;
    }

    this.modeEditCase = message.isModeEdit;
  }

  async loadData() {
    try {
      const result = await getCaseData({
        caseId: this.recordId,
      });

      console.log("CASE DATA:", JSON.stringify(result));

      this.customerName = result.customerName;

      this.nationalId = result.nationalId;

      this.contractId = result.contractId;

      this.retryCount = result.processActionCount || 0;

      this.isMaxRetryReached = this.retryCount >= 3;
      this.modeEditCase = result.viewMode === "handling" ? true : false;
    } catch (e) {
      console.error("Load data error", e);
    }
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
      console.error("Load DNB records error", e);
    }
  }

  async checkDNB() {
    console.log("Checking DNB for NID:", this.nationalId);

    return await checkDNBExisting({
      caseId: this.recordId,
    });
  }

  async createDNBRows() {
    await createExistingDNBRows({
      caseId: this.recordId,
    });
  }

  async initializeDNBFlow() {
    try {
      /*
       * STEP 1:
       * CHECK API ONLY
       */
      const result = await this.checkDNB();

      console.log("EXISTING DNB RESULT:", JSON.stringify(result));

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
       * STEP 2:
       * CREATE DB ROWS
       */
      await this.createDNBRows();

      /*
       * STEP 3:
       * LOAD DB
       */
      await this.loadDNBRecords();

      /*
       * DEFAULT UI
       */
      this.hasDNBData = this.data.length > 0;
      this.initialHasDNBData = this.hasDNBData;

      // this.selectedOption = this.hasDNBData ? "yes" : "no";
    } catch (e) {
      console.error("initializeDNBFlow ERROR", e);

      this.showToast(
        "Error",
        e?.body?.message || e?.message || "Unexpected error",
        "error",
      );
    }
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

  get reasonLabelMap() {
    return {
      not_interested: "Not interested",

      receiving_too_many_calls_sms_emails:
        "Receiving too many calls/ SMS/ Emails,...",

      already_have_a_loan_from_another_company:
        "Already have a loan from another company",

      already_being_served_by_1_fec_employee:
        "Already being served by 1 FEC employee",

      other_reason: "Other reason",
    };
  }

  async loadResultTable() {
    try {
      const result = await getListDNBs({
        caseId: this.recordId,
      });

      console.log("RESULT TABLE:", JSON.stringify(result));

      this.resultData = this.prepareDBData(result);

      this.showResultTable = true;
    } catch (e) {
      console.error("Load result table error", e);
    }
  }

  getReasonLabel(value) {
    const option = this.getReasonOptions().find((item) => item.value === value);

    return option ? option.label : value;
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
    if (/^\d+$/.test(value)) {
      return value.slice(0, 4) + "***" + value.slice(-3);
    }

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

  get showTable() {
    return this.selectedOption === "yes";
  }

  get hasDataAtDNB() {
    if (this.initialHasDNBData !== null) {
      return this.initialHasDNBData;
    }

    return this.hasDNBData;
  }

  // ===== Core Pagination =====
  updatePagedData() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.pagedData = this.data.slice(start, end);
  }

  // ===== Events =====
  handleRadioChange(event) {
    this.selectedOption = event.detail.value;

    if (this.selectedOption === "yes") {
      this.currentPage = 1;
      this.updatePagedData();
    }
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

  handleTextareaChange(event) {
    const { id, field, value } = event.detail;

    this.data = this.data.map((row) =>
      row.id === id ? { ...row, [field]: value } : row,
    );

    this.refreshData();
  }

  refreshData() {
    this.data = [...this.data];
    this.updatePagedData();
  }

  // get isUpdateDisabled() {
  //   return (
  //     !this.data.some((row) => row.active) || // chưa tick gì
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

        /*
         * Convert UI values before readonly
         */
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

  buildPayload() {
    return this.data
      .filter((row) => row.active)
      .map((row) => ({
        dnb_id: row.id,
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

  normalizeCompareValue(value) {
    if (!value) {
      return "";
    }

    /*
     * EMAIL
     */
    if (value.includes("@")) {
      return value.trim().toLowerCase();
    }

    /*
     * PHONE
     */
    let cleaned = value.replace(/\D/g, "");

    /*
     * 0xxxxxxxxx -> 84xxxxxxxxx
     */
    if (cleaned.startsWith("0")) {
      cleaned = "84" + cleaned.substring(1);
    }

    return cleaned;
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
      /*
       * User selected NO
       */
      await updateFieldDoNotBother({
        caseId: this.recordId,

        selectedOption: "no",
      });
    } catch (e) {
      console.error("Update DNB flag error", e);
    }

    this.close();
  }
}
