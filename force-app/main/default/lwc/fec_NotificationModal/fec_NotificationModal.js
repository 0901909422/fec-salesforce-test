import { LightningElement, api, track, wire } from 'lwc';
import getPicklistValues        from '@salesforce/apex/FEC_NotificationConfigController.getPicklistValues';
//import getTemplatesByChannel    from '@salesforce/apex/FEC_NotificationConfigController.getTemplatesByChannel';
import getSubCategories         from '@salesforce/apex/FEC_NotificationConfigController.getSubCategories';
import getSubCodes              from '@salesforce/apex/FEC_NotificationConfigController.getSubCodes';
import checkDuplicateNotifType  from '@salesforce/apex/FEC_NotificationConfigController.checkDuplicateNotifType';
import saveNotification         from '@salesforce/apex/FEC_NotificationConfigController.saveNotification';
import getNotificationById      from '@salesforce/apex/FEC_NotificationConfigController.getNotificationById';

import FEC_Target_Group from '@salesforce/label/c.FEC_Target_Group';
import FEC_Termination_Loading_Alt from '@salesforce/label/c.FEC_Termination_Loading_Alt';
import FEC_Btn_Close from '@salesforce/label/c.FEC_Btn_Close';
import FEC_Notification_History_Col_Notification_Type from '@salesforce/label/c.FEC_Notification_History_Col_Notification_Type';
import FEC_Label_Customer_Type from '@salesforce/label/c.FEC_Label_Customer_Type';
import FEC_Col_Channel from '@salesforce/label/c.FEC_Col_Channel';
import FEC_Section_Nature_Of_Case from '@salesforce/label/c.FEC_Section_Nature_Of_Case';
import FEC_Label_Product_Type from '@salesforce/label/c.FEC_Label_Product_Type';
import FEC_Label_Category from '@salesforce/label/c.FEC_Label_Category';
import FEC_Placeholder_Select_Category from '@salesforce/label/c.FEC_Placeholder_Select_Category';
import FEC_Sub_Category_Label from '@salesforce/label/c.FEC_Sub_Category_Label';
import FEC_Current_Status from '@salesforce/label/c.FEC_Current_Status';
import FEC_Label_Changed_Status from '@salesforce/label/c.FEC_Label_Changed_Status';
import title_Queue from '@salesforce/label/c.title_Queue';
import FEC_Tab_Case_Stage from '@salesforce/label/c.FEC_Tab_Case_Stage';
import FEC_Notification_Information from '@salesforce/label/c.FEC_Notification_Information';
import FEC_Notification_Template from '@salesforce/label/c.FEC_Notification_Template';
import FEC_Add_Item_Label from '@salesforce/label/c.FEC_Add_Item_Label';
import FEC_Button_Save from '@salesforce/label/c.FEC_Button_Save';
import FEC_Cancel from '@salesforce/label/c.FEC_Cancel';
import FEC_General_Information from '@salesforce/label/c.FEC_General_Information';
import FEC_Notification_Type_Required from '@salesforce/label/c.FEC_Notification_Type_Required';
import FEC_Select_Target_Group from '@salesforce/label/c.FEC_Select_Target_Group';
import FEC_Available from '@salesforce/label/c.FEC_Available';
import FEC_Selected from '@salesforce/label/c.FEC_Selected';
import FEC_Select_Product_Type from '@salesforce/label/c.FEC_Select_Product_Type';
import FEC_Sub_Code_Optional from '@salesforce/label/c.FEC_Sub_Code_Optional';
import FEC_Assigned_To_Queue from '@salesforce/label/c.FEC_Assigned_To_Queue';
import FEC_Receivers from '@salesforce/label/c.FEC_Receivers';
import FEC_Comma_separated_email_addresses from '@salesforce/label/c.FEC_Comma_separated_email_addresses';
import FEC_Schedule_Start_Time from '@salesforce/label/c.FEC_Schedule_Start_Time';
import FEC_Schedule_End_Time from '@salesforce/label/c.FEC_Schedule_End_Time';
import FEC_Applicable_User_Groups from '@salesforce/label/c.FEC_Applicable_User_Groups';
import FEC_Notification_Status_Active from '@salesforce/label/c.FEC_Notification_Status_Active';
import FEC_Notification_Channel from '@salesforce/label/c.FEC_Notification_Channel';
import FEC_Channel_Template_Unique_Message from '@salesforce/label/c.FEC_Channel_Template_Unique_Message';
import FEC_Channel_Template_Empty_Message from '@salesforce/label/c.FEC_Channel_Template_Empty_Message';

let lineKeyCounter = 0;
const newLineKey = () => `line_${++lineKeyCounter}`;

export default class Fec_NotificationModal extends LightningElement {

    labels = {
        FEC_Channel_Template_Empty_Message,
        FEC_Channel_Template_Unique_Message,
        FEC_Notification_Channel,
        FEC_Notification_Status_Active,
        FEC_Applicable_User_Groups,
        FEC_Schedule_Start_Time,
        FEC_Schedule_End_Time,
        FEC_Comma_separated_email_addresses,
        FEC_Receivers,
        FEC_Assigned_To_Queue,
        FEC_Sub_Code_Optional,
        FEC_Select_Product_Type,
        FEC_Selected,
        FEC_Available,
        FEC_Select_Target_Group,
        FEC_Notification_Type_Required,
        FEC_General_Information,
        FEC_Target_Group,
        FEC_Termination_Loading_Alt,
        FEC_Btn_Close,
        FEC_Notification_History_Col_Notification_Type,
        FEC_Label_Customer_Type,
        FEC_Col_Channel,
        FEC_Section_Nature_Of_Case,
        FEC_Label_Product_Type,
        FEC_Label_Category,
        FEC_Placeholder_Select_Category,
        FEC_Sub_Category_Label,
        FEC_Current_Status,
        FEC_Label_Changed_Status,
        title_Queue,
        FEC_Tab_Case_Stage,
        FEC_Notification_Information,
        FEC_Notification_Template,
        FEC_Add_Item_Label,
        FEC_Button_Save,
        FEC_Cancel,
    }

    @api mode       = 'create';   // 'create' | 'edit'
    @api tabType    = 'auto';
    @api recordId   = null;
    @api channels   = [];

    // ── Options ────────────────────────────────────────────────────────────
    @track targetGroupOptions    = [
        { label: 'Customer',       value: 'Customer' },
        { label: 'Internal User',  value: 'Internal User' }
    ];
    @track customerTypeOptions   = [];
    @track productTypeOptions    = [];
    @track categoryOptions       = [];
    @track subCategoryOptions    = [];
    @track subCodeOptions        = [];
    @track caseStatusOptions     = [];
    @track queueOptions          = [];
    @track userGroupOptions      = [];
    @track caseStageOptions      = [];
    @track notifChannelOptions   = [];
    @track allTemplates          = [];     // full list for filtering
    @track channelTemplateLines  = [];

    // ── Form State ─────────────────────────────────────────────────────────
    @track formData = {
        notificationType  : '',
        targetGroup       : '',
        customerType      : [],
        notificationStatus: true,
        channel           : [],
        productType       : '',
        category          : '',
        subCategory       : [],
        subCode           : [],
        currentStatus     : [],
        changedStatus     : [],
        assignedToQueue   : '',
        receivers         : '',
        scheduleStartTime : null,
        scheduleEndTime   : null,
        applicableUserGroups: [],
        caseStage         : [],
    };

    @track isLoading       = false;
    @track duplicateError = '';
    @track lineError      = '';

    // ── Lifecycle ──────────────────────────────────────────────────────────
    async connectedCallback() {
        this.isLoading = true;
        try {
        await this.initOptions();
        this.initLines();
        if (this.mode === 'edit' && this.recordId) {
            await this.loadExistingRecord();
        }
        } catch(e) {
            console.error('Error connectedCallback:', e);
        }
        finally {
            this.isLoading = false;
        }
    }

    async initOptions() {
        try {
            const pv = await getPicklistValues();
            this.customerTypeOptions  = this.toOptions(pv.customerTypes);
            this.productTypeOptions   = this.toOptions(pv.productTypes, true);
            this.categoryOptions      = this.toOptions(pv.categories, true);
            this.caseStatusOptions    = this.toOptions(pv.caseStatuses, true);
            this.queueOptions         = this.toOptions(pv.queues, true);
            this.userGroupOptions     = this.toOptions(pv.userGroups);
            this.caseStageOptions     = this.toOptions(pv.caseStages, true);
            this.allTemplates         = pv.templates || [];

            // Notification channels from parent prop
            this.notifChannelOptions = (this.channels || []).map(c => ({
                label: c.Name,
                value: c.Id,
                //isChannelActive: c.FEC_Noti_Channel_Status__c
            }));

            // Channel (FEC_Channel__c) — product channels, not notification channels
            this.channelOptions = this.toOptions(pv.channels, true);
        } catch (e) {
            console.error('Error loading picklist options:', e);
        }
    }

    initLines() {
        this.channelTemplateLines = [this.buildLine()];
    }

    buildLine(channelId = '', templateId = '', isChannelActive = true) {
        return {
            key                : newLineKey(),
            channelId,
            isChannelActive,
            templateId,
            templateOptions    : this.getTemplateOptionsForChannel(channelId),
            isTemplateDisabled : !channelId,
        };
    }

    async loadExistingRecord() {
        try {
            const rec = await getNotificationById({ recordId: this.recordId });
            if (rec.RecordType.Name === "Auto Notification" || rec.RecordType.DeveloperName === "Auto_Notification") {
                this.tabType = "auto";
            } else {
                this.tabType = "manual";
            }

            await this.loadSubCategories(rec.FEC_Product_Type__c, rec.FEC_Category__c);
            await this.loadSubCodes(rec.FEC_Product_Type__c, rec.FEC_Category__c, this.splitDelimited(rec.FEC_SubCategory__c));
            this.formData = {
                notificationType   : rec.Name || '',
                targetGroup        : rec.FEC_Target_Group__c || '',
                customerType       : this.splitDelimited(rec.FEC_Customer_Type__c,';'),
                notificationStatus : !!rec.FEC_Notification_Status__c,
                channel            : this.normalizeSelectedValues(rec.FEC_Channel__c, this.channelOptions),
                productType        : rec.FEC_Product_Type__c || '',
                category           : rec.FEC_Category__c || '',
                subCategory        : this.normalizeSelectedValues(rec.FEC_SubCategory__c, this.subCategoryOptions),
                subCode            : this.normalizeSelectedValues(rec.FEC_SubCode__c, this.subCodeOptions),
                currentStatus      : this.normalizeSelectedValues(rec.FEC_Current_Status__c, this.caseStatusOptions),
                changedStatus      : this.normalizeSelectedValues(rec.FEC_Changed_Status__c, this.caseStatusOptions),
                assignedToQueue    : rec.FEC_Assigned_to_Queue__c || '',
                receivers          : rec.FEC_Receivers__c || '',
                scheduleStartTime  : this.msToTimeString(rec.FEC_Schedule_Start_Time__c),
                scheduleEndTime    : this.msToTimeString(rec.FEC_Schedule_End_Time__c),
                applicableUserGroups: this.normalizeSelectedValues(rec.FEC_Applicable_User_Groups__c, this.userGroupOptions, ';'),
                caseStage          : this.normalizeSelectedValues(rec.FEC_Case_Stage__c, this.caseStageOptions),
            };

            // Rebuild lines from junction records
            const junctions = rec.Notification_Template_Channel__r || [];
            if (junctions.length > 0) {
                this.channelTemplateLines = junctions.map(j =>
                    this.buildLine(j.FEC_Notification_Channel__c, j.FEC_Notification_Template__c, j.FEC_Notification_Channel__r.FEC_Noti_Channel_Status__c)
                );
            }
        } catch (e) {
            console.error('Error loading record:', e);
        }
    }

    // ── Computed ───────────────────────────────────────────────────────────
    get modalTitle() {
        const action = this.mode === 'edit' ? 'Edit' : 'Add';
        const tab    = this.tabType === 'auto' ? 'Auto' : 'Manual';
        return `${action} ${tab} Notification`;
    }

    get isCustomer()    { return this.formData.targetGroup === 'Customer'; }
    get isInternalUser(){ return this.formData.targetGroup === 'Internal User'; }
    get isManual()      { return this.tabType === 'manual'; }
    get isAuto()        { return this.tabType === 'auto'; }
    get isOnlyLine()    { return this.channelTemplateLines.length <= 1; }

    get isCategoryDisabled()   { return !this.formData.productType; }
    get isSubCategoryDisabled(){ return !this.formData.category; }
    get isSubCodeDisabled()    { return this.formData.subCategory.length === 0; }

    get channelOptions() { return this._channelOptions || []; }
    set channelOptions(v){ this._channelOptions = v; }

    getTemplateOptionsForChannel(channelId) {
        if (!channelId) return [];
        const isZnsChannel = this.notifChannelOptions.some(c => c.label === 'ZNS' && c.value === channelId);
        return this.allTemplates
            .filter(t => !!(t.isZNS === 'true') === isZnsChannel)
            .map(t => ({ label: t.Name, value: t.Id }));
    }

    getIsChannelActive(channelId) {
        return this.channels.some(
            c => c.Id === channelId && c.FEC_Noti_Channel_Status__c
    );
}

    // ── Field Change Handlers ──────────────────────────────────────────────
    handleFieldChange(evt) {
        const field = evt.currentTarget.dataset.field;
        const value = evt.detail.value;
        this.formData = { ...this.formData, [field]: value };

        if (field === 'notificationType') { this.duplicateError = ''; }
    }

    handleCheckboxChange(evt) {
        const field = evt.currentTarget.dataset.field;
        this.formData = { ...this.formData, [field]: evt.detail.checked };
    }

    async handleProductTypeChange(evt) {
        this.formData = {
            ...this.formData,
            productType : evt.detail.value,
            category    : '',
            subCategory : [],
            subCode     : [],
        };
        this.categoryOptions    = [];
        this.subCategoryOptions = [];
        this.subCodeOptions     = [];
        try {
            const cats = await getPicklistValues({ filterType: 'categories', productTypeId: evt.detail.value });
            this.categoryOptions = this.toOptions(cats.categories, true);
        } catch (e) { console.error(e); }
    }

    async handleCategoryChange(evt) {
        this.formData = {
            ...this.formData,
            category    : evt.detail.value,
            subCategory : [],
            subCode     : [],
        };
        this.subCategoryOptions = [];
        this.subCodeOptions     = [];
        await this.loadSubCategories(this.formData.productType, evt.detail.value);
    }

    async loadSubCategories(productTypeId, categoryId) {
        if (!categoryId) return;
        try {
            const items = await getSubCategories({ productTypeId, categoryId });
            this.subCategoryOptions = items.map(s => ({ label: s.Name, value: s.FEC_Code__c }));
        } catch (e) { console.error(e); }
    }

    async handleSubCategoryChange(evt) {
        const selected = evt.detail.value;
        this.formData = { ...this.formData, subCategory: selected, subCode: [] };
        this.subCodeOptions = [];
        await this.loadSubCodes(this.formData.productType, this.formData.category, selected);
    }

    async loadSubCodes(productTypeId, categoryId, subCategoryIds) {
        if (!subCategoryIds || subCategoryIds.length === 0) return;
        try {
            const items = await getSubCodes({ productTypeId, categoryId, subCategoryIds });
            this.subCodeOptions = items.map(s => ({ label: s.Name, value: s.FEC_Code__c }));
        } catch (e) { console.error(e); }
    }

    // ── Channel / Template Line Handlers ───────────────────────────────────
    handleAddLine() {
        this.channelTemplateLines = [...this.channelTemplateLines, this.buildLine()];
        this.lineError = '';
    }

    handleDeleteLine(evt) {
        const key = evt.currentTarget.dataset.key;
        this.channelTemplateLines = this.channelTemplateLines.filter(l => l.key !== key);
    }

    handleLineChange(evt) {
        const key   = evt.currentTarget.dataset.key;
        const field = evt.currentTarget.dataset.field;
        const value = evt.detail.value;

        if (field === 'channelId') {
            const isChannelExist = this.channelTemplateLines.some(
                line =>
                    line.key !== key &&
                    line.channelId === value
            );

            evt.target.setCustomValidity(
                isChannelExist ? this.labels.FEC_Channel_Template_Unique_Message : ''
            );

            evt.target.reportValidity();
        }

        this.channelTemplateLines = this.channelTemplateLines.map(line => {
            if (line.key !== key) return line;
            if (field === 'channelId') {
                return {
                    ...line,
                    channelId          : value,
                    templateId         : '',
                    templateOptions    : this.getTemplateOptionsForChannel(value),
                    isTemplateDisabled : !value,
                    isChannelActive: this.getIsChannelActive(value),
                };
            }
            return { ...line, [field]: value };
        });
    }

    // ── Save / Cancel ──────────────────────────────────────────────────────
    async handleSave() {
        if (!this.validateForm()) return;

        // Async duplicate check
        try {
            const isDup = await checkDuplicateNotifType({
                notifType : this.formData.notificationType,
                excludeId : this.recordId
            });
            if (isDup) {
                this.duplicateError = `Notification Type "${this.formData.notificationType}" already exists.`;
                return;
            }
        } catch (e) {
            console.error(e);
        }

        this.isLoading = true;

        //map channel from Id to Name
        this.formData.currentStatus = this.formData.currentStatus.map(
            id =>this.caseStatusOptions.find(option => option.value === id)?.label || id);
        this.formData.changedStatus = this.formData.changedStatus.map(
            id =>this.caseStatusOptions.find(option => option.value === id)?.label || id);

        //map channel from Id to Name
        this.formData.channel = this.formData.channel.map(
            id => this.channelOptions.find(option => option.value === id)?.label || id);

        //map case stage from Id to Name
        this.formData.caseStage = this.formData.caseStage.map(
            id => this.caseStageOptions.find(option => option.value === id)?.label || id);

        try {
            const payload = {
                recordId          : this.recordId,
                tabType           : this.tabType,
                notificationType  : this.formData.notificationType,
                targetGroup       : this.formData.targetGroup,
                customerType      : this.formData.customerType.join(';'),
                notificationStatus: this.formData.notificationStatus,
                channel           : this.formData.channel.join(','),
                productType       : this.formData.productType,
                category          : this.formData.category,
                subCategory       : this.formData.subCategory.join(','),
                subCode           : this.formData.subCode.join(','),
                currentStatus     : this.formData.currentStatus.join(','),
                changedStatus     : this.formData.changedStatus.join(','),
                assignedToQueue   : this.formData.assignedToQueue,
                receivers         : this.formData.receivers,
                scheduleStartTime : this.formData.scheduleStartTime,
                scheduleEndTime   : this.formData.scheduleEndTime,
                applicableUserGroups: this.formData.applicableUserGroups.join(';'),
                caseStage         : this.formData.caseStage.join(','),
                channelTemplateLines: JSON.stringify(
                    this.channelTemplateLines.map(l => ({
                        channelId : l.channelId,
                        templateId: l.templateId
                    }))
                )
            };
            await saveNotification({ payload: JSON.stringify(payload) });
            this.dispatchEvent(new CustomEvent('modalsave', { bubbles: true, composed: true }));
        } catch (e) {
            console.error('Save error:', e);
            alert(e.body.message);
            this.handleCancel();
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('modalclose', { bubbles: true, composed: true }));
    }

    // ── Validation ─────────────────────────────────────────────────────────
    validateForm() {
        let valid = true;

        // LWC built-in validity
        this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-dual-listbox')
            .forEach(el => {
                if (el.reportValidity) { if (!el.reportValidity()) valid = false; }
            });

        // Channel/template line validation
        this.lineError = '';
        for (const line of this.channelTemplateLines) {
            if (!line.channelId || !line.templateId) {
                this.lineError = this.labels.FEC_Channel_Template_Empty_Message;
                valid = false;
                break;
            }
        }

        return valid;
    }

    // ── Helpers ────────────────────────────────────────────────────────────
    toOptions(arr = [], withId = false) {
        return arr.map(item =>
            withId
                ? { label: item.Name || item.label, value: item.Id || item.value }
                : { label: item.label || item, value: item.value || item }
        );
    }

    splitDelimited(str, delimiter = ',') {
        if (!str) return [];
        return str.split(delimiter).map(s => s.trim()).filter(Boolean);
    }

    get notificationTypeClass() {
        return this.getFieldClass('notificationType');
    }

    getFieldClass(field) {
        return this.formData[field] ? '' : 'field-error';
    }

    /**
     * Chuẩn hóa chuỗi chứa Id hoặc Label thành mảng các Id hợp lệ cho Dual Listbox / Combobox
     * @param {String} rawString - Chuỗi dữ liệu đầu vào (Ví dụ: "Id1,Id2" hoặc "Label1,Label2")
     * @param {Array} options - Danh sách options gốc [{label: '...', value: '...'}]
     * @param {String} delimiter - chuỗi phân cách trong dữ liệu đầu vào
     * @returns {Array} Mảng các value (Id) đã được chuẩn hóa
     */
    normalizeSelectedValues = (rawString, options, delimiter = ',') => {
        if (!rawString || !options || options.length === 0) return [];

        // Tách chuỗi bằng dấu phẩy và xóa khoảng trắng
        const rawItems = rawString.split(delimiter).map(item => item.trim());

        return rawItems.map(item => {
            // 1. Tìm theo Value (Id)
            const matchByValue = options.find(opt => String(opt.value).toLowerCase() === String(item).toLowerCase());
            if (matchByValue) return matchByValue.value;

            // 2. Tìm theo Label
            const matchByLabel = options.find(opt => String(opt.label).toLowerCase() === String(item).toLowerCase());
            if (matchByLabel) return matchByLabel.value;

            return null;
        }).filter(item => item !== null);
    };


    /**
     * Salesforce Time field → ISO 8601 string cho lightning-input type="time"
     * Input:  4500000  (milliseconds)
     * Output: "01:15:00.000Z"
     */
    msToTimeString(ms) {
        if (ms === null || ms === undefined || ms === '') return null;

        // Nếu đã là string ISO rồi thì giữ nguyên
        if (typeof ms === 'string' && ms.includes(':')) return ms;

        const totalSeconds = Math.floor(Number(ms) / 1000);
        const hh = String(Math.floor(totalSeconds / 3600)).padStart(2, '0');
        const mm = String(Math.floor((totalSeconds % 3600) / 60)).padStart(2, '0');
        const ss = String(totalSeconds % 60).padStart(2, '0');
        const millis = String(Number(ms) % 1000).padStart(3, '0');

        return `${hh}:${mm}:${ss}.${millis}Z`;
    }
}