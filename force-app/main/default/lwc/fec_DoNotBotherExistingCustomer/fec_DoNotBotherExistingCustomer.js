import { LightningElement, track, api } from "lwc";
import FEC_RECORDS_PER_PAGE_LABEL from "@salesforce/label/c.FEC_Record_per_Page";
import FEC_GO_TO_PAGE_LABEL from "@salesforce/label/c.FEC_Go_to_page_label";
import getCaseData from "@salesforce/apex/FEC_DNBHandler.getCaseData";
import createDNB from "@salesforce/apex/FEC_DNBHandler.createDNB";
import getDNB from "@salesforce/apex/FEC_DNBHandler.getDNBResult";
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

  @api recordId;
  @track selectedOption = "no";

  @track data = [];
  @track pagedData = [];

  customerName = "";
  nationalId = "";
  radioOptions = [
    { label: "Không", value: "no" },
    { label: "Có", value: "yes" },
  ];
  hasDNBData = false;
  dnbMap = new Map();
  isConfirmOpen = false;
  // ===== Pagination state =====
  pageSize = 10;
  currentPage = 1;
  goToPageValue;

  columns = [
    { label: "DNB Channel", fieldName: "channel", type: "text" },
    { label: "Type", fieldName: "type", type: "text" },
    { label: "Phone/Email", fieldName: "contact", type: "contact" },
    { label: "Current Status", fieldName: "status", type: "text" },

    {
      label: "Action",
      fieldName: "active",
      type: "checkbox",
      checkboxLabel: this.hasDNBData ? "Extend" : "Active",
    },
    { label: "Expiry Date", fieldName: "expiry", type: "text" },
    { label: "Original Reason", fieldName: "originalReason", type: "text" },
    { label: "Update Reason", fieldName: "updateReason", type: "picklist" },
    {
      label: "Remarks",
      fieldName: "remarks",
      type: "textarea",
    },
  ];

  async connectedCallback() {
    await this.getDnb();
    await this.loadData();
  }

  async getDnb() {
    try {
      const res = await getDNB({ caseId: this.recordId });
      const parsed = JSON.parse(res);
      const list = parsed.result || [];

      this.hasDNBData = list.length > 0;

      this.dnbMap = new Map();

      list.forEach((item) => {
        const key = `${item.type}_${item.type_value}`;
        this.dnbMap.set(key, item);
      });

      console.log("DNB MAP:", this.dnbMap);
    } catch (e) {
      console.error("Get DNB error", e);
    }
  }

  async loadData() {
    try {
      const result = await getCaseData({ caseId: this.recordId });

      this.customerName = result.customerName;
      this.nationalId = result.nationalId;

      const rows = this.buildDNBData(result);
      this.data = this.prepareData(rows);
      this.updatePagedData();
    } catch (e) {
      console.error("Load data error", e);
    }
  }

  buildDNBData(res) {
    const channel = res.channel?.toLowerCase();
    const isCall = ["inbound", "outbound"].includes(channel);

    const createRow = ({
      id,
      channel,
      type,
      contact,
      maskedContact,
      disableAction = false,
    }) => {
      const hasContact = !!contact;

      const typeKey = this.mapType(channel);
      const key = `${typeKey}_${contact}`;

      const dnb = this.dnbMap.get(key);

      const hasExpiry = !!dnb?.expiry;

      return {
        id,
        channel,
        type,

        contact: contact || "",
        maskedContact: maskedContact || "",
        isHidden: true,

        // ===== CORE LOGIC =====
        status: hasExpiry ? "Active" : "Inactive",
        expiry: dnb?.expiry || "",

        active: false,

        originalReason: dnb?.reason || "",
        updateReason: "",

        isReasonDisabled: true,

        isActionDisabled: disableAction || !hasContact,
        hasContact,

        reasonOptionsFormatted: this.getReasonOptions(),
        remarks: ""
      };
    };

    return [
      createRow({
        id: "primary-phone-call",
        channel: "Call",
        type: "Primary Phone",
        contact: res.primaryPhoneNumber,
        maskedContact: this.maskContact(res.primaryPhoneNumber),
      }),
      createRow({
        id: "primary-phone-sms",
        channel: "SMS",
        type: "Primary Phone",
        contact: res.primaryPhoneNumber,
        maskedContact: this.maskContact(res.primaryPhoneNumber),
      }),
      createRow({
        id: "interaction-phone-call",
        channel: "Call",
        type: "Interaction Phone",
        contact: res.interactionPhoneNumber,
        maskedContact: res.interactionMaskedPhone,
      }),
      createRow({
        id: "interaction-phone-sms",
        channel: "SMS",
        type: "Interaction Phone",
        contact: res.interactionPhoneNumber,
        maskedContact: res.interactionMaskedPhone,
      }),
      createRow({
        id: "interaction-email",
        channel: "Email",
        type: "Interaction Email",
        contact: isCall ? "" : res.interactionEmail,
        maskedContact: res.interactionMaskedEmail,
        disableAction: isCall,
      }),
    ];
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

  prepareData(data) {
    return data.map((row) => ({
      ...row,
      isReasonDisabled: !row.active,
      maskedContact: row.maskedContact || this.maskContact(row.contact),
    }));
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

  get isUpdateDisabled() {
    return (
      !this.data.some((row) => row.active) || // chưa tick gì
      this.data.some((row) => row.active && !row.updateReason)
    );
  }

  async handleUpdate() {
    if (this.isUpdateDisabled) return;

    const payload = this.buildPayload();

    console.log("FINAL PAYLOAD:", JSON.stringify(payload));

    try {
      await createDNB({ payload: payload }); // Apex call
    } catch (e) {
      console.error(e);
    }
  }

  buildPayload() {
    return this.data
      .filter((row) => row.active)
      .map((row) => ({
        reason: row.updateReason,
        full_name: this.customerName || "UNKNOWN",
        nid: this.nationalId || "000000000000",
        do_not_bother: true,
        type: this.mapType(row.channel),
        type_value: row.contact,
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

  handleCloseModal() {
    this.close();
  }
}
