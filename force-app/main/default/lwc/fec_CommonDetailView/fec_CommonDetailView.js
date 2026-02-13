/****************************************************************************************
 * File Name    : Fec_CommonDetailViewailView.js
 * Author       : Quangdv7
 * Date         : 2025-01-16
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-16     Quangdv7             Create
 
****************************************************************************************/

import { LightningElement, api, track } from 'lwc';

export default class Fec_CommonDetailViewailView extends LightningElement {

    /* ================= PUBLIC API ================= */
    @api title;
    @api subTitle;
    @api iconName = 'standard:orders';

    @api forceTwoColumn = false;
    @api columns;

    /* ================= INTERNAL STATE ================= */
    _sections = [];
    @track activeSections = [];

    /* ================= SECTIONS ================= */
    @api
    get sections() {
        return this._sections;
    }
    set sections(value) {
        this._sections = value || [];
        this.activeSections = this._sections.map(sec => sec.name);
    }

    /* ================= LAYOUT LOGIC ================= */
    get isSingleSection() {
        return this._sections.length === 1;
    }

    get useTwoColumn() {
        if (this.forceTwoColumn) {
            return true;
        }
        return !this.isSingleSection;
    }
    
    get resolvedColumns() {
        if (this.columns) {
            const col = Number(this.columns);
            return Math.min(Math.max(col, 1), 4);
        }

        if (this.forceTwoColumn) {
            return 2;
        }

        return this.isSingleSection ? 1 : 2;
    }

    getFieldColClassByColumns(columns) {
        switch (Number(columns)) {
            case 4:
                return 'slds-col slds-size_1-of-4 slds-p-around_x-small';
            case 3:
                return 'slds-col slds-size_1-of-3 slds-p-around_x-small';
            case 2:
                return 'slds-col slds-size_1-of-2 slds-p-around_x-small';
            default:
                return 'slds-col slds-size_1-of-1 slds-p-around_x-small';
        }
    }
    
    set sections(value) {
        this._sections = (value || []).map(sec => ({
            ...sec,
            fieldColClass: this.getFieldColClassByColumns(
                sec.columns ?? this.columns
            )
        }));

        this.activeSections = this._sections.map(sec => sec.name);
    }

    /* ================= EVENTS ================= */
    handleToggle(event) {
        event.stopPropagation();

        const fieldName = event.currentTarget.dataset.field;
        const sectionName = event.currentTarget.dataset.section;

        this.dispatchEvent(
            new CustomEvent('toggle', {
                detail: { fieldName, sectionName },
                bubbles: true,
                composed: true
            })
        );
    }
}