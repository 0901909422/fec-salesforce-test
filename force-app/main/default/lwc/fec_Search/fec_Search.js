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
import searchByListNIDs from "@salesforce/apex/FEC_SearchByListNIDsServiceCallout.searchByListNIDs";
import getCash24Contracts from "@salesforce/apex/FEC_SearchController.getCash24Contracts";
import getCustomerList from "@salesforce/apex/FEC_GetCustomerList.getCustomerList";
import searchByListPhones from "@salesforce/apex/FEC_SearchByListPhonesServiceCallout.searchByListPhones";

import FEC_National_ID_Passport_ID_Label  from '@salesforce/label/c.FEC_National_ID_Passport_ID_Label';
import FEC_Toast_Search_Validation from '@salesforce/label/c.FEC_Toast_Search_Validation';
import FEC_Toast_Validation_Title from '@salesforce/label/c.FEC_Toast_Validation_Title';
import FEC_Toast_Refresh_Success from '@salesforce/label/c.FEC_Toast_Refresh_Success';
import FEC_Toast_Error from '@salesforce/label/c.FEC_Toast_Error';
import FEC_Toast_Error_Generic from '@salesforce/label/c.FEC_Toast_Error_Generic';
import FEC_MSG_Create_Customer_History_Error from '@salesforce/label/c.FEC_MSG_Create_Customer_History_Error';
import FEC_MSG_Create_Customer_History_Success from '@salesforce/label/c.FEC_MSG_Create_Customer_History_Success';
import FEC_Error_Callout_Insurance from '@salesforce/label/c.FEC_Error_Callout_Insurance';
import FEC_MSG_Service_Error_Label from '@salesforce/label/c.FEC_MSG_Service_Error_Label';
import FEC_Common_No_Results_Label from '@salesforce/label/c.FEC_Common_No_Results_Label';

import checkFieldEditPermissions from "@salesforce/apex/FEC_SearchController.checkFieldEditPermissions";
import SkipModal from "c/fec_SkipModal";
import createInternalCase from "@salesforce/apex/FEC_CreateCaseHandler.createInternalCase";
import createInternalCaseOnSkip from "@salesforce/apex/FEC_SearchController.createInternalCaseOnSkip";
import getHistoryStatus from '@salesforce/apex/FEC_SearchController.getHistoryStatus';
import getCaseRecordTypeDevName from "@salesforce/apex/FEC_CreateCaseHandler.getCaseRecordTypeDevName";
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
import { formatDateFlexibleVN } from "c/fec_CommonUtils";
import SEARCH_PHONE_FIELD from "@salesforce/schema/Case.FEC_Search_Phone_Number__c";
import SEARCH_APP_ID_FIELD from "@salesforce/schema/Case.FEC_Search_Application_ID__c";
import SEARCH_CONTRACT_FIELD from "@salesforce/schema/Case.FEC_Search_Contract_Number__c";
import SEARCH_ACCOUNT_FIELD from "@salesforce/schema/Case.FEC_Search_Account_Number__c";
import SEARCH_EMAIL_FIELD from "@salesforce/schema/Case.FEC_Search_Email_Address__c";
import SEARCH_CUSTOMER_NUM_FIELD from "@salesforce/schema/Case.FEC_Search_Customer_Number__c";
import { CurrentPageReference } from 'lightning/navigation';
import { formatDateTimeVNShort, normalizePhone } from 'c/fec_CommonUtils';

const FIELDS_TO_CHECK = [
    'FEC_Search_National_ID__c',
    'FEC_Search_Phone_Number__c',
    'FEC_Search_Application_ID__c',
    'FEC_Search_Contract_Number__c',
    'FEC_Search_Account_Number__c',
    'FEC_Search_Email_Address__c',
    'FEC_Search_Customer_Number__c'
];

const FEC_TEST_API_SERVICE_ERROR_ACCOUNT = "0001500010000005555";

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
  isTestApiCase = false;
  isSearchServiceError = false;
  // linhdev: Fix jira FECREDIT_CSM_2025_KH-1243
  caseRecordTypeName;
  wiredCaseResult;
  fieldPermissions;
  errorCalloutIsurance;
  _customers = [];

  FEC_Toast_Search_Validation = FEC_Toast_Search_Validation;
  FEC_Toast_Validation_Title = FEC_Toast_Validation_Title;
  FEC_Toast_Error = FEC_Toast_Error;
  FEC_Toast_Error_Generic = FEC_Toast_Error_Generic;
  FEC_National_ID_Passport_ID_Label = FEC_National_ID_Passport_ID_Label;
  FEC_MSG_Create_Customer_History_Error = FEC_MSG_Create_Customer_History_Error;
  FEC_MSG_Create_Customer_History_Success = FEC_MSG_Create_Customer_History_Success;
  FEC_Toast_Refresh_Success = FEC_Toast_Refresh_Success;
  FEC_Common_No_Results_Label = FEC_Common_No_Results_Label;

  labels = {
    errorCalloutInsuranceMsg: FEC_Error_Callout_Insurance,
    errorApiMessage: FEC_MSG_Service_Error_Label
  }

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
        type: "text", 
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
        type: "text", 
        sortable: true },
      { label: "Product Code", fieldName: "ProductCode", sortable: true },
      ...(this.isAccountContractSearch ? [{ label: "Application ID", fieldName: "ApplicationID", sortable: true }] : []),
      { label: "Contract Status", fieldName: "ContractStatus", sortable: true },
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
        type: "text", 
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
        type: "text", 
        sortable: true },
      {
        label: "Buyer NID",
        fieldName: "BuyerNID",
        type: "maskedToggle",
        sortable: true,
        typeAttributes:  {
              caseId: this.recordId,
              fieldLabel: "Buyer NID"
            },
      },
      { label: "Product Name", fieldName: "ProductName", sortable: true },
      {
        label: "Premium Fee",
        fieldName: "PremiumFee",
        type: "number",
        typeAttributes: {
          minimumFractionDigits: 0,
          maximumFractionDigits: 0
        },
        sortable: true,
      },
      { label: "Payment ID", fieldName: "PaymentId", sortable: true },
      {
        label: "Effective Date",
        fieldName: "EffectiveDate",
        type: "text", 
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
      { label: "Date of Birth", fieldName: "DateOfBirth", type: "text", sortable: true },
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

  get hasIsuranceData() {
    return this.insuranceData && this.insuranceData?.length > 0;
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
      // linhdev: Fix jira FECREDIT_CSM_2025_KH-1243
      this.caseRecordTypeName = data?.RecordType?.Name;
      this.isTestApiCase = data?.FEC_Is_Test_API__c === true;
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
      // linhdev: Fix jira FECREDIT_CSM_2025_KH-1243
      this.caseRecordTypeName = result?.RecordType?.Name;
      this.isTestApiCase = result?.FEC_Is_Test_API__c === true;
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
    this.isSearchServiceError = false;
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

  _isSimulatedTestApiServiceErrorSearch() {
    if (!this.isTestApiCase) {
      return false;
    }
    const acc =
      this.accountNumber != null && this.accountNumber !== undefined
        ? String(this.accountNumber).trim()
        : "";
    return acc === FEC_TEST_API_SERVICE_ERROR_ACCOUNT;
  }

  async processSearch() {
    this.isLoaded = false;
    this.isNoCustomerFound = false;
    this.isSearchServiceError = false;

    // reset data
    this.cardData = [];
    this.loanData = [];
    this.loanContractData = [];
    this.loanB2Data = [];
    this.loanCash24Data = [];
    this.insuranceData = [];
    this.ubankData = [];

    try {
      const params = this.buildSearchParams();

      if (!this.hasAnySearchCriteria(params)) {
        this.showToast(
          FEC_Toast_Validation_Title,
          FEC_Toast_Search_Validation,
          "warning"
        );
        return;
      }

      const promises = [];

      // 1. Loan APIs
      if (this.contractNumber) {
        promises.push(
          Promise.all([
            getB2Contracts({ contractNumber: this.contractNumber }),
            getCash24Contracts({ contractNumber: this.contractNumber })
          ])
        );
      } else {
        promises.push(Promise.resolve([[], []]));
      }

      // 2. Customer API (API 20)
      promises.push(getCustomerList(params));

      // [CHANGE][Author : LongNH76] Insurance gọi song song API 88/90 để không bỏ sót kết quả khi user nhập cả NID + Phone.
      // UAT: phone -> API 20 + 90; NID -> API 20 + 88; both -> 20 + 88 + 90.
      // Old behavior (kept for reference):
      // - Chỉ gọi 1 API insurance theo nhánh if/else (NID hoặc Phone), không gọi song song.
      // if (this.nationalId) {
      //   promises.push(this.fetchBancaInsurance([this.nationalId]));
      // } else if (this.phoneNumber) {
      //   promises.push(this.fetchBancaInsuranceByPhone([this.phoneNumber]));
      // } else {
      //   promises.push(Promise.resolve([]));
      // }
      const insurancePromises = [];
      if (this.nationalId) {
        insurancePromises.push(this.fetchBancaInsurance([this.nationalId]));
      }
      if (this.phoneNumber) {
        const normalizedPhone = normalizePhone(this.phoneNumber);
        insurancePromises.push(this.fetchBancaInsuranceByPhone([normalizedPhone]));
      }
      if (insurancePromises.length === 0) {
        insurancePromises.push(Promise.resolve([]));
      }
      promises.push(Promise.all(insurancePromises));

      const [
        [b2Result, cash24Result],
        customerResult,
        insuranceResults
      ] = await Promise.all(promises);

      // =========================
      // MAP LOAN DATA
      // =========================
      this.loanB2Data = (b2Result || []).map(r => ({
        id: r.Id || r.Name,
        ContractNumber: r.Name,
        FullName: r.FEC_Full_Name__c,
        NationalID1: r.FEC_ID_Card__c,
        Code: r.FEC_Code__c,
        ProductCode: r.FEC_Product_Code__c,
        Installment: r.FEC_Installment__c,
        Principal: r.FEC_Principal__c,
        MonthlyFee: r.FEC_Monthly_Fee__c,
        Term: r.FEC_Term__c,
        City: r.FEC_City__c
      }));

      this.loanCash24Data = (cash24Result || []).map(r => ({
        id: r.Id || r.Name,
        ContractNumber: r.Name,
        SoldDate: r.FEC_Sold_Date__c,
        BalanceAmount: r.FEC_Balance_Amount__c,
        ProductCode: r.FEC_Product__c,
        ContractStatus: r.FEC_Contract_Status__c,
        Note: r.FEC_Note__c
      }));

      const customers = customerResult?.Customers || [];
      this._customers = customers;

      if (customers.length > 0) {
        this.processCustomerResults(customers);
      }

      // [CHANGE][Author : LongNH76] Merge + dedupe kết quả insurance từ nhiều API.
      // Old behavior (kept for reference):
      // this.insuranceData = insuranceResult || [];
      const mergedInsurance = (insuranceResults || []).flat();
      this.insuranceData = this.mergeInsuranceRows(mergedInsurance);

      // =========================
      const hasAnyData =
        this.cardData.length > 0 ||
        this.loanContractData.length > 0 ||
        this.loanB2Data.length > 0 ||
        this.loanCash24Data.length > 0 ||
        this.insuranceData.length > 0;

      if (this._isSimulatedTestApiServiceErrorSearch()) {
        this.cardData = [];
        this.loanData = [];
        this.loanContractData = [];
        this.loanB2Data = [];
        this.loanCash24Data = [];
        this.insuranceData = [];
        this.ubankData = [];
        this._customers = [];
        this.isSearchServiceError = true;
        this.isNoCustomerFound = true;
      } else {
        this.isSearchServiceError = false;
        this.isNoCustomerFound = !hasAnyData;
      }

    } catch (e) {
      console.error("Error fetching data:", e);

      this.showToast(
        FEC_Toast_Error,
        FEC_Toast_Error_Generic + " " + (e?.body?.message || e?.message || ""),
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

async fetchBancaInsurance(ids) {
  try {

    const result = await searchByListNIDs({ nationalIDs: ids });
    if (!result?.sys || result.sys.code !== 1) {
      this.insuranceData = [];
      return [];
    }

    const items = (result.result || []).map(el => ({
      id: el.userID,
      UserId: el.userID,
      FullName: el.buyerName,
      BuyerNID: el.buyerNID,
      DateOfBirth: el.buyerDOB,
      ProductName: el.productNameEn,
      PremiumFee: Number(el.collectedPremiumFee),
      PaymentId: el.paymentID,
      EffectiveDate: el.effectiveDate,
      Status: el.StatusDisplay,
      PolicyNumber: el.policyNumber,
      Phone: el.buyerPhone
    }));

    this.insuranceData = items;
    return items;

  } catch (e) {
    this.insuranceData = [];
    return [];
  }
}

async fetchBancaInsuranceByPhone(phones) {
  try {

    const result = await searchByListPhones({ phones });

    // [CHANGE][Author : LongNH76] Align theo source user cung cấp:
    // ưu tiên đọc payload result trực tiếp thay vì chặn cứng theo sys2.code2.
    // Old behavior (kept for reference):
    // if (!result?.sys2 || result.sys2.code2 !== '200') {
    //   return [];
    // }
    if (!result?.result || result.result.length === 0) {
      return [];
    }

    const items = (result.result || []).map(el => ({
      id: el.userID,
      UserId: el.userID,
      FullName: el.buyerName,
      BuyerNID: el.buyerNID,
      DateOfBirth: el.buyerDOB,
      ProductName: el.productNameEn,
      PremiumFee: Number(el.collectedPremiumFee),
      PaymentId: el.paymentID,
      EffectiveDate: el.effectiveDate,
      Status: el.statusDisplay,
      PolicyNumber: el.policyNumber,
      Phone: el.buyerPhone
    }));

    this.insuranceData = items;
    return items;

  } catch (e) {
    return [];
  }
}

  /**
   * [CHANGE][Author : LongNH76] Dedupe insurance rows theo PolicyNumber/UserId.
   * Nếu cùng key từ API 88 và 90, ưu tiên bản có buyerPhone để không mất nguồn phone khi tạo History/Case.
   * Old behavior (kept for reference):
   * - Không có bước merge/dedupe riêng, lấy trực tiếp insuranceResult từ 1 API branch.
   */
  mergeInsuranceRows(rows) {
    const map = new Map();
    (rows || []).forEach((item) => {
      const key = item.PolicyNumber || item.UserId;
      if (!key) {
        return;
      }
      const existing = map.get(key);
      if (!existing) {
        map.set(key, item);
        return;
      }
      map.set(key, this.preferInsuranceRow(existing, item));
    });
    return Array.from(map.values());
  }


  preferInsuranceRow(a, b) {
    const phoneA = a?.Phone && String(a.Phone).trim();
    const phoneB = b?.Phone && String(b.Phone).trim();
    if (phoneB && !phoneA) {
      return b;
    }
    if (phoneA && !phoneB) {
      return a;
    }
    return a;
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
                            DateOfBirth: formatDateFlexibleVN(cust.DateOfBirth),
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
                            DateOfBirth: formatDateFlexibleVN(cust.DateOfBirth),
                            ContractNumber: contractNum,
                            ProductCode: app.Product,
                            ContractStatus: app.Status,
                            Phone: phone,
                            CIFNumber: cust.CIFNumber
                        });
                    }
                }
                // INSURANCE
                // else if (productCode === 'INS' || (app.SchemeDesc && app.SchemeDesc.includes('INSURED'))) {
                //     insuranceList.push({
                //         id: app.ApplicationID,
                //         FullName: cust.FullName,
                //         BuyerNID: cust.NationalID,
                //         ProductName: app.SchemeDesc || 'Insurance',
                //         Status: app.Status,
                //         Phone: phone,
                //         CIFNumber: cust.CIFNumber
                //     });
                // }
            });
        }
    });

    this.cardData = Array.from(cardMap.values());
    this.loanContractData = Array.from(loanContractMap.values());
    // this.insuranceData = insuranceList;
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

      const devName = await getCaseRecordTypeDevName({
        caseId: caseIdToUse
      });

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
          c__isCreatedFromSearch: 'true',
          c__recordTypeDevName: devName
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
      this.isLoaded = false;
      if (!this.recordId || this.recordId === '') {
        createInternalCaseOnSkip()
          .then(async (caseId) => {
            this.dispatchEvent(new CustomEvent('skippedwithoutrecord', { 
              detail: {
                recordId: caseId
              }
             }));
            this.showToast("Thành công", "Tạo Internal Case thành công", "success");
          })
          .catch((error) => {
            this.showToast("Lỗi", error.body.message, "error");
          })
          .finally(() => {
            this.isLoaded = true;
          })
        
        return; 
      }
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

  handleInsuranceDblClick() {
    console.log('>>>handleInsuranceDblClick')
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
        this.historyModalRows = (rows || []).map(h => ({ ...h, editDate: formatDateTimeVNShort(h.editDate) }));
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
        this.appHistoryMap = { ...this.appHistoryMap, [key]: { loading: false, expanded: true, rows: (rows || []).map(h => ({ ...h, editDate: formatDateTimeVNShort(h.editDate) })) } };
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
      _dateOfBirth: formatDateFlexibleVN(r.DateOfBirth)
    }));
  }

  get loanContractDataWithHistory() {
    return this.loanContractData.map(r => ({
      ...r,
      _historyState: this.appHistoryMap[r.ContractNumber] || null,
      _btnClass: (this.appHistoryMap[r.ContractNumber]?.expanded) ? 'fec-toggle-btn fec-expanded' : 'fec-toggle-btn',
      _dateOfBirth: formatDateFlexibleVN(r.DateOfBirth)
    }));
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

    let id;
    // Resolve full row object and identifier string
    if (typeof row === 'string') {
      id = row;
      const type = action.type;
      let foundRow;
      if (type === 'Card') {
        foundRow = this.cardData.find(r => r.AccountNumber === id);
      } else if (type === 'Loan') {
        foundRow = this.loanContractData.find(r => r.ContractNumber === id) || 
                   this.loanB2Data.find(r => r.ContractNumber === id) || 
                   this.loanCash24Data.find(r => r.ContractNumber === id);
      } else if (type === 'Insurance') {
        foundRow = this.insuranceData.find(r => r.UserId === id);
      }
      if (foundRow) row = foundRow;
    } else {
      id = row?.AccountNumber || row?.ContractNumber || row?.UserId || row?.id;
    }

    let cifNumber = row?.CIFNumber ?? '';
    
    switch (action.name) {
      case "create_history": {
        if (!this.recordId) {
          this.dispatchEvent(
            new CustomEvent("rowselected", {
              detail: {
                fullName: row?.FullName || "",
                nationalId: id || "",
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
        let customerName = row?.FullName;
        let isListView = !this.recordId;
        if (action.label.fieldName === 'UserId') {
          if (categories.includes("Card") || categories.includes("Loan")) {
            this.isLoaded = true;
            return;
          }
          const customerIndex = this._customers.findIndex(
            (x) => x.NationalID === row?.BuyerNID
          );
          cifNumber = this._customers[customerIndex]
            ? this._customers[customerIndex].CIFNumber
            : "";
          if (
            this._customers[customerIndex] &&
            this._customers[customerIndex].FullName
          ) {
            customerName = this._customers[customerIndex].FullName;
          }
          // Align isListView for Insurance search tab to ensure Internal Case and navigation
          isListView = !this.recordId;
        }

        const resolvedPhone = (this.phoneNumber && normalizePhone(this.phoneNumber)) || null;

        createHistory({
          value: id,
          fieldName: action.label.fieldName,
          caseId: this.recordId,
          searchProducts: searchProducts,
          selectedType: action.type,
          cifNumber: cifNumber,
          phone: resolvedPhone,
          customerName: customerName,
          applicationId: row?.ApplicationID,
          isListView: isListView,
          policyNumber: row?.PolicyNumber || '', // Only for Insurance
          buyerNID: (this.nationalId && String(this.nationalId).trim()) || '',
        })
          .then(async (res) => {
            this.showToast("Success", "History created successfully", "success");
            
            if (this.recordId) {
                this.handlePublishMessageChanel();
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
                this.dispatchEvent(new RefreshEvent());
            } else {
                const devName = await getCaseRecordTypeDevName({ caseId: res });
                if (devName === 'Internal_Case') {
                    this.dispatchEvent(
                        new CustomEvent('closerequest', {
                            detail: { recordId: res }
                        })
                    );
                  } else {
                      this[NavigationMixin.Navigate]({
                          type: "standard__recordPage",
                          attributes: {
                              recordId: res,
                              objectApiName: "Case",
                              actionName: "view"
                          }
                      });
                  }
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

  async _pollHistoryReady(caseId) {
      const MAX_ATTEMPTS = 4;
      const INTERVAL_MS  = 1000;

      let historyId = await this._getHistoryIdFromCase(caseId);
      if (!historyId) return; 

      for (let i = 0; i < MAX_ATTEMPTS; i++) {
          await new Promise(resolve => setTimeout(resolve, INTERVAL_MS));

          try {
              const status = await getHistoryStatus({ historyId });
              if (status?.isReady) {
                  return;
              }
          } catch (e) {
              console.error('Polling error:', e);
              return; 
          }
      }
      console.warn('Polling timeout, refreshing anyway.');
  }

  async _getHistoryIdFromCase(caseId) {
    try {
        const result = await getCase({ caseId });
        const histories = result?.Customer_Histories__r;
        if (histories && histories.length > 0) {
            return histories[histories.length - 1].Id;
        }
    } catch (e) {
        console.error('_getHistoryIdFromCase error:', e);
    }
    return null;
  } 

  get isDisplayCreateCase() {
    return (
      (this.isCreateCaseTab ||
        this.tabName === 'FEC_Customer_Search' ||
        this.tabName === 'FEC_Account_Contract_Search' ||
        !!this.recordId) &&
      !this.isSearchServiceError
    );
  }

  get noCustomerFoundMessage() {
    if (this.isSearchServiceError) {
      return FEC_MSG_Service_Error_Label;
    }
    return FEC_Common_No_Results_Label;
  }

  get noCustomerFoundClass() {
    return "slds-text-align_center slds-text-body_regular slds-text-color_error slds-m-bottom_medium";
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
  async seedSampleRows(force = false) {
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
      // this.insuranceData = [
      //   {
      //     id: "ins1",
      //     UserId: "23456789",
      //     FullName: "NGUYEN VAN A",
      //     DateOfBirth: "1990-01-01",
      //     BuyerNID: "062789888321",
      //     ProductName: "Single Health",
      //     PremiumFee: 800000,
      //     PaymentId: "IZI00012345",
      //     EffectiveDate: "2024-01-01",
      //     Status: "Còn hiệu lực",
      //   },
      //   {
      //     id: "ins2",
      //     UserId: "98765432",
      //     FullName: "LE QUANG D",
      //     DateOfBirth: "1988-03-27",
      //     BuyerNID: "023456777210",
      //     ProductName: "Family Care",
      //     PremiumFee: 1250000,
      //     PaymentId: "IZI00056789",
      //     EffectiveDate: "2023-02-15",
      //     Status: "Hết hiệu lực",
      //   },
      // ];
      const response = await searchByListNIDs({nationalIDs: [this.nationalId]});
              let items = [];
              if (response.sys2.code2 != '200') {
                this.insuranceData = []; // not found insurance data
                this.errorCalloutIsurance = response.sys2.code2 != '400';
              } else if (response.sys2.code2 === '200') {
                  response.result.forEach(element => {
                    items.push({
                      id: element.userID,
                      UserId: element.userID,
                      FullName: element.buyerName,
                      BuyerNID: element.buyerNID,
                      DateOfBirth: element.buyerDOB,
                      ProductName: element.productNameEn,
                      PremiumFee: element.collectedPremiumFee,
                      PaymentId:  element.paymentID,
                      EffectiveDate:  element.effectiveDate,
                      Status:  element.StatusDisplay,
                      PolicyNumber:  element.policyNumber,
                    })
                  });
                this.insuranceData = items;
              }
    }

    this._customers = [
        {
          id: "card1",
          FullName: "NGUYEN VAN A",
          NationalID: "123456789",
          DateOfBirth: "1990-01-15",
          PlasticID: "DC8",
          AccountStatus: "A",
          AccountNumber: "0001500040006525520",
          FieldName: "AccountNumber",
          CIFNumber:'888888888'
        },
        {
          id: "card1",
          FullName: "NGUYEN VAN B",
          NationalID: "123456789",
          DateOfBirth: "1990-01-15",
          PlasticID: "DC8",
          AccountStatus: "A",
          AccountNumber: "0001500040006525520",
          FieldName: "AccountNumber",
          CIFNumber:'999999999'
        }
      ]
  }

  async handlePublishMessageChanel() {
    const payload = {
      isModeEdit: true,
    };
    publish(this.messageContext, IS_MODE_EDIT_INTERACTION, payload);
  }
}