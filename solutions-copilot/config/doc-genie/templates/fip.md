# <Feature Name> Implementation Plan

A Feature Implementation Plan (FIP) serves two goals: first, to ensure your squad does appropriate planning for implementation and delivery of your feature, and second, to identify all the things you need to consider when creating your feature. Delivery planning includes completing comprehensive technical breakdowns, identifying significant risks, and involving external stakeholders. The FIP is meant to be ephemeral; it is designed for your squad's use when planning your feature. Information intended for the long term should go into an appropriate durable artifact such as an architecture overview.

Every feature must have an FIP, but some parts are optional. The FIP should be complete before implementation begins. The FIP belongs to your squad, so it should go in your squad's folder structure.

Please DO NOT modify this template or create a separate template. If your squad requires additional information, you can expand on it in a linked document. If you have feedback on the FIP, please reach out to the Engineering Technology Council (ETC) so we can improve it.

**Feature Card/Initiative:** <link>
**Authors:** <names>
**Reviewers:** <Technical Advisor name(s)>
**Status:** Not Started
**Created:** <date>

---

## Feature Kickoff

Instructions: Link all material your PO presents to kick off the feature.

Timing: required before implementation begins
Required: for all features

---

## Breakdown Tasks

Instructions: Put links to your breakdown or other high-level implementation planning information here. Whether it's a link to a JIRA epic, a link to a document or set of documents, or some other format, it should have a list of tasks that will be required to successfully deliver this feature. This is to help you identify what work must be done and in what order.

To help ensure you complete all the necessary work, you may also wish to create a (optional) Feature Plan Checklist for your feature.

Timing: required before implementation begins
Required: for all features

<link to breakdown doc(s), JIRA ticket(s), or however your squad does breakdowns>

---

## Stakeholders

Instructions: List all Groups/Squads/Individuals who are impacted by this feature and how they are impacted. At a minimum, this list should include your TAC advisors and GTL (if your group has one). You should not think of this list as "gatekeepers" or "reviewers" but people who should be informed of the changes (share this document, ADRs, etc.) over the course of development. The team still owns the features, these folks should just be interested/impacted parties or valuable technical advisors who should be given the opportunity to voice opinions as early in the development process as is deemed feasible.

Timing: required before implementation begins
Required: for all features

| Stakeholder | How are they impacted? | Contacted? |
|-------------|----------------------|------------|
| | | |

---

## Durable Architecture Documentation

Instructions: What Architectural Overview (AO) (if any) or Core Architecture Diagrams (see README) need to be created or updated due to this feature? Update them and link them here. If there are significant unknowns or deferred decisions, link specific tickets that will be completed before feature delivery. This step is critical to ensure our architectural documentation is up-to-date. If no changes are needed, put in "No changes needed".

For example, if you are creating a new service, creating or changing connections between services (including LCP), storing customer data, or introducing a new dependency on a managed service such as S3, you must update the relevant AOs. If you are not sure which Architectural Overview(s) are relevant, speak with your Group Technical Lead. If no GTL is available, work with your TAC advisors.

Timing: required before implementation begins
Required: for all features that make significant architectural changes

<Link to Architecture Overview(s)>

---

## Feature Documentation/Diagrams

Instructions: Link any detailed diagrams or architectural descriptions that are useful for understanding feature implementation. Examples include component diagrams or sequence diagrams. In particular it is important to identify the modularity of this feature and how it is coupled to existing capabilities.

Timing: should be completed as necessary
Required: not required, but highly recommended

* <Link to diagram>
* <Link to diagram>
* <Link to documentation>
* <Link to documentation>
* …

---

## Architectural Decisions

Instructions: Link any Architectural Decision Records (ADRs) created as part of this feature breakdown. If they impact relevant Architecture Overview(s), link them in that document as well. If you add ADRs during implementation, it would be helpful to add them here. If there are no ADRs, just put "No ADRs".

Timing: should be completed as necessary
Required: not required, but highly recommended

* <Link to ADR>
* <Link to ADR>
* …

---

## Data Persistence

Instructions: if you are adding data persistence (on disk, in ADS, Elasticsearch or RDBMS, etc), you should complete the Feature Data Review and link it below. The worksheet has sections for guiding a squad's data modeling design in RDBMS, Elasticsearch and Appian RPA. It is advised that squads complete the worksheet early in the feature development lifecycle (during the design phase) for data intensive features. The worksheet can also be used to review the feature's data modeling aspects, in a structured manner, with the squad's Technical Advisors.

Timing: If review(s) are required, outreach is required before implementation.
Required: for all features that are adding data persistence.

---

## Security and Compliance

Instructions: Note what (if any) portions of the feature design require compliance or security reviews. Compliance and security reviews can be complex and time-consuming, and it is critical to start the process early to ensure we can address any problems quickly and reduce implementation costs.

Compliance is ensuring that we follow certain standards (such as SOC2 or FedRAMP) that are designed to help organizations ensure their infrastructure remains secure. As part of our Cloud offering, we offer customers assurance that we follow those frameworks. Compliance reviews follow the Security Impact Assessment (SIA) process defined by Infosec.

The difference between security and compliance: security is checking that your doors are locked before you go to bed, and compliance is your insurance company requiring that you have specific types of locks.

If you need a Security Review, put Required in the Security Review dropdown. Please note that not all features require security review but if your team is doing something novel or you are deploying a new service, container or AWS service, you must involve ProdSec earlier in the process to reduce the risk of finding surprises later on. If that's the case, notify ProdSec by tagging @POC in their chat space.

Timing: If review(s) are required, outreach is required before implementation.
Required: analysis is required for all features.

Compliance Review: Required - SIA Not started
Security Review: Required - ProdSec Not Informed
AI Usage Audit Log (required for all AI features)*: Not Required

* The AI Usage Audit Log is a system log to capture all interactions with AI capabilities on an Appian environment, which must be used when a new AI capability is implemented. The AI Audit Logs are intended to provide auditing capabilities to customers for all AI features within the Appian platform. Auditing capabilities are a key requirement for many of our existing and new customers when adopting AI capabilities.

---

## Accessibility (a11y)

Instructions: Note what (if any) portions of the feature design require an accessibility consultation. It's important to think about accessibility early because it can impact the feature's design, and it's easier to build in accessibility from the start rather than retrofit it later.
All features exposed to end users of the Appian product must be accessible. This typically includes elements used on a SAIL user interface, including interactive components and controls, images, text elements, and some layout types. This also includes updates to any of our end user environments, such as Sites, Portals, Embedded, Process HQ, or Enterprise Copilot (or the creation of new end user environments). See the Accessibility: Plan Feature practice card for more information.
If your feature requires an accessibility consultation, reach out to the Product Accessibility Office (PAO) as part of this FIP. If your feature does not require a consultation, you can select "Not Required" and move on.

Timing: If required, reach out to the PAO before implementation
Required: Required for all features that are exposed to end users of the Appian product

Accessibility Consultation: Required - Accessibility Consultation Not Started

---

## Risks/Open Questions

Instructions: What unanswered questions will you need to resolve before delivering this feature? Are there any unaddressed risks? How will you answer the questions and address the risks?

Timing: should be completed as necessary
Required: not required

---

## Squad-Specific Items

Instructions: If your squad has additional information you would like to include, please link to it here. For example, if you maintain a list of open spikes, a glossary of terms, or information on related features.

Timing: should be completed as necessary
Required: not required

<Link to squad-specific FIP items>
