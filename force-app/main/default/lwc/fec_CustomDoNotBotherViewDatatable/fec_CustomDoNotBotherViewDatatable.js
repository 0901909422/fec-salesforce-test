import LightningDatatable from "lightning/datatable";
import customTypeTemplate from "./fec_CustomDoNotBotherViewDatatable.html";

export default class Fec_CustomDoNotBotherViewDatatable extends LightningDatatable {

    static customTypes = {
        maskedContact: {
            template: customTypeTemplate,
            standardCellLayout: true,
            typeAttributes: [
                "maskedValue",
                "rawValue",
                "isVisible",
                "rowId"
            ],
        },
    };
}