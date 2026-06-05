/**
 * @description  Constants specific to the Template Management console.
 *               Shared across all fec_template* LWC components.
 *               Generic project-wide constants live in fec_CommonConst.
 * @module       fec_TemplateConstants
 */

/* ───── Tab / view identifiers ───── */
export const TAB_TEMPLATES = 'templates';
export const TAB_FOLDERS   = 'folders';

/* ───── Filter default ───── */
export const FILTER_ALL = 'All';

/* ───── Active status values ───── */
export const ACTIVE_YES = 'Yes';
export const ACTIVE_NO  = 'No';

/* ───── Row-action names ───── */
export const ACTION_EDIT       = 'edit';
export const ACTION_CLONE      = 'clone';
export const ACTION_DELETE     = 'delete';
export const ACTION_MOVE       = 'move';
export const ACTION_PREVIEW    = 'preview';
export const ACTION_ACTIVATE   = 'activate';
export const ACTION_DEACTIVATE = 'deactivate';
export const ACTION_OPEN       = 'open';
export const ACTION_SAVE_NEW   = 'save_new';
export const ACTION_BACK       = 'back';

/* ───── Event names ───── */
export const EVT_FOLDER_SELECT = 'folderselect';

/* ───── Applicable for Mailbox – static picklist values ───── */
export const MAILBOX_OPTIONS = [
    { label: 'dichvukhachhang@fecredit.com.vn', value: 'dichvukhachhang@fecredit.com.vn' },
    { label: 'dichvukhachhang@ubank.vn',        value: 'dichvukhachhang@ubank.vn' },
    { label: 'supportcsm@fecredit.com.vn',      value: 'supportcsm@fecredit.com.vn' },
    { label: 'cssupport@fecredit.com.vn',        value: 'cssupport@fecredit.com.vn' },
    { label: 'customercare@fecredit.com.vn',     value: 'customercare@fecredit.com.vn' },
    { label: 'e_com@fecredit.com.vn',            value: 'e_com@fecredit.com.vn' },
    { label: 'F2F@fecredit.com.vn',              value: 'F2F@fecredit.com.vn' },
    { label: 'cs_d2c@fecredit.com.vn',           value: 'cs_d2c@fecredit.com.vn' },
    { label: 'CS_OM@fecredit.com.vn',            value: 'CS_OM@fecredit.com.vn' },
    { label: 'CS_QC_TEAM@fecredit.com.vn',       value: 'CS_QC_TEAM@fecredit.com.vn' }
];

/* ───── Active filter options (reusable) ───── */
export const ACTIVE_OPTIONS = [
    { label: 'All', value: FILTER_ALL },
    { label: 'Yes', value: ACTIVE_YES },
    { label: 'No',  value: ACTIVE_NO }
];