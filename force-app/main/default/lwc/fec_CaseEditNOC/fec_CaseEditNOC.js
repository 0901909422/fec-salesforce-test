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
//PhongBT: Original Information của NOC lấy từ FEC_Case_Flow_History__c
import getOriginalNOCFromFlowHistory from "@salesforce/apex/FEC_CaseEditNOCController.getOriginalNOCFromFlowHistory";
//HieuTT74 Cập nhật ngày  17-4-2026: Bổ sung message channel để disable các combobox khi call api reset pin thành công
import PIN_RESET_CHANNEL from "@salesforce/messageChannel/FEC_PinReset__c";
//Thangtv update logic for Jira KH-1043: disable các NOC value after call api reissue pin
import PIN_REISSUE_MESSAGE_CHANNEL from "@salesforce/messageChannel/FEC_PinReissue__c";
// PhuongNT disable NOC after process action call api success
import PROCESS_ACTION_MESSAGE_CHANNEL from "@salesforce/messageChannel/FEC_ProcessAction__c";
// import getProductTypeIds from "@salesforce/apex/FEC_CaseEditNOCController.getProductTypeIds";
// import getCategoryIds from "@salesforce/apex/FEC_CaseEditNOCController.getCategoryIds";
// import getSubCategoryIds from "@salesforce/apex/FEC_CaseEditNOCController.getSubCategoryIds";
// import getSubCodeIds from "@salesforce/apex/FEC_CaseEditNOCController.getSubCodeIds";

import getNatureOfCase from "@salesforce/apex/FEC_CaseEditNOCController.getNatureOfCase";
import getNatureOfCaseWithoutSubCode from "@salesforce/apex/FEC_CaseEditNOCController.getNatureOfCaseWithoutSubCode";
//PhongBT11 update jira KH-1084 bổ sung Updated Information cho NOC, GSR Handling Stage
import hasAutoRoutingAssignment from "@salesforce/apex/FEC_CaseEditNOCController.hasAutoRoutingAssignment";

import getProductTypelst from "@salesforce/apex/FEC_CaseEditNOCController.getProductTypelst";
import getCategorylst from "@salesforce/apex/FEC_CaseEditNOCController.getCategorylst";
import getSubCategorylst from "@salesforce/apex/FEC_CaseEditNOCController.getSubCategorylst";
import getSubCodelst from "@salesforce/apex/FEC_CaseEditNOCController.getSubCodelst";
//HieuTT74-[UPDATE - 5/5/2026]: Lưu NOC sau khi call api Reset Pin,...
import saveNOC from "@salesforce/apex/FEC_CaseEditNOCController.saveNOC";
import getByCase from "@salesforce/apex/FEC_CaseBusinessService.getByCase";
import { updateRecord } from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
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

  @track isSubmited = true;
  _isInternalRequest = false;
  _internalProductTypeId = null;
  _internalApplied = false;
  
  //HieuTT74-[UPDATE - 5/5/2026]: Lưu NOC sau khi call api Reset Pin,...
  isDisableNOC = false;

//PhongBT: update bộ noc chọn ở updated khi revert về
  _currentStageName = null;

//PhongBT11 update jira KH-1084 bổ sung Updated Information cho NOC, GSR Handling Stage
  updatedCategoryId;       // Category đã chọn trong Updated section
  updatedSubCategoryId;    // Sub-Category đã chọn trong Updated section
  updatedSubCodeId;        // Sub-Code đã chọn trong Updated section
  hasAutoRoutingAssignment = false; // true → ẩn Updated section (có Routing Assignment)
  //PhongBT: Original Information của NOC lấy từ FEC_Case_Flow_History__c
  @track originalNOC = null;
  originalNOCBusinessProcessCode;

  //PhongBT: Original Information của NOC lấy từ FEC_Case_Flow_History__c
  get originalNOCFields() {
    if (!this.originalNOC) return [];
    return [
      { key: 'productType',  label: 'Product Type',  value: this.originalNOC.productType  || '-' },
      { key: 'category',     label: 'Category',      value: this.originalNOC.category     || '-' },
      { key: 'subCategory',  label: 'Sub-Category',  value: this.originalNOC.subCategory  || '-' },
      { key: 'subCode',      label: 'Sub-Code',      value: this.originalNOC.subCode      || '-' }
    ];
  }

  get isSubmittedState() {
    console.log('issubmited ' + this.isSubmited);
    console.log('showUpdatedSection ' + this.showUpdatedSection);
    return this.isSubmited === true && this.showUpdatedSection;
  }

  //PhongBT: update bộ noc chọn ở updated khi revert về
  get _isStage1() {
    return (this._currentStageName || '').includes('Stage 1');
  }

  // Sau submit (Submitted + Updated section): chỉ cho sửa khi user bật lại mode edit Case.
  // Không dùng interactionViewMode === handling — sau submit field Case có thể chưa kịp review
  // nên vẫn là handling và Updated NOC bị editable tới khi reload; chỉ còn modeEditCase là đúng UX.
  get isUpdatedSectionEditable() {
    if (!this.isSubmittedState) {
      return false;
    }
    //PhongBT: update bộ noc chọn ở updated khi revert về
    // Stage 1 → readonly Updated NOC
    if (this._isStage1) return false;
    return this.modeEditCase === true;
  }

  get showUpdatedSection() {
    const bpCode = (this.originalNOCBusinessProcessCode || "").toUpperCase();
    const isGsrOrCof = bpCode.includes("GSR") || bpCode.includes("COF");
    console.log('bpCode ' + bpCode);
    console.log('isGsrOrCof ' + isGsrOrCof);
    console.log('hasAutoRoutingAssignment ' + this.hasAutoRoutingAssignment);
    return this.isSubmited === true 
    // && !this.hasAutoRoutingAssignment 
    && isGsrOrCof;
  }

  get serializedProductTypeOptions() {
    return JSON.stringify(this.productTypeOptionlst ?? []);
  }

  get serializedCategoryOptions() {
    return JSON.stringify(this.categoryOptionlst ?? []);
  }

  get serializedSubCategoryOptions() {
    return JSON.stringify(this.subCategoryOptionlst ?? []);
  }

  get serializedSubCodeOptions() {
    return JSON.stringify(this.subCodeOptionlst ?? []);
  }

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
  @track interactionViewMode;
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
        this.isDisableNOC = res.FEC_Is_Call_API_Success__c;
//PhongBT: update bộ noc chọn ở updated khi revert về
        this._currentStageName = res.FEC_Current_Case_Stage__r?.Name || null;
        this.getProdType();
        this.getCategory();
        this.getSubCategory();
        this.getSubCode();

         // 👉 FIX: đặt ở đây
        if (this.isDisableNOC) {
          this.handleDisableResetPinSuccess("category");
          this.handleDisableResetPinSuccess("sub-category");
          this.handleDisableResetPinSuccess("sub-code");
        }

//PhongBT11 update jira KH-1084 bổ sung Updated Information cho NOC, GSR Handling Stage
        // [NOC-HANDLING-STAGE-UPDATE]: Khi đã submit, kiểm tra Auto-Routing Assignment
        // và pre-populate Updated section với giá trị hiện tại của Case
        if (res.FEC_Is_Submited__c) {
          // Pre-populate Updated section với giá trị NOC hiện tại
          this.updatedCategoryId = res.FEC_Category__c;
          this.updatedSubCategoryId = res.FEC_SubCategory__c;
          this.updatedSubCodeId = res.FEC_SubCode__c;

          // Kiểm tra có Routing Assignment không — nếu có thì ẩn Updated section
          hasAutoRoutingAssignment({ caseId: this.recordId })
            .then((result) => {
              this.hasAutoRoutingAssignment = result === true;
            })
            .catch((err) => {
              // Default false để không ẩn Updated section một cách sai lầm
              console.error("hasAutoRoutingAssignment error:", err);
              this.hasAutoRoutingAssignment = false;
            });

          //PhongBT: Original Information của NOC lấy từ FEC_Case_Flow_History__c
          getOriginalNOCFromFlowHistory({ caseId: this.recordId })
            .then((nocData) => {
              this.originalNOC = nocData || null;
              this.originalNOCBusinessProcessCode = nocData?.businessProcessCode || null;
            })
            .catch((err) => {
              console.error("getOriginalNOCFromFlowHistory error:", err);
              this.originalNOC = null;
              this.originalNOCBusinessProcessCode = null;
            });
        }

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
    // PhuongNT disable NOC after process action call api success
    this.subscriptionPinReissue = subscribe(
      this.messageContext,
      PROCESS_ACTION_MESSAGE_CHANNEL,
      (message) => this.handleMessageResetPin(message),
      { scope: APPLICATION_SCOPE },
    );
  }

  handleCaseNOCMessage(message) {
    if (!Object.prototype.hasOwnProperty.call(message, 'accountType')) return;
    if (message.caseId != null && message.caseId !== this.recordId) {
      return;
    }

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
    this.handleDisableResetPinSuccess("category");
    this.handleDisableResetPinSuccess("sub-category");
    this.handleDisableResetPinSuccess("sub-code");

    saveNOC({
        recordId: this.recordId,
        productTypeId: this.productTypeSelectedId,
        categoryId: this.categorySelectedId,
        subCategoryId: this.subCategorySelectedId,
        subCodeId: this.subCodeSelectedId
    })
    .then(() => {
        console.log('Save NOC success');
    })
    .catch(error => {
        console.error('Save NOC failed:', error);
    });
  }

  async handlePublishMessageChanel() {
    const payload = {
      caseId: this.recordId,
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

    // 🚫 API success rồi thì không cho edit nữa
    if (this.isDisableNOC) {
      return;
    }

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
//PhongBT: update bộ noc chọn ở updated khi revert về
        this._currentStageName = res.FEC_Current_Case_Stage__r?.Name || null;
        this.getProdType();
        this.getCategory();
        this.getSubCategory();
        this.getSubCode();
//PhongBT11 update jira KH-1084 bổ sung Updated Information cho NOC, GSR Handling Stage
        // [NOC-HANDLING-STAGE-UPDATE]: Re-populate Updated section sau khi reload
        if (res.FEC_Is_Submited__c) {
          this.updatedCategoryId = res.FEC_Category__c;
          this.updatedSubCategoryId = res.FEC_SubCategory__c;
          this.updatedSubCodeId = res.FEC_SubCode__c;

          hasAutoRoutingAssignment({ caseId: this.recordId })
            .then((result) => {
              this.hasAutoRoutingAssignment = result === true;
            })
            .catch((err) => {
              console.error("hasAutoRoutingAssignment error (reloadData):", err);
              this.hasAutoRoutingAssignment = false;
            });

          //PhongBT: Original Information của NOC lấy từ FEC_Case_Flow_History__c
          getOriginalNOCFromFlowHistory({ caseId: this.recordId })
            .then((nocData) => {
              this.originalNOC = nocData || null;
              this.originalNOCBusinessProcessCode = nocData?.businessProcessCode || null;
            })
            .catch((err) => {
              console.error("getOriginalNOCFromFlowHistory error (reloadData):", err);
              this.originalNOC = null;
              this.originalNOCBusinessProcessCode = null;
            });
        }
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
        // Không có option Sub-Code: resolve NOC không Sub-Code; getByCase (Apex) không fallback Sub-Code từ Case khi đã có Sub-Category từ UI.
        const triple =
          this.productTypeSelectedId &&
          this.categorySelectedId &&
          this.subCategorySelectedId;
        const noSubCodeOptions = !res || res.length === 0;

        if (triple && noSubCodeOptions) {
          this.subCodeSelectedId = null;
          this.syncSubCodeComboValue();
          return getNatureOfCaseWithoutSubCode({
            productTypeId: this.productTypeSelectedId,
            categoryId: this.categorySelectedId,
            subCategoryId: this.subCategorySelectedId
          })
            .then((noc) => {
              this.natureOfCase = noc;
              this.handlePublishMessageChanel();
            })
            .catch((e) => {
              console.log("getNatureOfCaseWithoutSubCode err:", e);
              this.natureOfCase = null;
              this.handlePublishMessageChanel();
            });
        }
      })
      .catch((err) => {
        console.log("🚀 ~ Fec_CaseEditNOC ~ getSubCode ~ err:", err);
      });
  }

    syncSubCodeComboValue() {
    const el = this.template.querySelector(`c-fec_-combo-box[data-id="sub-code"]`);
    if (el) {
      el.value = undefined;
    }
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
    this.subCodeSelectedId = null;
    this.natureOfCase = null;

    this.handleEnable("sub-code");
    this.handlePublishMessageChanel();
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
    } else {
      this.natureOfCase = null;
      this.handlePublishMessageChanel();
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
//PhongBT11 update jira KH-1084 bổ sung Updated Information cho NOC, GSR Handling Stage
  // ─────────────────────────────────────────────────────────────────────────
  // [NOC-HANDLING-STAGE-UPDATE]: Event handlers từ child component
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Handler khi Category thay đổi trong Updated section (từ child component).
   * Reset Sub-Category và Sub-Code, reload Sub-Category options.
   */
  handleUpdatedCategoryChange(e) {
    this.updatedCategoryId = e.detail.categoryId;
    this.updatedSubCategoryId = null;
    this.updatedSubCodeId = null;

    // Reload Sub-Category options theo Category mới
    if (this.updatedCategoryId) {
      getSubCategorylst({
        recordId: this.recordId,
        productTypeId: this.productTypeSelectedId,
        categoryId: this.updatedCategoryId
      })
        .then((res) => {
          this.subCategoryOptionlst = res;
        })
        .catch((err) => {
          console.error("getSubCategorylst error (Updated section):", err);
        });
    }
  }

  /**
   * Handler khi Sub-Category thay đổi trong Updated section (từ child component).
   * Reset Sub-Code, reload Sub-Code options.
   */
  handleUpdatedSubCategoryChange(e) {
    this.updatedSubCategoryId = e.detail.subCategoryId;
    this.updatedSubCodeId = null;

    // Reload Sub-Code options theo Sub-Category mới
    if (this.updatedSubCategoryId) {
      getSubCodelst({
        recordId: this.recordId,
        productTypeId: this.productTypeSelectedId,
        categoryId: this.updatedCategoryId,
        subCategoryId: this.updatedSubCategoryId
      })
        .then((res) => {
          this.subCodeOptionlst = res;
        })
        .catch((err) => {
          console.error("getSubCodelst error (Updated section):", err);
        });
    }
  }

  /**
   * Handler khi Sub-Code thay đổi trong Updated section (từ child component).
   * Child đã gọi getNatureOfCase và trả về natureOfCaseId trong event.detail.
   * Publish full payload lên CASE_NOC_Channel để trigger fec_CaseBussiness reload.
   */
  handleUpdatedSubCodeChange(e) {
    this.updatedSubCodeId = e.detail.subCodeId;
    const natureOfCaseId = e.detail.natureOfCaseId;

    // Publish lên CASE_NOC_Channel với bộ NOC mới (Updated NOC)
    const payload = {
      caseId: this.recordId,
      productTypeId: this.productTypeSelectedId,
      categoryId: this.updatedCategoryId,
      subCategoryId: this.updatedSubCategoryId,
      subCodeId: this.updatedSubCodeId,
      natureOfCaseId: natureOfCaseId
    };

    publish(this.messageContext, CASE_NOC, payload);
  }
}