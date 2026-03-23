import { LightningElement, api, track, wire } from "lwc";
import { loadStyle } from "lightning/platformResourceLoader";
import COMMON_STYLES from "@salesforce/resourceUrl/FEC_CommonCss";

import logSensitiveAccess from "@salesforce/apex/FEC_InteractionHighlightController.logSensitiveAccess";

import getKYC from "@salesforce/apex/FEC_KYCController.getKYC";
import submitKYC from "@salesforce/apex/FEC_KYCController.submitKYC";
import getKYCResult from "@salesforce/apex/FEC_KYCController.getKYCResult";
import getInterationId from "@salesforce/apex/FEC_KYCController.getInterationId";

import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import VIEW_MODE from "@salesforce/schema/Case.FEC_Interaction_View_Mode__c";

import {
  subscribe,
  unsubscribe,
  publish,
  APPLICATION_SCOPE,
  MessageContext
} from "lightning/messageService";
import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";

import { mask } from "c/fec_CommonUtils";
import { ICON_PREVIEW, ICON_HIDE } from "c/fec_CommonConst";

import FEC_KYC_Answer_Label from "@salesforce/label/c.FEC_KYC_Answer_Label";
import FEC_KYC_Product_Label from "@salesforce/label/c.FEC_KYC_Product_Label";
import FEC_KYC_Question_Label from "@salesforce/label/c.FEC_KYC_Question_Label";
import FEC_KYC_Result_Label from "@salesforce/label/c.FEC_KYC_Result_Label";
import FEC_Performed_On_Label from "@salesforce/label/c.FEC_Performed_On_Label";
import FEC_KYC_Method_Label from "@salesforce/label/c.FEC_KYC_Method_Label";
import FEC_KYC_Details_Label from "@salesforce/label/c.FEC_KYC_Details_Label";
import FEC_Suggested_answer_Label from "@salesforce/label/c.FEC_Suggested_answer_Label";
import FEC_Button_Fail from "@salesforce/label/c.FEC_Button_Fail";
import FEC_Button_Pass from "@salesforce/label/c.FEC_Button_Pass";

export default class Fec_KYC extends LightningElement {
  @api recordId;
  interationId;

  get isDisabled() {
    return (
      !this.isEdit ||
      (this.interationId !== undefined &&
        this.interationId !== null &&
        this.interationId !== this.recordId)
    );
  }

  @track kycData = {
    kycType: "",
    typelst: []
  };

  isLoaded = true;

  @track prodTypeSectionlst = [];
  @track kycSectionlst = ["KYC", "KYCResult"];
  @track kycResultlst = [];

  sectionLoaded = false;

  get hasProd() {
    return this.kycData.typelst?.length > 0;
  }

  isEdit = false;

  @wire(MessageContext)
  messageContext;

  subscription = null;

  customLabel = {
    kycAnswerLabel: FEC_KYC_Answer_Label,
    kycProductLabel: FEC_KYC_Product_Label,
    kycQuestionLabel: FEC_KYC_Question_Label,
    kycResultLabel: FEC_KYC_Result_Label,
    performedOnLabel: FEC_Performed_On_Label,
    kycMethodLabel: FEC_KYC_Method_Label,
    kycDetailsLabel: FEC_KYC_Details_Label,
    suggestedAnswerLabel: FEC_Suggested_answer_Label,
    buttonFail: FEC_Button_Fail,
    buttonPass: FEC_Button_Pass,
  }

  @track kycResultColumn = [
    { label: this.customLabel.kycProductLabel, fieldName: "productType" },
    { label: this.customLabel.kycQuestionLabel, fieldName: "question" },
    { label: this.customLabel.kycAnswerLabel, fieldName: "answer", isMaskable: true },
    { label: this.customLabel.kycResultLabel, fieldName: "result" },
    { label: this.customLabel.performedOnLabel, fieldName: "performedOn" }
  ];

  @wire(getRecord, {
    recordId: "$recordId",
    fields: [VIEW_MODE]
  })
  wiredCase({ data, error }) {
    if (data) {
      this.isEdit = getFieldValue(data, VIEW_MODE) === "handling";

      getInterationId({ recordId: this.recordId })
        .then((res) => {
          console.error(
            "🚀 ~ Fec_KYC ~ wiredCase ~ res:",
            JSON.stringify(res),
            this.recordId
          );
          this.interationId = res;

          this.getData();
        })
        .catch((err) => {
          console.log("🚀 ~ Fec_KYC ~ connectedCallback ~ err:", err);
        })
        .finally(() => { });
    } else if (error) {
      console.error("getRecord error:", error);
    }
  }

  connectedCallback() {
    this.subscribeToMessageChannel();

    loadStyle(this, COMMON_STYLES)
      .then(() => {
        console.log("Common styles loaded successfully");
      })
      .catch((error) => {
        console.error("Error loading common styles", error);
      });
  }

  subscribeToMessageChannel() {
    this.subscription = subscribe(
      this.messageContext,
      IS_MODE_EDIT,
      (message) => this.handleMessage(message),
      { scope: APPLICATION_SCOPE }
    );
  }

  handleMessage(message) {
    this.isEdit = message.isModeEdit;

    this.getData();
  }

  handleOpenAnswer(e) {
    let id = e.target.dataset.id;

    if (id) {
      this.kycData.typelst?.forEach((item) => {
        item.questions.forEach((question) => {
          if (question.id === id) {
            question.isOpenAnswer = !question.isOpenAnswer;
          }
        });
      });
    }
  }

  async handleKYC(e) {
    let id = e.target.dataset.id;
    let answer = e.target.dataset.answer;
    let checked = e.target.dataset.check === "true";

    if (id) {
      this.isLoaded = false;
      submitKYC({
        recordId: this.recordId,
        kycId: id,
        checked,
        answer
      })
        .then((res) => {
          this.kycData.typelst?.forEach((type) => {
            type.questions?.forEach((item) => {
              if (item.id === id) {
                item.stage = checked ? "true" : "false";
                item.isOpenAnswer = false;
              }
            });
          });
        })
        .catch((err) => {
          console.log("🚀 ~ Fec_KYC ~ handleKYC ~ err:", JSON.stringify(err));
        })
        .finally(() => {
          this.isLoaded = true;
        });
    }
  }

  handleChangeMethod() {
    let form = this.template.querySelector("lightning-record-edit-form");

    if (form) {
      form.submit();
    }
  }

  handleSucess() {
    this.getData();
  }

  getData() {
    this.isLoaded = false;

    Promise.all([
      getKYC({ recordId: this.interationId }),
      getKYCResult({ caseId: this.interationId })
    ])
      .then(([res, resultRes]) => {
        if (res) {
          res.typelst?.forEach((typeItem) => {
            this.prodTypeSectionlst.push(typeItem.type);

            typeItem.questions?.forEach((item) => {
              item.isOpenAnswer = false;

              item.isDisabled = !item.isEditable || this.isDisabled;

              if (item.isMasked) {
                item.iconName = ICON_HIDE;
              }

              item.maskedAnswer = item.isMasked
                ? (item.suggestedAnswer ? item.suggestedAnswer.split('\n').map(s => mask(s)).join('\n') : '')
                : item.suggestedAnswer;
            });
          });

          this.kycData = { ...res };
        }

        if (resultRes) {
          this.kycResultlst = [...resultRes];
        }
      })
      .catch((err) => {
        console.error(
          "🚀 ~ Fec_KYC ~ connectedCallback ~ err:",
          JSON.stringify(err)
        );
      })
      .finally(() => {
        this.isLoaded = true;
        this.sectionLoaded = true;
      });
  }

  handleToggleMask(e) {
    let id = e.target.dataset.id;
    let isPreview = e.target.iconName === ICON_PREVIEW;

    this.kycData.typelst?.forEach((typeItem) => {
      this.prodTypeSectionlst.push(typeItem.type);

      typeItem.questions?.forEach((item) => {
        if (item.id === id) {
          if (isPreview) {
            item.maskedAnswer = item.suggestedAnswer ? item.suggestedAnswer.split('\n').map(s => mask(s)).join('\n') : '';
            item.iconName = ICON_HIDE;
          } else {
            item.maskedAnswer = item.suggestedAnswer;
            item.iconName = ICON_PREVIEW;
            logSensitiveAccess({
              itemName: item.fieldName,
              caseId: this.recordId
            });
          }
        }
      });
    });
  }
}