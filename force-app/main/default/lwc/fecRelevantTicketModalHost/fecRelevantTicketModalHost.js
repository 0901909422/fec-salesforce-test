import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';
import searchCases from '@salesforce/apex/FEC_RelevantTicketController.searchCases';
import createRelevantTicket from '@salesforce/apex/FEC_RelevantTicketController.createRelevantTicket';
import TITLE from '@salesforce/label/c.FEC_RelevantTicket_Title';
import REQUIRED_INFO from '@salesforce/label/c.FEC_Required_Information';
import SECTION_INFO from '@salesforce/label/c.FEC_RelevantTicket_Section_Information';
import FIELD_INTERACTION from '@salesforce/label/c.FEC_RelevantTicket_Field_Interaction';
import SEARCH_PLACEHOLDER from '@salesforce/label/c.FEC_RelevantTicket_Search_Placeholder';
import NO_RESULTS from '@salesforce/label/c.FEC_RelevantTicket_No_Results';
import SELECT_REQUIRED from '@salesforce/label/c.FEC_RelevantTicket_Select_Required';
import SAVE_ERROR from '@salesforce/label/c.FEC_RelevantTicket_Save_Error';
import SAVE_SUCCESS from '@salesforce/label/c.FEC_RelevantTicket_Save_Success';
import CANCEL from '@salesforce/label/c.FEC_Button_Cancel';
import SAVE from '@salesforce/label/c.FEC_Button_Save';
import SAVE_AND_NEW from '@salesforce/label/c.FEC_Button_SaveAndNew';
const SIGNAL_KEY = 'fecOpenRelevantTicketModal';
export default class FecRelevantTicketModalHost extends LightningElement {
    @api recordId; @track results = []; isModalOpen = false; searchTerm = ''; selectedId = ''; selectedLabel = ''; errorMsg = ''; isOpen = false; isLoading = false; isSaving = false; timer; poller;
    labels = { title: TITLE, requiredInfo: REQUIRED_INFO, sectionInfo: SECTION_INFO, fieldInteraction: FIELD_INTERACTION, searchPlaceholder: SEARCH_PLACEHOLDER, noResults: NO_RESULTS, cancel: CANCEL, save: SAVE, saveAndNew: SAVE_AND_NEW };
    connectedCallback() { this.poller = window.setInterval(() => this.consumeSignal(), 500); this.consumeSignal(); }
    disconnectedCallback() { window.clearInterval(this.poller); }
    consumeSignal() { try { const raw = window.localStorage.getItem(SIGNAL_KEY); if (!raw) return; const signal = JSON.parse(raw); if (!signal || signal.caseId !== this.recordId) return; window.localStorage.removeItem(SIGNAL_KEY); this.openModal(); } catch (e) {} }
    get showNoResults() { return this.searchTerm && this.searchTerm.length >= 2 && !this.isLoading && this.results.length === 0; }
    openModal() { this.resetForm(); this.isModalOpen = true; } closeModal() { this.isModalOpen = false; this.resetForm(); }
    resetForm() { this.searchTerm=''; this.selectedId=''; this.selectedLabel=''; this.errorMsg=''; this.results=[]; this.isOpen=false; this.isLoading=false; }
    handleInput(event) { this.searchTerm = event.target.value; this.errorMsg = ''; if (!this.searchTerm || this.searchTerm.length < 2) { this.results = []; this.isOpen = false; return; } this.isOpen = true; this.isLoading = true; window.clearTimeout(this.timer); this.timer = window.setTimeout(() => this.doSearch(), 300); }
    handleFocus() { if (this.searchTerm && this.searchTerm.length >= 2) this.isOpen = true; } handleBlur() { window.setTimeout(() => { this.isOpen = false; }, 250); }
    doSearch() { searchCases({ searchTerm: this.searchTerm }).then(data => { this.results = data || []; this.isLoading = false; }).catch(() => { this.results = []; this.isLoading = false; }); }
    handleSelect(event) { this.selectedId = event.currentTarget.dataset.id; this.selectedLabel = event.currentTarget.dataset.label; this.isOpen = false; this.errorMsg = ''; } handleRemove() { this.selectedId=''; this.selectedLabel=''; this.searchTerm=''; this.results=[]; this.errorMsg=''; }
    handleSave() { this.save(false); } handleSaveAndNew() { this.save(true); }
    save(saveAndNew) { if (!this.selectedId) { this.errorMsg = SELECT_REQUIRED; return; } this.isSaving = true; this.errorMsg = ''; createRelevantTicket({ interactionId: this.selectedId, relatedToId: this.recordId }).then(() => { this.dispatchEvent(new ShowToastEvent({ title: SAVE, message: SAVE_SUCCESS, variant: 'success' })); this.dispatchEvent(new RefreshEvent()); if (saveAndNew) this.resetForm(); else this.closeModal(); }).catch(error => { this.errorMsg = this.reduceError(error) || SAVE_ERROR; }).finally(() => { this.isSaving = false; }); }
    reduceError(error) { if (!error) return ''; if (Array.isArray(error.body)) return error.body.map(e => e.message).join(', '); return error.body && error.body.message ? error.body.message : error.message; }
}