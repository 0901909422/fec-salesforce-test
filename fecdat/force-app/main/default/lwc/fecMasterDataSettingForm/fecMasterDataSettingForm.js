import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import getChannels from '@salesforce/apex/FEC_MasterDataSettingController.getChannels';
import getUserRoles from '@salesforce/apex/FEC_MasterDataSettingController.getUserRoles';

import LABEL_BUTTON_CANCEL from '@salesforce/label/c.FEC_Button_Cancel';
import LABEL_BUTTON_SAVE from '@salesforce/label/c.FEC_Button_Save';
import LABEL_LABEL_CHANNEL_MULTISELECT from '@salesforce/label/c.FEC_Label_Channel_Multiselect';
import LABEL_LABEL_APPLICABLE_ROLES from '@salesforce/label/c.FEC_Label_Applicable_Roles';
import LABEL_CUSTOMERTYPE_EXISTING from '@salesforce/label/c.FEC_Label_CustomerType_Existing';
import LABEL_CUSTOMERTYPE_NONEXISTING from '@salesforce/label/c.FEC_Label_CustomerType_NonExisting';
import LABEL_CUSTOMERTYPE_ALL from '@salesforce/label/c.FEC_Label_CustomerType_All';

import { FIELD_FIELD_ORDER_DISPLAY, OBJECT_MDM_MASTER_DATA_SETTING, FIELD_ADDITIONAL_FIELD, FIELD_FIELD_STATUS, FIELD_FIELD_READONLY, FIELD_FIELD_MANDATORY, FIELD_CHANNEL, FIELD_APPLICABLE_ROLE, FIELD_NATURE_OF_CASE, FIELD_STAGE_NAME, DATA_NAME_CHANNELS, DATA_NAME_ROLES, CUST_TYPE_EXISTING, CUST_TYPE_NON_EXISTING, CUST_TYPE_ALL, FIELD_SECTION } from 'c/fecConstants/fecConstants';

const FIELDS = [
    `${OBJECT_MDM_MASTER_DATA_SETTING}.${FIELD_CHANNEL}`,
    `${OBJECT_MDM_MASTER_DATA_SETTING}.${FIELD_APPLICABLE_ROLE}`
];

export default class FecMasterDataSettingForm extends LightningElement {
    @api recordId;
    @api natureOfCaseId;
    @api stageId;
    @api nextOrder; // Nhận giá trị từ cha

    @track selectedChannels = [];
    @track selectedRoles = [];
    @track channelOptions = [];
    @track roleOptions = [];
    @track displayOrder;
    @track customerTypeValue = CUST_TYPE_ALL; // Giá trị mặc định khi tạo mới
    // expose labels
    labelCancel = LABEL_BUTTON_CANCEL;
    labelSave = LABEL_BUTTON_SAVE;
    fieldOrderDisplay = FIELD_FIELD_ORDER_DISPLAY;
    objectApiName = OBJECT_MDM_MASTER_DATA_SETTING;
    fieldAdditionalField = FIELD_ADDITIONAL_FIELD;
    fieldSection = FIELD_SECTION;
    fieldOrder = FIELD_FIELD_ORDER_DISPLAY;
    fieldStatus = FIELD_FIELD_STATUS;
    fieldReadOnly = FIELD_FIELD_READONLY;
    fieldMandatory = FIELD_FIELD_MANDATORY;
    labelChannelMultiselect = LABEL_LABEL_CHANNEL_MULTISELECT;
    labelApplicableRoles = LABEL_LABEL_APPLICABLE_ROLES;
    dataNameChannels = DATA_NAME_CHANNELS;
    dataNameRoles = DATA_NAME_ROLES;


    // Định nghĩa danh sách 3 giá trị cho dropdown
    get customerTypeOptions() {
        return [
            { label: LABEL_CUSTOMERTYPE_EXISTING, value: CUST_TYPE_EXISTING },
            { label: LABEL_CUSTOMERTYPE_NONEXISTING, value: CUST_TYPE_NON_EXISTING },
            { label: LABEL_CUSTOMERTYPE_ALL, value: CUST_TYPE_ALL }
        ];
    }

    // Sử dụng connectedCallback để thiết lập giá trị mặc định khi form khởi tạo
    connectedCallback() {
        // Chỉ tự động điền nếu là tạo mới (không có recordId)
        if (!this.recordId) {
            this.displayOrder = this.nextOrder;
        }
    }

    handleCustomerTypeChange(event) {
        this.customerTypeValue = event.detail.value;
    }

    // --- AUTO-FILL LOGIC ---
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            // Lấy giá trị String từ Database (ví dụ: "Web, Mobile") - dùng constants
            const channelsStr = getFieldValue(data, `${OBJECT_MDM_MASTER_DATA_SETTING}.${FIELD_CHANNEL}`);
            const rolesStr = getFieldValue(data, `${OBJECT_MDM_MASTER_DATA_SETTING}.${FIELD_APPLICABLE_ROLE}`);

            // Chuyển chuỗi thành mảng để hiển thị Pills
            this.selectedChannels = channelsStr ? channelsStr.split(',').map(item => item.trim()) : [];
            this.selectedRoles = rolesStr ? rolesStr.split(',').map(item => item.trim()) : [];
        } else if (error) {
            console.error('Lỗi load dữ liệu cũ:', error);
        }
    }

    @wire(getChannels)
    wiredChannels({ data }) { if (data) this.channelOptions = data; }

    @wire(getUserRoles)
    wiredRoles({ data }) { if (data) this.roleOptions = data; }

    handleSelectCustom(event) {
        const field = event.target.dataset.name;
        const value = event.detail.value;
        if (field === DATA_NAME_CHANNELS && !this.selectedChannels.includes(value)) {
            this.selectedChannels = [...this.selectedChannels, value];
        } else if (field === DATA_NAME_ROLES && !this.selectedRoles.includes(value)) {
            this.selectedRoles = [...this.selectedRoles, value];
        }
    }

    handleRemoveCustom(event) {
        const field = event.target.dataset.name;
        const value = event.target.name;
        if (field === DATA_NAME_CHANNELS) {
            this.selectedChannels = this.selectedChannels.filter(v => v !== value);
        } else if (field === DATA_NAME_ROLES) {
            this.selectedRoles = this.selectedRoles.filter(v => v !== value);
        }
    }

    handleSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;

        // Gộp mảng thành chuỗi để lưu vào Database
        fields[FIELD_CHANNEL] = this.selectedChannels.join(', ');
        fields[FIELD_APPLICABLE_ROLE] = this.selectedRoles.join(', ');

        fields[FIELD_NATURE_OF_CASE] = this.natureOfCaseId;
        fields[FIELD_STAGE_NAME] = this.stageId;

        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSuccess(event) {
        this.dispatchEvent(new CustomEvent('success', { detail: event.detail }));
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleError(event) {
        // Simple error handling
        console.error('Form error', event.detail);
    }
}