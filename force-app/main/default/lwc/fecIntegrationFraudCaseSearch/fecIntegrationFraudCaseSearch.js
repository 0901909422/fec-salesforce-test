import { LightningElement, track } from 'lwc';
import searchFraudCases from '@salesforce/apex/FEC_IntegrationSearchFraudCaseController.searchFraudCases';

export default class IntegrationFraudCaseSearch extends LightningElement {

    fraudCaseId = '';
    serviceCaseId = '';
    nationalId = '';
    phoneNumber = '';
    applicationId = '';
    contractNumber = '';
    accountNumber = '';

    @track records = [];
    @track noResult = false;

    pageNumber = 1;
    pageSize = 10;
    totalRecords = 0;

    sortBy = 'CreatedDate';
    sortDirection = 'DESC';

    // Sorting handler
    handleSort(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;

        console.log('Sorting:', this.sortBy, this.sortDirection);

        this.doSearchFraudCase();
    }

    get totalPages() {
        return Math.ceil(this.totalRecords / this.pageSize);
    }

    get isFirstPage() {
        return this.pageNumber === 1;
    }

    get isLastPage() {
        return this.pageNumber >= this.totalPages;
    }

   columns = [
        { 
            label: 'Fraud Case ID',
            fieldName: 'FraudCaseLink',
            sortable: true,
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'FEC_CaseID__c' },
                target: '_blank'
            }
        },

        {
            label: 'Service Case ID',
            fieldName: 'ServiceCaseLink',
            type: 'url',
            sortable: true,
            typeAttributes: {
                label: { fieldName: 'FEC_Service_Case_ID__c' },
                target: '_blank'
            }
        },

        { label: 'Account Number', fieldName: 'FEC_Account_Number__c', sortable: true },
        { label: 'Fraud Category', fieldName: 'FEC_Category__c', sortable: true },
        { label: 'Fraud Sub Category', fieldName: 'FEC_Sub_Category__c', sortable: true },
        { label: 'Fraud Sub Code', fieldName: 'FEC_Sub_Code__c', sortable: true },
        { label: 'Status of Fraud Case', fieldName: 'FEC_Case_Status__c', sortable: true },
        { label: 'Fraud case created on', fieldName: 'CreatedDate', type: 'text', sortable: true },
        { label: 'Fraud case created by', fieldName: 'CreatedByEmail', sortable: true },
        { label: 'Channel', fieldName: 'FEC_Sys_Channel__c', sortable: true }
    ];


    // Handle search input
    handleChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
    }

    doSearchFraudCase() {
        this.pageNumber = 1; // Reset to page 1
        this.loadData();
    }

    doClear() {
        this.fraudCaseId = '';
        this.serviceCaseId = '';
        this.nationalId = '';
        this.phoneNumber = '';
        this.applicationId = '';
        this.contractNumber = '';
        this.accountNumber = '';

        this.records = [];
        this.noResult = false;
    }

    loadData() {
        searchFraudCases({
            fraudCaseId: this.fraudCaseId,
            nationalId: this.nationalId,
            phoneNumber: this.phoneNumber,
            applicationId: this.applicationId,
            contractNumber: this.contractNumber,
            accountNumber: this.accountNumber,
            pageNumber: this.pageNumber,
            pageSize: this.pageSize,
            sortBy: this.sortBy,
            sortDirection: this.sortDirection
        })
        .then(result => {
            this.records = result.pageRecords;
            this.totalRecords = result.total;
            this.noResult = this.records.length === 0;
        })
        .catch(err => {
            console.error('Search error: ', err);
        });
    }

    nextPage() {
        if (!this.isLastPage) {
            this.pageNumber++;
            this.loadData();
        }
    }

    prevPage() {
        if (!this.isFirstPage) {
            this.pageNumber--;
            this.loadData();
        }
    }
}