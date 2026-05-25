import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
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
import LABEL_FIELD_NAME from '@salesforce/label/c.FEC_Review_Field_Name';
import LABEL_LIVE_VALUE from '@salesforce/label/c.FEC_Review_Live_Value';
import LABEL_MDM_VALUE from '@salesforce/label/c.FEC_Review_MDM_Value';
import LABEL_DIFF_COUNT from '@salesforce/label/c.FEC_Review_Diff_Count';
import {
    ICON_NEW, ICON_UPDATED, ICON_SYNCED,
    ICON_CHEVRON_DOWN, ICON_CHEVRON_RIGHT,
    SECTION_NEW, SECTION_UPDATED, SECTION_SYNCED
} from 'c/fecConstants';

const STATUS_CLASS_MAP = {
    'New': 'status-badge status-new',
    'Update': 'status-badge status-update',
    'Synced': 'status-badge status-synced'
};

const SECTION_META = {
    [SECTION_NEW]: { icon: ICON_NEW, badgeClass: 'section-badge badge-new', summaryClass: 'summary-chip summary-chip-new', headerSuffix: 'new' },
    [SECTION_UPDATED]: { icon: ICON_UPDATED, badgeClass: 'section-badge badge-updated', summaryClass: 'summary-chip summary-chip-updated', headerSuffix: 'updated' },
    [SECTION_SYNCED]: { icon: ICON_SYNCED, badgeClass: 'section-badge badge-synced', summaryClass: 'summary-chip summary-chip-synced', headerSuffix: 'synced' }
};

export default class FecMasterDataReview extends LightningElement {
    isLoading = false;
    @track rawData = { [SECTION_NEW]: [], [SECTION_UPDATED]: [], [SECTION_SYNCED]: [] };
    @track val = { ct: null, p: null, b: null, c: null, sc: null, scc: null };

    @track customerTypes = [];
    @track products = [];
    @track bizs = [];
    @track cats = [];
    @track subCats = [];
    @track subCodes = [];

    @wire(getCustomerTypeOptions)
    wiredCustomerTypes({ data }) { if (data) this.customerTypes = data; }

    @wire(getProductOptions, { customerType: '$val.ct' })
    wiredP({ data }) { if (data) this.products = data; }

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
    labelFieldName = LABEL_FIELD_NAME;
    labelLiveValue = LABEL_LIVE_VALUE;
    labelMdmValue = LABEL_MDM_VALUE;
    labelDiffCount = LABEL_DIFF_COUNT;

    // --- Waterfall Handlers ---
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
        getBizOptions({ productId: this.val.p })
            .then(res => { this.bizs = res; })
            .catch(err => this.showError(err));
    }

    handleBChange(e) {
        this.val = { ...this.val, b: e.detail.value, c: null, sc: null, scc: null };
        this.cats = [];
        this.subCats = [];
        this.subCodes = [];
        getCategoryOptions({ productId: this.val.p, bizId: this.val.b })
            .then(res => { this.cats = res; })
            .catch(err => this.showError(err));
    }

    handleCChange(e) {
        this.val = { ...this.val, c: e.detail.value, sc: null, scc: null };
        this.subCats = [];
        this.subCodes = [];
        getSubCatOptions({ productId: this.val.p, bizId: this.val.b, catId: this.val.c })
            .then(res => { this.subCats = res; })
            .catch(err => this.showError(err));
    }

    handleSubCatChange(e) {
        this.val = { ...this.val, sc: e.detail.value, scc: null };
        this.subCodes = [];
        getSubCodeOptions({ productId: this.val.p, bizId: this.val.b, catId: this.val.c, subCatId: this.val.sc })
            .then(res => { this.subCodes = res; })
            .catch(err => this.showError(err));
    }

    handleSubCodeChange(e) {
        this.val = { ...this.val, scc: e.detail.value };
    }

    // --- Computed ---
    get isSearchDisabled() {
        return this.isLoading || !this.val.scc;
    }

    get hasData() {
        return this.rawData[SECTION_NEW].length > 0
            || this.rawData[SECTION_UPDATED].length > 0
            || this.rawData[SECTION_SYNCED].length > 0;
    }

    get sections() {
        const labels = { [SECTION_NEW]: this.labelNew, [SECTION_UPDATED]: this.labelUpdated, [SECTION_SYNCED]: this.labelSynced };
        return [SECTION_NEW, SECTION_UPDATED, SECTION_SYNCED].map(id => {
            const meta = SECTION_META[id];
            const data = this.rawData[id];
            return {
                id,
                label: labels[id],
                data,
                count: data.length,
                hasData: data.length > 0,
                icon: meta.icon,
                badgeClass: meta.badgeClass,
                summaryClass: meta.summaryClass
            };
        });
    }

    // --- Expand / Collapse ---
    handleExpandAll(e) {
        this.updateSectionExpansion(e.target.dataset.section, true);
    }

    handleCollapseAll(e) {
        this.updateSectionExpansion(e.target.dataset.section, false);
    }

    updateSectionExpansion(sectionId, shouldExpand) {
        this.rawData[sectionId] = this.rawData[sectionId].map(item => ({
            ...item,
            expanded: shouldExpand,
            iconName: shouldExpand ? ICON_CHEVRON_DOWN : ICON_CHEVRON_RIGHT
        }));
        this.rawData = { ...this.rawData };
    }

    // --- Search ---
    handleSearch() {
        if (!this.val.scc) return;
        this.isLoading = true;
        getComparisonData({
            productId: this.val.p, bizId: this.val.b, catId: this.val.c,
            subCatId: this.val.sc, subCodeId: this.val.scc
        }).then(res => {
            const mapRows = (list, sectionId) => list.map(row => {
                const meta = SECTION_META[sectionId];
                const diffs = (row.diffs || []).map(d => ({
                    ...d,
                    rowClass: d.isDifferent ? 'diff-row-changed' : 'diff-row-normal',
                    cellClass: d.isDifferent ? 'col-mdm diff-row-changed' : 'col-mdm'
                }));
                return {
                    ...row,
                    displayName: row.name,
                    hasPropertyName: !!row.propertyName,
                    expanded: false,
                    iconName: ICON_CHEVRON_RIGHT,
                    headerClass: 'row-header row-header-' + meta.headerSuffix,
                    statusClass: STATUS_CLASS_MAP[row.status] || 'status-badge status-synced',
                    diffs
                };
            });
            this.rawData = {
                [SECTION_NEW]: mapRows(res[SECTION_NEW] || [], SECTION_NEW),
                [SECTION_UPDATED]: mapRows(res[SECTION_UPDATED] || [], SECTION_UPDATED),
                [SECTION_SYNCED]: mapRows(res[SECTION_SYNCED] || [], SECTION_SYNCED)
            };
            this.isLoading = false;
        }).catch(err => {
            this.isLoading = false;
            this.showError(err);
        });
    }

    // --- Toggle ---
    handleToggle(e) {
        const id = e.currentTarget.dataset.id;
        const toggle = (list) => list.map(row => {
            if (row.externalId !== id) return row;
            const expanded = !row.expanded;
            return {
                ...row,
                expanded,
                iconName: expanded ? ICON_CHEVRON_DOWN : ICON_CHEVRON_RIGHT
            };
        });
        this.rawData = {
            [SECTION_NEW]: toggle(this.rawData[SECTION_NEW]),
            [SECTION_UPDATED]: toggle(this.rawData[SECTION_UPDATED]),
            [SECTION_SYNCED]: toggle(this.rawData[SECTION_SYNCED])
        };
    }

    // --- Utility ---
    showError(error) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: error.body?.message || error.message || 'Unknown error',
            variant: 'error'
        }));
    }
}