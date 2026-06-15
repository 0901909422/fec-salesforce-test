import LightningDatatable from "lightning/datatable";
import customTypeTemplate from "./fec_CustomClickToCallPhoneList.html";

export default class Fec_CustomClickToCallPhoneList extends LightningDatatable {

    static customTypes = {
        maskedContact: {
            template: customTypeTemplate,
           standardCellLayout: false,
            typeAttributes: [
                "maskedValue",
                "rawValue",
                "isVisible",
                "rowId"
            ],
        },
    };
}