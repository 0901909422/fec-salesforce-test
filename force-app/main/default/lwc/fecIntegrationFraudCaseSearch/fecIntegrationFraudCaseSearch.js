import { LightningElement, track } from 'lwc';
import searchFraudCases from '@salesforce/apex/FEC_IntegrationSearchFraudCaseController.searchFraudCases';
import getFraudSubCases from '@salesforce/apex/FEC_IntegrationSearchFraudCaseController.getFraudSubCases';


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
import LBL_TotalRecords from '@salesforce/label/c.LBL_TotalRecords';
import LBL_Search_RecordPerPage from '@salesforce/label/c.LBL_Search_RecordPerPage';



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
    pageSizeOptions = [
        { label: '10', value: '10' },
        { label: '20', value: '20' },
        { label: '30', value: '30' },
        { label: '50', value: '50' }
    ];
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
        totalRecords: LBL_TotalRecords,
        recordsPerPage: LBL_Search_RecordPerPage,

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

    handlePageSizeChange(event) {
        this.pageSize = event.detail.value; // keep string
        this.pageNumber = 1;
        this.loadData();
    }
    
    handleRowAction(event) {
        const { action, row } = event.detail;
    
        if (action.name !== 'toggle') return;
    
        const index = this.records.findIndex(r => r.Id === row.Id);
        if (index === -1) return;
    
        const record = this.records[index];
    
        // Do nothing if no children
        if (!record.hasChildren) return;
    
        if (record.isExpanded) {
            // COLLAPSE
            this.records.splice(index + 1, record.childCount);
            record.isExpanded = false;
            record.expandIcon = 'utility:chevronright';
        } else {
            // EXPAND
            this.loadSubCases(record).then(result => {
                const children = result.pageRecords || [];
                const childRows = children.map(child => ({
                    ...child,
                    isChild: true,
                    hasChildren: false,
                    isExpanded: false,
                    expandIcon: '',
                    FraudCaseUrl: child.FraudCaseLink,
                    displayLabel: '    ↳ ' + child.FraudCaseDisplay,
                }));
    
                this.records.splice(index + 1, 0, ...childRows);
    
                record.childCount = childRows.length;
                record.isExpanded = true;
                record.expandIcon = 'utility:chevrondown';
    
                //force re-render
                this.records = [...this.records];
            });
            return; // important
        }
    
        //force re-render for collapse
        this.records = [...this.records];
    }
    
    
    loadSubCases(parentRow) {
        //console.log('loadSubCases: ', JSON.stringify(parentRow));
        return getFraudSubCases({ fraudCaseId: parentRow.FEC_CaseID__c });
    }
    rowClass(row) {
        return row.isChild ? 'child-row' : '';
    }

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
            label: '',
            type: 'button-icon',
            initialWidth: 40,
            typeAttributes: {
                iconName: { fieldName: 'expandIcon' },
                name: 'toggle',
                variant: 'bare',
                alternativeText: 'Expand'
            }
        },
        { 
            label: LBL_FraudCaseID_Col,
            fieldName: 'FraudCaseUrl',
            sortable: true,
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'displayLabel' },
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
            const childCountMap = result.childCountMap || {};
            this.records = result.pageRecords.map(row => {        
                const childCount = childCountMap[row.FEC_CaseID__c] || 0;
                return {
                    ...row,
                    FraudCaseUrl: row.FraudCaseLink,
                    FraudCaseDisplay: row.FraudCaseDisplay,
                    isExpanded: false,
                    childCount: 0,
                    hasChildren: childCount > 0,
                    expandIcon: childCount > 0 ? 'utility:chevronright' : '',
                    isChild: false,
                    displayLabel: row.FraudCaseDisplay
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