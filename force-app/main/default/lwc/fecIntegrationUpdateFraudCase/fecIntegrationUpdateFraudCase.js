import { LightningElement, track , wire} from 'lwc';

import { CurrentPageReference } from 'lightning/navigation';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFraudCaseById from '@salesforce/apex/FEC_IntegrationCreateFraudController.getFraudCaseById';

import getIntegrationFieldTypes 
    from '@salesforce/apex/FEC_IntegrationCreateFraudController.getIntegrationFieldTypes';
import submitUpdateFraudCase from '@salesforce/apex/FEC_IntegrationCreateFraudController.submitUpdateFraudCase';
import loadMasterDataIntegrationMappingById from '@salesforce/apex/FEC_IntegrationCreateFraudController.loadMasterDataIntegrationMappingById';
import loadCategoryMapping from '@salesforce/apex/FEC_IntegrationCreateFraudController.loadCategoryMapping';
import submitCancelFraudCase from '@salesforce/apex/FEC_IntegrationCreateFraudController.submitCancelFraudCase';



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



export default class IntegrationCreateFraudCase extends LightningElement {

    @track caseId;
    @track loading = true;
    @track showPreview = false;
    @track previewJson = '';
    isUpdateSubmitting = false;
    isCancelSubmitting = false;
    
    fraudIntUserType = '';
    fraudIntChannel = '';
    fraudIntProductLine = '';
    fraudIntServiceType = '';
    fraudIntCategory = '';
    fraudIntSubCategory = '';
    fraudIntSubCode = '';
    fieldTypes = {};
    createActionType = 'create';
    updateActionType = 'update';
    cancelActionType = 'cancel';


    subCategoriesAll = [];    
    subCodesAll = [];
    @track rows = [];
    get notLoading() { return !this.loading; }

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
        //this.loading = true;   
    }

    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        const caseId = pageRef?.state?.c__caseId;        
        if (!caseId || this.caseId === caseId) {
            this.loading = false;
            return;
        }
        this.caseId = caseId;        
        console.log('this.caseId: ', this.caseId);
         // Load case data
         this.loadIntegrationCaseInfo(this.caseId);
    }
    
    
    async loadIntegrationCaseInfo(recordId) {
        try {
            this.fieldTypes = await getIntegrationFieldTypes();    
            const caseData = await getFraudCaseById({ fraudCaseId: recordId });   
            //console.log('caseData: ', JSON.stringify(caseData));
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
   

    /* ================= CATEGORY CHANGE ================= */

    handleCategory(e) {
        this.category = e.detail.value;
        this.additionalProps = [];
        console.log('[CHANGE] Category:', this.category);
    
        this.subCategory = null;
        this.subCode = null;
    
        this.subCategoryOptions = this.subCategoriesAll
            .filter(sc => sc.parentId === this.category)
            .map(sc => ({
                label: sc.label,
                value: sc.value
            }));
    
        this.subCodeOptions = [];
        this.rows = [];
    }
    
      
    /* ================= SUB CATEGORY CHANGE ================= */

    handleSubCategory(e) {
        this.subCategory = e.detail.value;   
        this.additionalProps = []; 
        this.subCode = null;
        this.subCodeOptions = [];    
        this.subCodeOptions = this.subCodesAll
            .filter(sc => sc.parentId === this.subCategory)
            .map(sc => ({
                label: sc.label,
                value: sc.value
            }));    
        //If no subcode → load mapping at SubCategory level
        if (this.subCodeOptions.length === 0) {
            // find selected subcategory
            const selectedSubCat = this.getSubCategoryByValue(this.subCategory);
            let mappingId = selectedSubCat?.mappingId ?? null;        
            // If SubCategory mapping not found → fallback to Category
            if (mappingId == null) {                
                const selectedCat = this.categoryOptions.find(sc => sc.value === this.category);   
                mappingId = selectedCat?.mappingId ?? null;
            }
        
            // Load only if mappingId exists
            if (mappingId != null) {
                this.loadMasterDataIntegrationMapping(mappingId);
            }
        }
        
        
    }
    

    /* ================= SUB CODE CHANGE ================= */

    handleSubCode(e) {
        this.subCode = e.detail.value;
        this.additionalProps = [];
        console.log('[CHANGE] SubCode:', this.subCode);
        const selectedSubCode = this.subCodesAll.find(
            sc => sc.value === this.subCode
        );
    
        let mappingId = selectedSubCode?.mappingId || null;
        if(mappingId == null) {
            //Get mapping at SubCategory level
            const selectedSubCat = this.getSubCategoryByValue(this.subCategory);
            mappingId = selectedSubCat?.mappingId || null;
            if(mappingId == null) {
                //Get mapping at Category level               
                const selectedCat = this.categoryOptions.find(
                    sc => sc.value === this.category
                );
                mappingId = selectedCat?.mappingId || null;
            }
        }
        console.log('[LOAD] Mapping at handleSubCode:', mappingId);
        if(mappingId != null) {
            this.loadMasterDataIntegrationMapping(mappingId);
        }    
    }


    loadAdditionalProps(responseData) {
        const list = Array.isArray(responseData) ? responseData : [];
        
        this.additionalProps = list.map(p => {
            const type = p.type?.trim().toLowerCase();
            let fileName = null;
            if(type == this.fieldTypes.FILE) {
                if (p.value && p.value.includes('|')) {
                    const [fileName, extension, contentDocumentId] = p.value.split('|');
                    console.log('this.additionalProps-fileName:', fileName);
                } else {
                    console.log('p.value does not contain "|" :', p.value);
                }
            }
           
    
            return {
                ...p,
                type,    
                // type flags
                isString: type === this.fieldTypes.STRING,
                isMulti: type === this.fieldTypes.MULTI,
                isDate: type === this.fieldTypes.DATE,
                isFile: type === this.fieldTypes.FILE,
                isNumber: type === this.fieldTypes.NUMBER,
                isBoolean: type === this.fieldTypes.BOOLEAN,
                isPicklist: type ===  this.fieldTypes.PICKLIST,
                isList: type ===  this.fieldTypes.LIST,
                fileName: fileName,
    
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
    buildPayload() {
        const additionalInfoPayload = this.additionalProps
            .filter(p => {
                if (p.type === this.fieldTypes.FILE) {
                    return !!p.fileName;
                }
                if (p.isBoolean) {
                    return p.value !== null && p.value !== undefined;
                }
            
                return p.value !== null && p.value !== undefined && p.value !== '';
            })
            .map(p => ({
                ID: p.property,
                Value: p.value !== null && p.value !== undefined
                    ? String(p.value)
                    : null,
                FileName: p.fileName || null,
                Type: p.type
            }));
    
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
            AdditionalInfo: additionalInfoPayload
        };
    }

    // -------------------------------------------------------------------
    // PREVIEW + SUBMIT
    // -------------------------------------------------------------------

    async onSubmitCancel() {
        if (this.isCancelSubmitting) return;
        this.loading = true;
        this.isCancelSubmitting = true;
        try {
            const payload = this.buildPayload();    
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
    
        allInputs.forEach(el => {
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
            const payload = this.buildPayload();
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