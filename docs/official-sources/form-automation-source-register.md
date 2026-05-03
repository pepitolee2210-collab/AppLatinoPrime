# Official Source Register

This register is the control document for USA Latino Prime form automation. A form, rule, fee, destination, checklist, DMV module, or local resource cannot be treated as production-ready unless it points back to an official source.

## Source Policy

- Use official government pages first.
- Store the source URL, agency, source type, jurisdiction, and last checked timestamp.
- Do not copy long official instructions into the app. Link, summarize, and version rules.
- Keep form editions, field maps, fees, filing destinations, and evidence requirements separate.
- Mark legal-risk workflows as requiring human review when the system would otherwise make a judgment call.

## Federal Immigration Sources

| Area | Official Source | Use In System |
| --- | --- | --- |
| USCIS form catalog | https://www.uscis.gov/forms/forms | Source of current USCIS form pages and editions. |
| AR-11 | https://www.uscis.gov/ar-11 | Form definition and address-change workflow source. |
| AR-11 PDF | https://www.uscis.gov/sites/default/files/document/forms/ar-11.pdf | Official PDF template source for reviewed prefill mapping. |
| USCIS address change guidance | https://www.uscis.gov/addresschange | Official change-of-address guidance and special-population routing. |
| USCIS online account change of address | https://my.uscis.gov/file-a-form | Preferred user-directed online change-of-address path. |
| I-765 | https://www.uscis.gov/i-765 | Form definition, instructions, categories, and edition tracking. |
| I-765 filing addresses | https://www.uscis.gov/i-765-addresses | Rule source for destinations by category/location/filing method. |
| USCIS fee schedule | https://www.uscis.gov/g-1055 | Fee rule source. |
| USCIS API | https://developer.uscis.gov/ | Case status API, OAuth, sandbox, and production approval. |
| EOIR forms | https://www.justice.gov/eoir/eoir-forms | EOIR form catalog source. |
| EOIR Respondent Access | https://respondentaccess.eoir.justice.gov/en/ | Respondent portal reference; do not request user passwords. |
| EOIR Case Information | https://www.justice.gov/eoir/eoir-case-information | Case and hearing information source. |
| EOIR Immigration Court reference materials | https://www.justice.gov/eoir/reference-materials/ic | Practice manual and motion workflow source. |
| CBP I-94 | https://www.cbp.gov/I94 | I-94 informational source. |
| I-94 portal | https://i94.cbp.dhs.gov/ | User-directed I-94 retrieval reference. |

## State-Specific Sources

Immigration forms are mainly federal, but state/location still matters for DMV, local resources, mailing address rules, court selection, and some commercial compliance constraints.

| State | Official Source | Current Product Status |
| --- | --- | --- |
| UT | https://dld.utah.gov/written-knowledge-test/ | First DMV module. |
| CA | https://www.dmv.ca.gov/portal/handbook/california-driver-handbook/ | Needs editorial import. |
| TX | https://www.dps.texas.gov/section/driver-license/driver-license-handbooks | Needs editorial import. |
| FL | https://www.flhsmv.gov/resources/handbooks-manuals/ | Needs editorial import. |

## Automation Classification

| Workflow | Automation Level | Human Review |
| --- | --- | --- |
| AR-11 | High: user-directed prefill, validation, PDF/checklist, official submission guidance. | Not required by default. |
| EOIR-33 | Medium-high: user-directed prefill and destination/court validation. | Recommended. |
| I-765 | Medium: packet preparation depends on eligibility category, fee, evidence, and current edition. | Recommended. |
| Change of Venue | Low-medium: generate draft packet from user facts. | Required. |
| I-94 | Medium: OCR/import and document storage. | Not a filing workflow. |
| DMV tests | State-specific content module. | Editorial verification required per state. |

## Production Rule

The app may prepare documents, map answers into official PDFs, and generate packets. The app must not claim legal advice, decide eligibility, or represent the user before an agency unless an authorized human service is explicitly involved.
