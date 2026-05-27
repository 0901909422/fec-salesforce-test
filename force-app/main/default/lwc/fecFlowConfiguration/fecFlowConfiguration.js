import { LightningElement, api, track, wire } from 'lwc';
import createCaseStage from '@salesforce/apex/FEC_MasterDataSettingController.createCaseStage';
import getCaseStageOptionsByBP from '@salesforce/apex/FEC_MasterDataSettingController.getCaseStageOptionsByBP';
import updateCaseStage from '@salesforce/apex/FEC_MasterDataSettingController.updateCaseStage';
import getCaseStageDetail from '@salesforce/apex/FEC_MasterDataSettingController.getCaseStageDetail';
import getUserGroupOptions from '@salesforce/apex/FEC_MasterDataSettingController.getUserGroupOptions';
import deleteCaseStage from '@salesforce/apex/FEC_MasterDataSettingController.deleteCaseStage';
import getStageScreensByStage from '@salesforce/apex/FEC_MasterDataSettingController.getStageScreensByStage';
import createStageScreen from '@salesforce/apex/FEC_MasterDataSettingController.createStageScreen';
import deleteStageScreen from '@salesforce/apex/FEC_MasterDataSettingController.deleteStageScreen';
import toggleStageScreenActive from '@salesforce/apex/FEC_MasterDataSettingController.toggleStageScreenActive';
import getActionButtonOptions from '@salesforce/apex/FEC_MasterDataSettingController.getActionButtonOptions';
import { refreshApex } from '@salesforce/apex';
import { showLog } from 'c/fecMDMUtils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LABEL_FLOW_STAGES_TITLE from '@salesforce/label/c.FEC_Flow_Stages_Title';
import LABEL_ADD_STAGE from '@salesforce/label/c.FEC_Add_Stage';
import LABEL_STAGE_PREFIX from '@salesforce/label/c.FEC_Label_Stage';
import LABEL_ALT_EDIT from '@salesforce/label/c.FEC_Alt_Edit';
import LABEL_ALT_REMOVE from '@salesforce/label/c.FEC_Alt_Remove';
import { EVENT_HANDLE_STAGE_CLICK, EVENT_SAVE_CONFIG, CSS_STAGE_BOX, PREFIX_BP, VARIANT_SUCCESS, VARIANT_ERROR } from 'c/fecConstants';

export default class FecFlowConfiguration extends LightningElement {
    @api nodeData;
    @track stages = [];
    @track selectedStageIndex = 0;
    @track refreshCounter = 0; 
    @track wiredStageResult;
    
    @track showEditModal = false;
    @track editingStageId = '';
    @track editingStageName = '';
    @track editingNameVN = '';
    @track editingAlias = '';
    @track editingPosOrder = 0;
    @track editingActive = false;
    @track editingDefaultStage = false;
    @track editingEndStage = false;
    @track editingStatusName = '';
    @track editingUserGroup = [];
    @track userGroupOptions = [];

    // Stage Screen tracked properties
    @track stageScreens = [];
    @track isLoadingScreens = false;
    @track showAddScreenModal = false;
    @track showStageScreenSection = false;
    @track actionButtonOptions = [];
    @track newScreenActionButtonId = '';
    @track newScreenUserGroup = [];
    @track newScreenActive = true;

    connectedCallback() {
        this.selectedStageIndex = 0;
    }

    // =========================================================
    // FIX LỖI UI: Ẩn Flow Stage nếu là Node Product Type
    // =========================================================
    get shouldShowFlow() {
        if (this.nodeData && this.nodeData.name && this.nodeData.name.startsWith('PT')) {
            return false; // Trả về false nếu là Product Type -> HTML sẽ ẩn khối Flow đi
        }
        return true;
    }

    get isBusinessProcess() {
        return this.nodeData &&
            this.nodeData.name &&
            this.nodeData.name.startsWith(PREFIX_BP);
    }

    processStageOptions(data) {
        if (!data || data.length === 0) return [];

        const rawStages = data.filter(item => item.value !== '');

        const stages = rawStages.map((stage, index) => ({
            id: stage.value, 
            name: stage.label,
            label: stage.label,
            order: index + 1, 
            posOrder: stage.posOrder ? parseInt(stage.posOrder, 10) : 0,
            properties: [],
            isActive: index === 0,
            defaultStage: stage.defaultStage === 'true',
            endStage: stage.endStage === 'true'
        }));

        // Auto-mark last stage as End Stage if none is marked
        if (stages.length > 1 && !stages.some(s => s.endStage)) {
            stages[stages.length - 1].endStage = true;
        }

        return stages;
    }

    get actualBPId() {
        if (this.nodeData && this.nodeData.name) {
            const parts = this.nodeData.name.split('_');
            if (this.nodeData.name.startsWith('PT')) return null;
            return parts[2]; 
        }
        return null;
    }

    @wire(getCaseStageOptionsByBP, { businessProcessId: '$actualBPId', refreshTrigger: '$refreshCounter' })
    wiredGetStageOptions(result) {
        this.wiredStageResult = result;
        const { error, data } = result;

        if (data) {
            this.stages = this.processStageOptions(data);

            if (this.stages.length > 0) {
                this.selectedStageIndex = 0;
                this.handleStageClick({
                    currentTarget: { dataset: { stageId: this.stages[0].id } }
                });
                this.stages[0].isActive = true;
            } else {
                this.selectedStageIndex = -1;
            }

        } else if (error) {
            console.error('Error fetching Flow Stage options:', error);
            this.stages = [];
            this.selectedStageIndex = -1;
        }
    }

    get currentStage() {
        return this.stages[this.selectedStageIndex] || {};
    }

    get stagesList() {
        return this.stages.map((stage, index) => {
            const isSelected = index === this.selectedStageIndex;
            let cssClass = CSS_STAGE_BOX;
            if (stage.defaultStage) {
                cssClass += ' stage-default';
            }
            if (stage.endStage) {
                cssClass += ' stage-end';
            }
            if (isSelected) {
                cssClass += ' active';
            }
            return {
                ...stage,
                isSelected,
                isLast: index === this.stages.length - 1,
                cssClass
            };
        });
    }

    handleStageClick(event) {
        const stageId = event.currentTarget.dataset.stageId;
        this.selectedStageIndex = this.stages.findIndex(s => s.id === stageId);
        console.log('selectedStageIndex:', this.selectedStageIndex);
        this.dispatchEvent(new CustomEvent(EVENT_HANDLE_STAGE_CLICK, { detail: stageId }));
        // Reset stage screen section when switching stages
        this.showStageScreenSection = false;
        this.stageScreens = [];
    }

    handleToggleStageScreens(event) {
        event.stopPropagation();
        const stageId = event.currentTarget.dataset.stageId;
        // If clicking same stage, toggle. If different stage, open for new stage.
        if (this.showStageScreenSection && this.selectedStageId === stageId) {
            this.showStageScreenSection = false;
        } else {
            // Select the stage first
            this.selectedStageIndex = this.stages.findIndex(s => s.id === stageId);
            this.dispatchEvent(new CustomEvent(EVENT_HANDLE_STAGE_CLICK, { detail: stageId }));
            this.showStageScreenSection = true;
            this.loadStageScreens(stageId);
        }
    }

    async loadStageScreens(stageId) {
        if (!stageId) return;
        this.isLoadingScreens = true;
        try {
            const data = await getStageScreensByStage({ stageId });
            this.stageScreens = (data || []).map(screen => ({
                ...screen,
                active: screen.active === 'true'
            }));
        } catch (error) {
            console.error('Error loading stage screens:', error);
            this.stageScreens = [];
            this.showToast('Error', 'Failed to load stage screens: ' + (error.body?.message || error.message), VARIANT_ERROR);
        } finally {
            this.isLoadingScreens = false;
        }
    }

    get hasStageScreens() {
        return this.stageScreens && this.stageScreens.length > 0;
    }

    get selectedStageId() {
        const stage = this.stages[this.selectedStageIndex];
        return stage ? stage.id : null;
    }

    get showEmptyScreenMessage() {
        return !this.isLoadingScreens && !this.hasStageScreens;
    }

    // =========================================================
    // Stage Screen CRUD Handlers
    // =========================================================

    async handleAddScreen() {
        try {
            const [buttonOpts, groupOpts] = await Promise.all([
                getActionButtonOptions(),
                getUserGroupOptions()
            ]);
            this.actionButtonOptions = buttonOpts.map(opt => ({
                label: opt.label,
                value: opt.value
            }));
            this.userGroupOptions = groupOpts.map(opt => ({
                label: opt.label,
                value: opt.value
            }));
            this.newScreenActionButtonId = '';
            this.newScreenUserGroup = [];
            this.newScreenActive = true;
            this.showAddScreenModal = true;
        } catch (error) {
            console.error('Error loading options:', error);
            this.showToast('Error', 'Failed to load options: ' + (error.body?.message || error.message), VARIANT_ERROR);
        }
    }

    handleCancelAddScreen() {
        this.showAddScreenModal = false;
        this.newScreenActionButtonId = '';
        this.newScreenUserGroup = [];
        this.newScreenActive = true;
    }

    handleChangeNewScreenActionButton(event) {
        this.newScreenActionButtonId = event.detail.value;
    }

    handleChangeNewScreenUserGroup(event) {
        this.newScreenUserGroup = event.detail.value;
    }

    handleChangeNewScreenActive(event) {
        this.newScreenActive = event.target.checked;
    }

    async handleSaveScreen() {
        if (!this.newScreenActionButtonId) {
            this.showToast('Error', 'Please select an Action Button', VARIANT_ERROR);
            return;
        }

        const stageId = this.selectedStageId;
        if (!stageId) return;

        try {
            await createStageScreen({
                stageId: stageId,
                actionButtonId: this.newScreenActionButtonId,
                userGroup: this.newScreenUserGroup.join(';'),
                active: this.newScreenActive
            });
            this.showAddScreenModal = false;
            this.showToast('Success', 'Action Button added successfully', VARIANT_SUCCESS);
            await this.loadStageScreens(stageId);
        } catch (error) {
            console.error('Error creating stage screen:', error);
            this.showToast('Error', 'Failed to add Action Button: ' + (error.body?.message || error.message), VARIANT_ERROR);
        }
    }

    async handleDeleteScreen(event) {
        const screenId = event.currentTarget.dataset.screenId;
        if (!screenId) return;

        // eslint-disable-next-line no-restricted-globals
        if (!confirm('Are you sure you want to delete this Action Button from the stage?')) {
            return;
        }

        try {
            await deleteStageScreen({ stageScreenId: screenId });
            this.showToast('Success', 'Action Button removed successfully', VARIANT_SUCCESS);
            await this.loadStageScreens(this.selectedStageId);
        } catch (error) {
            console.error('Error deleting stage screen:', error);
            this.showToast('Error', 'Failed to delete: ' + (error.body?.message || error.message), VARIANT_ERROR);
        }
    }

    async handleToggleScreenActive(event) {
        const screenId = event.currentTarget.dataset.screenId;
        const newActive = event.target.checked;
        if (!screenId) return;

        try {
            await toggleStageScreenActive({ stageScreenId: screenId, active: newActive });
            this.stageScreens = this.stageScreens.map(screen => {
                return screen.id === screenId ? { ...screen, active: newActive } : screen;
            });
        } catch (error) {
            console.error('Error toggling active:', error);
            this.showToast('Error', 'Failed to update active status: ' + (error.body?.message || error.message), VARIANT_ERROR);
            // Revert by reloading
            await this.loadStageScreens(this.selectedStageId);
        }
    }

    async handleAddStage() {
        try {
            const businessProcessId = this.nodeData?.idType;
            const businessProcessName = this.nodeData?.label || this.nodeData?.name || '';
            const isFirstStage = this.stages.length === 0;

            if (isFirstStage) {
                // First time: create Begin (Default, order 0) + End (order 999)
                const beginName = `${businessProcessName}-Begin`;
                const endName = `${businessProcessName}-End`;

                const beginParams = {
                    name: beginName,
                    code: `${beginName}-${Date.now()}`,
                    businessProcessId: businessProcessId,
                    nameVN: beginName,
                    status: true,
                    alias: beginName,
                    posOrder: 0,
                    defaultStage: true,
                    active: true,
                    endStage: false,
                    statusName: 'Open'
                };

                const endParams = {
                    name: endName,
                    code: `${endName}-${Date.now()}`,
                    businessProcessId: businessProcessId,
                    nameVN: endName,
                    status: true,
                    alias: endName,
                    posOrder: 999,
                    defaultStage: false,
                    active: true,
                    endStage: true,
                    statusName: 'END'
                };

                showLog('[handleAddStage] Creating Begin + End stages');
                await createCaseStage(beginParams);
                await createCaseStage(endParams);

                this.showToast('Success', 'Begin and End stages created', VARIANT_SUCCESS);
            } else {
                // Subsequent stages: insert between Begin and End
                // Find max posOrder excluding End stages
                const normalStages = this.stages.filter(s => !s.endStage);
                const maxOrder = normalStages.length > 0
                    ? Math.max(...normalStages.map(s => s.posOrder || s.order))
                    : 0;
                const newOrder = maxOrder + 1;
                const stageName = LABEL_STAGE_PREFIX + ' ' + newOrder;
                const fullName = `${businessProcessName}-${stageName}`;

                const params = {
                    name: fullName,
                    code: `${fullName}-${Date.now()}`,
                    businessProcessId: businessProcessId,
                    nameVN: fullName,
                    status: true,
                    alias: fullName,
                    posOrder: newOrder,
                    defaultStage: false,
                    active: true,
                    endStage: false
                };

                showLog('[handleAddStage] Creating stage with params:', params);
                await createCaseStage(params);
                this.showToast('Success', 'Stage added successfully', VARIANT_SUCCESS);
            }

            this.refreshCounter++;
            if (this.wiredStageResult) {
                refreshApex(this.wiredStageResult);
            }
            this.dispatchEvent(new CustomEvent('refreshall', { bubbles: true, composed: true }));

        } catch (error) {
            showLog('Error creating stage:', error);
            this.showToast('Error', 'Failed to add stage: ' + (error.body?.message || error.message), VARIANT_ERROR);
        }
    }

    async handleRemoveStage(event) {
        event.stopPropagation();
        
        if (!this.isBusinessProcess) {
            this.showToast('Info', 'Stages can only be deleted at Business Process level', 'info');
            return;
        }
        
        const stageId = event.currentTarget.dataset.stageId;
        const stage = this.stages.find(s => s.id === stageId);
        
        if (!stage) return;

        if (!confirm(`Are you sure you want to delete stage "${stage.label}"?`)) {
            return;
        }

        try {
            await deleteCaseStage({ stageId });
            this.stages = this.stages.filter(s => s.id !== stageId);
            
            if (this.selectedStageIndex >= this.stages.length) {
                this.selectedStageIndex = Math.max(0, this.stages.length - 1);
            }
            
            this.showToast('Success', `Stage "${stage.label}" deleted successfully`, VARIANT_SUCCESS);

            this.refreshCounter++;
            if (this.wiredStageResult) {
                refreshApex(this.wiredStageResult);
            }

            // =========================================================
            // FIX LỖI DATA KHÔNG LOAD: Ép load lại toàn bộ hệ thống cây
            // =========================================================
            this.dispatchEvent(new CustomEvent('refreshall', { bubbles: true, composed: true }));

        } catch (error) {
            showLog('Error deleting stage:', error);
            this.showToast('Error', 'Failed to delete stage: ' + error.body?.message, VARIANT_ERROR);
        }
    }

    async handleEditStageName(event) {
        event.stopPropagation();
        
        if (!this.isBusinessProcess) {
            this.showToast('Info', 'Stage names can only be edited at Business Process level', 'info');
            return;
        }
        
        const stageId = event.currentTarget.dataset.stageId;
        try {
            const [detail, groupOpts] = await Promise.all([
                getCaseStageDetail({ stageId }),
                getUserGroupOptions()
            ]);

            this.editingStageId = stageId;
            this.editingStageName = detail.name || '';
            this.editingNameVN = detail.nameVN || '';
            this.editingAlias = detail.alias || '';
            this.editingPosOrder = detail.posOrder ? parseInt(detail.posOrder, 10) : 0;
            this.editingActive = detail.active === 'true';
            this.editingDefaultStage = detail.defaultStage === 'true';
            this.editingEndStage = detail.endStage === 'true';
            this.editingStatusName = detail.statusName || '';

            this.userGroupOptions = groupOpts.map(opt => ({
                label: opt.label,
                value: opt.value
            }));

            const userGroupValue = detail.userGroup || '';
            this.editingUserGroup = userGroupValue ? userGroupValue.split(';') : [];

            this.showEditModal = true;
        } catch (error) {
            showLog('Error loading stage detail:', error);
            this.showToast('Error', 'Failed to load stage detail: ' + (error.body?.message || error.message), VARIANT_ERROR);
        }
    }

    handleCancelEdit() {
        this.showEditModal = false;
        this.editingStageId = '';
        this.editingStageName = '';
        this.editingNameVN = '';
        this.editingAlias = '';
        this.editingPosOrder = 0;
        this.editingActive = false;
        this.editingDefaultStage = false;
        this.editingEndStage = false;
        this.editingStatusName = '';
        this.editingUserGroup = [];
    }

    handleChangeName(event) {
        this.editingStageName = event.target.value;
    }

    handleChangeNameVN(event) {
        this.editingNameVN = event.target.value;
    }

    handleChangeAlias(event) {
        this.editingAlias = event.target.value;
    }

    handleChangePosOrder(event) {
        const raw = event.target.value;
        if (raw === '' || raw === null) {
            this.editingPosOrder = '';
            return;
        }
        const parsed = parseInt(raw, 10);
        if (isNaN(parsed) || parsed < 1 || parsed > 99) {
            return; // Let HTML validation handle the message
        }
        this.editingPosOrder = parsed;
    }

    /**
     * Chặn cứng input Pos Order: chỉ cho nhập số, tối đa 2 ký tự
     */
    handlePosOrderKeyDown(event) {
        const allowed = ['Backspace', 'Delete', 'Tab', 'Escape', 'Enter', 'ArrowLeft', 'ArrowRight', 'Home', 'End'];
        if (allowed.includes(event.key)) return;
        if ((event.ctrlKey || event.metaKey) && ['a', 'c', 'v', 'x'].includes(event.key)) return;
        if (!/^[0-9]$/.test(event.key)) {
            event.preventDefault();
            return;
        }
        const input = event.target;
        const currentValue = input.value || '';
        const selectionLength = (input.selectionEnd || 0) - (input.selectionStart || 0);
        if (currentValue.length >= 2 && selectionLength === 0) {
            event.preventDefault();
        }
    }

    /**
     * Fallback: strip ký tự không phải số (chặn paste chữ, mobile input)
     */
    handlePosOrderInput(event) {
        const raw = event.target.value;
        const cleaned = raw.replace(/[^0-9]/g, '').slice(0, 2);
        if (raw !== cleaned) {
            event.target.value = cleaned;
            this.editingPosOrder = cleaned;
        }
    }

    handleChangeActive(event) {
        this.editingActive = event.target.checked;
    }

    /**
     * Default Stage checkbox chỉ hiển thị khi Pos Order của stage đang edit
     * là nhỏ nhất trong tất cả stages (TC.CSUI.14)
     */
    get showDefaultStageCheckbox() {
        if (!this.editingStageId || this.stages.length === 0) return false;
        const currentPosOrder = parseInt(this.editingPosOrder, 10) || 0;
        const otherStages = this.stages.filter(s => s.id !== this.editingStageId);
        if (otherStages.length === 0) return true;
        const minOtherOrder = Math.min(...otherStages.map(s => s.posOrder || 0));
        return currentPosOrder <= minOtherOrder;
    }

    /**
     * Disable Pos Order cho Default Stage (luôn 0) và End Stage (luôn 999)
     */
    get isOrderDisabled() {
        return this.editingDefaultStage || this.editingEndStage;
    }

    /**
     * Ẩn Pos Order field cho Default Stage và End Stage
     */
    get showPosOrderField() {
        return !this.editingDefaultStage && !this.editingEndStage;
    }

    handleChangeDefaultStage(event) {
        this.editingDefaultStage = event.target.checked;
    }

    handleChangeEndStage(event) {
        this.editingEndStage = event.target.checked;
    }

    handleChangeStatusName(event) {
        this.editingStatusName = event.target.value;
    }

    handleChangeUserGroup(event) {
        this.editingUserGroup = event.detail.value;
    }

    handleStageNameChange(event) {
        this.editingStageName = event.target.value;
    }

    async handleSaveStage() {
        if (!this.editingStageName.trim()) {
            this.showToast('Error', 'Stage name cannot be empty', VARIANT_ERROR);
            return;
        }

        // Validate Pos Order: 1-99 cho stage thường (skip Default/End)
        if (!this.editingDefaultStage && !this.editingEndStage) {
            const posOrder = this.editingPosOrder === '' ? 1 : parseInt(this.editingPosOrder, 10);
            if (isNaN(posOrder) || posOrder < 1 || posOrder > 99) {
                this.showToast('Error', 'Pos Order must be between 1 and 99', VARIANT_ERROR);
                return;
            }
        }

        // Validate: cannot uncheck sole default stage
        if (!this.editingDefaultStage) {
            const defaultCount = this.stages.filter(s => s.defaultStage && s.id !== this.editingStageId).length;
            if (defaultCount === 0) {
                this.showToast('Warning', 'Phải có ít nhất một Default Stage', 'warning');
                this.editingDefaultStage = true;
                return;
            }
        }

        // Auto-uncheck Default Stage nếu Pos Order không phải nhỏ nhất (TC.CSUI.14)
        if (this.editingDefaultStage && !this.showDefaultStageCheckbox) {
            this.editingDefaultStage = false;
        }

        // Default Stage luôn giữ posOrder = 0
        if (this.editingDefaultStage) {
            this.editingPosOrder = 0;
        }

        // End Stage luôn giữ posOrder = 999
        if (this.editingEndStage) {
            this.editingPosOrder = 999;
        }

        try {
            await updateCaseStage({
                stageId: this.editingStageId,
                name: this.editingStageName,
                nameVN: this.editingNameVN,
                alias: this.editingAlias,
                status: this.editingActive,
                active: this.editingActive,
                defaultStage: this.editingDefaultStage,
                natureOfCasesId: '',
                userGroup: this.editingUserGroup.join(';'),
                posOrder: parseInt(this.editingPosOrder, 10) || 0,
                statusName: this.editingStatusName,
                endStage: this.editingEndStage
            });

            const index = this.stages.findIndex(s => s.id === this.editingStageId);
            if (index !== -1) {
                const updatedStages = [...this.stages];
                updatedStages[index] = {
                    ...updatedStages[index],
                    name: this.editingStageName,
                    label: this.editingStageName
                };
                this.stages = updatedStages;
            }

            this.showEditModal = false;
            this.showToast('Success', 'Stage updated successfully', VARIANT_SUCCESS);

            this.refreshCounter++;
            if (this.wiredStageResult) {
                refreshApex(this.wiredStageResult);
            }

            this.dispatchEvent(new CustomEvent('refreshall', { bubbles: true, composed: true }));
            // Also dispatch on window for cross-component communication (Decision Engine)
            window.dispatchEvent(new CustomEvent('refreshall'));

        } catch (error) {
            showLog('Error updating stage:', error);
            this.showToast('Error', 'Failed to update stage: ' + (error.body?.message || error.message), VARIANT_ERROR);
        }
    }

    // Keep for backward compatibility
    async handleSaveStageName() {
        return this.handleSaveStage();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant,
            })
        );
    }

    handleSaveConfiguration() {
        const configData = {
            nodeId: this.nodeData?.id,
            nodeType: this.nodeData?.type,
            stages: this.stages
        };

        this.dispatchEvent(new CustomEvent(EVENT_SAVE_CONFIG, { detail: configData }));
    }

    labelFlowTitle = LABEL_FLOW_STAGES_TITLE;
    labelAddStage = LABEL_ADD_STAGE;
    labelStagePrefix = LABEL_STAGE_PREFIX;
    labelAltEdit = LABEL_ALT_EDIT;
    labelAltRemove = LABEL_ALT_REMOVE;
}