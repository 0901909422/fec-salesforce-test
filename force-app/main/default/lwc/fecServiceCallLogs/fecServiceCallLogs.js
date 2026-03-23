import { LightningElement, track } from 'lwc';
import searchServiceLogs from '@salesforce/apex/FEC_ServiceCallLogController.searchServiceLogs';
import loadServiceCallLogDetailById from '@salesforce/apex/FEC_ServiceCallLogController.loadServiceCallLogDetailById';



// Screen / Input Labels
import LBL_SearchHint from '@salesforce/label/c.LBL_HelpSearch';
import LBL_NavigationMode from '@salesforce/label/c.LBL_NavigationMode';
import LBL_SortBy from '@salesforce/label/c.LBL_SortBy';

import LBL_SFT_Case_Id from '@salesforce/label/c.LBL_SFT_Case_Id';
import LBL_Service_Call_Logs_OperationName from '@salesforce/label/c.LBL_Service_Call_Logs_OperationName';
import LBL_Service_Call_Logs_Description from '@salesforce/label/c.LBL_Service_Call_Logs_Description';
import LBL_Service_Call_Logs_MessageStatus from '@salesforce/label/c.LBL_Service_Call_Logs_MessageStatus';
import LBL_Service_Call_Logs_CreatedOn from '@salesforce/label/c.LBL_Service_Call_Logs_CreatedOn';
import LBL_Service_Call_Logs_Requestor from '@salesforce/label/c.LBL_Service_Call_Logs_Requestor';

import LBL_Service_Call_Logs_RequestMessage from '@salesforce/label/c.LBL_Service_Call_Logs_RequestMessage';
import LBL_Service_Call_Logs_ResponseMessage from '@salesforce/label/c.LBL_Service_Call_Logs_ResponseMessage';
import LBL_Service_Call_Logs_StartDateTime from '@salesforce/label/c.LBL_Service_Call_Logs_StartDateTime';
import LBL_Service_Call_Logs_EndDateTime from '@salesforce/label/c.LBL_Service_Call_Logs_EndDateTime';
import LBL_Service_Call_Logs_Title from '@salesforce/label/c.LBL_Service_Call_Logs_Title';




// Button / Pagination Labels
import LBL_SearchBtn from '@salesforce/label/c.LBL_SearchBtn';
import LBL_ClearBtn from '@salesforce/label/c.LBL_ClearBtn';
import LBL_PrevBtn from '@salesforce/label/c.LBL_PrevBtn';
import LBL_NextBtn from '@salesforce/label/c.LBL_NextBtn';
import LBL_NoRecords from '@salesforce/label/c.LBL_NoRecords';


// Table Column Labels

import LBL_TotalRecords from '@salesforce/label/c.LBL_TotalRecords';
import LBL_Search_RecordPerPage from '@salesforce/label/c.LBL_Search_RecordPerPage';



export default class ServiceCallLogs extends LightningElement {

    caseID = null;
    operationName = null;
    startDate = null;
    endDate = null;
    startTime = null;
    endTime = null;
    isLoading = false;

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
        //screenTitle: LBL_SearchFraudCaseScreen,
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
        colCaseID: LBL_SFT_Case_Id,
        colOperationName: LBL_Service_Call_Logs_OperationName,
        colDescription: LBL_Service_Call_Logs_Description,
        colMessageStatus: LBL_Service_Call_Logs_MessageStatus,
        colCreatedOn: LBL_Service_Call_Logs_CreatedOn,
        colRequestor: LBL_Service_Call_Logs_Requestor,
        colStartDateTime: LBL_Service_Call_Logs_StartDateTime,
        colEndDateTime: LBL_Service_Call_Logs_EndDateTime,
        colRequestData: LBL_Service_Call_Logs_RequestMessage,
        colResponseData: LBL_Service_Call_Logs_ResponseMessage,
        screenTitle: LBL_Service_Call_Logs_Title
       
    };

    columns = [
        {
            type: 'button-icon',
            fixedWidth: 40,
            typeAttributes: {
                iconName: { fieldName: 'expandIcon' },
                name: 'toggle',
                variant: 'bare',
                alternativeText: 'Expand',
                title: 'Expand'
            }
        },
        { label: this.labels.colCaseID, fieldName:'FEC_Service_Case_Id__c', sortable:true },
        { label: this.labels.colOperationName, fieldName:'FEC_Service_Name__c', sortable:true },
        { label: this.labels.colDescription, fieldName:'FEC_Description__c', sortable:true, type:'text',
        wrapText:true },
        { label: this.labels.colMessageStatus, fieldName:'FEC_Message_Status__c', sortable:true },
        { label: this.labels.colCreatedOn, fieldName:'CreatedDate', sortable:true },
        { label: this.labels.colRequestor, fieldName:'FEC_Requestor__c', sortable:true }
    ];
        

    handlePageSizeChange(event) {
        this.pageSize = event.detail.value; // keep string
        this.pageNumber = 1;
        this.loadData();
    }
    
    handleRowAction(event) {
        const { action, row } = event.detail;
        if (row.isChild) return;
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
            this.loadServiceLogDetail(record.Id)
            .then(result => {

                const childRows = [
                    {
                        Id: record.Id + '_req',
                        isChild: true,
                        hasChildren: false,
                        expandIcon: '',
                        FEC_Service_Name__c: this.labels.colRequestData,
                        FEC_Description__c: result.FEC_Request_Data__c
                    },
                    {
                        Id: record.Id + '_res',
                        isChild: true,
                        hasChildren: false,
                        expandIcon: '',
                        FEC_Service_Name__c: this.labels.colResponseData,
                        FEC_Description__c: result.FEC_Response_Data__c
                    }
                ];

                this.records.splice(index + 1, 0, ...childRows);

                record.childCount = childRows.length;
                record.isExpanded = true;
                record.expandIcon = 'utility:chevrondown';

                this.records = [...this.records];
            })
            .catch(error => {
                console.error('loadServiceLogDetail error:', error);
            });
        }
        //force re-render for collapse
        this.records = [...this.records];
        
    }
    
   
    rowClass(row) {
        return row.isChild ? 'child-row' : '';
    }

    // Sorting handler
    handleSort(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.doSearchServiceCallLogs();
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

   


    // Handle search input
    handleChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
    }

    doSearchServiceCallLogs() {
        this.pageNumber = 1; // Reset to page 1
        this.loadData();
    }

    doClear() {
        this.records = [];
        this.noResult = false;
    
        this.caseID = null;
        this.operationName = null;
    
        this.startDate = null;
        this.startTime = null;
        this.endDate = null;
        this.endTime = null;
    
        this.template.querySelectorAll('lightning-input').forEach(input => {
            input.value = null;
        });
    }
    buildDateTime(date, time) {
        if (!date) return null;    
        const t = time ? time : '00:00';    
        // create ISO format required by Apex
        return `${date}T${t}:00.000Z`;
    }

    loadServiceLogDetail(recordId) {
        this.isLoading = true;
        return loadServiceCallLogDetailById({ recordId: recordId })
        .then(result => {
            console.log("results: ", result);
            return result;
        })
        .catch(err => {
            console.error('Search error: ', err);
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    loadData() {
        this.isLoading = true;
        this.records = [];
        this.noResult = false;
        const startDateTime = this.buildDateTime(this.startDate, this.startTime);
        const endDateTime = this.buildDateTime(this.endDate, this.endTime);
        searchServiceLogs({
            caseId: this.caseID,
            operationName: this.operationName,
            startDate: startDateTime,
            endDate: endDateTime,
            pageNumber: this.pageNumber,
            pageSize: this.pageSize,
            sortBy: this.sortBy,
            sortDirection: this.sortDirection
        })
        .then(result => {
            this.records = result.pageRecords.map(row => ({
                ...row,
                expandIcon: 'utility:chevronright',
                isExpanded: false,
                hasChildren: true
            }));
            this.totalRecords = result.total;
            this.noResult = this.records.length === 0;
        })        
        .catch(err => {
            console.error('Search error: ', err);
        }).finally(() => {
            this.isLoading = false;
        });;
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