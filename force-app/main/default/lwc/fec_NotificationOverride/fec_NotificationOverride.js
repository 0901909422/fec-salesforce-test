import { api, LightningElement, track, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { IsConsoleNavigation, getFocusedTabInfo, closeTab } from 'lightning/platformWorkspaceApi';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { loadStyle } from "lightning/platformResourceLoader";
import COMMON_STYLES from "@salesforce/resourceUrl/FEC_CommonCss";
import NOTIFICATION_OBJECT from "@salesforce/schema/FEC_Notification__c";
import NAME_FIELD from "@salesforce/schema/FEC_Notification__c.Name";
import TARGET_GROUP_FIELD from "@salesforce/schema/FEC_Notification__c.FEC_Target_Group__c";
import CUSTOMER_TYPE_FIELD from "@salesforce/schema/FEC_Notification__c.FEC_Customer_Type__c";
import CHANNEL_FIELD from "@salesforce/schema/FEC_Notification__c.FEC_Channel__c";
import PRODUCT_TYPE_FIELD from "@salesforce/schema/FEC_Notification__c.FEC_Product_Type__c";
import CATEGORY_FIELD from "@salesforce/schema/FEC_Notification__c.FEC_Category__c";
import SUB_CATEGORY_FIELD from "@salesforce/schema/FEC_Notification__c.FEC_SubCategory__c";
import SUB_CODE_FIELD from "@salesforce/schema/FEC_Notification__c.FEC_SubCode__c";
import CURRENT_STATUS_FIELD from "@salesforce/schema/FEC_Notification__c.FEC_Current_Status__c";
import CHANGED_STATUS_FIELD from "@salesforce/schema/FEC_Notification__c.FEC_Changed_Status__c";
import NOTIFICATION_STATUS_FIELD from "@salesforce/schema/FEC_Notification__c.FEC_Notification_Status__c";
import NOTIFICATION_CHANNEL_FIELD from "@salesforce/schema/FEC_Notification__c.FEC_Notification_Channel__c";
import NOTIFICATION_TEMPLATE_FIELD from "@salesforce/schema/FEC_Notification__c.FEC_Notification_Template__c";
import APPLICABLE_USER_GROUPS_FIELD from "@salesforce/schema/FEC_Notification__c.FEC_Applicable_User_Groups__c";
import CASE_STAGE_FIELD from "@salesforce/schema/FEC_Notification__c.FEC_Case_Stage__c";
import ASSIGNED_TO_QUEUE_FIELD from "@salesforce/schema/FEC_Notification__c.FEC_Assigned_to_Queue__c";
import RECEIVERS_FIELD from "@salesforce/schema/FEC_Notification__c.FEC_Receivers__c";
import SCHEDULE_START_TIME_FIELD from "@salesforce/schema/FEC_Notification__c.FEC_Schedule_Start_Time__c";
import SCHEDULE_END_TIME_FIELD from "@salesforce/schema/FEC_Notification__c.FEC_Schedule_End_Time__c";
import getRecordTypeName from "@salesforce/apex/FEC_Notification.getRecordTypeName";
import getNotificationById from "@salesforce/apex/FEC_Notification.getNotificationById";
import FEC_Tab_Nature_Of_Case from '@salesforce/label/c.FEC_Tab_Nature_Of_Case';
import FEC_Col_Channel from '@salesforce/label/c.FEC_Col_Channel';
import LBL_SearchBtn from '@salesforce/label/c.LBL_SearchBtn';
import FEC_Label_Product_Type from '@salesforce/label/c.FEC_Label_Product_Type';
import FEC_Label_Category from '@salesforce/label/c.FEC_Label_Category';
import FEC_Label_Sub_Category from '@salesforce/label/c.FEC_Label_Sub_Category';
import FEC_Label_Sub_Code from '@salesforce/label/c.FEC_Label_Sub_Code';
import FEC_Notification_Information from '@salesforce/label/c.FEC_Notification_Information';
import FEC_Notification_Template from '@salesforce/label/c.FEC_Notification_Template';
import Cancel from '@salesforce/label/c.Cancel';
import FEC_Button_SaveAndNew from '@salesforce/label/c.FEC_Button_SaveAndNew';
import FEC_Save from '@salesforce/label/c.FEC_Save';
import FEC_Toast_Save_Error_Message from '@salesforce/label/c.FEC_Toast_Save_Error_Message';
import FEC_LABEL_CASE_STATUS from "@salesforce/label/c.FEC_LABEL_CASE_STATUS";
import {
  AUTO_NOTIFICATION_HEADER_VI,
  MANUAL_NOTIFICATION_HEADER_VI,
  AUTO_NOTIFICATION_TYPE,
  MANUAL_NOTIFICATION_TYPE,
  TARGET_GROUP_INTERNAL_USER
} from "c/fec_CommonConst";

import { getRecord } from 'lightning/uiRecordApi';
import FEC_Notification_Channel_Disabled_Msg from "@salesforce/label/c.FEC_Notification_Channel_Disabled_Msg";

const SUB_CATEGORY_OBJECT = "FEC_Sub_Category__c";
const SUB_CODE_OBJECT = "FEC_Sub_Code__c";
/** Nhiều FEC_Case_Status__c.Name trên FEC_Current_Status__c / FEC_Changed_Status__c */
const CASE_STATUS_NAME_DELIMITER = ",";

/** FEC_Customer_Type__c (multi-select): cả 3 giá trị khi Target Group = Internal User (API value theo value set). */
const DEFAULT_INTERNAL_USER_CUSTOMER_TYPES =
  "All;Existing;Non-existing";

/**
 * FEC Notification Override
 * Provides three-section edit form for FEC_Notification__c
 */
export default class Fec_Notification extends NavigationMixin(LightningElement) {
  @api recordId;
  @api recordTypeId;

  // Trackers for lookup UI population (Pills)
  @track initialChannel = [];
  @track initialProductType = [];
  @track initialCategory = [];
  @track initialSubCategory = [];
  @track initialSubCode = [];
  @track initialCurrentStatus = [];
  @track initialChangedStatus = [];
  @track initialAssignedToQueue = [];

  showChannelWarning = false;
  selectedNotiChannelId = null;
  channelDisabled = FEC_Notification_Channel_Disabled_Msg
  isMultiRequired = false;
  FEC_Tab_Nature_Of_Case = FEC_Tab_Nature_Of_Case;
  FEC_Col_Channel = FEC_Col_Channel;
  FEC_Label_Product_Type = FEC_Label_Product_Type;
  LBL_SearchBtn = LBL_SearchBtn;
  FEC_Label_Category = FEC_Label_Category;
  FEC_Label_Sub_Category = FEC_Label_Sub_Category;
  FEC_Label_Sub_Code = FEC_Label_Sub_Code;
  FEC_Notification_Information = FEC_Notification_Information;
  FEC_Notification_Template = FEC_Notification_Template;
  Cancel = Cancel;
  FEC_Button_SaveAndNew = FEC_Button_SaveAndNew;
  FEC_Save = FEC_Save;
  FEC_Toast_Save_Error_Message = FEC_Toast_Save_Error_Message;
  headerLabel;
  @track recordType = {};
  notificationObject = NOTIFICATION_OBJECT;

  // General Information fields
  nameField = NAME_FIELD;
  targetGroupField = TARGET_GROUP_FIELD;
  customerTypeField = CUSTOMER_TYPE_FIELD;
  channelField = CHANNEL_FIELD;

  // Nature of Case fields
  productTypeField = PRODUCT_TYPE_FIELD;
  categoryField = CATEGORY_FIELD;
  subCategoryField = SUB_CATEGORY_FIELD;
  subCodeField = SUB_CODE_FIELD;

  // Notification Information fields
  notificationStatusField = NOTIFICATION_STATUS_FIELD;
  notificationChannelField = NOTIFICATION_CHANNEL_FIELD;
  notificationTemplateField = NOTIFICATION_TEMPLATE_FIELD;
  applicableUserGroupsField = APPLICABLE_USER_GROUPS_FIELD;
  caseStageField = CASE_STAGE_FIELD;
  assignedToQueueField = ASSIGNED_TO_QUEUE_FIELD;
  receiversField = RECEIVERS_FIELD;
  scheduleStartTimeField = SCHEDULE_START_TIME_FIELD;
  scheduleEndTimeField = SCHEDULE_END_TIME_FIELD;
  targetGroup;
  isSaveAndNew = false;
  // Hold selected values from FEC lookup components
  selectedChannelId = null;

  selectedProductTypeId = null;

  selectedCategoryId = null;

  selectedSubCategoryId = null;

  selectedSubCodeId = null;

  //selectedNotificationTemplateId = null;

  selectedAssignedToQueueId = null;

  /** Lưu chuỗi Name (FEC_Case_Status__c.Name), nhiều giá trị phân tách bằng ',' — khớp field text trên notification. */
  // Track Status selections
  selectedCurrentStatus = null;
  selectedChangedStatus = null;

  @wire(IsConsoleNavigation) isConsoleNavigation;

  @wire(getObjectInfo, { objectApiName: '$notificationObject' })
  objectInfo;

  @wire(getRecord, { recordId: '$selectedNotiChannelId', fields: ['FEC_Notification_Channel__c.FEC_Noti_Channel_Status__c'] })
  wiredChannelStatus({ error, data }) {
    if (data) {
      const status = data.fields.FEC_Noti_Channel_Status__c.value;
      // Show warning only if the status explicitly equals false
      this.showChannelWarning = status === false;
    } else if (error) {
      console.error('Error fetching channel status', error);
      this.showChannelWarning = false;
    }
  }

  handleNotificationChannelChange(event) {
    // lightning-input-field lookup returns an array of selected IDs
    const selectedIds = event.detail.value;
    this.selectedNotiChannelId = selectedIds && selectedIds.length > 0 ? selectedIds[0] : null;
    
    if (!this.selectedNotiChannelId) {
      this.showChannelWarning = false;
    }
  }

  get objectLabel() {
    return this.objectInfo?.data?.label;
  }

  /** @param {Array<{id?: string, title?: string, subtitle?: string}>|undefined} rows từ Apex getNotificationById */
  _mapCaseStatusPills(rows, fallbackCsv) {
    const subtitle = 'FEC Case Status';
    if (rows && rows.length) {
      return rows.map((p) => ({
        id: p.id,
        title: p.title,
        subtitle: p.subtitle || subtitle
      }));
    }
    if (!fallbackCsv) {
      return [];
    }
    return fallbackCsv
      .split(CASE_STATUS_NAME_DELIMITER)
      .map((s) => (s || '').trim())
      .filter(Boolean)
      .map((t) => ({ id: t, title: t, subtitle }));
  }

  handleSelected(event) {
    const ids = (event.detail || []).map((e) => e?.id);
    const joined = ids.join(',');
    const dataId = event.currentTarget?.dataset?.id;

    if (dataId === 'currentStatus') {
      const names = (event.detail || [])
        .map((e) => (e?.title != null ? String(e.title).trim() : ''))
        .filter(Boolean);
      this.selectedCurrentStatus = names.length ? names.join(CASE_STATUS_NAME_DELIMITER) : null;
      return;
    }
    if (dataId === 'changedStatus') {
      const names = (event.detail || [])
        .map((e) => (e?.title != null ? String(e.title).trim() : ''))
        .filter(Boolean);
      this.selectedChangedStatus = names.length ? names.join(CASE_STATUS_NAME_DELIMITER) : null;
      return;
    }

    const source = event?.target?.objectApiName;

    switch (source) {
      // Use related Object API Names from lookup components
      case CHANNEL_FIELD.fieldApiName:
        this.selectedChannelId = joined || null;
        break;
      case 'Group': // <--- ADD THIS CASE
        this.selectedAssignedToQueueId = joined || null;
        break;
      case PRODUCT_TYPE_FIELD.fieldApiName:
        if (this.selectedProductTypeId !== joined) {
           this.selectedProductTypeId = joined || null;
           // Cascade reset children
           this.selectedCategoryId = null; this.initialCategory = [];
           this.selectedSubCategoryId = null; this.initialSubCategory = [];
           this.selectedSubCodeId = null; this.initialSubCode = [];
        }
        break;
      case CATEGORY_FIELD.fieldApiName:
        if (this.selectedCategoryId !== joined) {
           this.selectedCategoryId = joined || null;
           // Cascade reset children
           this.selectedSubCategoryId = null; this.initialSubCategory = [];
           this.selectedSubCodeId = null; this.initialSubCode = [];
        }
        break;
      case SUB_CATEGORY_OBJECT:
        if (this.selectedSubCategoryId !== joined) {
           this.selectedSubCategoryId = joined || null;
           // Cascade reset down to sub code
           this.selectedSubCodeId = null; this.initialSubCode = [];
        }
        break;
      case SUB_CODE_OBJECT:
        this.selectedSubCodeId = joined || null;
        break;
      // case 'EmailTemplate':
      //   this.selectedNotificationTemplateId = joined || null;
      //   break;
      default:
        // no-op
        break;
    }
  }

  async closeTab() {
    if (!this.isConsoleNavigation) {
      return;
    }
    const { tabId } = await getFocusedTabInfo();
    await closeTab(tabId);
  }

  get placeholderSearchChannel() {
    return LBL_SearchBtn + ' ' + FEC_Col_Channel + '...';
  }

  get placeholderSearchProductType() {
    return LBL_SearchBtn + ' ' + FEC_Label_Product_Type + '...';
  }

  get placeholderSearchCategory() {
    return LBL_SearchBtn + ' ' + FEC_Label_Category + '...';
  }

  get placeholderSearchSubCategory() {
    return LBL_SearchBtn + ' ' + FEC_Label_Sub_Category + '...';
  }

  get placeholderSearchSubCode() {
    return LBL_SearchBtn + ' ' + FEC_Label_Sub_Code + '...';
  }

  get placeholderSearchCaseStatus() {
    return LBL_SearchBtn + ' ' + FEC_LABEL_CASE_STATUS + '...';
  }

  get placeholderSearchNotificationTemplate() {
    return LBL_SearchBtn + ' ' + FEC_Notification_Template + '...';
  }

  get isCreate() {
    return this.recordId == null;
  }

  // ====== BASE FLAGS ======
  get isAuto() {
    return this.recordType.DeveloperName === 'Auto_Notification';
  }

  get isProductType() {
    return this.selectedProductTypeId == null;
  }

  get isCategory() {
    return this.selectedCategoryId == null;
  }

  get isSubCategory() {
    return this.selectedSubCategoryId == null;
  }

  get isManual() {
    return this.recordType.DeveloperName === 'Manual_Notification';
  }

  get isCustomer() {
    return this.targetGroup === 'Customer';
  }

  get isInternal() {
    return this.targetGroup === TARGET_GROUP_INTERNAL_USER;
  }

  get isDisplay() {
    return this.isCustomer || this.isInternal;
  }

  // ====== FIELD VISIBILITY RULES ======
  // A. Customer Type: chỉ khi Target Group = Customer (Internal User: gán ẩn trong handleSubmit)
  get showCustomerType() {
    return this.isCustomer;
  }

  // B & C. Current Status + Changed Status: Auto + Customer
  get showStatusPair() {
    return this.isAuto && this.isCustomer;
  }

  // D. Applicable User Groups: Manual (Customer or Internal)
  get showApplicableUserGroups() {
    return this.isManual && this.isDisplay;
  }

  // E. Case Stage: Manual (Customer or Internal)
  get showCaseStage() {
    return this.isManual && this.isDisplay;
  }

  // F. Assigned to Queue: Auto + Internal User
  get showAssignedToQueue() {
    return this.isAuto && this.isInternal;
  }

  // G. Receivers: when sending to Internal User (Auto or Manual)
  get showReceivers() {
    return this.isInternal;
  }

  // H & I. Schedule Start/End Time: Auto + Internal User
  get showScheduleWindow() {
    return this.isAuto && this.isInternal;
  }

  connectedCallback() {
    loadStyle(this, COMMON_STYLES).catch(() => { });
    if (this.recordTypeId) {
      getRecordTypeName({ recordTypeId: this.recordTypeId })
        .then((res) => {
          if (res) {
            this.recordType = res;
            switch (res.DeveloperName) {
              case AUTO_NOTIFICATION_TYPE:
                this.headerLabel = AUTO_NOTIFICATION_HEADER_VI;
                break;
              case MANUAL_NOTIFICATION_TYPE:
                this.headerLabel = MANUAL_NOTIFICATION_HEADER_VI;
                break;
              default:
                this.headerLabel = "";
            }
          }
        })
        .catch((e) => {
          console.log('Error getting record type name:', e);
        });
    }
    // if (this.recordId) {
    //   getNotificationById({ recordId: this.recordId })
    //     .then((res) => {
    //       if (res) {
    //         this.headerLabel = 'Edit ' + res.Name;
    //         this.targetGroup = res.FEC_Target_Group__c;
    //         this.recordType.DeveloperName = res.RecordType.DeveloperName;
    //         this.recordTypeId = res.RecordTypeId;
    //         this.selectedNotiChannelId = res.FEC_Notification_Channel__c;
    //       }
    //     })
    //     .catch((e) => {
    //       console.log('Error getting record:', e);
    //     });
    // }

    if (this.recordId) {
      getNotificationById({ recordId: this.recordId })
        .then((response) => {
          if (response && response.record) {
            const res = response.record;

            // Map data to local tracking variables for saving and logic
            this.headerLabel = 'Edit ' + res.Name;
            this.targetGroup = res.FEC_Target_Group__c;
            this.recordType.DeveloperName = res?.RecordType?.DeveloperName;
            this.recordTypeId = res.RecordTypeId;
            this.selectedNotiChannelId = res.FEC_Notification_Channel__c;
            this.selectedChannelId = res.FEC_Channel__c;
            this.selectedProductTypeId = res.FEC_Product_Type__c;
            this.selectedCategoryId = res.FEC_Category__c;
            this.selectedSubCategoryId = res.FEC_SubCategory__c;
            this.selectedSubCodeId = res.FEC_SubCode__c;
            this.selectedAssignedToQueueId = res.FEC_Assigned_to_Queue__c || null;
            this.selectedCurrentStatus = res.FEC_Current_Status__c;
            this.selectedChangedStatus = res.FEC_Changed_Status__c;
            // Populating UI Pills for Multi-Select Channel
            if (res.FEC_Channel__c && response.channels) {
                this.initialChannel = response.channels.map(ch => ({
                    id: ch.Id, title: ch.Name, subtitle: 'FEC_Channel__c'
                }));
            }

            // Multi-select FEC_Case_Status__c: Apex trả Id + Name để lookup loại trừ đúng; fallback split Name nếu không có pill
            this.initialCurrentStatus = this._mapCaseStatusPills(
              response.currentStatusPills,
              res.FEC_Current_Status__c
            );
            this.initialChangedStatus = this._mapCaseStatusPills(
              response.changedStatusPills,
              res.FEC_Changed_Status__c
            );

            // Populating UI Pills for Single-Select Lookups
            if (res.FEC_Product_Type__c) {
                this.initialProductType = [{ id: res.FEC_Product_Type__c, title: res?.FEC_Product_Type__r?.Name }];
            }
            if (res.FEC_Category__c) {
                this.initialCategory = [{ id: res.FEC_Category__c, title: res?.FEC_Category__r?.Name }];
            }
            if (res.FEC_SubCategory__c) {
                this.initialSubCategory = [{ id: res.FEC_SubCategory__c, title: res?.FEC_SubCategory__r?.Name }];
            }
            if (res.FEC_SubCode__c) {
                this.initialSubCode = [{ id: res.FEC_SubCode__c, title: res?.FEC_SubCode__r?.Name }];
            }
            if (res.FEC_Assigned_to_Queue__c && response.queue) {
                this.initialAssignedToQueue = [{ 
                    id: response?.queue?.DeveloperName, 
                    title: response?.queue?.Name, 
                    subtitle: 'Group' 
                }];
            }
          }
        })
        .catch((e) => console.error('Error loading record', e));
    }
  }

  // Keep compatibility in case template uses onchange={handleChange}
  handleChange(event) {
    const v = event.detail?.value !== undefined ? event.detail.value : event.target?.value;
    this.targetGroup = v;
  }

  async handleSubmit(event) {
    event.preventDefault();
    // Collect fields from lightning-record-edit-form
    const fields = { ...event.detail.fields };
    // Map selected lookup IDs into fields if present
    fields[CHANNEL_FIELD.fieldApiName] = this.selectedChannelId || fields[CHANNEL_FIELD.fieldApiName];
    fields[PRODUCT_TYPE_FIELD.fieldApiName] = this.selectedProductTypeId || fields[PRODUCT_TYPE_FIELD.fieldApiName];
    fields[ASSIGNED_TO_QUEUE_FIELD.fieldApiName] = this.selectedAssignedToQueueId || fields[ASSIGNED_TO_QUEUE_FIELD.fieldApiName];
    fields[CATEGORY_FIELD.fieldApiName] = this.selectedCategoryId || fields[CATEGORY_FIELD.fieldApiName];
    fields[SUB_CATEGORY_FIELD.fieldApiName] = this.selectedSubCategoryId;
    fields[SUB_CODE_FIELD.fieldApiName] = this.selectedSubCodeId;
    //fields[NOTIFICATION_TEMPLATE_FIELD.fieldApiName] = this.selectedNotificationTemplateId || fields[NOTIFICATION_TEMPLATE_FIELD.fieldApiName];
    if (this.selectedCurrentStatus !== null) {
      fields[CURRENT_STATUS_FIELD.fieldApiName] = this.selectedCurrentStatus;
    }
    if (this.selectedChangedStatus !== null) {
      fields[CHANGED_STATUS_FIELD.fieldApiName] = this.selectedChangedStatus;
    }
    if (this.targetGroup === TARGET_GROUP_INTERNAL_USER) {
      fields[CUSTOMER_TYPE_FIELD.fieldApiName] = DEFAULT_INTERNAL_USER_CUSTOMER_TYPES;
    }

    let isFormValid = true;
    const lookupComponents = this.template.querySelectorAll('c-fec_-lookup');

    lookupComponents.forEach(lookup => {
      // Only check validity if the lookup is currently active (not disabled)
      if (!lookup.disabled && lookup.reportValidity && !lookup.reportValidity()) {
        isFormValid = false;
      }
    });

    // Block the submission if any active lookup failed validation
    if (!isFormValid) {
      return;
    }

    const recordInput = {
      apiName: NOTIFICATION_OBJECT.objectApiName || 'FEC_Notification__c',
      fields
    };
    this.template.querySelector('lightning-record-edit-form').submit(fields);
  }

  handleSaveAndNew() {
    this.isSaveAndNew = true;
  }

  // Sửa lại hàm closeTab để nhận vào một tabId cụ thể
  async closeCurrentTab(tabId) {
    await closeTab(tabId);
  }

  async handleSuccess(event) {
    const id = event?.detail?.id;
    const name = event?.detail?.fields?.Name?.value;

    // 1. Lấy ID của tab hiện tại NGAY LẬP TỨC trước khi navigate
    let currentTabId = null;
    if (this.isConsoleNavigation) {
      const tabInfo = await getFocusedTabInfo();
      currentTabId = tabInfo.tabId;
    }

    // 2. Hiển thị Toast
    this.dispatchEvent(
      new ShowToastEvent({
        title: this.recordId ? 'Success' : 'Notification created',
        message: this.objectLabel + ' "' + name + '" was ' + (this.recordId ? 'saved.' : 'created.'),
        variant: 'success'
      })
    );

    // 3. Xử lý điều hướng
    if (this.recordId) {
      // Trường hợp Edit: Chỉ cần đóng tab hiện tại
      await this.closeCurrentTab(currentTabId);
    } else if (this.isSaveAndNew) {
      // Trường hợp Create - Save & New
      this.isSaveAndNew = false; // Reset biến flag
      this[NavigationMixin.Navigate]({
        type: 'standard__objectPage',
        attributes: {
          objectApiName: 'FEC_Notification__c',
          actionName: 'new'
        },
        state: {
          useRecordTypeCheck: 'true',
          nooverride: '0'
        }
      });
      await this.closeCurrentTab(currentTabId);
    } else {
      // Trường hợp Create - Save thông thường
      this[NavigationMixin.Navigate]({
        type: 'standard__recordPage',
        attributes: {
          recordId: id,
          objectApiName: 'FEC_Notification__c',
          actionName: 'view'
        }
      });
      // Đóng tab "New" cũ sau khi đã mở tab "View" mới
      setTimeout(() => this.closeCurrentTab(currentTabId), 500);
    }
  }

  handleError(event) {
    let message = FEC_Toast_Save_Error_Message;
    if (event?.detail?.detail) {
      message = event.detail.detail;
    } else if (event?.detail?.message) {
      message = event.detail.message;
    }
    this.dispatchEvent(
      new ShowToastEvent({
        title: 'Save failed',
        message,
        variant: 'error',
        mode: 'sticky'
      })
    );
  }

  handleCancel() {
    // Back-compatible cancel: try to navigate back, else close tab
    try {
      this.reset();
      this.closeTab();
      //window.history.back();
    } catch (e) {
      // no-op
    }

  }

  reset() {
    // Reset local UI-driving state
    this.targetGroup = undefined;

    // Reset stored lookup selections
    this.selectedChannelId = null;
    this.selectedProductTypeId = null;
    this.selectedCategoryId = null;
    this.selectedSubCategoryId = null;
    this.selectedSubCodeId = null;
    //this.selectedNotificationTemplateId = null;
    this.selectedAssignedToQueueId = null;
    this.selectedCurrentStatus = null;
    this.selectedChangedStatus = null;

    // Reset all fields within the lightning-record-edit-form
    const form = this.template.querySelector('lightning-record-edit-form');
    if (form && typeof form.reset === 'function') {
      try {
        form.reset();
      } catch (e) {
        // Swallow to avoid disrupting UX
      }
    }
  }
}