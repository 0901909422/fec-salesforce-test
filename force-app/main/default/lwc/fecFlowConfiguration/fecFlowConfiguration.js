import { LightningElement, api, track, wire } from 'lwc';
import createCaseStage from '@salesforce/apex/FEC_MasterDataSettingController.createCaseStage';
import getCaseStageOptionsByBP from '@salesforce/apex/FEC_MasterDataSettingController.getCaseStageOptionsByBP';
import updateCaseStageName from '@salesforce/apex/FEC_MasterDataSettingController.updateCaseStageName';
import deleteCaseStage from '@salesforce/apex/FEC_MasterDataSettingController.deleteCaseStage';
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
    @track refreshCounter = 0; // Force wire adapter refresh
    
    // Modal states
    @track showEditModal = false;
    @track editingStageId = '';
    @track editingStageName = '';

    connectedCallback() {
        this.selectedStageIndex = 0;

    }

    // Thêm getter này vào trong class FecFlowConfiguration
    get isBusinessProcess() {
        // Kiểm tra an toàn xem nodeData và nodeData.name có tồn tại không
        return this.nodeData &&
            this.nodeData.name &&
            this.nodeData.name.startsWith(PREFIX_BP);
    }

    // Hàm chuyển đổi dữ liệu từ Apex sang định dạng Stage của Component
    processStageOptions(data) {
        if (!data || data.length === 0) return [];

        // Lọc bỏ tùy chọn "-- None --" mà Apex đã thêm (nếu có)
        const rawStages = data.filter(item => item.value !== '');

        // Chuyển đổi (map) sang định dạng stage cần thiết: { id, name, label, order, properties, isActive }
        return rawStages.map((stage, index) => ({
            id: stage.value, // ID của bản ghi FEC_Case_Stage__c
            name: stage.label,
            label: stage.label,
            order: index + 1, // Thứ tự dựa trên vị trí trong mảng
            properties: [],
            // Đặt stage đầu tiên (index 0) là Active mặc định
            isActive: index === 0
        }));
    }

    get actualBPId() {
        if (this.nodeData && this.nodeData.name) {
            const parts = this.nodeData.name.split('_');
            // Với format mới: [0]=Type, [1]=PT_ID, [2]=BP_ID, ...
            // Nếu node là PT thì parts[2] có thể không tồn tại, cần check type
            if (this.nodeData.name.startsWith('PT')) return null;
            return parts[2]; // Đây chính là Business Process ID cha
        }
        return null;
    }

    // [THAY ĐỔI 3]: Cập nhật hàm @wire để tải và gán dữ liệu vào this.stages
    @wire(getCaseStageOptionsByBP, { businessProcessId: '$actualBPId', refreshTrigger: '$refreshCounter' })
    wiredGetStageOptions({ error, data }) {
        if (data) {
            this.stages = this.processStageOptions(data);

            // Khởi tạo selectedStageIndex
            if (this.stages.length > 0) {
                // Đặt Active Stage đầu tiên
                this.selectedStageIndex = 0;
                // Kích hoạt sự kiện gửi Stage ID đầu tiên lên cha ngay lập tức
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

            // Get BP name from nodeData.label or nodeData.name
            const businessProcessName = this.nodeData?.label || this.nodeData?.name || '';
            const fullName = `${businessProcessName}-${stageName}`;
            const code = `${businessProcessName}-${stageName}`;

            const params = {
                // Use combined BusinessProcessName-StageName as the record Name
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
                // store the full record name, but keep label as simple Stage label for UI
                name: fullName,
                label: stageName,
                order: newStageNumber,
                properties: [],
                isActive: false
            };
            this.stages = [...this.stages, newStage];

            showLog('[handleAddStage] New stage added to local state. Total stages:', this.stages.length);
            this.showToast('Success', 'Stage added successfully', VARIANT_SUCCESS);

            // Trigger wire adapter refresh by incrementing refreshCounter
            // This forces getCaseStageOptionsByBP to re-execute and reload fresh data from server
            this.refreshCounter++;
            showLog('[handleAddStage] Triggered wire adapter refresh with refreshCounter:', this.refreshCounter);

        } catch (error) {
            showLog('Error creating stage:', error);
            this.showToast('Error', 'Failed to add stage: ' + error.body?.message, VARIANT_ERROR);
        }
    }

    async handleRemoveStage(event) {
        event.stopPropagation();
        
        // Only allow delete at Business Process level
        if (!this.isBusinessProcess) {
            this.showToast('Info', 'Stages can only be deleted at Business Process level', 'info');
            showLog('[handleRemoveStage] Delete not allowed - not at BP level. isBusinessProcess:', this.isBusinessProcess);
            return;
        }
        
        const stageId = event.currentTarget.dataset.stageId;
        const stage = this.stages.find(s => s.id === stageId);
        
        if (!stage) return;

        // Confirmation
        if (!confirm(`Are you sure you want to delete stage "${stage.label}"?`)) {
            return;
        }

        try {
            await deleteCaseStage({ stageId });
            this.stages = this.stages.filter(s => s.id !== stageId);
            
            // Update selected index if needed
            if (this.selectedStageIndex >= this.stages.length) {
                this.selectedStageIndex = Math.max(0, this.stages.length - 1);
            }
            
            this.showToast('Success', `Stage "${stage.label}" deleted successfully`, VARIANT_SUCCESS);
        } catch (error) {
            showLog('Error deleting stage:', error);
            this.showToast('Error', 'Failed to delete stage: ' + error.body?.message, VARIANT_ERROR);
        }
    }

    handleEditStageName(event) {
        event.stopPropagation();
        
        // Only allow edit at Business Process level
        if (!this.isBusinessProcess) {
            this.showToast('Info', 'Stage names can only be edited at Business Process level', 'info');
            showLog('[handleEditStageName] Edit not allowed - not at BP level. isBusinessProcess:', this.isBusinessProcess);
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
        // Dispatch event to parent with configuration data
        const configData = {
            nodeId: this.nodeData?.id,
            nodeType: this.nodeData?.type,
            stages: this.stages
        };

        this.dispatchEvent(new CustomEvent(EVENT_SAVE_CONFIG, { detail: configData }));
    }

    // expose labels to template
    labelFlowTitle = LABEL_FLOW_STAGES_TITLE;
    labelAddStage = LABEL_ADD_STAGE;
    labelStagePrefix = LABEL_STAGE_PREFIX;
    labelAltEdit = LABEL_ALT_EDIT;
    labelAltRemove = LABEL_ALT_REMOVE;
}