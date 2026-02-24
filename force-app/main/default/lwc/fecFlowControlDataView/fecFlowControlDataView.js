import { LightningElement, api } from 'lwc';
import LABEL_FLOW_CONTROL_TITLE from '@salesforce/label/c.FEC_Flow_Control_Title';
import LABEL_CONTROL_NAME from '@salesforce/label/c.FEC_Label_Control_Name';
import LABEL_BUSINESS_CODE from '@salesforce/label/c.FEC_Label_Business_Code';
import LABEL_MAPPING_ALIAS from '@salesforce/label/c.FEC_Label_Mapping_Alias';
import LABEL_CUSTOMER_SEGMENT from '@salesforce/label/c.FEC_Label_Customer_Segment';
import LABEL_EXECUTION_ORDER from '@salesforce/label/c.FEC_Label_Execution_Order';
import LABEL_STATUS_CONTROL from '@salesforce/label/c.FEC_Label_Status_Control';
import LABEL_LOCALIZED_NAME from '@salesforce/label/c.FEC_Label_Localized_Name';
import LABEL_COL_CONTROL_FIELD from '@salesforce/label/c.FEC_Col_Control_Field';
import LABEL_COL_CONFIG_VALUE from '@salesforce/label/c.FEC_Col_Config_Value';
import LABEL_Prompt_Select_Node_Flow_Control from '@salesforce/label/c.FEC_Prompt_Select_Node_Flow_Control';

export default class FecFlowControlDataView extends LightningElement {
    @api item; // Nhận dữ liệu NOC từ component cha

    labelTitle = LABEL_FLOW_CONTROL_TITLE;
    labelControlField = LABEL_COL_CONTROL_FIELD;
    labelConfigValue = LABEL_COL_CONFIG_VALUE;
    labelPromptSelectNode = LABEL_Prompt_Select_Node_Flow_Control; // fix label reference

    get flowFields() {
        if (!this.item) return [];

        // Trình bày dữ liệu theo đúng nghiệp vụ Flow Control, dùng labels
        return [
            { label: LABEL_CONTROL_NAME, value: this.item.label || '--' },
            { label: LABEL_BUSINESS_CODE, value: this.item.code || '--' },
            { label: LABEL_MAPPING_ALIAS, value: this.item.alias || '--' },
            { label: LABEL_CUSTOMER_SEGMENT, value: this.item.customerType || 'Inherited/All' },
            { label: LABEL_EXECUTION_ORDER, value: this.item.posOrder || '0' },
            { label: LABEL_STATUS_CONTROL, value: this.item.status ? 'Active' : 'Inactive' },
            { label: LABEL_LOCALIZED_NAME, value: this.item.nameVN || '--' }
        ];
    }
}