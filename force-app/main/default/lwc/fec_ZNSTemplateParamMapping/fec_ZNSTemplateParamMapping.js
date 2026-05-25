import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent }    from 'lightning/platformShowToastEvent';
import getParamMappings      from '@salesforce/apex/FEC_ZNSTemplateParamMappingController.getParamMappings';
import getPageContextOptions from '@salesforce/apex/FEC_ZNSTemplateParamMappingController.getPageContextOptions';
import getFunctionOptions    from '@salesforce/apex/FEC_ZNSTemplateParamMappingController.getFunctionOptions';
import getFieldOptions       from '@salesforce/apex/FEC_ZNSTemplateParamMappingController.getFieldOptions';
import saveParamMappings     from '@salesforce/apex/FEC_ZNSTemplateParamMappingController.saveParamMappings';
import getHistory            from '@salesforce/apex/FEC_ZNSTemplateParamMappingController.getHistory';

// Custom Labels
import previewLabel      from '@salesforce/label/c.FEC_Action_Preview';
import backToListLabel   from '@salesforce/label/c.FEC_Template_Back_To_List';
import lastModLabel      from '@salesforce/label/c.FEC_Col_Last_Modified_Date';
import lastModByLabel    from '@salesforce/label/c.FEC_Col_Last_Modified_By';
import templateHistoryTabLabel from '@salesforce/label/c.FEC_Template_History_Tab';
import FEC_Msg_No_Content from '@salesforce/label/c.FEC_Msg_No_Content';
import FEC_Merge_Field_Cancel from '@salesforce/label/c.FEC_Merge_Field_Cancel';
import FEC_Btn_Finish from '@salesforce/label/c.FEC_Btn_Finish';
import OldValue_Column from '@salesforce/label/c.CS_OrgChart_Table_HistoryLog_OldValue_Column';
import NewValue_Column from '@salesforce/label/c.CS_OrgChart_Table_HistoryLog_NewValue_Column';
import FEC_Field from '@salesforce/label/c.FEC_Field';
import FEC_Template_ID from '@salesforce/label/c.FEC_Template_ID';
import FEC_Btn_History from '@salesforce/label/c.FEC_Btn_History';
import Loading from '@salesforce/label/c.Loading';
import FEC_Button_Save from '@salesforce/label/c.FEC_Button_Save';
import FEC_Opt_Select from '@salesforce/label/c.FEC_Opt_Select';
import FEC_Label_Type from '@salesforce/label/c.FEC_Label_Type';
import FEC_Label_Field_Object_Name from '@salesforce/label/c.FEC_Label_Field_Object_Name';
import FEC_Parameter from '@salesforce/label/c.FEC_Parameter';
import FEC_Page_Context from '@salesforce/label/c.FEC_Page_Context';
import FEC_Function from '@salesforce/label/c.FEC_Function';
import FEC_DT_Search_Placeholder from '@salesforce/label/c.FEC_DT_Search_Placeholder';
import FEC_MSG_No_Data_To_Display from '@salesforce/label/c.FEC_MSG_No_Data_To_Display';
import FEC_Toast_Warning from '@salesforce/label/c.FEC_Toast_Warning';
import FEC_Error_Title from '@salesforce/label/c.FEC_Error_Title';
import FEC_Success_Title from '@salesforce/label/c.FEC_Success_Title';
import FEC_Toast_Save_Error from '@salesforce/label/c.FEC_Toast_Save_Error';
import FEC_Cannot_Refresh_Data from '@salesforce/label/c.FEC_Cannot_Refresh_Data';
import FEC_Save_Template_Config_Success from '@salesforce/label/c.FEC_Save_Template_Config_Success';

// constants
const ASC  = 'asc';
const DESC = 'desc';
const SORT_ICONS = { none: '↕', asc: '↑', desc: '↓' };
const PARAM_NAME = 'paramName';
const PARAM_TYPE = 'paramType';
const FIELD_NAME = 'fieldName';
const PAGE_CONTEXT = 'pageContext';
const FUNCTION_LABEL = 'functionLabel';
const FUNCTION_VALUE = 'functionValue';

export default class Fec_ZNSTemplateParamMapping extends LightningElement {

    // Labels exposed to template
    label = {
        previewLabel,
        backToListLabel,
        lastModLabel,
        lastModByLabel,
        templateHistoryTabLabel,
        FEC_Msg_No_Content,
        FEC_Merge_Field_Cancel,
        FEC_Btn_Finish,
        OldValue_Column,
        NewValue_Column,
        FEC_Field,
        FEC_Template_ID,
        FEC_Btn_History,
        Loading,
        FEC_Button_Save,
        FEC_Opt_Select,
        FEC_Label_Type,
        FEC_DT_Search_Placeholder,
        FEC_Label_Field_Object_Name,
        FEC_Parameter,
        FEC_Page_Context,
        FEC_Function,
        FEC_MSG_No_Data_To_Display,
        FEC_Toast_Warning,
        FEC_Error_Title,
        FEC_Success_Title,
        FEC_Toast_Save_Error,
        FEC_Cannot_Refresh_Data,
        FEC_Save_Template_Config_Success
    };

    /** Lifecycle flag – prevents setter-triggered fetch before connectedCallback */
    _connected = false;

    // ── Internal data ──────────────────────────────────────────────────────
    @track _record = null;
    @track _recordId = null;

    @api
    get record() {
        return this._record;
    }

    set record(value) {
        this._record = value ? JSON.parse(JSON.stringify(value)) : null;
        if (this._record && this._connected) {
            this._recordId = this._record.id;
            this._loadAllData(this._record.subject);
        }
    }

    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
    }

    // ── State ────────────────────────────────────────────────────────────────
    @track allRows          = [];   // master row list (mutated for edits)
    @track selectedRowId    = null;
    @track sortField        = null;
    @track sortDir          = ASC;
    @track filters          = {};   // { fieldName: 'filterText', ... }

    @track pageContextOptions = [];
    @track functionOptions    = [];
    @track fieldOptions       = [];  // current options for selected row's context
    fieldOptionsCache         = {};  // cache: { 'Case': [...opts] }

    @track showHistoryModal  = false;
    @track showPreviewModal  = false;
    @track historyRows       = [];

    @track isLoading         = false;

    /* ═══════════════════════════════════════════ */
    /*  DATA LOADING (imperative Apex)             */
    /* ═══════════════════════════════════════════ */
    async _loadAllData(znsId) {
        this.isLoading = true;

        try {
            const data = await getParamMappings({
                templateId: znsId
            });

            this.allRows = data.map((r) => ({
                id: r.recordId,
                paramName: r.paramName || '',
                paramType: r.paramType || '',
                pageContext: r.pageContext || '',
                fieldName: r.fieldName || '',
                functionValue: r.functionValue || ''
            }));

        } catch (error) {
            console.error('[fec_ZNSTemplateParamMapping] Error loading data:', error);
            this._showToast(this.label.FEC_Error_Title, error?.body?.message || this.label.FEC_Cannot_Refresh_Data,'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    connectedCallback() {
        this._connected = true;
        if (this._record && this._record.subject) {
            this._loadAllData(this._record.subject);
        }
        this._loadStaticOptions();
    }

    renderedCallback() {
        // Set select values for the currently selected row after each render
        if (!this.selectedRowId) return;
        const row = this.allRows.find(r => r.id === this.selectedRowId);
        if (!row) return;
        this._setSelectValue(PAGE_CONTEXT,   row.pageContext);
        this._setSelectValue(FIELD_NAME,     row.fieldName);
        this._setSelectValue(FUNCTION_VALUE, row.functionValue);
    }

    // ── Computed: displayed rows ──────────────────────────────────────────────
    get displayedRows() {
        let rows = [...this.allRows];

        // 1. Filter
        Object.keys(this.filters).forEach(field => {
            const filterVal = (this.filters[field] || '').toLowerCase().trim();
            if (!filterVal) return;
            rows = rows.filter(row => {
                const cellVal = field === 'functionLabel'
                    ? this._getFunctionLabel(row.functionValue)
                    : String(row[field] || '');
                return cellVal.toLowerCase().includes(filterVal);
            });
        });

        // 2. Sort
        if (this.sortField) {
            const dir = this.sortDir === ASC ? 1 : -1;
            rows = [...rows].sort((a, b) => {
                const aVal = this.sortField === 'functionLabel'
                    ? this._getFunctionLabel(a.functionValue)
                    : String(a[this.sortField] || '');
                const bVal = this.sortField === 'functionLabel'
                    ? this._getFunctionLabel(b.functionValue)
                    : String(b[this.sortField] || '');
                return dir * aVal.localeCompare(bVal, 'vi');
            });
        }

        // 3. Annotate for template rendering
        return rows.map(row => ({
            ...row,
            isSelected:     row.id === this.selectedRowId,
            rowClass:       row.id === this.selectedRowId ? 'row-selected' : 'row-normal',
            paramNameClass: row.id === this.selectedRowId ? 'param-name-cell selected-text' : 'param-name-cell',
            functionLabel:  this._getFunctionLabel(row.functionValue)
        }));
    }

    get hasRows()    { return this.displayedRows.length > 0; }
    get hasHistory() { return this.historyRows.length > 0; }

    // ── Sort icons per column ─────────────────────────────────────────────────
    get sortIcon() {
        const icon = (field) => {
            if (this.sortField !== field) return SORT_ICONS.none;
            return this.sortDir === ASC ? SORT_ICONS.asc : SORT_ICONS.desc;
        };
        return {
            paramName:     icon(PARAM_NAME),
            paramType:     icon(PARAM_TYPE),
            pageContext:   icon(PAGE_CONTEXT),
            fieldName:     icon(FIELD_NAME),
            functionLabel: icon(FUNCTION_LABEL)
        };
    }

    // ── Column header class (highlight sorted column) ─────────────────────────
    get colClass() {
        const cls = (field) => this.sortField === field ? 'col-header col-sorted' : 'col-header';
        return {
            paramName:     cls(PARAM_NAME),
            paramType:     cls(PARAM_TYPE),
            pageContext:   cls(PAGE_CONTEXT),
            fieldName:     cls(FIELD_NAME),
            functionLabel: cls(FUNCTION_LABEL)
        };
    }

    // ── Handlers: table interaction ───────────────────────────────────────────

    handleSort(event) {
        const field = event.currentTarget.dataset.field;
        if (this.sortField === field) {
            this.sortDir = this.sortDir === ASC ? DESC : ASC;
        } else {
            this.sortField = field;
            this.sortDir   = ASC;
        }
    }

    handleFilter(event) {
        const field = event.target.dataset.field;
        this.filters = { ...this.filters, [field]: event.target.value };
    }

    handleRowClick(event) {
        const id = event.currentTarget.dataset.id;
        if (this.selectedRowId === id) {
            // Deselect
            this.selectedRowId = null;
            this.fieldOptions  = [];
            return;
        }
        this.selectedRowId = id;
        const row = this.allRows.find(r => r.id === id);
        if (row?.pageContext) {
            this._loadFieldOptions(row.pageContext);
        } else {
            this.fieldOptions = [];
        }
    }

    handlePageContextChange(event) {
        event.stopPropagation();
        const newContext = event.target.value;
        this.allRows = this.allRows.map(r =>
            r.id === this.selectedRowId
                ? { ...r, pageContext: newContext, fieldName: '' }
                : r
        );
        this.fieldOptions = [];
        if (newContext) this._loadFieldOptions(newContext);
    }

    handleFieldNameChange(event) {
        event.stopPropagation();
        const newField = event.target.value;
        this.allRows = this.allRows.map(r =>
            r.id === this.selectedRowId ? { ...r, fieldName: newField } : r
        );
    }

    handleFunctionChange(event) {
        event.stopPropagation();
        const newFn = event.target.value;
        this.allRows = this.allRows.map(r =>
            r.id === this.selectedRowId ? { ...r, functionValue: newFn } : r
        );
    }

    // ── Handler: Save ─────────────────────────────────────────────────────────
    async handleSave() {
        this.isLoading = true;
        try {
            const inputs = this.allRows.map(r => ({
                recordId:      r.id,
                pageContext:   r.pageContext   || '',
                fieldName:     r.fieldName     || '',
                functionValue: r.functionValue || ''
            }));
            await saveParamMappings({ 'inputsJson':JSON.stringify(inputs), 'templateId': this._record.subject });
            await this._loadAllData(this._record.subject);
            this.selectedRowId = null;
            this._showToast(this.label.FEC_Success_Title, this.label.FEC_Save_Template_Config_Success, 'success');
        } catch (ex) {
            this._showToast(this.label.FEC_Error_Title, ex?.body?.message || this.label.FEC_Toast_Save_Error, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ── Handlers: History modal ───────────────────────────────────────────────
    async handleOpenHistory() {
        this.isLoading = true;
        try {
            const rows = await getHistory({ templateId: this._record.subject });
            this.historyRows = rows.map(h => ({
                ...h,
                modifiedOnFormatted: h.modifiedOn
                    ? new Date(h.modifiedOn).toLocaleString('vi-VN')
                    : ''
            }));
        } catch (ex) {
            this._showToast(this.label.FEC_Error_Title, ex?.body?.message || this.label.FEC_Cannot_Refresh_Data, 'error');
        } finally {
            this.isLoading        = false;
            this.showHistoryModal = true;
        }
    }

    handleCloseHistory() { this.showHistoryModal = false; }

    // ── Handlers: Preview modal ───────────────────────────────────────────────
    @api
    handleOpenPreview() {
        if (!this._record.previewZNSUrl || this._record.previewZNSUrl == "") {
            this._showToast(this.label.FEC_Toast_Warning, this.label.FEC_MSG_No_Data_To_Display, 'warning');
            return;
        }
        this.showPreviewModal  = true;
    }

    handleClosePreview() {
        this.showPreviewModal  = false;
    }

    // ── Utility ───────────────────────────────────────────────────────────────
    stopPropagation(event) { event.stopPropagation(); }

    // ── Private helpers ───────────────────────────────────────────────────────

    async _loadStaticOptions() {
        try {
            const [ctxOpts, fnOpts] = await Promise.all([
                getPageContextOptions(),
                getFunctionOptions()
            ]);
            this.pageContextOptions = ctxOpts;
            this.functionOptions    = fnOpts;
        } catch (ex) {
            console.error('[znsParamMapping] loadStaticOptions error:', ex);
        }
    }

    async _loadFieldOptions(objectApiName) {
        if (this.fieldOptionsCache[objectApiName]) {
            this.fieldOptions = this.fieldOptionsCache[objectApiName];
            return;
        }
        try {
            const opts = await getFieldOptions({ objectApiName });
            this.fieldOptionsCache[objectApiName] = opts;
            this.fieldOptions = opts;
        } catch (ex) {
            console.error('[znsParamMapping] loadFieldOptions error:', ex);
            this.fieldOptions = [];
        }
    }

    _getFunctionLabel(value) {
        if (!value) return 'Không';
        const opt = (this.functionOptions || []).find(o => o.value === value);
        return opt ? opt.label : value;
    }

    _setSelectValue(field, value) {
        const el = this.template.querySelector(`select[data-field="${field}"]`);
        if (el && value != null) el.value = value;
    }

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}