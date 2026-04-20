import { LightningElement, track, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { SUCCESS_TITLE, FAIL_TITLE, WARNING_TITLE, CAMPAIGN_INPROGRESS_EXPORT_HEADERS, CAMPAIGN_STRING_COLUMNS } from 'c/fecUtils';
import FEC_SHEETJS from '@salesforce/resourceUrl/FEC_SheetJS';
import FEC_SHEETJS_STYLE from '@salesforce/resourceUrl/FEC_SheetJSStyle';
import getCampaignMappings from '@salesforce/apex/FEC_CampaignController.getCampaignMappings';
import getInProgressSummary from '@salesforce/apex/FEC_CampaignController.getInProgressSummary';
import pushRecords from '@salesforce/apex/FEC_CampaignController.pushRecords';
import saveConfigurationDetails from '@salesforce/apex/FEC_CampaignController.saveConfigurationDetails';
import unableToLoadRecordsMsg from '@salesforce/label/c.FEC_Unable_To_Load_Records_Message';
import savedDataMsg from '@salesforce/label/c.FEC_Saved_Data';
import savingConfigErrMsg from '@salesforce/label/c.FEC_Saving_Configuration_Error_Message';
import selectACampaignMsg from '@salesforce/label/c.FEC_Please_Select_A_Campaign_Message';
import errorLoadExcelLib from '@salesforce/label/c.FEC_Load_Excel_Lib';
import inactiveItemMsg from '@salesforce/label/c.FEC_Label_Status_INACTIVE';
import noContentMsg from '@salesforce/label/c.FEC_Msg_No_Content';
import notifyPushStartedMsg from '@salesforce/label/c.FEC_Notify_Push_Started';
import lblCampaignConfiguration from '@salesforce/label/c.FEC_Lbl_Campaign_Configuration';
import btnSave from '@salesforce/label/c.FEC_Save';
import lblCsCampaignMapping from '@salesforce/label/c.FEC_Lbl_CS_Campaign_Mapping';
import placeholderSelectCampaign from '@salesforce/label/c.FEC_Placeholder_Select_Campaign';
import lblNoOfInprogressRecords from '@salesforce/label/c.FEC_Lbl_No_Of_Inprogress_Records';
import btnDownloadExcel from '@salesforce/label/c.FEC_Btn_Download_Excel';
import lblDbJobAnnouncement from '@salesforce/label/c.FEC_Lbl_DB_Job_Announcement';
import lblEnableSchedule from '@salesforce/label/c.FEC_Lbl_Enable_Schedule';
import lblRunWeekendQuestion from '@salesforce/label/c.FEC_Lbl_Run_Weekend_Question';
import lblSaturday from '@salesforce/label/c.FEC_Lbl_Saturday';
import lblSunday from '@salesforce/label/c.FEC_Lbl_Sunday';
import btnPushRecord from '@salesforce/label/c.FEC_Btn_Push_Record';
import lblUploadCampaignData from '@salesforce/label/c.FEC_Lbl_Upload_Campaign_Data';
import lblRecordLifetime from '@salesforce/label/c.FEC_Lbl_Record_Lifetime';

export default class FecUploadCampaignData extends LightningElement {
    label = {
        lblCampaignConfiguration,
        btnSave,
        lblCsCampaignMapping,
        placeholderSelectCampaign,
        lblNoOfInprogressRecords,
        btnDownloadExcel,
        lblDbJobAnnouncement,
        lblEnableSchedule,
        lblRunWeekendQuestion,
        lblSaturday,
        lblSunday,
        btnPushRecord,
        lblUploadCampaignData,
        lblRecordLifetime
    };

    @track blnIsScheduleEnabled = false;
    @track blnRunSaturday = false;
    @track blnRunSunday = false;
    @track recordLifetime = null;
    @track isSaving = false;
    @track blnIsModalOpen = false;
    @track inProgressCount = 0;
    @track inProgressData = [];
    @track mappingOptions = [];

    selectedMappingId = '';
    rawMappingData = [];
    librariesLoaded = false;
    isLoading = false;
    wiredMappingResult;

    renderedCallback() {
        if (this.librariesLoaded) return;
        loadScript(this, FEC_SHEETJS)
            .then(() => loadScript(this, FEC_SHEETJS_STYLE))
            .then(() => { this.librariesLoaded = true; })
            .catch(error => { console.error('Error loading XLSX', error); });
    }

    @wire(getCampaignMappings)
    wiredMappings(result) {
        this.wiredMappingResult = result;
        const { error, data } = result;
        if (data) {
            this.rawMappingData = data;
            let options = data.map(record => {
                let labelDisplay = record.Name;
                if (!record.FEC_IsActive__c) {
                    labelDisplay = '⛔ ' + labelDisplay;
                }
                return {
                    label: labelDisplay,
                    value: record.Id,
                    isActive: record.FEC_IsActive__c,
                    name: record.Name
                };
            });

            options.sort((a, b) => a.name.localeCompare(b.name));

            this.mappingOptions = options;

        } else if (error) {
            this.showToast(FAIL_TITLE, unableToLoadRecordsMsg + error.body.message, 'error');
        }
    }

    async refreshInProgressDetails() {
        if (!this.selectedMappingId) return;
        
        try {
            const res = await getInProgressSummary({ mappingId: this.selectedMappingId });
            this.inProgressCount = res.count;
            this.inProgressData = res.data;
        } catch (error) {
            console.error('Error refreshing count:', error);
        }
    }

    async handleMappingChange(event) {
        const selectedId = event.detail.value;
        const selectedRecord = this.rawMappingData.find(item => item.Id === selectedId);

        if (selectedRecord && !selectedRecord.FEC_IsActive__c) {
            this.showToast(WARNING_TITLE, `Campaign "${selectedRecord.Name + inactiveItemMsg}"`, 'warning');
            
            this.inProgressCount = 0;
            this.inProgressData = null;
            this.selectedMappingId = '';
            this.recordLifetime = null;
            return; 
        }

        this.selectedMappingId = selectedId;

        if (selectedRecord && selectedRecord.FEC_Campaign__r) {
            // Gán giá trị từ Object cha vào biến UI, mặc định false nếu null
            this.blnIsScheduleEnabled = selectedRecord.FEC_ScheduleCampaign__c || false;
            this.blnRunSaturday = selectedRecord.FEC_SaturdaySchedule__c || false;
            this.blnRunSunday = selectedRecord.FEC_SundaySchedule__c || false;
            this.recordLifetime = selectedRecord.FEC_RecordLifeTime__c ?? null;
        } else {
            // Reset về false nếu không tìm thấy dữ liệu liên quan
            this.blnIsScheduleEnabled = false;
            this.blnRunSaturday = false;
            this.blnRunSunday = false;
            this.recordLifetime = null;
        }
        await this.refreshInProgressDetails();
    }

    findCSCampaignLabel(id) {
        if (id == null) return;
        const csCampaign = this.mappingOptions.find(item => item.value === id);
        return csCampaign.label;
    }

    formatTimestamp(value) {
        if (!value) return '';
        const date = new Date(value);
        if (isNaN(date.getTime())) return '';
        const dd = String(date.getDate()).padStart(2, '0');
        const mm = String(date.getMonth() + 1).padStart(2, '0');
        const yyyy = date.getFullYear();
        const hh = String(date.getHours()).padStart(2, '0');
        const min = String(date.getMinutes()).padStart(2, '0');
        const ss = String(date.getSeconds()).padStart(2, '0');
        return `${dd}/${mm}/${yyyy} ${hh}:${min}:${ss}`;
    }

    handleDownloadExcel() {
            if (!this.librariesLoaded || !window.XLSX) {
                this.showToast(FAIL_TITLE, errorLoadExcelLib, 'error');
                return;
            }

            if (!this.inProgressData || this.inProgressData.length === 0) {
                this.showToast(WARNING_TITLE, noContentMsg, 'info');
                return;
            }

            const XLSX = window.XLSX;
            const headers = CAMPAIGN_INPROGRESS_EXPORT_HEADERS;
            const HEADER_ROWS = 3;

            // Build data: row 0 = header, row 1-2 = empty (merged), row 3+ = data
            const ws_data = [headers, [], []];

            this.inProgressData.forEach(item => {
                ws_data.push([
                    item.FEC_ProductLine__c || '',
                    item.FEC_AppId__c || '',
                    item.FEC_AccountOrContractNumber__c || '',
                    this.findCSCampaignLabel(this.selectedMappingId) || '',
                    item.FEC_DateTime1__c || '',
                    item.FEC_DateTime2__c || '',
                    item.FEC_DateTime3__c || '',
                    item.FEC_Number1__c ?? 0,
                    item.FEC_Number2__c ?? 0,
                    item.FEC_Number3__c ?? 0,
                    item.FEC_Number4__c ?? 0,
                    item.FEC_Number5__c ?? 0,
                    item.FEC_String1__c || '',
                    item.FEC_String2__c || '',
                    item.FEC_String3__c || '',
                    item.FEC_String4__c || '',
                    item.FEC_String5__c || '',
                    this.formatTimestamp(item.CreatedDate),
                    this.formatTimestamp(item.FEC_InsertionDate__c)
                ]);
            });

            const worksheet = XLSX.utils.aoa_to_sheet(ws_data);

            // Auto column width
            worksheet['!cols'] = headers.map(header => ({
                wch: header.length + 4
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
            const dataCellStyle = {
                border: {
                    top: borderStyle,
                    bottom: borderStyle,
                    left: borderStyle,
                    right: borderStyle
                }
            };

            // Merge header cells across 3 rows for each column
            worksheet['!merges'] = [];
            for (let col = 0; col < headers.length; col++) {
                worksheet['!merges'].push({
                    s: { r: 0, c: col },
                    e: { r: 2, c: col }
                });
                const cellRef = XLSX.utils.encode_cell({ r: 0, c: col });
                if (worksheet[cellRef]) {
                    worksheet[cellRef].s = headerStyle;
                    if (CAMPAIGN_STRING_COLUMNS.includes(col)) {
                        worksheet[cellRef].z = '@';
                    }
                }
                for (let row = 1; row <= 2; row++) {
                    const mergedRef = XLSX.utils.encode_cell({ r: row, c: col });
                    worksheet[mergedRef] = { v: '', t: 's', s: headerStyle };
                }
            }

            // Apply borders to all data cells (starting from row 3)
            for (let row = HEADER_ROWS; row < ws_data.length; row++) {
                for (let col = 0; col < headers.length; col++) {
                    const cellRef = XLSX.utils.encode_cell({ r: row, c: col });
                    if (worksheet[cellRef]) {
                        worksheet[cellRef].s = dataCellStyle;
                    }
                }
            }

            // Add 40 extra empty rows with borders after last data row
            const extraRowStart = ws_data.length;
            const extraRowEnd = extraRowStart + 40;
            for (let row = extraRowStart; row < extraRowEnd; row++) {
                for (let col = 0; col < headers.length; col++) {
                    const cellRef = XLSX.utils.encode_cell({ r: row, c: col });
                    worksheet[cellRef] = { v: '', t: 's', s: dataCellStyle };
                }
            }

            // Set range including extra rows
            const lastRow = extraRowEnd - 1;
            worksheet['!ref'] = XLSX.utils.encode_range({ s: { r: 0, c: 0 }, e: { r: lastRow, c: headers.length - 1 } });

            const workbook = XLSX.utils.book_new();
            XLSX.utils.book_append_sheet(workbook, worksheet, "InProgress_Records");

            const fileName = `Campaign_InProgress_${new Date().getTime()}.xlsx`;
            XLSX.writeFile(workbook, fileName);
        }


    handleToggleSchedule(event) {
        this.blnIsScheduleEnabled = event.target.checked;
        if (!this.blnIsScheduleEnabled) {
            this.blnRunSaturday = false;
            this.blnRunSunday = false;
        }
    }

    handleDayChange(event) {
        if (event.target.name === 'saturday') this.blnRunSaturday = event.target.checked;
        if (event.target.name === 'sunday') this.blnRunSunday = event.target.checked;
    }

    handleRecordLifetimeChange(event) {
        const val = event.detail.value;
        this.recordLifetime = val !== '' && val !== null && val !== undefined
            ? parseInt(val, 10) : null;
    }

    get isPushDisabled() {
        return !this.selectedMappingId || this.isLoading;
    }

    /**
     * Xử lý sự kiện lưu cấu hình Schedule
     */
    async handleSaveSchedule() {
        if (!this.selectedMappingId) {
            this.showToast(FAIL_TITLE, selectACampaignMsg, 'error');
            return;
        }

        this.isSaving = true;
        try {
            // Truyền các giá trị cờ hiện tại trên UI xuống Apex
            await saveConfigurationDetails({
                mappingId: this.selectedMappingId,
                isSchedule: this.blnIsScheduleEnabled,
                isSaturday: this.blnRunSaturday,
                isSunday: this.blnRunSunday,
                recordLifetime: this.recordLifetime
            });
            
            await refreshApex(this.wiredMappingResult);
            this.showToast(SUCCESS_TITLE, savedDataMsg, 'success');
        } catch (error) {
            this.showToast(FAIL_TITLE, savingConfigErrMsg + (error.body ? error.body.message : error.message), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    async handlePushRecord() {
        if (!this.selectedMappingId) {
            this.showToast(FAIL_TITLE, selectACampaignMsg, 'error');
            return;
        }
    
        this.isLoading = true;
        try {
            await pushRecords({ mappingId: this.selectedMappingId });
            
            this.showToast(SUCCESS_TITLE, notifyPushStartedMsg, 'success');
            await this.refreshInProgressDetails();
        } catch (error) {
            this.showToast(FAIL_TITLE, error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleUploadFile() {
        await this.refreshInProgressDetails();
        this.closeModal();
    }

    /**
     * Mở Modal khi nhấn nút Upload
     */
    handleUploadData() {
        this.blnIsModalOpen = true;
    }

    /**
     * Đóng Modal
     */
    closeModal() {
        this.blnIsModalOpen = false;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}