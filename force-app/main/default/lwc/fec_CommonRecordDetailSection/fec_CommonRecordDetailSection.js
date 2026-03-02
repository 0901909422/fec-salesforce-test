/****************************************************************************************
 * File Name    : Fec_CommomRecordDetailSection.js
 * Author       : Quangdv7
 * Date         : 2025-01-10
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-10     Quangdv7             Create
 
****************************************************************************************/

import { LightningElement, api } from 'lwc';
import { isNegative } from 'c/fec_CommonUtils';

export default class Fec_CommonRecordDetailSection extends LightningElement {
    /* ================= API ================= */
    @api sectionTitle;
    @api showRefreshButton = false;
    @api columns = 2;

    /* ================= PRIVATE STATE ================= */
    _fields = [];

    /* ================= FIELDS ================= */
    @api
    set fields(value) {
        this._fields = Array.isArray(value) ? value : [];
    }
    get fields() {
        return this._fields;
    }

    /* ================= EVENTS ================= */

    handleRefresh(event) {
        event.stopPropagation();

        this.dispatchEvent(
            new CustomEvent('refresh', {
                detail: { section: this.sectionTitle },
                bubbles: true,
                composed: true
            })
        );
    }

    handleButtonClick(event) {
        event.stopPropagation();

        const buttonName = event.currentTarget.dataset.name;

        this.dispatchEvent(
            new CustomEvent('buttonclick', {
                detail: {
                    section: this.sectionTitle,
                    buttonName
                },
                bubbles: true,
                composed: true
            })
        );
    }

    handleActionClick(event) {
        event.stopPropagation();

        const fieldKey = event.currentTarget.dataset.key;
        const field = this.fields.find(
            (f, index) => `field-${index}` === fieldKey
        );

        this.dispatchEvent(
            new CustomEvent('fieldaction', {
                detail: {
                    section: this.sectionTitle,
                    field
                },
                bubbles: true,
                composed: true
            })
        );
    }

    /* ================= ROW BUILDER ================= */

    get rows() {
        const rows = [];
        let currentRow = [];
        let currentSpan = 0;

        this.fields.forEach((field, index) => {
            /* ===== BUTTON ROW ===== */
            if (field.type === 'button') {
                if (currentRow.length) {
                    this.finalizeRow(rows, currentRow);
                    currentRow = [];
                    currentSpan = 0;
                }

                rows.push({
                    key: `row-${rows.length}`,
                    isButtonRow: true,
                    buttons: field.buttons || [],
                    buttonRowClass:
                        field.align === 'right'
                            ? 'slds-m-vertical_x-small slds-grid slds-grid_align-end'
                            : 'slds-m-vertical_x-small slds-grid'
                });
                return;
            }

            const colspan = Math.min(field.colspan || 1, this.columns);
            const syncStatus = field.syncStatus || 'NONE';

            if (currentSpan + colspan > this.columns) {
                this.finalizeRow(rows, currentRow);
                currentRow = [];
                currentSpan = 0;
            }

            const isNeg = isNegative(field.value);
            currentRow.push({
                ...field,
                key: `field-${index}`,
                colspan,
                isEmpty: !field.label,

                /* ===== GRID ===== */
                gridClass: `slds-size_${colspan}-of-${this.columns}`,
                
                /* ===== VALUE STYLE ===== */
                valueClass: isNeg ? 'text-negative' : '',

                /* ===== SYNC STATUS ===== */
                showSuccess: syncStatus === 'SUCCESS',
                showError: syncStatus === 'ERROR',

                /* ===== HELP TEXT ===== */
                hasHelpText: !!field.helpText,
                helpText: field.helpText,

                /* ===== HELPERS ===== */
                isEmail: field.type === 'email',
                isUrl: field.type === 'url',
                hasAction: field.action === true,

                emailHref:
                    field.type === 'email'
                        ? `mailto:${field.value}`
                        : '',
                actionIcon: field.actionIcon || 'utility:edit',
                actionLabel: field.actionLabel || 'Action'
            });

            currentSpan += colspan;

            if (currentSpan === this.columns) {
                this.finalizeRow(rows, currentRow);
                currentRow = [];
                currentSpan = 0;
            }
        });
    
        if (currentRow.length) {
            this.finalizeRow(rows, currentRow);
        }

        return rows;
    }

    /* ================= HELPERS ================= */

    finalizeRow(rows, row) {
        let usedSpan = row.reduce(
            (sum, f) => sum + (f.colspan || 1),
            0
        );

        while (usedSpan < this.columns) {
            row.push({
                key: `empty-${rows.length}-${usedSpan}`,
                isEmpty: true,
                colspan: 1,
                gridClass: `slds-size_1-of-${this.columns}`
            });
            usedSpan++;
        }

        rows.push({
            key: `row-${rows.length}`,
            fields: [...row]
        });
    }
}