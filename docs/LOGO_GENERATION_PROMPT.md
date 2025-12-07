# Open Graph Image Logo Generation Prompt for LovelyLittleMeal

## Purpose
This logo is specifically for Open Graph (OG) tags - the image that appears when sharing recipe links in chat apps (WhatsApp, Telegram, iMessage, etc.) and social media platforms.

## Image Generation Prompt

Use this prompt with DALL-E, Midjourney, or similar AI image generation tools:

```
Create a clean, modern Open Graph image logo optimized for social sharing and chat apps:

DESIGN ELEMENTS:
- Large bold letters "LLM" in black color
- A small, cute chef's hat positioned on top of the letters, centered above the "LLM" text
- White background (solid white, no transparency)
- Font: Funnel Sans (or similar modern, bold sans-serif font if Funnel Sans is not available)
- The chef's hat should be proportional to the text size - approximately 1/3 the height of the letters
- Clean, minimalist design suitable for a recipe/cooking website

TECHNICAL SPECIFICATIONS:
- Dimensions: 1200x630 pixels (1.91:1 aspect ratio - standard OG image ratio)
- Format: PNG with white background
- Resolution: High resolution (at least 72 DPI, preferably 300 DPI)
- Style: Flat design, modern, professional
- Text should be clearly readable and bold
- Chef's hat should be simple and recognizable, positioned directly above the center of "LLM"

COLOR SPECIFICATIONS:
- Background: Pure white (#FFFFFF)
- Text: Pure black (#000000)
- Chef's hat: Black outline or solid black, matching the text color

LAYOUT:
- "LLM" letters should be horizontally and vertically centered in the image
- Chef's hat should be centered above the letters
- Generous padding around all elements (at least 15% margin on all sides)
- The logo should be clearly visible and readable when displayed as a thumbnail in chat apps
- Design should work well at both full size (1200x630) and when cropped/displayed as a card
```

## Alternative Prompt (More Detailed)

If the above doesn't work well, try this more detailed version:

```
Design a professional Open Graph image for social sharing: The letters "LLM" in bold black Funnel Sans font, centered both horizontally and vertically on a pure white background. Above the letters, centered, place a small black chef's hat icon. The chef's hat should be approximately one-third the height of the letters. The entire image should be 1200 pixels wide by 630 pixels tall (standard Open Graph ratio for optimal display in chat apps and social media). Style: flat design, minimalist, modern, suitable for a cooking/recipe website. Colors: pure white background (#FFFFFF), pure black text and hat (#000000). The logo must be clearly visible and readable when displayed as a preview card in messaging apps like WhatsApp, Telegram, and iMessage.
```

## Usage Instructions

1. **Generate the logo** using one of the prompts above with your preferred AI image generator
2. **Save the image** as a PNG file with white background
3. **Upload to Cloudinary** to get a CDN URL
4. **Update the layout** (`app/views/layouts/application.html.erb`) to use the new logo URL in the default `og_image` variable

## Recommended Dimensions

- **OG Image**: 1200x630px (1.91:1 ratio) - This is the standard Open Graph image size
- **Why this size**: Optimized for display in:
  - WhatsApp link previews
  - Telegram link previews
  - iMessage link previews
  - Facebook/LinkedIn link previews
  - Twitter cards
  - Discord embeds

## Notes

- The 1200x630px ratio is the industry standard for OG images
- White background ensures it works on all platforms
- High resolution ensures it looks crisp on all devices
- The chef's hat adds a cooking/recipe theme to the "LLM" acronym
- This image will be used as the default when sharing recipe links (unless a recipe has its own image)

