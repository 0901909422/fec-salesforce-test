import { LightningElement, api, track, wire } from 'lwc';
import createCaseStage from '@salesforce/apex/FEC_MasterDataSettingController.createCaseStage';
import getCaseStageOptionsByBP from '@salesforce/apex/FEC_MasterDataSettingController.getCaseStageOptionsByBP';
import updateCaseStageName from '@salesforce/apex/FEC_MasterDataSettingController.updateCaseStageName';
import deleteCaseStage from '@salesforce/apex/FEC_MasterDataSettingController.deleteCaseStage';
import { refreshApex } from '@salesforce/apex';
import { showLog } from 'c/fecMDMUtils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LABEL_FLOW_STAGES_TITLE from '@salesforce/label/c.FEC_Flow_Stages_Title';
import LABEL_ADD_STAGE from '@salesforce/label/c.FEC_Add_Stage';
import LABEL_STAGE_PREFIX from '@salesforce/label/c.FEC_Label_Stage';
import LABEL_ALT_EDIT from '@salesforce/label/c.FEC_Alt_Edit';
import LABEL_ALT_REMOVE from '@salesforce/label/c.FEC_Alt_Remove';
import LABEL_PROMPT_ENTER_NEW_STAGE_NAME from '@salesforce/label/c.FEC_Prompt_Enter_New_Stage_Name';
import { EVENT_HANDLE_STAGE_CLICK, EVENT_SAVE_CONFIG, CSS_STAGE_BOX, CSS_STAGE_BOX_ACTIVE, PREFIX_BP, VARIANT_SUCCESS, VARIANT_ERROR } from 'c/fecConstants';

export default class FecFlowConfiguration extends LightningElement {
    @api nodeData;
    @track stages = [];
    @track selectedStageIndex = 0;
    @track refreshCounter = 0; 
    @track wiredStageResult;
    
    @track showEditModal = false;
    @track editingStageId = '';
    @track editingStageName = '';

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

        return rawStages.map((stage, index) => ({
            id: stage.value, 
            name: stage.label,
            label: stage.label,
            order: index + 1, 
            properties: [],
            isActive: index === 0
        }));
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
        return this.stages.map((stage, index) => ({
            ...stage,
            isSelected: index === this.selectedStageIndex,
            isLast: index === this.stages.length - 1,
            cssClass: index === this.selectedStageIndex ? CSS_STAGE_BOX_ACTIVE : CSS_STAGE_BOX
        }));
    }

    handleStageClick(event) {
        const stageId = event.currentTarget.dataset.stageId;
        this.selectedStageIndex = this.stages.findIndex(s => s.id === stageId);
        console.log('selectedStageIndex:', this.selectedStageIndex);
        this.dispatchEvent(new CustomEvent(EVENT_HANDLE_STAGE_CLICK, { detail: stageId }));
    }

    async handleAddStage() {
        try {
            const newStageNumber = this.stages.length + 1;
            const stageName = LABEL_STAGE_PREFIX + ' ' + newStageNumber;
            const businessProcessId = this.nodeData?.idType;

            const businessProcessName = this.nodeData?.label || this.nodeData?.name || '';
            const fullName = `${businessProcessName}-${stageName}`;
            const code = `${businessProcessName}-${stageName}`;

            const params = {
                name: fullName,
                code: code,
                businessProcessId: businessProcessId,
                nameVN: fullName,
                status: true,
                alias: fullName,
                posOrder: newStageNumber
            };

            showLog('[handleAddStage] Creating stage with params:', params);
            const newStageId = await createCaseStage(params);
            showLog('[handleAddStage] Stage created with ID:', newStageId);

            const newStage = {
                id: newStageId,
                name: fullName,
                label: stageName,
                order: newStageNumber,
                properties: [],
                isActive: false
            };
            this.stages = [...this.stages, newStage];

            showLog('[handleAddStage] New stage added to local state. Total stages:', this.stages.length);
            this.showToast('Success', 'Stage added successfully', VARIANT_SUCCESS);

            this.refreshCounter++;
            if (this.wiredStageResult) {
                refreshApex(this.wiredStageResult);
            }
            
            // Báo lên Cha load lại toàn bộ cây
            this.dispatchEvent(new CustomEvent('refreshall', { bubbles: true, composed: true }));

        } catch (error) {
            showLog('Error creating stage:', error);
            this.showToast('Error', 'Failed to add stage: ' + error.body?.message, VARIANT_ERROR);
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

    handleEditStageName(event) {
        event.stopPropagation();
        
        if (!this.isBusinessProcess) {
            this.showToast('Info', 'Stage names can only be edited at Business Process level', 'info');
            return;
        }
        
        const stageId = event.currentTarget.dataset.stageId;
        const stage = this.stages.find(s => s.id === stageId);
        if (stage) {
            this.editingStageId = stageId;
            this.editingStageName = stage.name;
            this.showEditModal = true;
        }
    }

    handleCancelEdit() {
        this.showEditModal = false;
        this.editingStageId = '';
        this.editingStageName = '';
    }

    handleStageNameChange(event) {
        this.editingStageName = event.target.value;
    }

    async handleSaveStageName() {
        if (!this.editingStageName.trim()) return;

        try {
            await updateCaseStageName({ 
                stageId: this.editingStageId, 
                newName: this.editingStageName 
            });

            const index = this.stages.findIndex(s => s.id === this.editingStageId);
            if (index !== -1) {
                const updatedStages = [...this.stages];
                updatedStages[index].name = this.editingStageName;
                updatedStages[index].label = this.editingStageName;
                this.stages = updatedStages;
            }

            this.showEditModal = false;
            this.showToast('Success', 'Stage updated successfully', VARIANT_SUCCESS);

            this.refreshCounter++;
            if (this.wiredStageResult) {
                refreshApex(this.wiredStageResult);
            }

            // Cập nhật tên cũng cần load lại cây
            this.dispatchEvent(new CustomEvent('refreshall', { bubbles: true, composed: true }));

        } catch (error) {
            showLog('Error updating stage:', error);
            this.showToast('Error', 'Failed to update stage: ' + error.body?.message, VARIANT_ERROR);
        }
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