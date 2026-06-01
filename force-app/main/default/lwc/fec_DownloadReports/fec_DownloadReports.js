/****************************************************************************************
 * File Name    : Fec_DownloadReports.js
 * Author       : Quangdv7
 * Date         : 2026-05-21
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-05-21     Quangdv7             Create
 
****************************************************************************************/

import { LightningElement, api, wire } from 'lwc';
import downloadReport from '@salesforce/apex/FEC_DownloadReportController.downloadReport';
import { EnclosingTabId, closeTab } from 'lightning/platformWorkspaceApi';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {DOWNLOAD_LOCK_KEY} from 'c/fec_CommonConst'
 
import FEC_Error_Download from '@salesforce/label/c.FEC_Error_Download';

export default class Fec_DownloadReports extends NavigationMixin(LightningElement) {

    @api recordIds;
    @wire(EnclosingTabId) tabId;

    customLabel = {
        errorDownload: FEC_Error_Download
    }

    showError(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message,
            variant: 'error'
        }));
    }

    async closeAndRefresh() {
        try {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'FEC_Download_Report__c',
                    actionName: 'list'
                },
                state: { filterName: 'Recent' }
            });
            await new Promise(resolve => setTimeout(resolve, 500));
            await closeTab(this.tabId);
        } catch (e) {
            console.error('closeAndRefresh error:', e);
        }
    }

    getIds() {
        if (this.recordIds && this.recordIds.length) {
            return Array.isArray(this.recordIds)
                ? this.recordIds
                : this.recordIds.split(',').map(id => id.trim()).filter(Boolean);
        }
        const urlParams = new URLSearchParams(window.location.search);
        const raw = urlParams.get('flow__ids');
        if (!raw) return [];
        return raw.split(',').map(id => id.trim()).filter(Boolean);
    }

    downloadFiles(urls) {
        if (!urls || urls.length === 0) return;

        urls.forEach((url, i) => {
            setTimeout(() => {
                const iframe = document.createElement('iframe');
                iframe.style.display = 'none';
                iframe.style.width = '0';
                iframe.style.height = '0';
                iframe.src = url;
                document.body.appendChild(iframe);
                setTimeout(() => {
                    if (document.body.contains(iframe)) {
                        document.body.removeChild(iframe);
                    }
                }, 10000);
            }, i * 1000);
        });
    }

    async renderedCallback() {
        if (sessionStorage.getItem(DOWNLOAD_LOCK_KEY)) return;
        sessionStorage.setItem(DOWNLOAD_LOCK_KEY, '1');

        const ids = this.getIds();

        if (!ids.length) {
            this.showError(this.customLabel.errorDownload);
            sessionStorage.removeItem(DOWNLOAD_LOCK_KEY);
            await this.closeAndRefresh();
            return;
        }

        try {
            const urls = await downloadReport({ downloadReportIds: ids });

            this.downloadFiles(urls);

            setTimeout(async () => {
                sessionStorage.removeItem(DOWNLOAD_LOCK_KEY);
                await this.closeAndRefresh();
            }, urls.length * 1000 + 300);

        } catch (e) {
            console.error(e);
            this.showError('Download failed.');
            sessionStorage.removeItem(DOWNLOAD_LOCK_KEY);
            await this.closeAndRefresh();
        }
    }

    disconnectedCallback() {
    }
}