import LBL_OPT_SELECT from '@salesforce/label/c.FEC_Opt_Select';
import LBL_OPT_CIF from '@salesforce/label/c.FEC_Opt_CIF';
import LBL_OPT_ID_CARD from '@salesforce/label/c.FEC_Opt_IDCard';
import LBL_OPT_CONTRACT from '@salesforce/label/c.FEC_Opt_Contract';
import LBL_OPT_ACCOUNT from '@salesforce/label/c.FEC_Opt_Account';
import LBL_OPT_APP_ID from '@salesforce/label/c.FEC_Opt_AppID';
import LBL_OPT_PHONE from '@salesforce/label/c.FEC_Opt_Phone';

// 1. Actions dùng chung cho Header
export const HEADER_ACTIONS = [
    { label: 'Lọc', name: 'filter_action' }
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
