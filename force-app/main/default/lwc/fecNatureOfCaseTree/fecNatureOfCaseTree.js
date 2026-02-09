import { LightningElement, wire, track, api } from 'lwc';
import getNatureOfCaseTreeData from '@salesforce/apex/FEC_NatureOfCaseTreeController.getNatureOfCaseTreeData';
import deleteNodeApex from '@salesforce/apex/FEC_NatureOfCaseTreeController.deleteNodeApex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import FECNatureOfCaseModal from 'c/fecNatureOfCaseModal';
import { showLog } from 'c/fecUtils';
import LABEL_TREE_TITLE from '@salesforce/label/c.FEC_Tree_Title';
import LABEL_PLACEHOLDER_SEARCH_TREE from '@salesforce/label/c.FEC_Placeholder_Search_Tree';
import LABEL_SHOW_FIELD from '@salesforce/label/c.FEC_Label_Show_Field';
import LABEL_ADD_ROOT from '@salesforce/label/c.FEC_Button_Add_Root';
import LABEL_ADD_NODE from '@salesforce/label/c.FEC_Button_Add_Node';
import LABEL_MESSAGE_NO_ITEMS from '@salesforce/label/c.FEC_Message_No_Items';
import LABEL_MESSAGE_LOADING_TREE from '@salesforce/label/c.FEC_Message_Loading_Tree';
import LABEL_ARIA_TREE from '@salesforce/label/c.FEC_Aria_Tree_Label';
import LABEL_ARIA_ADD_NODE from '@salesforce/label/c.FEC_Aria_Add_Node';
import LABEL_DISPLAY_CODE from '@salesforce/label/c.FEC_Label_Display_Code';
import LABEL_DISPLAY_ALIAS from '@salesforce/label/c.FEC_Label_Display_Alias';
import LABEL_DISPLAY_NAME_VN from '@salesforce/label/c.FEC_Label_Display_Name_VN';
import LABEL_DISPLAY_NAME_EN from '@salesforce/label/c.FEC_Label_Display_Name_EN';
import LABEL_STATUS_ALL from '@salesforce/label/c.FEC_Label_Status_ALL';
import LABEL_STATUS_ACTIVE from '@salesforce/label/c.FEC_Label_Status_ACTIVE';
import LABEL_STATUS_INACTIVE from '@salesforce/label/c.FEC_Label_Status_INACTIVE';
import { OBJ_PRODUCT_TYPE, OBJ_BUSINESS_PROCESS, OBJ_CATEGORY, OBJ_SUB_CATEGORY, OBJ_SUB_CODE, TAG_NATURE_TREE, PREFIX_SUB_CODE, PREFIX_PT, PREFIX_BP, PREFIX_CAT, DISPLAY_FIELD_CODE, DISPLAY_FIELD_ALIAS, DISPLAY_FIELD_NAME_VN, DISPLAY_FIELD_NAME_EN, STATUS_ALL, STATUS_ACTIVE, STATUS_INACTIVE, TITLE_CLASS_BASE, TITLE_CLASS_SELECTED_SUFFIX } from 'c/fecConstants';

export default class FecNatureOfCaseTree extends LightningElement {
    // labels
    labelTreeTitle = LABEL_TREE_TITLE;
    placeholderSearchTree = LABEL_PLACEHOLDER_SEARCH_TREE;
    labelShowField = LABEL_SHOW_FIELD;
    labelAddRoot = LABEL_ADD_ROOT;
    labelAddNode = LABEL_ADD_NODE;
    messageNoItems = LABEL_MESSAGE_NO_ITEMS;
    messageLoading = LABEL_MESSAGE_LOADING_TREE;
    ariaTreeLabel = LABEL_ARIA_TREE;
    ariaAddNode = LABEL_ARIA_ADD_NODE;

    @track treeItems;
    wiredTreeDataResult;
    @track selectedNodeId = null;
    @track selectedNodeCustomerType = null;
    @track selectedNodeLabel;
    @track selectedNodePrefix;
    @track selectedNodeName = ''; // Lưu name của node đang được chọn

    @track isTitleSelected = true; // Mặc định là Title được chọn khi mới tải
    @track treeKey = 1; // Biến key để buộc render lại Tree (FIX: Unselect)
    TAG = TAG_NATURE_TREE;
    fecRawData = [];       // Lưu trữ dữ liệu gốc từ Apex
    @track searchTerm = ''; // Thêm biến để lưu từ khóa
    @track expandedNodeNames = new Set(); // Lưu danh sách các node đang mở

    objectMap = {
        [PREFIX_PT]: OBJ_BUSINESS_PROCESS,
        [PREFIX_BP]: OBJ_CATEGORY,
        [PREFIX_CAT]: OBJ_SUB_CATEGORY,
        [PREFIX_SUB_CODE]: OBJ_SUB_CODE
    };
    objectMapRoot = {
        [PREFIX_PT]: OBJ_PRODUCT_TYPE,
        [PREFIX_BP]: OBJ_BUSINESS_PROCESS,
        [PREFIX_CAT]: OBJ_CATEGORY,
        [PREFIX_SUB_CODE]: OBJ_SUB_CATEGORY,
    };

    @wire(getNatureOfCaseTreeData)
    wiredTreeData(result) {
        this.wiredTreeDataResult = result;
        const { error, data } = result;
        if (data) {
            if (this.expandedNodeNames.size === 0) {
                this.treeItems = data;
            }
            this.fecRawData = data;
        } else if (result.error) {
            console.error('Error fetching tree data:', result.error);
            this.showToast('Error Loading Data', result.error.body.message, 'error');
        }
    }


    // Cho phép component cha gọi hàm này
    @api
    async refreshTreeData() {
        console.log('Tree đang thực hiện refreshApex...');
        await refreshApex(this.wiredTreeDataResult);
        const freshData = this.wiredTreeDataResult.data;
        // Tính toán lại treeItems để cập nhật màu sắc mới
        if (freshData) {
            this.treeKey = false;
            this.fecRawData = JSON.parse(JSON.stringify(freshData));
            if (this.selectedNodeName) {
                this.expandedNodeNames.add(String(this.selectedNodeName));
            }
            const processedItems = this.applyFilterAndExpand(this.fecRawData, this.searchTerm, this.selectedNodeName);
            setTimeout(() => {
                this.treeItems = processedItems;
                this.treeKey = true;
            }, 0);
        }
    }

    handleNodeToggle(event) {
        const nodeName = String(event.detail.name);
        const isExpanded = event.detail.isExpanded;

        if (isExpanded) {
            this.expandedNodeNames.add(nodeName);
        } else {
            // Khi đóng node cha, bạn có thể cân nhắc xóa luôn các node con 
            // của nó trong Set nếu muốn (tùy UX)
            this.expandedNodeNames.delete(nodeName);
        }
    }

    handleFecSearch(event) {
        this.searchTerm = event.target.value;
        // Khi xóa search, searchTerm thành rỗng, hàm applyFilterAndExpand sẽ chạy vào Trường hợp 2
        this.treeItems = this.applyFilterAndExpand(this.fecRawData, this.searchTerm);
    }

    // Hàm lọc đệ quy chuyên sâu
    filterTree(nodes, query) {
        return nodes.filter(node => {
            // Kiểm tra xem node hiện tại có khớp query không
            const isMatch = node.label.toLowerCase().includes(query);

            // Nếu có con, lọc tiếp các con
            if (node.items && node.items.length > 0) {
                node.items = this.filterTree(node.items, query);

                // Nếu có con khớp, thì cha cũng phải hiển thị và tự động mở ra
                if (node.items.length > 0) {
                    node.isExpanded = true; // Tự động bung ra để thấy con
                    return true;
                }
            }
            return isMatch;
        });
    }

    // --- GETTERS ĐỘNG ---

    get isTreeEmpty() {
        // Returns true if treeItems exists and is an empty array
        return Array.isArray(this.treeItems) && this.treeItems.length === 0;
    }

    get titleClass() {
        return TITLE_CLASS_BASE + (this.isTitleSelected ? TITLE_CLASS_SELECTED_SUFFIX : '');
    }

    get addNodeButtonLabel() {
        if (this.isTitleSelected && !this.selectedNodeId) {
            return this.labelAddRoot;
        }
        return this.labelAddNode;
    }

    get isAddNodeDisabled() {
        // 1. Nếu Title được chọn, nút luôn BẬT (để Add Root)
        if (this.isTitleSelected) {
            return false;
        }

        // 2. Nếu không có Node nào được chọn sau khi mất trạng thái Title, Disable
        if (!this.selectedNodeId) {
            return true;
        }

        // 3. Kiểm tra cấp cuối
        const prefix = this.selectedNodePrefix;
        if (prefix === PREFIX_SUB_CODE) {
            return true;
        }

        const targetObjectType = this.objectMap[prefix];
        return !targetObjectType;
    }

    /**
      * @description Xử lý khi click vào Tiêu đề Card.
      */
    handleTitleClick(event) {
        // 1. Reset trạng thái Node đã chọn trong JS
        this.selectedNodeId = null;
        this.selectedNodeCustomerType = null;
        this.selectedNodeLabel = null;
        this.selectedNodePrefix = null;

        // 2. Kích hoạt trạng thái Title được chọn
        this.isTitleSelected = true;

        // TẠM THỜI lưu trữ dữ liệu hiện tại
        // Đảm bảo tạo bản sao (spread operator) để tránh xung đột tham chiếu
        const currentItems = [...this.treeItems];

        // Buộc tree component render với mảng rỗng để xóa trạng thái selected
        this.treeItems = [];

        // Sử dụng Promise.resolve().then() để chờ LWC hoàn thành chu kỳ render vi mô
        // trước khi gán lại dữ liệu gốc (đảm bảo Tree đã render rỗng trước khi nạp lại data).
        Promise.resolve().then(() => {
            this.treeItems = currentItems;
        });

        console.log('Tree selection reset via data manipulation.');
    }

    handleNodeSelect(event) {
        // 1. TẮT trạng thái Title được chọn
        this.isTitleSelected = false;

        const selectedName = event.detail.name;
        this.selectedNodeName = event.detail.name;
        const selectedItem = event.detail.fullItem;
        showLog('selectedName:', selectedItem);

        if (!selectedItem) return;

        // 2. Cập nhật trạng thái Node
        const parts = selectedName.split('_');

        if (parts.length > 1) {
            this.selectedNodeId = selectedItem.idType;
            this.selectedNodeCustomerType = selectedItem.FEC_Customer_Type;
            this.selectedNodePrefix = parts[0];
            this.selectedNodeLabel = selectedItem.nameVN;
        } else {
            this.selectedNodeId = null;
            this.selectedNodeCustomerType = null;
            this.selectedNodePrefix = null;
            this.selectedNodeLabel = null;
        }
        this.dispatchEvent(new CustomEvent("itemselect", { detail: selectedItem }));

    }

    handleAddNodeAction() {
        if (this.isTitleSelected) {
            this.handleAddNewRoot();
        } else if (this.selectedNodeId) {
            this.handleAddNewChild();
        }
    }

    // Các hàm Modal (Giữ nguyên)
    async openAddNodeModal(parentId, objectType, parentLabel, parentCustomerType) {
        const result = await FECNatureOfCaseModal.open({
            size: 'small',
            description: `Form adding ${objectType}`,
            parentId: parentId,
            objectType: objectType,
            parentLabel: parentLabel,
            parentCustomerType: parentCustomerType,
        });
        console.log('openAddNodeModal:', result);


        if (result != null) {
            this.handleSaveSuccess();
        }
    }

    handleAddNewRoot() {
        this.openAddNodeModal(null, OBJ_PRODUCT_TYPE, this.labelAddRoot || 'Root', '');
    }

    handleAddNewChild() {
        if (!this.selectedNodeId) return;

        const prefix = this.selectedNodePrefix;
        const targetObjectType = this.objectMap[prefix];

        if (!targetObjectType) {
            this.showToast('Lỗi', 'Không thể thêm Node con vào cấp cuối cùng (Sub Code).', 'error');
            return;
        }

        this.openAddNodeModal(this.selectedNodeId, targetObjectType, this.selectedNodeLabel, this.selectedNodeCustomerType);
    }

    async handleSaveSuccess() {
        try {
            showLog('Refreshing tree data after save...');
            await refreshApex(this.wiredTreeDataResult);
            const freshData = this.wiredTreeDataResult.data;

            if (freshData) {
                // 1. Ép render lại từ đầu bằng cách tạm ẩn cây
                this.treeKey = false;

                // 2. Tạo bản sao mới hoàn toàn (Deep Copy)
                this.fecRawData = JSON.parse(JSON.stringify(freshData));

                // 3. Đảm bảo node đang select cũng được mở
                if (this.selectedNodeName) {
                    this.expandedNodeNames.add(String(this.selectedNodeName));
                }

                // 4. Tính toán lại treeItems với dữ liệu mới nhất, chỉ mở các node trong expandedNodeNames
                const processedItems = this.applyFilterAndExpand(this.fecRawData, this.searchTerm);

                // 5. Cập nhật dữ liệu và hiện lại cây
                setTimeout(() => {
                    this.treeItems = processedItems;
                    this.treeKey = true; // Kích hoạt render lại toàn bộ
                }, 0);

                this.showToast('Thành công', 'Thêm thành công!', 'success');
            }
        } catch (error) {
            console.error('Error:', error);
        }
    }
    // Hàm bổ trợ để lọc và tự động mở node
    applyFilterAndExpand(data, searchTerm, forceExpandId) {
        const searchKey = searchTerm ? searchTerm.toLowerCase().trim() : '';
        const targetId = forceExpandId ? String(forceExpandId) : null;

        const filterAndExpand = (items) => {
            return items.map(item => {
                const newItem = { ...item };
                const currentName = String(newItem.name);

                // Apply status filter: show only nodes that match selectedStatusFilter
                if (this.selectedStatusFilter && this.selectedStatusFilter !== 'ALL') {
                    const shouldBeActive = this.selectedStatusFilter === 'ACTIVE';
                    // If Status property is present, filter nodes that don't match
                    if (newItem.Status !== undefined && newItem.Status !== null) {
                        if (Boolean(newItem.Status) !== shouldBeActive) {
                            // Node itself doesn't match; but children might. We continue to process children and keep parent
                            // only if any child matches after recursion. We don't return null immediately.
                        }
                    }
                }

                let isAnyChildExpanded = false;
                if (newItem.items && newItem.items.length > 0) {
                    newItem.items = filterAndExpand(newItem.items);
                    // Nếu có bất kỳ con nào của nó đang mở, thì chính nó cũng phải mở
                    isAnyChildExpanded = newItem.items.some(child => child.isExpanded);
                }

                const isManuallyExpanded = this.expandedNodeNames.has(currentName);
                const isTargetParent = targetId && currentName === targetId;

                // Evaluate status match for this node
                let statusMatches = true; // default: matches
                if (this.selectedStatusFilter && this.selectedStatusFilter !== 'ALL' && newItem.Status !== undefined && newItem.Status !== null) {
                    statusMatches = (this.selectedStatusFilter === 'ACTIVE') ? Boolean(newItem.Status) === true : Boolean(newItem.Status) === false;
                }

                if (searchKey) {
                    showLog('Filtering node:', newItem.label);
                    // For search, check the selected display field to match searchKey
                    const fieldToSearch = (this.selectedDisplayField && newItem[this.selectedDisplayField] != null) ? String(newItem[this.selectedDisplayField]).toLowerCase() : String(newItem.label).toLowerCase();
                    const matchesSearch = fieldToSearch.includes(searchKey);
                    newItem.isExpanded = (matchesSearch && statusMatches) || isAnyChildExpanded;
                    return ((matchesSearch && statusMatches) || isAnyChildExpanded) ? newItem : null;
                } else {
                    // No search term: respect status filter and manual/child expansion
                    if (!statusMatches && !(newItem.items && newItem.items.length > 0)) {
                        // Node and descendants don't match status filter -> filter out
                        return null;
                    }

                    newItem.isExpanded = (isManuallyExpanded || isTargetParent) && statusMatches;
                    return newItem;
                }
            }).filter(item => item !== null);
        };

        return filterAndExpand(data || []);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    @track selectedDisplayField = DISPLAY_FIELD_CODE;
    displayFieldOptions = [
        { label: LABEL_DISPLAY_CODE, value: DISPLAY_FIELD_CODE },
        { label: LABEL_DISPLAY_ALIAS, value: DISPLAY_FIELD_ALIAS },
        { label: LABEL_DISPLAY_NAME_VN, value: DISPLAY_FIELD_NAME_VN },
        { label: LABEL_DISPLAY_NAME_EN, value: DISPLAY_FIELD_NAME_EN }
    ];

    @track selectedStatusFilter = STATUS_ALL;
    statusOptions = [
        { label: LABEL_STATUS_ALL, value: STATUS_ALL },
        { label: LABEL_STATUS_ACTIVE, value: STATUS_ACTIVE },
        { label: LABEL_STATUS_INACTIVE, value: STATUS_INACTIVE }
    ];

    handleDisplayFieldChange(event) {
        this.selectedDisplayField = event.detail.value;
        showLog('Selected Display Field:', this.selectedDisplayField);
    }

    handleStatusChange(event) {
        this.selectedStatusFilter = event.detail.value;
        showLog('Selected Status Filter:', this.selectedStatusFilter);
        // Re-apply filter to current raw data
        this.treeItems = this.applyFilterAndExpand(this.fecRawData, this.searchTerm, this.selectedNodeName);
    }

    handleNodeAdd(event) {
        event.stopPropagation();

        // 1. Lấy thông tin từ event detail
        const { type, fullItem, parentId } = event.detail;
        const selectedName = event.detail.name || fullItem.name;

        this.isTitleSelected = false;
        this.selectedNodeName = selectedName;

        // 2. Phân loại hành động dựa trên biến 'type' từ Component con gửi lên
        if (type === 'same') {
            // Nếu là "Add" (Same Level) -> Gọi hàm xử lý cùng cấp
            console.log('Action: Add Same Level for parent:', parentId);
            this.handleOpenModalForSameLevel(fullItem, parentId);
        } else {
            // Nếu là "Add Child" (hoặc mặc định) -> Gọi hàm xử lý thêm con
            console.log('Action: Add Child for node:', fullItem.id);

            // Cập nhật các biến ID/Prefix để UI biết đang thao tác trên node nào
            if (fullItem) {
                const parts = selectedName.split('_');
                if (parts.length > 1) {
                    this.selectedNodeId = fullItem.idType;
                    this.selectedNodeCustomerType = fullItem.FEC_Customer_Type;
                    this.selectedNodePrefix = parts[0];
                    this.selectedNodeLabel = fullItem.nameVN;
                }
            }
            this.handleAddNewChild(fullItem);
        }
    }

    // Sửa lại hàm này để tránh lỗi "objectType is not defined"
    async handleOpenModalForSameLevel(fullItem, parentId) {
        const currentPrefix = fullItem.name.split('_')[0];
        showLog('handleOpenModalForSameLevel - currentPrefix:', fullItem);
        const targetObjectType = this.objectMapRoot[currentPrefix];
        showLog('handleOpenModalForSameLevel - targetObjectType:', targetObjectType);

        this.openAddNodeModal(parentId, targetObjectType, 'Same Level', this.selectedNodeCustomerType);
    }

    async handleNodeDelete(event) {
        const { fullItem } = event.detail;

        // Trích xuất thông tin từ fullItem
        const idType = fullItem.idType;
        const type = fullItem.type;
        const code = fullItem.Code; // Lưu ý Code viết hoa chữ C theo log

        console.log('Processed Delete fullItem:', fullItem);

        if (!idType || !type) {
            this.showToast('Lỗi', 'Không thể xác định thông tin bản ghi để xóa.', 'error');
            return;
        }
        const msg = `CẢNH BÁO: Bạn đang xóa node ${code} loại "${type}".
        Tất cả các node con sẽ bị xóa. 
        Bạn có chắc chắn muốn tiếp tục?`;

        const confirmed = confirm(msg);
        if (!confirmed) return;

        try {
            this.loading = true;
            // Gọi Apex với các tham số đã trích xuất
            await deleteNodeApex({
                typeRecordId: idType,
                typeName: type
            });

            this.showToast('Thành công', 'Đã xóa bản ghi và các mapping liên quan.', 'success');
            await this.refreshTreeData();
        } catch (error) {
            this.showToast('Không thể xóa', error.body?.message || 'Lỗi hệ thống', 'error');
        } finally {
            this.loading = false;
        }
    }
}