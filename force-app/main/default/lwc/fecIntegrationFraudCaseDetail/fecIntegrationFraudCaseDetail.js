import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getFraudCaseDetail from '@salesforce/apex/FEC_IntegrationFraudCaseDetailController.getFraudCaseDetail';

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
    @track caseId;
    @track hierarchy = [];
    @track loading = false;
    @track error;

    // Task list (for table)
    @track tasks = [];
    isFraudCase = false;

    dataLoaded = false;
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
    // READ URL PARAM (App Page)
    // ===============================
    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        const caseId = pageRef?.state?.c__caseId;
        if (caseId && caseId.startsWith('FH-')) {
            this.isFraudCase = true;
        }
        if (caseId && !this.dataLoaded) {
            this.caseId = caseId;
            this.dataLoaded = true;
            this.loadData();
        }
    }

    // ===============================
    // LOAD DATA FROM APEX
    // ===============================
    loadData() {
        this.loading = true;
        this.error = null;
    
        getFraudCaseDetail({ caseId: this.caseId })
            .then(res => {
                //console.log('Fraud case detail:', res);
                const hierarchy = res?.hierarchy || [];
    
                this.hierarchy = hierarchy.map(item => ({
                    ...item,
                    caseUrl: `/lightning/r/FEC_Integration_Case__c/${item.Id}/view`,
                    Infos: (item.Infos || []).map(info => {
                        
                        let value = info.FEC_Info_Value__c || info.value;
                        let fieldName = info.FEC_Source_Id__c || info.id;
                        //console.log('fieldName: ', fieldName);
                        //Format Deadline field
                        if (fieldName === 'Deadline' && value) {
                            const year = value.substring(0, 4);
                            const month = value.substring(4, 6);
                            const day = value.substring(6, 8);
                            value = `${day}/${month}/${year}`;
                            //console.log('Deadline: ', value);
                        }
                        //console.log('Deadline: ', value);
    
                        return {
                            id: info.FEC_Source_Id__c || info.id,
                            value,
                            fieldType: info.fileType,
                            isFile: info.fileType === 'file',
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
    // MAIN CASE (ROOT CASE)
    // ===============================
    get mainCase() {
        return this.hierarchy?.[0];
    }

    // ===============================
    // AUTO SPLIT INFOS (COUNT BASED)
    // 10 → 5 | 5
    // 7  → 4 | 3
    // ===============================
    get leftInfos() {
        if (!this.mainCase?.Infos) return [];

        const infos = this.mainCase.Infos;
        const leftSize = Math.ceil(infos.length / 2);
        return infos.slice(0, leftSize);
    }

    get rightInfos() {
        if (!this.mainCase?.Infos) return [];

        const infos = this.mainCase.Infos;
        const leftSize = Math.ceil(infos.length / 2);
        return infos.slice(leftSize);
    }

    // ===============================
    // REMARKS & CONCLUSION
    // (Derived from Infos or main case)
    // ===============================
    get customerRemarks() {
        // Prefer Info record if exists
        const info = this.mainCase?.Infos?.find(
            i => i.id === 'CustomerRemarks' || i.id === 'CSRemark'
        );
        return info?.value || this.mainCase?.FEC_CS_Remark__c || '';
    }

    get fraudConclusion() {        
        return this.mainCase?.FEC_Investigation_Conclusion__c || '';
    }
    // ===============================
    // FILE DOWNLOAD (AUTO)
    // ===============================
    // handleFileDownload(event) {
    //     const rawValue = event.currentTarget.dataset.base64;    
    //     if (!rawValue) {
    //         console.error('File value is empty');
    //         return;
    //     }

    //     const parts = rawValue.split('|');
    //     if (parts.length < 3) {
    //         console.error('Invalid file format');
    //         return;
    //     }

    //     const fileName = parts[0];
    //     const extension = parts[1].toLowerCase();
    //     const base64Data = parts[2];
    //     console.log('fileName: ', fileName);
    //     console.log('extension: ', extension);
    //     const blob = this.base64ToBlob(
    //         base64Data,
    //         this.getMimeType(extension)
    //     );

    //     const url = URL.createObjectURL(blob);
    //     console.log('url: ', url);
    //     const a = document.createElement('a');
    //     a.href = url;
    //     a.download = fileName;
    //     document.body.appendChild(a);
    //     a.click();

    //     setTimeout(() => {
    //         document.body.removeChild(a);
    //         URL.revokeObjectURL(url);
    //     }, 100);
    // }
    handleFileDownload(event) {
        console.log('dataset:', JSON.stringify(event.currentTarget.dataset));
        const rawValue = event.currentTarget.dataset.base64; 
        if (!rawValue) {
            console.error('File value is empty');
            return;
        }
    
        const parts = rawValue.split('|');
        if (parts.length !== 3) {
            console.error('Invalid file format', rawValue);
            return;
        }
    
        const fileName = parts[0];
        const extension = parts[1];
        const contentDocumentId = parts[2];
    
        console.log('fileName:', fileName);
        console.log('extension:', extension);
        console.log('contentDocumentId:', contentDocumentId);
    
        // Native Salesforce file download
        const downloadUrl = `/sfc/servlet.shepherd/document/download/${contentDocumentId}`;
    
        window.open(downloadUrl, '_blank');
    }
    

    base64ToBlob(base64, mimeType) {
        const byteCharacters = atob(base64);
        const byteNumbers = new Uint8Array(byteCharacters.length);

        for (let i = 0; i < byteCharacters.length; i++) {
            byteNumbers[i] = byteCharacters.charCodeAt(i);
        }

        return new Blob([byteNumbers], { type: mimeType });
    }

    getMimeType(ext) {
        switch (ext) {
            case 'pdf':
                return 'application/pdf';
            case 'doc':
                return 'application/msword';
            case 'docx':
                return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
            case 'xls':
                return 'application/vnd.ms-excel';
            case 'xlsx':
                return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
            case 'png':
                return 'image/png';
            case 'jpg':
            case 'jpeg':
                return 'image/jpeg';
            default:
                return 'application/octet-stream';
        }
    }

}