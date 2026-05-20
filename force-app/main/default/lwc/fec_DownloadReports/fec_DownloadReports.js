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
import { EnclosingTabId, closeTab } from 'lightning/platformWorkspaceApi';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import downloadReport from '@salesforce/apex/FEC_DownloadReportController.downloadReport';

import FEC_Download_Report from '@salesforce/label/c.FEC_Download_Report';
import FEC_Export_View from '@salesforce/label/c.FEC_Export_View';
import FEC_Formatted_Report from '@salesforce/label/c.FEC_Formatted_Report';
import FEC_Title_Context_Report from '@salesforce/label/c.FEC_Title_Context_Report';
import FEC_Details_Only from '@salesforce/label/c.FEC_Details_Only';
import FEC_Export_Detail from '@salesforce/label/c.FEC_Export_Detail';
import FEC_Format from '@salesforce/label/c.FEC_Format';
import FEC_Format_Excel from '@salesforce/label/c.FEC_Format_Excel';
import FEC_Error_Download from '@salesforce/label/c.FEC_Error_Download';

export default class Fec_DownloadReports extends LightningElement {

    @api recordIds;
    @wire(EnclosingTabId) tabId;

    isLoading = false;
    isFormattedSelected = true;
    isDetailsSelected = false;

    customLabel = {
        downloadReport: FEC_Download_Report,
        exportView: FEC_Export_View,
        formattedReport: FEC_Formatted_Report,
        titleContextReport: FEC_Title_Context_Report,
        detailsOnly: FEC_Details_Only,
        exportDetail: FEC_Export_Detail,
        format: FEC_Format,
        formatExcel: FEC_Format_Excel,
        errorDownload: FEC_Error_Download
    }

    get formattedClass() {
        return this.isFormattedSelected ? 'option-card selected' : 'option-card';
    }

    get detailsClass() {
        return this.isDetailsSelected ? 'option-card selected' : 'option-card';
    }

    handleFormatted() {
        this.isFormattedSelected = true;
        this.isDetailsSelected = false;
    }

    handleDetails() {
        this.isDetailsSelected = true;
        this.isFormattedSelected = false;
    }

    getRecordIdsFromUrl() {
        const urlParams = new URLSearchParams(window.location.search);
        const raw = urlParams.get('flow__ids');
        if (!raw) return [];
        return raw.split(',').map(id => id.trim()).filter(Boolean);
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
                state: {
                    filterName: 'Recent'
                }
            });

            await new Promise(resolve => setTimeout(resolve, 300));
            await closeTab(this.tabId);

        } catch (e) {
            console.error('closeAndRefresh error:', e);
        }
    }

    async handleDownload() {
        const ids = this.getRecordIdsFromUrl();

        if (!ids.length) {
            this.showError(this.customLabel.errorDownload);
            return;
        }

        this.isLoading = true;

        try {
            const urls = await downloadReport({ downloadReportIds: ids });

            for (let i = 0; i < urls.length; i++) {
                setTimeout(() => {
                    window.open(urls[i], '_blank');
                }, i * 500);
            }

            setTimeout(async () => {
                await this.closeAndRefresh();
            }, urls.length * 500 + 300);

        } catch (e) {
            console.error(e);
        } finally {
            this.isLoading = false;
        }
    }

    async handleCancel() {
        await this.closeAndRefresh();
    }
}