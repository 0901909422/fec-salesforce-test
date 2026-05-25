import { LightningElement, api } from 'lwc';
import LABEL_NAME from '@salesforce/label/c.FEC_Label_Name';
import LABEL_NAME_EN from '@salesforce/label/c.FEC_Label_Name_EN';
import LABEL_NAME_VN from '@salesforce/label/c.FEC_Label_Name_VN';
import LABEL_ORDER from '@salesforce/label/c.FEC_Label_Order';
import LABEL_STATUS from '@salesforce/label/c.FEC_Label_Status';
import LABEL_ACTIVE from '@salesforce/label/c.FEC_Label_Active';
import LABEL_INACTIVE from '@salesforce/label/c.FEC_Label_Inactive';
import LABEL_NODE_DETAIL from '@salesforce/label/c.FEC_Label_Node_Detail_Title';

export default class FecLiveNodeDetail extends LightningElement {
    @api item;

    // Labels
    labelName = LABEL_NAME;
    labelNameEN = LABEL_NAME_EN;
    labelNameVN = LABEL_NAME_VN;
    labelOrder = LABEL_ORDER;
    labelStatus = LABEL_STATUS;
    labelNodeDetail = LABEL_NODE_DETAIL;

    get hasItem() {
        return this.item && this.item.name;
    }

    get cardTitle() {
        if (this.hasItem) {
            return `${this.labelNodeDetail} — ${this.item.type || ''} : ${this.item.label || ''}`;
        }
        return this.labelNodeDetail;
    }

    get cardIcon() {
        return this.hasItem ? 'standard:record' : 'standard:empty';
    }

    get itemNameEN() {
        return this.item?.NameEN || '';
    }

    get itemNameVN() {
        return this.item?.nameVN || '';
    }

    get itemOrder() {
        return this.item?.PosOrder != null ? String(this.item.PosOrder) : '';
    }

    get statusLabel() {
        if (!this.hasItem) return '';
        return this.item.Status ? LABEL_ACTIVE : LABEL_INACTIVE;
    }

    get statusBadgeClass() {
        const base = 'slds-badge';
        if (!this.hasItem) return base;
        return this.item.Status ? `${base} slds-theme_success` : `${base} slds-theme_error`;
    }
}