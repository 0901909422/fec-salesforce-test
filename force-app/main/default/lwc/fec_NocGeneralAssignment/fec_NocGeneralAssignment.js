import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { loadStyle } from 'lightning/platformResourceLoader';
import getGeneralAssignments from '@salesforce/apex/FEC_NocGeneralAssignmentController.getGeneralAssignments';
import getChannelValues from '@salesforce/apex/FEC_NocGeneralAssignmentController.getChannelValues';
import getGeneralAssignmentCodes from '@salesforce/apex/FEC_NocGeneralAssignmentController.getGeneralAssignmentCodes';
import getGACodeByName from '@salesforce/apex/FEC_GeneralAssignmentController.getGACodeByName';
import FEC_CommonCss from '@salesforce/resourceUrl/FEC_CommonCss';
import LABEL_PREVIOUS from '@salesforce/label/c.FEC_Previous_Btn_Label';
import LABEL_NEXT from '@salesforce/label/c.FEC_Next_Btn_Label';
import LABEL_PAGE_OF from '@salesforce/label/c.Pagination_Page_Of_Label';
import LABEL_NEW from '@salesforce/label/c.FEC_Btn_Add_New';
import LABEL_SUCCESS from '@salesforce/label/c.FEC_GA_Save_Success';
import LABEL_CREATED from '@salesforce/label/c.FEC_GA_Create_Success_Message';
import LABEL_CREATE_ERROR from '@salesforce/label/c.FEC_GA_Create_Error_Message';
import LABEL_ERROR from '@salesforce/label/c.FEC_GA_Save_Error';
import LABEL_CHANNEL_REQUIRED from '@salesforce/label/c.FEC_GA_Channel_Required';
import LABEL_NAME_REQUIRED from '@salesforce/label/c.FEC_GA_Name_Required';

export default class Fec_NocGeneralAssignment extends NavigationMixin(LightningElement) {
    @api recordId;
    @track records = [];
    @track showModal = false;
    @track channelSearchTerm = '';
    @track gaSearchTerm = '';
    @track selectedChannelIds = [];
    @track selectedGACodes = [];
    @track showChannelDropdown = false;
    @track showGADropdown = false;
    @track channelOptions = [];
    @track gaOptions = [];
    @track pageNumber = 1;
    @track pageSize = 10;
    wiredRecordsResult;
    allRecords = [];
    
    labels = {
        previous: LABEL_PREVIOUS,
        next: LABEL_NEXT,
        pageOf: LABEL_PAGE_OF,
        new: LABEL_NEW
    };

    connectedCallback() {
        loadStyle(this, FEC_CommonCss);
        this.loadChannelOptions();
        this.loadGAOptions();
    }

    get paginatedRecords() {
        const start = (this.pageNumber - 1) * this.pageSize;
        const end = this.pageNumber * this.pageSize;
        return this.allRecords.slice(start, end);
    }

    get totalPages() {
        return Math.ceil(this.allRecords.length / this.pageSize);
    }

    get isFirstPage() {
        return this.pageNumber === 1;
    }

    get isLastPage() {
        return this.pageNumber >= this.totalPages;
    }

    get pageInfo() {
        return this.labels.pageOf.replace('{0}', this.pageNumber).replace('{1}', this.totalPages);
    }

    handlePageInput(event) {
        const inputPage = parseInt(event.target.value, 10);
        if (inputPage >= 1 && inputPage <= this.totalPages) {
            this.pageNumber = inputPage;
            this.records = this.paginatedRecords;
        }
    }

    get channelComboboxClass() {
        return this.showChannelDropdown ? 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-is-open' : 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
    }

    get gaComboboxClass() {
        return this.showGADropdown ? 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-is-open' : 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
    }

    get filteredChannelOptions() {
        if (!this.channelSearchTerm) {
            return this.channelOptions.filter(opt => !this.selectedChannelIds.includes(opt.value));
        }
        const searchLower = this.channelSearchTerm.toLowerCase();
        return this.channelOptions.filter(opt => 
            opt.label.toLowerCase().includes(searchLower) && !this.selectedChannelIds.includes(opt.value)
        );
    }

    get filteredGAOptions() {
        if (!this.gaSearchTerm) {
            return this.gaOptions.filter(opt => !this.selectedGACodes.includes(opt.value));
        }
        const searchLower = this.gaSearchTerm.toLowerCase();
        return this.gaOptions.filter(opt => 
            opt.label.toLowerCase().includes(searchLower) && !this.selectedGACodes.includes(opt.value)
        );
    }

    loadChannelOptions() {
        getChannelValues()
            .then(result => {
                console.log('Channel values loaded:', result);
                this.channelOptions = result.map(item => ({
                    label: item.FEC_Channel_ID__c,
                    value: item.FEC_Channel_ID__c
                }));
                console.log('Channel options:', this.channelOptions);
            })
            .catch(error => {
                console.error('Error loading channels:', error);
            });
    }

    loadGAOptions() {
        getGeneralAssignmentCodes()
            .then(result => {
                this.gaOptions = result.map(item => ({
                    label: item.FEC_General_Assignment_Name__c,
                    value: item.FEC_General_Assignment_Name__c
                }));
            })
            .catch(error => {
                console.error('Error loading GA names:', error);
            });
    }

    handleChannelSearch(event) {
        this.channelSearchTerm = event.target.value;
        // Only show dropdown if user has typed something
        this.showChannelDropdown = this.channelSearchTerm.length > 0;
    }

    handleChannelFocus() {
        // Only show dropdown if there's search text
        if (this.channelSearchTerm.length > 0) {
            this.showChannelDropdown = true;
        }
    }

    handleChannelBlur() {
        setTimeout(() => {
            this.showChannelDropdown = false;
        }, 200);
    }

    handleChannelSelect(event) {
        const value = event.currentTarget.dataset.value;
        if (!this.selectedChannelIds.includes(value)) {
            this.selectedChannelIds = [...this.selectedChannelIds, value];
        }
        this.channelSearchTerm = '';
        this.showChannelDropdown = false;
    }

    handleChannelRemove(event) {
        const idToRemove = event.target.name;
        this.selectedChannelIds = this.selectedChannelIds.filter(id => id !== idToRemove);
    }

    handleGASearch(event) {
        this.gaSearchTerm = event.target.value;
        // Only show dropdown if user has typed something
        this.showGADropdown = this.gaSearchTerm.length > 0;
    }

    handleGAFocus() {
        // Only show dropdown if there's search text
        if (this.gaSearchTerm.length > 0) {
            this.showGADropdown = true;
        }
    }

    handleGABlur() {
        setTimeout(() => {
            this.showGADropdown = false;
        }, 200);
    }

    handleGASelect(event) {
        const value = event.currentTarget.dataset.value;
        if (!this.selectedGACodes.includes(value)) {
            this.selectedGACodes = [...this.selectedGACodes, value];
        }
        this.gaSearchTerm = '';
        this.showGADropdown = false;
    }

    handleGARemove(event) {
        const codeToRemove = event.target.name;
        this.selectedGACodes = this.selectedGACodes.filter(code => code !== codeToRemove);
    }

    @wire(getGeneralAssignments, { nocId: '$recordId' })
    wiredRecords(result) {
        this.wiredRecordsResult = result;
        if (result.data) {
            this.allRecords = result.data;
            this.records = this.paginatedRecords;
        } else if (result.error) {
            console.error('Error:', result.error);
        }
    }

    get columns() {
        return [
            { 
                label: 'GA Name', 
                fieldName: 'Name',
                type: 'button',
                typeAttributes: {
                    label: { fieldName: 'Name' },
                    name: 'view_detail',
                    variant: 'base'
                }
            },
            { label: 'Customer Type', fieldName: 'CustomerType', type: 'text' },
            { label: 'Channel', fieldName: 'Channel', type: 'text' },
            { label: 'Stage', fieldName: 'Stage', type: 'text' },
            { label: 'General Assignment Name', fieldName: 'GeneralAssignmentName', type: 'text' },
            { label: 'Status', fieldName: 'Active', type: 'boolean' },
            {
                type: 'action',
                typeAttributes: {
                    rowActions: [{ label: 'View', name: 'view_detail' }]
                }
            }
        ];
    }

    get hasRecords() {
        return this.allRecords && this.allRecords.length > 0;
    }

    handlePreviousPage() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.records = this.paginatedRecords;
        }
    }

    handleNextPage() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.records = this.paginatedRecords;
        }
    }

    handleNew() {
        this.showModal = true;
        this.channelSearchTerm = '';
        this.gaSearchTerm = '';
        this.selectedChannelIds = [];
        this.selectedGACodes = [];
    }

    handleCancel() {
        this.showModal = false;
        this.channelSearchTerm = '';
        this.gaSearchTerm = '';
        this.selectedChannelIds = [];
        this.selectedGACodes = [];
    }

    handleSubmit(event) {
        event.preventDefault();
        
        if (this.selectedChannelIds.length === 0) {
            this.dispatchEvent(new ShowToastEvent({ title: LABEL_ERROR, message: LABEL_CHANNEL_REQUIRED, variant: 'error' }));
            return;
        }
        if (this.selectedGACodes.length === 0) {
            this.dispatchEvent(new ShowToastEvent({ title: LABEL_ERROR, message: LABEL_NAME_REQUIRED, variant: 'error' }));
            return;
        }

        const gaName = this.selectedGACodes.join(',');
        const fields = event.detail.fields;
        fields.FEC_Nature_of_Cases__c = this.recordId;
        fields.FEC_Channel__c = this.selectedChannelIds.join(',');
        fields.FEC_General_Assignment_Name__c = gaName;

        // Auto-fill GA Code from GA Name
        getGACodeByName({ gaName: this.selectedGACodes[0] })
            .then(code => {
                if (code) fields.FEC_General_Assignment_Code__c = code;
                this.template.querySelector('lightning-record-edit-form').submit(fields);
            })
            .catch(() => {
                this.template.querySelector('lightning-record-edit-form').submit(fields);
            });
    }

    handleSuccess() {
        this.showModal = false;
        this.channelSearchTerm = '';
        this.gaSearchTerm = '';
        this.selectedChannelIds = [];
        this.selectedGACodes = [];
        this.dispatchEvent(new ShowToastEvent({
            title: LABEL_SUCCESS,
            message: LABEL_CREATED,
            variant: 'success'
        }));
        this.pageNumber = 1;
        return refreshApex(this.wiredRecordsResult);
    }

    handleError(event) {
        this.dispatchEvent(new ShowToastEvent({
            title: LABEL_ERROR,
            message: event.detail?.message || LABEL_CREATE_ERROR,
            variant: 'error'
        }));
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        if (actionName === 'view_detail') {
            // tungnm37: dùng standard__recordPage (LWC) thay vì Aura component
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: row.Id,
                    actionName: 'view'
                }
            });
        }
    }
}

