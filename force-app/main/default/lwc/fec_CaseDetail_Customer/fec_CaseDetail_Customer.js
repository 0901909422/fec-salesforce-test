import { LightningElement, track, api, wire } from "lwc";
import {
  subscribe,
  unsubscribe,
  publish,
  APPLICATION_SCOPE,
  MessageContext
} from "lightning/messageService";
import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";
import CASE_NOC from "@salesforce/messageChannel/FEC_Case_NOC__c";

import FEC_Case_Remark_Label from "@salesforce/label/c.FEC_Case_Remark_Label";
import FEC_Button_Save_Close from "@salesforce/label/c.FEC_Button_Save_Close";
import FEC_Button_Submit from "@salesforce/label/c.FEC_Button_Submit";

const REQUIRED_MSG = "{0} can't be Blank";

export default class Fec_CaseDetail_Customer extends LightningElement {
  @api recordId;
  @api modeEditCase;

  @wire(MessageContext)
  messageContext;

  subscription = null;
  nocSubscription = null;

  activeSections = ["case-remark"];

  @track errlst = [];

  get hasError() {
    return this.errlst && this.errlst.length > 0;
  }

  customLabel = {
    caseRemarkLabel: FEC_Case_Remark_Label,
    btnSaveClose: FEC_Button_Save_Close,
    btnSubmit: FEC_Button_Submit
  }

  connectedCallback() {
    this.subscribeToMessageChannel();

    this.isLoaded = true;
  }

  subscribeToMessageChannel() {
    this.subscription = subscribe(
      this.messageContext,
      IS_MODE_EDIT,
      (message) => this.handleMessage(message),
      { scope: APPLICATION_SCOPE }
    );

    this.nocSubscription = subscribe(
      this.messageContext,
      CASE_NOC,
      (message) => this.handleNOCMsg(message),
      { scope: APPLICATION_SCOPE }
    );
  }

  handleMessage(message) {
    this.modeEditCase = message.isModeEdit;

    const caseBusinessEle = this.template.querySelector(
      "c-fec_-case-bussiness"
    );

    if (caseBusinessEle) {
      caseBusinessEle.getData();
    }
  }

  handleNOCMsg(message) {
    const caseBusinessEle = this.template.querySelector(
      "c-fec_-case-bussiness"
    );

    if (caseBusinessEle) {
      caseBusinessEle.getData(
        message.productTypeId,
        message.categoryId,
        message.subCategoryId,
        message.subCodeId
      );
    }
  }

  async handlePublishMode(isEdit) {
    const payload = {
      isModeEdit: isEdit
    };

    publish(this.messageContext, IS_MODE_EDIT, payload);
  }

  handleSave() {
    const caseRemarksEle = this.template.querySelector("c-fec_-case-remarks");
    let isAllValid = true;
    this.errlst = [];

    if (!caseRemarksEle || !caseRemarksEle.validate()) {
      isAllValid = false;
      this.errlst.push(REQUIRED_MSG.replace("{0}", "Case Remarks"));
    }

    if (!isAllValid) return;

    this.isLoaded = false;

    Promise.all([caseRemarksEle.createRemark()])
      .then(([caseRemarkId]) => {})
      .catch((error) => {
        console.log(
          "🚀 ~ Fec_CaseDetail_Customer_Edit ~ handleSave ~ error:",
          error
        );
      })
      .finally(() => {
        this.isLoaded = true;
        this.handlePublishMode(false);
      });
  }

  async handleSubmit() {
    let isAllValid = true;

    const caseRemarksEle = this.template.querySelector("c-fec_-case-remarks");
    const caseBusinessEle = this.template.querySelector(
      "c-fec_-case-bussiness"
    );

    isAllValid = caseBusinessEle && caseBusinessEle.validate();

    if (!isAllValid) return;

    this.isLoaded = false;

    await caseRemarksEle.submitRemark();
    await caseBusinessEle.submit();

    this.isLoaded = true;

    setTimeout(() => {
      this.handlePublishMode(false);
    }, 1000);
  }
}