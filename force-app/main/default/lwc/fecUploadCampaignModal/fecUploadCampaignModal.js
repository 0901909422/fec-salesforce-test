import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FEC_SHEETJS from '@salesforce/resourceUrl/FEC_SheetJS';
import FEC_SHEETJS_STYLE from '@salesforce/resourceUrl/FEC_SheetJSStyle';
import { convertExcelToTimestamp, SUCCESS_TITLE, FAIL_TITLE, CAMPAIGN_EXCEL_HEADERS, CAMPAIGN_STRING_COLUMNS } from 'c/fecUtils';
import uploadCampaignData from '@salesforce/apex/FEC_CampaignController.uploadCampaignData';
import lblNoFileChosen from '@salesforce/label/c.FEC_Lbl_No_File_Chosen';
import savedDataMsg from '@salesforce/label/c.FEC_Saved_Data';
import errorUploadAtLeastExcelFile from '@salesforce/label/c.FEC_Error_Upload_At_Least_Excel_File';
import errorCannotReadFile from '@salesforce/label/c.FEC_Cannot_Read_File_Message';
import lblHeaderMismatch from '@salesforce/label/c.FEC_Header_Mismatch_Message';
import lblEmptyFile from '@salesforce/label/c.FEC_Empty_File_Message';
import lblUploadCampaignData from '@salesforce/label/c.FEC_Lbl_Upload_Campaign_Data';
import lblUploadInstruction from '@salesforce/label/c.FEC_Lbl_Upload_Instruction';
import lblChooseFile from '@salesforce/label/c.FEC_Lbl_Choose_File';
import lblNoTemplateQuestion from '@salesforce/label/c.FEC_Lbl_No_Template_Question';
import btnDownloadTemplate from '@salesforce/label/c.FEC_Btn_Download_Template';
import btnCancel from '@salesforce/label/c.Cancel';
import btnSave from '@salesforce/label/c.Save';

export default class FecUploadCampaignModal extends LightningElement {
    label = {
        lblNoFileChosen,
        lblUploadCampaignData,
        lblUploadInstruction,
        lblChooseFile,
        lblNoTemplateQuestion,
        btnDownloadTemplate,
        btnCancel,
        btnSave,
        lblHeaderMismatch,
        lblEmptyFile
    };
    @api isShow = false;
    @api selectedCampaignId;

    @track isLoading = false;
    @track fileNameDisplay = this.label.lblNoFileChosen;
    
    selectedFile;
    librariesLoaded = false;

    renderedCallback() {
        if (this.librariesLoaded) return;
        loadScript(this, FEC_SHEETJS)
            .then(() => loadScript(this, FEC_SHEETJS_STYLE))
            .then(() => { this.librariesLoaded = true; })
            .catch(error => { console.error('Error loading XLSX', error); });
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            this.selectedFile = file;
            this.fileNameDisplay = file.name;
        } else {
            this.fileNameDisplay = this.label.lblNoFileChosen;
        }
    }

    downloadTemplate() {
        if (!this.librariesLoaded) return;
        const XLSX = window.XLSX;
        const ws_data = [CAMPAIGN_EXCEL_HEADERS];
        const worksheet = XLSX.utils.aoa_to_sheet(ws_data);

        // Auto column width based on header text length
        worksheet['!cols'] = CAMPAIGN_EXCEL_HEADERS.map(header => ({
            wch: Math.max(header.length + 6, 18)
        }));

        // Style definitions
        const borderStyle = { style: 'thin', color: { rgb: '000000' } };
        const headerStyle = {
            fill: { fgColor: { rgb: 'BDD7EE' } },
            font: { color: { rgb: '000000' } },
            border: {
                top: borderStyle,
                bottom: borderStyle,
                left: borderStyle,
                right: borderStyle
            },
            alignment: { vertical: 'center' }
        };
        const emptyCellStyle = {
            border: {
                top: borderStyle,
                bottom: borderStyle,
                left: borderStyle,
                right: borderStyle
            }
        };

        // Merge header cells across 3 rows (row 0-2) for each column
        // Single-row header with increased height — no merge to avoid impacting validation rules
        worksheet['!rows'] = [{ hpt: 40 }];
        for (let col = 0; col < CAMPAIGN_EXCEL_HEADERS.length; col++) {
            const cellRef = XLSX.utils.encode_cell({ r: 0, c: col });
            if (worksheet[cellRef]) {
                worksheet[cellRef].s = headerStyle;
                if (CAMPAIGN_STRING_COLUMNS.includes(col)) {
                    worksheet[cellRef].z = '@';
                }
            }
        }

        // Add borders for 40 empty data rows below header (starting from row 1)
        for (let row = 1; row <= 40; row++) {
            for (let col = 0; col < CAMPAIGN_EXCEL_HEADERS.length; col++) {
                const cellRef = XLSX.utils.encode_cell({ r: row, c: col });
                worksheet[cellRef] = { v: '', t: 's', s: emptyCellStyle };
                if (CAMPAIGN_STRING_COLUMNS.includes(col)) {
                    worksheet[cellRef].z = '@';
                }
            }
        }

        // Set range to include header (1 row) + 40 empty rows
        worksheet['!ref'] = XLSX.utils.encode_range({ s: { r: 0, c: 0 }, e: { r: 40, c: CAMPAIGN_EXCEL_HEADERS.length - 1 } });

        const workbook = XLSX.utils.book_new();
        XLSX.utils.book_append_sheet(workbook, worksheet, "Template");

        XLSX.writeFile(workbook, "OutboundCampaignManualUpload_Template.xlsx");
    }

    validateHeaders(worksheet) {
        const XLSX = window.XLSX;
        const rawRows = XLSX.utils.sheet_to_json(worksheet, { header: 1 });
        if (!rawRows || rawRows.length === 0) {
            return { isValid: false, errorMessage: lblHeaderMismatch };
        }
        const headerRow = rawRows[0];
        if (headerRow.length !== CAMPAIGN_EXCEL_HEADERS.length) {
            return { isValid: false, errorMessage: lblHeaderMismatch };
        }
        for (let i = 0; i < CAMPAIGN_EXCEL_HEADERS.length; i++) {
            const actual = String(headerRow[i] || '').trim();
            const expected = CAMPAIGN_EXCEL_HEADERS[i];
            if (actual !== expected) {
                return { isValid: false, errorMessage: lblHeaderMismatch };
            }
        }
        return { isValid: true };
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleConfirm() {
        if (!this.selectedFile) {
            this.showToast(FAIL_TITLE, errorUploadAtLeastExcelFile, 'error');
            return;
        }

        this.isLoading = true;
        
        // 1. Đọc file Excel bằng JS
        const reader = new FileReader();
        reader.onload = (e) => {
            const data = e.target.result;
            const XLSX = window.XLSX;

            const workbook = XLSX.read(data, { type: 'binary' });
            const firstSheetName = workbook.SheetNames[0];
            const worksheet = workbook.Sheets[firstSheetName];

            // Validate headers before parsing data
            const headerResult = this.validateHeaders(worksheet);
            if (!headerResult.isValid) {
                this.showToast(FAIL_TITLE, headerResult.errorMessage, 'error');
                this.isLoading = false;
                return;
            }

            const jsonData = XLSX.utils.sheet_to_json(worksheet);

            // Filter out empty rows (rows with no meaningful values, only borders)
            const filteredData = jsonData.filter(row => {
                return Object.values(row).some(val => val !== null && val !== undefined && String(val).trim() !== '');
            });

            // Empty data guard
            if (filteredData.length === 0) {
                this.showToast(FAIL_TITLE, lblEmptyFile, 'error');
                this.isLoading = false;
                return;
            }

            this.sendDataToApex(filteredData);
        };
        reader.onerror = (error) => {
            this.isLoading = false;
            this.showToast(FAIL_TITLE, errorCannotReadFile, 'error');
        };
        reader.readAsBinaryString(this.selectedFile);
    }

    async sendDataToApex(jsonData) {
        this.isLoading = true;

        try {
            const processedData = jsonData.map(row => {
                let newRow = { ...row };
        
                if (newRow['DateTime 1']) newRow['DateTime 1'] = convertExcelToTimestamp(newRow['DateTime 1']);
                if (newRow['DateTime 2']) newRow['DateTime 2'] = convertExcelToTimestamp(newRow['DateTime 2']);
                if (newRow['DateTime 3']) newRow['DateTime 3'] = convertExcelToTimestamp(newRow['DateTime 3']);
    
                return newRow;
            });
    
            const result = await uploadCampaignData({ 
                jsonString: JSON.stringify(processedData), 
                csCampaignId: this.selectedCampaignId 
            })

            if (result === 'Success') {
                this.showToast(SUCCESS_TITLE, savedDataMsg, 'success');
                this.dispatchEvent(new CustomEvent('save'));
            }
        } catch (error) {
            const errorMsg = error.body?.message || error.message;
            this.showToast(FAIL_TITLE, errorMsg, 'error', 'sticky');
        } finally {
            this.resetForm();
            this.isLoading = false;
        }
    }

    resetForm() {
        this.selectedFile = null;
        
        const fileInput = this.template.querySelector('input[type="file"]');
        if (fileInput) {
            fileInput.value = null; 
        }

        this.fileNameDisplay = this.label.lblNoFileChosen;
    }

    showToast(title, message, variant, mode = 'dismissible') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode }));
    }
}