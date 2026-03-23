import { LightningElement, api, wire, track } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import HAS_ACCOUNT_OR_CONTACT from "@salesforce/schema/Case.FEC_Has_Account_or_Contract__c";
import CUSTOMER_TYPE from "@salesforce/schema/Case.FEC_Customer_Type__c";
import getInteractionAccountNumber from "@salesforce/apex/FEC_AccountOrContractPicklistHandler.getInteractionAccountNumber";
import getInteractionIdFromCustomerCase from "@salesforce/apex/FEC_AccountOrContractPicklistHandler.getInteractionIdFromCustomerCase";
import getProductsListByCif from "@salesforce/apex/FEC_AccountOrContractPicklistHandler.getProductsListByCif";
import getRecordTypeName from "@salesforce/apex/FEC_InteractionInforHandler.getRecordTypeName";
import {
  UBANK_PRODUCT_NAME,
  NON_EXISTING_CUSTOMER_PRODUCT_NAME,
  RECORD_TYPE_INTERACTION,
  RECORD_TYPE_CUSTOMER_CASE,
  NON_EXISTING_CUSTOMER_TYPE,
} from "c/fec_CommonConst";
import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext,
} from "lightning/messageService";
import { RefreshEvent } from "lightning/refresh";
import createHistory from "@salesforce/apex/FEC_AccountOrContractPicklistHandler.createHistory";
import createHistoryNonExistingCustomer from "@salesforce/apex/FEC_AccountOrContractPicklistHandler.createHistoryNonExistingCustomer";

import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";
import FEC_ACCOUNT_CONTRACT_NUMBER_LABEL from "@salesforce/label/c.FEC_Account_Contract_Number_Label";
import RECORDTYPE_ID from "@salesforce/schema/Case.RecordTypeId";
export default class Fec_AccountOrContractPicklistInteraction extends LightningElement {
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
  customerType;
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
    fields: [HAS_ACCOUNT_OR_CONTACT, CUSTOMER_TYPE, RECORDTYPE_ID],
  })
  wiredCase({ data, error }) {
    if (data) {
      this.hasAccountOrContact = getFieldValue(data, HAS_ACCOUNT_OR_CONTACT);
      this.customerType = getFieldValue(data, CUSTOMER_TYPE);
      this.recordTypeId = getFieldValue(data, RECORDTYPE_ID);
      if (this.recordTypeId) {
        this.getRecordTypeName();
      }

      console.log("Test");
      console.log("hasAccountOrContact:", this.hasAccountOrContact);
      console.log("customerType:", this.customerType);
      console.log("recordTypeDevName:", this.recordTypeDevName);
      if (!this.isNonExistingCustomer) {
        this.getInteractionAccountNumber();
      } else {
        this.getInteractionAccountNumberNonExistingCustomer();
      }
    }

    if (error) {
      console.error("[WIRE] Error loading Case", error);
    }
  }

  async getRecordTypeName() {
    try {
      this.recordTypeDevName = await getRecordTypeName({
        recordId: this.recordId,
      });
    } catch (e) {
      console.error("getRecordTypeName error:", e);
    }
  }

  async getInteractionAccountNumber() {
    try {
      const result = await getInteractionAccountNumber({
        caseId: this.recordId,
      });
      const data = result ? JSON.parse(result) : {};
      console.log(JSON.stringify(data));
      this.selectedValue = data.accountNumber || "";
      this.cifNumber = data.cifNumber;

      await this.getProductsList();
    } catch (error) {
      console.error("[APEX] GetInteractionAccountNumber error:", error);
    }
  }

  async getInteractionAccountNumberNonExistingCustomer() {
    try {
      const result = await getInteractionAccountNumber({
        caseId: this.recordId,
      });
      const data = result ? JSON.parse(result) : {};
      console.log("### Test ###");
      console.log(JSON.stringify(data));
      this.selectedValue = data.accountNumber || "";
      this.cifNumber = data.cifNumber;
      this.initAccountDataNonExisting();
    } catch (error) {
      console.error(
        "[APEX] getInteractionAccountNumberNonExistingCustomer error:",
        error,
      );
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
        accountContractNumber: "Non-Existing Customer",
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

  get showPicklist() {
    return this.hasAccountOrContact && this.isEditMode && this.isInteraction;
  }

  get isNonExistingCustomer() {
    return this.customerType === NON_EXISTING_CUSTOMER_TYPE;
  }

  get isInteraction() {
    return this.recordTypeDevName === RECORD_TYPE_INTERACTION;
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
          caseId: this.recordId,
          selectedType: selectedRow.product,
        });
      } else {
        await createHistory({
          caseId: this.recordId,
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
