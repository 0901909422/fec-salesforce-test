import LightningDatatable from "lightning/datatable";
import radioCell from "./fec_CustomAccountTable.html";

export default class Fec_CustomAccountTable extends LightningDatatable {
  static customTypes = {
    radioCell: {
      template: radioCell,
      standardCellLayout: true,
      typeAttributes: ["rowId", "selected"],
    },
  };
}
