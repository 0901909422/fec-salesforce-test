import { LightningElement, api, track, wire } from 'lwc';
import createCaseStage from '@salesforce/apex/FEC_MasterDataSettingController.createCaseStage';
import getCaseStageOptionsByBP from '@salesforce/apex/FEC_MasterDataSettingController.getCaseStageOptionsByBP';
import { showLog } from 'c/fecMDMUtils';
import LABEL_FLOW_STAGES_TITLE from '@salesforce/label/c.FEC_Flow_Stages_Title';
import LABEL_ADD_STAGE from '@salesforce/label/c.FEC_Add_Stage';
import LABEL_STAGE_PREFIX from '@salesforce/label/c.FEC_Label_Stage';
import LABEL_ALT_EDIT from '@salesforce/label/c.FEC_Alt_Edit';
import LABEL_ALT_REMOVE from '@salesforce/label/c.FEC_Alt_Remove';
import LABEL_PROMPT_ENTER_NEW_STAGE_NAME from '@salesforce/label/c.FEC_Prompt_Enter_New_Stage_Name';
import { EVENT_HANDLE_STAGE_CLICK, EVENT_SAVE_CONFIG, CSS_STAGE_BOX, CSS_STAGE_BOX_ACTIVE } from 'c/fecConstants';


export default class FecFlowConfiguration extends LightningElement {
    @api nodeData;
    @track stages = [];
    @track selectedStageIndex = 0;
    @track showPropertyModal = false;

    connectedCallback() {
        this.selectedStageIndex = 0;

    }

    // Thêm getter này vào trong class FecFlowConfiguration
    get isBusinessProcess() {
        // Kiểm tra an toàn xem nodeData và nodeData.name có tồn tại không
        return this.nodeData &&
            this.nodeData.name &&
            this.nodeData.name.startsWith('BP');
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
    @wire(getCaseStageOptionsByBP, { businessProcessId: '$actualBPId' })
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
            const code = businessProcessId + '-' + stageName;

            const params = {
                name: stageName, // Map đúng với biến 'name' trong Apex
                code: code,
                businessProcessId: businessProcessId, // Đảm bảo nodeData.id có giá trị
                nameVN: stageName,
                status: true,
                alias: stageName,
                posOrder: newStageNumber // Kiểu Number
            };
            showLog('Adding new stage:', this.nodeData);

            // Gọi Apex
            const newStageId = await createCaseStage(params);

            // Logic thêm vào mảng UI sau khi DB thành công
            const newStage = {
                id: newStageId,
                name: stageName,
                label: stageName,
                order: newStageNumber,
                properties: [],
                isActive: false
            };
            this.stages = [...this.stages, newStage];

        } catch (error) {
            showLog('Error creating stage:', error);
            // Hiển thị toast thông báo lỗi cụ thể từ Apex
        }
    }
    handleRemoveStage(event) {
        const stageId = event.currentTarget.dataset.stageId;
        this.stages = this.stages.filter(s => s.id !== stageId);
        if (this.selectedStageIndex >= this.stages.length) {
            this.selectedStageIndex = Math.max(0, this.stages.length - 1);
        }
    }

    handleEditStageName(event) {
        const stageId = event.currentTarget.dataset.stageId;
        const stageIndex = this.stages.findIndex(s => s.id === stageId);

        // For now, we'll use a simple prompt
        const newName = prompt(LABEL_PROMPT_ENTER_NEW_STAGE_NAME, this.stages[stageIndex].name);
        if (newName) {
            const updatedStages = [...this.stages];
            updatedStages[stageIndex].name = newName;
            updatedStages[stageIndex].label = newName;
            this.stages = updatedStages;
        }
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