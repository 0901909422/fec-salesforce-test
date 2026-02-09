import { showLog } from 'c/fecUtils';
import { LightningElement, api, track } from 'lwc';
import LABEL_BUTTON_ADD_CHILD from '@salesforce/label/c.FEC_Button_Add_Child';
import LABEL_BUTTON_DELETE from '@salesforce/label/c.FEC_Button_Delete';
import { ICON_TOGGLE_ADD, ICON_TOGGLE_DASH, STATUS_CLASS_BLUE, STATUS_CLASS_RED, STATUS_CLASS_YELLOW, ITEM_CLASS_BASE, ICON_BASE_CLASS, NODE_SELECTED_CLASS, STATUS_VALUE_NEW, STATUS_VALUE_UPDATE } from 'c/fecConstants';
import { DISPLAY_FIELD_ALIAS } from 'c/fecConstants';

export default class FecNatureOfCaseTreeItem extends LightningElement {
    @api level = 1;
    @track expanded = false;
    @track isExpanded = false;
    @api selectedNodeName; // BẮT BUỘC PHẢI CÓ DÒNG NÀY
    @api searchTerm; // Nhận từ khóa từ cha
    @track showAddButton = false;

    get highlightedLabel() {
        const label = this.item.label;
        if (!this.searchTerm || !label) {
            return label; // Nếu không search, trả về chữ bình thường
        }

        // Sử dụng Regex để tìm từ khóa (không phân biệt hoa thường 'gi')
        const regex = new RegExp(`(${this.searchTerm})`, 'gi');
        console.log('searchTerm:', this.searchTerm);

        // Thay thế từ khóa bằng thẻ <mark> để có nền vàng
        return label.replace(regex, '<mark style="background-color: #ffeb3b; color: black; padding: 0 2px; border-radius: 2px;">$1</mark>');
    }

    @api
    get item() { return this._item; }

    set item(value) {
        // KIỂM TRA 4: Component con có được nạp lại data không?
        if (value) {
        }

        this._item = value;

        if (value && value.isExpanded !== undefined) {
            this.isExpanded = value.isExpanded;
        }
    }

    get itemClass() {
        let classes = ITEM_CLASS_BASE;
        // So sánh phải dùng đúng tên biến @api ở trên
        if (this.item && this.selectedNodeName && String(this.item.name) === String(this.selectedNodeName)) {
            return classes + ' ' + NODE_SELECTED_CLASS;
        }
        return classes;
    }

    // 1. Xử lý khi click trực tiếp vào item này
    handleItemClick(event) {
        if (this.showAddButton) {
            // Nếu đang hiện nút mà click vào node thì ẩn nút đi (hoặc giữ tùy bạn)
        }

        // Tạo Custom Event mang tên 'nodeselect'
        const selectEvent = new CustomEvent('nodeselect', {
            detail: {
                name: this.item.name,      // Truyền name (ví dụ: PT_a0FAz...)
                fullItem: this.item        // Bạn có thể truyền cả object nếu cần
            },
            bubbles: true,   // Cho phép sự kiện nổi lên cha
            composed: true   // Cho phép vượt qua Shadow DOM
        });

        // Bắn sự kiện đi
        this.dispatchEvent(selectEvent);
    }

    // 2. Xử lý khi nhận được sự kiện từ các node con (đệ quy)
    handleChildSelect(event) {
        // Tiếp tục truyền sự kiện của con lên cha cao hơn
        this.dispatchEvent(new CustomEvent('nodeselect', {
            detail: event.detail,
            bubbles: true,
            composed: true
        }));
    }

    get computedIconClass() {
        let baseClass = ICON_BASE_CLASS;
        let statusClass = STATUS_CLASS_BLUE;
        const status = this.item.ChangeStatus;

        if (status === STATUS_VALUE_NEW) {
            statusClass = STATUS_CLASS_RED;
        } else if (status === STATUS_VALUE_UPDATE) {
            statusClass = STATUS_CLASS_YELLOW;
        }
        return `${baseClass} ${statusClass}`;
    }

    handleToggle(event) {
        event.stopPropagation(); // Quan trọng: Để không kích hoạt handleItemClick
        this.isExpanded = !this.isExpanded;
        // Bắn sự kiện thông báo cho Cha biết Node này vừa đổi trạng thái
        this.dispatchEvent(new CustomEvent('nodetoggle', {
            detail: {
                name: this.item.name,
                isExpanded: this.isExpanded
            },
            bubbles: true,
            composed: true
        }));
    }

    @track showActionButtons = false;

    handleRightClick(event) {
        event.preventDefault();
        event.stopPropagation(); // Ngăn nổ bọt lên các node cha lồng nhau

        // Hiện nút +Add tại node này
        this.showAddButton = true;
        this.showActionButtons = true;
    }

    handleActionBoxMouseLeave() {
        this.showActionButtons = false;
    }

    // XỬ LÝ ADD CÙNG CẤP
    triggerAddSameLevel(event) {
        event.stopPropagation();
        this.showActionButtons = false;
        this.dispatchAddEvent('same');
    }

    // XỬ LÝ ADD CON
    triggerAddChild(event) {
        event.stopPropagation();
        this.showActionButtons = false;
        this.dispatchAddEvent('child');
    }

    @api parentId;

    dispatchAddEvent(type) {
        const cleanItem = JSON.parse(JSON.stringify(this.item));

        // Nếu bấm "+ Add" (Same Level): Dùng parentId của chính node này (được truyền từ trên xuống)
        // Nếu bấm "+ Add Child": Dùng ID của node này làm cha cho node mới
        const finalParentId = (type === 'same') ? this.parentId : cleanItem.id;

        this.dispatchEvent(new CustomEvent('nodeadd', {
            detail: {
                type: type,
                fullItem: cleanItem,
                parentId: finalParentId // Gửi cái này lên Cha
            },
            bubbles: true,
            composed: true
        }));
    }
    triggerAddNode(event) {
        event.preventDefault();
        event.stopPropagation(); // Không cho kích hoạt sự kiện chọn node (onclick)
        this.showAddButton = false; // Ẩn nút sau khi bấm
        const itemDetail = { ...this.item };

        // Bắn sự kiện lên cha để mở Modal thực sự
        this.dispatchEvent(new CustomEvent('nodeadd', {
            detail: {
                name: this.item.name,
                fullItem: itemDetail
            },
            bubbles: true,
            composed: true
        }));
    }

    handleAddAction(event) {
        event.stopPropagation();
        this.dispatchEvent(new CustomEvent('nodeadd', {
            detail: {
                name: this.item.name,
                fullItem: this.item
            },
            bubbles: true,
            composed: true
        }));
    }

    get hasChildren() { return this.item.items && this.item.items.length > 0; }
    get nextLevel() { return this.level + 1; }
    get toggleIconName() { return this.isExpanded ? ICON_TOGGLE_DASH : ICON_TOGGLE_ADD; }

    @api displayField = DISPLAY_FIELD_ALIAS;

    get displayValue() {
        // Return the value of the selected display field, fallback to label if not found
        if (this.item && this.displayField && this.item[this.displayField] != null) {
            return this.item[this.displayField];
        }
        return this.item ? this.item.Alias : '';
    }

    get highlightedDisplayValue() {
        const value = this.displayValue;
        if (!this.searchTerm || !value) {
            return value;
        }
        // Highlight search term in the selected display field
        const regex = new RegExp(`(${this.searchTerm})`, 'gi');
        return value.replace(regex, '<mark style="background-color: #ffeb3b; color: black; padding: 0 2px; border-radius: 2px;">$1</mark>');
    }

    get canDelete() {
        // Only allow delete if Status is 'New'
        return this.item && this.item.ChangeStatus === 'New';
    }

    handleDeleteNode(event) {
        event.stopPropagation();
        this.dispatchEvent(new CustomEvent('nodedelete', {
            detail: {
                id: this.item.id,
                name: this.item.name,
                fullItem: this.item
            },
            bubbles: true,
            composed: true
        }));
    }
}