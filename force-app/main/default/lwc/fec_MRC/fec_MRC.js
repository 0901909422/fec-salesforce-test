import { LightningElement, api, track, wire } from 'lwc';
import updateMRCRecord from '@salesforce/apex/FEC_GetMRCInfo.updateMRCRecord';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { formatDate } from 'c/fec_CommonUtils';
import { STR_EMPTY } from 'c/fec_CommonConst';
import FEC_SUBCODE_ID from '@salesforce/schema/Case.FEC_SubCode__c';
import FEC_SUBCODE_CODE_FIELD from '@salesforce/schema/FEC_Sub_Code__c.FEC_Code__c';

import FEC_Original_MRC from '@salesforce/label/c.FEC_Original_MRC';
import FEC_Notarized_MRC from '@salesforce/label/c.FEC_Notarized_MRC';
import FEC_MRC_Zone from '@salesforce/label/c.FEC_MRC_Zone';
import FEC_Area from '@salesforce/label/c.FEC_Area';
import FEC_Plate_Number from '@salesforce/label/c.FEC_Plate_Number';
import FEC_Status from '@salesforce/label/c.FEC_Status';
import FEC_Status_ID from '@salesforce/label/c.FEC_Status_ID';
import FEC_ID from '@salesforce/label/c.FEC_ID';
import FEC_Remark from '@salesforce/label/c.FEC_Remark';
import FEC_Modified_Date from '@salesforce/label/c.FEC_Modified_Date';
import FEC_Delivery_Date from '@salesforce/label/c.FEC_Delivery_Date';
import FEC_Received_Date from '@salesforce/label/c.FEC_Received_Date';
import FEC_Receiver from '@salesforce/label/c.FEC_Receiver';
import FEC_Posted_Date from '@salesforce/label/c.FEC_Posted_Date';
import FEC_Postal_Code from '@salesforce/label/c.FEC_Postal_Code';
import FEC_Provided_Number from '@salesforce/label/c.FEC_Provided_Number';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';

const STATUS = {
    ERROR: 'ERROR',
    NONE: 'NONE',
    EMPTY: '-',
    UNKNOWN_ERROR: 'Unknown error'
};

const MrcFields = {
    ZONE: 'FEC_MRC_Zone__c',
    AREA: 'FEC_Area__c',
    PLATE: 'FEC_Plate_Number__c',
    STATUS: 'FEC_MRC_Status__c',
    STATUS_ID: 'FEC_Status_ID__c',
    ID: 'FEC_ID__c',
    REMARK_ORIGINAL: 'FEC_Original_MRC_Remark__c',
    REMARK_NOTARIZED: 'FEC_Notarized_MRC_Remark__c',
    MODIFIED_DATE: 'FEC_Modified_Date__c',
    DELIVERY_DATE: 'FEC_Delivery_Date__c',
    RECEIVED_DATE: 'FEC_Received_Date__c',
    RECEIVER_ORIGINAL: 'FEC_Original_MRC_Receiver__c',
    RECEIVER_NOTARIZED: 'FEC_Notarized_MRC_Receiver__c',
    POSTED_DATE: 'FEC_Posted_Date__c',
    POSTAL_CODE: 'FEC_Postal_Code__c',
    PROVIDED_NUMBER: 'FEC_Provided_Number__c'
};

const CASE_SUB_FIELDS = [FEC_SUBCODE_ID];

/** Chỉ ẩn khi parent/master data ép (isHiddenLwc). RL05.02 dùng subsection Property Info, không LWC này. */
function normalizeSubCodeUpper(value) {
    if (value == null || value === STR_EMPTY) {
        return STR_EMPTY;
    }
    return String(value).trim().toUpperCase();
}

export default class Fec_MRC extends LightningElement {
    @api recordId;
    /** Từ fec_CaseBussiness — Sub-Code code đã chọn (ưu tiên hơn wire Case). */
    _subCodeCodeFromParent = STR_EMPTY;
    @api
    get subCodeCode() {
        return this._subCodeCodeFromParent;
    }
    set subCodeCode(value) {
        const next = normalizeSubCodeUpper(value);
        if (this._subCodeCodeFromParent === next) {
            return;
        }
        this._subCodeCodeFromParent = next;
        this.syncAccordionSections();
        this._syncHideAndLoad();
    }
    /** Master data / parent có thể ép ẩn (fec_CaseBussiness). */
    @api isHiddenLwc;

    @track accountData;
    @track error;
    @track isLoading = false;

    subCodeRecordId;
    _subCodeCodeFromWire = STR_EMPTY;
    _mrcLoadStarted = false;
    _caseWireLoaded = false;
    _subCodeWireLoaded = false;

    @wire(getRecord, { recordId: '$recordId', fields: CASE_SUB_FIELDS })
    wiredCaseSub({ data }) {
        this._caseWireLoaded = true;
        this.subCodeRecordId = data ? getFieldValue(data, FEC_SUBCODE_ID) : null;
        if (!this.subCodeRecordId) {
            this._subCodeCodeFromWire = STR_EMPTY;
            this._subCodeWireLoaded = true;
            this.syncAccordionSections();
        } else {
            this._subCodeWireLoaded = false;
        }
        this._syncHideAndLoad();
    }

    @wire(getRecord, { recordId: '$subCodeRecordId', fields: [FEC_SUBCODE_CODE_FIELD] })
    wiredSubCode({ data, error }) {
        if (!this.subCodeRecordId) {
            return;
        }
        if (data) {
            const v = getFieldValue(data, FEC_SUBCODE_CODE_FIELD);
            this._subCodeCodeFromWire = v ? normalizeSubCodeUpper(v) : STR_EMPTY;
            this._subCodeWireLoaded = true;
        } else if (error) {
            this._subCodeCodeFromWire = STR_EMPTY;
            this._subCodeWireLoaded = true;
        } else {
            return;
        }
        this.syncAccordionSections();
        this._syncHideAndLoad();
    }

    @track activeSections = [FEC_Original_MRC, FEC_Notarized_MRC];

    customLabel = {
        originalMRCLabel: FEC_Original_MRC,
        notarizedMRCLabel: FEC_Notarized_MRC,
        mrcZoneLabel: FEC_MRC_Zone,
        areaLabel: FEC_Area,
        plateNumberLabel: FEC_Plate_Number,
        statusLabel: FEC_Status,
        statusIDLabel: FEC_Status_ID,
        idLabel: FEC_ID,
        remarkLabel: FEC_Remark,
        modifiedDateLabel: FEC_Modified_Date,
        deliveryDateLabel: FEC_Delivery_Date,
        receivedDateLabel: FEC_Received_Date,
        receiverLabel: FEC_Receiver,
        postedDateLabel: FEC_Posted_Date,
        postalCodeLabel: FEC_Postal_Code,
        providedNumberLabel: FEC_Provided_Number,
        msgErrorAPI: FEC_MSG_Error_API_Label,
    };

    get _effectiveSubCodeUpper() {
        if (this._subCodeCodeFromParent) {
            return this._subCodeCodeFromParent;
        }
        return this._subCodeCodeFromWire || STR_EMPTY;
    }

    get _isSubCodeContextReady() {
        if (this._subCodeCodeFromParent) {
            return true;
        }
        if (!this._caseWireLoaded) {
            return false;
        }
        if (!this.subCodeRecordId) {
            return true;
        }
        return this._subCodeWireLoaded;
    }

    get shouldHideComponent() {
        return this.isHiddenLwc === true;
    }

    /** Chỉ render sau khi biết Sub-Code. */
    get shouldRenderMrc() {
        return this._isSubCodeContextReady && !this.shouldHideComponent;
    }

    get showOriginalMrcBlock() {
        return this.shouldRenderMrc;
    }

    get showNotarizedMrcBlock() {
        if (!this.shouldRenderMrc) {
            return false;
        }
        const s = this._effectiveSubCodeUpper;
        if (s.includes('RL05.01')) {
            return false;
        }
        return true;
    }

    syncAccordionSections() {
        const next = [FEC_Original_MRC];
        if (this.showNotarizedMrcBlock) {
            next.push(FEC_Notarized_MRC);
        }
        this.activeSections = next;
    }

    _clearMrcDisplayState() {
        this.accountData = undefined;
        this.error = undefined;
        this.isLoading = false;
        this._mrcLoadStarted = false;
    }

    _syncHideAndLoad() {
        if (this.shouldHideComponent) {
            this._clearMrcDisplayState();
            return;
        }
        this._maybeLoadMrc();
    }

    _maybeLoadMrc() {
        if (
            !this._isSubCodeContextReady ||
            this.shouldHideComponent ||
            !this.recordId ||
            this._mrcLoadStarted
        ) {
            return;
        }
        this._mrcLoadStarted = true;
        this.loadData();
    }

    loadData() {
        if (!this.recordId || !this.shouldRenderMrc) {
            this._mrcLoadStarted = false;
            return;
        }

        this.isLoading = true;

        updateMRCRecord({ caseId: this.recordId })
            .then((result) => {
                if (!this.shouldRenderMrc) {
                    this._clearMrcDisplayState();
                    return;
                }
                this.accountData = result;
                this.error = undefined;
            })
            .catch((err) => {
                if (!this.shouldRenderMrc) {
                    this._clearMrcDisplayState();
                    return;
                }
                this.handleError(err);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get hasData() {
        return Boolean(this.accountData && Object.keys(this.accountData).length > 0);
    }

    get originalMrcFields() {
        if (!this.accountData && !this.error) return [];

        return [
            this.buildField(this.customLabel.mrcZoneLabel, this.accountData?.[MrcFields.ZONE], MrcFields.ZONE),
            this.buildField(this.customLabel.statusLabel, this.accountData?.[MrcFields.STATUS], MrcFields.STATUS),
            this.buildField(this.customLabel.deliveryDateLabel, formatDate(this.accountData?.[MrcFields.DELIVERY_DATE]), MrcFields.DELIVERY_DATE),
            this.buildField(this.customLabel.areaLabel, this.accountData?.[MrcFields.AREA], MrcFields.AREA),
            this.buildField(this.customLabel.statusIDLabel, this.accountData?.[MrcFields.STATUS_ID], MrcFields.STATUS_ID),
            this.buildField(this.customLabel.receivedDateLabel, formatDate(this.accountData?.[MrcFields.RECEIVED_DATE]), MrcFields.RECEIVED_DATE),
            this.buildField(this.customLabel.plateNumberLabel, this.accountData?.[MrcFields.PLATE], MrcFields.PLATE),
            this.buildField(this.customLabel.modifiedDateLabel, formatDate(this.accountData?.[MrcFields.MODIFIED_DATE]), MrcFields.MODIFIED_DATE),
            this.buildField(this.customLabel.receiverLabel, this.accountData?.[MrcFields.RECEIVER_ORIGINAL], MrcFields.RECEIVER_ORIGINAL),
            this.buildField(this.customLabel.idLabel, this.accountData?.[MrcFields.ID], MrcFields.ID),
            this.buildField(this.customLabel.remarkLabel, this.accountData?.[MrcFields.REMARK_ORIGINAL], MrcFields.REMARK_ORIGINAL)
        ];
    }

    get notarizedMrcFields() {
        if (!this.accountData && !this.error) return [];

        return [
            this.buildField(this.customLabel.postedDateLabel, formatDate(this.accountData?.[MrcFields.POSTED_DATE]), MrcFields.POSTED_DATE),
            this.buildField(this.customLabel.providedNumberLabel, this.accountData?.[MrcFields.PROVIDED_NUMBER], MrcFields.PROVIDED_NUMBER),
            this.buildField(STR_EMPTY, STATUS.EMPTY, 'EMPTY_NOTARIZED_1'),
            this.buildField(this.customLabel.postalCodeLabel, this.accountData?.[MrcFields.POSTAL_CODE], MrcFields.POSTAL_CODE),
            this.buildField(this.customLabel.receiverLabel, this.accountData?.[MrcFields.RECEIVER_NOTARIZED], MrcFields.RECEIVER_NOTARIZED),
            this.buildField(STR_EMPTY, STATUS.EMPTY, 'EMPTY_NOTARIZED_2'),
            this.buildField(this.customLabel.remarkLabel, this.accountData?.[MrcFields.REMARK_NOTARIZED], MrcFields.REMARK_NOTARIZED)
        ];
    }

    buildField(label, value, fieldApiName) {
        return {
            label,
            value: value || STATUS.EMPTY,
            syncStatus: this.error ? STATUS.ERROR : STATUS.NONE,
            helpText: null,
            hasHelpText: false
        };
    }

    handleError(err) {
        this.error = err?.body?.message || err?.message || STATUS.UNKNOWN_ERROR;
    }
}