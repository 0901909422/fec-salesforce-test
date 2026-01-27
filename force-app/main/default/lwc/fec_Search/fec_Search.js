import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { updateRecord, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import Toast from 'lightning/toast';
import { refreshApex } from "@salesforce/apex";
import FORM_FACTOR from '@salesforce/client/formFactor';
import { loadStyle } from "lightning/platformResourceLoader";
import COMMON_STYLES from "@salesforce/resourceUrl/FEC_CommonCss";
import getCase from '@salesforce/apex/FEC_SearchController.getCase';
import createHistory from '@salesforce/apex/FEC_SearchController.createHistory';
import createCustomerCase from '@salesforce/apex/FEC_SearchController.createCustomerCase';
import SkipModal from 'c/fec_SkipModal';
import {
    IsConsoleNavigation,
    getFocusedTabInfo,
    refreshTab
} from 'lightning/platformWorkspaceApi';
import MyModal from 'c/fec_SendNotification';

export default class Fec_Search extends NavigationMixin(LightningElement) {
    @api recordId;
    @api isLoaded = false;
    activeSections = ['searchCriteria', 'results'];
    nationalId;
    phoneNumber;
    isDisplay = false;
    applicationId;
    contractNumber;
    accountNumber;
    emailAddress;
    customerNumber;
    fullName = '';
    fullNameForCreate = '';
    nationalIdForCreate = '';
    isNoCustomerFound = false;
    showNewCaseModal = false;
    isSkip;
    wiredCaseResult;

    @wire(IsConsoleNavigation) isConsoleNavigation;
    async refreshTab() {
        if (!this.isConsoleNavigation) {
            return;
        }
        const { tabId } = await getFocusedTabInfo();
        await refreshTab(tabId, {
            includeAllSubtabs: true
        });
    }
    // Active tab state
    activeTabValue = 'Card';

    // Demo columns per tab (adjust fields as needed)
    get cardColumns() {
        return [
            {
                label: 'Account Number',
                type: this.recordId ? 'dblclickText' : 'text',
                fieldName: 'AccountNumber',
                typeAttributes: this.recordId ? {
                    value: { fieldName: 'AccountNumber' },
                    fieldName: 'AccountNumber'
                } : {},
                sortable: false
            },
            { label: 'Full Name', fieldName: 'FullName', sortable: true },
            { label: 'National ID 1', fieldName: 'NationalID1', type: 'maskedToggle', sortable: true },
            { label: 'National ID 2', fieldName: 'NationalID2', type: 'maskedToggle', sortable: true },
            { label: 'Date of Birth', fieldName: 'DateOfBirth', sortable: true },
            { label: 'Plastic ID', fieldName: 'PlasticID', sortable: true },
            { label: 'Account Status', fieldName: 'AccountStatus', sortable: true }
        ];
    }

    get loanContractColumns() {
        return [
            {
                label: 'Contract Number',
                type: this.recordId ? 'dblclickText' : 'text',
                fieldName: 'ContractNumber',
                typeAttributes: this.recordId ? {
                    value: { fieldName: 'ContractNumber' },
                    fieldName: 'ContractNumber'
                } : {},
                sortable: false
            },
            { label: 'Full Name', fieldName: 'FullName', sortable: true },
            { label: 'National ID 1', fieldName: 'NationalID1', type: 'maskedToggle', sortable: true },
            { label: 'National ID 2', fieldName: 'NationalID2', type: 'maskedToggle', sortable: true },
            { label: 'Date of Birth', fieldName: 'DateOfBirth', sortable: true },
            { label: 'Product Code', fieldName: 'ProductCode', sortable: true },
            { label: 'Contract Status', fieldName: 'ContractStatus', sortable: true },
        ];
    }

    get loanB2Columns() {
        return [
            { label: 'Contract Number', fieldName: 'ContractNumber', sortable: true },
            { label: 'Full Name', fieldName: 'FullName', sortable: true },
            { label: 'National ID', fieldName: 'NationalID1', type: 'maskedToggle', sortable: true },
            { label: 'Code', fieldName: 'Code', sortable: true },
            { label: 'Product Code', fieldName: 'ProductCode', sortable: true },
            { label: 'Installment', fieldName: 'Installment', sortable: true },
            { label: 'Principal', fieldName: 'Principal', sortable: true },
            { label: 'Monthly Fee', fieldName: 'MonthlyFee', sortable: true },
            { label: 'Term', fieldName: 'Term', sortable: true },
            { label: 'City ', fieldName: 'City', sortable: true },
        ];
    }

    get loanCash24Columns() {
        return [
            { label: 'Contract Number', fieldName: 'ContractNumber', sortable: true },
            { label: 'Sold Date', fieldName: 'SoldDate', sortable: true },
            { label: 'Balance Amount', fieldName: 'BalanceAmount ', sortable: true },
            { label: 'Product Code', fieldName: 'ProductCode', sortable: true },
            { label: 'Contract Status', fieldName: 'ContractStatus', sortable: true },
            { label: 'Note', fieldName: 'Note', sortable: true }
        ];
    }

    get insuranceColumns() {
        return [
            {
                label: 'User ID',
                type: this.recordId ? 'dblclickText' : 'text',
                fieldName: 'UserId',
                typeAttributes: this.recordId ? {
                    value: { fieldName: 'UserId' },
                    fieldName: 'UserId'
                } : {},
                sortable: false
            },
            { label: 'Full Name', fieldName: 'FullName', sortable: true },
            { label: 'Date of Birth', fieldName: 'DateOfBirth', sortable: true },
            { label: 'Buyer NID', fieldName: 'BuyerNID', type: 'maskedToggle', sortable: true },
            { label: 'Product Name', fieldName: 'ProductName', sortable: true },
            { label: 'Premium Fee', fieldName: 'PremiumFee', type: 'currency', sortable: true },
            { label: 'Payment ID', fieldName: 'PaymentId', sortable: true },
            { label: 'Effective Date', fieldName: 'EffectiveDate', type: 'date', sortable: true },
            { label: 'Status', fieldName: 'Status', sortable: true }
        ];
    }

    get ubankColumns() {
        return [
            { label: 'Full Name', fieldName: 'FullName', sortable: true },
            { label: 'National ID 1', fieldName: 'NationalID1', type: 'maskedToggle', sortable: true },
            { label: 'National ID 2', fieldName: 'NationalID2', type: 'maskedToggle', sortable: true },
            { label: 'Date of Birth', fieldName: 'DateOfBirth', sortable: true },
            { label: 'Account Status', fieldName: 'AccountStatus', sortable: true },
            {
                label: 'Account Number',
                type: this.recordId ? 'button' : 'text',
                fieldName: 'AccountNumber',
                typeAttributes: this.recordId ? {
                    label: { fieldName: 'AccountNumber' },
                    name: 'create_history',
                    variant: 'base',
                    value: { fieldName: 'AccountNumber' }
                } : {},
                sortable: false
            }
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

    @wire(getCase, { caseId: '$recordId' })
    wiredCase(result) {
        this.wiredCaseResult = result;
        const { data, error } = result;
        if (data) {
            // Logic xử lý dữ liệu khi thành công (tương đương phần .then cũ)
            this.isSkip = data?.RecordType?.Name == 'Internal Case';
            this.isDisplay = data.Customer_Histories__r === undefined && data.FEC_Skip_Search_Internal_Case__c === false;
            this.phoneNumber = data.FEC_Phone_Number__c || null;
            this.nationalId = data.FEC_National_ID_Passport_ID__c || null;
            this.contractNumber = data.FEC_Contract_Number__c || null;

            // Tự động seed data nếu có thông tin tìm kiếm từ Case
            if (this.phoneNumber || this.nationalId || this.contractNumber) {
                this.seedSampleRows(true);
            }
        } else if (error) {
            // Xử lý lỗi (tương đương phần .catch cũ)
            console.error('Error fetching case data:', error);
            // this.showToast('Error', 'Không thể lấy thông tin Case', 'error');
        }
    }

    connectedCallback() {
        this.isLoaded = true;
        // Load styles
        loadStyle(this, COMMON_STYLES)
            .then(() => console.log("Common styles loaded"))
            .catch(err => console.error(err));
            
        // KHÔNG gọi getCase ở đây nữa vì @wire đã đảm nhiệm
        if (!this.recordId) {
            this.isDisplay = true;
        }
    }

    // connectedCallback() {
    //     this.isLoaded = true;

    //     // Load shared styles
    //     loadStyle(this, COMMON_STYLES)
    //         .then(() => {
    //             console.log("Common styles loaded successfully");
    //         })
    //         .catch((error) => {
    //             console.error("Error loading common styles", error);
    //         });

    //     // Initialize from server via Apex when placed on a Case record page
    //     // Uses Apex controller per requirement instead of UI API
    //     if (this.recordId) {
    //         getCase({ caseId: this.recordId })
    //             .then((res) => {
    //                 if (!res) {
    //                     return;
    //                 }
    //                 this.isDisplay = res.Customer_Histories__r == undefined && !res.FEC_Skip_Search_Internal_Case__c;
    //                 this.isSkip = res.RecordType.Name == 'Internal Case';
    //                 this.phoneNumber = res.FEC_Phone_Number__c || null;
    //                 this.nationalId = res.FEC_National_ID_Passport_ID__c || null;
    //                 this.contractNumber = res.FEC_Contract_Number__c || null;
    //                 if (this.phoneNumber || this.nationalId || this.contractNumber) {
    //                     this.seedSampleRows(true);
    //                 }
    //             })
    //             .catch((e) => {
    //                 // Non-blocking: silently ignore; component still usable
    //                 // Optionally surface as toast if desired
    //                 // this.showToast('Error', 'Failed to initialize from Case', 'error');
    //             });
    //     } else {
    //         this.isDisplay = true;
    //     }
    // }

    // Handle inputs (wire these ids to your current fields as needed)
    handleInputChange(event) {
        const id = event.target.dataset.id;
        const value = event.detail.value;
        switch (id) {
            case 'nationalId':
                this.nationalId = value;
                // Validate National ID length: must be 9 or 12 chars
                {
                    const input = this.template.querySelector('[data-id="nationalId"]');
                    if (input) {
                        if (!value) {
                            // Empty value: clear custom error
                            input.setCustomValidity('');
                        } else if (value.length !== 9 && value.length !== 12) {
                            input.setCustomValidity('National ID must be 9 characters or 12 characters');
                        } else {
                            input.setCustomValidity('');
                        }
                        input.reportValidity();
                    }
                }
                break;
            case 'phoneNumber':
                this.phoneNumber = value;
                // Validate Phone Number:
                // - If starts with '0' -> must be exactly 10 digits
                // - If starts with '84' -> must be exactly 11 digits
                {
                    const input = this.template.querySelector('[data-id="phoneNumber"]');
                    if (input) {
                        const val = value ? value.toString().trim() : '';
                        if (!val) {
                            input.setCustomValidity('');
                        } else if (/^0/.test(val)) {
                            if (!/^\d{10}$/.test(val)) {
                                input.setCustomValidity('Phone number must be 10 digits if it starts with 0');
                            } else {
                                input.setCustomValidity('');
                            }
                        } else if (/^84/.test(val)) {
                            if (!/^\d{11}$/.test(val)) {
                                input.setCustomValidity('Phone number must be 11 digits if it starts with 84');
                            } else {
                                input.setCustomValidity('');
                            }
                        } else {
                            // If it doesn't start with 0 or 84, consider invalid per rules
                            input.setCustomValidity('Phone number must start with 0 (10 digits) or 84 (11 digits)');
                        }
                        input.reportValidity();
                    }
                }
                break;
            case 'applicationId':
                this.applicationId = value;
                {
                    const input = this.template.querySelector('[data-id="applicationId"]');
                    if (input) {
                        const val = value ? value.toString().trim() : '';
                        if (!val) {
                            // allow empty
                            input.setCustomValidity('');
                        } else if (!/^\d+$/.test(val)) {
                            input.setCustomValidity('Application ID must contain only digits');
                        } else if (!(val.length === 6 || val.length === 8 || val.length === 9)) {
                            input.setCustomValidity('Application ID must be 6, 8, or 9 digits');
                        } else {
                            input.setCustomValidity('');
                        }
                        input.reportValidity();
                    }
                }
                break;
            case 'contractNumber':
                this.contractNumber = value;
                // Validate Contract Number against allowed formats:
                {
                    const input = this.template.querySelector('[data-id="contractNumber"]');
                    if (input) {
                        const val = value ? value.toString().trim() : '';
                        const patterns = [
                            /^\d{8}-\d{6}-\d{4}$/,
                            /^\d{8}-\d{7}-\d{3}$/,
                            /^\d{8}-\d{7}-\d{2}$/,
                            /^\d{8}-\d{7}-\d{1}$/,
                            /^\d{8}-\d{7}$/,
                            /^\d{2}-\d{2}-\d{2}-\d{2}$/
                        ];
                        const valid = !val || patterns.some((re) => re.test(val));
                        if (!valid) {
                            input.setCustomValidity(
                                'Contract Number must be one of: (8)-(6)-(4) | (8)-(7)-(3) | (8)-(7)-(2) | (8)-(7)-(1) | (8)-(7) | (2)-(2)-(2)-(2) digits'
                            );
                        } else {
                            input.setCustomValidity('');
                        }
                        input.reportValidity();
                    }
                }
                break;
            case 'accountNumber':
                this.accountNumber = value;
                {
                    const input = this.template.querySelector('[data-id="accountNumber"]');
                    if (input) {
                        const val = value ? value.toString().trim() : '';
                        if (!val) {
                            // allow empty so user can clear field
                            input.setCustomValidity('');
                        } else if (!/^\d+$/.test(val)) {
                            input.setCustomValidity('Account Number must contain only digits');
                        } else if (!(val.length === 16 || val.length === 19)) {
                            input.setCustomValidity('Account Number must be 16 or 19 digits');
                        } else {
                            input.setCustomValidity('');
                        }
                        input.reportValidity();
                    }
                }
                break;
            case 'emailAddress':
                this.emailAddress = value;
                {
                    const input = this.template.querySelector('[data-id="emailAddress"]');
                    if (input) {
                        const val = value ? value.toString().trim() : '';
                        if (!val) {
                            input.setCustomValidity('');
                        } else {
                            // REMOVED the "\." from the [A-Za-z0-9.\-]+ section in both lines below
                            // This forces the structure to strictly follow "text.text" or "text.text.text"
                            const oneLevel = /^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+\.[A-Za-z]{2,5}$/;
                            const twoLevel = /^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+\.[A-Za-z]{2,5}\.[A-Za-z]{2,5}$/;

                            if (!(oneLevel.test(val) || twoLevel.test(val))) {
                                input.setCustomValidity('Email must be one of (randomString1)@(randomString2).(2-5 chars) or (randomString1)@(randomString2).(2-5 chars).(2-5 chars)');
                            } else {
                                input.setCustomValidity('');
                            }
                        }
                        input.reportValidity();
                    }
                }
                break;
            case 'customerNumber':
                this.customerNumber = value;
                break;
            default:
                break;
        }
    }

    handleClear() {
        this.nationalId = null;
        this.phoneNumber = null;
        this.applicationId = null;
        this.contractNumber = null;
        this.accountNumber = null;
        this.emailAddress = null;
        this.customerNumber = null;

        // Clear input values and error messages (custom validity) on all inputs
        const inputs = this.template.querySelectorAll('lightning-input');
        inputs.forEach((inp) => {
            try {
                // Reset UI value
                inp.value = '';
                // Clear any custom validity messages and refresh validity UI
                inp.setCustomValidity('');
                inp.reportValidity();
            } catch (e) {
                // No-op: some inputs may not support setCustomValidity in edge cases
            }

        });

        // Clear all datasets
        this.cardData = [];
        this.loanData = [];
        this.insuranceData = [];
        this.ubankData = [];
    }

    handleSearch() {
        // Validate all inputs and ensure at least one search field is provided
        const inputs = this.template.querySelectorAll('.responsive-layout lightning-input');

        // Determine if at least one field has a value
        let hasAnyValue = false;
        inputs.forEach((inp) => {
            const val = (inp.value || '').toString().trim();
            if (val) {
                hasAnyValue = true;
            }
        });

        if (!hasAnyValue) {
            this.showToast('Validation', 'Enter at least one search criterion.', 'warning');
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
            this.showToast('Validation', 'Please correct the highlighted errors before searching.', 'error');
            return;
        }

        // Example: populate data sets based on current criteria.
        // Replace with actual Apex calls and set the dataset corresponding to each tab.
        this.seedSampleRows(true);
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
            const result = await createCustomerCase({
                fullName: this.fullNameForCreate,
                nationalId: this.nationalIdForCreate
            });

            // Support both Id string or Case sObject return
            const caseId = (result && result.Id) ? result.Id : result;

            if (!caseId) {
                this.showToast('Warning', 'Case created but no Id was returned.', 'warning');
                return;
            }

            this.showToast('Success', 'Case created successfully.', 'success');

            // Navigate to the newly created Case record
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: caseId,
                    objectApiName: 'Case',
                    actionName: 'view'
                }
            });
        } catch (e) {
            this.showToast('Error', 'Failed to create Case.', 'error');
        }
    }

    async handleSkip() {
        const result = await SkipModal.open({
            size: 'small',
            label: 'Skip Search',
            content: 'Bạn có chắc chắn bỏ qua bước tìm kiếm khách hàng không? Bạn sẽ không thể quay lại tìm kiếm sau khi xác nhận.'
        });

        // Nếu result có giá trị 'confirmed' (do mình định nghĩa ở handleConfirm)
        if (result === 'confirm') {
            this.isLoaded = false;
            const fields = {};
            fields['Id'] = this.recordId;
            fields['FEC_Skip_Search_Internal_Case__c'] = true;

            const recordInput = { fields };

            try {
                // Bước 1: Cập nhật bản ghi xuống Database
                await updateRecord(recordInput);

                // Bước 2: ĐẶT TẠI ĐÂY - Thông báo cho UI làm mới dữ liệu
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
                await refreshApex(this.wiredCaseResult);

                this.showToast('Thành công', 'Case đã được cập nhật.', 'success');
            } catch (error) {
                this.showToast('Lỗi', error.body.message, 'error');
            } 
            finally {
                this.isLoaded = true;
            }
        }
    }

    handleFullNameChange(event) {
        this.fullNameForCreate = event.target.value;
    }

    handleNationalIdChange(event) {
        this.nationalIdForCreate = event.target.value;
    }

    get isNewCaseDisabled() {
        return !this.fullNameForCreate;
    }

    // Shared toast helper with de-duplication by title+message+variant signature
    showToast(title, msg, type) {
        Toast.show(
            {
                label: title,
                message: msg,
                mode: 'dismissible',
                variant: type
            },
            this
        );
    }

    // Handle button actions from datatable rows
    handleRowAction(event) {
        const { action, row } = event.detail || {};
        if (!action || !action.name) {
            return;
        }
        switch (action.name) {
            case 'create_history': {
                if (!this.recordId) {
                    this.dispatchEvent(
                        new CustomEvent('rowselected', {
                            detail: {
                                fullName: row?.FullName || '',
                                nationalId: row?.AccountNumber || row?.ContractNumber || ''

                            },
                            bubbles: true,
                            composed: true
                        })

                    );
                    return;
                }
                createHistory({ value: row, fieldName: action.label.fieldName, caseId: this.recordId })
                    .then(async (res) => {
                        await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
                        await refreshApex(this.wiredCaseResult);
                        await this.refreshTab();
                        this.showToast('Success', 'History created successfully', 'success');
                    })
                    .catch((e) => {
                        this.showToast('Error', 'Failed to create history', 'error');
                    });

                break;
            }
            default:
                break;
        }
    }

    // Sorting helpers if you want per-table sorting in future (optional)
    onSorting(event) {
        const { fieldName, sortDirection } = event.detail;
        const tab = this.activeTabValue;
        if (tab === 'Accounts') {
            this.accountsData = this.sortData(this.accountsData, fieldName, sortDirection);
        } else if (tab === 'Contacts') {
            this.contactsData = this.sortData(this.contactsData, fieldName, sortDirection);
        } else if (tab === 'Cases') {
            this.casesData = this.sortData(this.casesData, fieldName, sortDirection);
        } else if (tab === 'Opportunities') {
            this.oppsData = this.sortData(this.oppsData, fieldName, sortDirection);
        }
    }

    sortData(data, fieldname, direction) {
        const clone = JSON.parse(JSON.stringify(data || []));
        const isReverse = direction === 'asc' ? 1 : -1;
        clone.sort((a, b) => {
            const x = a[fieldname] ?? '';
            const y = b[fieldname] ?? '';
            return isReverse * ((x > y) - (y > x));
        });
        return clone;
    }

    // Demo data seeding
    seedSampleRows(force = false) {
        if (this.emailAddress == 'a@a.aa') {
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
                    id: 'card1',
                    FullName: 'NGUYEN VAN A',
                    NationalID1: '062789144',
                    NationalID2: '230444789',
                    DateOfBirth: '1990-01-15',
                    PlasticID: 'DC8',
                    AccountStatus: 'A',
                    AccountNumber: '0001500040006525520',
                    FieldName: 'AccountNumber'
                },
                {
                    id: 'card2',
                    FullName: 'TRAN THI B',
                    NationalID1: '024567777',
                    NationalID2: '',
                    DateOfBirth: '1987-06-20',
                    PlasticID: 'AB3',
                    AccountStatus: '9',
                    AccountNumber: '0001500049876501245',
                    FieldName: 'AccountNumber'
                }
            ];
        }

        // LOAN - Contract
        if (force || this.loanContractData?.length === 0) {
            this.loanContractData = [
                {
                    id: 'lcon1',
                    FullName: 'NGUYEN VAN A',
                    NationalID1: '062789666',
                    NationalID2: '230999789',
                    DateOfBirth: '1990-01-01',
                    ProductCode: 'CDL',
                    ContractStatus: 'Active',
                    ContractNumber: '20240318-0915427'
                },
                {
                    id: 'lcon2',
                    FullName: 'PHAM THU C',
                    NationalID1: '098345777',
                    NationalID2: '',
                    DateOfBirth: '1985-09-12',
                    ProductCode: 'MCL',
                    ContractStatus: 'Closed',
                    ContractNumber: '20230711-1745620'
                }
            ];
        }

        // LOAN - B2
        if (force || this.loanB2Data?.length === 0) {
            this.loanB2Data = [
                {
                    id: 'lb2_1',
                    FullName: 'TRAN THI B',
                    NationalID1: '024567444',
                    Code: 'B2-001',
                    ProductCode: 'B2P',
                    Installment: '1,200,000',
                    Principal: '20,000,000',
                    MonthlyFee: '50,000',
                    Term: '24',
                    City: 'Hanoi',
                    ContractNumber: '20230711-1745620'
                },
                {
                    id: 'lb2_2',
                    FullName: 'LE QUANG D',
                    NationalID1: '023456666',
                    Code: 'B2-002',
                    ProductCode: 'B2P',
                    Installment: '950,000',
                    Principal: '15,000,000',
                    MonthlyFee: '45,000',
                    Term: '18',
                    City: 'Da Nang',
                    ContractNumber: '20230711-1745620'
                }
            ];
        }

        // LOAN - Cash24
        if (force || this.loanCash24Data?.length === 0) {
            this.loanCash24Data = [
                {
                    id: 'lc24_1',
                    FullName: 'NGUYEN VAN A',
                    SoldDate: '2024-08-10',
                    BalanceAmount: '12,500,000',
                    ProductCode: 'C24',
                    ContractStatus: 'Sold',
                    Note: 'Transferred to partner',
                    ContractNumber: '20230711-1745620'
                },
                {
                    id: 'lc24_2',
                    FullName: 'TRAN THI B',
                    SoldDate: '2023-12-05',
                    BalanceAmount: '8,200,000',
                    ProductCode: 'C24',
                    ContractStatus: 'Closed',
                    Note: 'Paid off',
                    ContractNumber: '20230711-1745620'
                }
            ];
        }

        // INSURANCE
        if (force || this.insuranceData?.length === 0) {
            this.insuranceData = [
                {
                    id: 'ins1',
                    UserId: '23456789',
                    FullName: 'NGUYEN VAN A',
                    DateOfBirth: '1990-01-01',
                    BuyerNID: '062789888321',
                    ProductName: 'Single Health',
                    PremiumFee: 800000,
                    PaymentId: 'IZI00012345',
                    EffectiveDate: '2024-01-01',
                    Status: 'Còn hiệu lực'
                },
                {
                    id: 'ins2',
                    UserId: '98765432',
                    FullName: 'LE QUANG D',
                    DateOfBirth: '1988-03-27',
                    BuyerNID: '023456777210',
                    ProductName: 'Family Care',
                    PremiumFee: 1250000,
                    PaymentId: 'IZI00056789',
                    EffectiveDate: '2023-02-15',
                    Status: 'Hết hiệu lực'
                }
            ];
        }

        // UBANK
        if (force || this.ubankData?.length === 0) {
            this.ubankData = [
                {
                    id: 'ub1',
                    FullName: 'NGUYEN VAN A',
                    NationalID1: '062789***321',
                    NationalID2: '230***789',
                    DateOfBirth: '1990-01-01',
                    AccountStatus: 'Active',
                    AccountNumber: '318477418'
                },
                {
                    id: 'ub2',
                    FullName: 'TRAN THI B',
                    NationalID1: '054321***987',
                    NationalID2: '',
                    DateOfBirth: '1993-11-05',
                    AccountStatus: 'Dormant',
                    AccountNumber: '564823791'
                }
            ];
        }
    }

}