import { LightningElement, api, track } from 'lwc';
import LightningModal from 'lightning/modal'; // 👈 Sử dụng LightningModal cho popup giữa màn hình
import saveNewLookupNode from '@salesforce/apex/FEC_NatureOfCaseTreeController.saveNewLookupNode';
import getNextPosOrder from '@salesforce/apex/FEC_NatureOfCaseTreeController.getNextPosOrder'; // Import mới
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { showLog } from 'c/fecMDMUtils';
import LABEL_LABEL_CUSTOMERTYPE from '@salesforce/label/c.FEC_Label_CustomerType';
import LABEL_FIELD_ID from '@salesforce/label/c.FEC_Label_Field_ID';
import LABEL_ALIAS from '@salesforce/label/c.FEC_Label_Alias';
import LABEL_NAME_EN from '@salesforce/label/c.FEC_Label_Name_EN';
import LABEL_NAME_VN from '@salesforce/label/c.FEC_Label_Name_VN';
import LABEL_ORDER from '@salesforce/label/c.FEC_Label_Order';
import LABEL_STATUS from '@salesforce/label/c.FEC_Label_Status';
import LABEL_BUTTON_SAVEANDNEW from '@salesforce/label/c.FEC_Button_SaveAndNew';
import LABEL_CUSTOMERTYPE_EXISTING from '@salesforce/label/c.FEC_Label_CustomerType_Existing';
import LABEL_CUSTOMERTYPE_NONEXISTING from '@salesforce/label/c.FEC_Label_CustomerType_NonExisting';
import LABEL_CUSTOMERTYPE_ALL from '@salesforce/label/c.FEC_Label_CustomerType_All';
import LABEL_MODAL_ADD_NEW_NODE from '@salesforce/label/c.FEC_Label_Add_New_Node';
import LABEL_FOR from '@salesforce/label/c.FEC_Label_For';
import LABEL_ROOT from '@salesforce/label/c.FEC_Label_Root';
import LABEL_SUCCESS_ADD from '@salesforce/label/c.LABEL_SUCCESS_ADD';
import LABEL_ERROR_SAVE_LOOKUP from '@salesforce/label/c.LABEL_ERROR_SAVE_LOOKUP';
import LABEL_TOAST_VALIDATION_TITLE from '@salesforce/label/c.FEC_Toast_Validation_Title';
import LABEL_TOAST_VALIDATION_MESSAGE from '@salesforce/label/c.FEC_Toast_Validation_Message';
import LABEL_TOAST_SAVE_SUCCESS_TITLE from '@salesforce/label/c.FEC_Toast_Save_Success_Title';
import LABEL_BUTTON_CANCEL from '@salesforce/label/c.FEC_Button_Cancel';
import LABEL_BUTTON_SAVE from '@salesforce/label/c.FEC_Button_Save';
import LABEL_UNKNOWN_ERROR from '@salesforce/label/c.FEC_Unknown_Error';
import { FIELD_CODE, FIELD_ALIAS, FIELD_NAME, FIELD_NAME_VN, FIELD_POS_ORDER, FIELD_STATUS, FIELD_CUSTOMER_TYPE, CUST_TYPE_ALL, CUST_TYPE_EXISTING, CUST_TYPE_NON_EXISTING, VARIANT_SUCCESS, VARIANT_ERROR, FIELD_PRODUCT_TYPE_NAME, FIELD_BUSINESS_PROCESS_NAME, FIELD_CATEGORY_NAME, FIELD_SUB_CATEGORY_NAME, OBJ_PRODUCT_TYPE, OBJ_BUSINESS_PROCESS, OBJ_CATEGORY, OBJ_SUB_CATEGORY, OBJ_SUB_CODE } from 'c/fecConstants';

/**
 * Tên LWC: fecNatureOfCaseModal
 */
export default class FecNatureOfCaseModal extends LightningModal {
    @api parentId;
    @api objectType;
    @api parentLabel;

    @track strName = '';
    @track strAlias = '';
    @track strCode = '';
    @track strNameVN = '';
    @track intPosOrder;
    @track isStatus = true;
    @api parentCustomerType; // Thêm biến này để nhận Customer Type từ Tree truyền vào

    @track customerTypeValue = CUST_TYPE_ALL;

    // expose labels for template binding
    labelCustomerType = LABEL_LABEL_CUSTOMERTYPE;
    labelFieldId = LABEL_FIELD_ID;
    labelAlias = LABEL_ALIAS;
    labelNameEn = LABEL_NAME_EN;
    labelNameVn = LABEL_NAME_VN;
    labelOrder = LABEL_ORDER;
    labelStatus = LABEL_STATUS;
    labelSaveAndNew = LABEL_BUTTON_SAVEANDNEW;
    labelModalAddNew = LABEL_MODAL_ADD_NEW_NODE;
    labelFor = LABEL_FOR;
    labelRoot = LABEL_ROOT;
    labelCancel = LABEL_BUTTON_CANCEL;
    labelSave = LABEL_BUTTON_SAVE;

    connectedCallback() {
        this.isRootNode = (this.objectType === OBJ_PRODUCT_TYPE);

        // Nếu không phải Root, mặc định lấy Customer Type của cha
        if (!this.isRootNode) {
            this.customerTypeValue = this.parentCustomerType;
        }
        this.fetchNextOrder();
    }

    get customerTypeOptions() {
        return [
            { label: LABEL_CUSTOMERTYPE_EXISTING, value: CUST_TYPE_EXISTING },
            { label: LABEL_CUSTOMERTYPE_NONEXISTING, value: CUST_TYPE_NON_EXISTING },
            { label: LABEL_CUSTOMERTYPE_ALL, value: CUST_TYPE_ALL }
        ];
    }

    handleCustomerTypeChange(event) {
        this.customerTypeValue = event.detail.value;
    }

    get isShowCustomerType() {
        return this.isRootNode; // Chỉ hiện combobox cho Product Type
    }

    async fetchNextOrder() {
        let lookupFieldName = '';

        // Logic Mapping: Tạo node con thì phải tìm dựa trên trường cha
        switch (this.objectType) {
            case OBJ_BUSINESS_PROCESS:
                lookupFieldName = FIELD_PRODUCT_TYPE_NAME; // Tìm các BP chung Product Type
                break;
            case OBJ_CATEGORY:
                lookupFieldName = FIELD_BUSINESS_PROCESS_NAME; // Tìm các Cat chung BP
                break;
            case OBJ_SUB_CATEGORY:
                lookupFieldName = FIELD_CATEGORY_NAME; // Tìm các SubCat chung Cat
                break;
            case OBJ_SUB_CODE:
                lookupFieldName = FIELD_SUB_CATEGORY_NAME;
                break;
            default:
                lookupFieldName = ''; // Đối với Product Type (Root)
        }

        try {
            const nextOrder = await getNextPosOrder({
                parentId: this.parentId,
                childFieldName: lookupFieldName
            });
            this.intPosOrder = nextOrder;
        } catch (error) {
            this.intPosOrder = 1;
        }
    }

    /**
     * @description Tiêu đề cho Modal (được dùng bởi lightning-modal-header)
     * @return String Tiêu đề
     * @author DAT NGO
     */
    get modalTitle() {
        return `${this.labelModalAddNew} (${this.objectType}) ${this.labelFor} ${this.parentLabel || this.labelRoot}`;
    }

    /**
     * @description Đóng Modal khi click Cancel
     * @author DAT NGO
     */
    handleClose() {
        this.close();
    }

    /**
     * @description Xử lý thay đổi input và gán giá trị vào biến @track
     * @param event Sự kiện thay đổi
     * @author DAT NGO
     */
    handleInputChange(event) {
        // Get the input element from the event
        const inputElement = event.currentTarget;
        const fieldName = inputElement.dataset.field; // Sử dụng data-field
        
        let field;
        let value;

        // Map the element to identify which field it is
        if (fieldName === 'inputCode') {
            field = FIELD_CODE;
            value = event.detail.value;
            this.strCode = value;
            showLog('Updated strCode to:', this.strCode);
        } else if (fieldName === 'inputAlias') {
            field = FIELD_ALIAS;
            value = event.detail.value;
            this.strAlias = value;
            showLog('Updated strAlias to:', this.strAlias);
        } else if (fieldName === 'inputName') {
            field = FIELD_NAME;
            value = event.detail.value;
            this.strName = value;
            showLog('Updated strName to:', this.strName);
        } else if (fieldName === 'inputNameVN') {
            field = FIELD_NAME_VN;
            value = event.detail.value;
            this.strNameVN = value;
            showLog('Updated strNameVN to:', this.strNameVN);
        } else if (fieldName === 'inputOrder') {
            field = FIELD_POS_ORDER;
            value = event.detail.value;
            this.intPosOrder = parseInt(value, 10) || 0;
            showLog('Updated intPosOrder to:', this.intPosOrder);
        } else if (fieldName === 'inputStatus') {
            field = FIELD_STATUS;
            value = inputElement.checked;
            this.isStatus = value;
            showLog('Updated isStatus to:', this.isStatus);
        }

        showLog(`handleInputChange - field: ${field}, value:`, value);
    }

    handleSaveAndNew() {
        showLog('handleSaveAndNew called');
        this.handleSaveNode(true);
    }
    handleSave() {
        showLog('handleSave called');
        this.handleSaveNode(false);
    }

    // Sửa lại handleSave để nhận thêm tham số
    handleSaveNode(keepOpen) {
        // Validation
        const inputFields = this.template.querySelectorAll('lightning-input');
        let isValid = true;
        inputFields.forEach(inputField => {
            if (!inputField.checkValidity()) {
                inputField.reportValidity();
                isValid = false;
            }
        });
        if (!isValid) {
            return;
        }
        showLog('Validation passed, proceeding to save');
        showLog('Preparing to save new lookup node with values:', {
            strName: this.strName,
            strAlias: this.strAlias,
            strCode: this.strCode,
            strNameVN: this.strNameVN
        });

        // Additional validation: Check for empty required fields
        if (!this.strName || !this.strAlias || !this.strCode || !this.strNameVN) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: LABEL_TOAST_VALIDATION_TITLE,
                    message: LABEL_TOAST_VALIDATION_MESSAGE,
                    variant: VARIANT_ERROR
                })
            );
            return;
        }

        // Map display label to API object name
        const objectTypeMap = {
            [OBJ_PRODUCT_TYPE]: 'FEC_MDM_Product_Type__c',
            [OBJ_BUSINESS_PROCESS]: 'FEC_MDM_Business_Process__c',
            [OBJ_CATEGORY]: 'FEC_MDM_Category__c',
            [OBJ_SUB_CATEGORY]: 'FEC_MDM_Sub_Category__c',
            [OBJ_SUB_CODE]: 'FEC_MDM_Sub_Code__c'
        };
        
        const apiObjectType = objectTypeMap[this.objectType] || this.objectType;

        const saveNewLookupNodeFields = {
            strObjectType: apiObjectType,
            strCustomerType: this.customerTypeValue,
            strParentId: this.parentId,
            strName: this.strName,
            strAlias: this.strAlias,
            strCode: this.strCode,
            strNameVN: this.strNameVN,
            intPosOrder: this.intPosOrder,
            isStatus: this.isStatus
        };
        showLog('Calling saveNewLookupNode with fields:', saveNewLookupNodeFields);

        saveNewLookupNode({
            strObjectType: apiObjectType,
            strCustomerType: this.customerTypeValue,
            strParentId: this.parentId,
            strName: this.strName,
            strAlias: this.strAlias,
            strCode: this.strCode,
            strNameVN: this.strNameVN,
            intPosOrder: this.intPosOrder,
            isStatus: this.isStatus
        })
            .then(result => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: LABEL_TOAST_SAVE_SUCCESS_TITLE,
                        message: `${LABEL_SUCCESS_ADD} (ID: ${result})`,
                        variant: VARIANT_SUCCESS
                    })
                );
                if (keepOpen) {
                    showLog('Resetting form for new entry');
                    this.strName = '';
                    this.customerTypeValue = CUST_TYPE_ALL;
                    this.strAlias = '';
                    this.strCode = '';
                    this.strNameVN = '';
                    this.intPosOrder = this.intPosOrder + 1; // Tăng order cho lần tiếp theo
                    this.isStatus = true;
                } else {
                    showLog('Closing modal with result:', result);
                    this.close(result);
                }
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: LABEL_ERROR_SAVE_LOOKUP,
                        message: error.body && error.body.message ? error.body.message : LABEL_UNKNOWN_ERROR,
                        variant: VARIANT_ERROR
                    })
                );
            });
    }
}