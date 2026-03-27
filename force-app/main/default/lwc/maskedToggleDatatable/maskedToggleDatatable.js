import LightningDatatable from 'lightning/datatable';
import maskedTemplate from './maskedToggleDatatable_masked.html';
import dblclickTemplate from './maskedToggleDatatable_dblclick.html';

export default class MaskedToggleDatatable extends LightningDatatable {
    static customTypes = {
        maskedToggle: {
            template: maskedTemplate,
            standardCellLayout: true,
            typeAttributes: ['caseId']
        },
        dblclickText: {
            template: dblclickTemplate,
            standardCellLayout: true,
            typeAttributes: ['value', 'fieldName', 'selectedType']
        }
    };
}