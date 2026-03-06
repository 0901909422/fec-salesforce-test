import { LightningElement, api, track, wire } from "lwc";
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { IsConsoleNavigation, openTab } from 'lightning/platformWorkspaceApi';
import VIEW_MODE from "@salesforce/schema/Case.FEC_Interaction_View_Mode__c";
import getCase from "@salesforce/apex/FEC_InteractionSLAController.getCase";
import getOutcomeCodePicklistValues from "@salesforce/apex/FEC_InteractionSLAController.getOutcomeCodePicklistValues";
import getQuickOutcomeCodePicklistValues from "@salesforce/apex/FEC_InteractionSLAController.getQuickOutcomeCodePicklistValues";
import updateInteractionOutcome from "@salesforce/apex/FEC_InteractionSLAController.updateInteractionOutcome";
import updateInteractionQuickWrapUp from "@salesforce/apex/FEC_InteractionSLAController.updateInteractionQuickWrapUp";
import getRelatedCasesCount from "@salesforce/apex/FEC_InteractionSLAController.getRelatedCasesCount";
import hasUnsubmittedCases from "@salesforce/apex/FEC_InteractionSLAController.hasUnsubmittedCases";
import hasSubmittedCases from "@salesforce/apex/FEC_InteractionSLAController.hasSubmittedCases";
import ICONS from "@salesforce/resourceUrl/FEC_SLA_Icon";

import FEC_Interaction_Remarks_Label from '@salesforce/label/c.FEC_Interaction_Remarks_Label';
import FEC_Quick_Wrap_up_Label from '@salesforce/label/c.FEC_Quick_Wrap_up_Label';
import FEC_Wrap_up_Information_Label from '@salesforce/label/c.FEC_Wrap_up_Information_Label';
import FEC_Select_Outcome_Code_Label from '@salesforce/label/c.FEC_Select_Outcome_Code_Label';
import FEC_Interaction_Remark_Placeholder from '@salesforce/label/c.FEC_Interaction_Remark_Placeholder';
import FEC_Btn_Cancel from '@salesforce/label/c.FEC_Btn_Cancel';
import FEC_Button_Confirm from '@salesforce/label/c.FEC_Button_Confirm';
import FEC_Success_Title from '@salesforce/label/c.FEC_Success_Title';
import FEC_Error_Title from '@salesforce/label/c.FEC_Error_Title';
import FEC_Unknown_Error from '@salesforce/label/c.FEC_Unknown_Error';
import FEC_Warning_Title from '@salesforce/label/c.FEC_Warning_Title';
import FEC_MSG_Interaction_wrapped_up_success from '@salesforce/label/c.FEC_MSG_Interaction_wrapped_up_success';
import FEC_MSG_Not_Found from '@salesforce/label/c.FEC_MSG_Not_Found';
import FEC_MSG_Wrap_Up_Warning from '@salesforce/label/c.FEC_MSG_Wrap_Up_Warning';
import FEC_MSG_Close_Interaction_Warning from '@salesforce/label/c.FEC_MSG_Close_Interaction_Warning';
import FEC_MSG_Close_Interaction_Complete_Case_Warning from '@salesforce/label/c.FEC_MSG_Close_Interaction_Complete_Case_Warning';
import FEC_MSG_Select_outcome_code from '@salesforce/label/c.FEC_MSG_Select_outcome_code';
import FEC_MSG_check_related_case_error from '@salesforce/label/c.FEC_MSG_check_related_case_error';
import FEC_MSG_check_case_type_error from '@salesforce/label/c.FEC_MSG_check_case_type_error';

import { urlCmpWithRecordId } from "c/fec_CommonUtils";
import { OUTCOME_CODE } from "c/fec_CommonConst";

const SLA_RULES = {
  Inbound: { green: 5, yellow: 10 },
  Outbound: { green: 5, yellow: null },
  Email: { green: 7, yellow: 10 },
  Chat: { green: 7, yellow: 10 },
  F2F: { green: 5, yellow: 10 },
  Letter: { green: 5, yellow: 10 },
  Internal: { green: 5, yellow: 10 },
  External: { green: 5, yellow: 10 }
};

export default class Fec_InteractionSLA extends NavigationMixin(LightningElement) {
  @api recordId;
  @api isModeEdit = false;

  interactionViewMode;

  @wire(getRecord, { recordId: "$recordId", fields: [VIEW_MODE] })
  wiredCaseRecord({ data, error }) {
    if (data) {
      this.interactionViewMode = getFieldValue(data, VIEW_MODE);
      console.log("Interaction View Mode:", this.interactionViewMode);
    }
  }

  get isReviewMode() {
    return this.interactionViewMode === 'review';
  }

  greenTimer;
  yellowTimer;

  firstTimeLoaded = true;

  @track record = {};
  @track isWrapUpModalOpen = false;
  @track isQuickWrapUpModalOpen = false;
  @track selectedOutcomeCode = '';
  @track interactionRemarks = '';
  @track outcomeCodeOptions = [];
  @track quickOutcomeCodeOptions = [];
  quickWrapUpOutcomeCode = OUTCOME_CODE;

  iconUrl;

  customLabel = {
    interactionRemark: FEC_Interaction_Remarks_Label,
    quickWrapUp: FEC_Quick_Wrap_up_Label,
    wrapUpInformation: FEC_Wrap_up_Information_Label,
    selectOutcomeCode: FEC_Select_Outcome_Code_Label,
    interactionRemarkPlaceholder: FEC_Interaction_Remark_Placeholder,
    btnCancel: FEC_Btn_Cancel,
    btnConfirm: FEC_Button_Confirm,
    successTitle: FEC_Success_Title,
    errorTitle: FEC_Error_Title,
    unknownError: FEC_Unknown_Error,
    warningTitle: FEC_Warning_Title,
    msgInteractionWrappedUpSuccess: FEC_MSG_Interaction_wrapped_up_success,
    msgNotFound: FEC_MSG_Not_Found,
    msgWrapUpWarning: FEC_MSG_Wrap_Up_Warning,
    msgCloseInteractionWarning: FEC_MSG_Close_Interaction_Warning,
    msgCloseInteractionCompleteCaseWarning: FEC_MSG_Close_Interaction_Complete_Case_Warning,
    msgSelectOutcomeCode: FEC_MSG_Select_outcome_code,
    msgCheckRelatedCaseError: FEC_MSG_check_related_case_error,
    msgCheckCaseTypeError: FEC_MSG_check_case_type_error,
  }

  @wire(IsConsoleNavigation)
  isConsoleNavigation;

  connectedCallback() {
    // Load picklist values cho cả 2 modal
    this.loadOutcomeCodeOptions();
    this.loadQuickOutcomeCodeOptions();
  }

  loadOutcomeCodeOptions() {
    // Sử dụng cùng field FEC_Outcome_Code__c cho Wrap-up Information
    getQuickOutcomeCodePicklistValues()
      .then((result) => {
        this.outcomeCodeOptions = result;
      })
      .catch((error) => {
        console.error('Error loading outcome code options:', error);
      });
  }

  loadQuickOutcomeCodeOptions() {
    getQuickOutcomeCodePicklistValues()
      .then((result) => {
        this.quickOutcomeCodeOptions = result;
      })
      .catch((error) => {
        console.error('Error loading quick outcome code options:', error);
      });
  }

  renderedCallback() {
    if (this.firstTimeLoaded) {
      getCase({ recordId: this.recordId })
        .then((res) => {
          if (!res) return;

          this.record = { ...res };

          this.iconUrl = `${ICONS}/${res.FEC_Channel__c}.svg`;

          this.refreshUI();

          this.scheduleHighlight(
            this.record.FEC_Channel__c,
            this.record.CreatedDate
          );
        })
        .catch((err) => {
          console.log(
            "🚀 ~ Fec_InteractionSLA ~ connectedCallback ~ err:",
            err
          );
        })
        .finally(() => {});

      this.firstTimeLoaded = false;
    }
  }

  disconnectedCallback() {
    this.clearTimers();
  }

  toMs(minutes) {
    return minutes * 60 * 1000;
  }

  scheduleHighlight(channel, createdDate) {
    const rule = SLA_RULES[channel];
    if (!rule) return;

    const created = new Date(createdDate).getTime();
    const now = Date.now();

    this.clearTimers();

    if (rule.yellow !== null) {
      const greenEnd = created + this.toMs(rule.green);
      const delayToYellow = greenEnd - now;

      if (delayToYellow > 0) {
        this.greenTimer = setTimeout(() => {
          this.refreshUI();
        }, delayToYellow);
      }
    }

    // 🟡 YELLOW → RED
    const yellowEnd = created + this.toMs(rule.yellow ?? rule.green);
    const delayToRed = yellowEnd - now;

    if (delayToRed > 0) {
      this.yellowTimer = setTimeout(() => {
        this.refreshUI();
      }, delayToRed);
    }
  }

  clearTimers() {
    if (this.greenTimer) {
      clearTimeout(this.greenTimer);
      this.greenTimer = null;
    }
    if (this.yellowTimer) {
      clearTimeout(this.yellowTimer);
      this.yellowTimer = null;
    }
  }

  getHighlight(channel, createdDate) {
    const minutes = this.getMinutesDiff(createdDate);
    const rule = SLA_RULES[channel];

    if (!rule) {
      return "duration__donut"; // fallback
    }

    if (minutes < rule.green) {
      return "duration__donut";
    }

    if (rule.yellow !== null && minutes < rule.yellow) {
      return "duration__donut duration__donut--yellow";
    }

    clearInterval(this.timer);

    if( this.record?.IsClosed ) {
      return "duration__donut duration__donut--grey";
    }

    return "duration__donut duration__donut--red";
  }

  refreshUI() {
    let donut = this.template.querySelector(".duration__donut");

    if (donut) {
      donut.classList = this.getHighlight(
        this.record.FEC_Channel__c,
        this.record.CreatedDate
      );
    }
  }

  getMinutesDiff(createdDate) {
    const created = new Date(createdDate);
    const now = new Date();
    return Math.floor((now - created) / 60000); // minutes
  }

  handleQuickWrapUpClick() {
    // Đảm bảo combobox luôn chọn đúng giá trị mặc định
    this.quickWrapUpOutcomeCode = OUTCOME_CODE;
    this.isQuickWrapUpModalOpen = true;
  }

  handleQuickWrapUpCancelClick() {
    this.isQuickWrapUpModalOpen = false;
  }

  handleQuickWrapUpConfirmClick() {
    // Luôn dùng giá trị mặc định cho Quick Wrap-up
    const quickOutcomeCode = this.quickWrapUpOutcomeCode;
    updateInteractionQuickWrapUp({ 
      recordId: this.recordId, 
      outcomeCode: quickOutcomeCode
    })
      .then(() => {
        this.showToast(this.customLabel.successTitle, this.customLabel.msgInteractionWrappedUpSuccess, 'success');
        this.record.FEC_Outcome_Code__c = quickOutcomeCode;
        this.record.Status = 'Closed';
        this.isQuickWrapUpModalOpen = false;
        
        // Notify LDS that record has been updated to refresh all components
        notifyRecordUpdateAvailable([{recordId: this.recordId}]);
        
        // Reload page after a short delay to ensure data is refreshed
        setTimeout(() => {
          window.location.reload();
        }, 1000);
      })
      .catch((error) => {
        console.error('Full error object:', JSON.stringify(error));
        console.error('Error details:', error);
        let errorMessage = this.customLabel.unknownError;
        if (error.body) {
          if (error.body.message) {
            errorMessage = error.body.message;
          } else if (error.body.fieldErrors) {
            errorMessage = JSON.stringify(error.body.fieldErrors);
          } else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
            errorMessage = error.body.pageErrors[0].message;
          }
        } else if (error.message) {
          errorMessage = error.message;
        }
        this.showToast(this.customLabel.errorTitle, errorMessage, 'error');
      });
  }

  @api
  handleWrapUpClick() {
    // Lấy thông tin Case để xác định loại và trạng thái submit
    getCase({ recordId: this.recordId })
      .then((caseData) => {
        if (!caseData) {
          this.showToast(this.customLabel.errorTitle, this.customLabel.msgNotFound.replace('{0}', 'Case'), 'error');
          return;
        }
        const isInteraction = caseData.RecordType && caseData.RecordType.DeveloperName === 'Interaction';
        // Nếu là Case con (không phải Interaction)
        if (!isInteraction) {
          if (caseData.FEC_Is_Submited__c) {
            // Đã submit, mở popup wrap-up
            this.selectedOutcomeCode = OUTCOME_CODE;
            if (this.outcomeCodeOptions && this.outcomeCodeOptions.length > 0) {
              const defaultOption = this.outcomeCodeOptions.find(
                option => option.label === OUTCOME_CODE
              );
              if (defaultOption) {
                this.selectedOutcomeCode = defaultOption.value;
              }
            }
            this.interactionRemarks = '';
            this.isWrapUpModalOpen = true;
          } else {
            // Chưa submit, cảnh báo
            this.showToast(this.customLabel.warningTitle, this.customLabel.msgWrapUpWarning, 'warning');
          }
          return;
        }
        // Nếu là Interaction, giữ logic cũ
        getRelatedCasesCount({ recordId: this.recordId })
          .then((count) => {
            if (count === 0) {
              this.showToast(this.customLabel.warningTitle, this.customLabel.msgCloseInteractionWarning, 'warning');
              return;
            }
            return hasUnsubmittedCases({ recordId: this.recordId })
              .then((hasUnsubmitted) => {
                if (hasUnsubmitted) {
                  this.showToast(this.customLabel.warningTitle, this.customLabel.msgCloseInteractionCompleteCaseWarning, 'warning');
                  return;
                }
                return hasSubmittedCases({ recordId: this.recordId })
                  .then((hasSubmitted) => {
                    if (!hasSubmitted) {
                      this.showToast(this.customLabel.warningTitle, this.customLabel.msgCloseInteractionCompleteCaseWarning, 'warning');
                      return;
                    }
                    this.selectedOutcomeCode = OUTCOME_CODE;
                    if (this.outcomeCodeOptions && this.outcomeCodeOptions.length > 0) {
                      const defaultOption = this.outcomeCodeOptions.find(
                        option => option.label === OUTCOME_CODE
                      );
                      if (defaultOption) {
                        this.selectedOutcomeCode = defaultOption.value;
                      }
                    }
                    this.interactionRemarks = '';
                    this.isWrapUpModalOpen = true;
                  });
              });
          })
          .catch((error) => {
            console.error('Error checking related cases:', error);
            this.showToast(this.customLabel.errorTitle, this.customLabel.msgCheckRelatedCaseError, 'error');
          });
      })
      .catch((error) => {
        console.error('Error checking case type:', error);
        this.showToast(this.customLabel.errorTitle, this.customLabel.msgCheckCaseTypeError, 'error');
      });
  }

  handleCancelClick() {
    this.isWrapUpModalOpen = false;
    this.selectedOutcomeCode = '';
    this.interactionRemarks = '';
  }

  handleOutcomeCodeChange(event) {
    this.selectedOutcomeCode = event.detail.value;
  }

  handleInteractionRemarksChange(event) {
    this.interactionRemarks = event.target.value || '';
  }

  handleConfirmClick() {
    if (!this.selectedOutcomeCode) {
      this.showToast(this.customLabel.errorTitle, this.customLabel.msgSelectOutcomeCode, 'error');
      return;
    }

    // Update Interaction with outcome code and remarks
    updateInteractionOutcome({ 
      recordId: this.recordId, 
      outcomeCode: this.selectedOutcomeCode,
      interactionRemarks: this.interactionRemarks || ''
    })
      .then(() => {
        this.showToast(this.customLabel.successTitle, this.customLabel.msgInteractionWrappedUpSuccess, 'success');
        
        // Refresh the record
        this.record.FEC_Outcome_Code__c = this.selectedOutcomeCode;
        this.record.FEC_Interaction_Remarks__c = this.interactionRemarks;
        this.record.FEC_Interaction_Status__c = 'Closed';
        
        // Close modal and reset
        this.isWrapUpModalOpen = false;
        this.selectedOutcomeCode = '';
        this.interactionRemarks = '';
        
        // Notify LDS that record has been updated to refresh all components
        notifyRecordUpdateAvailable([{recordId: this.recordId}]);
        
        // Reload page after a short delay to ensure data is refreshed
        setTimeout(() => {
          window.location.reload();
        }, 1000);
      })
      .catch((error) => {
        console.error('Full error object:', JSON.stringify(error));
        console.error('Error details:', error);
        
        let errorMessage = this.customLabel.unknownError;
        
        if (error.body) {
          if (error.body.message) {
            errorMessage = error.body.message;
          } else if (error.body.fieldErrors) {
            errorMessage = JSON.stringify(error.body.fieldErrors);
          } else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
            errorMessage = error.body.pageErrors[0].message;
          }
        } else if (error.message) {
          errorMessage = error.message;
        }
        
        this.showToast(this.customLabel.errorTitle, errorMessage, 'error');
      });
  }

  async handleCreateCase() {
    if (this.isConsoleNavigation) {
      await openTab({
        url: urlCmpWithRecordId('fec_InteractionCreateCase', this.recordId),
        focus: true
      });
    } else {
      this[NavigationMixin.Navigate]({
        type: 'standard__component',
        attributes: {
          componentName: "c__fec_InteractionCreateCase"
        },
        state: {
          c__recordId: this.recordId
        }
      });
    }
  }

  async handleEditInteraction() {
    if (this.isConsoleNavigation) {
      await openTab({
        url: urlCmpWithRecordId('fec_CaseDetail_Interation_Edit', this.recordId),
        focus: true
      });
    } else {
      this[NavigationMixin.Navigate]({
        type: 'standard__component',
        attributes: {
          componentName: "c__fec_CaseDetail_Interation_Edit"
        },
        state: {
          c__recordId: this.recordId
        }
      });
    }
  }

  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(event);
  }
}