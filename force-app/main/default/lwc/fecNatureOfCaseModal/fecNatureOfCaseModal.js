import { LightningElement, api, track } from 'lwc';
import LightningModal from 'lightning/modal'; // 👈 Sử dụng LightningModal cho popup giữa màn hình
import saveNewLookupNode from '@salesforce/apex/FEC_NatureOfCaseTreeController.saveNewLookupNode';
import getNextPosOrder from '@salesforce/apex/FEC_NatureOfCaseTreeController.getNextPosOrder'; // Import mới
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { showLog } from 'c/fecUtils';
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
        const field = event.target.dataset.fieldname;
        let value = event.target.value;

        switch (field) {
            case FIELD_NAME:
                this.strName = value;
                break;
            case FIELD_ALIAS:
                this.strAlias = value;
                break;
            case FIELD_CODE:
                this.strCode = value;
                break;
            case FIELD_NAME_VN:
                this.strNameVN = value;
                break;
            case FIELD_POS_ORDER:
                this.intPosOrder = parseInt(value, 10) || 0;
                break;
            case FIELD_STATUS:
                this.isStatus = event.target.checked;
                break;
            default:
                break;
        }
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

        const saveNewLookupNodeFields = {
            strObjectType: this.objectType,
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
            strObjectType: this.objectType,
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
                        title: 'Success',
                        message: `New Node (ID: ${result}) created for ${this.objectType}!`,
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
                        title: 'Error creating Lookup Node',
                        message: error.body && error.body.message ? error.body.message : 'Unknown error',
                        variant: VARIANT_ERROR
                    })
                );
            });
    }
}