import { LightningElement, api, track } from "lwc";
import createNote from "@salesforce/apex/FEC_CaseRelatedNoteHandler.createNote";
import updateNote from "@salesforce/apex/FEC_CaseRelatedNoteHandler.updateNote";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
export default class Fec_NewNoteModal extends LightningElement {
  @api recordId;
  @api note;
  @track title = "";
  @track content = "";

  connectedCallback() {
    if (this.note) {
      this.title = this.note.title;
      this.content = this.note.preview; // hoặc full content nếu có
    }
  }

  handleTitle(event) {
    this.title = event.target.value;
  }

  handleContent(event) {
    this.content = event.target.value;
  }

  handleClose() {
    this.title = "";
    this.content = "";
    this.dispatchEvent(new CustomEvent("close"));
  }

  handleSave() {
    // 👉 UPDATE mode
    if (this.note && this.note.id) {
      updateNote({
        noteId: this.note.id,
        title: this.title,
        content: this.content,
      })
        .then(() => {
          this.dispatchEvent(
            new ShowToastEvent({
              title: "Success",
              message: "Note updated",
              variant: "success",
            }),
          );
          this.dispatchEvent(new CustomEvent("success"));
        })
        .catch((error) => {
          console.error(error);
        });

      return;
    }

    // 👉 CREATE mode
    createNote({
      recordId: this.recordId,
      title: this.title,
      content: this.content,
    })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Note created",
            variant: "success",
          }),
        );
        this.dispatchEvent(new CustomEvent("success"));
      })
      .catch((error) => {
        console.error(error);
      });
  }
}