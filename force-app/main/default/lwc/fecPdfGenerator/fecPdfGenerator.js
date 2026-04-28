/**
 * fecPdfGenerator
 * Service LWC component (không có UI) - chỉ để được gọi từ component khác.
 * Chức năng: Tạo PDF từ HTML template, trả về base64 string.
 *
 * Usage:
 *   const generator = this.template.querySelector('c-fec-pdf-generator');
 *   const { base64, fileName } = await generator.generatePdf('TEMPLATE_CODE', { key: value });
 *
 * @created  : 2026/04/13 long.nguyen.50
 * @modified : 2026/04/22 - Refactor thành service component, bỏ UI và download/save
 */
import { LightningElement, api } from "lwc";
import { loadScript } from "lightning/platformResourceLoader";
import PDFMAKE from "@salesforce/resourceUrl/FEC_pdfmake";
import PDFMAKE_VFS from "@salesforce/resourceUrl/FEC_pdfmakeVfs";
import FONT_REGULAR from "@salesforce/resourceUrl/FEC_TimesNewRoman";
import FONT_BOLD from "@salesforce/resourceUrl/FEC_TimesNewRomanBold";
import FONT_ITALIC from "@salesforce/resourceUrl/FEC_TimesNewRomanItalic";
import FONT_BOLDITALIC from "@salesforce/resourceUrl/FEC_TimesNewRomanBoldItalic";
import getTemplateData from "@salesforce/apex/FEC_ClientPDFService.getTemplateData";
import { htmlToPdfmake, replacePlaceholders, resolveImages } from "./fecHtmlToPdfmake";

// ==================== CONSTANTS ====================
const FONT_NAME = "TimesNewRoman";
const FONT_FILES = {
    regular: "TNR-Regular.ttf",
    bold: "TNR-Bold.ttf",
    italic: "TNR-Italic.ttf",
    bolditalic: "TNR-BoldItalic.ttf"
};
const PDF_CONFIG = {
    pageSize: "A4",
    pageMargins: [30, 10, 30, 40],
    defaultFontSize: 12
};
const CHUNK_SIZE = 8192; // bytes per chunk for base64 conversion

// ==================== MODULE STATE ====================
let cachedFonts = null;
let pdfMakeLoaded = false;

export default class FecPdfGenerator extends LightningElement {
    /**
     * Tạo PDF từ template code và params.
     * @param {string} strTemplateCode - Mã template (VD: 'LSTT', 'XNTL_HDTD')
     * @param {Object} params - Key-value params để replace placeholders
     * @returns {Promise<{base64: string, fileName: string}>}
     */
    @api
    async generatePdf(strTemplateCode, params = {}) {
        // 1. Load pdfmake
        await this._loadPdfMake();
        const fonts = await this._loadFonts();
        this._registerFonts(fonts);

        // 2. Chuẩn bị params - stringify _rows nếu là array
        const processedParams = { ...params };
        if (processedParams._rows && Array.isArray(processedParams._rows)) {
            processedParams._rows = JSON.stringify(processedParams._rows);
        }

        // 3. Lấy HTML template từ Apex
        const templateData = await getTemplateData({ strTemplateCode });
        const htmlBody = templateData.htmlBody;
        const fileName = templateData.fileName || strTemplateCode;

        // 4. Replace placeholders
        const renderedHtml = replacePlaceholders(htmlBody, processedParams);

        // 5. Resolve images (/resource/Logo → base64)
        const htmlWithImages = await resolveImages(renderedHtml);

        // 6. Parse HTML → pdfmake content
        const content = htmlToPdfmake(htmlWithImages);

        // 7. Build docDefinition & render
        const docDefinition = {
            pageSize: PDF_CONFIG.pageSize,
            pageMargins: PDF_CONFIG.pageMargins,
            defaultStyle: {
                font: FONT_NAME,
                fontSize: PDF_CONFIG.defaultFontSize,
                preserveLeadingSpaces: true
            },
            content: content
        };

        // eslint-disable-next-line no-undef
        const base64 = await new Promise((resolve, reject) => {
            try {
                // eslint-disable-next-line no-undef
                pdfMake.createPdf(docDefinition).getBase64((b64) => resolve(b64));
            } catch (err) {
                reject(err);
            }
        });

        return { base64, fileName };
    }

    // ==================== PRIVATE HELPERS ====================

    async _loadPdfMake() {
        if (pdfMakeLoaded) return;
        await loadScript(this, PDFMAKE);
        await loadScript(this, PDFMAKE_VFS);
        pdfMakeLoaded = true;
    }

    async _loadFonts() {
        if (cachedFonts) return cachedFonts;
        const [r, b, i, bi] = await Promise.all([
            fetch(FONT_REGULAR).then((res) => res.arrayBuffer()),
            fetch(FONT_BOLD).then((res) => res.arrayBuffer()),
            fetch(FONT_ITALIC).then((res) => res.arrayBuffer()),
            fetch(FONT_BOLDITALIC).then((res) => res.arrayBuffer())
        ]);
        cachedFonts = {
            regular: this._toBase64(r),
            bold: this._toBase64(b),
            italic: this._toBase64(i),
            bolditalic: this._toBase64(bi)
        };
        return cachedFonts;
    }

    _toBase64(buffer) {
        const bytes = new Uint8Array(buffer);
        let binary = "";
        for (let j = 0; j < bytes.length; j += CHUNK_SIZE) {
            binary += String.fromCharCode(...bytes.subarray(j, j + CHUNK_SIZE));
        }
        return btoa(binary);
    }

    _registerFonts(fonts) {
        // eslint-disable-next-line no-undef
        pdfMake.vfs = pdfMake.vfs || {};
        // eslint-disable-next-line no-undef
        pdfMake.vfs[FONT_FILES.regular] = fonts.regular;
        // eslint-disable-next-line no-undef
        pdfMake.vfs[FONT_FILES.bold] = fonts.bold;
        // eslint-disable-next-line no-undef
        pdfMake.vfs[FONT_FILES.italic] = fonts.italic;
        // eslint-disable-next-line no-undef
        pdfMake.vfs[FONT_FILES.bolditalic] = fonts.bolditalic;
        // eslint-disable-next-line no-undef
        pdfMake.fonts = {
            [FONT_NAME]: {
                normal: FONT_FILES.regular,
                bold: FONT_FILES.bold,
                italics: FONT_FILES.italic,
                bolditalics: FONT_FILES.bolditalic
            }
        };
    }
}
