import { LightningElement, track } from 'lwc';
import searchFraudCases from '@salesforce/apex/FEC_IntegrationSearchFraudCaseController.searchFraudCases';

// Screen / Input Labels
import LBL_SearchFraudCaseScreen from '@salesforce/label/c.LBL_SearchFraudCaseScreen';
import LBL_FraudCaseID from '@salesforce/label/c.LBL_FraudCaseID';
import LBL_NationalID from '@salesforce/label/c.LBL_NationalID';
import LBL_PhoneNumber from '@salesforce/label/c.LBL_PhoneNumber';
import LBL_ApplicationID from '@salesforce/label/c.LBL_ApplicationID';
import LBL_ContractNumber from '@salesforce/label/c.LBL_ContractNumber';
import LBL_AccountNumber from '@salesforce/label/c.LBL_AccountNumber';
import LBL_SearchHint from '@salesforce/label/c.LBL_HelpSearch';
import LBL_NavigationMode from '@salesforce/label/c.LBL_NavigationMode';
import LBL_SortBy from '@salesforce/label/c.LBL_SortBy';

// Button / Pagination Labels
import LBL_SearchBtn from '@salesforce/label/c.LBL_SearchBtn';
import LBL_ClearBtn from '@salesforce/label/c.LBL_ClearBtn';
import LBL_PrevBtn from '@salesforce/label/c.LBL_PrevBtn';
import LBL_NextBtn from '@salesforce/label/c.LBL_NextBtn';
import LBL_NoRecords from '@salesforce/label/c.LBL_NoRecords';

// Table Column Labels
import LBL_FraudCaseID_Col from '@salesforce/label/c.LBL_FraudCaseID_Col';
import LBL_ServiceCaseID_Col from '@salesforce/label/c.LBL_ServiceCaseID_Col';
import LBL_AccountNumber_Col from '@salesforce/label/c.LBL_AccountNumber_Col';
import LBL_FraudCategory_Col from '@salesforce/label/c.LBL_FraudCategory_Col';
import LBL_FraudSubCategory_Col from '@salesforce/label/c.LBL_FraudSubCategory_Col';
import LBL_FraudSubCode_Col from '@salesforce/label/c.LBL_FraudSubCode_Col';
import LBL_FraudStatus_Col from '@salesforce/label/c.LBL_FraudStatus_Col';
import LBL_FraudCreatedOn_Col from '@salesforce/label/c.LBL_FraudCreatedOn_Col';
import LBL_FraudCreatedBy_Col from '@salesforce/label/c.LBL_FraudCreatedBy_Col';
import LBL_Channel_Col from '@salesforce/label/c.LBL_Channel_Col';



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
    labels = {
        screenTitle: LBL_SearchFraudCaseScreen,
        fraudCaseId: LBL_FraudCaseID,
        nationalId: LBL_NationalID,
        phoneNumber: LBL_PhoneNumber,
        applicationId: LBL_ApplicationID,
        contractNumber: LBL_ContractNumber,
        accountNumber: LBL_AccountNumber,
        searchBtn: LBL_SearchBtn,
        clearBtn: LBL_ClearBtn,
        prevBtn: LBL_PrevBtn,
        nextBtn: LBL_NextBtn,
        helpSearch: LBL_SearchHint,
        noRecords: LBL_NoRecords,
        sortBy: LBL_SortBy,
        navigationMode: LBL_NavigationMode,

        // Table columns
        colFraudCaseID: LBL_FraudCaseID_Col,
        colServiceCaseID: LBL_ServiceCaseID_Col,
        colAccountNumber: LBL_AccountNumber_Col,
        colFraudCategory: LBL_FraudCategory_Col,
        colFraudSubCategory: LBL_FraudSubCategory_Col,
        colFraudSubCode: LBL_FraudSubCode_Col,
        colFraudStatus: LBL_FraudStatus_Col,
        colFraudCreatedOn: LBL_FraudCreatedOn_Col,
        colFraudCreatedBy: LBL_FraudCreatedBy_Col,
        colChannel: LBL_Channel_Col
    };
    

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
            label: LBL_FraudCaseID_Col,
            fieldName: 'FraudCaseUrl',
            sortable: true,
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'FraudCaseDisplay' },
                target: '_blank'
            }
        },

        {
            label: LBL_ServiceCaseID_Col,
            fieldName: 'ServiceCaseLink',
            type: 'url',
            sortable: true,
            typeAttributes: {
                label: { fieldName: 'FEC_Service_Case_ID__c' },
                target: '_blank'
            }
        },

        { label: LBL_AccountNumber_Col, fieldName: 'AccountNumber', sortable: true },
        { label: LBL_FraudCategory_Col, fieldName: 'FEC_Category__c', sortable: true },
        { label: LBL_FraudSubCategory_Col, fieldName: 'FEC_Sub_Category__c', sortable: true },
        { label: LBL_FraudSubCode_Col, fieldName: 'FEC_Sub_Code__c', sortable: true },
        { label: LBL_FraudStatus_Col, fieldName: 'FEC_Case_Status__c', sortable: true },
        { label: LBL_FraudCreatedOn_Col, fieldName: 'CreatedDate', type: 'text', sortable: true },
        { label: LBL_FraudCreatedBy_Col, fieldName: 'CreatedByEmail', sortable: true },
        { label: LBL_Channel_Col, fieldName: 'FEC_Sys_Channel__c', sortable: true }
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
            console.log("reaults: ", result);
            this.records = result.pageRecords.map(row => {        
                const isFH = row.FEC_CaseID__c?.startsWith('FH-');               
                return {
                    ...row,
                    FraudCaseUrl: isFH ? row.FraudCaseLink : row.FraudCaseDisplay,
                    FraudCaseDisplay: row.FraudCaseDisplay
                };
            });
        
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