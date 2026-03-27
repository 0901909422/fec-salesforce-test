import { LightningElement, api, wire, track } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import getInteractionAccountNumber from "@salesforce/apex/FEC_AccountOrContractPicklistHandler.getInteractionAccountNumber";
import getProductsListByCif from "@salesforce/apex/FEC_AccountOrContractPicklistHandler.getProductsListByCif";
import {
  UBANK_PRODUCT_NAME,
  NON_EXISTING_CUSTOMER_PRODUCT_NAME,
  NON_EXISTING_CUSTOMER_TYPE,
} from "c/fec_CommonConst";
import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext,
} from "lightning/messageService";
import createHistory from "@salesforce/apex/FEC_AccountOrContractPicklistHandler.createHistory";
import createHistoryNonExistingCustomer from "@salesforce/apex/FEC_AccountOrContractPicklistHandler.createHistoryNonExistingCustomer";
import getInteractionCustomerType from "@salesforce/apex/FEC_AccountOrContractPicklistHandler.getInteractionCustomerType";
import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";
import FEC_ACCOUNT_CONTRACT_NUMBER_LABEL from "@salesforce/label/c.FEC_Account_Contract_Number_Label";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import getInteractionIdFromCustomerCase from "@salesforce/apex/FEC_AccountOrContractPicklistHandler.getInteractionIdFromCustomerCase";
import CASE_ID from "@salesforce/schema/Case.Id";
export default class AccountOrContractPicklistCustomerCase extends LightningElement {
  labels = {
    accountContractNumber: FEC_ACCOUNT_CONTRACT_NUMBER_LABEL,
  };

  @api recordId;
  selectedValue = "";
  cifNumber = "";
  hasAccountOrContact = false;
  isOpen = false;
  selectedRows = [];
  isEditMode = false;
  recordTypeId;
  recordTypeDevName;
  subscription = null;
  interactionCustomerType;
  interactionId;
  @wire(MessageContext)
  messageContext;

  columns = [
    {
      label: "",
      type: "radioCell",
      fixedWidth: 48,
      typeAttributes: {
        rowId: { fieldName: "id" },
        selected: { fieldName: "isSelected" },
      },
    },
    { label: "Product", fieldName: "product" },
    {
      label: FEC_ACCOUNT_CONTRACT_NUMBER_LABEL,
      fieldName: "displayValue",
    },
    { label: "Product Name", fieldName: "productName" },
  ];
  data = [];

  /* =======================
   * LMS SUBSCRIPTION
   * ======================= */

  connectedCallback() {
    this.subscribeToModeChannel();
  }

  subscribeToModeChannel() {
    if (this.subscription) return;

    this.subscription = subscribe(
      this.messageContext,
      IS_MODE_EDIT,
      (message) => this.handleModeMessage(message),
      { scope: APPLICATION_SCOPE },
    );
  }

  handleModeMessage(message) {
    console.log("[LMS] Mode received:", message);

    if (message?.isModeEdit !== undefined) {
      this.isEditMode = message.isModeEdit;

      console.log("[LMS] isEditMode:", this.isEditMode);
    }
  }

  disconnectedCallback() {
    if (this.subscription) {
      unsubscribe(this.subscription);
      this.subscription = null;
    }
  }

  /* =======================
   * WIRE
   * ======================= */
  @wire(getRecord, {
    recordId: "$recordId",
    fields: [CASE_ID],
  })
  wiredCase({ data, error }) {
     console.log('có data không');
    console.log(data ? true : false);
    if (data) {
      this.initData(); // chỉ gọi 1 entry point
    }

    if (error) {
      console.error("[WIRE] Error loading Case", error);
    }
  }

  async initData() {
    try {
      console.log("Test");
      console.log(this.recordId);
      this.interactionId = await getInteractionIdFromCustomerCase({
        caseId: this.recordId,
      });

      // 1. lấy customer type
      this.interactionCustomerType = await getInteractionCustomerType({
        caseId: this.interactionId,
      });

      // 2. load account data
      await this.loadAccountData();
    } catch (e) {
      console.error("initData error:", e);
    }
  }

  async loadAccountData() {
    try {
      const result = await getInteractionAccountNumber({
        caseId: this.interactionId,
      });

      const data = result ? JSON.parse(result) : {};

      console.log("DATA:", data);

      this.selectedValue = data.accountNumber || "";
      this.cifNumber = data.cifNumber;
      this.hasAccountOrContact = data.hasContractAccount;

      if (this.isNonExistingCustomer) {
        this.initAccountDataNonExisting();
      } else {
        await this.getProductsList();
      }
    } catch (error) {
      console.error("loadAccountData error:", error);
    }
  }

  async getProductsList() {
    if (!this.cifNumber) {
      console.warn("Missing CIF → skip getProductsList");
      return;
    }

    try {
      const result = await getProductsListByCif({
        cifNumber: this.cifNumber,
      });

      const mappedData = result.map((item, index) => ({
        id: String(index + 1),
        product: item.productType,
        accountContractNumber: item.accountContractNumber,
        displayValue: item.accountContractNumber,
        productName: item.productName,
        isSelected: item.accountContractNumber === this.selectedValue,
      }));

      mappedData.push({
        id: String(mappedData.length + 1),
        product: UBANK_PRODUCT_NAME,
        accountContractNumber: UBANK_PRODUCT_NAME,
        displayValue: "",
        productName: null,
        isSelected: UBANK_PRODUCT_NAME === this.selectedValue,
      });

      this.data = mappedData;
    } catch (error) {
      console.error("[APEX] getProductsListByCif error:", error);
    }
  }

  initAccountDataNonExisting() {
    this.data = [
      {
        id: "1",
        product: NON_EXISTING_CUSTOMER_PRODUCT_NAME,
        accountContractNumber: NON_EXISTING_CUSTOMER_PRODUCT_NAME,
        displayValue: "",
        productName: null,
        isSelected: NON_EXISTING_CUSTOMER_PRODUCT_NAME == this.selectedValue,
      },
      {
        id: "2",
        product: UBANK_PRODUCT_NAME,
        accountContractNumber: UBANK_PRODUCT_NAME,
        displayValue: "",
        productName: null,
        isSelected: UBANK_PRODUCT_NAME == this.selectedValue,
      },
    ];
    console.log(UBANK_PRODUCT_NAME, NON_EXISTING_CUSTOMER_PRODUCT_NAME);
  }

  get isNonExistingCustomer() {
    return this.interactionCustomerType === NON_EXISTING_CUSTOMER_TYPE;
  }

  get showPicklist() {
    return true;
  }

  /* =======================
   * UI ACTIONS
   * ======================= */

  toggle() {
    this.isOpen = !this.isOpen;
  }

  async handleRowAction(event) {
    const rowId = event.detail.row;

    const row = this.data.find((r) => r.id === rowId);

    if (!row) return;

    this.selectedRows = [row.id];

    this.data = this.data.map((r) => ({
      ...r,
      isSelected: r.id === row.id,
    }));
    this.selectedValue = row.accountContractNumber;
    const success = await this.createHistory();
    this.isOpen = false;
    if (success) {
      window.location.reload();
    }
  }

  async createHistory() {
    const selectedRow = this.data.find(
      (r) => r.accountContractNumber === this.selectedValue,
    );

    if (!selectedRow) {
      console.error("Selected row not found");
      return false;
    }

    try {
      if (this.isNonExistingCustomer) {
        await createHistoryNonExistingCustomer({
          caseId: this.interactionId,
          selectedType: selectedRow.product,
        });
      } else {
        await createHistory({
          caseId: this.interactionId,
          selectedAccountContractNumber: this.selectedValue,
          selectedType: selectedRow.product,
          cifNumber: this.cifNumber,
        });
      }

      return true;
    } catch (error) {
      console.error("Error creating history:", error);
      return false;
    }
  }
}
