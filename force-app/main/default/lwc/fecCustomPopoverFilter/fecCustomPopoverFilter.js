import { LightningElement, api, track } from 'lwc';

export default class Fec_CustomPopoverFilter extends LightningElement {
    @api strColumnLabel = '';
    @api strColumnField = '';
    @api strPopoverStyle = '';
    
    @track lstAllOptions = []; 
    @track strSearchKey = '';

    @api 
    set filterOptions(value) {
        // Đồng bộ hóa: Ép dữ liệu từ Cha (checked) vào biến của Con (isChecked)
        if (value) {
            this.lstAllOptions = value.map(opt => ({
                ...opt,
                isChecked: opt.checked || false 
            }));
        } else {
            this.lstAllOptions = [];
        }
    }
    get filterOptions() { return this.lstAllOptions; }

    get lstVisibleOptions() {
        if (!this.strSearchKey) return this.lstAllOptions;
        return this.lstAllOptions.filter(opt => 
            opt.label.toLowerCase().includes(this.strSearchKey.toLowerCase())
        );
    }

    handleSearchChange(event) { this.strSearchKey = event.target.value; }

    handleCheckboxChange(event) {
        const strVal = event.target.value;
        const isChecked = event.target.checked;
        
        this.lstAllOptions = this.lstAllOptions.map(opt => {
            if (opt.value === strVal) return { ...opt, isChecked: isChecked };
            return opt;
        });

        // Bắn event ngay khi check để Cha cập nhật lstFilterOptions
        this.dispatchEvent(new CustomEvent('checkboxchange', {
            detail: { value: strVal, checked: isChecked }
        }));
    }

    handleClearFilter() {
        this.lstAllOptions = this.lstAllOptions.map(opt => ({...opt, isChecked: false}));
        this.strSearchKey = '';
        this.dispatchEvent(new CustomEvent('clear'));
    }

    handleCancel() { this.dispatchEvent(new CustomEvent('close')); }

    handleApply() {
        // Chỉ lấy những giá trị được tick
        const selectedValues = this.lstAllOptions
            .filter(opt => opt.isChecked)
            .map(opt => opt.value);

        this.dispatchEvent(new CustomEvent('apply', {
            detail: { values: selectedValues }
        }));
    }
}