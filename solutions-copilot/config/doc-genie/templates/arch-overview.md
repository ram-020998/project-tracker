# Architecture Overview: [NAME]

See Architecture Overview and ADR Organization for additional guidance.

## Guidelines

* Start by copying this document and renaming it.
* Read the README for more information
* This document is a component of the Appian Well Built Mechanism and is meant to serve as permanent conceptual documentation for a single piece of Appian's architecture. Each Architecture Overview should:
   * Document a Product, Service, or Major Functional Area. For example, Low-Code Platform (LCP) is a product, but it encompasses many functional areas such as Records and Process Execution. The intent is to cover long-lived areas of our architecture that are of general interest, organized in a fashion that reflects people's areas of interest. If you are unsure whether to create a new AO, update an existing one, or do nothing, reach out to your Group Technical Lead (GTL).
   * Provide business context for your product architecture.
   * Contain high-level information about your product architecture including a summary description and architecture diagrams.
   * Enable visibility and tracking of ADRs, and thus helps drive faster resolution of ADRs.
   * Provide links to any relevant architectural documents.
   * Be updated as the architecture changes. These are living documents.
   * Avoid mentions of current squads or features. The architecture will likely exist longer than a given squad. While individual features contribute to one or more bounded contexts, they may or may not have a significant architectural impact and should not be documented here.
   * If you feel like one section provides more value than another – for example, if you feel that diagrams are more immediately useful than the summary – please keep both sections but reorder them as needed.
* Async collaboration
   * Use comments for async discussion.
   * Explicitly @ tag people if you expect them to respond.
   * Ensure comment threads that you start are resolved as soon as possible.
   * Ensure that relevant information from comment threads is recorded in this document (or another document if appropriate) before resolving the comment threads.

---

## Background

Instructions: Write one or more paragraphs describing the broader business context.

---

## Requirements

Instructions: What is the scope of your system? Describe what your architecture does and does not do. This can include both product and technical requirements. One effective technique is to use the MoSCoW method to list your high-level product requirements.

### Must Have
*

### Should Have
*

### Could Have
*

### Won't Have
*

---

## Architecture

### Architecture Summary

Instructions: Write one or more paragraphs summarizing your product architecture. What is it for? How would someone unfamiliar with Appian's architecture understand it? Are there any shortcomings or missing capabilities?

---

### Architecture Diagrams

Instructions: Create architecture diagrams and add them to the sections below. How does this system fit into the wider Appian ecosystem? Many types of diagrams may be useful, such as Context, Container, and Deployment diagrams from the C4 model, or sequence diagrams. The preferred tool for creating diagrams at Appian is LucidChart. Create other sections here as necessary for other relevant diagrams.

#### Context Diagram

Instructions: Add your C4 Context Diagram here.

#### Container Diagram

Instructions: Add your C4 Container Diagram diagram here.

#### Deployment Diagram

Instructions: Add your (optional) C4 Deployment Diagram here.

---

## Architecture Decisions

Instructions: When an architectural decision is required, start a new ADR and add it to your ADR folder. Use this section to link to relevant ADRs.

### Performance

Instructions: What decisions have you made about performance?

### Security

Instructions: Highlight any important security decisions here.

### Compliance

Instructions: Which compliance frameworks (if any) does your system adhere to?

---

## API / Contracts

Instructions: Use this section to link to any API or contract documentation (such as an OpenAPI specification) for your bounded context. For example, if this describes a service with a HTTP API, the documentation should be linked here.

---

## Glossary

Instructions: Use this section to define terms that may be unfamiliar outside the context of this document.

[TERM] - Definition

---

## Additional Information

Instructions: It is preferred to provide links inline where possible. However, if there are additional sources, link them here.
