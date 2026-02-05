import { LightningElement, track, wire } from 'lwc';
import getCustomerTypeOptions from '@salesforce/apex/FEC_MasterDataReviewController.getCustomerTypeOptions';
import getProductOptions from '@salesforce/apex/FEC_MasterDataReviewController.getProductOptions';
import getBizOptions from '@salesforce/apex/FEC_MasterDataReviewController.getBizOptions';
import getCategoryOptions from '@salesforce/apex/FEC_MasterDataReviewController.getCategoryOptions';
import getSubCatOptions from '@salesforce/apex/FEC_MasterDataReviewController.getSubCatOptions';
import getSubCodeOptions from '@salesforce/apex/FEC_MasterDataReviewController.getSubCodeOptions';
import getComparisonData from '@salesforce/apex/FEC_MasterDataReviewController.getComparisonData';
import LABEL_MASTERDATAREVIEW_TITLE from '@salesforce/label/c.FEC_MasterDataReview_Title';
import LABEL_BUTTON_QUERY from '@salesforce/label/c.FEC_Button_Query';
import LABEL_LABEL_CUSTOMERTYPE from '@salesforce/label/c.FEC_Label_CustomerType';
import LABEL_LABEL_PRODUCT from '@salesforce/label/c.FEC_Label_Product';
import LABEL_LABEL_BIZ from '@salesforce/label/c.FEC_Label_Biz_Process';
import LABEL_LABEL_CATEGORY from '@salesforce/label/c.FEC_Label_Category';
import LABEL_LABEL_SUBCAT from '@salesforce/label/c.FEC_Label_Sub_Cat';
import LABEL_LABEL_SUBCODE from '@salesforce/label/c.FEC_Label_Sub_Code';
import LABEL_PLACEHOLDER_SELECT_CUSTOMERTYPE from '@salesforce/label/c.FEC_Placeholder_Select_CustomerType';
import LABEL_PLACEHOLDER_SELECT_PRODUCT from '@salesforce/label/c.FEC_Placeholder_Select_Product';
import LABEL_PLACEHOLDER_SELECT_BIZ from '@salesforce/label/c.FEC_Placeholder_Select_Biz';
import LABEL_PLACEHOLDER_SELECT_CATEGORY from '@salesforce/label/c.FEC_Placeholder_Select_Category';
import LABEL_PLACEHOLDER_SELECT_SUBCAT from '@salesforce/label/c.FEC_Placeholder_Select_SubCat';
import LABEL_PLACEHOLDER_SELECT_SUBCODE from '@salesforce/label/c.FEC_Placeholder_Select_SubCode';
import LABEL_NEW_RECORDS from '@salesforce/label/c.FEC_Label_New_Records';
import LABEL_UPDATED_RECORDS from '@salesforce/label/c.FEC_Label_Updated_Records';
import LABEL_SYNCED_RECORDS from '@salesforce/label/c.FEC_Label_Synced_Records';
import LABEL_BUTTON_EXPAND_ALL from '@salesforce/label/c.FEC_Button_Expand_All';
import LABEL_BUTTON_COLLAPSE_ALL from '@salesforce/label/c.FEC_Button_Collapse_All';
import LABEL_NODATA_MESSAGE from '@salesforce/label/c.FEC_NoData_Message';
import { ICON_NEW, ICON_UPDATED, ICON_SYNCED, ICON_CHEVRON_DOWN, ICON_CHEVRON_RIGHT, TITLE_CLASS_SUCCESS, TITLE_CLASS_ERROR, TITLE_CLASS_WEAK, SECTION_NEW, SECTION_UPDATED, SECTION_SYNCED } from 'c/fecConstants/fecConstants';

export default class FecMasterDataReview extends LightningElement {
    @track isLoading = false;
    @track rawData = { [SECTION_NEW]: [], [SECTION_UPDATED]: [], [SECTION_SYNCED]: [] };
    @track val = { ct: null, p: null, b: null, c: null, sc: null, scc: null };

    @track customerTypes = [];
    @track products = []; @track bizs = []; @track cats = []; @track subCats = []; @track subCodes = [];

    @wire(getCustomerTypeOptions)
    wiredCustomerTypes({ data }) { if (data) this.customerTypes = data; }

    @wire(getProductOptions, { customerType: '$val.ct' })
    wiredP({ data }) { if (data) this.products = data; }

    // labels
    labelTitle = LABEL_MASTERDATAREVIEW_TITLE;
    labelQuery = LABEL_BUTTON_QUERY;
    labelCustomerType = LABEL_LABEL_CUSTOMERTYPE;
    labelProduct = LABEL_LABEL_PRODUCT;
    labelBiz = LABEL_LABEL_BIZ;
    labelCategory = LABEL_LABEL_CATEGORY;
    labelSubCat = LABEL_LABEL_SUBCAT;
    labelSubCode = LABEL_LABEL_SUBCODE;
    placeholderCustomerType = LABEL_PLACEHOLDER_SELECT_CUSTOMERTYPE;
    placeholderProduct = LABEL_PLACEHOLDER_SELECT_PRODUCT;
    placeholderBiz = LABEL_PLACEHOLDER_SELECT_BIZ;
    placeholderCategory = LABEL_PLACEHOLDER_SELECT_CATEGORY;
    placeholderSubCat = LABEL_PLACEHOLDER_SELECT_SUBCAT;
    placeholderSubCode = LABEL_PLACEHOLDER_SELECT_SUBCODE;
    labelNew = LABEL_NEW_RECORDS;
    labelUpdated = LABEL_UPDATED_RECORDS;
    labelSynced = LABEL_SYNCED_RECORDS;
    labelExpandAll = LABEL_BUTTON_EXPAND_ALL;
    labelCollapseAll = LABEL_BUTTON_COLLAPSE_ALL;
    labelNoData = LABEL_NODATA_MESSAGE;

    // --- EVENT HANDLERS (Waterfall Logic) ---
    handleCustomerTypeChange(e) {
        this.val = { ...this.val, ct: e.detail.value, p: null, b: null, c: null, sc: null, scc: null };
        // Optionally clear products and below
        this.products = [];
        this.bizs = [];
        this.cats = [];
        this.subCats = [];
        this.subCodes = [];
    }
    handlePChange(e) {
        this.val = { ...this.val, p: e.detail.value, b: null, c: null, sc: null, scc: null };
        getBizOptions({ productId: this.val.p }).then(res => this.bizs = res);
    }
    handleBChange(e) {
        this.val = { ...this.val, b: e.detail.value, c: null, sc: null, scc: null };
        getCategoryOptions({ productId: this.val.p, bizId: this.val.b }).then(res => this.cats = res);
    }
    handleCChange(e) {
        this.val = { ...this.val, c: e.detail.value, sc: null, scc: null };
        getSubCatOptions({ productId: this.val.p, bizId: this.val.b, catId: this.val.c }).then(res => this.subCats = res);
    }
    handleSubCatChange(e) {
        this.val = { ...this.val, sc: e.detail.value, scc: null };
        getSubCodeOptions({ productId: this.val.p, bizId: this.val.b, catId: this.val.c, subCatId: this.val.sc }).then(res => this.subCodes = res);
    }
    handleSubCodeChange(e) {
        this.val = { ...this.val, scc: e.detail.value };
    }

    get hasData() {
        return this.rawData[SECTION_NEW].length > 0 || this.rawData[SECTION_UPDATED].length > 0 || this.rawData[SECTION_SYNCED].length > 0;
    }

    get sections() {
        return [
            { id: SECTION_NEW, label: this.labelNew, data: this.rawData[SECTION_NEW], count: this.rawData[SECTION_NEW].length, hasData: this.rawData[SECTION_NEW].length > 0, icon: ICON_NEW, titleClass: TITLE_CLASS_SUCCESS },
            { id: SECTION_UPDATED, label: this.labelUpdated, data: this.rawData[SECTION_UPDATED], count: this.rawData[SECTION_UPDATED].length, hasData: this.rawData[SECTION_UPDATED].length > 0, icon: ICON_UPDATED, titleClass: TITLE_CLASS_ERROR },
            { id: SECTION_SYNCED, label: this.labelSynced, data: this.rawData[SECTION_SYNCED], count: this.rawData[SECTION_SYNCED].length, hasData: this.rawData[SECTION_SYNCED].length > 0, icon: ICON_SYNCED, titleClass: TITLE_CLASS_WEAK }
        ];
    }

    // --- XỬ LÝ EXPAND / COLLAPSE ALL ---
    handleExpandAll(e) {
        const sectionId = e.target.dataset.section;
        this.updateSectionExpansion(sectionId, true);
    }

    handleCollapseAll(e) {
        const sectionId = e.target.dataset.section;
        this.updateSectionExpansion(sectionId, false);
    }

    updateSectionExpansion(sectionId, shouldExpand) {
        // Cập nhật mảng cụ thể trong rawData
        this.rawData[sectionId] = this.rawData[sectionId].map(item => ({
            ...item,
            expanded: shouldExpand,
            iconName: shouldExpand ? ICON_CHEVRON_DOWN : ICON_CHEVRON_RIGHT
        }));
        
        // Kích hoạt reactivity bằng cách gán lại object
        this.rawData = { ...this.rawData };
    }

    handleSearch() {
        if (!this.val.scc) return;
        this.isLoading = true;
        getComparisonData({
            productId: this.val.p, bizId: this.val.b, catId: this.val.c,
            subCatId: this.val.sc, subCodeId: this.val.scc
        }).then(res => {
            const mapRow = (list) => list.map(row => ({ ...row, expanded: false, iconName: ICON_CHEVRON_RIGHT }));
            this.rawData = {
                [SECTION_NEW]: mapRow(res[SECTION_NEW]),
                [SECTION_UPDATED]: mapRow(res[SECTION_UPDATED]),
                [SECTION_SYNCED]: mapRow(res[SECTION_SYNCED])
            };
            this.isLoading = false;
        }).catch(() => { this.isLoading = false; });
    }

    handleToggle(e) {
        const id = e.currentTarget.dataset.id;
        // Duyệt qua cả 3 danh sách để tìm và lật trạng thái record được chọn
        const toggleInList = (list) => list.map(row =>
            row.externalId === id ? { ...row, expanded: !row.expanded, iconName: !row.expanded ? ICON_CHEVRON_DOWN : ICON_CHEVRON_RIGHT } : row
        );

        this.rawData = {
            [SECTION_NEW]: toggleInList(this.rawData[SECTION_NEW]),
            [SECTION_UPDATED]: toggleInList(this.rawData[SECTION_UPDATED]),
            [SECTION_SYNCED]: toggleInList(this.rawData[SECTION_SYNCED])
        };
    }
}