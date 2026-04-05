import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import checkFollowStatus from '@salesforce/apex/FEC_FollowUpController.checkFollowStatus';
import followCase from '@salesforce/apex/FEC_FollowUpController.followCase';
import followCaseForUser from '@salesforce/apex/FEC_FollowUpController.followCaseForUser';
import searchUsers from '@salesforce/apex/FEC_FollowUpController.searchUsers';
import FEC_Error_Title from '@salesforce/label/c.FEC_Error_Title';
import FEC_Success_Title from '@salesforce/label/c.FEC_Success_Title';
import FEC_Warning_Title from '@salesforce/label/c.FEC_Warning_Title';
import FEC_MSG_FollowUp_Please_Select_User from '@salesforce/label/c.FEC_MSG_FollowUp_Please_Select_User';
import FEC_MSG_FollowUp_Add_User_To_Watcher_Success from '@salesforce/label/c.FEC_MSG_FollowUp_Add_User_To_Watcher_Success';
import FEC_MSG_FollowUp_Type_Updated_Success from '@salesforce/label/c.FEC_MSG_FollowUp_Type_Updated_Success';
import FEC_MSG_FollowUp_Case_Follow_Success from '@salesforce/label/c.FEC_MSG_FollowUp_Case_Follow_Success';
import FEC_MSG_FollowUp_Error_Detail from '@salesforce/label/c.FEC_MSG_FollowUp_Error_Detail';
import FEC_Follow_Up_Label from '@salesforce/label/c.FEC_Follow_Up_Label';
import FEC_Follow_Up_Until_Resolved from '@salesforce/label/c.FEC_Follow_Up_Until_Resolved';
import FEC_Follow_Up_Until_Unfollow from '@salesforce/label/c.FEC_Follow_Up_Until_Unfollow';
import FEC_Action_Select_User from '@salesforce/label/c.FEC_Action_Select_User';
import FEC_Action_Cancel from '@salesforce/label/c.FEC_Action_Cancel';
import FEC_Action_Confirm from '@salesforce/label/c.FEC_Action_Confirm';
import FEC_Label_Select_Follow_Up_User from '@salesforce/label/c.FEC_Label_Select_Follow_Up_User';
import FEC_Action_Close from '@salesforce/label/c.FEC_Action_Close';
import FEC_Label_User from '@salesforce/label/c.FEC_Label_User';
import FEC_Label_Clear_User_Selection from '@salesforce/label/c.FEC_Label_Clear_User_Selection';
import FEC_MSG_No_User_Found from '@salesforce/label/c.FEC_MSG_No_User_Found';
import FEC_Label_Follow_Up_Type from '@salesforce/label/c.FEC_Label_Follow_Up_Type';
import FEC_Select_Follow_Up_User_Type_Resolved from '@salesforce/label/c.FEC_Select_Follow_Up_User_Type_Resolved';
import FEC_Select_Follow_Up_User_Type_Unfollow from '@salesforce/label/c.FEC_Select_Follow_Up_User_Type_Unfollow';

export default class FecCaseFollowHeadlessAction extends LightningElement {
    @api recordId;

    showModal = false;
    showUserModal = false;
    isCaseOwner = false;

    userSearchTerm = '';
    userSearchResults = [];
    selectedUserId = '';
    selectedUserName = '';
    selectedFollowUpTypeInUserModal = 'UNTIL_RESOLVED';
    _userSearchTimeout;
    dropdownPanelVisible = false; // Đóng dropdown khi click ra ngoài
    showFollowTypeDropdown = false; // Đóng dropdown Follow-Up Type khi click ra ngoài

    isLoading = true;
    selectedFollowType = 'UNTIL_RESOLVED';
    alreadyFollowing = false;
    currentFollowType = '';
    caseStatus = ''; // Lưu status của Case

    // Custom Labels getter
    get customLabels() {
        return {
            labelFollowUp: FEC_Follow_Up_Label,
            untilResolved: FEC_Follow_Up_Until_Resolved,
            untilUnfollow: FEC_Follow_Up_Until_Unfollow,
            actionSelectUser: FEC_Action_Select_User,
            actionCancel: FEC_Action_Cancel,
            actionConfirm: FEC_Action_Confirm,
            labelSelectFollowUpUser: FEC_Label_Select_Follow_Up_User,
            actionClose: FEC_Action_Close,
            labelUser: FEC_Label_User,
            labelClearUserSelection: FEC_Label_Clear_User_Selection,
            msgNoUserFound: FEC_MSG_No_User_Found,
            labelFollowUpType: FEC_Label_Follow_Up_Type,
            selectedFollowUpTypeLabel: this.selectedFollowUpTypeLabel,
            labelCancel: FEC_Action_Cancel,
            labelConfirm: FEC_Action_Confirm
        };
    }

    // Headless Action - invoke() được gọi khi click button
    @api
    invoke() {
        this.showModal = true;
        this.isLoading = true;
        this.checkStatus();
    }

    handleSelectUser() {
        this.showModal = false;
        this.showUserModal = true;
        this.selectedFollowUpTypeInUserModal = this.selectedFollowType || 'UNTIL_RESOLVED';
        this.userSearchTerm = '';
        this.userSearchResults = [];
        this.selectedUserId = '';
        this.selectedUserName = '';
        this.dropdownPanelVisible = false;
        this.showFollowTypeDropdown = false;
    }

    handleCloseUserModal() {
        this.showUserModal = false;
        this.showFollowTypeDropdown = false;
    }

    get userSearchDisplayValue() {
        if (this.selectedUserId && this.selectedUserName) return this.selectedUserName;
        return this.userSearchTerm;
    }

    get showUserDropdown() {
        return this.dropdownPanelVisible && this.userSearchResults && this.userSearchResults.length > 0 && !this.selectedUserId;
    }

    get showNoUserResults() {
        return this.dropdownPanelVisible && this.userSearchTerm && this.userSearchTerm.length >= 2 && !this.selectedUserId &&
            this.userSearchResults && this.userSearchResults.length === 0;
    }

    /** Class cho combobox: thêm slds-is-open để dropdown hiển thị đúng theo SLDS */
    get userComboboxClass() {
        const base = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click user-combobox-container';
        return (this.showUserDropdown || this.showNoUserResults) ? base + ' slds-is-open' : base;
    }

    /** Class cho combobox Follow-Up Type (custom) */
    get followTypeComboboxClass() {
        const base = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click follow-type-combobox-container';
        return this.showFollowTypeDropdown ? base + ' slds-is-open' : base;
    }

    /** Label hiển thị cho Follow-Up Type đã chọn */
    get selectedFollowUpTypeLabel() {
        const opts = this.followUpTypeOptions;
        const found = opts.find(o => o.value === this.selectedFollowUpTypeInUserModal);
        return found ? found.label : 'Choose follow-up type';
    }

    connectedCallback() {
        this._boundHandleDocumentClick = this._handleDocumentClick.bind(this);
        document.addEventListener('click', this._boundHandleDocumentClick);
    }

    disconnectedCallback() {
        document.removeEventListener('click', this._boundHandleDocumentClick);
    }

    /** Đóng dropdown khi click ra ngoài vùng combobox (chỉ khi modal Select Follow-Up User đang mở).
     * Dùng composedPath() vì trong Shadow DOM event.target bị retarget nên contains(event.target) sai. */
    _handleDocumentClick(event) {
        if (!this.showUserModal) return;
        const path = event.composedPath();
        const userContainer = this.template.querySelector('.user-combobox-container');
        const followTypeContainer = this.template.querySelector('.follow-type-combobox-container');
        const clickInsideUser = userContainer && path.some(node => node !== document && node !== window && userContainer.contains(node));
        const clickInsideFollowType = followTypeContainer && path.some(node => node !== document && node !== window && followTypeContainer.contains(node));
        if (clickInsideUser || clickInsideFollowType) return;
        this.dropdownPanelVisible = false;
        this.showFollowTypeDropdown = false;
    }

    handleUserSearchFocus() {
        if (this.selectedUserId) {
            this.selectedUserId = '';
            this.selectedUserName = '';
            this.userSearchTerm = '';
        }
        // Khi focus vào ô trống: tải danh sách user có sẵn để hiển thị dropdown
        if (!this.userSearchTerm && !this.selectedUserId) {
            searchUsers({ searchTerm: '' })
                .then((results) => {
                    const list = (results || []).map((u) => {
                        const name = u.name || u.Name || '';
                        const email = u.email || u.Email || '';
                        return {
                            id: u.id || u.Id,
                            name,
                            email,
                            displayLabel: name
                        };
                    });
                    this.userSearchResults = list;
                    this.dropdownPanelVisible = true;
                })
                .catch(() => {
                    this.userSearchResults = [];
                });
        }
    }

    handleUserSearchInput(event) {
        // Hỗ trợ cả lightning-input (event.detail.value) và native input (event.target.value)
        this.userSearchTerm = event.detail?.value ?? event.target?.value ?? '';
        if (this.selectedUserId) {
            this.selectedUserId = '';
            this.selectedUserName = '';
        }
        if (this._userSearchTimeout) clearTimeout(this._userSearchTimeout);
        if (this.userSearchTerm.length === 0) {
            this.userSearchResults = [];
            return;
        }
        // Xóa kết quả cũ ngay để không hiển thị danh sách không liên quan (vd: Amit khi đã gõ "ducnm")
        this.userSearchResults = [];
        this._userSearchTimeout = setTimeout(() => {
            searchUsers({ searchTerm: this.userSearchTerm })
                .then((results) => {
                    const list = (results || []).map((u) => {
                        const name = u.name || u.Name || '';
                        const email = u.email || u.Email || '';
                        return {
                            id: u.id || u.Id,
                            name,
                            email,
                            displayLabel: name
                        };
                    });
                    this.userSearchResults = list;
                    this.dropdownPanelVisible = true;
                })
                .catch((err) => {
                    this.userSearchResults = [];
                    const errMsg = err.body?.message || err.message || '';
                    this.showToast(FEC_Error_Title, FEC_MSG_FollowUp_Error_Detail.replace('{0}', errMsg), 'error');
                });
        }, 300);
    }

    handleUserOptionSelect(event) {
        const id = event.currentTarget.dataset.userId;
        const name = event.currentTarget.dataset.userName || '';
        this.selectedUserId = id;
        this.selectedUserName = name;
        this.userSearchResults = [];
        this.dropdownPanelVisible = false;
    }

    /** Xóa user đã chọn (click icon X bên phải ô User) để chọn user khác */
    handleClearSelectedUser() {
        this.selectedUserId = '';
        this.selectedUserName = '';
        this.userSearchTerm = '';
    }

    handleClearSelectedUserKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleClearSelectedUser();
        }
    }

    handleFollowTypeToggle(event) {
        event.stopPropagation(); // Tránh click bubble lên document khiến _handleDocumentClick đóng dropdown ngay
        this.showFollowTypeDropdown = !this.showFollowTypeDropdown;
    }

    handleFollowTypeOptionSelect(event) {
        event.stopPropagation(); // Tránh click bubble lên wrapper (toggle) làm dropdown mở lại
        const value = event.currentTarget.dataset.value;
        this.selectedFollowUpTypeInUserModal = value;
        this.showFollowTypeDropdown = false;
    }

    /**
     * Confirm trong modal Select Follow-Up User: thêm user đã chọn vào danh sách follow-up và bảng Watcher Information.
     * Backend followCaseForUser sẽ: tạo/cập nhật FEC_Watcher__c, thêm vào Case Team, cập nhật FEC_Follow_Up_User__c và publish event để Watchers Information refresh.
     */
    handleConfirmUserModal() {
        if (!this.selectedUserId) {
            this.showToast(FEC_Warning_Title, FEC_MSG_FollowUp_Please_Select_User, 'warning');
            return;
        }
        this.isLoading = true;
        followCaseForUser({
            caseId: this.recordId,
            targetUserId: this.selectedUserId,
            followType: this.selectedFollowUpTypeInUserModal
        })
            .then(() => {
                this.isLoading = false;
                getRecordNotifyChange([{ recordId: this.recordId }]);
                this.showToast(FEC_Success_Title, FEC_MSG_FollowUp_Add_User_To_Watcher_Success, 'success');
                this.showUserModal = false;
                this.selectedUserId = '';
                this.selectedUserName = '';
                this.userSearchTerm = '';
                this.userSearchResults = [];
            })
            .catch(error => {
                this.isLoading = false;
                const errMsg = error.body?.message || error.message || '';
                this.showToast(FEC_Error_Title, FEC_MSG_FollowUp_Error_Detail.replace('{0}', errMsg), 'error');
            });
    }

    // Chỉ popup Select Follow-Up User — nhãn riêng; modal Follow-up chính dùng FEC_Follow_Up_Until_*
    get followUpTypeOptions() {
        return [
            { label: FEC_Follow_Up_Until_Resolved, value: 'UNTIL_RESOLVED' },
            { label: FEC_Follow_Up_Until_Unfollow, value: 'UNTIL_UNFOLLOW' }
        ];
    }

    checkStatus() {
        if (!this.recordId) {
            this.isLoading = false;
            return;
        }
        checkFollowStatus({ caseId: this.recordId })
            .then(result => {
                this.alreadyFollowing = result.isFollowing;
                this.currentFollowType = result.followType || '';
                this.caseStatus = result.status || '';
                this.isCaseOwner = result.isOwner === true;
                
                // Pre-select followType:
                // 1. Nếu Case đã Resolved → chỉ cho phép UNTIL_UNFOLLOW
                // 2. Nếu đang follow (Active = true) → dùng followType hiện tại
                // 3. Nếu không đang follow nhưng có followType (re-follow) → dùng followType cũ
                // 4. Nếu không có → default = UNTIL_RESOLVED
                if (this.isCaseResolved) {
                    this.selectedFollowType = 'UNTIL_UNFOLLOW';
                } else if (result.followType) {
                    this.selectedFollowType = result.followType;
                } else {
                    this.selectedFollowType = 'UNTIL_RESOLVED';
                }
                
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                const errMsg = error.body?.message || error.message || '';
                this.showToast(FEC_Error_Title, FEC_MSG_FollowUp_Error_Detail.replace('{0}', errMsg), 'error');
                this.showModal = false;
            });
    }

    // Kiểm tra Case đã Resolved chưa (status bắt đầu bằng "Resolved")
    get isCaseResolved() {
        return this.caseStatus && this.caseStatus.startsWith('Resolved');
    }

    // Ẩn option "Until Case Resolved" nếu Case đã Resolved
    get showUntilResolvedOption() {
        return !this.isCaseResolved;
    }

    get isUntilResolvedChecked() {
        return this.selectedFollowType === 'UNTIL_RESOLVED';
    }

    get isUntilUnfollowChecked() {
        return this.selectedFollowType === 'UNTIL_UNFOLLOW';
    }

    // Disable option đang chọn nếu user đã follow
    get isUntilResolvedDisabled() {
        return this.alreadyFollowing && this.currentFollowType === 'UNTIL_RESOLVED';
    }

    get isUntilUnfollowDisabled() {
        return this.alreadyFollowing && this.currentFollowType === 'UNTIL_UNFOLLOW';
    }

    // Class cho radio buttons (thêm disabled style nếu cần)
    get resolvedRadioClass() {
        let baseClass = 'slds-radio slds-m-bottom_x-small';
        if (this.isUntilResolvedDisabled) {
            baseClass += ' slds-is-disabled';
        }
        return baseClass;
    }

    get unfollowRadioClass() {
        let baseClass = 'slds-radio';
        if (this.isUntilUnfollowDisabled) {
            baseClass += ' slds-is-disabled';
        }
        return baseClass;
    }

    handleSelectResolved() {
        if (!this.isUntilResolvedDisabled) {
            this.selectedFollowType = 'UNTIL_RESOLVED';
        }
    }

    handleSelectUnfollow() {
        if (!this.isUntilUnfollowDisabled) {
            this.selectedFollowType = 'UNTIL_UNFOLLOW';
        }
    }

    handleCancel() {
        this.showModal = false;
    }

    handleConfirm() {
        this.isLoading = true;
        followCase({ 
            caseId: this.recordId, 
            followType: this.selectedFollowType 
        })
            .then(() => {
                this.isLoading = false;
                
                getRecordNotifyChange([{ recordId: this.recordId }]);

                const message = this.alreadyFollowing 
                    ? FEC_MSG_FollowUp_Type_Updated_Success 
                    : FEC_MSG_FollowUp_Case_Follow_Success;
                this.showToast(FEC_Success_Title, message, 'success');
                
                this.showModal = false;
            })
            .catch(error => {
                this.isLoading = false;
                const errMsg = error.body?.message || error.message || '';
                this.showToast(FEC_Error_Title, FEC_MSG_FollowUp_Error_Detail.replace('{0}', errMsg), 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        }));
    }
}