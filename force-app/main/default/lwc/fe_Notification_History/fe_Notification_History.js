import { LightningElement, api, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import COMMON_STYLES from '@salesforce/resourceUrl/FEC_CommonCss';

import getSmsInfoFromItTelco from '@salesforce/apex/FEC_GetSMSInfoFromITTelcoCallout.getSmsInfoFromItTelco';
import getNotificationHistoryForCase from '@salesforce/apex/FEC_NotificationHistoryController.getNotificationHistoryForCase';

import lblLoading from '@salesforce/label/c.FEC_Notification_History_Loading';
import lblCaseReadError from '@salesforce/label/c.FEC_Notification_History_Case_Read_Error';
import lblSmsNoLogDefault from '@salesforce/label/c.FEC_Notification_History_SMS_No_Log_Default';
import lblSmsLoadFailed from '@salesforce/label/c.FEC_Notification_History_SMS_Load_Failed';
import lblSmsHttpFailed from '@salesforce/label/c.FEC_Notification_History_SMS_Http_Failed';
import lblErrorUnknown from '@salesforce/label/c.FEC_Notification_History_Error_Unknown';
import lblEmailNeedRecord from '@salesforce/label/c.FEC_Notification_History_Email_Need_Record';
import lblPhonePrefix from '@salesforce/label/c.FEC_Notification_History_Phone_Prefix';
import lblTabSms from '@salesforce/label/c.FEC_Notification_History_Tab_SMS';
import lblTabZns from '@salesforce/label/c.FEC_Notification_History_Tab_ZNS';
import lblTabEmail from '@salesforce/label/c.FEC_Notification_History_Tab_Email';
import lblTabMobileApp from '@salesforce/label/c.FEC_Notification_History_Tab_MobileApp';
import lblColDateTime from '@salesforce/label/c.FEC_Notification_History_Col_DateTime';
import lblColNotificationType from '@salesforce/label/c.FEC_Notification_History_Col_Notification_Type';
import lblColNotificationContent from '@salesforce/label/c.FEC_Notification_History_Col_Notification_Content';
import lblColSentType from '@salesforce/label/c.FEC_Notification_History_Col_Sent_Type';
import lblColSentSystem from '@salesforce/label/c.FEC_Notification_History_Col_Sent_System';
import lblColUser from '@salesforce/label/c.FEC_Notification_History_Col_User';
import lblColSentStatus from '@salesforce/label/c.FEC_Notification_History_Col_Sent_Status';
import lblColFailureReason from '@salesforce/label/c.FEC_Notification_History_Col_Failure_Reason';
import lblColCaseId from '@salesforce/label/c.FEC_Notification_History_Col_Case_Id';
import lblSortDateTime from '@salesforce/label/c.FEC_Notification_History_Sort_DateTime';
import lblEmptyDash from '@salesforce/label/c.FEC_Notification_History_Empty_Dash';
import lblNoResults from '@salesforce/label/c.FEC_List_relevant_case_empty';

import FEC_Toast_Error from '@salesforce/label/c.FEC_Toast_Error';
import FEC_Toast_Error_Generic from '@salesforce/label/c.FEC_Toast_Error_Generic';

const CASE_PHONE_FIELDS = ['Case.FEC_Account_or_Contract__r.FEC_Primary_Phone__c'];

const SMS_COLUMNS = [
    { label: lblColDateTime, fieldName: 'dateTime', sortable: true, cellAlign: 'left', width: '170px' },
    { label: lblColNotificationType, fieldName: 'notificationType', sortable: true, cellAlign: 'left', width: '140px' },
    { label: lblColNotificationContent, fieldName: 'notificationContent', sortable: false, cellAlign: 'left' }
];

const EXTENDED_COLUMNS = [
    { label: lblColDateTime, fieldName: 'sentDateTime', sortable: true, cellAlign: 'left', width: '150px' },
    { label: lblColSentType, fieldName: 'sentType', sortable: true, cellAlign: 'left', width: '110px' },
    { label: lblColNotificationType, fieldName: 'notificationType', sortable: true, cellAlign: 'left', width: '120px' },
    { label: lblColNotificationContent, fieldName: 'notificationContent', sortable: false, cellAlign: 'left' },
    { label: lblColSentSystem, fieldName: 'sentSystem', sortable: true, cellAlign: 'left', width: '110px' },
    { label: lblColUser, fieldName: 'user', sortable: true, cellAlign: 'left', width: '100px' },
    { label: lblColSentStatus, fieldName: 'sentStatus', sortable: true, cellAlign: 'left', width: '110px' },
    { label: lblColFailureReason, fieldName: 'failureReason', sortable: false, cellAlign: 'left', width: '130px' },
    { label: lblColCaseId, fieldName: 'caseId', sortable: false, cellAlign: 'left', width: '120px' }
];

export default class Fe_Notification_History extends LightningElement {
    @api recordId;

    activeSections = ['sms', 'zns', 'email', 'mobileApp'];

    smsColumns = SMS_COLUMNS;
    extendedColumns = EXTENDED_COLUMNS;
    pageSizeDefault = 10;
    pageSizeOptions = [10, 20, 30, 40, 50];

    @track smsRows = [];
    @track smsLoading = false;
    @track smsInfoBanner = '';
    smsFetched = false;
    smsLoadError = '';

    resolvedPhone = null;
    _smsFetchKey = null;
    _smsRequestId = 0;

    @track znsRows = [];
    @track znsHistoryLoading = false;
    @track znsHistoryError = '';
    @track emailRows = [];
    @track emailHistoryLoading = false;
    @track emailHistoryError = '';
    @track mobileAppRows = [];
    @track mobileAppHistoryLoading = false;
    @track mobileAppHistoryError = '';

    get labelTabSms() {
        return lblTabSms;
    }
    get labelTabZns() {
        return lblTabZns;
    }
    get labelTabEmail() {
        return lblTabEmail;
    }
    get labelTabMobileApp() {
        return lblTabMobileApp;
    }
    get labelPhonePrefix() {
        return lblPhonePrefix;
    }
    get labelLoading() {
        return lblLoading;
    }
    get labelSortDateTime() {
        return lblSortDateTime;
    }

    /** Có dữ liệu: bỏ padding ngoài để fec_RelatedListPaging hiển thị trọn khung. Không dữ liệu: padding như cũ (bảng placeholder). */
    get smsSectionClass() {
        return 'section-block ' + (this.smsHasRows ? 'section-block--with-paging' : 'section-block--empty-state');
    }
    get znsSectionClass() {
        return 'section-block ' + (this.znsHasRows ? 'section-block--with-paging' : 'section-block--empty-state');
    }
    get emailSectionClass() {
        return 'section-block ' + (this.emailHasRows ? 'section-block--with-paging' : 'section-block--empty-state');
    }
    get mobileAppSectionClass() {
        return 'section-block ' + (this.mobileAppHasRows ? 'section-block--with-paging' : 'section-block--empty-state');
    }

    get smsHasRows() {
        return Array.isArray(this.smsRows) && this.smsRows.length > 0;
    }

    get znsHasRows() {
        return Array.isArray(this.znsRows) && this.znsRows.length > 0;
    }

    get emailHasRows() {
        return Array.isArray(this.emailRows) && this.emailRows.length > 0;
    }

    get mobileAppHasRows() {
        return Array.isArray(this.mobileAppRows) && this.mobileAppRows.length > 0;
    }

    get smsEmptyMsgClass() {
        return this._emptyStateMsgClass(!!this.smsLoadError);
    }

    get znsEmptyMsgClass() {
        return this._emptyStateMsgClass(!!this.znsHistoryError);
    }

    get emailEmptyMsgClass() {
        return this._emptyStateMsgClass(!!this.emailHistoryError);
    }

    get mobileAppEmptyMsgClass() {
        return this._emptyStateMsgClass(!!this.mobileAppHistoryError);
    }

    _emptyStateMsgClass(isError) {
        return 'nh-empty-state-msg' + (isError ? ' nh-empty-state-msg--error' : ' nh-empty-state-msg--neutral');
    }

    connectedCallback() {
        loadStyle(this, COMMON_STYLES).catch((e) => {
            console.error('[fe_Notification_History] FEC_CommonCss', e);
        });
    }

    @wire(getNotificationHistoryForCase, { caseId: '$recordId', channel: 'EMAIL' })
    wiredEmailNotificationHistory(result) {
        this._applyNotificationHistoryWire('email', result);
    }

    @wire(getNotificationHistoryForCase, { caseId: '$recordId', channel: 'ZNS' })
    wiredZnsNotificationHistory(result) {
        this._applyNotificationHistoryWire('zns', result);
    }

    @wire(getNotificationHistoryForCase, { caseId: '$recordId', channel: 'MOBILE_APP' })
    wiredMobileAppNotificationHistory(result) {
        this._applyNotificationHistoryWire('mobileApp', result);
    }

    @wire(getRecord, { recordId: '$recordId', fields: CASE_PHONE_FIELDS })
    wiredCaseForSms({ error, data }) {
        this.smsInfoBanner = '';
        this.smsLoadError = '';

        if (error) {
            this.resolvedPhone = null;
            this.smsRows = [];
            this.smsFetched = true;
            this._smsFetchKey = null;
            this.smsLoadError = lblCaseReadError;
            return;
        }
        if (!data) {
            return;
        }

        const fromCh = data.fields?.FEC_Account_or_Contract__r?.value?.fields?.FEC_Primary_Phone__c?.value;
        const nextPhone =
            fromCh != null && String(fromCh).trim() !== '' ? String(fromCh).trim() : null;

        const key = `${this.recordId || ''}|${nextPhone || ''}`;
        if (key === this._smsFetchKey) {
            return;
        }
        this._smsFetchKey = key;

        this.resolvedPhone = nextPhone;
        this.smsRows = [];
        this.smsFetched = false;

        if (!this.resolvedPhone) {
            this.smsLoading = false;
            this.smsFetched = true;
            return;
        }

        this.smsLoading = true;
        this._smsRequestId += 1;
        void this._executeSmsFetch(this._smsRequestId);
    }

    get resolvedPhoneDisplay() {
        return this.resolvedPhone || '';
    }

    get smsEmptyMessage() {
        if (this.smsLoading) {
            return lblLoading;
        }
        if (this.smsLoadError) {
            return this.smsLoadError;
        }
        if (!this.resolvedPhone) {
            return lblNoResults;
        }
        if (this.smsFetched && (!this.smsRows || this.smsRows.length === 0)) {
            return lblNoResults;
        }
        return lblEmptyDash;
    }

    get znsEmptyMessage() {
        if (!this.recordId) {
            return lblEmailNeedRecord;
        }
        if (this.znsHistoryLoading) {
            return lblLoading;
        }
        if (this.znsHistoryError) {
            return this.znsHistoryError;
        }
        if (!this.znsRows || this.znsRows.length === 0) {
            return lblNoResults;
        }
        return lblEmptyDash;
    }

    get emailEmptyMessage() {
        if (!this.recordId) {
            return lblEmailNeedRecord;
        }
        if (this.emailHistoryLoading) {
            return lblLoading;
        }
        if (this.emailHistoryError) {
            return this.emailHistoryError;
        }
        if (!this.emailRows || this.emailRows.length === 0) {
            return lblNoResults;
        }
        return lblEmptyDash;
    }

    get mobileAppEmptyMessage() {
        if (!this.recordId) {
            return lblEmailNeedRecord;
        }
        if (this.mobileAppHistoryLoading) {
            return lblLoading;
        }
        if (this.mobileAppHistoryError) {
            return this.mobileAppHistoryError;
        }
        if (!this.mobileAppRows || this.mobileAppRows.length === 0) {
            return lblNoResults;
        }
        return lblEmptyDash;
    }

    _applyNotificationHistoryWire(channel, { data, error }) {
        if (channel === 'email') {
            this.emailHistoryError = '';
            if (!this.recordId) {
                this.emailRows = [];
                this.emailHistoryLoading = false;
                return;
            }
            if (error) {
                this.emailRows = [];
                this.emailHistoryLoading = false;
                this.emailHistoryError = this._extractErrorMsg(error);
                console.error('[fe_Notification_History] Email history wire', error);
                return;
            }
            if (data === undefined) {
                this.emailHistoryLoading = true;
                return;
            }
            this.emailHistoryLoading = false;
            this.emailRows = Array.isArray(data) ? data : [];
            return;
        }
        if (channel === 'zns') {
            this.znsHistoryError = '';
            if (!this.recordId) {
                this.znsRows = [];
                this.znsHistoryLoading = false;
                return;
            }
            if (error) {
                this.znsRows = [];
                this.znsHistoryLoading = false;
                this.znsHistoryError = this._extractErrorMsg(error);
                console.error('[fe_Notification_History] ZNS history wire', error);
                return;
            }
            if (data === undefined) {
                this.znsHistoryLoading = true;
                return;
            }
            this.znsHistoryLoading = false;
            this.znsRows = Array.isArray(data) ? data : [];
            return;
        }
        if (channel === 'mobileApp') {
            this.mobileAppHistoryError = '';
            if (!this.recordId) {
                this.mobileAppRows = [];
                this.mobileAppHistoryLoading = false;
                return;
            }
            if (error) {
                this.mobileAppRows = [];
                this.mobileAppHistoryLoading = false;
                this.mobileAppHistoryError = this._extractErrorMsg(error);
                console.error('[fe_Notification_History] Mobile App history wire', error);
                return;
            }
            if (data === undefined) {
                this.mobileAppHistoryLoading = true;
                return;
            }
            this.mobileAppHistoryLoading = false;
            this.mobileAppRows = Array.isArray(data) ? data : [];
        }
    }

    async _executeSmsFetch(requestId) {
        try {
            const result = await getSmsInfoFromItTelco({ phoneNumber: this.resolvedPhone });

            if (requestId !== this._smsRequestId) {
                return;
            }

            if (result && result.success) {
                this.smsRows = this._flattenSmsRecords(result);
                if (result.dataNotFound) {
                    this.smsInfoBanner = result.sysDescription || lblSmsNoLogDefault;
                } else if (this.smsRows.length === 0) {
                    this.smsInfoBanner = '';
                }
            } else {
                this.smsRows = [];
                this.smsInfoBanner = '';
                const msg =
                    result?.errorMessage ||
                    result?.sysDescription ||
                    (result?.httpStatus != null
                        ? lblSmsHttpFailed.replace('{0}', String(result.httpStatus))
                        : lblSmsLoadFailed);
                this.smsLoadError = msg;
                this._toast(FEC_Toast_Error, msg, 'error');
            }
        } catch (e) {
            if (requestId !== this._smsRequestId) {
                return;
            }
            this.smsRows = [];
            this.smsInfoBanner = '';
            this.smsLoadError = this._extractErrorMsg(e);
            console.error('[fe_Notification_History] SMS', e);
            this._toast(FEC_Toast_Error, this.smsLoadError, 'error');
        } finally {
            if (requestId === this._smsRequestId) {
                this.smsLoading = false;
                this.smsFetched = true;
            }
        }
    }

    _flattenSmsRecords(apiResult) {
        const rows = [];
        let seq = 1;
        const list = apiResult?.records;
        if (!Array.isArray(list)) {
            return rows;
        }

        for (const rec of list) {
            const typeVal = rec?.smsTemplateCode != null ? String(rec.smsTemplateCode) : '';
            const contentVal = rec?.smsTemplateContent != null ? String(rec.smsTemplateContent) : '';
            const dates = Array.isArray(rec?.sentDates)
                ? rec.sentDates.filter((d) => d != null && String(d).trim() !== '')
                : [];

            if (dates.length === 0) {
                rows.push({
                    id: seq++,
                    dateTime: lblEmptyDash,
                    notificationType: typeVal || lblEmptyDash,
                    notificationContent: contentVal || lblEmptyDash
                });
            } else {
                for (const dt of dates) {
                    rows.push({
                        id: seq++,
                        dateTime: String(dt).trim(),
                        notificationType: typeVal || lblEmptyDash,
                        notificationContent: contentVal || lblEmptyDash
                    });
                }
            }
        }
        return rows;
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _extractErrorMsg(error) {
        if (!error) return lblErrorUnknown;
        if (Array.isArray(error?.body)) {
            return error.body.map((x) => x.message).join(', ');
        }
        if (typeof error?.body?.message === 'string') {
            return error.body.message;
        }
        if (typeof error?.message === 'string') {
            return error.message;
        }
        return FEC_Toast_Error_Generic;
    }
}
