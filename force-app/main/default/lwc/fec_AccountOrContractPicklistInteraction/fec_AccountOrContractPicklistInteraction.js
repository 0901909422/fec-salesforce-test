import { LightningElement, api, wire, track } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import HAS_ACCOUNT_OR_CONTACT from "@salesforce/schema/Case.FEC_Has_Account_or_Contract__c";
import getInteractionAccountNumber from "@salesforce/apex/FEC_AccountOrContractPicklistHanlder.getInteractionAccountNumber";
import GetProductsListByCif from "@salesforce/apex/FEC_AccountOrContractPicklistHanlder.GetProductsListByCif";
import getRecordTypeName from "@salesforce/apex/FEC_InteractionInforHandler.getRecordTypeName";
import { UBANK_PRODUCT_NAME } from "c/fec_CommonConst";
import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext,
} from "lightning/messageService";

import createHistory from "@salesforce/apex/FEC_AccountOrContractPicklistHanlder.createHistory";

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
      fieldName: "accountContractNumber",
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
    fields: [HAS_ACCOUNT_OR_CONTACT, RECORDTYPE_ID],
  })
  wiredCase({ data, error }) {
    if (data) {
      this.hasAccountOrContact = getFieldValue(data, HAS_ACCOUNT_OR_CONTACT);
      this.recordTypeId = getFieldValue(data, RECORDTYPE_ID);
      console.log("[WIRE] Case loaded");
      console.log("[WIRE] recordId:", this.recordId);
      console.log("[WIRE] hasAccountOrContact:", this.hasAccountOrContact);
      if (this.recordTypeId) {
        this.loadRecordType();
      }
      if (this.hasAccountOrContact) {
        this.getInteractionAccountNumber();
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

  getInteractionAccountNumber() {
    getInteractionAccountNumber({ caseId: this.recordId })
      .then((result) => {
        const data = JSON.parse(result);

        console.log(data.accountNumber);
        console.log(data.cifNumber);
        this.selectedValue = data.accountNumber;
        this.cifNumber = data.cifNumber;

        // gọi tiếp sau khi đã có cif
        return this.getProductsList();
      })
      .catch((error) => {
        console.error("[APEX] GetInteractionAccountNumber error:", error);
      });
  }

  getProductsList() {
    GetProductsListByCif({ cifNumber: this.cifNumber })
      .then((result) => {
        console.log(
          "[APEX] GetProductsListByCif result:",
          JSON.stringify(result),
        );
        const mappedData = result.map((item, index) => ({
          id: String(index + 1),
          product: item.productType,
          accountContractNumber: item.accountContractNumber,
          productName: item.productName,
          isSelected: item.accountContractNumber === this.selectedValue
        }));

        mappedData.push({
          id: String(mappedData.length + 1),
          product: UBANK_PRODUCT_NAME,
          accountContractNumber: UBANK_PRODUCT_NAME,
          productName: UBANK_PRODUCT_NAME,
          isSelected: UBANK_PRODUCT_NAME === this.selectedValue
        });
        console.log("Mapped Data:", mappedData);
        this.data = mappedData;
      })
      .catch((error) => {
        console.error("[APEX] GetProductsListByCif error:", error);
      });
  }

  get showPicklist() {
    return this.hasAccountOrContact && this.isEditMode;
  }

  get isInteractionCase() {
    return this.recordTypeDevName === "Interaction";
  }

  get isCustomerCase() {
    return this.recordTypeDevName === "Customer_Case";
  }
  /* =======================
   * UI ACTIONS
   * ======================= */

  toggle() {
    this.isOpen = !this.isOpen;
  }

  handleRowAction(event) {
    const rowId = event.detail.row;

    const row = this.data.find((r) => r.id === rowId);

    if (!row) return;

    this.selectedRows = [row.id];

    this.data = this.data.map((r) => ({
      ...r,
      isSelected: r.id === row.id,
    }));
    this.selectedValue = row.accountContractNumber;
    this.createHistory();
    this.isOpen = false;
  }

  createHistory() {
    createHistory({
      caseId: this.recordId,
      selectedAccountContractNumber: this.selectedValue,
      selectedType: this.data.find(
        (r) => r.accountContractNumber === this.selectedValue,
      )?.product,
      cifNumber: this.cifNumber,
    })
      .then(() => {
        console.log("History created successfully");
      })
      .catch((error) => {
        console.error("Error creating history:", error);
      });
  }
}
