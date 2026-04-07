import { LightningElement, api, track } from "lwc";
import createNote from "@salesforce/apex/FEC_CaseRelatedNoteHandler.createNote";
import updateNote from "@salesforce/apex/FEC_CaseRelatedNoteHandler.updateNote";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { SUCCESS_MODAL_TITLE } from "c/fec_CommonConst";

import FEC_RELATED_NOTES_UPDATED_MSG from "@salesforce/label/c.FEC_RELATED_NOTES_UPDATED_MSG";
import FEC_RELATED_NOTES_CREATED_MSG from "@salesforce/label/c.FEC_RELATED_NOTES_CREATED_MSG";

import FEC_RELATED_NOTES_NEW_NOTE_MODAL_TITLE from "@salesforce/label/c.FEC_RELATED_NOTES_NEW_NOTE_MODAL_TITLE";
import FEC_RELATED_NOTES_EDIT_NOTE_MODAL_TITLE from "@salesforce/label/c.FEC_RELATED_NOTES_EDIT_NOTE_MODAL_TITLE";

import FEC_RELATED_NOTES_TABLE_HEADER_TITLE_COLUMN from "@salesforce/label/c.FEC_RELATED_NOTES_TABLE_HEADER_TITLE_COLUMN";
import FEC_RELATED_NOTES_COMPOSE_TEXT_FIELD from "@salesforce/label/c.FEC_RELATED_NOTES_COMPOSE_TEXT_FIELD";
import FEC_ACTION_CANCEL from "@salesforce/label/c.FEC_Action_Cancel";
import FEC_Button_Save from "@salesforce/label/c.FEC_Button_Save";
export default class Fec_NewNoteModal extends LightningElement {
  @api recordId;
  @api isEdit; // 'create' or 'edit'
  @api note;
  @track title = "";
  @track content = "";

  connectedCallback() {
    if (this.note) {
      this.title = this.note.title;
      this.content = this.note.content; // hoặc full content nếu có
    }
  }

  labels = {
    titleField: FEC_RELATED_NOTES_TABLE_HEADER_TITLE_COLUMN,
    composeTextField: FEC_RELATED_NOTES_COMPOSE_TEXT_FIELD,
    cancelBtn: FEC_ACTION_CANCEL,
    saveBtn: FEC_Button_Save,
  };

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

  get modalTitle() {
    return this.note && this.note.id
      ? FEC_RELATED_NOTES_EDIT_NOTE_MODAL_TITLE
      : FEC_RELATED_NOTES_NEW_NOTE_MODAL_TITLE;
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
              title: SUCCESS_MODAL_TITLE,
              message: FEC_RELATED_NOTES_UPDATED_MSG,
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
            title: SUCCESS_MODAL_TITLE,
            message: FEC_RELATED_NOTES_CREATED_MSG,
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
