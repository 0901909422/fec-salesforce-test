import { LightningElement, api, track } from "lwc";
import getByCase from "@salesforce/apex/FEC_CaseBusinessService.getByCase";
import run from "@salesforce/apex/FEC_CaseBusinessService.run";
import logSensitiveAccess from "@salesforce/apex/FEC_InteractionHighlightController.logSensitiveAccess";

import { mask } from "c/fec_CommonUtils";

import FEC_Reason_Label from "@salesforce/label/c.FEC_Reason_Label";
import FEC_Routing_Action_Label from "@salesforce/label/c.FEC_Routing_Action_Label";
import FEC_Action_Label from "@salesforce/label/c.FEC_Action_Label";
import FEC_Team_Label from "@salesforce/label/c.FEC_Team_Label";
import FEC_Queue_Label from "@salesforce/label/c.FEC_Queue_Label";
import FEC_Decision_Label from "@salesforce/label/c.FEC_Decision_Label";

const ACTION_PHONE_UPDATE = "Phone Update";
const ACTION_EMAIL_UPDATE = "Email Update";
const ACTION_FULLNAME_UPDATE = "Full Name Update";
const ACTION_DOB_UPDATE = "Date of Birth Update";
const ACTION_GENDER_UPDATE = "Gender Update";
const OC_001 = "Outbound Campaign - OU01";

const ACTION_ROUTE_TO = "Route to";
const ACTION_REVERT = "Revert";
const ACTION_REJECT = "Reject";
const ACTION_RESOLVE = "Resolve";

const CASE_UPDATED_INFO_PHONE_NUMBER = "Case.FEC_Updated_Info_Phone_Number__c";
const CASE_CS_D2C_ASSIGNMENT_TYPE = "Case.FEC_CS_D2C_Assessment_Type__c";
const CASE_CS_D2C_REQUIRED_CORRECTIVE_ACTION =
  "Case.FEC_CS_D2C_Required_Corrective_Action__c";
const CASE_CS_D2C_RISK_LEVEL = "Case.FEC_CS_D2C_Risk_Level__c";
const CASE_CS_SUPPORT_ASSESMENT_TYPE = "Case.FEC_CS_Support_Assessment_Type__c";
const CASE_CONFIRM_D2C_ASSESMENT = "Case.FEC_Confirm_D2C_Assessment__c";
const CASE_ACTIONS_TAKEN_D2C_ASSESMENT =
  "Case.FEC_Actions_Taken_D2C_Assessment__c";
const CASE_CONFIRM_CS_SP_ASSESMENT = "Case.FEC_Confirm_CS_SP_Assessment__c";

const CS_D2C_REQUIRED_CORRECTIVE_ACTION =
  "FEC_CS_D2C_Required_Corrective_Action__c";
const CS_D2C_RISK_LEVEL = "FEC_CS_D2C_Risk_Level__c";
const CS_SUPPORT_ASSESMENT_TYPE = "FEC_CS_Support_Assessment_Type__c";
const CONFIRM_D2C_ASSESMENT = "FEC_Confirm_D2C_Assessment__c";
const ACTIONS_TAKEN_D2C_ASSESMENT = "FEC_Actions_Taken_D2C_Assessment__c";
const CONFIRM_CS_SP_ASSESMENT = "Case.FEC_Confirm_CS_SP_Assessment__c";

const ACTION_PHONE_UPDATE_HEADER = "Update Customer Info";
const ACTION_PHONE_UPDATE_MSG =
  "Bạn sắp cập nhật thông tin cho khách hàng này. Bạn có chắc chắn muốn tiếp tục?";

const ACTION_PHONE_UPDATE_SUCCESS_MSG =
  "Cập nhật thông tin khác hàng thành công";

const ACTION_PHONE_UPDATE_ERROR_MSG =
  "Cập nhật thông tin khác hàng thất bại. Vui lòng thử lại";

const TYPE_QUALIFIED = "Qualified";
const TYPE_UNQUALIFIED = "Unqualified";
const TYPE_AGREE = "Agree";
const TYPE_DISAGREE = "Disagree";

export default class Fec_CaseBussiness extends LightningElement {
  @api recordId;
  @api isEdit;

  @track business = {};

  isLoaded = true;

  businessLoaded = false;

  @track activeSectionlst = ["routing-action"];

  // get eyeIcon() {
  //   return this.isMasked ? "utility:preview" : "utility:hide";
  // }

  actionValue;

  isModalOpen = false;
  header;
  content;

  get showRouteTo() {
    return ACTION_ROUTE_TO === this.actionValue;
  }

  get showRevert() {
    return ACTION_REVERT === this.actionValue;
  }

  processActionMethod;

  processActionMsg;
  isProcessActionSuccessed = false;
  isProcessActionFailed = false;

  showProcessAction = false;
  isProcessActionValid = true;

  get finalShowProcessAction() {
    return this.showProcessAction && this.isProcessActionValid && this.isEdit;
  }

  customLabel = {
    reasonLabel: FEC_Reason_Label,
    routingActionLabel: FEC_Routing_Action_Label,
    actionLabel: FEC_Action_Label,
    teamLabel: FEC_Team_Label,
    queueLabel: FEC_Queue_Label,
    decisionLabel: FEC_Decision_Label,
  }

  connectedCallback() {
    this.getData();
  }

  disconnectedCallback() {}

  handleToggleMask(e) {
    let filter = {
      section: e.target.dataset.section,
      subSection: e.target.dataset.sub,
      obj: e.target.dataset.obj,
      field: e.target.dataset.field
    };

    let { field } = this.find(filter);

    let isPreview = e.target.iconName === "utility:preview";
    e.target.iconName = isPreview ? "utility:hide" : "utility:preview";

    if (isPreview) {
      field.value = mask(field.original, 4);
    } else {
      field.value = field.original;

      logSensitiveAccess({
        fieldName: field.apiName,
        caseId: this.recordId
      });
    }
  }

  @api getData(
    productTypeId = null,
    categoryId = null,
    subCategoryId = null,
    subCodeId = null
  ) {
    this.businessLoaded = false;

    getByCase({
      caseId: this.recordId,
      productTypeId,
      categoryId,
      subCategoryId,
      subCodeId
    })
      .then((res) => {
        if (!res) return;

        this.business = { ...res };

        this.activeSectionlst = ["routing-action"];

        this.business.hasRoutingAction =
          this.business.routingActionlst &&
          this.business.routingActionlst.length > 0 &&
          this.isEdit;

        // this.business.routingActionlst?.forEach((item) => {
        //   if (item.value === ACTION_REVERT) {
        //     this.actionValue = ACTION_REVERT;
        //   } else if (item.value === ACTION_RESOLVE) {
        //     this.actionValue = ACTION_RESOLVE;
        //   }
        // });

        // if (!this.actionValue)
        this.actionValue = this.business.routingActionlst[0]?.value;

        if (!this.business.nextQueue) {
          this.business.nextQueue = { label: "", value: null };
        }

        this.business.sectionlst.forEach((section, index) => {
          // handle error
          if (section.error?.errorlst?.length > 0) {
            section.hasError = true;

            section.error.errorPanellst = [];

            section.error?.errorlst?.forEach((error, index1) => {
              section.error.errorPanellst.push({
                id: index1,
                value: error
              });
            });

            this.actionValue = ACTION_REJECT;
          }
          section.id = crypto.randomUUID();

          this.activeSectionlst.push(section.id);
          section.isLastSection = index === this.business.sectionlst.length - 1;

          section.subSectionlst?.forEach((sub) => {
            sub.className = `slds-col slds-size_1-of-1 slds-medium-size_${sub.layout}-of-12`;
            sub.objlst.forEach((obj) => {
              let assignmentType;

              obj.fieldlst?.forEach((field) => {
                if (!this.isEdit) {
                  field.readonly = true;
                  field.editable = false;
                }

                let currentField = `${obj.name}.${field.apiName}`;

                if (
                  currentField == CASE_CS_D2C_ASSIGNMENT_TYPE ||
                  currentField == CASE_CONFIRM_D2C_ASSESMENT
                ) {
                  assignmentType = field.value;
                }

                if (!field.readonly) {
                  if (
                    currentField === CASE_CS_D2C_REQUIRED_CORRECTIVE_ACTION ||
                    currentField === CASE_CS_D2C_RISK_LEVEL
                  ) {
                    field.isHidden =
                      !assignmentType || assignmentType === TYPE_QUALIFIED;
                  } else if (
                    currentField === CASE_ACTIONS_TAKEN_D2C_ASSESMENT
                  ) {
                    field.isHidden =
                      !assignmentType || assignmentType === TYPE_DISAGREE;
                  } else {
                    field.isHidden = false;
                  }
                }

                field.original = field.value;

                field.hasHelpText =
                  field.helpText != null &&
                  field.helpText !== undefined &&
                  field.helpText !== "";

                field.masked = field.masked && field.value;

                if (field.masked) {
                  field.value = mask(field.original, 4, this.recordId);
                }
              });
            });
          });
        });

        console.error(
          "🚀 ~ Fec_CaseBussiness ~ getData ~ this.business:",
          JSON.stringify(this.business)
        );

        this.businessLoaded = true;
      })
      .catch((err) => {
        console.error(
          "🚀 ~ Fec_CaseBussiness ~ connectedCallback ~ err:",
          JSON.stringify(err)
        );
      })
      .finally(() => {});
  }

  handleChangeInput(e) {
    let value = e.target.value;

    let sectionName = e.target.dataset.section;
    let sub = e.target.dataset.sub;
    let fieldName = e.target.fieldName;
    let objName = e.target.dataset.objName;
    let objId = e.target.dataset.obj;

    let adHocFieldlst = [
      CASE_CS_D2C_ASSIGNMENT_TYPE,
      CASE_UPDATED_INFO_PHONE_NUMBER,
      CASE_CS_SUPPORT_ASSESMENT_TYPE,
      CASE_CONFIRM_D2C_ASSESMENT,
      CASE_CONFIRM_CS_SP_ASSESMENT
    ];

    let toRouteTo;
    let toRevert;
    let toReject;

    let { obj, field } = this.find({
      section: sectionName,
      subSection: sub,
      obj: objId,
      field: fieldName
    });

    if (field) {
      field.value = value;
    }

    // check Updated Info - Phone Number
    if (adHocFieldlst.includes(`${objName}.${fieldName}`)) {
      switch (`${objName}.${fieldName}`) {
        case CASE_UPDATED_INFO_PHONE_NUMBER:
          toRouteTo = value && value.trim() != "";
          break;

        case CASE_CS_D2C_ASSIGNMENT_TYPE:
          if (obj) {
            obj?.fieldlst?.forEach((item) => {
              if (
                item.apiName === CS_D2C_REQUIRED_CORRECTIVE_ACTION ||
                item.apiName === CS_D2C_RISK_LEVEL
              ) {
                item.isHidden = !(TYPE_UNQUALIFIED == value);
                item.value = undefined;
              }
            });
          }

          toRouteTo = TYPE_QUALIFIED == value;

          toRevert = TYPE_UNQUALIFIED == value;
          break;

        case CASE_CS_SUPPORT_ASSESMENT_TYPE:
          this.showProcessAction = TYPE_QUALIFIED == value;

          if (TYPE_UNQUALIFIED == value) {
            toRevert = true;
          }
          break;

        case CASE_CONFIRM_D2C_ASSESMENT:
          toReject = TYPE_AGREE == value;
          toRouteTo = TYPE_DISAGREE == value;

          if (obj) {
            obj?.fieldlst?.forEach((item) => {
              if (item.apiName === ACTIONS_TAKEN_D2C_ASSESMENT) {
                item.isHidden = TYPE_DISAGREE == value;
                item.value = undefined;
              }
            });
          }
          break;

        case CASE_CONFIRM_CS_SP_ASSESMENT:
          toReject = TYPE_AGREE == value;
          toRouteTo = TYPE_DISAGREE == value;
          break;

        default:
          break;
      }

      let routeToEle = this.template.querySelector(
        'lightning-select[data-id="routing-action"]'
      );

      if (routeToEle) {
        if (toRouteTo === true) {
          routeToEle.value = ACTION_ROUTE_TO;
          this.actionValue = ACTION_ROUTE_TO;
        }

        if (toRevert === true) {
          routeToEle.value = ACTION_REVERT;
          this.actionValue = ACTION_REVERT;
        }

        if (toReject === true) {
          routeToEle.value = ACTION_REJECT;
          this.actionValue = ACTION_REJECT;
        }
      }
    }
  }

  handleChangeAction(e) {
    this.actionValue = e.detail.value;
  }

  @api validate() {
    let isAllValid = true;

    let inputFiellst = this.template.querySelectorAll("lightning-input-field");

    inputFiellst.forEach((item) => {
      isAllValid = item.reportValidity() && isAllValid;
    });

    let routeToEle = this.template.querySelector(
      'lightning-select[data-id="routing-action"]'
    );

    isAllValid = routeToEle && routeToEle.reportValidity() && isAllValid;

    return isAllValid;
  }

  @api async submit() {
    if (!this.validate()) return;

    let routeToEle = this.template.querySelector(
      'lightning-select[data-id="routing-action"]'
    );

    let method = routeToEle.value;

    let actionId;

    this.business.routingActionlst?.forEach((item) => {
      if (item.value == method) {
        actionId = item.id;
      }
    });

    let params = { method };

    switch (method) {
      case ACTION_ROUTE_TO:
        params = {
          ...params,
          params: {
            caseId: this.recordId,
            queueId: this.business.nextQueue?.value,
            natureOfCaseId: this.business.natureOfCase,
            actionId: actionId
          }
        };
        break;

      case ACTION_REVERT:
        params = {
          ...params,
          params: {
            caseId: this.recordId
          }
        };
        break;

      default:
        break;
    }

    await run({ ...params });

    let formlst = this.template.querySelectorAll("lightning-record-edit-form");

    formlst.forEach((item) => {
      let fieldlst = item.querySelectorAll("lightning-input-field");

      if (fieldlst && fieldlst.length > 0) {
        item.submit();
        console.error("SUBMIT .......");
      }
    });
  }

  handleProcessAction(e) {
    let method = e.target.dataset.id;

    this.processActionMethod = method;

    this.header = ACTION_PHONE_UPDATE_HEADER;
    this.content = ACTION_PHONE_UPDATE_MSG;
    this.isModalOpen = true;
  }

  handleCloseModal() {
    this.isModalOpen = false;
  }

  handleRun() {
    this.isLoaded = false;
    this.isModalOpen = false;

    let params;

    switch (this.processActionMethod) {
      case ACTION_PHONE_UPDATE:
        params = {
          caseId: this.recordId
        };
        break;

      case ACTION_EMAIL_UPDATE:
        params = {
          caseId: this.recordId
        };
        break;

      case ACTION_FULLNAME_UPDATE:
        params = {
          caseId: this.recordId
        };
        break;

      case ACTION_DOB_UPDATE:
        params = {
          caseId: this.recordId
        };
        break;

      case ACTION_GENDER_UPDATE:
        params = {
          caseId: this.recordId
        };
        break;

      case OC_001:
        params = {
          caseId: this.recordId
        };
        break;
        
      default:
        break;
    }

    run({ method: this.processActionMethod, params })
      .then((res) => {
        let isSuccess = res?.success;

        this.isProcessActionValid =
          res?.actionCount != -1 && res?.actionCount != 3;

        if (isSuccess) {
          this.processActionMsg = ACTION_PHONE_UPDATE_SUCCESS_MSG;
          this.isProcessActionSuccessed = true;
          this.actionValue = ACTION_RESOLVE;

          let routeToEle = this.template.querySelector(
            'lightning-select[data-id="routing-action"]'
          );

          if (routeToEle) {
            routeToEle.value = ACTION_RESOLVE;
          }
        } else {
          this.processActionMsg = ACTION_PHONE_UPDATE_ERROR_MSG;
          this.isProcessActionFailed = true;
        }

        // switch (this.processActionMethod) {
        //   case ACTION_PHONE_UPDATE:
        //     break;

        //   default:
        //     break;
        // }
      })
      .catch((err) => {
        console.error(
          "🚀 ~ Fec_CaseBussiness ~ handleRun ~ err:",
          JSON.stringify(err)
        );

        this.isProcessActionFailed = true;
        this.processActionMsg = ACTION_PHONE_UPDATE_ERROR_MSG;
      })
      .finally(() => {
        this.isLoaded = true;
      });
  }

  find(filter) {
    // let filter = {
    //   section: e.target.dataset.section,
    //   subSection: e.target.dataset.sub,
    //   obj: e.target.dataset.obj,
    //   field: e.target.dataset.field
    // };

    let section;
    let subSection;
    let obj;
    let field;

    section = this.business?.sectionlst?.find(
      (item) => item.id === filter.section
    );

    if (section) {
      subSection = section.subSectionlst?.find(
        (item) => item.name === filter.subSection
      );

      if (subSection) {
        obj = subSection.objlst?.find((item) => (item.id = filter.obj));

        if (obj) {
          field = obj.fieldlst.find((item) => item.apiName === filter.field);
        }
      }
    }

    return { section, subSection, obj, field };
  }

  handleSuccess() {}
}