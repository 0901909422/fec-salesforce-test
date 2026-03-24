# FEC CSS Best Practices & Standards

## Overview

This document outlines the CSS standards and best practices for the FEC (Financial Engagement Center) project. These standards ensure consistency, maintainability, and accessibility across all components.

## Core Principles

### 1. Use SLDS Design Tokens

**Always use SLDS design tokens instead of hard-coded values.**

```css
/* ❌ BAD */
background-color: #f3f3f3;
font-size: 13px;
padding: 8px 0 4px;

/* ✅ GOOD */
background-color: var(--lwc-colorBackground, #f3f3f3);
font-size: var(--lwc-fontSize4, 0.875rem);
padding: var(--lwc-spacingXSmall, 0.5rem) 0 var(--lwc-spacingXxxSmall, 0.125rem);
```

**Benefits:**

- Consistency with Lightning Design System
- Theme and dark mode support
- Easy maintenance when SLDS updates
- Better performance with CSS variables

### 2. Create Custom Classes (Don't Override SLDS)

**Create custom classes instead of overriding SLDS classes.**

```css
/* ❌ BAD */
.THIS .slds-accordion__section {
  background: #fff;
}
.THIS .slds-icon {
  fill: #0070d2;
}

/* ✅ GOOD */
.THIS .fec-accordion-section {
  background: var(--lwc-colorBackgroundAlt, #fff);
}
.THIS .fec-icon {
  fill: var(--lwc-colorTextLink, #0070d2);
}
```

**Custom Class Naming Convention:**

- `fec-` prefix for all FEC custom classes
- `fec-component-name` for component-specific classes
- `fec-utility-name` for utility classes

### 3. Mobile-First Font Sizes

**Use minimum 14px (0.875rem) font size for mobile readability.**

```css
/* Minimum font sizes: */
-- Desktop: 14px (0.875rem) minimum
-- Mobile: 14px (0.875rem) minimum
-- Small text: 13px (0.8125rem) minimum
-- Very small: 12px (0.75rem) minimum (avoid when possible)
```

### 4. Responsive Design

**Implement mobile-first responsive design with media queries.**

```css
/* Base styles (mobile first) */
.THIS .component {
  width: 100%;
  padding: var(--lwc-spacingSmall, 0.75rem);
}

/* Tablet and up */
@media (min-width: 768px) {
  .THIS .component {
    width: 50%;
    padding: var(--lwc-spacingMedium, 1rem);
  }
}

/* Desktop */
@media (min-width: 1024px) {
  .THIS .component {
    width: 33.333%;
    padding: var(--lwc-spacingLarge, 1.25rem);
  }
}
```

### 5. Accessibility Requirements

**Ensure all components meet WCAG 2.1 AA standards.**

#### Color Contrast

- Text: Minimum 4.5:1 contrast ratio
- Large text: Minimum 3:1 contrast ratio
- UI components: Minimum 3:1 contrast ratio

#### Focus States

```css
.THIS .focussable-element:focus {
  outline: var(--lwc-borderWidthThick, 2px) solid
    var(--lwc-colorBorderBrand, #0176d3);
  outline-offset: var(--lwc-spacingXxxSmall, 0.125rem);
}
```

#### Tap Target Size

- Minimum 44x44px for touch targets
- Use `min-height` and `min-width` for interactive elements

### 6. CSS Structure

**Organize CSS in this order:**

```css
/* 1. Custom properties (CSS variables) */
:host {
  --fec-primary-color: var(--lwc-colorBrand, #0176d3);
}

/* 2. Reset/normalize styles */
.THIS { box-sizing: border-box; }

/* 3. Base component styles */
.THIS .component { ... }

/* 4. Component variations */
.THIS .component--variant { ... }

/* 5. State styles (hover, focus, active) */
.THIS .component:hover { ... }
.THIS .component:focus { ... }

/* 6. Utility classes */
.THIS .fec-text-center { text-align: center; }

/* 7. Media queries (mobile first) */
@media (min-width: 768px) { ... }

/* 8. Print styles */
@media print { ... }
```

### 7. Performance Optimizations

#### Avoid !important

- Use specificity instead of `!important`
- Only use `!important` for utility classes that need to override

#### Minimize Specificity

- Keep selectors as simple as possible
- Avoid nested selectors more than 3 levels deep

#### Use CSS Variables

- Define reusable values as CSS variables
- Reduces duplication and improves maintainability

### 8. Testing Requirements

#### Browser Support

- Chrome (latest 2 versions)
- Firefox (latest 2 versions)
- Safari (latest 2 versions)
- Edge (latest 2 versions)

#### Device Testing

- Mobile: iPhone, Android phones
- Tablet: iPad, Android tablets
- Desktop: Windows, macOS

#### Accessibility Testing

- Screen reader testing (NVDA, VoiceOver)
- Keyboard navigation
- High contrast mode
- Zoom to 200%

## File Structure

```
force-app/
├── main/
│   └── default/
│       ├── aura/
│       │   └── fecComponent/
│       │       ├── fecComponent.cmp
│       │       ├── fecComponent.css
│       │       ├── fecComponentController.js
│       │       └── fecComponentHelper.js
│       ├── lwc/
│       │   └── fecComponent/
│       │       ├── fecComponent.html
│       │       ├── fecComponent.js
│       │       ├── fecComponent.css
│       │       └── fecComponent.js-meta.xml
│       └── staticresources/
│           └── FEC_CommonCss.css
└── .kiro/
    └── steering/
        └── fec-css-best-practices.md
```

## Common Patterns

### Accordion Styling

```css
/* Custom accordion classes */
.fec-accordion-summary {
  background-color: var(--lwc-colorBackground, #f3f2f2);
  border-radius: var(--lwc-borderRadiusSmall, 0.25rem);
  padding: var(--lwc-spacingXSmall, 0.5rem) var(--lwc-spacingSmall, 0.75rem);
  font-size: var(--lwc-fontSize4, 0.875rem);
}
```

### Button Styling

```css
.fec-button {
  min-height: var(--lwc-sizeMedium, 2.25rem);
  min-width: var(--lwc-sizeMedium, 2.25rem);
  padding: var(--lwc-spacingXSmall, 0.5rem) var(--lwc-spacingMedium, 1rem);
  font-size: var(--lwc-fontSize4, 0.875rem);
}
```

### Form Input Styling

```css
.fec-input {
  height: var(--lwc-sizeMedium, 2.25rem);
  padding: 0 var(--lwc-spacingSmall, 0.75rem);
  font-size: var(--lwc-fontSize4, 0.875rem);
  border: var(--lwc-borderWidthThin, 1px) solid var(--lwc-colorBorder, #dddbda);
}
```

## Code Review Checklist

- [ ] Uses SLDS design tokens
- [ ] No SLDS class overrides (uses custom classes)
- [ ] Minimum font size 14px for mobile
- [ ] Responsive design implemented
- [ ] Accessibility requirements met
- [ ] No `!important` declarations (except utilities)
- [ ] CSS organized in recommended order
- [ ] Performance optimizations applied
- [ ] Cross-browser testing completed

## Resources

- [Salesforce Lightning Design System](https://www.lightningdesignsystem.com/)
- [SLDS Design Tokens](https://www.lightningdesignsystem.com/design-tokens/)
- [WCAG 2.1 Guidelines](https://www.w3.org/TR/WCAG21/)
- [CSS Variables Guide](https://developer.mozilla.org/en-US/docs/Web/CSS/Using_CSS_custom_properties)

## Version History

| Version | Date       | Changes                     |
| ------- | ---------- | --------------------------- |
| 1.0     | 2026-03-19 | Initial standards document  |
| 1.1     | 2026-03-19 | Added mobile font sizes     |
| 1.2     | 2026-03-19 | Added accessibility section |

---

_This document is maintained by the FEC development team. Please update when standards change._
