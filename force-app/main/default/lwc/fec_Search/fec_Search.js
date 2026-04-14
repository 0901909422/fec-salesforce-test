import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import {
  updateRecord,
  notifyRecordUpdateAvailable,
} from "lightning/uiRecordApi";
import Toast from "lightning/toast";
import { refreshApex } from "@salesforce/apex";
import { RefreshEvent } from "lightning/refresh";
import { loadStyle } from "lightning/platformResourceLoader";
import COMMON_STYLES from "@salesforce/resourceUrl/FEC_CommonCss";
import getCase from "@salesforce/apex/FEC_SearchController.getCase";
import createHistory from "@salesforce/apex/FEC_SearchController.createHistory";
import getB2Contracts from "@salesforce/apex/FEC_SearchController.getB2Contracts";
import getCash24Contracts from "@salesforce/apex/FEC_SearchController.getCash24Contracts";
import getCustomerList from "@salesforce/apex/FEC_GetCustomerList.getCustomerList";
import getBancaInsurance from "@salesforce/apex/FEC_SearchByListNIDs.searchByNIDs";

import FEC_National_ID_Passport_ID_Label  from '@salesforce/label/c.FEC_National_ID_Passport_ID_Label';
import FEC_Toast_Search_Validation from '@salesforce/label/c.FEC_Toast_Search_Validation';
import FEC_Toast_Validation_Title from '@salesforce/label/c.FEC_Toast_Validation_Title';
import FEC_Toast_Refresh_Success from '@salesforce/label/c.FEC_Toast_Refresh_Success';
import FEC_Toast_Error from '@salesforce/label/c.FEC_Toast_Error';
import FEC_Toast_Error_Generic from '@salesforce/label/c.FEC_Toast_Error_Generic';
import FEC_MSG_Create_Customer_History_Error from '@salesforce/label/c.FEC_MSG_Create_Customer_History_Error';
import FEC_MSG_Create_Customer_History_Success from '@salesforce/label/c.FEC_MSG_Create_Customer_History_Success';

import checkFieldEditPermissions from "@salesforce/apex/FEC_SearchController.checkFieldEditPermissions";
import SkipModal from "c/fec_SkipModal";
import createInternalCase from "@salesforce/apex/FEC_CreateCaseHandler.createInternalCase";
import createInternalCaseOnSkip from "@salesforce/apex/FEC_SearchController.createInternalCaseOnSkip";
import {
  publish,
  MessageContext,
} from "lightning/messageService";
import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";
import IS_MODE_EDIT_INTERACTION from "@salesforce/messageChannel/FEC_Interaction_Case_Mode__c";
import {
  IsConsoleNavigation,
  getFocusedTabInfo,
  refreshTab,
} from "lightning/platformWorkspaceApi";
import getCardInfoByAccountNumber from "@salesforce/apex/FEC_SearchController.getCardInfoByAccountNumber";
import getApplicationHistory from "@salesforce/apex/FEC_SearchController.getApplicationHistory";
import CASE_ID_FIELD from "@salesforce/schema/Case.Id";
import SEARCH_NATIONAL_ID_FIELD from "@salesforce/schema/Case.FEC_Search_National_ID__c";
import SEARCH_PHONE_FIELD from "@salesforce/schema/Case.FEC_Search_Phone_Number__c";
import SEARCH_APP_ID_FIELD from "@salesforce/schema/Case.FEC_Search_Application_ID__c";
import SEARCH_CONTRACT_FIELD from "@salesforce/schema/Case.FEC_Search_Contract_Number__c";
import SEARCH_ACCOUNT_FIELD from "@salesforce/schema/Case.FEC_Search_Account_Number__c";
import SEARCH_EMAIL_FIELD from "@salesforce/schema/Case.FEC_Search_Email_Address__c";
import SEARCH_CUSTOMER_NUM_FIELD from "@salesforce/schema/Case.FEC_Search_Customer_Number__c";
import { CurrentPageReference } from 'lightning/navigation';

const FIELDS_TO_CHECK = [
    'FEC_Search_National_ID__c',
    'FEC_Search_Phone_Number__c',
    'FEC_Search_Application_ID__c',
    'FEC_Search_Contract_Number__c',
    'FEC_Search_Account_Number__c',
    'FEC_Search_Email_Address__c',
    'FEC_Search_Customer_Number__c'
];

export default class Fec_Search extends NavigationMixin(LightningElement) {
  @api recordId;
  @api isLoaded = false;
  @api showSkipButton = false;
  activeSections = ["searchCriteria", "results"];
  nationalId;
  phoneNumber;
  isDisplay = false;
  applicationId;
  contractNumber;
  accountNumber;
  emailAddress;
  customerNumber;
  fullName = "";
  custNameForCreate = "";
  nationalIdForCreate = "";
  @api isNoCustomerFound = false;
  showNewCaseModal = false;
  isSkip;
  wiredCaseResult;
  fieldPermissions;

  FEC_Toast_Search_Validation = FEC_Toast_Search_Validation;
  FEC_Toast_Validation_Title = FEC_Toast_Validation_Title;
  FEC_Toast_Error = FEC_Toast_Error;
  FEC_Toast_Error_Generic = FEC_Toast_Error_Generic;
  FEC_National_ID_Passport_ID_Label = FEC_National_ID_Passport_ID_Label;
  FEC_MSG_Create_Customer_History_Error = FEC_MSG_Create_Customer_History_Error;
  FEC_MSG_Create_Customer_History_Success = FEC_MSG_Create_Customer_History_Success;
  FEC_Toast_Refresh_Success = FEC_Toast_Refresh_Success;

  @wire(MessageContext)
  messageContext;

  @wire(CurrentPageReference)
  pageRef;

  get tabName() {
    return this.pageRef?.attributes?.apiName; // e.g. 'Customer_Search'
  }

  get tabLabel() {
    return this.tabName == 'FEC_Account_Contract_Search' ? 'Account/Contract Search' : 'Customer Search';
  }

  get isAccountContractSearch() {
    return this.tabName === 'FEC_Account_Contract_Search'; // your tab's API name
  }

  get isListView() {
    return this.pageRef?.type === 'standard__objectPage' &&
      this.pageRef?.attributes?.objectApiName === 'Case' &&
      !this.recordId;
  }

  get isCreateCaseTab() {
    return this.pageRef?.type === 'standard__navItemPage' &&
      this.pageRef?.attributes?.apiName === 'Create_Case';
  }

  @wire(IsConsoleNavigation) isConsoleNavigation;
  async refreshTab() {
    if (!this.isConsoleNavigation) {
      return;
    }
    const { tabId } = await getFocusedTabInfo();
    await refreshTab(tabId, {
      includeAllSubtabs: true,
    });
  }
  // Active tab state
  activeTabValue = "Card";

  // Demo columns per tab (adjust fields as needed)
  get cardColumns() {
    return [
      {
        label: "Account Number",
        type: "dblclickText",
        fieldName: "AccountNumber",
        typeAttributes:  {
              value: { fieldName: "AccountNumber" },
              fieldName: "AccountNumber",
              selectedType: "Card",
              isExpanded: this.isAccountContractSearch ? { fieldName: "_isExpanded" } : false,
              isAccountContractSearch: this.isAccountContractSearch
            },
        sortable: false,
      },
      { label: "Customer Name", fieldName: "FullName", sortable: true },
      {
        label: "National ID 1",
        fieldName: "NationalID1",
        type: "maskedToggle",
        sortable: true,
        typeAttributes:  {
              caseId: this.recordId
            },
      },
      {
        label: "National ID 2",
        fieldName: "NationalID2",
        type: "maskedToggle",
        sortable: true,
        typeAttributes:  {
              caseId: this.recordId
            },
      },
      { label: "Date of Birth", 
        fieldName: "DateOfBirth", 
        type: "date", 
        typeAttributes:{
            day: "2-digit",
            month: "2-digit",
            year: "numeric"
        },
        sortable: true },
      { label: "Plastic ID", fieldName: "PlasticID", sortable: true },
      ...(this.isAccountContractSearch ? [{ label: "Application ID", fieldName: "ApplicationID", sortable: true }] : []),
      { label: "Account Status", fieldName: "AccountStatus", sortable: true },
    ];
  }

  get isDisabledSearch() {
    return !(
      (this.nationalId && this.nationalId.trim()) ||
      (this.phoneNumber && this.phoneNumber.trim()) ||
      (this.applicationId && this.applicationId.trim()) ||
      (this.contractNumber && this.contractNumber.trim()) ||
      (this.accountNumber && this.accountNumber.trim()) ||
      (this.emailAddress && this.emailAddress.trim())
    );
  }

  get isShowCustomerNumber() {
    return this.recordId ? true : false;
  }

  get nationalId_PassPortId_PlaceHolder() {
    return 'Nhập ' + this.FEC_National_ID_Passport_ID_Label;
  }

  get loanContractColumns() {
    return [
      {
        label: "Contract Number",
        type: "dblclickText",
        fieldName: "ContractNumber",
        typeAttributes:  {
              value: { fieldName: "ContractNumber" },
              fieldName: "ContractNumber",
              selectedType: "Loan",
              isExpanded: this.isAccountContractSearch ? { fieldName: "_isExpanded" } : false,
              isAccountContractSearch: this.isAccountContractSearch
            },
        sortable: false,
      },
      { label: "Customer Name", fieldName: "FullName", sortable: true },
      {
        label: "National ID 1",
        fieldName: "NationalID1",
        type: "maskedToggle",
        sortable: true,
        typeAttributes:  {
              caseId: this.recordId
            },
      },
      {
        label: "National ID 2",
        fieldName: "NationalID2",
        type: "maskedToggle",
        sortable: true,
        typeAttributes:  {
              caseId: this.recordId
            },
      },
      { label: "Date of Birth", 
        fieldName: "DateOfBirth", 
        type: "date", 
        typeAttributes:{
            day: "2-digit",
            month: "2-digit",
            year: "numeric"
        }, 
        sortable: true },
      { label: "Plastic ID", fieldName: "PlasticID", sortable: true },
      ...(this.isAccountContractSearch ? [{ label: "Application ID", fieldName: "ApplicationID", sortable: true }] : []),
      { label: "Account Status", fieldName: "ContractStatus", sortable: true },
    ];
  }

  get loanB2Columns() {
    return [
      { label: "Contract Number", fieldName: "ContractNumber", sortable: true },
      { label: "Customer Name", fieldName: "FullName", sortable: true },
      {
        label: "National ID",
        fieldName: "NationalID1",
        type: "maskedToggle",
        sortable: true,
        typeAttributes:  {
              caseId: this.recordId
            },
      },
      { label: "Code", fieldName: "Code", sortable: true },
      { label: "Product Code", fieldName: "ProductCode", sortable: true },
      { label: "Installment", fieldName: "Installment", sortable: true },
      { label: "Principal", fieldName: "Principal", sortable: true },
      { label: "Monthly Fee", fieldName: "MonthlyFee", sortable: true },
      { label: "Term", fieldName: "Term", sortable: true },
      { label: "City ", fieldName: "City", sortable: true },
    ];
  }

  get loanCash24Columns() {
    return [
      { label: "Contract Number", fieldName: "ContractNumber", sortable: true },
      { label: "Sold Date", fieldName: "SoldDate", sortable: true,
        type: "date", 
        typeAttributes:{
            day: "2-digit",
            month: "2-digit",
            year: "numeric",
            dateStyle: "short"
        },
       },
      { label: "Balance Amount", fieldName: "BalanceAmount", sortable: true },
      { label: "Product Code", fieldName: "ProductCode", sortable: true },
      { label: "Contract Status", fieldName: "ContractStatus", sortable: true },
      { label: "Note", fieldName: "Note", sortable: true },
    ];
  }

  get insuranceColumns() {
    return [
      {
        label: "User ID",
        type: "dblclickText",
        fieldName: "UserId",
        typeAttributes:  {
              value: { fieldName: "UserId" },
              fieldName: "UserId",
              selectedType: "Insurance"
            },
        sortable: false,
      },
      { label: "Customer Name", fieldName: "FullName", sortable: true },
      { label: "Date of Birth", 
        fieldName: "DateOfBirth", 
        type: "date", 
        typeAttributes:{
            day: "2-digit",
            month: "2-digit",
            year: "numeric"
        },
        sortable: true },
      {
        label: "Buyer NID",
        fieldName: "BuyerNID",
        type: "maskedToggle",
        sortable: true,
        typeAttributes:  {
              caseId: this.recordId
            },
      },
      { label: "Product Name", fieldName: "ProductName", sortable: true },
      {
        label: "Premium Fee",
        fieldName: "PremiumFee",
        type: "currency",
        sortable: true,
      },
      { label: "Payment ID", fieldName: "PaymentId", sortable: true },
      {
        label: "Effective Date",
        fieldName: "EffectiveDate",
        type: "date", 
        typeAttributes:{
            day: "2-digit",
            month: "2-digit",
            year: "numeric"
        },
        sortable: true,
      },
      { label: "Status", fieldName: "Status", sortable: true },
    ];
  }

  get ubankColumns() {
    return [
      { label: "Customer Name", fieldName: "FullName", sortable: true },
      {
        label: "National ID 1",
        fieldName: "NationalID1",
        type: "maskedToggle",
        sortable: true,
      },
      {
        label: "National ID 2",
        fieldName: "NationalID2",
        type: "maskedToggle",
        sortable: true,
      },
      { label: "Date of Birth", fieldName: "DateOfBirth", sortable: true },
      { label: "Account Status", fieldName: "AccountStatus", sortable: true },
      {
        label: "Account Number",
        type: this.recordId ? "button" : "text",
        fieldName: "AccountNumber",
        typeAttributes: this.recordId
          ? {
              label: { fieldName: "AccountNumber" },
              name: "create_history",
              variant: "base",
              value: { fieldName: "AccountNumber" },
            }
          : {},
        sortable: false,
      },
    ];
  }

  // Sample data placeholders (replace with real wired/callout data)
  cardData = [];
  // Deprecated aggregate loanData; keeping for backward-compat but unused in UI now
  loanData = [];
  // New, specific datasets per loan table
  loanContractData = [];
  loanB2Data = [];
  loanCash24Data = [];
  insuranceData = [];
  ubankData = [];

  // Application History state: key = applicationId, value = { loading, rows, expanded }
  appHistoryMap = {};
  // Modal state
  historyModalKey = null;
  historyModalRows = [];
  historyModalLoading = false;
  get showHistoryModal() { return !!this.historyModalKey; }

  handleCloseHistoryModal() {
    this.historyModalKey = null;
    this.historyModalRows = [];
  }

  @wire(getCase, { caseId: "$recordId" })
  wiredCase(result) {
    this.wiredCaseResult = result;
    const { data, error } = result;
    if (data) {
      // Logic xử lý dữ liệu khi thành công (tương đương phần .then cũ)
      this.isSkip = this.showSkipButton || (data && data.RecordType?.Name === 'Internal Case');
      this.isDisplay =
        data.Customer_Histories__r === undefined &&
        data.FEC_Skip_Search_Internal_Case__c === false;
    } else if (error) {
      // Xử lý lỗi (tương đương phần .catch cũ)
      console.error("Error fetching case data:", error);
      // this.showToast('Error', 'Không thể lấy thông tin Case', 'error');
    }
  }

  async connectedCallback() {
    this.isLoaded = false;
    this.isSkip = this.showSkipButton;
    // Load styles
    loadStyle(this, COMMON_STYLES)
      .then(() => console.log("Common styles loaded"))
      .catch((err) => console.error(err));

    try {
      let objectName;
      if (this.recordId) {
        objectName = 'Case';
      } else {
        objectName = 'FEC_Customer_Search__c';
      }
      this.fieldPermissions = await checkFieldEditPermissions({
        sObjectType: objectName,
        fieldNames: FIELDS_TO_CHECK
      })
      let result = await getCase({ caseId: this.recordId });
      this.nationalId = this.fieldPermissions['FEC_Search_National_ID__c'] ? result.FEC_National_ID_Passport_ID__c : null;
      this.phoneNumber = this.fieldPermissions['FEC_Search_Phone_Number__c'] ? result.FEC_Phone_Number__c : null;
      this.applicationId = this.fieldPermissions['FEC_Search_Application_ID__c'] ? result.FEC_Application_ID__c : null;
      this.contractNumber = this.fieldPermissions['FEC_Search_Contract_Number__c'] ? result.FEC_Contract_Number__c : null;
      this.accountNumber = this.fieldPermissions['FEC_Search_Account_Number__c'] ? result.FEC_Account_Number__c : null;
      this.emailAddress = this.fieldPermissions['FEC_Search_Email_Address__c'] ? result.FEC_Interaction_Email__c : null;
      //this.customerNumber = this.fieldPermissions['FEC_Search_Customer_Number__c'] ? result.FEC_Search_Customer_Number__c : null;
     if (this.applicationId || this.phoneNumber || this.nationalId || this.contractNumber || this.accountNumber || this.emailAddress) {
        await this.processSearch();
      }
    } catch (error) {
      console.error("Error fetching case data:", error);
    }
    this.isLoaded = true;
    if (!this.recordId) {
      this.isDisplay = true;
    }
  }
  get isDisabledNationalId() {
    return this.fieldPermissions ? !this.fieldPermissions['FEC_Search_National_ID__c'] : true;
  }

  get isDisabledPhoneNumber() {
    return this.fieldPermissions ? !this.fieldPermissions['FEC_Search_Phone_Number__c'] : true;
  }

  get isDisabledApplicationId() {
    return this.fieldPermissions ? !this.fieldPermissions['FEC_Search_Application_ID__c'] : true;
  }

  get isDisabledContractNumber() {
    return this.fieldPermissions ? !this.fieldPermissions['FEC_Search_Contract_Number__c'] : true;
  }

  get isDisabledAccountNumber() {
    return this.fieldPermissions ? !this.fieldPermissions['FEC_Search_Account_Number__c'] : true;
  }

  get isDisabledEmailAddress() {
    return this.fieldPermissions ? !this.fieldPermissions['FEC_Search_Email_Address__c'] : true;
  }

  get isDisabledCustomerNumber() {
    return this.fieldPermissions ? !this.fieldPermissions['FEC_Search_Customer_Number__c'] : true;
  }

  // Handle inputs (wire these ids to your current fields as needed)
  handleInputChange(event) {
    const id = event.target.dataset.id;
    const value = event.detail.value;
    switch (id) {
      case "nationalId":
        this.nationalId = value;
        // Validate National ID length: must be 9 or 12 chars
        {
          const input = this.template.querySelector('[data-id="nationalId"]');
          if (input) {
            if (!value) {
              // Empty value: clear custom error
              input.setCustomValidity("");
            } else if (value.length !== 9 && value.length !== 12) {
              input.setCustomValidity(
                "National ID must be 9 characters or 12 characters",
              );
            } else {
              input.setCustomValidity("");
            }
            input.reportValidity();
          }
        }
        break;
      case "phoneNumber":
        this.phoneNumber = value;
        const input = this.template.querySelector('[data-id="phoneNumber"]');
        if (input) {
            const val = value ? value.toString().trim() : "";
            if (!val) {
                input.setCustomValidity("");
            } else if (val.startsWith('0')) {
                // Check if starts with 0 and has exactly 10 digits
                if (!/^0\d{9}$/.test(val)) {
                    input.setCustomValidity("Phone number starting with 0 must be exactly 10 digits.");
                } else {
                    input.setCustomValidity("");
                }
            } else if (val.startsWith('84')) {
                // Check if starts with 84 and has exactly 11 digits
                if (!/^84\d{9}$/.test(val)) {
                    input.setCustomValidity("Phone number starting with 84 must be exactly 11 digits.");
                } else {
                    input.setCustomValidity("");
                }
            } else {
                // Fallback for invalid prefixes
                input.setCustomValidity("Phone number must start with 0 (10 digits) or 84 (11 digits).");
            }
            input.reportValidity();
        }
        break;
      case "applicationId":
        this.applicationId = value;
        {
          const input = this.template.querySelector(
            '[data-id="applicationId"]',
          );
          if (input) {
            const val = value ? value.toString().trim() : "";
            if (!val) {
              // allow empty
              input.setCustomValidity("");
            } else if (!/^\d+$/.test(val)) {
              input.setCustomValidity(
                "Application ID must contain only digits",
              );
            } else if (
              !(val.length === 6 || val.length === 8 || val.length === 9)
            ) {
              input.setCustomValidity(
                "Application ID must be 6, 8, or 9 digits",
              );
            } else {
              input.setCustomValidity("");
            }
            input.reportValidity();
          }
        }
        break;
      case "contractNumber":
        this.contractNumber = value;
        // Validate Contract Number against allowed formats:
        {
          const input = this.template.querySelector(
            '[data-id="contractNumber"]',
          );
          if (input) {
            const val = value ? value.toString().trim() : "";
            const patterns = [
              /^\d{8}-\d{6}-\d{4}$/,
              /^\d{8}-\d{7}-\d{3}$/,
              /^\d{8}-\d{7}-\d{2}$/,
              /^\d{8}-\d{7}-\d{1}$/,
              /^\d{8}-\d{7}$/,
              /^\d{2}-\d{2}-\d{2}-\d{2}$/,
            ];
            const valid = !val || patterns.some((re) => re.test(val));
            if (!valid) {
              input.setCustomValidity(
                "Contract Number must be one of: (8)-(6)-(4) | (8)-(7)-(3) | (8)-(7)-(2) | (8)-(7)-(1) | (8)-(7) | (2)-(2)-(2)-(2) digits",
              );
            } else {
              input.setCustomValidity("");
            }
            input.reportValidity();
          }
        }
        break;
      case "accountNumber":
        this.accountNumber = value;
        {
          const input = this.template.querySelector(
            '[data-id="accountNumber"]',
          );
          if (input) {
            const val = value ? value.toString().trim() : "";
            if (!val) {
              // allow empty so user can clear field
              input.setCustomValidity("");
            } else if (!/^\d+$/.test(val)) {
              input.setCustomValidity(
                "Account Number must contain only digits",
              );
            } else if (!(val.length === 16 || val.length === 19)) {
              input.setCustomValidity("Account Number must be 16 or 19 digits");
            } else {
              input.setCustomValidity("");
            }
            input.reportValidity();
          }
        }
        break;
      case "emailAddress":
        this.emailAddress = value;
        {
          const input = this.template.querySelector('[data-id="emailAddress"]');
          if (input) {
            const val = value ? value.toString().trim() : "";
            if (!val) {
              input.setCustomValidity("");
            } else {
              // REMOVED the "\." from the [A-Za-z0-9.\-]+ section in both lines below
              // This forces the structure to strictly follow "text.text" or "text.text.text"
              const oneLevel =
                /^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+\.[A-Za-z]{2,5}$/;
              const twoLevel =
                /^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+\.[A-Za-z]{2,5}\.[A-Za-z]{2,5}$/;

              if (!(oneLevel.test(val) || twoLevel.test(val))) {
                input.setCustomValidity(
                  "Email must be one of (randomString1)@(randomString2).(2-5 chars) or (randomString1)@(randomString2).(2-5 chars).(2-5 chars)",
                );
              } else {
                input.setCustomValidity("");
              }
            }
            input.reportValidity();
          }
        }
        break;
      case "customerNumber":
        this.customerNumber = value;
        break;
      default:
        break;
    }
  }

  handleClear() {
    this.isNoCustomerFound = false;
    this.nationalId = null;
    this.phoneNumber = null;
    this.applicationId = null;
    this.contractNumber = null;
    this.accountNumber = null;
    this.emailAddress = null;
    this.customerNumber = null;

    // Clear input values and error messages (custom validity) on all inputs
    const inputs = this.template.querySelectorAll("lightning-input");
    inputs.forEach((inp) => {
      try {
        // Reset UI value
        inp.value = "";
        // Clear any custom validity messages and refresh validity UI
        inp.setCustomValidity("");
        inp.reportValidity();
      } catch (e) {
        // No-op: some inputs may not support setCustomValidity in edge cases
      }
    });

    // Clear all datasets
    this.cardData = [];
    this.loanData = [];
    this.loanContractData = [];
    this.loanB2Data = [];
    this.loanCash24Data = [];
    this.insuranceData = [];
    this.ubankData = [];
  }

  async handleSearch() {
    // Validate all inputs and ensure at least one search field is provided
    const inputs = this.template.querySelectorAll(
      ".responsive-layout lightning-input",
    );

    // Determine if at least one field has a value
    let hasAnyValue = false;
    inputs.forEach((inp) => {
      const val = (inp.value || "").toString().trim();
      if (val) {
        hasAnyValue = true;
      }
    });

    if (!hasAnyValue) {
      this.showToast(
        "Validation",
        "Enter at least one search criterion.",
        "warning",
      );
      return;
    }

    // Run validity check on each input. If any invalid, show toast and abort
    let allValid = true;
    inputs.forEach((inp) => {
      if (!inp.reportValidity()) {
        allValid = false;
      }
    });
    if (!allValid) {
      this.showToast(
        "Validation",
        "Please correct the highlighted errors before searching.",
        "error",
      );
      return;
    }

    if (this.recordId) {
      try {
        const fields = {};
        fields[CASE_ID_FIELD.fieldApiName] = this.recordId;
        fields[SEARCH_NATIONAL_ID_FIELD.fieldApiName] = this.nationalId;
        fields[SEARCH_PHONE_FIELD.fieldApiName] = this.phoneNumber;
        fields[SEARCH_APP_ID_FIELD.fieldApiName] = this.applicationId;
        fields[SEARCH_CONTRACT_FIELD.fieldApiName] = this.contractNumber;
        fields[SEARCH_ACCOUNT_FIELD.fieldApiName] = this.accountNumber;
        fields[SEARCH_EMAIL_FIELD.fieldApiName] = this.emailAddress;
        fields[SEARCH_CUSTOMER_NUM_FIELD.fieldApiName] = this.customerNumber;

        const recordInput = { fields };
        await updateRecord(recordInput);
      } catch (error) {
        console.error("Failed to sync search criteria to Case record:", error);
        this.showToast(
        FEC_Toast_Error,
        FEC_Toast_Error_Generic + ' ' + (e?.body?.message || e?.message || ""),
        "error"
      );
      }
    }
    //this.seedSampleRows(true);
    this.processSearch() 
  }

  async processSearch() {
    this.isLoaded = false;
    this.isNoCustomerFound = false;


    // Optional: clear old results before new search
    this.cardData = [];
    this.loanData = [];
    this.loanContractData = [];
    this.loanB2Data = [];
    this.loanCash24Data = [];
    this.insuranceData = [];
    this.ubankData = [];

    try {
      const params = this.buildSearchParams();

      // Guard (extra safety). handleSearch() already checks this.
      if (!this.hasAnySearchCriteria(params)) {
        this.showToast(FEC_Toast_Validation_Title, FEC_Toast_Search_Validation, "warning");
        return;
      }
      if (this.contractNumber) {
        const [b2Result, cash24Result] = await Promise.all([
          getB2Contracts({ contractNumber: this.contractNumber }),
          getCash24Contracts({ contractNumber: this.contractNumber })
        ]);

        // 3. Process B2 Data
        this.loanB2Data = b2Result ? b2Result.map(record => ({
          id: record.Id || record.Name,
          ContractNumber: record.Name,
          FullName: record.FEC_Full_Name__c,
          NationalID1: record.FEC_ID_Card__c,
          Code: record.FEC_Code__c,
          ProductCode: record.FEC_Product_Code__c,
          Installment: record.FEC_Installment__c,
          Principal: record.FEC_Principal__c,
          MonthlyFee: record.FEC_Monthly_Fee__c,
          Term: record.FEC_Term__c,
          City: record.FEC_City__c
        })) : [];

        // 4. Process Cash24 Data
        this.loanCash24Data = cash24Result ? cash24Result.map(record => ({
          id: record.Id || record.Name,
          ContractNumber: record.Name,
          SoldDate: record.FEC_Sold_Date__c,
          BalanceAmount: record.FEC_Balance_Amount__c,
          ProductCode: record.FEC_Product__c,
          ContractStatus: record.FEC_Contract_Status__c,
          Note: record.FEC_Note__c
        })) : [];
      }
      const result = await getCustomerList(params);
      console.log("getCustomerList params:", params);
      console.log("getCustomerList result:", result);

      const customers = result?.Customers || [];
      if (this.loanB2Data.length > 0 || this.loanCash24Data.length > 0 || customers.length > 0) {
        this.isNoCustomerFound = false;
        if (customers.length > 0) {
          this.processCustomerResults(customers);
          this.fetchPlasticIds();
          // Gọi Banca Insurance API với danh sách NID từ kết quả (unique, tối đa 20)
          const nidSet = new Set(
            customers
              .map(c => c.NationalID)
              .filter(n => n && n.trim())
          );
          const nids = Array.from(nidSet).slice(0, 20);
          console.log('NIDs for Banca:', nids, 'length:', nids.length);
          if (nids.length > 0) {
            this.fetchBancaInsurance(nids);
          }
        }
      } else {
        this.isNoCustomerFound = true;
      }
    } catch (e) {
      console.error("Error fetching customer list:", e);
      this.showToast(
        FEC_Toast_Error,
        FEC_Toast_Error_Generic + ' ' + (e?.body?.message || e?.message || ""),
        "error"
      );
    } finally {
      this.isLoaded = true;
    }
  }

  async fetchPlasticIds() {
    if (!this.cardData || this.cardData.length === 0) return;
    let tempCardData = this.cardData;
    for (let i = 0; i < tempCardData.length; i++) {
        const card = tempCardData[i];
        
        try {
            const response = await getCardInfoByAccountNumber({ 
                accountNumber: card.AccountNumber 
            });
            card.PlasticID = response?.CardBasicInfo?.MainCard?.PlasticIndicator || "N/A";
        } catch (error) {
            console.error('Lỗi khi lấy Plastic cho thẻ: ' + card.AccountNumber, error);
            card.PlasticID = "Error";
        }
        this.cardData = [...tempCardData];
    }
}

async fetchBancaInsurance(nids) {
    console.log('fetchBancaInsurance called with nids:', nids);
    try {
        const results = await getBancaInsurance({ nationalIds: nids });
        console.log('fetchBancaInsurance results:', results);
        if (!results || results.length === 0) return;
        this.insuranceData = results.map(r => ({
            id: r.paymentID || r.policyNumber,
            UserId: r.userId,
            FullName: r.buyerName,
            DateOfBirth: r.buyerDOB,
            BuyerNID: r.buyerNID,
            MarkedBuyerNID: r.markedBuyerNID,
            ProductName: r.productNameEn,
            PremiumFee: r.collectedPremiumFee,
            PaymentId: r.paymentID,
            EffectiveDate: r.effectiveDate,
            Status: r.statusDisplay,
            PolicyNumber: r.policyNumber,
            InsurerCompany: r.insurerCompany
        }));
    } catch (e) {
        console.error('fetchBancaInsurance error:', e);
    }
}

/**
 * Build Apex params from UI inputs (NO hard-coding).
 * Matches Apex signature: getCustomerList({ requestorId, phoneNumber, ... })
 */
  buildSearchParams() {
    const val = (v) => (v === null || v === undefined ? null : String(v).trim() || null);

    const nationalId = val(this.nationalId);
    const phoneNumber = val(this.phoneNumber);
    const applicationId = val(this.applicationId);
    const contractNumber = val(this.contractNumber);
    const accountNumber = val(this.accountNumber);
    const email = val(this.emailAddress);
    const personId = val(this.customerNumber);
    const fullName = val(this.fullName);

    return {
      // Keep this if required by integration; remove/adjust if your API expects something else.
      requestorId: "PEGA_CSM",

      // Use actual search fields
      phoneNumber,
      fullName,
      nationalId,
      applicationId,
      contractNumber,
      accountNumber,
      email,
      personId,

      // If your backend supports "reference search", set it based on a field like personId/customerNumber.
      // Update logic if your business definition differs.
      isReferenceSearch: personId ? true : false,

      // Keep as null unless you truly have a card number input field
      creditCardNumber: null
    };
  }

/**
 * Validate at least one criteria exists (based on built params).
 */
hasAnySearchCriteria(params) {
  return Boolean(
    params?.phoneNumber ||
      params?.fullName ||
      params?.nationalId ||
      params?.applicationId ||
      params?.contractNumber ||
      params?.accountNumber ||
      params?.email ||
      params?.personId
  );
}

  processCustomerResults(customers) {
    let cardMap = new Map();
    let loanContractMap = new Map();
    let insuranceList = [];

    customers.forEach(cust => {
        if (cust.Applications && cust.Applications.length > 0) {
            cust.Applications.forEach(app => {
                const productCode = app.Product ? app.Product.toUpperCase() : '';
                const phone = (cust.Phones && cust.Phones.length > 0) ? cust.Phones[0].Phone : null;
                const currentNationalId = cust.NationalID || "";

                // NHÓM THEO CARD (AccountNumber)
                if (productCode === '' && app.AccountNumber) {
                    const accNum = app.AccountNumber;
                    if (cardMap.has(accNum)) {
                        let existingRec = cardMap.get(accNum);
                        if (existingRec.NationalID1) {
                            existingRec.NationalID2 = currentNationalId;
                        }
                    } else {
                        cardMap.set(accNum, {
                            id: app.ApplicationID,
                            ApplicationID: app.ApplicationID,
                            FullName: cust.FullName,
                            NationalID1: currentNationalId,
                            NationalID2: "",
                            DateOfBirth: cust.DateOfBirth,
                            AccountNumber: accNum,
                            AccountStatus: app.Status,
                            PlasticID: "Loading...", // Hiển thị trạng thái đang lấy data
                            CIFNumber: cust.CIFNumber,
                            Phone: phone
                        });
                    }
                }
                // NHÓM THEO LOAN (ContractNumber)
                else if (app.ContractNumber) {
                    const contractNum = app.ContractNumber;
                    if (loanContractMap.has(contractNum)) {
                        let existingRec = loanContractMap.get(contractNum);
                        if (existingRec.NationalID1) {
                            existingRec.NationalID2 = currentNationalId;
                        }
                    } else {
                        loanContractMap.set(contractNum, {
                            id: app.ApplicationID,
                            ApplicationID: app.ApplicationID,
                            FullName: cust.FullName,
                            NationalID1: currentNationalId,
                            NationalID2: "",
                            DateOfBirth: cust.DateOfBirth,
                            ContractNumber: contractNum,
                            ProductCode: app.Product,
                            ContractStatus: app.Status,
                            Phone: phone,
                            CIFNumber: cust.CIFNumber
                        });
                    }
                }
                // INSURANCE
                else if (productCode === 'INS' || (app.SchemeDesc && app.SchemeDesc.includes('INSURED'))) {
                    insuranceList.push({
                        id: app.ApplicationID,
                        FullName: cust.FullName,
                        BuyerNID: cust.NationalID,
                        ProductName: app.SchemeDesc || 'Insurance',
                        Status: app.Status,
                        Phone: phone,
                        CIFNumber: cust.CIFNumber
                    });
                }
            });
        }
    });

    this.cardData = Array.from(cardMap.values());
    this.loanContractData = Array.from(loanContractMap.values());
    this.insuranceData = insuranceList;
}


  handleTabChange(event) {
    // lightning-tabset fires 'active' with event.target.value on the tab element
    const tab = event.target;
    if (tab && tab.value) {
      this.activeTabValue = tab.value;
    }
  }

  async handleNewCase() {
    try {
      let input = this.template.querySelector('[data-id="national-id"]');
      if (!input.reportValidity()) {
        this.showToast(
          "Validation",
          "Please correct the highlighted errors before creating.",
          "error"
        );
        return;
      }

      let caseIdToUse = this.recordId;

      if (!caseIdToUse) {
        caseIdToUse = await createInternalCase({
          customerName: this.custNameForCreate,
          nationalId: this.nationalIdForCreate
        });
      }

      this.dispatchEvent(
        new CustomEvent("createsuccess", {
          detail: {
            recordId: caseIdToUse
          },
          bubbles: true,
          composed: true
        })
      );

      this[NavigationMixin.Navigate]({
        type: "standard__component",
        attributes: {
          componentName: "c__fec_InteractionCreateCase",
        },
        state: {
          c__recordId: caseIdToUse,
          c__customerName: this.custNameForCreate,
          c__identityNo: this.nationalIdForCreate,
          c__isCreatedFromSearch: 'true'
        },
      });
    } catch (e) {
      this.showToast("Error", "Failed to create Case.", "error");
    }
  }

  async handleSkip() {
    const result = await SkipModal.open({
      size: "small",
      label: "Skip Search",
      content:
        "Bạn có chắc chắn bỏ qua bước tìm kiếm khách hàng không? Bạn sẽ không thể quay lại tìm kiếm sau khi xác nhận.",
    });

    // Nếu result có giá trị 'confirmed' (do mình định nghĩa ở handleConfirm)
    if (result === "confirm") {
       if (!this.recordId || this.recordId === '') {
           const caseId = await createInternalCaseOnSkip();

            this.showToast("Thông báo", "Skip thành công.", "success");
            this.dispatchEvent(new CustomEvent('skippedwithoutrecord', { bubbles: true, composed: true }));
            this[NavigationMixin.Navigate]({
              type: "standard__recordPage",
              attributes: {
                recordId: caseId,
                objectApiName: "Case",
                actionName: "view",
              },
            });
            return;
        }
      this.isLoaded = false;
      const fields = {};
      fields["Id"] = this.recordId;
      fields["FEC_Skip_Search_Internal_Case__c"] = true;

      const recordInput = { fields };

      try {
        // Bước 1: Cập nhật bản ghi xuống Database
        await updateRecord(recordInput);

        // Bước 2: ĐẶT TẠI ĐÂY - Thông báo cho UI làm mới dữ liệu
        //await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        await refreshApex(this.wiredCaseResult);

        this.showToast("Thành công", "Case đã được cập nhật.", "success");
      } catch (error) {
        this.showToast("Lỗi", error.body.message, "error");
      } finally {
        this.isLoaded = true;
      }
    }
  }

  handleCustNameChange(event) {
    this.custNameForCreate = event.target.value;
  }

  handleNationalIdChange(event) {
    const input = event.target;
    const value = input.value?.trim();

    this.nationalIdForCreate = value;

    input.setCustomValidity("");

    if (value && value.length !== 9 && value.length !== 12) {
      input.setCustomValidity(
        "National ID must be exactly 9 or 12 characters.",
      );
    }

    input.reportValidity();
  }

  get isNewCaseDisabled() {
    return !this.custNameForCreate;
  }

  validateNewCaseFields() {

  }

  // Shared toast helper with de-duplication by title+message+variant signature
  showToast(title, msg, type) {
    Toast.show(
      {
        label: title,
        message: msg,
        mode: "dismissible",
        variant: type,
      },
      this,
    );
  }

  // Double-click on link in custom table → toggle Application History only (no case/history creation)
  handleDblClickRow(event) {
    event.stopPropagation();
    const key = event.currentTarget.dataset.key;
    const fieldName = event.currentTarget.dataset.field;
    if (!key || !fieldName) return;
    this._toggleHistory(key, fieldName);
  }

  // Single click on Account/Contract Number → toggle Application History only
  handleSingleClickRow(event) {
    event.stopPropagation();
    const key = event.currentTarget.dataset.key;
    const fieldName = event.currentTarget.dataset.field;
    if (!key || !fieldName) return;
    this._toggleHistory(key, fieldName);
  }

  // Single click on Account/Contract Number → open Application History modal
  handleDblClick(event) {
    const { value, fieldName } = event.detail || {};
    if (!value) return;
    this._toggleHistory(value, fieldName);
  }

  _openHistoryModal(key, fieldName) {
    let applicationId = null;
    if (fieldName === 'AccountNumber') {
      const row = this.cardData.find(r => r.AccountNumber === key);
      applicationId = row?.ApplicationID;
    } else if (fieldName === 'ContractNumber') {
      const row = this.loanContractData.find(r => r.ContractNumber === key);
      applicationId = row?.ApplicationID;
    }
    if (!applicationId) return;

    this.historyModalKey = key;
    this.historyModalRows = [];
    this.historyModalLoading = true;

    getApplicationHistory({ applicationId })
      .then(rows => {
        this.historyModalRows = rows || [];
        this.historyModalLoading = false;
      })
      .catch(() => {
        this.historyModalRows = [];
        this.historyModalLoading = false;
      });
  }

  // Handle click from custom table toggle button or link
  handleToggleHistory(event) {
    const key = event.currentTarget.dataset.key;
    const fieldName = event.currentTarget.dataset.field;
    if (!key) return;
    this._toggleHistory(key, fieldName);
  }

  _toggleHistory(key, fieldName) {
    // Find applicationId
    let applicationId = null;
    if (fieldName === 'AccountNumber') {
      const row = this.cardData.find(r => r.AccountNumber === key);
      applicationId = row?.ApplicationID;
    } else if (fieldName === 'ContractNumber') {
      const row = this.loanContractData.find(r => r.ContractNumber === key);
      applicationId = row?.ApplicationID;
    }
    if (!applicationId) return;

    const current = this.appHistoryMap[key] || {};

    // Toggle collapse
    if (current.expanded) {
      this.appHistoryMap = { ...this.appHistoryMap, [key]: { ...current, expanded: false } };
      this._refreshData();
      return;
    }

    // Already loaded → just expand
    if (current.rows) {
      this.appHistoryMap = { ...this.appHistoryMap, [key]: { ...current, expanded: true } };
      this._refreshData();
      return;
    }

    // Load from API
    this.appHistoryMap = { ...this.appHistoryMap, [key]: { loading: true, expanded: true, rows: null } };
    this._refreshData();

    getApplicationHistory({ applicationId })
      .then(rows => {
        this.appHistoryMap = { ...this.appHistoryMap, [key]: { loading: false, expanded: true, rows: rows || [] } };
        this._refreshData();
      })
      .catch(() => {
        this.appHistoryMap = { ...this.appHistoryMap, [key]: { loading: false, expanded: true, rows: [] } };
        this._refreshData();
      });
  }

  // Force LWC reactivity for appHistoryMap
  _refreshData() {
    this.cardData = this.cardData.map(r => ({
      ...r,
      _isExpanded: !!(this.appHistoryMap[r.AccountNumber]?.expanded)
    }));
    this.loanContractData = this.loanContractData.map(r => ({
      ...r,
      _isExpanded: !!(this.appHistoryMap[r.ContractNumber]?.expanded)
    }));
  }
  get cardDataWithHistory() {
    return this.cardData.map(r => ({
      ...r,
      _historyState: this.appHistoryMap[r.AccountNumber] || null,
      _btnClass: (this.appHistoryMap[r.AccountNumber]?.expanded) ? 'fec-toggle-btn fec-expanded' : 'fec-toggle-btn',
      _dateOfBirth: this._formatDate(r.DateOfBirth)
    }));
  }

  get loanContractDataWithHistory() {
    return this.loanContractData.map(r => ({
      ...r,
      _historyState: this.appHistoryMap[r.ContractNumber] || null,
      _btnClass: (this.appHistoryMap[r.ContractNumber]?.expanded) ? 'fec-toggle-btn fec-expanded' : 'fec-toggle-btn',
      _dateOfBirth: this._formatDate(r.DateOfBirth)
    }));
  }

  _formatDate(dateStr) {
    if (!dateStr) return '';
    // Handle YYYY-MM-DD format
    const parts = dateStr.split('-');
    if (parts.length === 3) return `${parts[2]}/${parts[1]}/${parts[0]}`;
    return dateStr;
  }

  // Returns interleaved array: each data row followed by its history row (if expanded)
  // Used for Account/Contract Search to render history inline
  get cardRowsInterleaved() {
    const result = [];
    this.cardData.forEach(r => {
      result.push({ ...r, _isDataRow: true, _key: 'data_' + r.AccountNumber, _singleRow: [r] });
      const hs = this.appHistoryMap[r.AccountNumber];
      if (hs && hs.expanded) {
        result.push({ _isDataRow: false, _key: 'hist_' + r.AccountNumber, _historyState: hs });
      }
    });
    return result;
  }

  get loanRowsInterleaved() {
    const result = [];
    this.loanContractData.forEach(r => {
      result.push({ ...r, _isDataRow: true, _key: 'data_' + r.ContractNumber, _singleRow: [r] });
      const hs = this.appHistoryMap[r.ContractNumber];
      if (hs && hs.expanded) {
        result.push({ _isDataRow: false, _key: 'hist_' + r.ContractNumber, _historyState: hs });
      }
    });
    return result;
  }

  // Handle button actions from datatable rows
  handleRowAction(event) {
    console.log("Row action event:", event);
    let { action, row } = event.detail || {};
    if (!action || !action.name) {
      return;
    }
    let id = row;
    console.log('Row JSON yy1:', JSON.stringify(row, null, 2));
    if (action.name == "create_history") {
      switch (action.label.fieldName) {
        case "AccountNumber":
          row = this.cardData.find(r => r.AccountNumber == row);
          break;
        case "ContractNumber":
          row = this.loanContractData.find(r => r.ContractNumber == row);
          break;
        case "UserId":
          row = this.insuranceData.find(r => r.UserId == row);
          break;
      }
    } 
    const cifNumber = row?.CIFNumber ?? '';
    console.log('cifNumber ', cifNumber );
    
    switch (action.name) {
      case "create_history": {
        if (!this.recordId) {
          this.dispatchEvent(
            new CustomEvent("rowselected", {
              detail: {
                fullName: row?.FullName || "",
                nationalId: row?.AccountNumber || row?.ContractNumber || "",
                cifNumber: cifNumber
              },
              bubbles: true,
              composed: true,
            }),
          );

        }
        let categories = [];

        // 1. Check Card data
        if (this.cardData && this.cardData.length > 0) {
          categories.push("Card");
        }

        // 2. Check Loan data (If ANY of the three have records)
        if (
          (this.loanContractData && this.loanContractData.length > 0) ||
          (this.loanB2Data && this.loanB2Data.length > 0) ||
          (this.loanCash24Data && this.loanCash24Data.length > 0)
        ) {
          categories.push("Loan");
        }

        // 3. Check Insurance data
        if (this.insuranceData && this.insuranceData.length > 0) {
          categories.push("Insurance");
        }

        // Combine them into a string (e.g., "Card, Loan, Insurance")
        let searchProducts = categories.join(";");
        this.isLoaded = false;
        createHistory({
          value: id,
          fieldName: action.label.fieldName,
          caseId: this.recordId,
          searchProducts: searchProducts,
          selectedType: action.type,
          cifNumber: cifNumber,
          phone: row?.Phone,
          customerName: row?.FullName,
          isListView: !this.recordId
        })
          .then(async (res) => {
            // const payload = {
            //     isModeEdit: true
            // };
            this.showToast(
              "Success",
              "History created successfully",
              "success",
            );
            if (this.recordId) {
                //publish(this.messageContext, IS_MODE_EDIT, payload);
                this.handlePublishMessageChanel();
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
                // await refreshApex(this.wiredCaseResult);
                this.dispatchEvent(new RefreshEvent());
            } else {
                this.dispatchEvent(
                  new CustomEvent('closerequest', {
                    bubbles: true,
                    composed: true
                  })
                );
              this[NavigationMixin.Navigate]({
                type: "standard__recordPage",
                attributes: {
                  recordId: res,
                  objectApiName: "Case",
                  actionName: "view",
                },
              });
            }
            //await this.refreshTab();
          })
          .catch((e) => {
            this.showToast("Error", "Failed to create history", "error");
          })
          .finally(() => {
            this.isLoaded = true;
          });
        break;
      }
      default:
        break;
    }
  }

  get isDisplayCreateCase() {
    return this.isNoCustomerFound && (this.recordId || this.isListView || this.isCreateCaseTab);
  }

  // Sorting helpers if you want per-table sorting in future (optional)
  onSorting(event) {
    const { fieldName, sortDirection } = event.detail;
    const tab = this.activeTabValue;
    if (tab === "Accounts") {
      this.accountsData = this.sortData(
        this.accountsData,
        fieldName,
        sortDirection,
      );
    } else if (tab === "Contacts") {
      this.contactsData = this.sortData(
        this.contactsData,
        fieldName,
        sortDirection,
      );
    } else if (tab === "Cases") {
      this.casesData = this.sortData(this.casesData, fieldName, sortDirection);
    } else if (tab === "Opportunities") {
      this.oppsData = this.sortData(this.oppsData, fieldName, sortDirection);
    }
  }

  sortData(data, fieldname, direction) {
    const clone = JSON.parse(JSON.stringify(data || []));
    const isReverse = direction === "asc" ? 1 : -1;
    clone.sort((a, b) => {
      const x = a[fieldname] ?? "";
      const y = b[fieldname] ?? "";
      return isReverse * ((x > y) - (y > x));
    });
    return clone;
  }

  // Demo data seeding
  seedSampleRows(force = false) {
    if (this.emailAddress == "a@a.aa") {
      this.isNoCustomerFound = true;
      this.cardData = [];
      this.loanContractData = [];
      this.loanB2Data = [];
      this.loanCash24Data = [];
      this.insuranceData = [];
      this.ubankData = [];
      return;
    } else {
      this.isNoCustomerFound = false;
    }
    // CARD
    if (force || this.cardData?.length === 0) {
      this.cardData = [
        {
          id: "card1",
          FullName: "NGUYEN VAN A",
          NationalID1: "062789144",
          NationalID2: "230444789",
          DateOfBirth: "1990-01-15",
          PlasticID: "DC8",
          AccountStatus: "A",
          AccountNumber: "0001500040006525520",
          FieldName: "AccountNumber",
        },
        {
          id: "card2",
          FullName: "TRAN THI B",
          NationalID1: "024567777",
          NationalID2: "",
          DateOfBirth: "1987-06-20",
          PlasticID: "AB3",
          AccountStatus: "9",
          AccountNumber: "0001500049876501245",
          FieldName: "AccountNumber",
        },
      ];
    }

    // LOAN - Contract
    if (force || this.loanContractData?.length === 0) {
      this.loanContractData = [
        {
          id: "lcon1",
          FullName: "NGUYEN VAN A",
          NationalID1: "062789666",
          NationalID2: "230999789",
          DateOfBirth: "1990-01-01",
          ProductCode: "CDL",
          ContractStatus: "Active",
          ContractNumber: "20240318-0915427",
        },
        {
          id: "lcon2",
          FullName: "PHAM THU C",
          NationalID1: "098345777",
          NationalID2: "",
          DateOfBirth: "1985-09-12",
          ProductCode: "MCL",
          ContractStatus: "Closed",
          ContractNumber: "20230711-1745620",
        },
      ];
    }

    // LOAN - B2
    if (force || this.loanB2Data?.length === 0) {
      this.loanB2Data = [
        {
          id: "lb2_1",
          FullName: "TRAN THI B",
          NationalID1: "024567444",
          Code: "B2-001",
          ProductCode: "B2P",
          Installment: "1,200,000",
          Principal: "20,000,000",
          MonthlyFee: "50,000",
          Term: "24",
          City: "Hanoi",
          ContractNumber: "20230711-1745620",
        },
        {
          id: "lb2_2",
          FullName: "LE QUANG D",
          NationalID1: "023456666",
          Code: "B2-002",
          ProductCode: "B2P",
          Installment: "950,000",
          Principal: "15,000,000",
          MonthlyFee: "45,000",
          Term: "18",
          City: "Da Nang",
          ContractNumber: "20230711-1745620",
        },
      ];
    }

    // LOAN - Cash24
    if (force || this.loanCash24Data?.length === 0) {
      this.loanCash24Data = [
        {
          id: "lc24_1",
          FullName: "NGUYEN VAN A",
          SoldDate: "2024-08-10",
          BalanceAmount: "12,500,000",
          ProductCode: "C24",
          ContractStatus: "Sold",
          Note: "Transferred to partner",
          ContractNumber: "20230711-1745620",
        },
        {
          id: "lc24_2",
          FullName: "TRAN THI B",
          SoldDate: "2023-12-05",
          BalanceAmount: "8,200,000",
          ProductCode: "C24",
          ContractStatus: "Closed",
          Note: "Paid off",
          ContractNumber: "20230711-1745620",
        },
      ];
    }

    // INSURANCE
    if (force || this.insuranceData?.length === 0) {
      this.insuranceData = [
        {
          id: "ins1",
          UserId: "23456789",
          FullName: "NGUYEN VAN A",
          DateOfBirth: "1990-01-01",
          BuyerNID: "062789888321",
          ProductName: "Single Health",
          PremiumFee: 800000,
          PaymentId: "IZI00012345",
          EffectiveDate: "2024-01-01",
          Status: "Còn hiệu lực",
        },
        {
          id: "ins2",
          UserId: "98765432",
          FullName: "LE QUANG D",
          DateOfBirth: "1988-03-27",
          BuyerNID: "023456777210",
          ProductName: "Family Care",
          PremiumFee: 1250000,
          PaymentId: "IZI00056789",
          EffectiveDate: "2023-02-15",
          Status: "Hết hiệu lực",
        },
      ];
    }
  }

  async handlePublishMessageChanel() {
    const payload = {
      isModeEdit: true,
    };
    publish(this.messageContext, IS_MODE_EDIT_INTERACTION, payload);
  }
}
