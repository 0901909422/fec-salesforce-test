import { LightningElement, api } from 'lwc';

export default class Fec_CommonRecordDetailSection extends LightningElement {
    /* ================= API ================= */
    @api sectionTitle;
    @api showRefreshButton = false;

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
                detail: {
                    section: this.sectionTitle
                },
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

        this.fields.forEach((field, index) => {
            /* ===== BUTTON ROW ===== */
            if (field.type === 'button') {
                if (currentRow.length) {
                    this.normalizeRow(rows, currentRow);
                    currentRow = [];
                }

                rows.push({
                    key: `row-${rows.length}`,
                    isButtonRow: true,
                    buttons: field.buttons || []
                });
                return;
            }

            /* ===== FIELD ===== */
            const colspan = field.colspan || 1;
            const syncStatus = field.syncStatus || 'NONE';

            currentRow.push({
                ...field,
                key: `field-${index}`,
                colspan,
                isEmpty: !field.label,

                /* ===== TYPE FLAGS ===== */
                isEmail: field.type === 'email',
                isUrl: field.type === 'url',
                hasAction: field.action === true,
                isRegular:
                    field.type !== 'email' &&
                    field.type !== 'url' &&
                    field.action !== true,

                /* ===== SYNC STATUS ICON ===== */
                showSuccess: syncStatus === 'SUCCESS',
                showError: syncStatus === 'ERROR',

                /* ===== HELPTEXT (NEW) ===== */
                hasHelpText: !!field.helpText,
                helpText: field.helpText,

                /* ===== HELPERS ===== */
                emailHref:
                    field.type === 'email' ? `mailto:${field.value}` : '',
                actionIcon: field.actionIcon || 'utility:edit',
                actionLabel: field.actionLabel || 'Action',
                isFullWidth: colspan === 2
            });

            if (colspan === 2 || currentRow.length === 2) {
                rows.push({
                    key: `row-${rows.length}`,
                    fields: [...currentRow]
                });
                currentRow = [];
            }
        });

        if (currentRow.length) {
            this.normalizeRow(rows, currentRow);
        }

        return rows;
    }

    normalizeRow(rows, row) {
        if (row.length === 1 && !row[0].isFullWidth) {
            row.push({
                key: `field-empty-${rows.length}`,
                isEmpty: true
            });
        }

        rows.push({
            key: `row-${rows.length}`,
            fields: [...row]
        });
    }
}