import { LightningElement, track, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';

import downloadReport from '@salesforce/apex/FEC_DownloadReportController.downloadReport';

import FEC_Download_Report from '@salesforce/label/c.FEC_Download_Report';
import FEC_Export_View from '@salesforce/label/c.FEC_Export_View';
import FEC_Formatted_Report from '@salesforce/label/c.FEC_Formatted_Report';
import FEC_Title_Context_Report from '@salesforce/label/c.FEC_Title_Context_Report';
import FEC_Details_Only from '@salesforce/label/c.FEC_Details_Only';
import FEC_Export_Detail from '@salesforce/label/c.FEC_Export_Detail';
import FEC_Format from '@salesforce/label/c.FEC_Format';
import FEC_Format_Excel from '@salesforce/label/c.FEC_Format_Excel';

export default class FEC_DownloadReport extends LightningElement {

    @api recordId;
    @track isLoading = false;


    customLabel = {
        downloadReport: FEC_Download_Report,
        exportView: FEC_Export_View,
        formattedReport: FEC_Formatted_Report,
        titleContextReport: FEC_Title_Context_Report,
        detailsOnly: FEC_Details_Only,
        exportDetail: FEC_Export_Detail,
        format: FEC_Format,
        formatExcel: FEC_Format_Excel
    }

    connectedCallback() {
        setTimeout(() => {
            const allCloseBtns = document.querySelectorAll('.slds-modal__close');
            allCloseBtns.forEach(btn => {
                if (btn.getAttribute('data-id') !== 'header-close') {
                    btn.style.display = 'none';
                }
            });
        }, 100);
    }

    handleCancel() {
        this.dispatchEvent(
            new CloseActionScreenEvent()
        );
    }

    // =========================================================
    // DOWNLOAD FILE
    // =========================================================
    async handleDownload() {

        if (this.isLoading) {
            return;
        }

        this.isLoading = true;

        try {

            const downloadUrl =
                await downloadReport({
                    downloadReportId : this.recordId
                });

            if (!downloadUrl) {
                return;
            }

            // =====================================================
            // DOWNLOAD SALESFORCE FILE
            // =====================================================
            window.open(
                downloadUrl,
                '_blank'
            );

            this.dispatchEvent(
                new CloseActionScreenEvent()
            );

        } catch (e) {

            console.error(JSON.stringify(e)
            );

        } finally {

            this.isLoading = false;
        }
    }
}