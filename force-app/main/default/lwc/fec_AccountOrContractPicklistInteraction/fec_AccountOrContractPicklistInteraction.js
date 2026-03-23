import { LightningElement, api, wire, track } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import HAS_ACCOUNT_OR_CONTACT from "@salesforce/schema/Case.FEC_Has_Account_or_Contract__c";
import CUSTOMER_TYPE from "@salesforce/schema/Case.FEC_Customer_Type__c";
import getInteractionAccountNumber from "@salesforce/apex/FEC_AccountOrContractPicklistHandler.getInteractionAccountNumber";
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
    fields: [HAS_ACCOUNT_OR_CONTACT, RECORDTYPE_ID, CUSTOMER_TYPE],
  })
  wiredCase({ data, error }) {
    if (data) {
      this.hasAccountOrContact = getFieldValue(data, HAS_ACCOUNT_OR_CONTACT);
      this.recordTypeId = getFieldValue(data, RECORDTYPE_ID);
      this.customerType = getFieldValue(data, CUSTOMER_TYPE);
      console.log("[WIRE] Case loaded");
      console.log("[WIRE] recordId:", this.recordId);
      console.log("[WIRE] hasAccountOrContact:", this.hasAccountOrContact);
      console.log("[WIRE] customerType:", this.customerType);
      if (this.recordTypeId) {
        this.loadRecordType();
      }
      if (this.hasAccountOrContact) {
        this.getInteractionAccountNumber();
      } else {
        if (this.isNonExistingCustomer) {
          this.data = [
            {
              id: "1",
              product: NON_EXISTING_CUSTOMER_PRODUCT_NAME,
              accountContractNumber: NON_EXISTING_CUSTOMER_PRODUCT_NAME,
              displayValue: "",
              productName: null,
              isSelected:
                NON_EXISTING_CUSTOMER_PRODUCT_NAME === this.selectedValue,
            },
            {
              id: "2",
              product: UBANK_PRODUCT_NAME,
              accountContractNumber: UBANK_PRODUCT_NAME,
              displayValue: "",
              productName: null,
              isSelected: UBANK_PRODUCT_NAME === this.selectedValue,
            },
          ];
        }
      }
    }

    if (error) {
      console.error("[WIRE] Error loading Case", error);
    }
  }

  async loadRecordType() {
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

      this.selectedValue = data.accountNumber || "";
      this.cifNumber = data.cifNumber;

      await this.getProductsList();
    } catch (error) {
      console.error("[APEX] GetInteractionAccountNumber error:", error);
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

  get isNonExistingCustomer() {
    return this.customerType === NON_EXISTING_CUSTOMER_TYPE;
  }

  get showPicklist() {
    return this.hasAccountOrContact && this.isEditMode;
  }

  get isInteractionCase() {
    return this.recordTypeDevName === RECORD_TYPE_INTERACTION;
  }

  get isCustomerCase() {
    return this.recordTypeDevName === RECORD_TYPE_CUSTOMER_CASE;
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
      this.dispatchEvent(new RefreshEvent());
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
