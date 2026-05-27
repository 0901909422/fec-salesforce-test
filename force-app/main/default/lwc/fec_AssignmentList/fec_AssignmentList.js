import { LightningElement, api, wire, track } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { loadStyle } from "lightning/platformResourceLoader";
import COMMON_STYLES from "@salesforce/resourceUrl/FEC_CommonCss";
// import getAssignments from "@salesforce/apex/FEC_AssignmentListHandler.getAssignments";
import getAssignmentsNEW from "@salesforce/apex/FEC_AssignmentListHandler.getAssignmentsNEW";
import getQueueNames from "@salesforce/apex/FEC_AssignmentListHandler.getQueueNames"; // tungnm37 thêm
import getAction from "@salesforce/apex/FEC_AssignmentListHandler.getAction";
import getUserDepartment from "@salesforce/apex/FEC_AssignmentListHandler.getUserDepartment";
import getUsersInGroup from "@salesforce/apex/FEC_AssignmentListHandler.getUsersInGroup";
import getQueuesForUser from "@salesforce/apex/FEC_AssignmentListHandler.getQueuesForUser";

import getTeams from "@salesforce/apex/FEC_AssignmentRoutingActionHandler.getTeams";
//HieuTT74: [Update 20/5/2026] Get Team cho Action Route to
import getTeamForRouteToAction from "@salesforce/apex/FEC_AssignmentListHandler.getTeamForRouteToAction";
import getQueueForRouteToAction from "@salesforce/apex/FEC_AssignmentListHandler.getQueueForRouteToAction";

import getQueuesByTeam from "@salesforce/apex/FEC_AssignmentRoutingActionHandler.getQueuesByTeam";

import CASE_ID from "@salesforce/schema/Case.Id";
import USER_ID from "@salesforce/user/Id";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import executeSubmit from "@salesforce/apex/FEC_AssignmentRoutingActionHandler.execute";
//thangtv: refresh ẩn/hiện nút Execute Assignment sau Submit
import refreshExecuteVisibility from "@salesforce/apex/FEC_AssignmentExecuteService.refreshExecuteAssignmentVisibility";
import {
  subscribe,
  unsubscribe,
  publish,
  APPLICATION_SCOPE,
  MessageContext,
} from "lightning/messageService";
import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Assignment_Mode__c";

import FEC_Assignment_List from "@salesforce/label/c.FEC_Assignment_List";
import FEC_Assignment_Routing_Action from "@salesforce/label/c.FEC_Assignment_Routing_Action";
import FEC_Assignment_Id from "@salesforce/label/c.FEC_Assignment_Id";
import FEC_Assignment_Status from "@salesforce/label/c.FEC_Assignment_Status";
import FEC_Assignment_Owner from "@salesforce/label/c.FEC_Assignment_Owner";

import FEC_Assignment_Remarks_History from "@salesforce/label/c.FEC_Assignment_Remarks_History";
import saveAssignmentDraft from "@salesforce/apex/FEC_AssignmentListHandler.saveAssignmentDraft";
import {
  PAGE_SIZE_OPTIONS,
  ACTION_OPTIONS_CS_SUPPORT,
  ACTION_OPTIONS_OTHER,
  DECISION_OPTIONS_MAP,
  ACTIONS_REQUIRE_DECISION,
  ACTIONS_REQUIRE_SUBDECISION_MAP,
  ACTION,
  OPEN_STATUS,
  QUEUE_ID_START,
  NEW_STATUS,
} from "c/fec_CommonConst";
import { getUsernameBeforeAt } from "c/fec_CommonUtils";
import isCSSupport from "@salesforce/apex/FEC_AssignmentListHandler.isCSSupport";

import isCSCustomerCare from "@salesforce/apex/FEC_AssignmentListHandler.isCSCustomerCare";
export default class Fec_AssignmentList extends LightningElement {
  label = {
    FEC_Assignment_List,
    FEC_Assignment_Routing_Action,
    FEC_Assignment_Id,
    FEC_Assignment_Status,
    FEC_Assignment_Owner,
    FEC_Assignment_Remarks_History,
  };

  async connectedCallback() {
    try {
      this.loadStyles();

      console.log("Before getUserDepartment");

      this.userDept = await getUserDepartment();

      console.log("After getUserDepartment:", JSON.stringify(this.userDept));

      /*
       * Load department flags
       */
      this.isCSSupportUser = await isCSSupport();

      this.isCSCustomerCareUser = await isCSCustomerCare();

      console.log("isCSSupportUser:", this.isCSSupportUser);

      console.log("isCSCustomerCareUser:", this.isCSCustomerCareUser);

      this.initSubscription();

      this.loadActions();
    } catch (error) {
      console.error("getUserDepartment error:", JSON.stringify(error));
    }
  }

  loadStyles() {
    loadStyle(this, COMMON_STYLES).catch((e) =>
      console.error("Load style error", e),
    );
  }

  @wire(MessageContext)
  messageContext;

  @api recordId;
  @api modeEditCase;

  currentUserId = USER_ID;
  userDept;

  @track pagedData = [];
  @track pageSize = PAGE_SIZE_OPTIONS[0];
  @track currentPage = 1;

  @track assignments = [];
  @track actionOptions = [];
  @track userOptions = [];
  @track queueOptions = [];

  @track teamOptions = [];
  @track queueOptionsByTeam = [];

  subscription = null;
  isCSSupportUser = false;

  isCSCustomerCareUser = false;
  initSubscription() {
    if (this.subscription) return;

    this.subscription = subscribe(
      this.messageContext,
      IS_MODE_EDIT,
      (message) => this.handleModeMessage(message),
      { scope: APPLICATION_SCOPE },
    );
  }

  async handleModeMessage(message) {
    console.log("MODE MESSAGE:", JSON.stringify(message));

    if (message?.caseId !== this.recordId) {
      return;
    }

    this.modeEditCase = message?.isEditMode;

    /*
     * IMPORTANT:
     * Reload assignments
     * after execute action
     */
    console.log("START RELOAD ASSIGNMENTS");

    await this.initData();

    console.log("RELOAD ASSIGNMENTS DONE");

    /*
     * Refresh readonly state
     */
    this.refreshReadonlyState();
  }

  refreshReadonlyState() {
    const isEdit = this.modeEditCase;

    // 👉 đóng tất cả row đang mở khi chuyển sang view
    if (!isEdit) {
      this.assignments = this.assignments.map((item) => ({
        ...item,
        isOpen: false,
      }));
    }

    // 👉 clear input đang nhập (tránh giữ state cũ)
    this.assignments = this.assignments.map((item) => ({
      ...item,
      action: isEdit ? item.action : null,
      remark: isEdit ? item.remark : null,
      decision: isEdit ? item.decision : null,
      subDecision: isEdit ? item.subDecision : null,
    }));

    // 👉 refresh lại paging
    this.updatePagedData();
  }

  disconnectedCallback() {
    if (this.subscription) {
      unsubscribe(this.subscription);
      this.subscription = null;
    }
  }

  //------- get data from server -------//
  /* =======================
   * WIRE
   * ======================= */
  @wire(getRecord, {
    recordId: "$recordId",
    fields: [CASE_ID],
  })
  wiredCase({ data, error }) {
    if (data) {
      this.initData(); // chỉ gọi 1 entry point
    }
    if (error) {
      console.error("[WIRE] Error loading Case", error);
    }
  }

  async initData() {
    try {
      const result = await getAssignmentsNEW({
        caseId: this.recordId,
      });
      console.log("getAssignments result:", JSON.stringify(result));

      // tungnm37: FEC_OwnerID__c giờ lưu Queue Name trực tiếp
      this.assignments = result.map((item) => ({
        id: item.Id,
        assignmentId: item.Name,
        ownerId: item.FEC_Assignment_Owner__c || "",
        // tungnm37: dùng formula FEC_Assignment_Owner_Text__c (tự xử lý Unassigned/queue/user)
        owner:
          item.FEC_Assignment_Owner_Text__c ||
          (item.FEC_Assignment_Owner__c?.startsWith("00G")
            ? item.FEC_Assignment_Owner__r?.Name
            : getUsernameBeforeAt(item.FEC_Assignment_Owner__r?.Email) || ""),
        remark: item.FEC_Draft_Assignment_Remark__c,
        isOwner: item.FEC_Assignment_Owner__c ? this.isOwner(item) : false,
        status:
          // tungnm37 sửa: COF/GSR (Routing type) hiện 'Open', các loại khác giữ nguyên 'New'
          item.FEC_Assignment_Type__c === "Routing" &&
          item.FEC_Assignment_Status__c === OPEN_STATUS
            ? OPEN_STATUS
            : item.FEC_Assignment_Status__c === OPEN_STATUS
              ? NEW_STATUS
              : item.FEC_Assignment_Status__c,

        isOpen: false,

        action: null,
        decision: null,
        subDecision: null,
        userInGroup: null,
        queueForUser: null,

        detailKey: item.Id + "-detail",

        // UI derived (được set khi action/decision thay đổi)
        decisionOptions: [],
        showDecision: false,
        showSubDecision: false,
        isUserDecision: false,
        isQueueDecision: false,
      }));
      console.log("Processed assignments:", JSON.stringify(this.assignments));
      this.updatePagedData();
    } catch (e) {
      console.error("initData error:", JSON.stringify(e));
    }
  }

  isOwner(item) {
    return item.FEC_Assignment_Owner__c === this.currentUserId;
  }
  handleToggle(event) {
    const id = event.currentTarget.dataset.id;

    this.assignments = this.assignments.map((item) => {
      return {
        ...item,
        isOpen: item.id === id ? !item.isOpen : false, // only 1 open
      };
    });
    this.updatePagedData();
  }

  get isCSSupport() {
    return this.userDept === "CS";
  }

  async loadActions() {
    try {
      const result = await getAction({
        caseId: this.recordId,
      });

      this.actionOptions = result;

      console.log("actionOptions:", JSON.stringify(result));
    } catch (e) {
      console.error("getAction error", e);

      this.error = e;
    }
  }

  handleActionChange(event) {
    const id = event.target.dataset.id;
    const value = event.detail.value;

    this.assignments = this.assignments.map((item) => {
      if (item.id !== id) {
        return item;
      }

      return {
        ...item,

        action: value,

        decision: null,
        subDecision: null,

        decisionOptions: this.getDecisionOptions(value),

        showDecision: ACTIONS_REQUIRE_DECISION.includes(value),

        showSubDecision: false,

        isUserDecision: false,
        isQueueDecision: false,

        /*
         * Route_to
         * show team combobox immediately
         */
        showTeam: value === "Route_to",

        showQueueByTeam: false,

        selectedTeam: null,
        selectedQueue: null,
      };
    });

    this.updatePagedData();

    /*
     * Auto load teams for Route_to
     */
    if (value === "Route_to") {
      const currentItem = this.assignments.find((item) => item.id === id);

      if (currentItem) {
        this.loadTeamsForRouteToAction(
          currentItem.assignmentId,
          currentItem.id,
        );
      }
    }
  }

  getDecisionOptions(action) {
    /*
     * UPDATE
     */
    if (action === "Update") {
      /*
       * CS Support
       */
      if (this.isCSSupportUser) {
        return DECISION_OPTIONS_MAP.UpdateSP || [];
      }

      /*
       * CS Customer Care
       */
      if (this.isCSCustomerCareUser) {
        return DECISION_OPTIONS_MAP.UpdateCC || [];
      }

      return [];
    }

    /*
     * Default
     */
    return DECISION_OPTIONS_MAP[action] || [];
  }

  handleDecisionChange(event) {
    const id = event.target.dataset.id;
    const value = event.detail.value;

    /*
     * Find current assignment
     */
    const currentItem = this.assignments.find((item) => item.id === id);

    if (!currentItem) {
      return;
    }

    this.assignments = this.assignments.map((item) => {
      if (item.id !== id) {
        return item;
      }

      const requiredSubDecisionValues =
        ACTIONS_REQUIRE_SUBDECISION_MAP[item.action] || [];

      return {
        ...item,

        decision: value,
        subDecision: null,

        showSubDecision: requiredSubDecisionValues.includes(value),

        isUserDecision: value === "USER",

        isQueueDecision: value === "QUEUE",

        showTeam: item.action === "Route_to" && value === "TEAM",

        showQueueByTeam: false,

        selectedTeam: null,
        selectedQueue: null,
      };
    });

    this.updatePagedData();

    /*
     * USER
     */
    if (value === "USER") {
      this.loadUsers();
    } else if (value === "QUEUE") {
      /*
       * QUEUE
       */
      this.loadQueues();
    } else if (value === "TEAM") {
      /*
       * TEAM
       */
      /*
       * Route To
       */
      if (currentItem.action === "Route_to") {
        this.loadTeamsForRouteToAction(currentItem.assignmentId);
      } else {
        /*
         * Other actions
         */
        this.loadTeams();
      }
    }
  }

  async loadUsers() {
    const result = await getUsersInGroup();
    this.userOptions = result.map((r) => ({
      label: r.label,
      value: r.value,
    }));
  }

  async loadQueues() {
    const result = await getQueuesForUser();

    console.log("QUEUE RESULT", JSON.stringify(result));

    this.queueOptions = result.map((r) => ({
      label: r.label,
      value: r.value,
    }));

    console.log("QUEUE OPTIONS", JSON.stringify(this.queueOptions));
  }

  async loadTeams() {
    const result = await getTeams();

    this.teamOptions = result.map((r) => ({
      label: r.label,
      value: r.value,
    }));
  }

  async loadTeamsForRouteToAction(selectedAssignmentId) {
    const result = await getTeamForRouteToAction({
      caseId: this.recordId,
      assignmentId: selectedAssignmentId,
    });
    this.teamOptions = result.map((r) => ({
      label: r.label,
      value: r.value,
    }));
  }

  async loadQueuesForRouteToAction(selectedAssignmentId) {
    const result = await getQueueForRouteToAction({
      caseId: this.recordId,
      assignmentId: selectedAssignmentId,
    });
    this.queueOptionsByTeam = result.map((r) => ({
      label: r.label,
      value: r.value,
    }));
  }

  handleTeamChange(event) {
    const id = event.target.dataset.id;
    const team = event.detail.value;

    /*
     * Find current assignment
     */
    const currentItem = this.assignments.find((item) => item.id === id);

    if (!currentItem) {
      return;
    }
    // set team vào decision (giữ nguyên)
    this.assignments = this.assignments.map((item) => {
      if (item.id === id) {
        return {
          ...item,
          // decision: team,
          subDecision: team,
          showQueueByTeam: true,
        };
      }
      return item;
    });

    this.updatePagedData();

    // this.loadQueuesByTeam(team);

    if (currentItem.action === "Route_to") {
      this.loadQueuesForRouteToAction(currentItem.assignmentId);
    } else {
      /*
       * Other actions
       */
    }
  }

  async loadQueuesByTeam(team) {
    const result = await getQueuesByTeam({ team });

    this.queueOptionsByTeam = result.map((r) => ({
      label: r.label,
      value: r.value, // queueId
    }));
  }

  handleSubDecisionChange(event) {
    const id = event.target.dataset.id;
    const value = event.detail.value;

    console.log("Sub decision change", JSON.stringify({ id, value }));
    this.updateField(id, "subDecision", value);
  }

  handleRemarkChange(event) {
    const id = event.target.dataset.id;
    const value = event.target.value;
    this.updateField(id, "remark", value);
  }

  updateField(id, field, value) {
    this.assignments = this.assignments.map((item) => {
      if (item.id === id) {
        return { ...item, [field]: value };
      }
      return item;
    });

    this.updatePagedData();
  }

  async handleSubmit() {
    if (this.isSubmitting) return;
    this.isSubmitting = true;

    const selected = this.assignments.find((a) => a.isOpen);
    if (!selected) {
      this.isSubmitting = false;
      return;
    }

    // ===== VALIDATION =====
    const container = this.template
      .querySelector(`[data-id="${selected.id}"]`)
      ?.closest(".slds-box");

    const inputs =
      container?.querySelectorAll("lightning-combobox, lightning-textarea") ||
      [];

    let isValid = true;

    inputs.forEach((input) => {
      input.reportValidity();
      if (!input.checkValidity()) {
        isValid = false;
      }
    });

    if (!isValid) {
      this.isSubmitting = false;
      return;
    }

    try {
      console.log("Payload");
      console.log(
        JSON.stringify({
          caseId: this.recordId,
          assignmentId: selected.id,
          action: selected.action,
          remark: selected.remark,
          decision: selected.decision,
          subDecision: selected.subDecision,
        }),
      );
      // ===== CALL APEX =====
      await executeSubmit({
        caseId: this.recordId,
        assignmentId: selected.id,
        action: selected.action,
        remark: selected.remark,
        decision: selected.decision,
        subDecision: selected.subDecision,
      });

      // ===== SUCCESS =====
      console.log("Submit success");
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Submit success",
          variant: "success",
        }),
      );
      // reload data
      await this.initData();
      const remarkHistoryCmp = this.template.querySelector(
        "c-fec_-assignment-remark-history-table, c-fec_-assignment-remark-history-table",
      );

      if (
        remarkHistoryCmp &&
        typeof remarkHistoryCmp.refreshData === "function"
      ) {
        await remarkHistoryCmp.refreshData();
      }
      //thangtv: cập nhật FEC_Can_Execute_Assignment__c khi assignment đã Completed
      await refreshExecuteVisibility({ caseId: this.recordId });

      // 👇 QUAN TRỌNG: chuyển mode view
      setTimeout(() => {
        this.modeEditCase = false;
        this.handlePublishMode(false);
      }, 0);
    } catch (error) {
      console.error("FULL ERROR:", error);

      const message =
        error?.body?.message || error?.message || "Unexpected error occurred";

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: message,
          variant: "error",
        }),
      );
    } finally {
      this.isSubmitting = false;
    }
  }

  async handleSaveClose() {
    const selected = this.assignments.find((a) => a.isOpen);

    if (!selected) {
      return;
    }

    try {
      await saveAssignmentDraft({
        assignmentId: selected.id,
        remark: selected.remark,
      });

      // collapse row
      this.assignments = this.assignments.map((item) => {
        if (item.id === selected.id) {
          return {
            ...item,
            isOpen: false,
            // isReviewMode: true,
          };
        }

        return item;
      });

      // this.updatePagedData();

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Save success",
          variant: "success",
        }),
      );

      // reload data
      // await this.initData();

      await refreshExecuteVisibility({ caseId: this.recordId });

      // 👇 QUAN TRỌNG: chuyển mode view
      setTimeout(() => {
        this.modeEditCase = false;
        this.handlePublishMode(false);
      }, 0);
    } catch (e) {
      console.error(e);
    }
  }

  async handlePublishMode(isEdit) {
    if (this.messageContext == null) return;
    const payload = {
      caseId: this.recordId,
      isEditMode: Boolean(isEdit),
    };
    publish(this.messageContext, IS_MODE_EDIT, payload);
  }

  //---pagination handlers---//
  get pageSizeOptions() {
    return PAGE_SIZE_OPTIONS.map((size) => ({
      label: size.toString(),
      value: size.toString(),
    }));
  }

  get pageSizeStr() {
    return this.pageSize.toString();
  }

  get totalPages() {
    return Math.ceil(this.assignments.length / this.pageSize);
  }

  get isFirstPage() {
    return this.currentPage === 1;
  }

  get isLastPage() {
    return this.currentPage >= this.totalPages;
  }

  get showPagination() {
    return this.totalPages > 1;
  }

  updatePagedData() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.pagedData = this.assignments.slice(start, end);
  }

  handlePageSizeChange(event) {
    this.pageSize = parseInt(event.detail.value, 10);
    this.currentPage = 1;
    this.updatePagedData();
  }

  handleNextPage() {
    if (!this.isLastPage) {
      this.currentPage++;
      this.updatePagedData();
    }
  }

  handlePrevPage() {
    if (!this.isFirstPage) {
      this.currentPage--;
      this.updatePagedData();
    }
  }

  //getter
  get hasAssignmentData() {
    return Array.isArray(this.pagedData) && this.pagedData.length > 0;
  }
}
