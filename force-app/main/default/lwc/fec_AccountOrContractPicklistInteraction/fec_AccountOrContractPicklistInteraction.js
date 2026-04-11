import { LightningElement, api, wire, track } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import HAS_ACCOUNT_OR_CONTACT from "@salesforce/schema/Case.FEC_Has_Account_or_Contract__c";
import CUSTOMER_TYPE from "@salesforce/schema/Case.FEC_Customer_Type__c";
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
import getInteractionFirstCustomerHistoryAccountNumber from "@salesforce/apex/FEC_AccountOrContractPicklistHandler.getInteractionFirstCustomerHistoryAccountNumber";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Interaction_Case_Mode__c";
import FEC_ACCOUNT_CONTRACT_NUMBER_LABEL from "@salesforce/label/c.FEC_Account_Contract_Number_Label";
import RECORDTYPE_ID from "@salesforce/schema/Case.RecordTypeId";
import {
  getMode,
  setMode,
  subscribeMode,
  unsubscribeMode,
} from "c/fec_InteractionCaseModeStore";
export default class Fec_AccountOrContractPicklistInteraction extends LightningElement {
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
  recordTypeDevName;
  subscription = null;
  customerType;
  isLoading = false;
  isInitialized = false;
  @wire(MessageContext)
  messageContext;
  firstAccountContractNumber;
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
    this.isEditMode = getMode();

    this._modeListener = (value) => {
      this.isEditMode = value;
      console.log("[STORE] isEditMode:", value);
    };
    subscribeMode(this._modeListener);

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
      setMode(message.isModeEdit);
    }
  }

  disconnectedCallback() {
    if (this.subscription) {
      unsubscribe(this.subscription);
      this.subscription = null;
    }

    if (this._modeListener) {
      unsubscribeMode(this._modeListener);
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
      console.log("🔥 WIRED TRIGGERED");
      // reset state để force UI rebuild
      this.isOpen = false;
      this.hasAccountOrContact = getFieldValue(data, HAS_ACCOUNT_OR_CONTACT);
      this.customerType = getFieldValue(data, CUSTOMER_TYPE);

      //  FIX: chỉ load khi có recordId và chưa init
      if (this.recordId) {
        this.loadAccountData();
      }
    }

    if (error) {
      console.error("[WIRE] Error loading Case", error);
    }
  }

  // ===== CORE LOGIC =====
  async loadAccountData(retry = 0) {
    if (this.isLoading || !this.recordId) return;

    this.isLoading = true;

    try {
      const result = await getInteractionAccountNumber({
        caseId: this.recordId,
      });

      const parsed = result ? JSON.parse(result) : {};

      console.log("DATA:", JSON.stringify(parsed));

      // ❗ nếu chưa có data → retry
      if (!parsed.accountNumber && retry < 3) {
        console.warn(`Retry lần ${retry + 1}`);

        setTimeout(() => {
          this.isLoading = false; // unlock
          this.loadAccountData(retry + 1);
        }, 300);

        return;
      }

      // ✅ data OK → set state
      this.selectedValue = parsed.accountNumber || "";
      this.cifNumber = parsed.cifNumber;
      this.phone = parsed.phone || "";
      await this.getInteractionFirstCustomerHistoryAccountNumber();
      if (this.isNonExistingCustomer) {
        this.initAccountDataNonExisting();
      } else {
        await this.getProductsList();
      }
    } catch (e) {
      console.error("loadAccountData error:", e);
    } finally {
      this.isLoading = false;
    }
  }

  async getProductsList() {
    if (!this.cifNumber) {
      this.data = [];
      return;
    }

    try {
      const result = await getProductsListByCif({
        cifNumber: this.cifNumber,
      });

      if (!result || !Array.isArray(result)) {
        this.data = [];
        return;
      }

      const mapped = result.map((item, index) => ({
        id: String(index + 1),
        product: item.productType,
        accountContractNumber: item.accountContractNumber,
        displayValue: item.accountContractNumber,
        productName: item.productName,
        isSelected: item.accountContractNumber === this.selectedValue,
      }));

      mapped.push({
        id: String(mapped.length + 1),
        product: UBANK_PRODUCT_NAME,
        accountContractNumber: UBANK_PRODUCT_NAME,
        displayValue: "",
        productName: null,
        isSelected: UBANK_PRODUCT_NAME === this.selectedValue,
      });

      this.data = mapped;
    } catch (e) {
      console.error("loadProducts error:", e);
    }
  }

  async getInteractionFirstCustomerHistoryAccountNumber() {
    if (!this.recordId) return;

    const result = await getInteractionFirstCustomerHistoryAccountNumber({
      caseId: this.recordId,
    });

    console.log("AccountNumber:", result);

    this.firstAccountContractNumber = result || "";
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
    return this.hasAccountOrContact && this.isEditMode;
  }

  get isNonExistingCustomer() {
    return this.customerType === NON_EXISTING_CUSTOMER_TYPE;
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
      await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
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
        if (selectedRow.product === UBANK_PRODUCT_NAME) {
          this.selectedValue = this.firstAccountContractNumber;
        }

        console.log(
          "Creating history with:",
          JSON.stringify({
            caseId: this.recordId,
            selectedAccountContractNumber: this.selectedValue,
            selectedType: selectedRow.product,
            cifNumber: this.cifNumber,
            phone: this.phone,
          }),
        );
        await createHistory({
          caseId: this.recordId,
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