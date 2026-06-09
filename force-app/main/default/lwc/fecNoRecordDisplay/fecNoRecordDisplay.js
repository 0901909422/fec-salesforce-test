import { LightningElement } from 'lwc';
import noRecordsToDisplayMsg from '@salesforce/label/c.No_Record_To_Display_Msg';

export default class FecNoRecordDisplay extends LightningElement {
    content = noRecordsToDisplayMsg;
}