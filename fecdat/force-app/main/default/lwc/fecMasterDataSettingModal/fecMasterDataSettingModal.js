import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveMasterDataSetting from '@salesforce/apex/FEC_MasterDataSettingController.saveMasterDataSetting';
import getLookupOptions from '@salesforce/apex/FEC_MasterDataSettingController.getLookupOptions'; // IMPORT HÀM CHUNG MỚI
import LABEL_FIELD_OBJECT_NAME from '@salesforce/label/c.FEC_Label_Field_Object_Name';
import LABEL_PROPERTY_NAME from '@salesforce/label/c.FEC_Label_Property_Name';
import LABEL_SECTION from '@salesforce/label/c.FEC_Label_Section';
import LABEL_ORDER_DISPLAY from '@salesforce/label/c.FEC_Label_Order_Display';
import LABEL_EDITABLE_ROLE from '@salesforce/label/c.FEC_Label_Editable_Role';
import LABEL_APPLICABLE_ROLE from '@salesforce/label/c.FEC_Label_Applicable_Role';
import LABEL_STAGE_NAME from '@salesforce/label/c.FEC_Label_Stage_Name';
import LABEL_STATUS from '@salesforce/label/c.FEC_Label_Status';
import LABEL_MANDATORY from '@salesforce/label/c.FEC_Label_Mandatory';
import LABEL_READONLY from '@salesforce/label/c.FEC_Label_ReadOnly';
import LABEL_EDITABLE from '@salesforce/label/c.FEC_Label_Editable';
import LABEL_BUTTON_CANCEL from '@salesforce/label/c.FEC_Button_Cancel';
import LABEL_BUTTON_SAVE from '@salesforce/label/c.FEC_Button_Save';
import LABEL_PARENT_NATURE_INFO from '@salesforce/label/c.FEC_Label_Parent_Nature_Info';
import { FIELD_FIELD_OBJECT_NAME, FIELD_FIELD_API_NAME, FIELD_SECTION, FIELD_FIELD_ORDER_DISPLAY, FIELD_EDITABLE_ROLE, FIELD_APPLICABLE_ROLE, FIELD_STAGE_NAME, FIELD_FIELD_STATUS, FIELD_FIELD_MANDATORY, FIELD_FIELD_READONLY, FIELD_FIELD_EDITABLE, SOBJECT_CASE_STAGE, SOBJECT_ADDITIONAL_FIELD, VARIANT_SUCCESS, VARIANT_ERROR } from 'c/fecConstants/fecConstants';
import LABEL_PLACEHOLDER_PROPERTY from '@salesforce/label/c.FEC_Placeholder_Select_Property';
import LABEL_PLACEHOLDER_CASE_STAGE from '@salesforce/label/c.FEC_Placeholder_Select_CaseStage';
import LABEL_TOAST_VALIDATION_TITLE from '@salesforce/label/c.FEC_Toast_Validation_Title';
import LABEL_TOAST_VALIDATION_MESSAGE from '@salesforce/label/c.FEC_Toast_Validation_Message';
import LABEL_TOAST_SAVE_SUCCESS from '@salesforce/label/c.FEC_Toast_Save_Success';
import LABEL_TOAST_SAVE_ERROR from '@salesforce/label/c.FEC_Toast_Save_Error';
import LABEL_TOAST_SAVE_SUCCESS_MESSAGE from '@salesforce/label/c.FEC_Toast_Save_Success_Message';

/**
 * @description Form thêm mới/chỉnh sửa bản ghi FEC_Master_Data_Setting__c (Sử dụng Lightning Input).
 */
export default class FecMasterDataSettingModal extends LightningElement {
    @api recordId;
    @api natureOfCaseId; // ID Node cha (FEC_MDM_Nature_Of_Case__c)
    @api handleStage; // ID Node cha (FEC_MDM_Nature_Of_Case__c)

    @track formData = {};
    @track isAddMode = true;
    @track stageOptions = []; // BIẾN MỚI để lưu trữ các tùy chọn Stage
    connectedCallback() {
        this.isAddMode = !this.recordId;

        // Khởi tạo các trường mặc định (chỉ xảy ra khi Add)
        if (this.isAddMode) {
            this.formData = {
                // 2. 10 Trường trực tiếp (Dựa trên yêu cầu mới)
                [FIELD_SECTION]: '',
                [FIELD_FIELD_STATUS]: true,
                [FIELD_FIELD_READONLY]: false,
                [FIELD_FIELD_ORDER_DISPLAY]: null, // Number
                [FIELD_FIELD_OBJECT_NAME]: '',
                [FIELD_FIELD_MANDATORY]: false,
                [FIELD_FIELD_EDITABLE]: false,
                [FIELD_FIELD_API_NAME]: '',
                [FIELD_EDITABLE_ROLE]: '',
                [FIELD_APPLICABLE_ROLE]: '', // TRƯỜNG MỚI THEO YÊU CẦU

                // 3. 4 Trường Lookup (Dùng ID field cho Payload)
                [FIELD_NATURE_OF_CASE]: this.natureOfCaseId, // ID được truyền từ component cha
                [FIELD_STAGE_NAME]: this.handleStage,
                [FIELD_CHANNEL]: ' ',
                [FIELD_CASE_CHANNEL]: ''
            };
        }
        // Lưu ý: Nếu ở Edit Mode, bạn cần gọi Apex để tải dữ liệu bản ghi hiện tại vào this.formData
    }

    // 1. WIRE CALL cho FEC_Case_Stage__c
    // Tham số sObjectName được truyền vào hàm getLookupOptions
    @wire(getLookupOptions, { sObjectName: SOBJECT_CASE_STAGE })
    wiredGetStageOptions({ error, data }) {
        if (data) {
            this.stageOptions = data;
        } else if (error) {
            console.error('Error fetching Stage options:', error);
        }
    }

    // 2. WIRE CALL cho FEC_MDM_Additional_Field__c
    @wire(getLookupOptions, { sObjectName: SOBJECT_ADDITIONAL_FIELD })
    wiredGetFieldApiNameOptions({ error, data }) {
        if (data) {
            this.fieldApiNameOptions = data;
        } else if (error) {
            console.error('Error fetching Field API Name options:', error);
        }
    }

    // --- Data Handlers ---

    handleInputChange(event) {
        const fieldName = event.target.name;
        let value = event.target.value;

        // Xử lý kiểu dữ liệu đặc biệt
        if (event.target.type === 'checkbox') {
            value = event.target.checked;
        } else if (event.target.type === 'number') {
            // Chuyển string number thành integer, null nếu rỗng
            value = value ? parseInt(value) : null;
        }

        this.formData = {
            ...this.formData,
            [fieldName]: value
        };
    }

    /**
     * @description Xử lý khi người dùng nhấn nút Save/Submit.
     */
    async handleSubmit() {
        // 1. Kiểm tra Validation
        if (!this.validateAllFields()) {
            this.showToast(LABEL_TOAST_VALIDATION_TITLE, LABEL_TOAST_VALIDATION_MESSAGE, 'error');
            return;
        }

        // [DEBUG 1] Kiểm tra xem code đã chạy đến đây chưa
        console.log('1. Validation Passed. Starting submission process.');

        this.isLoading = true;

        // 2. Lấy Payload
        const payload = this.getPayload();

        // [DEBUG 2] Kiểm tra payload trước khi gọi Apex
        console.log('2. Payload prepared:', JSON.stringify(payload));

        try {
            // [DEBUG 3] Log ngay trước khi gọi hàm Apex
            console.log('3. Calling Apex with payload:', payload);

            // 3. Gọi Apex Controller
            // !!! ĐIỂM CẦN KIỂM TRA QUAN TRỌNG: Tên hàm và tên tham số phải khớp !!!
            const recordId = await saveMasterDataSetting({ nodeData: payload });

            // [DEBUG 4] Nếu đến được đây, Apex đã chạy thành công
            console.log('4. Apex Call Successful. Record ID:', recordId);

            // 4. Xử lý thành công
            const successMessage = LABEL_TOAST_SAVE_SUCCESS_MESSAGE.replace('{0}', recordId);
            this.showToast(LABEL_TOAST_SAVE_SUCCESS, successMessage, VARIANT_SUCCESS);
            this.dispatchEvent(new CustomEvent('success', { detail: recordId }));

        } catch (error) {
            // [DEBUG 5] Nếu rơi vào đây, lỗi là do Apex (Hoặc Framework lỗi ở bước 3)
            console.error('5. Submission Error Caught:', error);

            // Thử lấy thông báo lỗi chi tiết hơn từ framework
            let errorMessage = 'Lỗi không xác định.';
            if (error.body && error.body.message) {
                errorMessage = error.body.message;
            } else if (typeof error === 'string') {
                errorMessage = error;
            } else if (error.message) {
                errorMessage = error.message;
            }

            this.showToast(LABEL_TOAST_SAVE_ERROR, errorMessage, VARIANT_ERROR);

        } finally {
            this.isLoading = false;
            console.log('6. Submission process finished.');
        }
    }
    // --- Public API ---

    /**
     * @description Public method để Modal cha gọi lấy dữ liệu và kiểm tra validation.
     * @returns {Object|null} Payload hoàn chỉnh nếu validation OK, ngược lại là null.
     */

    getPayload() {
        if (!this.validateAllFields()) {
            return null;
        }

        const payload = {
            recordId: this.recordId,
            ...this.formData
        };

        return payload;
    }

    /**
     * @description Thực hiện kiểm tra validation cho tất cả các trường.
     * @returns {Boolean}
     */

    validateAllFields() {
        let isValid = true;
        const allInputs = this.template.querySelectorAll('lightning-input, lightning-combobox');

        allInputs.forEach(input => {
            // Kiểm tra validation cho từng input
            if (!input.reportValidity()) {
                isValid = false;
            }
        });
        
        return isValid;
    }

    showToast(title, message, variant) {
        // ... (Logic hiển thị Toast)
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

     // Xử lý sự kiện Cancel (phát sự kiện lên cha)
     handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
     }
}