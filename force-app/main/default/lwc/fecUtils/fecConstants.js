import LBL_OPT_SELECT from '@salesforce/label/c.FEC_Opt_Select';
import LBL_OPT_CIF from '@salesforce/label/c.FEC_Opt_CIF';
import LBL_OPT_ID_CARD from '@salesforce/label/c.FEC_Opt_IDCard';
import LBL_OPT_CONTRACT from '@salesforce/label/c.FEC_Opt_Contract';
import LBL_OPT_ACCOUNT from '@salesforce/label/c.FEC_Opt_Account';
import LBL_OPT_APP_ID from '@salesforce/label/c.FEC_Opt_AppID';
import LBL_OPT_PHONE from '@salesforce/label/c.FEC_Opt_Phone';
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
    { label: LBL_OPT_CIF, value: 'CIF' },
    { label: LBL_OPT_ID_CARD, value: 'ID_CARD' },
    { label: LBL_OPT_CONTRACT, value: 'CONTRACT_NO' },
    { label: LBL_OPT_ACCOUNT, value: 'ACCOUNT_NO' },
    { label: LBL_OPT_APP_ID, value: 'APPLICATION_ID' },
    { label: LBL_OPT_PHONE, value: 'PHONE' }
];
