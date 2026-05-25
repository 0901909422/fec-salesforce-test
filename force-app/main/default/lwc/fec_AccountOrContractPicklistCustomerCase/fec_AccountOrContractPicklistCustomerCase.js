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
import getCustomerHistoryId from "@salesforce/apex/FEC_AccountOrContractPicklistHandler.getCustomerHistoryId";
import getAccountNumberCustomerCase from "@salesforce/apex/FEC_AccountOrContractPicklistHandler.getAccountNumberCustomerCase";
import getInteractionCustomerType from "@salesforce/apex/FEC_AccountOrContractPicklistHandler.getInteractionCustomerType";
import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";
import FEC_ACCOUNT_CONTRACT_NUMBER_LABEL from "@salesforce/label/c.FEC_Account_Contract_Number_Label";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import getInteractionIdFromCustomerCase from "@salesforce/apex/FEC_AccountOrContractPicklistHandler.getInteractionIdFromCustomerCase";
import CASE_ID from "@salesforce/schema/Case.Id";
import getInteractionFirstCustomerHistoryAccountNumber from "@salesforce/apex/FEC_AccountOrContractPicklistHandler.getInteractionFirstCustomerHistoryAccountNumber";
export default class AccountOrContractPicklistCustomerCase extends LightningElement {
  labels = {
    accountContractNumber: FEC_ACCOUNT_CONTRACT_NUMBER_LABEL,
  };

  @api recordId;
  selectedValue = "";
  cifNumber = "";
  hasAccountOrContact = false;
  phone = "";
  isOpen = false;
  selectedRows = [];
  isEditMode = false;
  recordTypeId;
  customerHistoryId;
  recordTypeDevName;
  subscription = null;
  interactionCustomerType;
  interactionId;
  @wire(MessageContext)
  messageContext;
  isLoading = false;
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

    if (message?.isModeEdit !== undefined && message?.caseId === this.recordId) {
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
    console.log("có data không");
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
      this.interactionId = await getInteractionIdFromCustomerCase({
        caseId: this.recordId,
      });

      this.interactionCustomerType = await getInteractionCustomerType({
        caseId: this.interactionId,
      });

      this.customerHistoryId = await getCustomerHistoryId({
        caseId: this.recordId,
      });

      console.log("interactionId:", this.interactionId);
      console.log("interactionCustomerType:", this.interactionCustomerType);
      console.log("customerHistoryId:", this.customerHistoryId);

      await this.getInteractionFirstCustomerHistoryAccountNumber();
      await this.loadAccountData();
    } catch (e) {
      console.error("initData error:", e);
    }
  }

  async loadAccountData(retry = 0) {
    if (this.isLoading || !this.interactionId) return;

    this.isLoading = true;

    try {
      const result = await getInteractionAccountNumber({
        caseId: this.interactionId,
      });

      const parsed = result ? JSON.parse(result) : {};

      console.log("DATA final customer case:", parsed);

      // Retry nếu chưa có accountNumber
      if (!parsed?.accountNumber) {
        if (retry < 3) {
          console.warn(`Retry lần ${retry + 1}`);

          setTimeout(() => {
            this.isLoading = false;
            this.loadAccountData(retry + 1);
          }, 300);

          return;
        }
      }
      // Set base state
      this.selectedValue = parsed?.accountNumber || "";
      this.cifNumber = parsed?.cifNumber || "";
      this.hasAccountOrContact = parsed?.hasContractAccount || false;
      this.phone = parsed?.phone || "";
      // Load data list
      await this.loadProductData();
    } catch (error) {
      console.error("loadAccountData error:", error);
    } finally {
      this.isLoading = false;
    }
  }

  async loadProductData() {
    if (this.isNonExistingCustomer) {
      this.initAccountDataNonExisting();
      return;
    }

    if (!this.cifNumber) {
      console.warn("Missing CIF → skip getProductsList");
      this.data = [];
      return;
    }

    await this.getProductsList();
  }

  async getInteractionFirstCustomerHistoryAccountNumber() {
    if (!this.interactionId) return;

    const result = await getInteractionFirstCustomerHistoryAccountNumber({
      caseId: this.interactionId,
    });

    console.log("AccountNumber:", result);

    this.firstAccountContractNumber = result || "";
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
        if (selectedRow.product === UBANK_PRODUCT_NAME) {
          this.selectedValue = this.firstAccountContractNumber;
        }

        console.log(
          "Creating history with:",
          JSON.stringify({
            caseId: this.interactionId,
            selectedAccountContractNumber: this.selectedValue,
            selectedType: selectedRow.product,
            cifNumber: this.cifNumber,
            phone: this.phone,
          }),
        );
        await createHistory({
          caseId: this.interactionId,
          selectedAccountContractNumber: this.selectedValue,
          selectedType: selectedRow.product,
          cifNumber: this.cifNumber,
          phone: this.phone,
        });
      }

      return true;
    } catch (error) {
      console.error("Error creating history:", error);
      return false;
    }
  }
}
