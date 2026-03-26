import LBL_OPT_SELECT from '@salesforce/label/c.FEC_Opt_Select';
import deleteConfirmationTitle from '@salesforce/label/c.FEC_Delete_Confirmation_Title';
import deleteConfirmationMsg from '@salesforce/label/c.FEC_Delete_Confirmation_Msg';
import successTitle from '@salesforce/label/c.FEC_Success_Title';
import failTitle from '@salesforce/label/c.FEC_Fail_Title';
import warningTitle from '@salesforce/label/c.FEC_Warning_Title';
import deletedDataSuccessfullyMsg from '@salesforce/label/c.FEC_Deleted_Data_Successfully_Msg';

export const VIEW_HISTORY_ACTION = 'view_history';
export const FILTER_ACTION = 'filter_action';
export const EDIT_ACTION = 'edit';
export const DELETE_ACTION = 'delete';
export const FILE_ACCEPT = '.xlsx, .xls, .csv';
export const DELETE_CONFIRMATION_TITLE = deleteConfirmationTitle;
export const DELETE_CONFIRMATION_MSG = deleteConfirmationMsg;
export const DELETED_DATA_SUCCESSFULLY_MSG = deletedDataSuccessfullyMsg;
export const SUCCESS_TITLE = successTitle;
export const FAIL_TITLE = failTitle;
export const WARNING_TITLE = warningTitle;

export const HEADER_ACTIONS = [
    { label: 'Lọc', name: FILTER_ACTION }
];

export const ACCOUNT_LINKAGE_OPTIONS = [
    { label: LBL_OPT_SELECT, value: '' },
    { label: 'CIF Number (CIF_NUMBER)', value: 'CIF_NUMBER' },
    { label: 'ID Card / Citizen ID (ID_CARD)', value: 'ID_CARD' },
    { label: 'Contract Number (CONTRACT_NO)', value: 'CONTRACT_NO' },
    { label: 'Account Number (ACCOUNT_NO)', value: 'ACCOUNT_NO' },
    { label: 'Application ID (APPLICATION_ID)', value: 'APPLICATION_ID' },
    { label: 'Primary Phone Number (PHONE_NUMBER)', value: 'PHONE_NUMBER' }
];

// Status constants
export const STATUS_UPLOADED = 'Uploaded';
export const STATUS_REUPLOADED = 'Reuploaded';
export const STATUS_PROCESSING = 'Processing';
export const STATUS_PROCESSED = 'Processed';
export const STATUS_REPROCESS = 'Reprocess';
export const STATUS_CANCELLED = 'Cancelled';
export const STATUS_FAILURE = 'Failure';

// Status groups
export const PENDING_STATUSES = new Set([
    STATUS_UPLOADED, STATUS_REUPLOADED, STATUS_PROCESSING, STATUS_REPROCESS, STATUS_FAILURE
]);
export const PROCESSED_STATUSES = new Set([
    STATUS_PROCESSED, STATUS_CANCELLED
]);
export const DELETABLE_STATUSES = new Set([
    STATUS_UPLOADED, STATUS_REUPLOADED, STATUS_FAILURE
]);
export const EDITABLE_STATUSES = new Set([
    STATUS_UPLOADED, STATUS_REUPLOADED, STATUS_FAILURE, STATUS_PROCESSED
]);
export const CAMPAIGN_EXCEL_HEADERS = [
    "ProductLine",
    "Campaign ID",
    "App ID",
    "Account or Contract number",
    "DateTime 1",
    "DateTime 2",
    "DateTime 3",
    "Number 1",
    "Number 2",
    "Number 3",
    "Number 4",
    "Number 5",
    "String 1",
    "String 2",
    "String 3",
    "String 4",
    "String 5"
];
