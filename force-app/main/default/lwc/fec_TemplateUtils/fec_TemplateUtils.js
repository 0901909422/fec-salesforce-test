/**
 * @description  Reusable helper / utility functions for Template Management.
 *               Components import these instead of duplicating filter / transform logic.
 * @module       fec_TemplateUtils
 */

import { FILTER_ALL } from 'c/fec_TemplateConstants';

/**
 * Filter an array of template objects based on the supplied criteria.
 * All filters are optional — pass empty string / 'All' to skip a filter.
 *
 * @param {Array}  templates       – source array of template mock objects
 * @param {Object} filters
 * @param {String} filters.searchText    – free-text search (matches name or subject)
 * @param {String} filters.folderId      – selected folder id (null = all)
 * @param {String} filters.filterActive  – 'All' | 'Yes' | 'No'
 * @returns {Array} filtered template list
 */
export function filterTemplates(templates, filters = {}) {
    const {
        searchText = '',
        folderId = null,
        filterActive = FILTER_ALL
    } = filters;

    const search = searchText.toLowerCase().trim();

    return templates.filter((tmpl) => {
        /* Free-text search on name & subject */
        if (search) {
            const nameMatch    = (tmpl.name || '').toLowerCase().includes(search);
            const subjectMatch = (tmpl.subject || '').toLowerCase().includes(search);
            if (!nameMatch && !subjectMatch) return false;
        }

        /* Folder filter */
        if (folderId && tmpl.folderId !== folderId) return false;

        /* Active filter */
        if (filterActive && filterActive !== FILTER_ALL) {
            const isActiveExpected = filterActive === 'Yes';
            if (tmpl.isActive !== isActiveExpected) return false;
        }

        return true;
    });
}

/**
 * Filter folder records client-side.
 *
 * @param {Array}  folders     – source array of folder mock objects
 * @param {String} searchText  – free-text search on name / description
 * @returns {Array} filtered folder list
 */
export function filterFolders(folders, searchText = '') {
    if (!searchText) return [...folders];

    const search = searchText.toLowerCase().trim();

    return folders.filter((f) => {
        const nameMatch = (f.name || '').toLowerCase().includes(search);
        const descMatch = (f.description || '').toLowerCase().includes(search);
        return nameMatch || descMatch;
    });
}

/**
 * Map a boolean `isActive` flag to a user-friendly display string.
 *
 * @param {Boolean} isActive
 * @returns {String} 'Yes' | 'No'
 */
export function formatActiveLabel(isActive) {
    return isActive ? 'Yes' : 'No';
}

/**
 * Auto-generate an API name from a label string.
 * Rule: replace spaces and special chars with underscores.
 *
 * @param {String} label – the user-visible label
 * @returns {String} API-safe name
 */
export function generateApiName(label) {
    if (!label) return '';
    return label
        .trim()
        .replace(/[^a-zA-Z0-9_]/g, '_')   // non-alphanumeric → underscore
        .replace(/_+/g, '_')               // collapse consecutive underscores
        .replace(/^_|_$/g, '');             // trim leading/trailing underscores
}

/**
 * Format file size (bytes) to a human-readable string.
 *
 * @param {Number} bytes
 * @returns {String} e.g. "1.2 MB", "245 KB"
 */
export function formatFileSize(bytes) {
    if (!bytes || bytes === 0) return '0 KB';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1048576) return `${(bytes / 1024).toFixed(0)} KB`;
    return `${(bytes / 1048576).toFixed(1)} MB`;
}