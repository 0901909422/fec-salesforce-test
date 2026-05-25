import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAttachments from '@salesforce/apex/ArchiveCaseAttachmentController.getAttachments';
import downloadFile from '@salesforce/apex/ArchiveCaseAttachmentController.downloadFile';

import titleAtt from '@salesforce/label/c.CS_TITLE_NAME_OF_ATTACHMENT';
import typeAtt from '@salesforce/label/c.CS_TYPE_OF_ATTACHMENT';
import downloadAtt from '@salesforce/label/c.CS_DOWNLOAD_ATTACHMENT';
import noAttachment from '@salesforce/label/c.CS_NO_ARCHIVE_ATTACHMENT';

const ICON_MAP = {
    pdf: 'doctype:pdf',
    png: 'doctype:image',
    jpg: 'doctype:image',
    jpeg: 'doctype:image',
    gif: 'doctype:image',
    bmp: 'doctype:image',
    svg: 'doctype:image',
    doc: 'doctype:word',
    docx: 'doctype:word',
    xls: 'doctype:excel',
    xlsx: 'doctype:excel',
    csv: 'doctype:csv',
    ppt: 'doctype:ppt',
    pptx: 'doctype:ppt',
    txt: 'doctype:txt',
    zip: 'doctype:zip',
    xml: 'doctype:xml',
    html: 'doctype:html'
};

export default class Fec_ArchiveAttachments extends LightningElement {
    @api recordId;
    files = [];
    isLoading = true;

    customLabel = {titleAtt, typeAtt, downloadAtt, noAttachment};

    @wire(getAttachments, { caseId: '$recordId' })
    wiredAttachments({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.files = data.map(f => ({
                ...f,
                isDownloading: false,
                downloadLinkClass: '',
                extension: this.getExtension(f.filename),
                iconName: this.getIcon(f.filename)
            }));
        } else if (error) {
            console.error('getAttachments error', error);
        }
    }

    get hasFiles() {
        return this.files && this.files.length > 0;
    }

    getExtension(filename) {
        if (!filename) return '';
        const parts = filename.split('.');
        return parts.length > 1 ? parts.pop().toLowerCase() : '';
    }

    getIcon(filename) {
        const ext = this.getExtension(filename);
        return ICON_MAP[ext] || 'doctype:unknown';
    }

    formatSize(bytes) {
        if (!bytes || bytes === 0) return '0 B';
        const units = ['B', 'KB', 'MB', 'GB'];
        let i = 0;
        let size = bytes;
        while (size >= 1024 && i < units.length - 1) {
            size /= 1024;
            i++;
        }
        return size.toFixed(size < 10 && i > 0 ? 1 : 0) + ' ' + units[i];
    }

    async handleDownload(event) {
        event.preventDefault();
        const s3Key = event.currentTarget.dataset.s3key;
        const file = this.files.find(f => f.s3Key === s3Key);
        if (!file || file.isDownloading) return;

        // Set downloading state
        this.files = this.files.map(f =>
            f.s3Key === s3Key ? { ...f, isDownloading: true, downloadLinkClass: 'slds-is-disabled' } : f
        );

        try {
            const result = await downloadFile({
                s3Key: file.s3Key,
                filename: file.filename,
                contentType: file.contentType,
                caseId: this.recordId
            });

            if (result.success) {
                this.triggerBrowserDownload(result.base64Data, result.filename, result.contentType);
            } else {
                this.showToast('Error', result.errorMessage || 'Download failed', 'error');
            }
        } catch (err) {
            this.showToast('Error', err.body?.message || 'Download failed', 'error');
        } finally {
            this.files = this.files.map(f =>
                f.s3Key === s3Key ? { ...f, isDownloading: false, downloadLinkClass: '' } : f
            );
        }
    }

    triggerBrowserDownload(base64, filename, contentType) {
        const byteChars = atob(base64);
        const byteNumbers = new Array(byteChars.length);
        for (let i = 0; i < byteChars.length; i++) {
            byteNumbers[i] = byteChars.charCodeAt(i);
        }
        const byteArray = new Uint8Array(byteNumbers);
        const blob = new Blob([byteArray], { type: contentType });

        const link = document.createElement('a');
        link.href = URL.createObjectURL(blob);
        link.download = filename;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(link.href);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
