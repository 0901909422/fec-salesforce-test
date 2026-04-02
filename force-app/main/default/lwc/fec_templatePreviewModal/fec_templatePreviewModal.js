/**
 * @description  Template Preview Modal – displays a read-only preview of the
 *               email template with Subject and Body rendered as rich HTML.
 *               Used by both the Template Editor and Template Detail Page.
 * @component    fec_templatePreviewModal
 */
import { LightningElement, api, track } from 'lwc';

export default class Fec_templatePreviewModal extends LightningElement {

    /** Subject line text */
    @api subject = '';

    /** Email body HTML content */
    @api emailBody = '';

    /** Letterhead header HTML (optional – from Enhanced Letterhead) */
    @api headerHtml = '';

    /** Letterhead footer HTML (optional – from Enhanced Letterhead) */
    @api footerHtml = '';

    /** Controls modal visibility */
    _isOpen = false;

    @api
    get isOpen() { return this._isOpen; }
    set isOpen(value) {
        this._isOpen = !!value;
        if (this._isOpen) {
            this._bodyRendered = false;
        }
    }

    /** Flag to render body HTML only once per open */
    _bodyRendered = false;

    /* ═══════════════════════════════════════════ */
    /*  COMPUTED                                   */
    /* ═══════════════════════════════════════════ */

    get subjectDisplay() {
        return this.subject || '(No subject)';
    }

    /* ═══════════════════════════════════════════ */
    /*  LIFECYCLE                                  */
    /* ═══════════════════════════════════════════ */

    renderedCallback() {
        if (this._isOpen && !this._bodyRendered) {
            const container = this.template.querySelector('.preview-body-container');
            if (container) {
                // Compose: letterhead header → body → letterhead footer
                const header = this.headerHtml || '';
                const body   = this.emailBody || '<p style="color:#706e6b;">No body content.</p>';
                const footer = this.footerHtml || '';
                container.innerHTML = header + body + footer;
                this._bodyRendered = true;
            }
        }
    }

    /* ═══════════════════════════════════════════ */
    /*  HANDLERS                                   */
    /* ═══════════════════════════════════════════ */

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    /** Close modal on backdrop click */
    handleBackdropClick() {
        this.handleClose();
    }
}