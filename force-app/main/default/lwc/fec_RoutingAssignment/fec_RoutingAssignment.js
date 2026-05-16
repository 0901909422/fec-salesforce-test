// tungnm37 thêm: LWC hiển thị Routing Assignment (Team/Queue) từ FEC_Routing_Assignment__c
import { LightningElement, api, track, wire } from 'lwc';
import getRoutingAssignments from '@salesforce/apex/FEC_CaseBusinessService.getRoutingAssignments';
import getTeamQueueOptions from '@salesforce/apex/FEC_CaseBusinessService.getTeamQueueOptions';
import FEC_Team_Label from '@salesforce/label/c.FEC_Team_Label';
import FEC_Queue_Label from '@salesforce/label/c.FEC_Queue_Label';
import FEC_Add_Item_Label from '@salesforce/label/c.FEC_Add_Item_Label';
import FEC_Assignment_Remark_Label from '@salesforce/label/c.FEC_Assignment_Remark_Label';
import FEC_Confirm_Label from '@salesforce/label/c.FEC_Confirm_Label';
import FEC_Choose_Team_Placeholder from '@salesforce/label/c.FEC_Choose_Team_Placeholder';
import FEC_Choose_Queue_Placeholder from '@salesforce/label/c.FEC_Choose_Queue_Placeholder';
import FEC_Enter_Remark_Placeholder from '@salesforce/label/c.FEC_Enter_Remark_Placeholder';
import FEC_Remark_Label from '@salesforce/label/c.FEC_Remark_Label';
import FEC_Duplicate_Queue_Error from '@salesforce/label/c.FEC_Duplicate_Queue_Error';

const ROUTING_ASSIGNMENT_PREFIXES = ['COF', 'GSR'];

export default class Fec_RoutingAssignment extends LightningElement {
  @api
  get natureOfCaseId() { return this._natureOfCaseId; }
  set natureOfCaseId(val) {
    this._natureOfCaseId = val;
    if (val) this._loadAssignments();
  }
  _natureOfCaseId;

  @api businessCode;
  @api customerType;
  @api isSubmited;
  @api userGroup;
  // tungnm37 fix: tên Queue của Case Owner để ẩn team tương ứng trong Add Item
  @api caseOwnerQueueName;

  @track assignments = [];
  @track allTeamQueueOptions = [];
  @track showAddForm = false;
  @track manualItems = [];
  @track formTeam = '';
  @track formQueue = '';

  // tungnm37: expose để parent check form đang mở chưa confirm
  @api get hasUnconfirmedForm() {
    return this.showAddForm && (this.formTeam || this.formQueue);
  }

  // tungnm37: expose để parent check nút Add Item đang hiển thị nhưng chưa add item nào
  @api get requiresManualItemButEmpty() {
    return this.showAddItem && this.manualItems.length === 0;
  }
  @track formRemark = '';
  @track showValidationError = false;
  @track validationErrorMsg = '';

  teamLabel = FEC_Team_Label;
  queueLabel = FEC_Queue_Label;
  addItemLabel = FEC_Add_Item_Label;
  assignmentRemarkLabel = FEC_Assignment_Remark_Label;
  confirmLabel = FEC_Confirm_Label;
  chooseTeamPlaceholder = FEC_Choose_Team_Placeholder;
  chooseQueuePlaceholder = FEC_Choose_Queue_Placeholder;
  enterRemarkPlaceholder = FEC_Enter_Remark_Placeholder;
  remarkLabel = FEC_Remark_Label;

  get isVisible() {
    return (
      typeof this.businessCode === 'string' &&
      ROUTING_ASSIGNMENT_PREFIXES.some(p => this.businessCode.startsWith(p)) &&
      this.assignments.length > 0
    );
  }

  get isSingle() {
    return this.assignments.length === 1;
  }

  get firstItem() {
    return this.assignments.length > 0 ? this.assignments[0] : { team: '', queue: '' };
  }

  // tungnm37: hiện nút Add Item khi COF/GSR + isSubmited + FEC_Team__c = CC hoặc SP
  get showAddItem() {
    if (!this.isVisible || this.isSubmited !== true) return false;
    return this.assignments.some(a => a.team === 'CC' || a.team === 'SP');
  }

  get hasManualItems() {
    return this.manualItems.length > 0;
  }

  // tungnm37: danh sách Team unique từ FEC_Team_Queue__c
  // tungnm37 fix: ẩn team tương ứng với Case Owner Queue
  // - Case Owner = DQ CS Customer Care → ẩn CC
  // - Case Owner = DQ CS Support → ẩn SP
  get teamOptions() {
    const seen = new Set();
    const ownerQueue = this.caseOwnerQueueName || '';
    // Dựa vào assignments: nếu có team CC/SP trong routing assignments thì ẩn team đó
    const assignmentTeams = new Set(this.assignments.map(a => a.team));
    const hiddenTeams = new Set();
    if (assignmentTeams.has('CC')) hiddenTeams.add('CC');
    if (assignmentTeams.has('SP')) hiddenTeams.add('SP');
    // Fallback: dựa vào caseOwnerQueueName nếu có
    if (ownerQueue.toLowerCase().includes('customer care')) hiddenTeams.add('CC');
    if (ownerQueue.toLowerCase().includes('support')) hiddenTeams.add('SP');
    return this.allTeamQueueOptions
      .filter(o => !hiddenTeams.has(o.teamName))
      .filter(o => { if (seen.has(o.teamName)) return false; seen.add(o.teamName); return true; })
      .map(o => ({ label: o.teamName, value: o.teamName }));
  }

  // tungnm37: danh sách Queue lọc theo Team đã chọn
  get queueOptions() {
    if (!this.formTeam) return [];
    return this.allTeamQueueOptions
      .filter(o => o.teamName === this.formTeam)
      .map(o => ({ label: o.queueName, value: o.queueName }));
  }

  // tungnm37: dùng imperative call thay wire để tránh cache cũ
  connectedCallback() {
    this._loadAssignments();
    this._loadTeamQueueOptions();
  }

  _loadAssignments() {
    if (!this.natureOfCaseId) return;
    console.log('[fec_RoutingAssignment] _loadAssignments natureOfCaseId=' + this.natureOfCaseId + ' customerType=' + this.customerType);
    getRoutingAssignments({ natureOfCaseId: this.natureOfCaseId, customerType: this.customerType })
      .then(data => {
        console.log('[fec_RoutingAssignment] getRoutingAssignments result', JSON.stringify(data));
        this.assignments = data || [];
        this.dispatchEvent(new CustomEvent('assignmentsloaded', { detail: { count: this.assignments.length } }));
      })
      .catch(error => {
        console.error('[fec_RoutingAssignment] getRoutingAssignments error', error);
        this.assignments = [];
        this.dispatchEvent(new CustomEvent('assignmentsloaded', { detail: { count: 0 } }));
      });
  }

  _loadTeamQueueOptions() {
    getTeamQueueOptions()
      .then(data => { this.allTeamQueueOptions = data || []; })
      .catch(error => console.error('[fec_RoutingAssignment] getTeamQueueOptions error', error));
  }

  @wire(getTeamQueueOptions)
  wiredTeamQueue({ data, error }) {
    if (data) this.allTeamQueueOptions = data;
    else if (error) console.error('[fec_RoutingAssignment] getTeamQueueOptions error', error);
  }

  handleToggleForm() {
    if (this.showAddForm) {
      this.showAddForm = false;
    } else {
      this.showAddForm = true;
      this.formTeam = '';
      this.formQueue = '';
      this.formRemark = '';
    }
  }

  handleAddItem() {
    this.showAddForm = true;
    this.formTeam = '';
    this.formQueue = '';
    this.formRemark = '';
  }

  handleCancelForm() {
    this.showAddForm = false;
    this.showValidationError = false;
  }

  handleTeamChange(e) {
    this.formTeam = e.detail.value;
    this.formQueue = ''; // reset queue khi đổi team
  }

  handleQueueChange(e) {
    this.formQueue = e.detail.value;
  }

  handleRemarkChange(e) {
    this.formRemark = e.target.value;
  }

  handleConfirm() {
    this.showValidationError = false;
    const errors = [];
    if (!this.formTeam) errors.push('Team');
    if (!this.formQueue) errors.push('Queue');
    if (!this.formRemark) errors.push('Assignment Remark');
    if (errors.length > 0) {
      this.showValidationError = true;
      this.validationErrorMsg = errors.join(', ') + ' là bắt buộc.';
      return;
    }
    // tungnm37: check duplicate queue
    const isDuplicateQueue = this.manualItems.some(i => i.queueName === this.formQueue);
    if (isDuplicateQueue) {
      this.dispatchEvent(new CustomEvent('duplicatequeue', {
        detail: { message: FEC_Duplicate_Queue_Error }
      }));
      return;
    }
    const newItem = {
      key: Date.now() + '_' + Math.random(),
      teamName: this.formTeam,
      queueName: this.formQueue,
      remark: this.formRemark
    };
    this.manualItems = [...this.manualItems, newItem];
    this.showAddForm = false;
    // tungnm37: fire event lên parent với danh sách manual items
    this.dispatchEvent(new CustomEvent('manualitemschange', {
      detail: { items: this.manualItems }
    }));
  }

  handleRemoveItem(e) {
    const key = e.currentTarget.dataset.key;
    this.manualItems = this.manualItems.filter(i => i.key !== key);
    this.dispatchEvent(new CustomEvent('manualitemschange', {
      detail: { items: this.manualItems }
    }));
  }

  // tungnm37: clear manual items sau khi submit thành công
  @api clearManualItems() {
    this.manualItems = [];
    this.showAddForm = false;
    this.showValidationError = false;
    this.dispatchEvent(new CustomEvent('manualitemschange', {
      detail: { items: [] }
    }));
  }
}