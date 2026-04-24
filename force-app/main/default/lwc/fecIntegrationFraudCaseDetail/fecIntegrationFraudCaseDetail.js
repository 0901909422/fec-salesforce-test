import { LightningElement, wire, track, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

import getFraudCaseDetail from '@salesforce/apex/FEC_IntegrationFraudCaseDetailController.getFraudCaseDetail';
import getIntegrationFieldTypes from '@salesforce/apex/FEC_IntegrationFraudCaseDetailController.getIntegrationFieldTypes';

// Labels
import LBL_FraudCaseDetail from '@salesforce/label/c.LBL_FraudCaseDetail';
import LBL_LoadingFraudCase from '@salesforce/label/c.LBL_LoadingFraudCase';
import LBL_FraudCaseId from '@salesforce/label/c.LBL_FraudCaseID';
import LBL_CaseStatus from '@salesforce/label/c.LBL_CaseStatus';
import LBL_Creator from '@salesforce/label/c.LBL_Creator';
import LBL_Category from '@salesforce/label/c.LBL_Category';
import LBL_SubCategory from '@salesforce/label/c.LBL_SubCategory';
import LBL_SubCode from '@salesforce/label/c.LBL_SubCode';
import LBL_CreateTime from '@salesforce/label/c.LBL_CreateTime';
import LBL_UpdateTime from '@salesforce/label/c.LBL_UpdateTime';
import LBL_DownloadFile from '@salesforce/label/c.LBL_DownloadFile';
import LBL_Remarks from '@salesforce/label/c.LBL_Remarks';
import LBL_Conclusion from '@salesforce/label/c.LBL_Conclusion';
import LBL_TaskList from '@salesforce/label/c.LBL_TaskList';

import LBL_TaskID from '@salesforce/label/c.LBL_TaskID';
import LBL_FraudTaskID from '@salesforce/label/c.LBL_FraudTaskID';
import LBL_TaskName from '@salesforce/label/c.LBL_TaskName';
import LBL_UIC from '@salesforce/label/c.LBL_UIC';
import LBL_Deadline from '@salesforce/label/c.LBL_Deadline';
import LBL_TaskStatus from '@salesforce/label/c.LBL_TaskStatus';
import LBL_CreateTimeTask from '@salesforce/label/c.LBL_CreateTimeTask';
import LBL_UpdateTimeTask from '@salesforce/label/c.LBL_UpdateTimeTask';
import LBL_AppID from '@salesforce/label/c.LBL_AppID';
import LBL_ViolationType from '@salesforce/label/c.LBL_ViolationType';

export default class IntegrationFraudCaseDetail extends LightningElement {

    // ===============================
    // STATE
    // ===============================
    @api fraudHandlingCaseId;
    @track caseId;
    @track hierarchy = [];
    @track tasks = [];
    @track loading = false;
    @track error;

    casePrefixes = {};
    fieldTypes = {};
    isFraudCase = false;
    dataLoaded = false;

    deadlineFile = 'Deadline';
    propertyCustomerRemarks = 'CustomerRemarks';
    propertyCSRemark = 'CSRemark';
    casePrefixesFH = 'FH-';

    labels = {
        fraudCaseDetail: LBL_FraudCaseDetail,
        loading: LBL_LoadingFraudCase,
        fraudCaseId: LBL_FraudCaseId,
        caseStatus: LBL_CaseStatus,
        creator: LBL_Creator,
        category: LBL_Category,
        subCategory: LBL_SubCategory,
        subCode: LBL_SubCode,
        createTime: LBL_CreateTime,
        updateTime: LBL_UpdateTime,
        downloadFile: LBL_DownloadFile,
        remarks: LBL_Remarks,
        conclusion: LBL_Conclusion,
        taskList: LBL_TaskList,
        taskId: LBL_TaskID,
        fraudTaskId: LBL_FraudTaskID,
        taskName: LBL_TaskName,
        uic: LBL_UIC,
        deadline: LBL_Deadline,
        taskStatus: LBL_TaskStatus,
        createTimeTask: LBL_CreateTimeTask,
        updateTimeTask: LBL_UpdateTimeTask,
        appId: LBL_AppID,
        violationType: LBL_ViolationType
    };

    // ===============================
    // LOAD FIELD TYPES
    // ===============================
    connectedCallback() {
        getIntegrationFieldTypes()
            .then(res => {
                this.fieldTypes = res || {};
            })
            .catch(err => {
                console.error('getIntegrationFieldTypes error', err);
            });
    }

   

    // ===============================
    // READ URL PARAM
    // ===============================
    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        if (pageRef && pageRef.state) {
            this.caseId = pageRef.state.c__caseId || this.fraudHandlingCaseId;
             // Safe fraud-case detection (FH / TK / SFT)       
            this.isFraudCase = this.caseId.startsWith(this.casePrefixesFH);
            if (!this.dataLoaded) {                
                this.dataLoaded = true;
                this.loadData();
            }
            
        } else{
            return
        }
           
       
    }

    // ===============================
    // LOAD DATA FROM APEX
    // ===============================
    loadData() {
        this.loading = true;
        this.error = null;

        const caseGetURL = '/lightning/r/FEC_Integration_Case__c/';

        getFraudCaseDetail({ caseId: this.caseId })
            .then(res => {
                const hierarchy = res?.hierarchy || [];
                //console.log('getFraudCaseDetail: ', res);

                this.hierarchy = hierarchy.map(item => ({
                    ...item,
                    caseUrl: `${caseGetURL}${item.Id}/view`,
                    Infos: (item.Infos || []).map(info => {
                        let value = info.FEC_Info_Value__c || info.value;
                        const fieldName = info.FEC_Source_Id__c || info.id;

                        // Format Deadline (YYYYMMDD → DD/MM/YYYY)
                        if (fieldName === this.deadlineFile && value) {
                            value = `${value.substring(6, 8)}/${value.substring(4, 6)}/${value.substring(0, 4)}`;
                        }

                        return {
                            id: fieldName,
                            value,
                            fieldType: info.fileType,
                            isFile: this.fieldTypes?.FILE
                                ? info.fileType === this.fieldTypes.FILE
                                : false,
                            fileName: info.fileName
                        };
                    })
                }));

                this.tasks = res?.tasks || [];
            })
            .catch(err => {
                console.error('getFraudCaseDetail error', err);
                this.error = err?.body?.message || 'Failed to load fraud case detail';
            })
            .finally(() => {
                this.loading = false;
            });
    }

    // ===============================
    // MAIN CASE
    // ===============================
    get mainCase() {
        return this.hierarchy?.[0];
    }

    // ===============================
    // 4-COLUMN INFO LAYOUT
    // ===============================
    get getLayoutColumns() {
        if (!this.mainCase?.Infos) return [];

        const infos = this.mainCase.Infos;
        const columnCount = 4;
        const size = Math.ceil(infos.length / columnCount);

        return Array.from({ length: columnCount }, (_, i) => ({
            key: `col-${i}`,
            items: infos.slice(i * size, (i + 1) * size)
        })).filter(col => col.items.length > 0);
    }

    // ===============================
    // REMARKS & CONCLUSION
    // ===============================
    get customerRemarks() {
        const info = this.mainCase?.Infos?.find(
            i =>
                i.id === this.propertyCustomerRemarks ||
                i.id === this.propertyCSRemark
        );

        return info?.value || this.mainCase?.FEC_CS_Remark__c || '';
    }

    get fraudConclusion() {
        return this.mainCase?.FEC_Investigation_Conclusion__c || '';
    }

    // ===============================
    // FILE DOWNLOAD
    // ===============================
    handleFileDownload(event) {
        const rawValue = event.currentTarget.dataset.base64;
        if (!rawValue) return;

        const [fileName, extension, contentDocumentId] = rawValue.split('|');
        if (!contentDocumentId) return;

        window.open(
            `/sfc/servlet.shepherd/document/download/${contentDocumentId}`,
            '_blank'
        );
    }
}