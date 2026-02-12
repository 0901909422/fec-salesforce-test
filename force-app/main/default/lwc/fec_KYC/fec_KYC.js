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

  @track kycResultColumn = [
    { label: "KYC Product", fieldName: "productType" },
    { label: "KYC Question", fieldName: "question" },
    { label: "KYC Answer", fieldName: "answer" },
    { label: "KYC Result", fieldName: "result" },
    { label: "Performed On", fieldName: "performedOn" }
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
        .finally(() => {});
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
    let resultId = e.target.dataset.result;
    let checked = e.target.dataset.check === "true";

    if (id) {
      this.isLoaded = false;
      submitKYC({
        recordId: this.recordId,
        resultId,
        kycId: id,
        checked
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
                item.iconName = "utility:hide";
              }

              item.maskedAnswer = item.isMasked
                ? mask(item.suggestedAnswer)
                : item.suggestedAnswer;
            });
          });

          this.kycData = { ...res };

          console.error("this.kycData", JSON.stringify(this.kycData));
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
    let isPreview = e.target.iconName === "utility:preview";

    this.kycData.typelst?.forEach((typeItem) => {
      this.prodTypeSectionlst.push(typeItem.type);

      typeItem.questions?.forEach((item) => {
        if (item.id === id) {
          if (isPreview) {
            item.maskedAnswer = mask(item.suggestedAnswer);
            item.iconName = "utility:hide";
          } else {
            item.maskedAnswer = item.suggestedAnswer;
            item.iconName = "utility:preview";
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