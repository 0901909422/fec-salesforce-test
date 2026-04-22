import { LightningElement, track, api, wire } from "lwc";
import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext,
  publish
} from "lightning/messageService";
import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";
import CASE_NOC from "@salesforce/messageChannel/FEC_Case_NOC__c";
import getCase from "@salesforce/apex/FEC_CaseEditNOCController.getCase";
//HieuTT74 Cập nhật ngày  17-4-2026: Bổ sung message channel để disable các combobox khi call api reset pin thành công
import PIN_RESET_CHANNEL from "@salesforce/messageChannel/FEC_PinReset__c";
//Thangtv update logic for Jira KH-1043: disable các NOC value after call api reissue pin
import PIN_REISSUE_MESSAGE_CHANNEL from "@salesforce/messageChannel/FEC_PinReissue__c";
// import getProductTypeIds from "@salesforce/apex/FEC_CaseEditNOCController.getProductTypeIds";
// import getCategoryIds from "@salesforce/apex/FEC_CaseEditNOCController.getCategoryIds";
// import getSubCategoryIds from "@salesforce/apex/FEC_CaseEditNOCController.getSubCategoryIds";
// import getSubCodeIds from "@salesforce/apex/FEC_CaseEditNOCController.getSubCodeIds";

import getNatureOfCase from "@salesforce/apex/FEC_CaseEditNOCController.getNatureOfCase";

import getProductTypelst from "@salesforce/apex/FEC_CaseEditNOCController.getProductTypelst";
import getCategorylst from "@salesforce/apex/FEC_CaseEditNOCController.getCategorylst";
import getSubCategorylst from "@salesforce/apex/FEC_CaseEditNOCController.getSubCategorylst";
import getSubCodelst from "@salesforce/apex/FEC_CaseEditNOCController.getSubCodelst";
import getByCase from "@salesforce/apex/FEC_CaseBusinessService.getByCase";
import { updateRecord } from "lightning/uiRecordApi";
import FEC_Tab_Nature_Of_Case from "@salesforce/label/c.FEC_Tab_Nature_Of_Case";
import {
  ACTION_REOPEN,
  ACTION_RECALL,
  // RECORD_TYPE_INTERNAL_CASE,
  VIEW_MODE_HANDLING,
  VIEW_MODE_REVIEW,
  // STR_UNDEFINED,
  INTERNAL_REQUEST,
  INTERNAL_UBANK
} from "c/fec_CommonConst";
import ID_FIELD from "@salesforce/schema/Case.Id";
import IS_ROUTING_ACTION_DISPLAY_FIELD from "@salesforce/schema/Case.FEC_Is_Routing_Action_Display__c";
import resetViewMode from "@salesforce/apex/FEC_InteractionInforHandler.resetViewMode";

export default class Fec_CaseEditNOC extends LightningElement {
  @api recordId;
  @api modeEditCase;

  isSubmited = true;
  _isInternalRequest = false;
  _internalProductTypeId = null;
  _internalApplied = false;

  get isEdit() {

    const defaultEdit = (this.modeEditCase || this.interactionViewMode === VIEW_MODE_HANDLING) ? true : false;
    return defaultEdit && !this.isSubmited;
  }

  get natureOfCaseLabel() {
    return FEC_Tab_Nature_Of_Case;
  }

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
  subscriptionNOC = null;
  subscriptionResetPin = null;
  subscriptionPinReissue = null;

  activeSection = ["noc"];
  productTypeSelectedId;
  categorySelectedId;
  subCategorySelectedId;
  subCodeSelectedId;
  natureOfCase;

  disableProdType;
  interactionViewMode;
  recordTypeDevName;

  get disableCategory() {
    return !this.productTypeSelectedId;
  }
  get disableSubCategory() {
    return !this.categorySelectedId;
  }
  get disableSubCode() {
    return !this.subCategorySelectedId;
  }

  @track productTypeOptionlst = [];
  @track categoryOptionlst = [];
  @track subCategoryOptionlst = [];
  @track subCodeOptionlst = [];

  get formattedProductTypeOption() {
    return JSON.stringify(this.productTypeOptionlst);
  }

  get formattedCategoryOption() {
    return JSON.stringify(this.categoryOptionlst);
  }

  get formattedSubCategoryOption() {
    return JSON.stringify(this.subCategoryOptionlst);
  }

  get formattedSubCodeOption() {
    return JSON.stringify(this.subCodeOptionlst);
  }

  renderedCallback() {
    if (this._internalProductTypeId && !this._internalApplied) {
      const el = this.template.querySelector(`c-fec_-combo-box[data-id="prod-type"]`);
      if (el) {
        el.value = this._internalProductTypeId;
        el.disabled = true;
        this._internalApplied = true;
      }
    }
  }

  async connectedCallback() {
    await resetViewMode({
      recordId: this.recordId,
      viewMode: VIEW_MODE_REVIEW,
    });
    this.subscribeToMessageChannel();

    getCase({ recordId: this.recordId })
      .then((res) => {
        this.productTypeSelectedId = res.FEC_Product_Type__c;
        this.disableProdType = !!this.productTypeSelectedId;

        this.categorySelectedId = res.FEC_Category__c;

        this.subCategorySelectedId = res.FEC_SubCategory__c;

        this.subCodeSelectedId = res.FEC_SubCode__c;

        this.isSubmited = res.FEC_Is_Submited__c;
        this.interactionViewMode = res.FEC_Interaction_View_Mode__c;
        this.recordTypeDevName = res.RecordType?.DeveloperName;
        this._isInternalRequest = res.FEC_Account_Contract_Number_PL__c === INTERNAL_REQUEST;
        this.getProdType();
        this.getCategory();
        this.getSubCategory();
        this.getSubCode();

        getByCase({
          caseId: this.recordId,
          productTypeId: this.productTypeSelectedId,
          categoryId: this.categorySelectedId,
          subCategoryId: this.subCategorySelectedId,
          subCodeId: this.subCodeSelectedId,
        })
          .then((res) => {
            if (!res) return;

            let business = { ...res };
            const actions = business.routingActionlst || [];
            const foundActions = [];

            if (actions.some((a) => a.value === ACTION_REOPEN))
              foundActions.push(ACTION_REOPEN);
            if (actions.some((a) => a.value === ACTION_RECALL))
              foundActions.push(ACTION_RECALL);

            this.updateRoutingActionDisplay(
              foundActions.length > 0 ? foundActions.join(";") : ""
            );
          });
      })
      .catch((err) => {
        console.log("🚀 ~ Fec_CaseEditNOC ~ connectedCallback ~ err:", err);
      });
  }

  updateRoutingActionDisplay(field) {
    let fields = {};
    fields[ID_FIELD.fieldApiName] = this.recordId;
    fields[IS_ROUTING_ACTION_DISPLAY_FIELD.fieldApiName] = field;
    let recordInput = { fields };

    updateRecord(recordInput)
      .then(() => {
        console.log("Record updated successfully");
      })
      .catch((error) => {
        console.error("Error updating record:", error);
      });
  }

  disconnectedCallback() {
    unsubscribe(this.subscription);
    this.subscription = null;

    unsubscribe(this.subscriptionNOC);
    this.subscriptionNOC = null;

    //HieuTT74 Cập nhật ngày  17-4-2026: Bổ sung message channel để disable các combobox khi call api reset pin thành công
    unsubscribe(this.subscriptionResetPin);
    this.subscriptionResetPin = null;

    this.modeEditCase = false;
  }

  subscribeToMessageChannel() {
    this.subscription = subscribe(
      this.messageContext,
      IS_MODE_EDIT,
      (message) => this.handleMessage(message),
      { scope: APPLICATION_SCOPE }
    );

    this.subscriptionNOC = subscribe(
      this.messageContext,
      CASE_NOC,
      (message) => this.handleCaseNOCMessage(message),
      { scope: APPLICATION_SCOPE }
    );

    //HieuTT74 Cập nhật ngày  17-4-2026: Bổ sung message channel để disable các combobox khi call api reset pin thành công
    this.subscriptionResetPin = subscribe(
      this.messageContext,
      PIN_RESET_CHANNEL,
      (message) => this.handleMessageResetPin(message),
      { scope: APPLICATION_SCOPE },
    );
    //Thangtv update logic for Jira KH-1043: disable các NOC value after call api reissue pin
    this.subscriptionPinReissue = subscribe(
      this.messageContext,
      PIN_REISSUE_MESSAGE_CHANNEL,
      (message) => this.handleMessageResetPin(message),
      { scope: APPLICATION_SCOPE },
    );
  }

  handleCaseNOCMessage(message) {
    if (!Object.prototype.hasOwnProperty.call(message, 'accountType')) return;

    const accountType = message.accountType;
    const isInternalType = accountType === INTERNAL_REQUEST || accountType === INTERNAL_UBANK;
    const hasExistingNOCSelection =
      !!this.productTypeSelectedId ||
      !!this.categorySelectedId ||
      !!this.subCategorySelectedId ||
      !!this.subCodeSelectedId;

    if (this._incomingAccountType == null && hasExistingNOCSelection && !isInternalType) {
      this._incomingAccountType = accountType;
      return;
    }

    if (this._incomingAccountType === accountType) {
      return;
    }

    this._incomingAccountType = accountType;
    this._isInternalRequest = false;
    this.disableProdType = false;
    this._internalProductTypeId = null;
    this._internalApplied = false;

    this.productTypeSelectedId = null;
    this.categorySelectedId = null;
    this.subCategorySelectedId = null;
    this.subCodeSelectedId = null;

    this.categoryOptionlst = [];
    this.subCategoryOptionlst = [];
    this.subCodeOptionlst = [];

    this.natureOfCase = null;

    ['prod-type', 'category', 'sub-category', 'sub-code'].forEach(id => {
      const el = this.template.querySelector(`c-fec_-combo-box[data-id="${id}"]`);
      if (el) el.clear();
    });

    if (isInternalType) {
      this._isInternalRequest = accountType === INTERNAL_REQUEST;

      const option = this.productTypeOptionlst?.find(
        (opt) => opt.label === accountType
      );

      if (option) {
        setTimeout(() => {
          this.productTypeSelectedId = option.value;
          this.disableProdType = true;
          this._internalProductTypeId = option.value;
          this._internalApplied = false;

          const categoryEl = this.template.querySelector(`c-fec_-combo-box[data-id="category"]`);
          if (categoryEl) categoryEl.disabled = false;

          this.getCategory();
        }, 50);
      }
    } else {
      this.handleDisable('category');
      this.handleDisable('sub-category');
      this.handleDisable('sub-code');
    }
  }

  //HieuTT74 Cập nhật ngày  17-4-2026: Bổ sung message channel để disable các combobox khi call api reset pin thành công
  handleMessageResetPin(message) {
    if (message.status === "SUCCESS") {
      this.handleDisableResetPinSuccess("category");
      this.handleDisableResetPinSuccess("sub-category");
      this.handleDisableResetPinSuccess("sub-code");
    }
  }

  async handlePublishMessageChanel() {
    const payload = {
      productTypeId: this.productTypeSelectedId,
      categoryId: this.categorySelectedId,
      subCategoryId: this.subCategorySelectedId,
      subCodeId: this.subCodeSelectedId,
      natureOfCaseId: this.natureOfCase?.Id
    };

    publish(this.messageContext, CASE_NOC, payload);
  }

  handleMessage(message) {
    if (!message || typeof message.isModeEdit === "undefined") return;
    const nextModeEdit = message.isModeEdit === true;
    const prevModeEdit = this.modeEditCase === true;
    this.modeEditCase = nextModeEdit;
    if (prevModeEdit !== nextModeEdit && !nextModeEdit) {
      this.reloadData();
    }
  }

  reloadData() {
    this._internalApplied = false;
    this._internalProductTypeId = null;

    getCase({ recordId: this.recordId })
      .then((res) => {
        this.productTypeSelectedId = res.FEC_Product_Type__c;
        this.categorySelectedId = res.FEC_Category__c;
        this.subCategorySelectedId = res.FEC_SubCategory__c;
        this.subCodeSelectedId = res.FEC_SubCode__c;

        this.isSubmited = res.FEC_Is_Submited__c;
        this.interactionViewMode = res.FEC_Interaction_View_Mode__c;
        this.recordTypeDevName = res.RecordType?.DeveloperName;
        this._isInternalRequest = res.FEC_Account_Contract_Number_PL__c === INTERNAL_REQUEST;
        this.getProdType();
        this.getCategory();
        this.getSubCategory();
        this.getSubCode();
      })
      .catch((err) => {
        console.log("reloadData err:", err);
      });
  }

  // handleProductTypeSelect(event) {
  //   this.productTypeSelectedId = event.detail.recordId;
  //   if (!this.productTypeSelectedId) {
  //     this.handleClearSelection("category");
  //     this.handleClearSelection("subCategory");
  //     this.handleClearSelection("subCode");
  //     this.categorySelectedId = null;
  //     this.subCategorySelectedId = null;
  //     this.subCodeSelectedId = null;
  //   } else {
  //     getCategoryIds({
  //       recordId: this.recordId,
  //       productTypeId: this.productTypeSelectedId
  //     })
  //       .then((result) => {
  //         this.categoryFilter = {
  //           criteria: [
  //             {
  //               fieldPath: "Id",
  //               operator: "in",
  //               value: result
  //             }
  //           ]
  //         };
  //       })
  //       .catch((error) => {
  //         console.log("error", error);
  //       });
  //   }
  // }

  // handleCategorySelect(event) {
  //   this.categorySelectedId = event.detail.recordId;
  //   if (!this.categorySelectedId) {
  //     this.handleClearSelection("subCategory");
  //     this.handleClearSelection("subCode");
  //     this.subCategorySelectedId = null;
  //     this.subCodeSelectedId = null;
  //   } else {
  //     getSubCategoryIds({
  //       recordId: this.recordId,
  //       productTypeId: this.productTypeSelectedId,
  //       categoryId: this.categorySelectedId
  //     })
  //       .then((result) => {
  //         this.subCategoryFilter = {
  //           criteria: [
  //             {
  //               fieldPath: "Id",
  //               operator: "in",
  //               value: result
  //             }
  //           ]
  //         };
  //       })
  //       .catch((error) => {
  //         console.log("error", error);
  //       });
  //   }
  // }

  // handleSubCategorySelect(event) {
  //   this.subCategorySelectedId = event.detail.recordId;
  //   if (!this.subCategorySelectedId) {
  //     this.handleClearSelection("subCode");
  //     this.subCodeSelectedId = null;
  //   } else {
  //     getSubCodeIds({
  //       recordId: this.recordId,
  //       productTypeId: this.productTypeSelectedId,
  //       categoryId: this.categorySelectedId,
  //       subCategoryId: this.subCategorySelectedId
  //     })
  //       .then((result) => {
  //         this.subCodeFilter = {
  //           criteria: [
  //             {
  //               fieldPath: "Id",
  //               operator: "in",
  //               value: result
  //             }
  //           ]
  //         };
  //       })
  //       .catch((error) => {
  //         console.log("error", error);
  //       });
  //   }

  //   this.handlePublishMessageChanel();
  // }

  // handleSubCodeSelect(event) {
  //   this.subCodeSelectedId = event.detail.recordId;
  //   if (this.subCodeSelectedId) {
  //     getNatureOfCase({
  //       productTypeId: this.productTypeSelectedId,
  //       categoryId: this.categorySelectedId,
  //       subCategoryId: this.subCategorySelectedId,
  //       subCodeId: this.subCodeSelectedId
  //     })
  //       .then((result) => {
  //         this.natureOfCase = result;
  //       })
  //       .catch((error) => {
  //         console.log("error", error);
  //       });

  //     this.handlePublishMessageChanel();
  //   }
  // }

  // handleClearSelection(selection) {
  //   const picker = this.template.querySelector(
  //     `lightning-record-picker[data-name="${selection}"]`
  //   );
  //   picker.clearSelection();
  // }

  getProdType() {
    getProductTypelst({ recordId: this.recordId }).then((res) => {
      console.log(
        "🚀 ~ Fec_CaseEditNOC ~ getProdType ~ res:",
        JSON.stringify(res)
      );
      this.productTypeOptionlst = res;
      if (this._isInternalRequest && !this.productTypeSelectedId) {
        const internalOption = res?.find((opt) => opt.label === INTERNAL_REQUEST);

        if (internalOption) {
          this.productTypeSelectedId = internalOption.value;
          this.disableProdType = true;
          this._internalProductTypeId = internalOption.value;
          this._internalApplied = false;
          this.getCategory();
          this.getSubCategory();
          this.getSubCode();
        }
      }
    });
  }

  getCategory() {
    getCategorylst({
      recordId: this.recordId,
      productTypeId: this.productTypeSelectedId
    })
      .then((res) => {
        console.log(
          "🚀 ~ Fec_CaseEditNOC ~ getCategory ~ res:",
          JSON.stringify(res)
        );
        this.categoryOptionlst = res;

        this.handleChangeOption("category", this.categoryOptionlst);
      })
      .catch((err) => {
        console.log("🚀 ~ Fec_CaseEditNOC ~ getCategory ~ err:", err);
      });
  }

  getSubCategory() {
    getSubCategorylst({
      recordId: this.recordId,
      productTypeId: this.productTypeSelectedId,
      categoryId: this.categorySelectedId
    })
      .then((res) => {
        console.log(
          "🚀 ~ Fec_CaseEditNOC ~ getSubCategory ~ res:",
          JSON.stringify(res)
        );
        this.subCategoryOptionlst = res;

        this.handleChangeOption("sub-category", this.subCategoryOptionlst);
      })
      .catch((err) => {
        console.log("🚀 ~ Fec_CaseEditNOC ~ getSubCategory ~ err:", err);
      });
  }

  getSubCode() {
    getSubCodelst({
      recordId: this.recordId,
      productTypeId: this.productTypeSelectedId,
      categoryId: this.categorySelectedId,
      subCategoryId: this.subCategorySelectedId
    })
      .then((res) => {
        console.log(
          "🚀 ~ Fec_CaseEditNOC ~ getSubCode ~ res:",
          JSON.stringify(res)
        );

        this.subCodeOptionlst = res;

        this.handleChangeOption("sub-code", this.subCodeOptionlst);
      })
      .catch((err) => {
        console.log("🚀 ~ Fec_CaseEditNOC ~ getSubCode ~ err:", err);
      });
  }

  handleRemoveProdType() {
    let element = this.template.querySelector(
      `c-fec_-combo-box[data-id="prod-type"]`
    );

    if (element) {
      element.searchKey = undefined;
    }

    this.handleDisable("category");
    this.handleDisable("sub-category");
    this.handleDisable("sub-code");
  }

  handleRemoveCategory() {
    this.handleDisable("sub-category");
    this.handleDisable("sub-code");
  }

  handleRemoveSubCategory() {
    this.handleDisable("sub-code");
  }

  handleRemoveSubCode() {
    let element = this.template.querySelector(
      `c-fec_-combo-box[data-id="sub-code"]`
    );

    if (element) {
      element.value = undefined;
      element.disabled = false;
    }
  }

  handleChangeProdType(e) {
    this.productTypeSelectedId = e.detail.value;
    this.handleEnable("category");
  }

  handleChangeCategory(e) {
    this.categorySelectedId = e.detail.value;
    this.handleEnable("sub-category");
  }

  handleChangeSubCategory(e) {
    this.subCategorySelectedId = e.detail.value;

    this.handleEnable("sub-code");

    if (this.subCategorySelectedId) this.handlePublishMessageChanel();
  }

  handleChangeSubCode(e) {
    this.subCodeSelectedId = e.detail.value;

    let element = this.template.querySelector(
      `c-fec_-combo-box[data-id="sub-code"]`
    );

    if (element) {
      element.value = this.subCodeSelectedId;
    }

    if (this.subCodeSelectedId) {
      getNatureOfCase({
        productTypeId: this.productTypeSelectedId,
        categoryId: this.categorySelectedId,
        subCategoryId: this.subCategorySelectedId,
        subCodeId: this.subCodeSelectedId
      })
        .then((result) => {
          this.natureOfCase = result;
          this.handlePublishMessageChanel();
        })
        .catch((error) => {
          console.log("error", error);
        });
    }
  }

  handleDisable(id) {
    let element = this.template.querySelector(
      `c-fec_-combo-box[data-id="${id}"]`
    );

    if (element) {
      element.value = undefined;
      element.disabled = true;
      element.searchKey = undefined;
    }
  }

  //HieuTT74 Cập nhật ngày  17-4-2026: Bổ sung message channel để disable các combobox khi call api reset pin thành công
  handleDisableResetPinSuccess(id) {
    let element = this.template.querySelector(
      `c-fec_-combo-box[data-id="${id}"]`,
    );

    if (element) {
      element.disabled = true;
    }
  }

  handleEnable(id) {
    let element = this.template.querySelector(
      `c-fec_-combo-box[data-id="${id}"]`
    );

    if (element) {
      element.disabled = false;

      switch (id) {
        case "category":
          this.getCategory();
          break;
        case "sub-category":
          this.getSubCategory();
          break;
        case "sub-code":
          this.getSubCode();
          break;
        default:
          break;
      }
    }
  }

  handleChangeOption(id, optionlst) {
    let element = this.template.querySelector(
      `c-fec_-combo-box[data-id="${id}"]`
    );

    if (element) {
      element.option = JSON.stringify(optionlst);
    }
  }
}