import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLiveReviewCustomerTypes from '@salesforce/apex/FEC_LiveDataViewController.getLiveReviewCustomerTypes';
import getLiveReviewProductOptions from '@salesforce/apex/FEC_LiveDataViewController.getLiveReviewProductOptions';
import getLiveReviewBizOptions from '@salesforce/apex/FEC_LiveDataViewController.getLiveReviewBizOptions';
import getLiveReviewCategoryOptions from '@salesforce/apex/FEC_LiveDataViewController.getLiveReviewCategoryOptions';
import getLiveReviewSubCatOptions from '@salesforce/apex/FEC_LiveDataViewController.getLiveReviewSubCatOptions';
import getLiveReviewSubCodeOptions from '@salesforce/apex/FEC_LiveDataViewController.getLiveReviewSubCodeOptions';
import getLiveReviewComparison from '@salesforce/apex/FEC_LiveDataViewController.getLiveReviewComparison';
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
import {
    ICON_NEW, ICON_UPDATED, ICON_SYNCED,
    ICON_CHEVRON_DOWN, ICON_CHEVRON_RIGHT,
    TITLE_CLASS_SUCCESS, TITLE_CLASS_ERROR, TITLE_CLASS_WEAK,
    SECTION_NEW, SECTION_UPDATED, SECTION_SYNCED
} from 'c/fecConstants';

export default class FecLiveDataReview extends LightningElement {
    isLoading = false;
    @track rawData = { [SECTION_NEW]: [], [SECTION_UPDATED]: [], [SECTION_SYNCED]: [] };
    @track val = { ct: null, p: null, b: null, c: null, sc: null, scc: null };

    @track customerTypes = [];
    @track products = [];
    @track bizs = [];
    @track cats = [];
    @track subCats = [];
    @track subCodes = [];

    // Labels
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

    // Wire: Customer Types (top-level, no params)
    @wire(getLiveReviewCustomerTypes)
    wiredCustomerTypes({ data, error }) {
        if (data) {
            this.customerTypes = data;
        } else if (error) {
            this.showErrorToast(error.body?.message || error.message || 'Error loading customer types');
        }
    }

    // Wire: Product Types (reactive on customerType)
    @wire(getLiveReviewProductOptions, { customerType: '$val.ct' })
    wiredProducts({ data, error }) {
        if (data) {
            this.products = data;
        } else if (error) {
            this.showErrorToast(error.body?.message || error.message || 'Error loading products');
        }
    }

    // Computed
    get isSearchDisabled() {
        return this.isLoading || !this.val.scc;
    }

    get hasData() {
        return this.rawData[SECTION_NEW].length > 0 ||
               this.rawData[SECTION_UPDATED].length > 0 ||
               this.rawData[SECTION_SYNCED].length > 0;
    }

    get sections() {
        return [
            {
                id: SECTION_NEW, label: this.labelNew,
                data: this.rawData[SECTION_NEW], count: this.rawData[SECTION_NEW].length,
                hasData: this.rawData[SECTION_NEW].length > 0,
                icon: ICON_NEW, titleClass: TITLE_CLASS_SUCCESS
            },
            {
                id: SECTION_UPDATED, label: this.labelUpdated,
                data: this.rawData[SECTION_UPDATED], count: this.rawData[SECTION_UPDATED].length,
                hasData: this.rawData[SECTION_UPDATED].length > 0,
                icon: ICON_UPDATED, titleClass: TITLE_CLASS_ERROR
            },
            {
                id: SECTION_SYNCED, label: this.labelSynced,
                data: this.rawData[SECTION_SYNCED], count: this.rawData[SECTION_SYNCED].length,
                hasData: this.rawData[SECTION_SYNCED].length > 0,
                icon: ICON_SYNCED, titleClass: TITLE_CLASS_WEAK
            }
        ];
    }

    // Cascading filter handlers
    handleCustomerTypeChange(e) {
        this.val = { ...this.val, ct: e.detail.value, p: null, b: null, c: null, sc: null, scc: null };
        this.products = [];
        this.bizs = [];
        this.cats = [];
        this.subCats = [];
        this.subCodes = [];
    }

    handlePChange(e) {
        this.val = { ...this.val, p: e.detail.value, b: null, c: null, sc: null, scc: null };
        this.bizs = [];
        this.cats = [];
        this.subCats = [];
        this.subCodes = [];
        getLiveReviewBizOptions({ productId: this.val.p })
            .then(res => { this.bizs = res; })
            .catch(error => {
                this.showErrorToast(error.body?.message || error.message || 'Error loading business processes');
            });
    }

    handleBChange(e) {
        this.val = { ...this.val, b: e.detail.value, c: null, sc: null, scc: null };
        this.cats = [];
        this.subCats = [];
        this.subCodes = [];
        getLiveReviewCategoryOptions({ productId: this.val.p, bizId: this.val.b })
            .then(res => { this.cats = res; })
            .catch(error => {
                this.showErrorToast(error.body?.message || error.message || 'Error loading categories');
            });
    }

    handleCChange(e) {
        this.val = { ...this.val, c: e.detail.value, sc: null, scc: null };
        this.subCats = [];
        this.subCodes = [];
        getLiveReviewSubCatOptions({ productId: this.val.p, bizId: this.val.b, catId: this.val.c })
            .then(res => { this.subCats = res; })
            .catch(error => {
                this.showErrorToast(error.body?.message || error.message || 'Error loading sub categories');
            });
    }

    handleSubCatChange(e) {
        this.val = { ...this.val, sc: e.detail.value, scc: null };
        this.subCodes = [];
        getLiveReviewSubCodeOptions({ productId: this.val.p, bizId: this.val.b, catId: this.val.c, subCatId: this.val.sc })
            .then(res => { this.subCodes = res; })
            .catch(error => {
                this.showErrorToast(error.body?.message || error.message || 'Error loading sub codes');
            });
    }

    handleSubCodeChange(e) {
        this.val = { ...this.val, scc: e.detail.value };
    }

    // Search / Query comparison
    handleSearch() {
        if (!this.val.scc) return;
        this.isLoading = true;
        getLiveReviewComparison({
            productId: this.val.p, bizId: this.val.b, catId: this.val.c,
            subCatId: this.val.sc, subCodeId: this.val.scc
        })
            .then(res => {
                const mapRow = (list) => (list || []).map(row => ({
                    ...row, expanded: false, iconName: ICON_CHEVRON_RIGHT
                }));
                this.rawData = {
                    [SECTION_NEW]: mapRow(res[SECTION_NEW]),
                    [SECTION_UPDATED]: mapRow(res[SECTION_UPDATED]),
                    [SECTION_SYNCED]: mapRow(res[SECTION_SYNCED])
                };
            })
            .catch(error => {
                this.showErrorToast(error.body?.message || error.message || 'Error loading comparison data');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Expand / Collapse
    handleExpandAll(e) {
        const sectionId = e.target.dataset.section;
        this.updateSectionExpansion(sectionId, true);
    }

    handleCollapseAll(e) {
        const sectionId = e.target.dataset.section;
        this.updateSectionExpansion(sectionId, false);
    }

    updateSectionExpansion(sectionId, shouldExpand) {
        this.rawData[sectionId] = this.rawData[sectionId].map(item => ({
            ...item,
            expanded: shouldExpand,
            iconName: shouldExpand ? ICON_CHEVRON_DOWN : ICON_CHEVRON_RIGHT
        }));
        this.rawData = { ...this.rawData };
    }

    handleToggle(e) {
        const id = e.currentTarget.dataset.id;
        const toggleInList = (list) => list.map(row =>
            row.externalId === id
                ? { ...row, expanded: !row.expanded, iconName: !row.expanded ? ICON_CHEVRON_DOWN : ICON_CHEVRON_RIGHT }
                : row
        );
        this.rawData = {
            [SECTION_NEW]: toggleInList(this.rawData[SECTION_NEW]),
            [SECTION_UPDATED]: toggleInList(this.rawData[SECTION_UPDATED]),
            [SECTION_SYNCED]: toggleInList(this.rawData[SECTION_SYNCED])
        };
    }

    showErrorToast(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error'
        }));
    }
}