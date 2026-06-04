/**
 * fecHtmlToPdfmake
 * Utility module parse HTML string → pdfmake docDefinition content array.
 * Hỗ trợ các HTML elements phổ biến trong PDF templates:
 *   div, p, span, br, b, strong, i, em, u, table, tr, td, h1-h6, img, ul, ol, li
 * Hỗ trợ inline styles: font-size, text-align, font-weight, font-style,
 *   border, padding, margin, width, color, line-height, text-decoration, padding-left
 *
 * @created  : 2026/04/13 long.nguyen.50
 * @modified :
 */

// ==================== MAIN ENTRY ====================

/**
 * Resolve tất cả <img src="/resource/XXX"> trong HTML thành base64 data URI.
 * Fetch image từ Salesforce Static Resource → convert sang base64 → replace src.
 *
 * @param {string} html - HTML string chứa img tags
 * @returns {Promise<string>} HTML với img src đã convert sang base64
 */
export async function resolveImages(html) {
    if (!html) return html;

    // Tìm tất cả src="/resource/XXX" patterns
    const imgRegex = /src="(\/resource\/[^"]+)"/g;
    const matches = [];
    let match;
    while ((match = imgRegex.exec(html)) !== null) {
        matches.push(match[1]);
    }

    if (matches.length === 0) return html;

    // Deduplicate
    const uniqueSrcs = [...new Set(matches)];

    // Fetch từng image → base64
    let result = html;
    for (const src of uniqueSrcs) {
        try {
            const response = await fetch(src);
            if (!response.ok) continue;
            const blob = await response.blob();
            const base64 = await new Promise((resolve) => {
                const reader = new FileReader();
                reader.onloadend = () => resolve(reader.result);
                reader.readAsDataURL(blob);
            });
            // Replace tất cả occurrences
            result = result.split('src="' + src + '"').join('src="' + base64 + '"');
        } catch (e) {
            // Skip nếu fetch lỗi
        }
    }

    return result;
}

/**
 * Parse HTML string thành pdfmake content array.
 * @param {string} html - HTML string (đã replace placeholders)
 * @param {Object} options - { defaultFontSize, pageWidthPt }
 * @returns {Array} pdfmake content array
 */
export function htmlToPdfmake(html, options = {}) {
    const { defaultFontSize = 12, pageWidthPt = 467 } = options;
    // 467pt = A4 width (595) - margins (61+61) - buffer (6)

    const parser = new DOMParser();
    const doc = parser.parseFromString(`<body>${html}</body>`, "text/html");
    const body = doc.body;

    const ctx = { defaultFontSize, pageWidthPt };
    return parseChildren(body, ctx);
}

// ==================== NODE PARSERS ====================

/**
 * Parse children nodes của một element
 * @param {Element} element
 * @param {Object} ctx - context { defaultFontSize, pageWidthPt }
 * @returns {Array}
 */
function parseChildren(element, ctx) {
    const result = [];
    for (const node of element.childNodes) {
        const parsed = parseNode(node, ctx);
        if (parsed !== null) {
            if (Array.isArray(parsed)) {
                result.push(...parsed);
            } else {
                result.push(parsed);
            }
        }
    }
    return result;
}

/**
 * Parse một DOM node thành pdfmake object
 * @param {Node} node
 * @param {Object} ctx
 * @returns {Object|Array|string|null}
 */
function parseNode(node, ctx) {
    // Text node
    if (node.nodeType === 3) {
        const raw = node.textContent;
        const hasNbsp = raw.indexOf("\u00A0") !== -1;
        // Collapse whitespace thường (space/tab/newline) nhưng giữ \u00A0
        // Sau đó convert \u00A0 → space thường (pdfmake preserveLeadingSpaces sẽ giữ)
        const text = raw
            .replace(/[^\S\u00A0]+/g, " ")
            .replace(/\u00A0/g, " ");
        // Bỏ text node rỗng, nhưng giữ nếu có &nbsp; (indent)
        if (!hasNbsp && text.trim() === "") return null;
        if (text === "") return null;
        return text;
    }

    // Element node
    if (node.nodeType !== 1) return null;

    const tag = node.tagName.toLowerCase();

    switch (tag) {
        case "table":
            return parseTable(node, ctx);
        case "ul":
        case "ol":
            return parseList(node, tag, ctx);
        case "img":
            return parseImg(node);
        case "br":
            return { text: "\n" };
        case "h1":
        case "h2":
        case "h3":
        case "h4":
        case "h5":
        case "h6":
            return parseHeading(node, tag, ctx);
        case "p":
            return parseParagraph(node, ctx);
        case "div":
            return parseDiv(node, ctx);
        case "b":
        case "strong":
            return parseInline(node, ctx, { bold: true });
        case "i":
        case "em":
            return parseInline(node, ctx, { italics: true });
        case "u":
            return parseInline(node, ctx, { decoration: "underline" });
        case "span":
            return parseInline(node, ctx, {});
        default:
            // Fallback: parse children
            return parseChildren(node, ctx);
    }
}

// ==================== ELEMENT PARSERS ====================

/**
 * Parse <table> → pdfmake table object
 */
function parseTable(tableEl, ctx) {
    const rows = [];
    let colCount = 0;
    const trElements = tableEl.querySelectorAll(":scope > tr, :scope > thead > tr, :scope > tbody > tr");

    for (const tr of trElements) {
        const cells = [];
        const tdElements = tr.querySelectorAll(":scope > td, :scope > th");
        for (const td of tdElements) {
            cells.push(parseTableCell(td, ctx));
        }
        if (cells.length > colCount) colCount = cells.length;
        rows.push(cells);
    }

    if (rows.length === 0) return null;

    // Normalize: đảm bảo mỗi row có cùng số cột
    for (const row of rows) {
        while (row.length < colCount) {
            row.push({ text: "", border: [false, false, false, false] });
        }
    }

    // Tính widths từ style của td đầu tiên
    const widths = computeTableWidths(rows[0], colCount, tableEl, ctx);

    const tableStyle = parseStyle(tableEl.getAttribute("style"));
    const tableObj = {
        table: {
            headerRows: 0,
            widths: widths,
            body: rows
        }
    };

    // Xác định layout dựa trên border style
    const hasBorder = hasBorderStyle(tableEl);
    if (!hasBorder) {
        tableObj.layout = "noBorders";
    } else {
        // Detect border color từ cell style
        let borderColor = "#aca899";
        const firstTd = tableEl.querySelector("td, th");
        if (firstTd) {
            const tdStyleStr = firstTd.getAttribute("style") || "";
            const colorMatch = tdStyleStr.match(/border:\s*\d+px\s+solid\s+(#[0-9a-fA-F]{3,6}|[a-z]+)/);
            if (colorMatch) borderColor = colorMatch[1];
        }

        // Detect border-spacing
        let spacing = 0;
        if (tableStyle["border-spacing"]) {
            spacing = parsePxValue(tableStyle["border-spacing"].split(/\s+/)[0]);
        }

        // Detect cell padding
        let cellPadding = 4;
        if (firstTd) {
            const firstTdStyle = parseStyle(firstTd.getAttribute("style"));
            if (firstTdStyle.padding) {
                cellPadding = parsePxValue(firstTdStyle.padding);
            }
        }

        tableObj.layout = {
            hLineWidth: (i, node) => (i === 0 || i === 1 || i === node.table.body.length) ? 0.75 : 0.5,
            vLineWidth: () => 0.5,
            hLineColor: () => borderColor,
            vLineColor: () => borderColor,
            paddingTop: () => cellPadding + spacing,
            paddingBottom: () => cellPadding + spacing,
            paddingLeft: () => cellPadding + spacing,
            paddingRight: () => cellPadding + spacing
        };
    }

    // Margin
    const margin = parseMargin(tableStyle);
    if (margin) tableObj.margin = margin;

    return tableObj;
}

/**
 * Parse <td>/<th> → pdfmake cell object
 */
function parseTableCell(td, ctx) {
    const style = parseStyle(td.getAttribute("style"));
    const children = parseChildren(td, ctx);

    // Flatten nếu chỉ có 1 text child
    let content;
    if (children.length === 0) {
        content = { text: "" };
    } else if (children.length === 1 && typeof children[0] === "string") {
        content = { text: children[0] };
    } else if (children.every((c) => typeof c === "string" || (c && c.text !== undefined && !c.table && !c.ul && !c.ol))) {
        // Tất cả là text/inline → gom thành 1 text array
        content = { text: flattenTextArray(children) };
    } else {
        // Có block elements → dùng stack
        content = { stack: children };
    }

    // Apply styles
    applyTextStyles(content, style, ctx);

    // Đảm bảo alignment từ td style được set ở cell level
    if (style["text-align"] && !content.alignment) {
        content.alignment = style["text-align"];
    }

    // Border per cell
    const cellBorder = hasCellBorder(style);
    if (!cellBorder) {
        content.border = [false, false, false, false];
    }

    // Lưu width để computeTableWidths sử dụng
    if (style.width) {
        content._widthStyle = style.width;
    }

    return content;
}

/**
 * Parse <p> → pdfmake paragraph
 */
function parseParagraph(pEl, ctx) {
    const style = parseStyle(pEl.getAttribute("style"));
    const children = parseChildren(pEl, ctx);

    if (children.length === 0) return { text: "\n" };

    const obj = buildTextOrStack(children);
    applyTextStyles(obj, style, ctx);

    const margin = parseMargin(style);
    if (margin) {
        obj.margin = margin;
    } else {
        obj.margin = [0, 4, 0, 4];
    }

    // Đánh dấu là block paragraph để buildTextOrStack nhận diện
    obj._block = true;

    return obj;
}

/**
 * Parse <div> → pdfmake stack hoặc text
 */
function parseDiv(divEl, ctx) {
    const style = parseStyle(divEl.getAttribute("style"));
    const children = parseChildren(divEl, ctx);

    if (children.length === 0) return null;

    const obj = buildTextOrStack(children);
    applyTextStyles(obj, style, ctx);

    const margin = parseMargin(style);
    if (margin) obj.margin = margin;

    obj._block = true;

    return obj;
}

/**
 * Parse heading h1-h6
 */
function parseHeading(hEl, tag, ctx) {
    const level = parseInt(tag.charAt(1), 10);
    const sizeMap = { 1: 24, 2: 20, 3: 16, 4: 14, 5: 12, 6: 11 };
    const style = parseStyle(hEl.getAttribute("style"));
    const children = parseChildren(hEl, ctx);

    const obj = buildTextOrStack(children);
    obj.bold = true;
    obj.fontSize = sizeMap[level] || 14;
    applyTextStyles(obj, style, ctx);

    const margin = parseMargin(style);
    obj.margin = margin || [0, 8, 0, 6];

    return obj;
}

/**
 * Parse inline elements (b, i, u, span)
 */
function parseInline(el, ctx, attrs) {
    const style = parseStyle(el.getAttribute("style"));
    const children = parseChildren(el, ctx);

    if (children.length === 0) return null;

    // Flatten thành text array
    const textArr = flattenTextArray(children);

    if (textArr.length === 1) {
        const item = typeof textArr[0] === "string" ? { text: textArr[0] } : { ...textArr[0] };
        // Merge attrs — không override existing styles
        for (const key of Object.keys(attrs)) {
            item[key] = attrs[key];
        }
        applyTextStyles(item, style, ctx);
        return item;
    }

    // Nhiều items — apply attrs vào từng item
    const merged = textArr.map((t) => {
        if (typeof t === "string") {
            return { text: t, ...attrs };
        }
        // Merge attrs vào existing object
        const obj = { ...t };
        for (const key of Object.keys(attrs)) {
            obj[key] = attrs[key];
        }
        return obj;
    });

    const obj = { text: merged };
    applyTextStyles(obj, style, ctx);
    return obj;
}

/**
 * Parse <ul>/<ol> → pdfmake list
 */
function parseList(listEl, tag, ctx) {
    const style = parseStyle(listEl.getAttribute("style"));
    const items = [];

    for (const li of listEl.querySelectorAll(":scope > li")) {
        const children = parseChildren(li, ctx);
        if (children.length === 1 && typeof children[0] === "string") {
            items.push(children[0]);
        } else {
            items.push(buildTextOrStack(children));
        }
    }

    const listObj = tag === "ul" ? { ul: items } : { ol: items };
    applyTextStyles(listObj, style, ctx);

    const margin = parseMargin(style);
    if (margin) listObj.margin = margin;

    return listObj;
}

/**
 * Parse <img> → pdfmake image
 * Hỗ trợ base64 data URI và relative /resource/ URLs (đã được pre-process)
 */
function parseImg(imgEl) {
    const src = imgEl.getAttribute("src") || "";
    const style = parseStyle(imgEl.getAttribute("style"));

    // Skip nếu không có src hoặc là relative URL chưa convert
    if (!src || (!src.startsWith("data:") && !src.startsWith("http"))) {
        return null;
    }

    const imgObj = { image: src };

    if (style.width) {
        imgObj.width = parsePxValue(style.width);
    }
    if (style.height && style.height !== "auto") {
        imgObj.height = parsePxValue(style.height);
    }

    if (style["text-align"] === "right") {
        imgObj.alignment = "right";
    } else if (style["text-align"] === "center") {
        imgObj.alignment = "center";
    }

    return imgObj;
}

// ==================== STYLE HELPERS ====================

/**
 * Parse inline style string → object
 * @param {string} styleStr - "font-size: 12pt; text-align: center;"
 * @returns {Object} { "font-size": "12pt", "text-align": "center" }
 */
function parseStyle(styleStr) {
    const result = {};
    if (!styleStr) return result;
    const parts = styleStr.split(";");
    for (const part of parts) {
        const idx = part.indexOf(":");
        if (idx > 0) {
            const key = part.substring(0, idx).trim().toLowerCase();
            const val = part.substring(idx + 1).trim();
            if (key && val) result[key] = val;
        }
    }
    return result;
}

/**
 * Apply text styles từ CSS style object vào pdfmake object
 */
function applyTextStyles(obj, style, ctx) {
    if (!style || Object.keys(style).length === 0) return;

    if (style["font-size"]) {
        obj.fontSize = parseFontSize(style["font-size"], ctx);
    }
    if (style["text-align"]) {
        obj.alignment = style["text-align"];
    }
    if (style["font-weight"] === "bold") {
        obj.bold = true;
    }
    if (style["font-style"] === "italic") {
        obj.italics = true;
    }
    if (style["text-decoration"] === "underline") {
        obj.decoration = "underline";
    }
    if (style.color && style.color !== "inherit") {
        obj.color = style.color;
    }
    if (style["line-height"]) {
        const lh = parseFloat(style["line-height"]);
        if (!isNaN(lh)) {
            // pdfmake lineHeight là multiplier (1.0 = normal)
            obj.lineHeight = lh > 10 ? lh / 100 : lh;
        }
    }
    if (style["font-family"]) {
        obj.font = style["font-family"].replace(/['"]/g, "").trim();
    }
}

/**
 * Parse font-size value → number (pt)
 * Hỗ trợ: "12pt", "16px", "11pt"
 */
function parseFontSize(value, ctx) {
    if (!value) return ctx.defaultFontSize;
    const num = parseFloat(value);
    if (isNaN(num)) return ctx.defaultFontSize;
    if (value.includes("px")) {
        return Math.round(num * 0.75); // px → pt
    }
    return num;
}

/**
 * Parse px/pt value → number
 */
function parsePxValue(value) {
    if (!value) return 0;
    const num = parseFloat(value);
    return isNaN(num) ? 0 : num;
}

/**
 * Parse margin từ style object → [left, top, right, bottom]
 */
function parseMargin(style) {
    if (!style) return null;

    let top = 0;
    let right = 0;
    let bottom = 0;
    let left = 0;
    let hasMargin = false;

    if (style["margin-top"]) {
        top = parsePxValue(style["margin-top"]);
        hasMargin = true;
    }
    if (style["margin-bottom"]) {
        bottom = parsePxValue(style["margin-bottom"]);
        hasMargin = true;
    }
    if (style["margin-left"]) {
        left = parsePxValue(style["margin-left"]);
        hasMargin = true;
    }
    if (style["margin-right"]) {
        right = parsePxValue(style["margin-right"]);
        hasMargin = true;
    }
    if (style.margin) {
        const parts = style.margin.split(/\s+/).map(parsePxValue);
        if (parts.length === 1) {
            top = right = bottom = left = parts[0];
        } else if (parts.length === 2) {
            top = bottom = parts[0];
            right = left = parts[1];
        } else if (parts.length === 4) {
            top = parts[0];
            right = parts[1];
            bottom = parts[2];
            left = parts[3];
        }
        hasMargin = true;
    }

    return hasMargin ? [left, top, right, bottom] : null;
}

/**
 * Check xem table element có border style không
 */
function hasBorderStyle(tableEl) {
    const style = tableEl.getAttribute("style") || "";
    if (style.includes("border:") || style.includes("border-collapse")) {
        // Check nếu có "border: 1px solid" hoặc tương tự
        if (style.match(/border:\s*\d+px\s+solid/)) return true;
    }
    // Check cells
    const firstTd = tableEl.querySelector("td, th");
    if (firstTd) {
        const tdStyle = firstTd.getAttribute("style") || "";
        if (tdStyle.match(/border:\s*\d+px\s+solid/)) return true;
    }
    return false;
}

/**
 * Check xem cell có border không
 */
function hasCellBorder(style) {
    if (!style || !style.border) return false;
    return style.border.match(/\d+px\s+solid/) !== null;
}

/**
 * Tính widths cho table columns
 */
function computeTableWidths(firstRow, colCount, tableEl, ctx) {
    const widths = [];
    const tableStyle = parseStyle(tableEl.getAttribute("style"));
    const tableWidthPct = parseWidthPercent(tableStyle.width);

    for (let i = 0; i < colCount; i++) {
        if (firstRow[i] && firstRow[i]._widthStyle) {
            const w = firstRow[i]._widthStyle;
            if (w === "auto") {
                widths.push("auto");
            } else if (w.includes("%")) {
                widths.push(w);
            } else {
                widths.push(parsePxValue(w));
            }
            delete firstRow[i]._widthStyle;
        } else {
            widths.push("*");
        }
    }

    // Nếu table width < 100%, scale widths
    if (tableWidthPct && tableWidthPct < 100) {
        const scaledPageWidth = (ctx.pageWidthPt * tableWidthPct) / 100;
        for (let i = 0; i < widths.length; i++) {
            if (typeof widths[i] === "string" && widths[i].includes("%")) {
                const pct = parseFloat(widths[i]);
                widths[i] = Math.round((scaledPageWidth * pct) / 100);
            }
        }
    }

    return widths;
}

/**
 * Parse width percentage
 */
function parseWidthPercent(value) {
    if (!value || !value.includes("%")) return null;
    return parseFloat(value);
}

// ==================== TEXT HELPERS ====================

/**
 * Build pdfmake text object hoặc stack từ children array.
 * Nếu tất cả children là text/inline → trả về { text: [...] }
 * Nếu có block elements (table, list) → trả về { stack: [...] }
 */
function buildTextOrStack(children) {
    if (children.length === 0) return { text: "" };

    // Nếu chỉ có 1 child và nó là object (không phải string) → trả về trực tiếp
    if (children.length === 1 && typeof children[0] !== "string" && children[0] !== null) {
        return children[0];
    }

    const isBlock = (c) =>
        c && typeof c !== "string" && (c.table || c.ul || c.ol || c.stack || c.image || c._block);

    const hasBlockEl = children.some(isBlock);

    if (hasBlockEl) {
        // Gom các inline items liên tiếp thành 1 text block
        const stackItems = [];
        let inlineBuf = [];

        const flushInline = () => {
            if (inlineBuf.length === 0) return;
            const textArr = flattenTextArray(inlineBuf);
            if (textArr.length === 1 && typeof textArr[0] === "string") {
                stackItems.push({ text: textArr[0] });
            } else if (textArr.length === 1) {
                stackItems.push(textArr[0]);
            } else if (textArr.length > 0) {
                stackItems.push({ text: textArr });
            }
            inlineBuf = [];
        };

        for (const child of children) {
            if (isBlock(child)) {
                flushInline();
                stackItems.push(child);
            } else {
                inlineBuf.push(child);
            }
        }
        flushInline();

        if (stackItems.length === 1) return stackItems[0];
        return { stack: stackItems };
    }

    // Tất cả inline → flatten thành text array
    const textArr = flattenTextArray(children);
    if (textArr.length === 1 && typeof textArr[0] === "string") {
        return { text: textArr[0] };
    }
    if (textArr.length === 1) {
        return textArr[0];
    }
    return { text: textArr };
}

/**
 * Flatten nested text arrays thành flat array cho pdfmake.
 * pdfmake text array: [string | {text, bold, ...}, ...]
 */
function flattenTextArray(items) {
    const result = [];
    for (const item of items) {
        if (item === null || item === undefined) continue;
        if (typeof item === "string") {
            result.push(item);
        } else if (item.text !== undefined && !item.table && !item.ul && !item.ol && !item.stack && !item.image && !item._block) {
            // Inline text object
            if (Array.isArray(item.text)) {
                // Nested text array — flatten nhưng giữ styles
                for (const sub of item.text) {
                    if (typeof sub === "string") {
                        const wrapper = { text: sub };
                        copyInlineStyles(item, wrapper);
                        result.push(wrapper);
                    } else {
                        const merged = { ...sub };
                        copyInlineStyles(item, merged);
                        result.push(merged);
                    }
                }
            } else {
                result.push(item);
            }
        } else {
            // Block element trong inline context — giữ nguyên
            result.push(item);
        }
    }
    return result;
}

/**
 * Copy inline styles từ parent sang child (nếu child chưa có)
 */
function copyInlineStyles(parent, child) {
    if (parent.bold) child.bold = true;
    if (parent.italics) child.italics = true;
    if (parent.decoration) child.decoration = parent.decoration;
    if (parent.fontSize && !child.fontSize) child.fontSize = parent.fontSize;
    if (parent.color && !child.color) child.color = parent.color;
}

// ==================== PLACEHOLDER ENGINE ====================

/**
 * Replace Pega-style placeholders trong HTML template.
 * Tương tự FEC_PDFGeneratorService.replacePlaceholders() nhưng chạy client-side.
 *
 * Hỗ trợ:
 *   - <pega:reference name=".Key"></pega:reference>
 *   - <pega:reference name="pyWorkPage.Key"></pega:reference>
 *   - <pega:reference format="VNDate" name=".Key"></pega:reference>
 *   - <pega:forEach name=".ListName">...</pega:forEach>
 *   - $this.FieldName trong forEach
 *
 * @param {string} template - HTML template string
 * @param {Object} params - { key: value, _rows: JSON array string }
 * @returns {string} HTML đã replace
 */
export function replacePlaceholders(template, params) {
    if (!template) return "";
    if (!params || Object.keys(params).length === 0) return template;

    let result = template;

    //PhongBT 02/06/26: {{TODAY}} ưu tiên params.TODAY (Case.CreatedDate), không thì ngày hệ thống
    let strToday = params.TODAY != null && String(params.TODAY).trim() !== ""
        ? String(params.TODAY).trim()
        : null;
    if (!strToday) {
        const dtToday = new Date();
        strToday =
            String(dtToday.getDate()).padStart(2, "0") +
            "/" +
            String(dtToday.getMonth() + 1).padStart(2, "0") +
            "/" +
            dtToday.getFullYear();
    }
    result = result.replace(/\{\{TODAY\}\}/g, strToday);

    // 1. Process forEach
    result = processForEach(result, params);

    // 2. Replace placeholders
    for (const key of Object.keys(params)) {
        if (key === "_rows") continue;
        const value = params[key] != null ? String(params[key]) : "";
        const escapedKey = escapeRegex(key);

        // Dạng có format attribute
        const fmtRegex = new RegExp(
            `<pega:reference\\s+format="([^"]*)"\\s+name="[^"]*\\.${escapedKey}"\\s*>[\\s\\S]*?</pega:reference>`,
            "g"
        );
        result = result.replace(fmtRegex, (match, format) => applyFormat(value, format));

        // Dạng plain
        const plainRegex = new RegExp(
            `<pega:reference\\s+name="[^"]*\\.${escapedKey}"\\s*>[\\s\\S]*?</pega:reference>`,
            "g"
        );
        result = result.replace(plainRegex, value);
    }

    return result;
}

/**
 * Process pega:forEach blocks
 */
function processForEach(template, params) {
    const forEachRegex = /<pega:forEach[^>]*>([\s\S]*?)<\/pega:forEach>/gi;
    const match = forEachRegex.exec(template);
    if (!match) return template;

    const fullMatch = match[0];
    const rowTemplate = match[1];

    const rowsJson = params._rows;
    if (!rowsJson) {
        return template.replace(fullMatch, "");
    }

    let rows;
    try {
        rows = typeof rowsJson === "string" ? JSON.parse(rowsJson) : rowsJson;
    } catch (e) {
        return template.replace(fullMatch, "");
    }

    let rendered = "";
    for (const row of rows) {
        let rowHtml = rowTemplate;
        for (const field of Object.keys(row)) {
            const val = row[field] != null ? String(row[field]) : "";

            // $this.Field với format
            const fmtRegex = new RegExp(
                `<pega:reference\\s+format="([^"]*)"\\s+name="\\$this\\.${escapeRegex(field)}"\\s*>[\\s\\S]*?</pega:reference>`,
                "g"
            );
            rowHtml = rowHtml.replace(fmtRegex, (m, fmt) => applyFormat(val, fmt));

            // $this.Field plain
            rowHtml = rowHtml.replace(
                new RegExp(`<pega:reference\\s+name="\\$this\\.${escapeRegex(field)}"\\s*>[\\s\\S]*?</pega:reference>`, "g"),
                val
            );
        }
        rendered += rowHtml;
    }

    return template.replace(fullMatch, rendered);
}

/**
 * Apply format (client-side version)
 */
function applyFormat(value, format) {
    if (!value || !format) return value || "";

    if (format === "VNDate") {
        return formatVNDate(value);
    }
    if (format === "Date" || format === "ChangeFormatDate") {
        return formatDate(value);
    }
    if (format === "FormatCurrency" || format === "CurrencyAmount") {
        return formatCurrency(value);
    }
    if (format === "Uppercase") {
        return String(value).toUpperCase();
    }
    if (format === "Lowercase") {
        return String(value).toLowerCase();
    }
    return value;
}

function formatVNDate(dateStr) {
    const parts = dateStr.split("-");
    if (parts.length === 3) {
        return `ngày ${parseInt(parts[2], 10)} tháng ${parseInt(parts[1], 10)} năm ${parts[0]}`;
    }
    return dateStr;
}

function formatDate(dateStr) {
    const parts = dateStr.split("-");
    if (parts.length === 3) {
        return `${parts[2]}/${parts[1]}/${parts[0]}`;
    }
    return dateStr;
}

function formatCurrency(value) {
    const num = parseFloat(String(value).replace(/[,.]/g, ""));
    if (isNaN(num)) return value;
    return num.toLocaleString("en-US");
}

function escapeRegex(str) {
    return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}