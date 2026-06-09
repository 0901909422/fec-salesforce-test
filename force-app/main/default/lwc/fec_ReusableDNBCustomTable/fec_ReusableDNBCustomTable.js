import { LightningElement, api } from "lwc";

export default class Fec_ReusableDNBCustomTable extends LightningElement {
  @api data = [];
  @api columns = [];

  get processedColumns() {
    return this.columns.map((col) => {
      return {
        ...col,
        isText: col.type === "text",
        isCheckbox: col.type === "checkbox",
        isContact: col.type === "contact",
        isPicklist: col.type === "picklist",
        isTextarea: col.type === "textarea",
      };
    });
  }
  // get processedData() {
  //   return this.data.map((row) => {
  //     return {
  //       id: row.id,
  //       cells: this.processedColumns.map((col) => {
  //         let displayValue = row[col.fieldName];
  //         let iconName = null;

  //         // ✅ HANDLE CONTACT HERE
  //         if (col.isContact) {
  //           displayValue = row.isHidden ? row.maskedContact : row.contact;

  //           iconName = row.isHidden ? "utility:hide" : "utility:preview";
  //         }

  //         return {
  //           fieldName: col.fieldName,
  //           value: row[col.fieldName],
  //           displayValue,
  //           iconName,
  //           rowId: row.id,

  //           isText: col.isText,
  //           isTextarea: col.isTextarea,
  //           isCheckbox: col.isCheckbox,
  //           isContact: col.isContact,
  //           isPicklist: col.isPicklist,

  //           options: row.reasonOptionsFormatted || [],
  //           isDisabled: col.isPicklist
  //             ? !row.active || row.isReadonly
  //             : row.isReadonly,

  //           isDisabledText: col.isTextarea
  //             ? !row.active || row.isReadonly
  //             : row.isReadonly,
  //           isRequired: row.active,
  //           checkboxLabel:
  //             row[col.checkboxLabelField] || col.checkboxLabel || "",
  //           hasContact: row.hasContact,
  //           isActionDisabled: row.isActionDisabled,

  //           cellClass: this.getCellClass(col),
  //         };
  //       }),
  //     };
  //   });
  // }

  get processedData() {
    return this.data.map((row) => {
      return {
        id: row.id,

        cells: this.processedColumns.map((col) => {
          let displayValue = row[col.fieldName];

          let iconName = null;

          /*
           * CONTACT DISPLAY
           */
          if (col.isContact) {
            displayValue = row.isHidden ? row.maskedContact : row.contact;

            iconName = row.isHidden ? "utility:hide" : "utility:preview";
          }

          /*
           * READONLY DISPLAY
           */
          if (row.isReadonly && col.fieldName === "updateReasonLabel") {
            displayValue = row.updateReasonLabel || "-";
          }

          if (row.isReadonly && col.fieldName === "remarks") {
            displayValue = row.remarks || "-";
          }

          return {
            fieldName: col.fieldName,

            value: row[col.fieldName],

            displayValue,

            iconName,

            rowId: row.id,

            isText: col.isText,

            isTextarea: col.isTextarea,

            isCheckbox: col.isCheckbox,

            isContact: col.isContact,

            isPicklist: col.isPicklist,

            options: row.reasonOptionsFormatted || [],

            /*
             * DISABLE STATES
             */
            isDisabled: col.isPicklist
              ? !row.active || row.isReadonly
              : row.isReadonly,

            isDisabledText: col.isTextarea
              ? !row.active || row.isReadonly
              : row.isReadonly,

            isRequired: row.active,

            checkboxLabel:
              row[col.checkboxLabelField] || col.checkboxLabel || "",

            hasContact: row.hasContact,

            isActionDisabled: row.isActionDisabled || row.isReadonly,

            cellClass: this.getCellClass(col),
          };
        }),
      };
    });
  }

  getCellClass(col) {
    switch (col.fieldName) {
      case "updateReason":
        return "update-reason-cell";

      case "remarks":
        return "remarks-cell";

      default:
        return "";
    }
  }

  handleCheckboxChange(event) {
    const rowId = event.target.dataset.id;
    const field = event.target.dataset.field;
    const checked = event.target.checked;

    this.dispatchEvent(
      new CustomEvent("checkboxchange", {
        detail: {
          id: rowId,
          field: field,
          value: checked,
        },
      }),
    );
  }

  handlePicklistChange(event) {
    const id = event.target.dataset.id;
    const field = event.target.dataset.field;
    const value = event.detail.value;

    this.dispatchEvent(
      new CustomEvent("picklistchange", {
        detail: { id, field, value },
      }),
    );
  }

  handleToggleContact(event) {
    const rowId = event.currentTarget.dataset.id;

    this.data = this.data.map((row) => {
      if (row.id === rowId) {
        return {
          ...row,
          isHidden: !row.isHidden,
        };
      }
      return row;
    });
  }

  handleTextareaChange(event) {
    const id = event.target.dataset.id;
    const field = event.target.dataset.field;
    const value = event.target.value;

    this.dispatchEvent(
      new CustomEvent("textareachange", {
        detail: { id, field, value },
      }),
    );
  }
}
