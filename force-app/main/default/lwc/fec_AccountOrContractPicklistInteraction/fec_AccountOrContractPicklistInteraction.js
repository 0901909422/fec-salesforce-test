import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import HAS_ACCOUNT_OR_CONTACT from "@salesforce/schema/Case.FEC_Has_Account_or_Contract__c";
import GetProductsListByCif from "@salesforce/apex/FEC_AccountOrContractPicklistHanlder.GetProductsListByCif";

export default class Fec_AccountOrContractPicklistInteraction extends LightningElement {
  @api recordId;

  selectedValue = "0001500010000123456";
  hasAccountOrContact = false;
  isOpen = false;

  selectedRows = [];

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
      label: "Account/Contract Number",
      fieldName: "accountContractNumber",
    },
    { label: "Product Name", fieldName: "productName" },
  ];

  data = [];

  /* =======================
   * WIRE
   * ======================= */
  @wire(getRecord, {
    recordId: "$recordId",
    fields: [HAS_ACCOUNT_OR_CONTACT],
  })
  wiredCase({ data, error }) {
    if (data) {
      this.hasAccountOrContact = getFieldValue(data, HAS_ACCOUNT_OR_CONTACT);

      console.log("[WIRE] Case loaded");
      console.log("[WIRE] recordId:", this.recordId);
      console.log("[WIRE] hasAccountOrContact:", this.hasAccountOrContact);

      // if (this.hasAccountOrContact) {
      //   this.getProductsList();
      // }
    }

    if (error) {
      console.error("[WIRE] Error loading Case", error);
    }
  }

  getProductsList() {
    GetProductsListByCif({ cifNumber: "" })
      .then((result) => {
        console.log(
          "[APEX] GetProductsListByCif result:",
          JSON.stringify(result, null, 2),
        );

        this.data = result.map((item, index) => ({
          id: String(index + 1),
          product: item.productType,
          accountContractNumber: item.accountContractNumber,
          productName: item.productName,
          isSelected: false,
        }));
        this.data.push({
          id: String(this.data.length + 1),
          product: "UBANK",
          accountContractNumber: "",
          productName: "",
          isSelected: false,
        });
      })
      .catch((error) => {
        console.error(
          "[APEX] GetProductsListByCif error:",
          JSON.stringify(error),
        );
      });
  }

  /* =======================
   * UI ACTIONS
   * ======================= */
  toggle() {
    this.isOpen = !this.isOpen;

    console.log("[ACTION] toggle popover");
    console.log("[STATE] isOpen:", this.isOpen);
  }

  handleRowSelection(event) {
    const selected = event.detail.selectedRows;

    console.log("[ACTION] row selection event fired");
    console.log("[EVENT] selectedRows:", JSON.stringify(selected));

    if (!selected.length) return;

    const row = selected[0];
    const now = Date.now();

    // single click
    this.selectedRows = [row.id];
    this.data = this.data.map((r) => ({
      ...r,
      isSelected: r.id === row.id,
    }));

    console.log("[STATE] selected row id:", row.id);
    console.log("[STATE] selectedRows:", JSON.stringify(this.selectedRows));
    console.log("[STATE] data after select:", JSON.stringify(this.data));

    this.selectedValue = row.accountContractNumber;
  }

  handleUbankClick() {
    this.selectedValue = "UBANK";
    // ví dụ:
    // open UBANK tab
    // publish LMS
    // navigate external
  }
}