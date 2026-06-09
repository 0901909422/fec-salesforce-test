import LightningDatatable from "lightning/datatable";
import radioCell    from "./fec_RadioCell.html";
import nameLinkCell from "./fec_NameLinkCell.html";
import conditionalTextCell from "./fec_ConditionalTextCell.html";

export default class Fec_CustomDatatable extends LightningDatatable {
  static customTypes = {
    radioCell: {
      template: radioCell,
      standardCellLayout: true,
      typeAttributes: ["rowId", "selected"],
    },
    nameLink: {
      template: nameLinkCell,
      standardCellLayout: true,
      typeAttributes: ["label", "rowId", "columnName"],
    },
    conditionalText: {
      template: conditionalTextCell,
      standardCellLayout: true,
      typeAttributes: ["isStrikethrough"],
    },
  };
}