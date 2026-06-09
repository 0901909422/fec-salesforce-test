import { LightningElement, track , wire, api} from 'lwc';

import { CurrentPageReference } from 'lightning/navigation';
import { publish, MessageContext } from 'lightning/messageService';
import FRAUD_FIELD_SYNC from '@salesforce/messageChannel/FEC_Fraud_Field_Sync__c';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFraudCaseById from '@salesforce/apex/FEC_IntegrationCreateFraudController.getFraudCaseById';

import getIntegrationFieldTypes 
    from '@salesforce/apex/FEC_IntegrationCreateFraudController.getIntegrationFieldTypes';
import submitUpdateFraudCase from '@salesforce/apex/FEC_IntegrationCreateFraudController.submitUpdateFraudCase';
import loadMasterDataIntegrationMappingById from '@salesforce/apex/FEC_IntegrationCreateFraudController.loadMasterDataIntegrationMappingById';
import loadCategoryMapping from '@salesforce/apex/FEC_IntegrationCreateFraudController.loadCategoryMapping';
import submitCancelFraudCase from '@salesforce/apex/FEC_IntegrationCreateFraudController.submitCancelFraudCase';
import getFileBase64ByDocumentIds from '@salesforce/apex/FEC_IntegrationCreateFraudController.getFileBase64ByDocumentIds';



import Loading from '@salesforce/label/c.Loading';
import User_Type from '@salesforce/label/c.User_Type';
import Int_Channel from '@salesforce/label/c.Int_Channel';
import Int_User_Type from '@salesforce/label/c.Int_User_Type';
import Int_Product_Line from '@salesforce/label/c.Int_Product_Line';
import Int_Service_Type from '@salesforce/label/c.Int_Service_Type';
import Int_Category from '@salesforce/label/c.Int_Category';
import Int_Sub_Category from '@salesforce/label/c.Int_Sub_Category';
import Int_Sub_Code from '@salesforce/label/c.Int_Sub_Code';
import Integrating_Property from '@salesforce/label/c.Integrating_Property';
import Vietnamese_Name from '@salesforce/label/c.Vietnamese_Name';
import Integrating_Property_Type from '@salesforce/label/c.Integrating_Property_Type';
import CSM_Property from '@salesforce/label/c.CSM_Property';
import CSM_Property_Type from '@salesforce/label/c.CSM_Property_Type';
import Auto_Mapping from '@salesforce/label/c.Auto_Mapping';
import Mandatory from '@salesforce/label/c.Mandatory';
import Cancel from '@salesforce/label/c.Cancel';
import Save from '@salesforce/label/c.Save';
import Integration_Mapping_Title from '@salesforce/label/c.Integration_Mapping_Title';
import LBL_Success from '@salesforce/label/c.LBL_Success';
import LBL_Error from '@salesforce/label/c.LBL_Error';
import LBL_SaveSuccess from '@salesforce/label/c.LBL_SaveSuccess';
import LBL_SaveFailed from '@salesforce/label/c.LBL_SaveFailed';
import LBL_UnexpectedError from '@salesforce/label/c.LBL_UnexpectedError';
import LBL_ValidationError from '@salesforce/label/c.LBL_ValidationError';
import LBL_HeaderRequired from '@salesforce/label/c.LBL_HeaderRequired';
import LBL_SelectAtLeastOneRow from '@salesforce/label/c.LBL_SelectAtLeastOneRow';
import LBL_Missing_Required_Fields from '@salesforce/label/c.LBL_Missing_Required_Fields';
import LBL_Fill_Required_Fields from '@salesforce/label/c.LBL_Fill_Required_Fields';
import LBL_Missing_Additional_Properties from '@salesforce/label/c.LBL_Missing_Additional_Properties';
import LBL_Add_Additional_Property from '@salesforce/label/c.LBL_Add_Additional_Property';
import LBL_Create_Fraud_Case_Submission_Failed from '@salesforce/label/c.LBL_Create_Fraud_Case_Submission_Failed';
import LBL_Create_Fraud_Case_Success from '@salesforce/label/c.LBL_Create_Fraud_Case_Success';
import LBL_Cancel_Fraud_Case_Missing_Field from '@salesforce/label/c.LBL_Cancel_Fraud_Case_Missing_Field';
import LBL_Cancel_Fraud_Case_Button from '@salesforce/label/c.LBL_Cancel_Fraud_Case_Button';
import LBL_Create_Fraud_Case_Button from '@salesforce/label/c.LBL_Create_Fraud_Case_Button';
import LBL_DownloadFile from '@salesforce/label/c.LBL_DownloadFile';

import getIntegrationActionModes from '@salesforce/apex/FEC_IntegrationCreateFraudController.getIntegrationActionModes';


export default class IntegrationCreateFraudCase extends LightningElement {

    @api fraudHandlingCaseId;
    @api actionMode;
    @api serviceCaseId;
    @api caseDataId;
    @track caseId;
    @track loading = true;
    @track showPreview = false;
    @track previewJson = '';
    isUpdateSubmitting = false;
    isCancelSubmitting = false;
    @track showCancelConfirm = false;

    @wire(MessageContext)
    messageContext;
    
    fraudIntUserType = '';
    fraudIntChannel = '';
    fraudIntProductLine = '';
    fraudIntServiceType = '';
    fraudIntCategory = '';
    fraudIntSubCategory = '';
    fraudIntSubCode = '';
    intCaseId = '';
    fieldTypes = {};
    actionModes = {};
    createActionType = 'create';
    updateActionType = 'update';
    cancelActionType = 'cancel';


    subCategoriesAll = [];    
    subCodesAll = [];
    @track rows = [];
    get notLoading() { return !this.loading; }
    get showCancelButton() {
        console.log('[DEBUG] showCancelButton — actionMode:', this.actionMode, '| actionModes.EDIT_MODE:', this.actionModes.EDIT_MODE, '| result:', this.actionMode === this.actionModes.EDIT_MODE);
        return this.actionMode === this.actionModes.EDIT_MODE;
    }

    master = null;
    resultMessage = '';

    // FORM VALUES (IDs only)
    selectedSubCategory = null;
    selectedSubCode = null;

    // OPTIONS
    categoryOptions = [];
    subCategoryOptions = [];
    subCodeOptions = [];

    // Additional Props
    @track additionalProps = [];

    // Other fields
    productType = '';
    remarks = '';
    creatorEmail = '';
    fraudCase = '';
    ServiceCaseId = '';
    actionType = this.createActionType; // create | update | cancel
    labels = {
        Integration_Mapping_Title,
        Loading,
        User_Type,
        Int_Channel,
        Int_User_Type,
        Int_Product_Line,
        Int_Service_Type,
        Int_Category,
        Int_Sub_Category,
        Int_Sub_Code,
        Integrating_Property,
        Vietnamese_Name,
        Integrating_Property_Type,
        CSM_Property,
        CSM_Property_Type,
        Auto_Mapping,
        Mandatory,
        Cancel,
        Save,
        success: LBL_Success,
        error: LBL_Error,
        saveSuccess: LBL_SaveSuccess,
        saveFailed: LBL_SaveFailed,
        unexpectedError: LBL_UnexpectedError,
        validationError: LBL_ValidationError,
        headerRequired: LBL_HeaderRequired,
        selectAtLeastOneRow: LBL_SelectAtLeastOneRow,
        missingRequiredTitle: LBL_Missing_Required_Fields,
        missingRequiredMsg: LBL_Fill_Required_Fields,
        missingAdditionalTitle: LBL_Missing_Additional_Properties,
        missingAdditionalMsg: LBL_Add_Additional_Property,
        responseSuccess: LBL_Create_Fraud_Case_Success,
        responseFailed: LBL_Create_Fraud_Case_Submission_Failed,
        missingRequiredCancel: LBL_Cancel_Fraud_Case_Missing_Field,
        Create_Fraud_Case_Button: LBL_Create_Fraud_Case_Button,
        Cancel_Fraud_Case_Button: LBL_Cancel_Fraud_Case_Button,
        downloadFile: LBL_DownloadFile
    };
   

    connectedCallback() {
        getIntegrationActionModes()
            .then(res => { this.actionModes = res || {}; })
            .catch(err => { console.error('getIntegrationActionModes error', err); });
    }

    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        if (pageRef && pageRef.state) {
            this.caseId = pageRef.state.c__caseId || this.fraudHandlingCaseId;
        } else {
            this.loading = false;
            return;
        }        
        console.log('this.caseId: ', this.caseId);
         // Load case data
         this.loadIntegrationCaseInfo(this.caseId);
    }
    
    
    async loadIntegrationCaseInfo(recordId) {
        try {
            this.fieldTypes = await getIntegrationFieldTypes();    
            const caseData = await getFraudCaseById({ fraudCaseId: recordId });   
            console.log('caseData: ', JSON.stringify(caseData));
            const infoList = caseData.propertyValues || [];
    
            this.fraudIntChannel = caseData.intChannel;
            this.fraudIntUserType = caseData.intUserType;
            this.fraudIntProductLine = caseData.intProductLine;
            this.fraudIntServiceType = caseData.intServiceType;
            this.fraudIntCategory = caseData.intCategory;
            this.fraudIntSubCategory = caseData.intSubCategory;
            this.fraudIntSubCode = caseData.intSubCode;
            this.ServiceCaseId = caseData.serviceCaseId;
            this.fraudCase = caseData.fraudCaseId;
            this.remarks = caseData.csRemarks;
            this.category = caseData.intCategory;
            this.subCategory = caseData.intSubCategory;
            this.subCode = caseData.intSubCode;
            this.intCaseId = caseData.intCaseId;
    
            const resultData = await loadCategoryMapping({
                channelCode: this.fraudIntChannel
            });
            
            this.categoryAll = (resultData.categoryAll || []).map(item => ({
                label: item.displayName,
                value: item.value,
                mappingId: item.mappingId
            }));
    
            this.subCategoriesAll = (resultData.subCategoriesAll || []).map(item => ({
                label: item.displayName,
                value: item.value,
                parentId: item.parentId,
                mappingId: item.mappingId
            }));
    
            this.subCodesAll = (resultData.subCodesAll || []).map(item => ({
                label: item.displayName,
                value: item.value,
                parentId: item.parentId,
                mappingId: item.mappingId
            }));
            this.categoryOptions = this.categoryAll.map(sc => ({
                label: sc.label,
                value: sc.value
            }));
    
            this.subCategoryOptions = this.subCategoriesAll
                .filter(sc => sc.parentId === this.fraudIntCategory)
                .map(sc => ({
                    label: sc.label,
                    value: sc.value
                }));
    
            this.subCodeOptions = this.subCodesAll
                .filter(sc => sc.parentId === this.fraudIntSubCategory)
                .map(sc => ({
                    label: sc.label,
                    value: sc.value
                }));
         
            this.loadAdditionalProps(infoList);
    
        } catch (error) {
            console.error('[ERROR] loadIntegrationCaseInfo', error);
        }
        finally {
            this.loading = false;
        }
    }

    loadMasterDataIntegrationMapping(mappingId) {
        console.log('[CALL] loadMasterDataIntegrationMapping:', mappingId);
        loadMasterDataIntegrationMappingById({
            integrationMappingId: mappingId
        })
        .then(data => {
            console.log('[SUCCESS] loadMasterDataIntegrationMapping list:', data);
            this.fraudIntChannel = data.intChannel;
            this.fraudIntUserType = data.intUserType;
            this.fraudIntProductLine = data.intProductLine;
            this.fraudIntServiceType = data.intServiceType;
            this.fraudIntCategory = data.intCategory;
            this.fraudIntSubCategory = data.intSubCategory;
            this.fraudIntSubCode = data.intSubCode;            
            this.loadAdditionalProps(data.propertyValues);
        })
        .catch(err => {
            console.error('[ERROR] loadMasterDataIntegrationMapping:', err);
            throw err; // important for Promise.all
        });
    }
   


    loadAdditionalProps(responseData) {
        const list = Array.isArray(responseData) ? responseData : [];
        console.log('[loadAdditionalProps] fieldTypes:', JSON.stringify(this.fieldTypes));
        
        this.additionalProps = list.map(p => {
            const type = p.type?.trim().toLowerCase();
            console.log('[loadAdditionalProps] prop:', p.displayName, 'type:', type, 'fieldTypes.FILE:', this.fieldTypes.FILE);
            let fileName = null;
            if(type == this.fieldTypes.FILE?.toLowerCase()) {
                if (p.value && p.value.includes('|')) {
                    const parts = p.value.split('|');
                    fileName = parts[0];
                    console.log('this.additionalProps-fileName:', fileName);
                } else if (p.value) {
                    fileName = p.value;
                    console.log('this.additionalProps-fileName (no pipe):', fileName);
                } else {
                    console.log('p.value is empty:', p.value);
                }
            }
           
    
            const isFileType = type === this.fieldTypes.FILE?.toLowerCase();
            const fileHasValue = isFileType && !!fileName;

            return {
                ...p,
                type,    
                // type flags
                isString: type === this.fieldTypes.STRING?.toLowerCase(),
                isMulti: type === this.fieldTypes.MULTI?.toLowerCase(),
                isDate: type === this.fieldTypes.DATE?.toLowerCase(),
                isFile: isFileType,
                isFileWithValue: isFileType && !!p.value,
                isFileWithoutValue: isFileType && !p.value,
                isNumber: type === this.fieldTypes.NUMBER?.toLowerCase(),
                isBoolean: type === this.fieldTypes.BOOLEAN?.toLowerCase(),
                isPicklist: type ===  this.fieldTypes.PICKLIST?.toLowerCase(),
                isList: type ===  this.fieldTypes.LIST?.toLowerCase(),
                fileName: fileName,
                // Skip HTML required for file inputs that already have data loaded from server
                fileRequired: isFileType && p.mandatory && !fileHasValue,
    
                options: (p.availableValues || []).map(v => ({
                    label: v.displayName,
                    value: v.property
                }))
            };
        });
        //console.log('this.additionalProps:',JSON.stringify(this.additionalProps));
    }
    getSubCategoryByValue(value) {
        return this.subCategoriesAll.find(sc => sc.value === value);
    }
    
    getSubCodeByValue(value) {
        return this.subCodesAll.find(sc => sc.value === value);
    }
    
    


    // OTHER FIELD CHANGES
    @api
    setFieldValue(fieldId, value) {
        console.log('[fecIntegrationUpdateFraudCase] setFieldValue:', fieldId, value, '| props count:', this.additionalProps?.length, '| matched:', this.additionalProps?.some(p => p.id === fieldId || p.property === fieldId));
        this.additionalProps = this.additionalProps.map(p =>
            (p.id === fieldId || p.property === fieldId)
                ? { ...p, value }
                : p
        );
    }

    onSimpleChange(event) {
        const field = event.target.dataset.field;
        if (field) {
            this[field] = event.detail.value;
            console.log(`[SET] ${field}:`, this[field]);
        }
    }

    onFieldChange(event) {
        const fieldId = event.target.dataset.id;
        console.log('onFieldChange: ', fieldId);
    
        const value =
            event.target.type === 'checkbox'
                ? event.target.checked
                : event.detail.value;
        console.log('onFieldChange: ', value);
    
        this.additionalProps = this.additionalProps.map(p =>
            p.id === fieldId
                ? { ...p, value }
                : p
        );

        // Publish fraud→case sync via LMS
        const prop = this.additionalProps.find(p => p.id === fieldId);
        if (prop && prop.property) {
            publish(this.messageContext, FRAUD_FIELD_SYNC, {
                fieldId: prop.property,
                value: value,
                source: 'fraud'
            });
        }
    }

    // -------------------------------------------------------------------
    // FILE HANDLING
    // -------------------------------------------------------------------
    onFileChange(event) {
        const fieldId = event.target.dataset.id;
        const file = event.target.files[0];
        if (!file) return;
    
        const reader = new FileReader();
        reader.onload = () => {
            const base64 = reader.result.split(',')[1];
            const fileName = file.name;
            const fileType = fileName.split('.').pop();
    
            const combinedValue = `${fileName}|${fileType}|${base64}`;
    
            this.additionalProps = this.additionalProps.map(p =>
                p.id === fieldId
                    ? {
                        ...p,
                        value: combinedValue,
                        base64,
                        fileName
                    }
                    : p
            );
        };
    
        reader.readAsDataURL(file);
    }

    // -------------------------------------------------------------------
    // BUILD PAYLOAD — USE ID INSTEAD OF NAME
    // -------------------------------------------------------------------
    async buildPayload() {
        const additionalInfoPayload = this.additionalProps
            .map(p => ({
                ID: p.property,
                Value: p.value !== null && p.value !== undefined
                    ? String(p.value)
                    : '',
                FileName: p.fileName || null,
                Type: p.type
            }));

        // Resolve ContentDocument IDs to base64 for file types
        const fileItems = additionalInfoPayload.filter(p => p.Type === this.fieldTypes.FILE?.toLowerCase() && p.Value);
        const docIds = [];
        for (const item of fileItems) {
            const parts = item.Value.split('|');
            if (parts.length === 3) {
                const possibleId = parts[2];
                // ContentDocument IDs are 15 or 18 chars starting with '069'
                if (possibleId && possibleId.startsWith('069') && (possibleId.length === 15 || possibleId.length === 18)) {
                    docIds.push(possibleId);
                }
            }
        }

        if (docIds.length > 0) {
            const base64Map = await getFileBase64ByDocumentIds({ documentIds: docIds });
            for (const item of fileItems) {
                const parts = item.Value.split('|');
                if (parts.length === 3 && base64Map[parts[2]]) {
                    item.Value = parts[0] + '|' + parts[1] + '|' + base64Map[parts[2]];
                }
            }
        }
    
        return {
            CaseType: this.fraudIntServiceType,
            ProductType: this.fraudIntProductLine,
            Category: this.category,
            SubCategory: this.subCategory,
            SubCode: this.subCode,
            Remarks: this.remarks,
            UserType: this.fraudIntUserType,
            CreatorEmail: this.creatorEmail,
            FraudCaseId: this.fraudCase,
            ServiceCaseId: this.ServiceCaseId,
            IntCaseId: this.intCaseId,
            AdditionalInfo: additionalInfoPayload
        };
    }

    // -------------------------------------------------------------------
    // PREVIEW + SUBMIT
    // -------------------------------------------------------------------

    async onSubmitCancel() {
        if (this.isCancelSubmitting) return;
        this.showCancelConfirm = true;
    }

    closeCancelConfirm() {
        this.showCancelConfirm = false;
    }

    async confirmCancelFraudCase() {
        this.showCancelConfirm = false;
        this.loading = true;
        this.isCancelSubmitting = true;
        try {
            const payload = await this.buildPayload();    
            const serviceCaseId = payload?.ServiceCaseId;
            const fraudCaseId = payload?.FraudCaseId;    
            if (!serviceCaseId || !fraudCaseId) {
                this.showErrorToast(
                    this.labels.missingRequiredTitle,
                    this.labels.missingRequiredCancel
                );
                this.loading = false;
                this.isCancelSubmitting = false;
                return;
            }
    
            this.previewJson = JSON.stringify(payload, null, 2);
            this.actionType = this.cancelActionType;    
            await this.confirmSubmit(); //wait until finished
        } catch (error) {
            this.showErrorToast('Error', error?.body?.message || error.message);
        } finally {
            this.loading = false; //unlock only when everything finishes
            this.isCancelSubmitting = false;
        }
    }
    
    async onSubmit() {

        if (this.isUpdateSubmitting) return; // extra protection against double click   
        this.isUpdateSubmitting = true;   
        this.loading = true;  
        //Validate standard lightning inputs
        const allInputs = this.template.querySelectorAll(
            'lightning-input, lightning-combobox, lightning-textarea'
        );
    
        let isValid = true;
        let firstInvalid = null;

        // Collect file field IDs that already have data loaded from server
        const fileFieldsWithData = new Set(
            this.additionalProps
                .filter(p => p.isFile && p.fileName)
                .map(p => p.id)
        );
    
        allInputs.forEach(el => {
            // Skip validation for file inputs that already have data
            if (el.type === 'file' && fileFieldsWithData.has(el.dataset.id)) {
                return;
            }
            if (!el.checkValidity()) {
                el.reportValidity();
                isValid = false;
    
                if (!firstInvalid) {
                    firstInvalid = el;
                }
            }
        });
    
        //Validate dynamic additional properties
        const missingDynamic = this.additionalProps.filter(p => {
    
            if (!p.mandatory) return false;
    
            if (p.isBoolean) {
                return p.value !== true;
            }
    
            if (p.isFile) {
                return !p.fileName;
            }
    
            return !p.value || p.value === '';
        });
    
        if (missingDynamic.length > 0) {
            isValid = false;
    
            const firstMissing = missingDynamic[0];
            const el = this.template.querySelector(
                `[data-id="${firstMissing.id}"]`
            );
    
            if (el) {
                el.reportValidity?.();
                firstInvalid = el;
            }
        }
    
        if (!isValid) {
            if (firstInvalid) {
                firstInvalid.scrollIntoView({
                    behavior: 'smooth',
                    block: 'center'
                });
            }
    
            this.showErrorToast(
                this.labels.missingRequiredTitle,
                this.labels.missingRequiredMsg
            );
            this.loading = false;
            this.isUpdateSubmitting = false;   
            return;
        }
    
        if (this.additionalProps.length === 0) {
            this.showErrorToast(
                this.labels.missingAdditionalTitle,
                this.labels.missingAdditionalMsg
            );
            this.loading = false;
            this.isUpdateSubmitting = false;   
            return;
        }
    
        // =============================
        // PROCESSING STARTS HERE
        // =============================    
        try {
            const payload = await this.buildPayload();
            this.previewJson = JSON.stringify(payload, null, 2);
            //this.showPreview = true;
    
            this.actionType = this.updateActionType;        
            console.log('onSUbmit: ', this.previewJson);  
            await this.confirmSubmit();
            
            
        } catch (error) {
            this.showErrorToast(
                'Error',
                error?.body?.message || error.message
            );
        } finally {
            this.loading = false;
            this.isUpdateSubmitting = false;   
        }
    }

    showSuccessToast(title, message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: 'success',
                mode: 'dismissable'
            })
        );
    }
    
    showErrorToast(title, message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: 'error',
                mode: 'sticky' // stays until user closes
            })
        );
    }

    async confirmSubmit() {
        let payload;
    
        try {
            payload = JSON.parse(this.previewJson);
        } catch (e) {
            //this.showPreview = false;
            //return;
        }
       
        let actionPromise;
       
        if (this.actionType === this.cancelActionType) {
            actionPromise = await submitCancelFraudCase({ payload });
        } 
        else if (this.actionType === this.updateActionType) {
            actionPromise = await submitUpdateFraudCase({ payload });
        }        
        if (actionPromise && actionPromise.success) {
            this.showSuccessToast(
                this.labels.responseSuccess,
                actionPromise.message
            );
            // Notify parent to reload
            this.dispatchEvent(new CustomEvent('fraudcasesuccess', {
                detail: { message: actionPromise.message },
                bubbles: true,
                composed: true
            }));
        } else {
            this.showErrorToast(
                this.labels.responseFailed,
                actionPromise.message
            );
        }
    
        this.resultMessage = actionPromise?.message;
    
    }
    

    cancelPreview() {
        this.showPreview = false;
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