import { LightningElement, track, api, wire } from "lwc";
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext, publish } from 'lightning/messageService';
import IS_MODE_EDIT from '@salesforce/messageChannel/FEC_Case_Mode__c';
import CASE_NOC from '@salesforce/messageChannel/FEC_Case_NOC__c';
import getCase from "@salesforce/apex/FEC_CaseEditNOCController.getCase";
import getProductTypeIds from "@salesforce/apex/FEC_CaseEditNOCController.getProductTypeIds";
import getCategoryIds from "@salesforce/apex/FEC_CaseEditNOCController.getCategoryIds";
import getSubCategoryIds from "@salesforce/apex/FEC_CaseEditNOCController.getSubCategoryIds";
import getSubCodeIds from "@salesforce/apex/FEC_CaseEditNOCController.getSubCodeIds";
import getNatureOfCase from "@salesforce/apex/FEC_CaseEditNOCController.getNatureOfCase";

export default class Fec_CaseEditNOC extends LightningElement {
  @api recordId;
  @api modeEditCase;

  @wire(MessageContext)
  messageContext;

  @track productTypeFilter = {
    criteria: []
  };
  @track categoryFilter = {
    criteria: []
  };
  @track subCategoryFilter = {
    criteria: []
  };
  @track subCodeFilter = {
    criteria: []
  };

  subscription = null;

  activeSection = ["noc"];
  productTypeSelectedId;
  categorySelectedId;
  subCategorySelectedId;
  subCodeSelectedId;
  natureOfCase;

  get disableCategory() {
    return !this.productTypeSelectedId;
  }
  get disableSubCategory() {
    return !this.categorySelectedId;
  }
  get disableSubCode() {
    return !this.subCategorySelectedId;
  }

  connectedCallback() {
    this.subscribeToMessageChannel();

    getCase({
      recordId: this.recordId
    }).then(res => {
        this.productTypeSelectedId = res.FEC_Product_Type__c;
        this.categorySelectedId = res.FEC_Category__c;
        this.subCategorySelectedId = res.FEC_SubCategory__c;
        this.subCodeSelectedId = res.FEC_SubCode__c;
    }).catch(err => {}).finally(() => {})

    getProductTypeIds({
      recordId: this.recordId
    })
      .then((result) => {
        console.log('>>>>>>result: ', result);
        this.productTypeFilter = {
          criteria: [
            {
              fieldPath: "Id",
              operator: "in",
              value: result
            }
          ]
        };
      })
      .catch((error) => {
        console.log("error", error);
      });

      console.error("🚀 ~ Fec_CaseEditNOC ~ connectedCallback ~ connectedCallback:")
  }

  disconnectedCallback() {
    unsubscribe(this.subscription);
    this.subscription = null;
  }

  subscribeToMessageChannel() {
    this.subscription = subscribe(
      this.messageContext,
      IS_MODE_EDIT,
      (message) => this.handleMessage(message),
      { scope: APPLICATION_SCOPE }
    );
  }

   async handlePublishMessageChanel() {
      const payload = {
        productTypeId: this.productTypeSelectedId, categoryId: this.categorySelectedId, subCategoryId: this.subCategorySelectedId, subCodeId: this.subCodeSelectedId
      };
      
      publish(this.messageContext, CASE_NOC, payload);
    }

  handleMessage(message) {
    this.modeEditCase = message.isModeEdit;
  }

  handleProductTypeSelect(event) {
    this.productTypeSelectedId = event.detail.recordId;
    if (!this.productTypeSelectedId) {
      this.handleClearSelection("category");
      this.handleClearSelection("subCategory");
      this.handleClearSelection("subCode");
      this.categorySelectedId = null;
      this.subCategorySelectedId = null;
      this.subCodeSelectedId = null;
    } else {
      getCategoryIds({
        recordId: this.recordId,
        productTypeId: this.productTypeSelectedId
      })
        .then((result) => {
          this.categoryFilter = {
            criteria: [
              {
                fieldPath: "Id",
                operator: "in",
                value: result
              }
            ]
          };
        })
        .catch((error) => {
          console.log("error", error);
        });
    }
  }

  handleCategorySelect(event) {
    this.categorySelectedId = event.detail.recordId;
    if (!this.categorySelectedId) {
      this.handleClearSelection("subCategory");
      this.handleClearSelection("subCode");
      this.subCategorySelectedId = null;
      this.subCodeSelectedId = null;
    } else {
      getSubCategoryIds({
        recordId: this.recordId,
        productTypeId: this.productTypeSelectedId,
        categoryId: this.categorySelectedId
      })
        .then((result) => {
          this.subCategoryFilter = {
            criteria: [
              {
                fieldPath: "Id",
                operator: "in",
                value: result
              }
            ]
          };
        })
        .catch((error) => {
          console.log("error", error);
        });
    }
  }

  handleSubCategorySelect(event) {
    this.subCategorySelectedId = event.detail.recordId;
    if (!this.subCategorySelectedId) {
      this.handleClearSelection("subCode");
      this.subCodeSelectedId = null;
    } else {
      getSubCodeIds({
        recordId: this.recordId,
        productTypeId: this.productTypeSelectedId,
        categoryId: this.categorySelectedId,
        subCategoryId: this.subCategorySelectedId
      })
        .then((result) => {
          this.subCodeFilter = {
            criteria: [
              {
                fieldPath: "Id",
                operator: "in",
                value: result
              }
            ]
          };
        })
        .catch((error) => {
          console.log("error", error);
        });
    }
  }

  handleSubCodeSelect(event) {
    this.subCodeSelectedId = event.detail.recordId;
    if (this.subCodeSelectedId) {
        getNatureOfCase({
          productTypeId: this.productTypeSelectedId,
          categoryId: this.categorySelectedId,
          subCategoryId: this.subCategorySelectedId,
          subCodeId: this.subCodeSelectedId
        })
        .then((result) => {
          this.natureOfCase = result;
        })
        .catch((error) => {
          console.log("error", error);
        });

        this.handlePublishMessageChanel();
    }
  }

  handleClearSelection(selection) {
    const picker = this.template.querySelector(
      `lightning-record-picker[data-name="${selection}"]`
    );
    picker.clearSelection();
  }

}