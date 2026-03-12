## nolon 2.1.3

### Changes
- fix(clawhub): retry remote list requests on HTTP 429 to avoid transient catalog failures
- fix(gemini): remove duplicate active account card shown in the usage tab
- test: add coverage for Clawhub rate-limit retries and Gemini usage-card deduplication
- docs: sync feature/dev notes and session memory for both fixes
