import LightningDatatable from "lightning/datatable";
import maskedContactTemplate from "c/fec_MaskedContactTemplate";
export default class Fec_CustomDoNotBotherViewDatatable extends LightningDatatable {
  static customTypes = {
    maskedContact: {
      template: maskedContactTemplate,
      standardCellLayout: true,
      typeAttributes: ["maskedValue", "rawValue", "isVisible", "rowId"],
    },
  };
}
