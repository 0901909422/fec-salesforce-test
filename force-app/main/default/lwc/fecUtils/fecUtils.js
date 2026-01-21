import * as Constants from './fecConstants';
import * as Helpers from './fecHelpers';

// Export Constants
export const HEADER_ACTIONS = Constants.HEADER_ACTIONS;
export const COLUMNS_PROCESSED = Constants.COLUMNS_PROCESSED;
export const ACCOUNT_LINKAGE_OPTIONS = Constants.ACCOUNT_LINKAGE_OPTIONS;
export const VIEW_HISTORY_ACTION = Constants.VIEW_HISTORY_ACTION;
export const FILTER_ACTION = Constants.FILTER_ACTION;
export const EDIT_ACTION = Constants.EDIT_ACTION;
export const DELETE_ACTION = Constants.DELETE_ACTION;
export const FILE_ACCEPT = Constants.FILE_ACCEPT;
export const DELETE_CONFIRMATION_TITLE = Constants.DELETE_CONFIRMATION_TITLE;
export const DELETE_CONFIRMATION_MSG = Constants.DELETE_CONFIRMATION_MSG;
export const DELETED_DATA_SUCCESSFULLY_MSG = Constants.DELETED_DATA_SUCCESSFULLY_MSG;
export const SUCCESS_TITLE = Constants.SUCCESS_TITLE;
export const FAIL_TITLE = Constants.FAIL_TITLE;
export const WARNING_TITLE = Constants.WARNING_TITLE;

// Export Status Constants
export const STATUS_UPLOADED = Constants.STATUS_UPLOADED;
export const STATUS_REUPLOADED = Constants.STATUS_REUPLOADED;
export const STATUS_PROCESSING = Constants.STATUS_PROCESSING;
export const STATUS_PROCESSED = Constants.STATUS_PROCESSED;
export const STATUS_REPROCESS = Constants.STATUS_REPROCESS;
export const STATUS_CANCELLED = Constants.STATUS_CANCELLED;
export const STATUS_FAILURE = Constants.STATUS_FAILURE;

// Export Status Groups
export const PENDING_STATUSES = Constants.PENDING_STATUSES;
export const PROCESSED_STATUSES = Constants.PROCESSED_STATUSES;
export const DELETABLE_STATUSES = Constants.DELETABLE_STATUSES;
export const EDITABLE_STATUSES = Constants.EDITABLE_STATUSES;

// Export Helpers
export const sortData = Helpers.sortData;
export const formatDateDDMMYYYY = Helpers.formatDateDDMMYYYY;
export const formatString = Helpers.formatString;
export const getTomorrowDate = Helpers.getTomorrowDate;
export const convertExcelToTimestamp = Helpers.convertExcelToTimestamp;
