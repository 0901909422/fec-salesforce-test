import { LightningElement } from 'lwc';
import LABEL_LIVE from '@salesforce/label/c.FEC_Tab_Live_Data';
import LABEL_MDM from '@salesforce/label/c.FEC_Tab_MDM_Data';
import LABEL_SYNC from '@salesforce/label/c.FEC_Tab_Sync_Operations';

export default class FecMdmDataView extends LightningElement {
    labelLive = LABEL_LIVE;
    labelMdm = LABEL_MDM;
    labelSync = LABEL_SYNC;
}