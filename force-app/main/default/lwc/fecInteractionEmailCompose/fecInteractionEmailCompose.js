import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { CurrentPageReference } from 'lightning/navigation';
import sendEmailToCustomer from '@salesforce/apex/FEC_InteractionEmailController.sendEmailToCustomer';
import getEmailTemplates from '@salesforce/apex/FEC_InteractionEmailController.getEmailTemplates';

import INTERACTION_EMAIL from '@salesforce/schema/Case.FEC_Interaction_Email__c';
import SEND_TO from '@salesforce/schema/Case.FEC_Send_To__c';
import SUBJECT_FIELD from '@salesforce/schema/Case.Subject';

const READONLY_FROM = [
    'dichvukhachhang@fecredit.com.vn',
    'dichvukhachhang@ubank.com.vn'
];

export default class FecInteractionEmailCompose extends LightningElement {
    @api recordId;

    @wire(CurrentPageReference)
    pageRef(ref) {
        if (ref && ref.attributes && ref.attributes.recordId) {
            this.recordId = ref.attributes.recordId;
        }
    }

    @track showModal = false;
    @track fromEmail = '';
    @track toEmail = '';
    @track ccEmail = '';
    @track subject = '';
    @track body = '';
    @track errorMsg = '';
    @track isSending = false;
    @track titleReply = '';
    @track replyTemplate = '';
    @track templateOptions = [{ label: '--None--', value: '' }];

    _originalSubject = '';
    activeSections = ['emailCompose'];

    titleOptions = [
        { label: 'Anh', value: 'Anh' },
        { label: 'Chị', value: 'Chị' },
        { label: 'Anh/ Chị', value: 'Anh/ Chị' }
    ];

    @wire(getRecord, { recordId: '$recordId', fields: [INTERACTION_EMAIL, SEND_TO, SUBJECT_FIELD] })
    wiredCase({ data }) {
        if (data) {
            this.fromEmail = getFieldValue(data, INTERACTION_EMAIL) || '';
            this.toEmail = getFieldValue(data, SEND_TO) || getFieldValue(data, INTERACTION_EMAIL) || '';
            this._originalSubject = getFieldValue(data, SUBJECT_FIELD) || '';
        }
    }

    @wire(getEmailTemplates)
    wiredTemplates({ data }) {
        if (data && data.length > 0) {
            this.templateOptions = [
                { label: '--None--', value: '' },
                ...data.map(t => ({ label: t.Name, value: t.Id }))
            ];
        }
    }

    get isFromReadonly() {
        return READONLY_FROM.includes((this.fromEmail || '').toLowerCase());
    }

    handleTitleChange(e) { this.titleReply = e.detail.value; }
    handleTemplateChange(e) { this.replyTemplate = e.detail.value; }

    handleOpenCompose() {
        this.subject = this._originalSubject ? 'RE:' + this._originalSubject : '';
        this.errorMsg = '';
        this.showModal = true;
    }

    handleDiscard() {
        this.showModal = false;
        this.subject = '';
        this.body = '';
        this.ccEmail = '';
        this.errorMsg = '';
    }

    handlePreview() {}

    handleFromChange(e) { if (!this.isFromReadonly) this.fromEmail = e.target.value; }
    handleToChange(e) { this.toEmail = e.target.value; }
    handleCcChange(e) { this.ccEmail = e.target.value; }
    handleSubjectChange(e) { this.subject = e.target.value; }
    handleBodyChange(e) { this.body = e.target.value; }

    handleSend() {
        if (!this.toEmail) { this.errorMsg = 'To email is required.'; return; }
        if (!this.subject) { this.errorMsg = 'Subject is required.'; return; }
        if (!this.body) { this.errorMsg = 'Body is required.'; return; }

        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(this.toEmail)) { this.errorMsg = 'Invalid To email format.'; return; }
        if (this.ccEmail && !emailRegex.test(this.ccEmail)) { this.errorMsg = 'Invalid CC email format.'; return; }

        this.isSending = true;
        this.errorMsg = '';

        sendEmailToCustomer({
            caseId: this.recordId,
            fromEmail: this.fromEmail,
            toEmail: this.toEmail,
            ccEmail: this.ccEmail || null,
            subject: this.subject,
            body: this.body
        })
        .then(() => { this.handleDiscard(); })
        .catch(err => { this.errorMsg = err.body?.message || 'Failed to send email.'; })
        .finally(() => { this.isSending = false; });
    }
}
