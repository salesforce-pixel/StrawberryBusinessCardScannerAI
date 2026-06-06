# Strawberry Business Card Scanner (AI)

An Agentforce/Einstein-powered Lightning Web Component that turns a photo of a
business card into a Salesforce **Lead**. Built for **Strawberry Hotels**.

A user uploads or photographs a business card, the component sends the image to an
**Einstein Prompt Template** for structured extraction, checks for an existing Lead
by email, and then **creates** a new Lead or lets the user **review and overwrite**
the matching one — with a clear, mobile-optimized UI.

## How it works

```
businessCardScanner (LWC)
└─ BusinessCardController (Apex)
   ├─ extractFromCard → AI_businessCardAnalyzer
   │     └─ ConnectApi.EinsteinLLM → "Business_Card_Scanner_Prompt" (GenAiPromptTemplate)
   ├─ findLead   → SOQL on Lead (by email, non-converted)
   ├─ createLead → inserts a new Lead
   └─ updateLead → updates the matched Lead
```

1. **Upload / capture** a card image (`lightning-file-upload`, mobile camera friendly).
2. **Analyze with AI** — the image is passed to the `Business_Card_Scanner_Prompt`
   prompt template, which returns normalized JSON (first/last name, title, company,
   email, phone, mobile, website, address, LinkedIn).
3. **Duplicate check** — looks up an existing, non-converted Lead by email.
4. **Create or overwrite** — create a fresh Lead, or open the existing one to review
   before overwriting. A completion panel ends the flow cleanly.

## Components

| Type | Name | Purpose |
| --- | --- | --- |
| LightningComponentBundle | `businessCardScanner` | The UI (upload, preview, review, save). |
| ApexClass | `BusinessCardController` | Aura endpoints: extract, find, create, update Lead. |
| ApexClass | `AI_businessCardAnalyzer` | Calls the Einstein prompt template via ConnectApi. |
| GenAiPromptTemplate | `Business_Card_Scanner_Prompt` | Vision prompt that extracts card fields as JSON. |
| StaticResource | `strawberryLogo` | Strawberry logo used in the component header. |

## Prerequisites

- A Salesforce org with **Einstein Generative AI / Prompt Builder** enabled.
- A **multimodal (vision-capable)** model available to the prompt template. The
  template ships referencing `sfdc_ai__DefaultGPT54`; confirm it (or your chosen
  model) accepts image input in **Setup → Prompt Builder**.
- API version **66.0** (see `sfdx-project.json`).

## Validate & Deploy

```bash
# authorize your org (once)
sf org login web --alias myOrg

# validate first — check-only deploy, makes NO changes to the org
sf project deploy validate --manifest manifest/package.xml --target-org myOrg

# deploy the feature
sf project deploy start --manifest manifest/package.xml --target-org myOrg
```

Then add **Business Card Scanner** to a Lightning App, Home, or Record page in the
Lightning App Builder.

## Notes

- **Prompt template versioning:** updating prompt content via metadata requires
  bumping the `versionIdentifier` / `activeVersionIdentifier`, otherwise the deploy
  no-ops the content.
- **No Apex test class is included yet** — add one before deploying to production
  (75% coverage requirement).
- Brand colors approximate the official Strawberry palette (warm coral `#e2685a`);
  adjust the CSS custom properties in `businessCardScanner.css` to match exact brand
  guidelines.

## Author

**Rajeev Shekhar**
