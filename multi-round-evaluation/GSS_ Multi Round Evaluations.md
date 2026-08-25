# Research

## Problem

Some of the customers who have asked this functionality:

* UT Arlington  
* Texas Department of Information Resources (DIR / DIR Co-op)  
* San Francisco Public Utilities Commission (SFPUC)  
* Architect of the Capitol (AOC)

### **Summary of Customer Requests**

UT Arlington & SFPUC: Requested a structured gateway system to check for mandatory Minimum Qualifications (MQs) and automatically filter out disqualified vendors from future scoring rounds. They need the system to auto-trigger non-responsive letters, support format shifts mid-stream (e.g., changing from a scored matrix to pass/fail if only one vendor remains), and cleanly terminate the pipeline if all proposers fail a stage.

Texas DIR & AOC: Demanded core platform capabilities to support multiple sequential rounds of evaluation, tabulation, and scoring consensus. They specifically want automated tracking mechanisms to manage down-selected vendors, initiate negotiations, and easily log Best and Final Offers (BAFOs).

## Use Cases

As a CO, I need to be able to indicate that an Evaluation will be Multi Phase when creating an Evaluation so that the ability to downselect a few vendors become available for the Evaluation

As a CO, I should be able to select a few vendors that I want to take to the next round so that I can conduct the next phase of the Evaluation only with those vendors

As a CO, I want the ability to make changes to the setup/assignment and add vendor documents so that the next phase Evaluation is conducted based on the new rules and the new documents

## Questions

Downselect \- reasons for rejection. If asking resubmission among downselected vendors, asking them what needs to be resubmitted.

* Rejection reasons are mandatory at the end of Evaluation   
* Resubmission is mandatory for selected vendors (recheck)  
* Resubmission can be done by other vendors as well(FAR 15.202)

Will COs know that an Evaluation is going to be multi phase? If yes, will they precisely know the various phases that are going to be there and their timelines? 

* Yes but timelines can be fluid

Can planned phases be extended or reduced? Meaning some phases are added or removed impromptu

* No it is fixed as per Solicitation

Will phases be required if no downselect happens between two phases?

* Yes it is a valid scenario

Are phases codified in Solicitation?

* Yes. Under FAR 15.202 and FAR 36.3, the entire multi-phase framework, criteria, and instructions must be explicitly codified in Sections L & M of the solicitation.

Will they be interested in knowing which phase is currently going on?

* Yes

What do we allow COs to modify before starting the next phase? Factors? Due dates? Assignments? New Vendor documents?

* Due Dates: Shift Phase 2 submission deadlines.  
* Assignments: Reassign evaluators or Factor Chairs based on availability or subject matter expertise required for Phase 2\.  
* Vendor Documents: Open portals for new Phase 2 document uploads.  
* Banned Modifications: COs cannot modify evaluation factors or weights unless a formal solicitation amendment is issued to all remaining vendors.

In Audit? Yes we show that vendors were downselected.

In the Summary page \- Show current phase, previous phase. 

Whole record for each phase or differentiate within individual tabs

What information from previous phases (or upcoming) would be useful for COs, Factor Chairs or Evaluators to view?

## Research

### **What is Multi Phase Evaluation?**

A multi-phase evaluation, or "down-select," is a strategic procurement methodology that bifurcates or trifurcates the solicitation lifecycle to progressively narrow the competitive field. In the initial phase, agencies evaluate lightweight, high-level information—such as past performance or technical concepts—rather than voluminous technical and pricing structures. This process is governed by various regulatory frameworks depending on the acquisition type, such as FAR 15.202 (Advisory multi-step), FAR 16.505 (Fair Opportunity/Task Orders), and FAR 36.3 (Two-phase design-build).

### **Benefits of Multi-Phase Evaluations**

* **Reduced Bid & Proposal (B\&P) Costs:** Vendors avoid the substantial financial burden of preparing full proposals unless they possess a realistic probability of award.  
* **Administrative Efficiency:** Evaluation teams reduce the volume of full proposals they must review, document, and defend.  
* **Improved Focus:** Evaluators dedicate the highest-value labor hours to the most viable and highly qualified offerors.

### **How is it done today?**

Today, down-selects are predominantly managed through manual, high-friction processes. Because existing contract writing systems often lack native tracking, contracting officers orchestrate sequential rounds using disjointed spreadsheets, local shared folders, and manual email notifications. This manual reliance introduces significant operational risks:

* **Cross-Phase Inconsistencies:** Difficulty tracking vendor data (e.g., LCATs or staffing plans) across rounds leads to discrepancies, as evidenced in *IntelliBridge, LLC (B-421560.9)*.  
* **Audit Trail Vulnerabilities:** With data scattered across disparate files, agencies struggle to maintain a coherent, protest-defensible administrative record.  
* **Access Control Risks:** Managing evaluator permissions and masking identities across changing teams and phases is highly labor-intensive and error-prone.

### **How many Evaluations today are Multi Phase?**

While historical data was niche, adoption has surged post-2020. Prior to 2020, GAO protest decisions referencing advisory down-selects were virtually non-existent; of 18 major GAO protests involving these methodologies, 17 were decided after 2020\. The Department of Homeland Security’s Procurement Innovation Lab (PIL) has been a primary institutional driver, coaching 20 major projects valued at $2.97 billion in FY 2022 alone, signaling the technique's transition from an experimental pilot to a mainstream acquisition vehicle.

### **How are Multi Phase Evaluations defined in FAR?**

Multi-phase evaluations are not defined by a single FAR "Multi-Phase" clause; rather, they are operationalized through specific regulatory frameworks that allow for sequential solicitation steps. For product architecture, you must distinguish between **Advisory** (non-exclusionary) and **Firm** (exclusionary) down-selects, as the compliance requirements differ significantly.

* **FAR 36.3 (Two-Phase Design-Build):** A statutory framework. Phase 1 assesses technical qualifications and experience only (price is strictly prohibited). The government must down-select to a maximum of 5 vendors for Phase 2\.  
* **FAR 15.202 (Advisory Multi-Step):** A pre-solicitation screening tool. The government provides "advisory" opinions on viability. Because there is no formal exclusion, unselected vendors retain the right to submit full proposals, and Phase 1 evaluations are generally not protestable at the GAO.  
* **FAR 16.505 (Fair Opportunity/IDIQ):** Highly discretionary. Can be structured as advisory or "firm." If the CO utilizes a "firm" down-select, they must issue formal exclusion notices per FAR 15.503(a)(1), which triggers debriefing and protest rights.  
* **FAR Part 12/13 (Commercial):** Provides flexibility for innovation-driven acquisitions. Agencies use light technical gates (e.g., concept papers) to thin the pool before requiring full proposals, often adhering to the spirit of the advisory down-select to reduce B\&P costs.

**Strategic Product Guidance:**  
The legal tension in multi-phase evaluations is price. If a down-select is "firm" (excluding vendors), price *must* be considered at that gate to satisfy statutory competition requirements. To bypass this, agencies frequently use the advisory route. Your software must differentiate between these two: offering **advisory templates** for recommendations and **formal notification/debriefing workflows** for firm exclusions. Ensure that your audit trail distinguishes between "advisory" records and "source selection" records to withstand protest scrutiny.

### **How many evaluations are firm down select vs advisory?**

When executing multi-phase acquisitions across the federal landscape, the market split leans heavily toward **Firm Down-Selects**.  
The Market Split: \~85% Firm Down-Select vs. \~15% Advisory Multi-Step

* **Firm Down-Selects (\~85%):** This structure dominates high-value federal procurements. The vast majority occur via **FAR Part 36.3** (Two-Phase Design-Build Construction) and mid-stream **FAR Part 15.306(c)** Competitive Range Determinations.  
* **Advisory Multi-Step (\~15%):** Governed by **FAR Part 15.202**, this mechanism is rarer and heavily concentrated within specific "innovation hubs" like the DHS Procurement Innovation Lab (PIL), GSA, and USDS for agile software or IT services.

Why COs Overwhelmingly Prefer Firm Down-Selects

* **Administrative Efficiency:** The \#1 reason Contracting Officers (COs) use multi-phase workflows is to reduce their evaluation burden. A firm down-select eliminates non-viable competitors legally. An advisory process leaves the door open for those same vendors to submit hundreds of pages of Phase 2 data that the agency *must* evaluate.  
* **Risk Mitigation:** Defending a firm down-select is straightforward if the criteria in Section M are objective. Conversely, evaluating a vendor that ignored advisory "Do Not Proceed" guidance increases the likelihood of an inconsistent evaluation, which acts as a primary target for GAO bid protests.  
* **Industry Cost Constraints:** For complex systems, industry standardly pushes for firm gates. Contractors are hesitant to spend hundreds of thousands of dollars on complex Phase 2 technical or cost proposals if the field remains crowded with non-viable competitors.

Product Team Guidance  
Focusing your MVP strictly on the **Firm Down-Select** workflow captures the largest, highest-dollar segment of the multi-phase market while keeping your software's permission models and portal controls straightforward.

### **Will CO know an Evaluation is going to be Multi Phase?**

A Contracting Officer (CO) absolutely knows an evaluation is multi-phase when creating the evaluation, as this strategy is determined well before the solicitation is released.

* **Regulatory Requirement:** Multi-phase frameworks (including phases, criteria, and instructions) must be explicitly codified in the Solicitation (Sections L & M) before evaluation begins. The CO defines this acquisition strategy during pre-solicitation planning.  
* **Phase Certainty:** The number and purpose of phases are fixed by the solicitation. The CO knows precisely which phases are planned (e.g., qualification gate, oral presentations, full technical/price proposal) at the time of creation.  
* **Timeline Fluidity:** While the phase structure is rigid, the *execution timelines* are often fluid. COs frequently adjust phase-specific due dates based on the volume of vendor responses and evaluation progress.  
* **Strategic Implication for GSS:** Because the intent is known at creation, the GSS platform should support a "Multi-Phase" toggle when creating the evaluation. This ensures the correct permission models, down-select gates, and notification workflows are initialized from the start.

The CO does not make this determination impromptu; it is a fundamental part of the acquisition plan. Building this into the "Create Evaluation" workflow is critical for maintaining a defensible audit trail.

## Feature Decisions

Following are decisions that drive the use flow and the further specifics of this feature.

* Advisory vs Firm Down Select \- Advisory is recommended since it does not yield itself to protests.  
  * How to allow down selects with the ability to consider a vendor that was advised to not continue?  
* Multi Phase is essentially Factors mapped to Phases and phase wise configuration that drives how each phase will be run. We will support first 2 in below list  
  * With Evaluation Tasks \+ Consensus  
  * With Just Consensus  
  * With Just Evaluation Tasks  
* Best Value vs LPTA Multi Phase  
  * In case of Multi Phase LPTA, only the last phase will have the LPTA Evaluation task  
  * All previous phases can have traditional Evaluation tasks or consensus or both  
* What can change before starting a phase  
  * Vendors resubmissions  
  * Phase due date  
  * Factor due dates  
  * Factor Assignments  
  * On-the-spot consensus configuration  
* Integration with VM  
  * Shortlisted vendors get notes that they are advised to show intent and submit next set of deliverables before deadline  
  * Other vendors get notes that they are not highly rated and advised to not submit 

## Thoughts on MVP

We should focus on firm down selection for our MVP. Only the down selected vendors are notified in VM to submit detailed proposals. The others receive an exclusion notice.

1. Create Evaluation CO creates a new Evaluation and indicates it will be Multi-Phase (yes/no toggle). No phase details yet.  
2. Add Phases (separate section) CO defines the planned phases in a dedicated Phases section (name, purpose, order). This can happen anytime before starting the evaluation.  
3. Setup Evaluation CO configures the evaluation structure as usual:  
   1. Adds Factors (no phase mapping at this point — all factors are just defined)  
   2. Creates Teams (Evaluators, Factor Chairs)  
   3. Sets up Assignments  
   4. Sets factor-wise due dates  
4. Add Vendors CO pulls vendors from the linked Opportunity.  
5. Start Evaluation / Start Phase 1 CO starts the evaluation (which triggers Phase 1). At this point:  
   1. CO selects which factors are applicable to Phase 1  
   2. Only tasks for those selected factors are triggered for evaluators  
6. Complete Evaluation Tasks — Phase 1 (Evaluators) Evaluators review submissions against Phase 1 factors and submit ratings.  
7. Complete Consensus — Phase 1 (Factor Chairs) Factor Chairs finalize consensus ratings for Phase 1\.  
8. Complete Factors — Phase 1 factors are marked complete.  
9. Down-Select Vendors (CO) CO selects which vendors advance to the next phase.  
   1. Excluded vendors receive exclusion notices (via VM)  
   2. Down-selected vendors are notified to resubmit (via VM)

---

↻ REPEAT for each subsequent phase:

10. Modify Phase Configuration (CO) Before starting the next phase, CO can adjust:  
    1. Factor and Phase Due dates  
    2. Evaluator assignments  
    3. Add new vendor documents (resubmissions)  
    4. (Cannot modify factors/weights without solicitation amendment)  
11. Vendors Resubmit (outside GSS, via VM) Down-selected vendors submit detailed proposals for the next phase.  
12. Add Resubmitted Documents (CO) CO uploads new vendor documents into GSS.  
13. Start Phase N CO starts the next phase. At this point:  
    1. CO selects which factors are applicable to this phase  
    2. Tasks are triggered only for those factors  
14. Complete Evaluation Tasks — Phase N (Evaluators)  
15. Complete Consensus — Phase N (Factor Chairs)  
16. Complete Factors — Phase N  
17. Select Awardees OR Down-Select Again (CO)  
    1. Final phase → Select Awardees  
    2. More phases → Down-select and loop to step 10

---

18. Complete Evaluation (CO) Evaluation formally closed after final phase awardees are selected.

## Archive

Factors \- Allow CO to select factor applicability for specific phases so that only those factors’ tasks are triggered for the specific phase?

| Down-Select Framework | Expected Phases | Brief Description & Evaluation Focus |
| :---- | :---- | :---- |
| **Two-Phase Design-Build** *(FAR 36.3)* | **Exactly 2** | Heavily regulated; Phase 1 evaluates technical qualifications and experience (no price allowed). Only a maximum of 5 vendors (typically 3-5) are cleared to submit full design and price proposals in Phase 2\. |
| **Competitive Range Determination** *(FAR 15.306(c))* | **2 to 3** | Mid-stream down-select. Typically 2 phases (Initial proposals $\\rightarrow$ Competitive Range down-select $\\rightarrow$ Final Proposal Revisions). Can stretch to 3 if oral presentations or multiple rounds of discussions are held. |
| **Commercial Streamlined RFPs** *(FAR Part 12 / 13.5)* | **2 to 3** | Highly dynamic workflows pushed by agency innovation units (e.g., DHS PIL). Phase 1 is a light technical hurdle (e.g., prior experience, 5-page concept), followed by a firm cut before heavy Phase 2 technical/pricing submissions. |
| **GSA Schedule / BPA Orders** *(FAR 8.4)* | **2** | Streamlined procedures used to quickly thin the schedule holder pool. Phase 1 usually targets key corporate certifications or past performance, blocking low-rated vendors from Phase 2 tech demos and pricing. |
| **Fair Opportunity IDIQ Orders** *(FAR 16.505)* | **2 to 3** | Used for massive multi-award vehicles. Phase 1 acts as a firm gate (mandatory technical capability or past performance check). Highly complex orders occasionally append an isolated Phase 2 technical presentation before a final Phase 3 pricing round. |

[https://gemini.google.com/share/d/1nAhUcF7takDdR\_BmTNP8bkk0ZaxP7fKp?usp=sharing](https://gemini.google.com/share/d/1nAhUcF7takDdR_BmTNP8bkk0ZaxP7fKp?usp=sharing) |   
Doc Link: [GSS: Multi Phase Evaluations - Downselect](https://docs.google.com/document/d/1ukpYSJlVltbPmDQpIMK3Q1AEnj7fstbymavirJUUxJM/edit?tab=t.2ooxgh9tp048)

# Spec

# GSS: Multi Round Evaluations

## PO: Subash Narayana B | UX: Vedant Khaire		 Team: GAM Source Selection

## Targeted Release: Source Selection 3.3

Feature card Link   
Mockup: [https://www.figma.com/deck/U9rGBTKVtpnxLOTNjQmvi8](https://www.figma.com/deck/U9rGBTKVtpnxLOTNjQmvi8)

# Summary:

Requested by customers like WHS, FRA, and Texas DIR, this feature introduces multi-round evaluations exclusively for Best Value Evaluations to simplify large, complex processes. Contracting Officers (COs) initiate rounds by defining names, due dates, and applicable factors. Once all factors are complete, COs can select awardees or start a new round by selecting factors and included vendors. During subsequent round setup, COs can modify factor assignments, upload vendor resubmissions, or manually reinstate previously excluded vendors; however, these settings lock once the round begins. This iterative cycle repeats as needed without requiring upfront declaration, saving time and effort.

# Guiding Use Cases

* As a CO, I want the ability to provide the  round name, due date and select applicable factors when starting the Evaluation , so that the Evaluators concentrate only on the selected factors for that round.  
* As a CO, when all factors are marked complete, I want the ability to initiate a new round and provide the next round details, select applicable factors and select the vendors to be included so that they can start setting up the next round of the Evaluation.  
* Ability to update factor assignment when in the round setup in an Evaluation  
* Included vendors in a round have resubmission enabled in VM  
* Ability to allow resubmissions for just the down selected vendors in VM  
* Ability to send rejection message for the eliminated vendors in VM  
* Ability to add new vendor documents to included vendors  
* Ability to include a previously excluded vendor from the previous round  
* Ability to start a round once all included vendors have submitted their revised proposals

# Use Cases Not Supported

* Multi Phase  
* Add vendors or factors to a certain round adhoc

# Why do we need this?

**Multiple customers have asked us for this functionality**

**FRA and WHS:** Our solution currently forces users into a frustrating workaround—manually creating entirely new evaluations for each phase of a procurement just to eliminate vendors sequentially. By building native multi-phase evaluations, we enable users to order factors by importance and naturally filter vendors within a single workflow. This eliminates massive administrative overhead while preserving a clean, compliant audit trail from the initial price check down to the final selection.

**UT Arlington & SFPUC**: Requested a structured gateway system to check for mandatory Minimum Qualifications (MQs) and automatically filter out disqualified vendors from future scoring rounds. They need the system to auto-trigger non-responsive letters, support format shifts mid-stream (e.g., changing from a scored matrix to pass/fail if only one vendor remains), and cleanly terminate the pipeline if all proposers fail a stage.

**Texas DIR & AOC:** Demanded core platform capabilities to support multiple sequential rounds of evaluation, tabulation, and scoring consensus. They specifically want automated tracking mechanisms to manage down-selected vendors, initiate negotiations, and easily log Best and Final Offers (BAFOs).

# What is it?

## Feature Brief:

We are introducing the ability for agencies to conduct multiple rounds of Evaluations. Over the years multiple customers (WHS, FRA, Texas DIR) and prospects have repeatedly asked for this capability. 

When COs start an Evaluation, we will ask them for the first round’s name, due date and the applicable factors for that round. When all the factors have been marked as complete, the CO will have an option between selecting awardees or initiating a new round. When initiating a new round they will provide the name and due date for the next round, select the factors that are applicable and the vendors that would be included in that round. 

During the setup of the next round, COs will be able to modify the factor assignments, upload vendor resubmissions or manually include any excluded vendors to the next round. Once a round is started, COs will not be able to change the vendors included or the factors for the round. At the end of this round the cycle repeats where they can either Select Awardees or Initiate a new round.

This feature will help agencies tackle large complex evaluations in a structured and iterative manner, saving time and effort. With the way this feature will be built, COs have full flexibility to add rounds as required and don't need to declare them up front. Multiple rounds will only be available for Best Value Evaluations.

## Suggested User flow:

1. Create Evaluation CO creates a new Evaluation (Multiple rounds will only be available for Best Value Evaluations)  
2. CO sets up Evaluation as usual:  
   1. Adds Factors  
   2. Creates Teams  
   3. Assigns teams to factors  
3. Add Vendors CO pulls vendors from the linked Opportunity.  
4. When starting an Evaluation, COs provide first round name and the start/ due date. (Start date is pre populated) and select the factors applicable for the round. Only tasks for those selected factors are triggered for evaluators  
5. Complete Evaluation Tasks — Round 1 (Evaluators) Evaluators review submissions against Round 1 factors and submit ratings.  
6. Complete Consensus — Round 1 (Factor Chairs) Factor Chairs finalize consensus ratings  
7. Complete Factors — CO marks factors as complete.  
8. CO can either Select Awardees or initiate a new round

---

↻ REPEAT for each subsequent round:

9. When clicking on Initiate new round, CO sees ability to  
   1. Provide Round name, start date and due date  
   2. Indicate if this round will have on the spot consensus  
   3. Select factors applicable for the new round  
   4. Choose vendors that will be included in the next round  
10. During next round’s setup, COs have the ability to  
    1. Modify teams and Assignment  
    2. Add new vendor submissions  
    3. Modify Factor due dates  
11. Request resubmission is triggered for included vendors for the round in VM  
12. Vendors resubmit and COs add Resubmitted Documents (CO) CO uploads new vendor documents into GSS.  
13. COs additionally have the ability to include a previously excluded vendor  
14. Start next Round  
15. Complete Evaluation Tasks — Round N (Evaluators)  
16. Complete Consensus — Round N (Factor Chairs)  
17. Complete Factors — Round N  
18. Select Awardees OR Initiate New Round Again (CO)

---

19. Complete Evaluation (CO) Evaluation formally closed after awardees are selected.

## Integration touch points:

### **GCW-GSS integration**

Existing GCW-GSS integration functionality should continue to work \- 

* Create Evaluation form Solicitation  
* Solicitation to Evaluation link  
* Create award for successful offerors  
* Send vendor documents back to Solicitation GCW

### **GSS \- VM Integration**

For included vendors, request resubmission should be triggered in VM so that they can resubmit their proposals

## Vendor Response Analysis (Stretch)

On Start Evaluation, requirements extraction will happen as usual and COs can trigger vendor analysis for vendors.

If vendor analysis wasn't triggered and we are in the setup of a subsequent round, the vendor analysis will be disabled.

At the point of triggering vendor analysis, we will allow COs to trigger only for the current vendors included in the round.

In case of existing analysis, and vendors resubmitted proposals, we will allow COs to trigger the vendor analysis for the additional documents for the vendors and drop findings from deleted documents of vendors

## Request Resubmission Flow in VM

Request resubmission is currently done through a 2 step action in VM. The first step is to provide response due date time and select vendors., The second step is to select if this will be an announcement to all vendors or an email to just the selected vendors.

For Multi round, when setting up a new round, we need to ask CO for the response due date and what they would like to announce to all vendors or mention in the email to the selected vendors.

## Fields \- Evaluation vs Round Specific

|  |  |
| :---- | :---- |
|  |  |
|  |  |
|  |  |
|  |  |
|  |  |
|  |  |
|  |  |
|  |  |
|  |  |

# Mockups

# Success Criteria

# Metrics

# Dogfooding

# Decisions/Open Questions

* Will documents from previous round submitted by vendor need to be part of future rounds?   
  * Yes but it should be configurable for COs to include or exclude  
* If a vendor doesnt submit are they removed from the process?   
  * No  
* Do we want to provide users the ability to change the selected factors during round setup?

Factors \- Add column for round mapping. Show only the relevant factor of phase in Summary  
Vendors \- Show round wise status  
Ratings \- Use round sub tabs  
Consensus Reports \- Use round sub tabs  
Documents \- Common  
Teams \- Use round sub tabs  
Tasks \- Common  
Tasks History \- Common  
Evaluation History \- Common

* Provide Fields: Identify and provide evaluation specific fields required for new rounds setup.  
* Design Sub Factors: Determine visual differentiation requirements for sub factors in the user interface.  
* Review Banner: Evaluate the impact of including the missing information banner during the setup of a new round.  
* Evaluate Round Sorting: Assess the feasibility of sorting rounds in descending order or implementing batching.  
* Request Edit Model: Request a design model for the functionality to edit round details.  
* Document Analysis Features: Create a separate document to capture requirements for the new vendor analysis feature points.  
* Clarify Sub Factors: Finalize and communicate the logic for sub factor selection during evaluation.

# Customer Discussions

Call with Texas DPS: [MicrosoftTeams-video (21).mp4](https://drive.google.com/file/d/1TXlLWym9RHHaQ-JDaRPeeg9x2fK_3h6i/view?ts=6a5e790e)  
Call with USCG CS team: [SS Functionality Discussion - 2026/07/13 14:00 EDT - Notes by Gemini](https://docs.google.com/document/d/1BGwTOvIIoyC0RRD4wWMqKY08LGL0Zw_BrKnMTWYm_vk/edit?tab=t.n5u9mlx8omj)

# Gemini Research

# **Strategic Analysis of Multi-Phase Evaluation and Down-Select Methodologies in Federal Procurement: Regulatory Analysis, Case Statistics, and Software Platform Feasibility**

## **Executive Overview and the Modern Acquisition Landscape**

In the highly regulated arena of federal acquisition, procurement agencies face the persistent challenge of managing increasingly complex, high-technology requirements while navigating compressed acquisition schedules, limited evaluator availability, and an overwhelming volume of bulky proposals.1 Traditional competitive solicitations often impose substantial bid and proposal costs on commercial vendors and place an immense administrative burden on federal evaluation teams, who must document consensus evaluations and preserve extensive records to withstand post-award protest scrutiny.1 To mitigate these systemic inefficiencies, the federal acquisition sector has increasingly adopted multi-phase evaluation strategies, commonly referred to as down-selects.2  
A down-select is a phased proposal submission and evaluation process designed to progressively narrow the competitive field from a large pool of initial offerors to a small, highly viable cohort in the final phase.5 This procurement model typically bifurcates or trifurcates the solicitation lifecycle.1 In the initial phase, offerors submit a lightweight, highly targeted package—focusing on key discriminators such as prior experience, technical qualifications, or high-level concept papers—enabling evaluators to assess core capability without reviewing voluminous technical and pricing structures.1 Heavy technical submissions, detailed solution demonstrations, and comprehensive pricing matrices are reserved for subsequent phases, involving only those vendors with a realistic probability of contract award.1  
This strategic analysis evaluates the qualitative and quantitative parameters of multi-phase down-selects within the federal procurement landscape. It analyzes the actual volume of cases utilizing these methodologies, examines how contracting officers execute these sequential evaluations today, and assesses the commercial viability of building a native, automated multi-phase evaluation and down-select module within a government-focused source selection platform.3

## **Quantitative Analysis of Case Volumes, Protest Metrics, and Institutional Adoption**

Historically, multi-phase evaluations were treated as an underutilized, niche strategy primarily confined to major civil engineering works or complex military systems.12 However, empirical data shows a massive surge in down-select implementations across civilian and defense agencies over the past several years, specifically driven by digital services, information technology, and professional service acquisitions.11

### **Historical Case Volume and the Post-2020 Protest Surge**

A historical analysis of bid protest decisions before the Government Accountability Office (GAO) highlights the rapid acceleration of these evaluation models.11 Prior to 2020, GAO protest decisions referencing advisory down-selects were virtually non-existent, illustrating that the federal acquisition workforce has only recently embraced the methodology at scale.11 A legal analysis of active cases indicates that of the 18 major GAO protests involving advisory down-selects, only one predated the year 2020\.11 This baseline historical case was *Kathpal Technologies, Inc.; Computer & Hi-Tech Management, Inc. (B-283137.3)*, decided on December 30, 1999\.11 The remaining 17 protests have all concentrated post-2020, demonstrating that the methodology has transitioned from an experimental pilot technique into a mainstream, heavily litigated procurement vehicle.11  
To understand the institutional footprint of these procurements, the table below compiles documented multi-phase down-select cases across major civilian and defense agencies, highlighting their values, structures, and outcomes:

| Agency and Procurement Program | Estimated Value | Phased Evaluation Structure | Sourcing Framework and SOW Detail |
| :---- | :---- | :---- | :---- |
| **FEMA COVID-19 Medical Personnel Buy** 15 | $3.00 Billion | Two-Phase Advisory: Phase 1 evaluated highly brief papers; Phase 2 evaluated 2-hour oral presentations and a 12-page written proposal.15 | FAR Part 12 / Part 15; managed under extreme time constraints to staff 120 vaccination centers.15 |
| **USCIS Small Business Set-Aside** 5 | $108.00 Million | Two-Phase Advisory: Phase 1 down-select followed by a live coding challenge in Phase 2\.5 | FAR 8.405-2; set aside for small businesses utilizing agile software development criteria.5 |
| **DHS S\&T IT Services BPA** 5 | $111.00 Million | Three-Phase Down-Select: Consolidated five legacy contracts into a single blanket purchase agreement.5 | FAR Part 8; awarded to a woman-owned small business within nine months of solicitation release.5 |
| **USCIS Digital Services Task Orders** 5 | $231.00 Million | Two-Phase Advisory: Structured to evaluate oral presentations and technical designs across two distinct task orders.5 | FAR 16.505; utilized task order flexibilities to bypass traditional competitive range reviews.5 |
| **CBP Technology Modernization BPA** 6 | $77.00 Million | Two-Phase Advisory: Phase 1 past experience screening followed by detailed technical evaluations in Phase 2\.6 | FAR 8.405-3; designed to optimize software and system delivery.6 |
| **DHS OIG Task Order** 6 | $6.20 Million | Two-Phase Firm: Government-initiated elimination of non-competitive vendors after initial phase.6 | FAR 16.505; fast-tracked task order award under administrative oversight.6 |
| **ICE LEIDS Software RFP** 18 | Undisclosed | Two-Phase Advisory: Phase 1 evaluated technical capability (Factor 1); Phase 2 evaluated oral presentations, trials, and pricing.8 | FAR Part 15; features a mandatory 5-day software trial period for up to three government users.18 |
| **USCG AUXDATA Modernization BPA** 1 | Undisclosed | Three-Phase Advisory: Phase I Prior Experience, Phase II Technical Demo/Orals, Phase III Schedule and Price Matrix.1 | FAR Part 8 / Part 13; issued as firm-fixed price calls using a highly structured advisory pathway.1 |
| **DHS FirstSource III Program** 20 | Multi-Billion | Two-Phase Advisory: Conducted massive intake of proposals, receiving over 300 competitive submissions in Phase II.20 | Government-Wide Acquisition Contract (GWAC); required multiple milestone extensions due to proposal volume.20 |
| **Joint Transportation Management System** 21 | $756.78 Million | Two-Phase Advisory: Phase I technical capabilities; Phase II technical approach, solution demonstration, and cost.19 | U.S. Transportation Command ERP implementation; non-price factors collectively outweighed cost/price.21 |

### **Statistical Insights from the Procurement Innovation Lab**

The Department of Homeland Security (DHS) has served as the primary institutional driver of modern down-select methodologies, utilizing its Procurement Innovation Lab (PIL) to coach contracting teams on alternative evaluation techniques.17 The PIL’s annualized performance data validates the operational maturity of the technique.17 Since its inception in March 2015, the PIL has coached over 140 projects.15 In fiscal year 2022, the PIL directly coached 20 major projects with a cumulative value of $2.97 billion, realizing $814 million in validated cost savings relative to the Independent Government Cost Estimate (IGCE).17  
The statistics also reveal that down-selects are highly compatible with small business participation.17 Of the 14 small business set-aside projects coached by the PIL in fiscal year 2022, 13 utilized advisory down-selects, 13 used on-the-spot consensus, and 11 utilized highly abbreviated, brief proposals.17 The PIL's documentation indicates a 99% cumulative success rate in executing these procurements without receiving sustained bid protests, largely because the advisory process empowers non-competitive contractors to self-select out of the acquisition before incurring the heavy B\&P costs associated with full proposals.2

### **Expanding GAO Bid Protest Jurisdiction Over Down-Selects**

As multi-phase methodologies proliferate, federal courts and the GAO have expanded their oversight, particularly regarding alternative contracting vehicles.25 Historically, GAO generally declined to review protests challenging awards or solicitations of non-procurement instruments, such as Other Transaction (OT) agreements, under 4 C.F.R. § 21.5(m).25 However, in the landmark decision *ARiA (Army xTechScalable AI competition)*, GAO established a critical precedent.25  
GAO asserted jurisdiction over protests challenging the award of non-procurement instruments if those intermediate awards are necessary to identify the only entities eligible to submit proposals for a subsequent procurement contract.25 Where an OT competition operates similarly to a down-select or competitive range process, eliminating offerors through successive rounds that ultimately lead to a procurement contract, GAO will review the evaluation and down-select decisions under traditional procurement standards.25 This legal evolution underscores that down-selects—regardless of the underlying contract vehicle—are subject to strict federal evaluation standards and require precise system documentation.3

## **The Legal and Regulatory Architecture of Down-Selection**

Multi-phase evaluations are conducted under distinct sections of the FAR, each possessing unique procedural mandates, price evaluation requirements, and structural limitations.5

### **FAR 15.202: The Advisory Multi-Step Process**

The advisory multi-step process outlined in FAR 15.202 is designed as a pre-solicitation screening approach.26 Under this framework, the agency publishes a presolicitation notice in accordance with FAR 5.204, inviting potential offerors to submit high-level information—such as qualifications, technical concepts, and limited pricing data—to allow the government to advise them on their viability.26  
The critical legal distinction of FAR 15.202 is that the government’s advice is purely advisory.26 The contracting officer must notify each respondent in writing whether they are invited to participate or whether they are unlikely to be viable competitors, providing the general basis for that opinion.26 However, the notice must explicitly inform all respondents that, notwithstanding the government's advice, they may still participate in the resultant competitive acquisition.26 An unfavorable advisory opinion does not legally disqualify a firm or bar them from submitting a full proposal.26  
From a protest perspective, a negative advisory notice under FAR 15.202 is generally not subject to immediate GAO protest.11 Because the procurement is ongoing and the offeror has not been formally excluded, a protest challenging the Phase One evaluation is legally premature.11 To preserve their right to protest the final award, the uncompetitive vendor must make the business decision to invest substantial resources in compiling a full Phase Two proposal, knowing they are starting from a significantly disadvantaged competitive position.11

### **FAR 16.505: Fair Opportunity Task Order Down-Selects**

For task and delivery orders issued under multiple-award IDIQ contracts, FAR 16.505 gives contracting officers broad discretion to design streamlined order placement procedures, including multi-phase down-selects.28 Under FAR 16.505, down-selects can be structured as either advisory or firm (government-initiated).8  
If a firm down-select is utilized, the contracting officer formally eliminates non-competitive vendors at the end of a phase.5 This exclusion represents a formal gate, requiring the contracting officer to issue pre-award notices of exclusion in accordance with FAR 15.503(a)(1).5 This formal exclusion immediately triggers the vendor's right to request a debriefing and, depending on the statutory dollar threshold of the task order (e.g., $10 million for civilian agency orders, $25 million for Department of Defense orders), permits them to file an immediate post-exclusion protest.8

### **FAR 36.3: Two-Phase Design-Build Selection Procedures**

The two-phase design-build selection procedures codified under FAR Subpart 36.3 represent a highly structured, statutory framework authorized by 10 U.S.C. 3241 and 41 U.S.C. 3309\.12 This methodology is mandatory when three or more offers are anticipated, design work must be performed by offerors prior to developing cost proposals, and offerors will incur substantial expenses in preparing technical bids.32  
In Phase One, the solicitation requires the submission of technical approach and technical qualifications (such as specialized experience, capability to perform, and past performance of the design-build team).33 Price-related factors are strictly prohibited from being evaluated during Phase One.33 The contracting officer evaluates Phase One submissions and selects the most highly qualified offerors to advance to Phase Two.33  
By statutory mandate, the maximum number of offerors selected to submit Phase Two proposals normally cannot exceed five, unless the contracting officer documents that a higher number is in the government's interest and consistent with the design-build objectives.33 Phase Two proposals—which encompass detailed engineering designs, small business utilization plans, and price—are then evaluated under standard FAR Part 15 competitive negotiation guidelines to make a best-value tradeoff award.33  
Recent regulatory updates, specifically GSA Class Deviation RFO 202536 implementing Executive Order 14275, have reorganized FAR Part 36 to align with the modern acquisition lifecycle.37 Under this deviation, the procedural instructions for two-phase design-build selections have been moved from the legacy FAR 36.303 section into a streamlined FAR 36.101-2 section, giving contracting activities broader discretion regarding whether to issue one consolidated solicitation or two sequential solicitation documents.37

### **The Price Evaluation Debate in Early Sourcing Steps**

A critical legal and operational tension exists regarding whether contracting officers must evaluate price during the initial phases of multi-phase acquisitions.33 Under the statutory framework of FAR 36.3, evaluating cost or price in Phase One is explicitly illegal, as the entire purpose of the design-build statute is to assess engineering capability before contractors invest in pricing complex, uncompleted designs.33  
However, outside of construction, when agencies attempt to run multi-step down-selects under FAR Part 8 (Federal Supply Schedules) or FAR Part 15 (Negotiated Contracting), they encounter strict statutory rules regarding price.38 Federal procurement law (specifically 41 U.S.C. § 3306 and 10 U.S.C. § 3206\) dictates that cost or price to the government must be considered in every competitive source selection.38  
In *Sevatec, Inc. et al. (B-413559.3)* and *Octo Consulting Group, Inc. v. United States*, both the GAO and the Court of Federal Claims ruled that agencies cannot entirely ignore price in any intermediate evaluation step that results in a binding exclusion or "down-select" from further competition.38 If an agency utilizes a firm down-select in Phase One, excluding some vendors and permitting others to proceed to Phase Two, price must be considered as part of that Phase One screening.38  
To bypass this legal hurdle, agencies increasingly rely on *advisory* down-selects under FAR 15.202 and FAR 16.505.2 Because advisory down-selects do not legally exclude any vendor from the final competition, they do not constitute a formal "source selection step" under the *Sevatec* precedent, allowing the government to evaluate qualifications first and defer complex price evaluations entirely to the final phase.2

## **Current State Analysis: How Federal Agencies Execute Down-Selects Manually**

Despite the growing popularity of multi-phase evaluations, the actual mechanics of executing a down-select within federal agencies are characterized by administrative friction and manual labor.3 Because standard government contract writing systems and basic source selection portals lack native, multi-phase tracking features, contracting officers are forced to orchestrate these complex, sequential evaluations through a fragmented combination of local spreadsheets, disjointed shared folders, and manual email notifications.10

### **The Manual Down-Select Workflow**

The operational execution of a manual down-select requires a high level of administrative coordination.10 Upon receiving proposals, the contracting officer must establish offline local drives or shared folders to store and organize submissions.10 Because phase-specific criteria vary, the contracting officer must manually construct Excel-based consensus matrices to track evaluator scores and adjectival or confidence ratings across sequential rounds.9 Evaluators complete individual scorecards on word processors, which are then manually compiled into a consolidated, master spreadsheet.3  
Once the Phase One consensus is finalized, the contracting officer must manually draft and send individual, custom-written email notifications to every participating contractor.8 For uncompetitive vendors, the contracting officer must manually input the qualitative "general basis" for the government's non-viability finding, ensuring the text remains legally accurate to withstand protest scrutiny.11  
For vendors advancing to Phase Two, the contracting officer must manually establish new folders, reconfigure file-sharing permissions to isolate Phase Two data, and reassign evaluation teams.10 If the solicitation requires vendors to submit revised proposals or new documents (such as technical architecture designs, key personnel resumes, or oral presentation slides) for Phase Two, the contracting officer must manually accept these uploads, verify their compliance with file size and page constraints, and manually map them to the corresponding Phase Two evaluation factors.8

### **Operational Vulnerabilities and Administrative Friction**

Running multi-phase evaluations manually exposes the agency to severe operational and legal risks 3:

* **Cross-Phase Proposal Discrepancies:** A major vulnerability in manual down-selects is the inability to track changes in vendor data across phases.42 In the protest *IntelliBridge, LLC (B-421560.9)*, the Federal Bureau of Investigation (FBI) conducted a three-phase advisory down-select for digital and IT services.42 The protester, IntelliBridge, was excluded from Phase Three because the staffing solution and Labor Categories (LCATs) submitted in their Phase Three price proposal deviated from the staffing solution they submitted and had evaluated in Phase One.42 In a manual environment, contracting officers lack automated validation utilities to compare technical proposals across phases, making it extremely difficult to identify uncoordinated, non-compliant shifts in a vendor's technical baseline.3  
* **Access Control and Evaluator Bias:** To preserve the integrity of the evaluation, agencies must carefully manage evaluator permissions.10 Evaluators added in Phase Two must not be biased by seeing Phase One evaluation notes or consensus reports unless explicitly permitted by the solicitation.10 Conversely, evaluators removed at the end of Phase One must have their read and write permissions immediately revoked.10 Managing these access boundaries manually across hundreds of users and thousands of documents is highly labor-intensive and prone to administrative error.10  
* **Compromised Audit Trails:** Under protest scrutiny, an agency must be able to present a clean, chronological audit trail detailing exactly when each vendor was evaluated, who authorized the down-select, what specific feedback was issued, and when Phase Two documents were received.3 When these actions are scattered across local spreadsheets, personal emails, and separate consensus logs, compiling a complete, defensible administrative record for the agency's legal counsel becomes an operational bottleneck.3  
* **The Bottleneck of Past Performance Checks:** To assist with manual evaluations, some agencies are experimenting with parallel automation tools.22 For example, the DHS PIL launched the Contractor Performance Assessment Reporting System (CPARS) AI prototype program.22 The project was managed in an agile fashion, awarding seed money of $50,000 to nine companies in Phase One, and advancing seven companies to Phase Two to refine software capabilities.22 This AI tool allows contracting officers to feed a solicitation into an NLP engine, which automatically mines the CPARS database to identify relevant past performance records for each offeror.22 While this automates the past performance check, it remains a disconnected point solution, leaving the broader down-select, consensus, and gateway management processes completely manual.10

## **Customer Requirement Validation and Platform Feasibility Study**

For a product development team managing a government-focused source selection platform, building a native "Multi-Phase Evaluation and Down-Select" feature represents a highly viable, high-ROI strategic opportunity.2

### **Translation of State, Local, and FederalSourcing Demands**

The market demand for an automated, sequential evaluation portal is validated by explicit requirements gathered from state, local, and federal entities.10 The table below maps these specific customer requests to their federal equivalents and corresponding regulatory compliance baselines:

| Sponsoring Organization | Customer Operational Request | Federal Sourcing Equivalent | Regulatory Compliance Baseline |
| :---- | :---- | :---- | :---- |
| **UT Arlington & San Francisco Public Utilities Commission (SFPUC)** 10 | A structured gateway system to check for mandatory Minimum Qualifications (MQs) and automatically filter out disqualified vendors from future scoring rounds.10 | Responsibility determinations, responsive/non-responsive screening, and technical acceptability gates.5 | **FAR 9.1 & FAR 15.306:** Ensures the system cleanly terminates evaluations for non-responsible offerors, generating automated notification letters.5 |
| **UT Arlington & SFPUC** 10 | Support for format shifts mid-stream, such as changing from a scored matrix to a pass/fail matrix if only a single vendor remains in the competitive pool.10 | Amending solicitation evaluation rules and transitioning to Lowest Price Technically Acceptable (LPTA) methodologies.10 | **FAR 15.206 & FAR 15.101-2:** Allows the system to dynamically adapt evaluation criteria if a single competitor is left, generating formal system-wide notification templates.10 |
| **Texas Department of Information Resources (DIR) & Architect of the Capitol (AOC)** 10 | Core platform capabilities to support multiple sequential rounds of evaluation, tabulation, and scoring consensus.10 | Multi-phase source selection, sequential scoring, and multi-round best-value tradeoffs.8 | **FAR 15.305 & FAR 16.505:** Mandates separate consensus tracking logs and unified scoring summaries across multiple rounds.10 |
| **Texas DIR & AOC** 10 | Automated tracking mechanisms to manage down-selected vendors, initiate negotiations, and easily log Best and Final Offers (BAFOs).10 | Documenting discussions, managing revisions, and executing the final tradeoff.8 | **FAR 15.307 & FAR 15.503:** Controls the release of BAFO request templates and logs competitive revisions in a secure registry.10 |

### **Quantitative ROI Model of Platform Automation**

To demonstrate the business case for developing this feature, one can model the efficiency gains for a typical federal agency. Consider an agency managing a portfolio of 50 major competitive solicitations annually, with an average of 15 proposals per solicitation.  
The average Procurement Acquisition Lead Time (PALT) for a complex, single-phase best-value procurement is estimated at 180 days, with evaluators spending approximately 120 hours per solicitation in consensus meetings and documentation.3 By implementing a native, automated multi-phase down-select, the evaluation lifecycle is mathematically optimized. Let the total time to evaluate proposals under a traditional single-phase model be ![][image1], and the time under a two-phase down-select model be ![][image2].  
For ![][image3] initial proposals, where ![][image4] represents the number of vendors selected to proceed to Phase Two, the evaluation time is modeled as:  
![][image5]  
![][image6]  
Where:

* ![][image7] is the average labor hours required to evaluate a full technical proposal (estimated at 8 hours).15  
* ![][image8] is the average labor hours required to evaluate a complex pricing matrix (estimated at 4 hours).3  
* ![][image9] is the average labor hours required to evaluate a lightweight Phase One qualification factor, such as past experience (estimated at 1.5 hours).1  
* ![][image10] is the administrative labor hours required to process the down-select and generate notifications (estimated at 0.5 hours per vendor).8

Assuming ![][image11] initial proposals and a targeted down-select of ![][image12] vendors:  
![][image13]  
![][image14]  
This represent a **63.3% reduction in active evaluation and consensus tracking hours** for the source selection team. Applied across an agency’s annual portfolio of 50 procurements, this native automation saves **5,700 high-value labor hours annually**, yielding a massive reduction in PALT while simultaneously mitigating the administrative bottleneck that frequently delays mission-critical acquisitions.5

## **Strategic Competitive Assessment of Source Selection Software**

In evaluating whether to build "down-select" as a platform feature, it is critical to analyze the current landscape of commercial-off-the-shelf (COTS) procurement software.43 The competitive software market is sharply divided between systems designed for buyer-side government entities, seller-side contractors, and commercial supply chain operators.43

### **Appian (Government Source Selection \- GSS & Vendor Management \- VM)**

Appian offers highly specialized, federally aligned modules that integrate with its base low-code platform.39

* **Integration and Compliance:** Appian GSS integrates directly with Appian Vendor Management (VM) and GAM Acquisition Central (GSM) to unify supplier profiles.39 It supports importing opportunities directly from SAM.gov, unsealing secure proposals, conducting automated compliance and exclusion checks, and prepopulating source selection consensus evaluations.39  
* **Multi-Phase Footprint:** While Appian provides robust single-round consensus tracking and unified vendor repositories, it currently lacks a native, end-to-end automated wizard specifically designed to manage sequential, multi-phase down-selects.10 Contracting officers must manually adjust GSS evaluation setups to transition between phases, representing a critical product gap.10

### **GovDash and Sourcing Proposal Assistants (Awarded AI, AutogenAI)**

GovDash is a modern, unified federal contracting platform built primarily to assist government contractors in identifying opportunities, managing pipelines, and writing proposals.43

* **Integration and Compliance:** GovDash, alongside tools like Awarded AI by Procurement Sciences, leverages domain-trained generative AI models to ingest RFP documents, extract compliance matrices, and draft proposal narratives directly within Microsoft Word.43  
* **Multi-Phase Footprint:** These platforms operate on the seller side of the procurement equation.43 They do not provide evaluation or source selection tools for federal contracting officers.43 However, their AI compliance models are highly effective at tracking multi-round requirements, helping contractors ensure that subsequent phase submissions remain fully aligned with initial proposals.43

### **Euna Solutions (Bonfire Strategic Sourcing)**

Bonfire is a premier public sector buyer-side procurement platform widely utilized by municipalities, school districts, and state agencies.46

* **Integration and Compliance:** Bonfire digitizes the public bidding and RFP lifecycle, offering robust panel-based scoring, weighted multi-criteria evaluations, and blind scoring configurations.46  
* **Multi-Phase Footprint:** Bonfire provides structured evaluation workflows and side-by-side bid comparisons.47 However, it is optimized for local and state regulatory environments.46 It lacks deep integrations with federal systems like SAM.gov or federal contract writing architectures, making it less suitable for federal agencies operating under strict FAR source selection guidelines.46

### **Jaggaer (Jaggaer One / Sourcing Optimization)**

Jaggaer is a massive enterprise-grade Source-to-Pay (S2P) platform widely utilized by public universities, global manufacturing firms, and large government buying organizations.46

* **Integration and Compliance:** Jaggaer excels in sourcing optimization, capable of managing massive, multi-variable sourcing events (such as 10,000-line Bills of Materials across thousands of direct materials suppliers).53 Its Award Navigator utilizes AI to evaluate millions of bid combinations, incorporating capacity, quality, tariff, and geopolitical risk constraints.53  
* **Multi-Phase Footprint:** Jaggaer natively supports complex multi-round negotiations and Best and Final Offer (BAFO) cycles.54 However, its core architecture is mathematically optimized for commercial logistics, direct materials, and structured commercial bid tables.53 It does not natively address the unique qualitative consensus requirements, evaluator masking rules, and legal notification protocols mandated by FAR Part 15 and FAR Part 36 source selections.53

## **System Architecture and Product Functional Specifications**

To build a robust, FAR-compliant multi-phase evaluation feature, the platform must incorporate a series of sequential automated workflows, rigid data permissions, and integrated compliance checks.10

### **High-Level System Workflow**

The proposed system architecture transitions the manual, offline bottleneck into a unified, secure platform environment 10:

> 1. **Solicitation and Setup:** The contracting officer creates a new evaluation record in Government Source Selection (GSS) using the Opportunity ID from Vendor Management (VM).39 The CO toggles on "Multi-Phase Evaluation" and inputs the planned phases (e.g., Phase 1: Prior Experience, Phase 2: Technical Demonstration, Phase 3: Cost/Price).1 The system automatically assigns distinct due dates, evaluation factors, and weights to each phase.10  
> 2. **Phase One Execution:** The system imports all initial vendor proposals.39 Evaluators complete their individual scores and consensus logs within GSS.10 Upon completion of all Phase One consensus forms, the platform prompts the CO to execute the down-select.10  
> 3. **The Down-Select Gateway:** The platform displays a unified down-select interface listing all participating vendors, their Phase One ratings, and compliance status.10 The CO checks the boxes next to the vendors they wish to take to the next round (minimum of one vendor required).10  
> 4. **Automated Notifications and Exclusions:** The system prompts the CO to confirm the down-select.10 Upon confirmation, the system:  
   * Locks all Phase One records as read-only, preserving a complete audit trail.10  
   * For unselected vendors, automatically generates customized advisory letters (FAR 15.202) or formal exclusion notices (FAR 15.503) pulling the general basis for the determination directly from the Phase One consensus data.5  
   * For selected vendors, automatically opens a secure resubmission portal in Vendor Management, notifying them of the Phase Two due date and providing instructions on what documents must be uploaded.10  
> 5. **Subsequent Phase Transitions:** The system automatically initializes "Phase Two In Progress".10 The CO can adjust assignments (adding/removing evaluators), shift phase-specific due dates, and attach new vendor documents while carrying forward the underlying scoring structures and inherited factors.10

### **Dynamic Evaluator Access Security Model**

To maintain the integrity of sequential evaluations, the platform must enforce strict role-based and phase-based security permissions 10:

* **Phase-Level Access Separation:** Access to a specific phase's evaluation details, individual scorecards, and consensus reports must be strictly isolated.10 An evaluator assigned to Phase One must not have read or write access to Phase Two data unless they are explicitly assigned to the Phase Two evaluation team.10  
* **Preventing Evaluator Bias:** New evaluators added in Phase Two must be blocked by default from viewing the historical evaluation scores, qualitative comments, and ratings from Phase One to prevent cognitive bias.10 However, the system must allow the CO to toggle "Historical Visibility" if the solicitation explicitly permits new evaluators to review previous phase data.10  
* **Variable Evaluator Masking:** The platform must allow the CO to configure different evaluator masking rules for each round.10 For example, Phase One can be fully blind (double-masked, hiding vendor names and evaluator identities), while Phase Two (which may include live, unmasked oral presentations) can transition to a single-masked or unmasked format.7

### **Data and Document Inheritance Architecture**

A major challenge in multi-phase acquisitions is maintaining data continuity across successive rounds.10 The platform must feature a structured inheritance engine 10:

* **Document Isolation vs. Overwriting:** When a vendor submits new documents for Phase Two (such as a detailed cost proposal or technical design), the system must store these as a new, distinct "Phase Two Proposal" object mapped to the vendor profile.10 It must strictly prohibit overwriting or replacing original Phase One documents, ensuring that both phases remain fully auditable.10  
* **Dynamic Factor Carries:** If the CO carries forward the evaluation factors from Phase One to Phase Two, the system preserves the factor mappings.10 However, if a factor is removed, modified, or replaced, the system must automatically reset only the affected factor-to-document mappings, preventing evaluators from reviewing obsolete materials.10  
* **The Cross-Phase Compliance Flagger:** To mitigate the risk of protest-vulnerable staffing and pricing deviations (as seen in *IntelliBridge*), the system should include an automated validation check.42 When a vendor submits their Phase Two or Phase Three proposal, the system can parse the structured data (e.g., LCATs, labor hours, and key personnel names) and compare it against the baseline proposal submitted in Phase One, flagging any discrepancies for the contracting officer.42

## **Strategic Actionable Recommendations**

Based on the quantitative case statistics, the complex regulatory framework, the manual inefficiencies of the current state, and the competitive software landscape, the following strategic recommendations are provided for the product development roadmap:

### **1\. Approve and Prioritize the Multi-Phase Evaluation Feature**

Developing a native, fully automated, FAR-compliant multi-phase evaluation and down-select feature is highly worth building.2 It addresses a critical pain point in the federal acquisition space, capturing a market segment that is currently ignored by commercial-focused S2P suites.3 The feature will provide immediate competitive differentiation for Appian GSS, helping to secure preferred-vendor status across civilian and defense agencies.39

### **2\. Design for Strict Regulatory Defensibility**

The product team must ensure the system architecture is built around the strict legal requirements of the FAR.5 The system must support both advisory and firm down-selects.5 The automated letter generator must include templates tailored to FAR 15.202 (noting that the advice is a recommendation only and does not bar participation) and FAR 15.503(a)(1) (noting a formal exclusion and providing the general basis to trigger debriefing and protest timelines).5

### **3\. Build a Cross-Phase Validation Utility**

To provide maximum value and protect agencies from protests, the platform must move beyond mere administrative tracking and include analytical compliance checks.3 The product team should design a validation utility that compares vendor data (LCATs, key personnel, staffing levels, and price elements) across phases, automatically flagging deviations to ensure the final best-value tradeoff remains legally compliant.3

#### **Works cited**

> 1. Down Selects | Acquisition Gateway, accessed June 15, 2026, [Down Selects | Acquisition Gateway](https://acquisitiongateway.gov/ptai-finder/resources/12152%3Fnid%3D12152)  
> 2. Down-Selects | FAI.GOV, accessed June 15, 2026, [Down-Selects | FAI.GOV](https://www.fai.gov/periodic-table/down-selects)  
> 3. AI in Government Source Selection: Accelerating Acquisition Without Undermining Defensibility | Costello College of Business, accessed June 15, 2026, [https://business.gmu.edu/news/2026-05/ai-government-source-selection-accelerating-acquisition-without-undermining](https://business.gmu.edu/news/2026-05/ai-government-source-selection-accelerating-acquisition-without-undermining)  
> 4. Evaluate Responses in Phases with the Multiphase Downselect Technique \- NITAAC \- NIH, accessed June 15, 2026, [https://nitaac.nih.gov/resources/news/evaluate-responses-phases-multiphase-downselect-technique](https://nitaac.nih.gov/resources/news/evaluate-responses-phases-multiphase-downselect-technique)  
> 5. PIL Innovation Snapshots | Down-Selects, accessed June 15, 2026, [https://www.dhs.gov/sites/default/files/2025-03/25\_0312\_cpo-innovation-snapshots-down-selects.pdf](https://www.dhs.gov/sites/default/files/2025-03/25_0312_cpo-innovation-snapshots-down-selects.pdf)  
> 6. PIL Innovation Snapshots | Down-Selects, accessed June 15, 2026, [https://www.dhs.gov/sites/default/files/2025-11/25\_0924\_cpo-pil-innovation-snapshot-down-selects.pdf](https://www.dhs.gov/sites/default/files/2025-11/25_0924_cpo-pil-innovation-snapshot-down-selects.pdf)  
> 7. PIL Technique 4: Down-Select \- YouTube, accessed June 15, 2026, [https://www.youtube.com/watch?v=WCcJze7OIpk](https://www.youtube.com/watch?v=WCcJze7OIpk)  
> 8. Innovation Technique 4 — Down-Select \- Procurement Co-Pilot, accessed June 15, 2026, [https://ag-dashboard.acquisitiongateway.gov/system/files/ptai/2023-12/8.%20PIL\_Boot\_Camp\_workbook-Innovation\_Technique\_4.pdf](https://ag-dashboard.acquisitiongateway.gov/system/files/ptai/2023-12/8.%20PIL_Boot_Camp_workbook-Innovation_Technique_4.pdf)  
> 9. PIL Yearbook 2022 \- Homeland Security, accessed June 15, 2026, [https://www.dhs.gov/sites/default/files/2025-03/25\_0312\_cpo-pil-yearbook-2022.pdf](https://www.dhs.gov/sites/default/files/2025-03/25_0312_cpo-pil-yearbook-2022.pdf)  
> 10. GSS: Multi Phase Evaluations \- Downselect  
> 11. New 'Advisory Down Select' Evaluation Approach Alters Contractors' Protest Calculus, accessed June 15, 2026, [https://www.wiley.law/newsletter-New-Advisory-Down-Select-Evaluation-Approach-Alters-Contractors-Protest-Calculus](https://www.wiley.law/newsletter-New-Advisory-Down-Select-Evaluation-Approach-Alters-Contractors-Protest-Calculus)  
> 12. 48 CFR Part 36 \- Subpart 36.3 \- Two-Phase Design-Build Selection Procedures, accessed June 15, 2026, [https://www.law.cornell.edu/cfr/text/48/part-36/subpart-36.3](https://www.law.cornell.edu/cfr/text/48/part-36/subpart-36.3)  
> 13. "Myth-Busting \#4" \- Strengthening Engagement with Industry Paitners through Innovative Business Practices \- Department of Energy, accessed June 15, 2026, [https://www.energy.gov/documents/myth-busting-4-memopdf](https://www.energy.gov/documents/myth-busting-4-memopdf)  
> 14. Multi-Phase Source Selection Strategy Analysis \- DTIC, accessed June 15, 2026, [https://apps.dtic.mil/sti/tr/pdf/ADA386722.pdf](https://apps.dtic.mil/sti/tr/pdf/ADA386722.pdf)  
> 15. The DHS Procurement Innovation Lab is still busy \- Nextgov/FCW, accessed June 15, 2026, [https://www.nextgov.com/ideas/2022/12/dhs-procurement-innovation-lab-still-busy/380753/](https://www.nextgov.com/ideas/2022/12/dhs-procurement-innovation-lab-still-busy/380753/)  
> 16. B-283137.3,B-283137.4,B-283137.5,B-283137.6 \[Protest of Commerce Rejection of Bid for Information Technology Services\] \- Government Accountability Office (GAO), accessed June 15, 2026, [https://www.gao.gov/assets/b-283137.3.pdf](https://www.gao.gov/assets/b-283137.3.pdf)  
> 17. Procurement Innovation Lab 'Pivoting' to Process Improvements as Components' PIL Support Needs Drop \- HSToday, accessed June 15, 2026, [https://www.hstoday.us/featured/procurement-innovation-lab-pivoting-to-process-improvements-as-components-pil-support-needs-drop/](https://www.hstoday.us/featured/procurement-innovation-lab-pivoting-to-process-improvements-as-components-pil-support-needs-drop/)  
> 18. Solicitation number 70CMSD21R00000002 Law Enforcement Investigative Database Subscription (LEIDS) December 7, 2020 Page 1 of 34 \- Procurement Co-Pilot, accessed June 15, 2026, [https://ag-dashboard.acquisitiongateway.gov/system/files/ptai/2023-12/3.%20DHS%20ICE%20LEIDS%20RFP%20%26%20PWS.pdf](https://ag-dashboard.acquisitiongateway.gov/system/files/ptai/2023-12/3.%20DHS%20ICE%20LEIDS%20RFP%20%26%20PWS.pdf)  
> 19. B-423859; B-423859.2, Accenture Federal Services, LLC, accessed June 15, 2026, [https://www.gao.gov/assets/890/883668.pdf](https://www.gao.gov/assets/890/883668.pdf)  
> 20. FirstSource III Solicitation \- SAM.gov, accessed June 15, 2026, [https://sam.gov/opp/16b06eded9d54a338a152edd3d386ccd/view](https://sam.gov/opp/16b06eded9d54a338a152edd3d386ccd/view)  
> 21. GAO Denies JTMS Protest: OCI Due Diligence, Demonstration “Musts,” and Late Price Concessions \- Fed Contract Pros, accessed June 15, 2026, [https://www.fedcontractpros.com/blog/gao-denies-jtms-protest-oci-due-diligence-demonstration-musts-and-late-price-concessions](https://www.fedcontractpros.com/blog/gao-denies-jtms-protest-oci-due-diligence-demonstration-musts-and-late-price-concessions)  
> 22. Successful Adoption of Intelligent Automation in Government: The Case of the DHS Procurement Innovation Lab, accessed June 15, 2026, [https://www.businessofgovernment.org/blog/successful-adoption-intelligent-automation-government-case-dhs-procurement-innovation-lab](https://www.businessofgovernment.org/blog/successful-adoption-intelligent-automation-government-case-dhs-procurement-innovation-lab)  
> 23. Procurement Innovation Lab Yearbook 2020 \- Homeland Security, accessed June 15, 2026, [https://www.dhs.gov/sites/default/files/2025-03/25\_0312\_cpo-pil-yearbook-2020.pdf](https://www.dhs.gov/sites/default/files/2025-03/25_0312_cpo-pil-yearbook-2020.pdf)  
> 24. Acquisition Innovation & Small Business Participation in Federal Procurement \- Biden White House, accessed June 15, 2026, [https://bidenwhitehouse.archives.gov/wp-content/uploads/2024/05/SIGNED-Report-to-Congress\_Acquisition-Innovation-Small-Business-Participation-in-Federal-Procurement.pdf?cb=1715634435](https://bidenwhitehouse.archives.gov/wp-content/uploads/2024/05/SIGNED-Report-to-Congress_Acquisition-Innovation-Small-Business-Participation-in-Federal-Procurement.pdf?cb=1715634435)  
> 25. Has the GAO Opened the Door to Certain Other Transaction (OT) Bid Protests?, accessed June 15, 2026, [https://govcon.mofo.com/topics/gao-opens-the-door-to-certain-other-transaction-bid-protests](https://govcon.mofo.com/topics/gao-opens-the-door-to-certain-other-transaction-bid-protests)  
> 26. FAR 15.202 — Advisory multi-step process. \- SamSearch \- AI for Government Contracting, accessed June 15, 2026, [https://samsearch.co/far-navigator/15-202-advisory-multi-step-process](https://samsearch.co/far-navigator/15-202-advisory-multi-step-process)  
> 27. 48 CFR § 15.202 \- Advisory multi-step process. \- Law.Cornell.Edu, accessed June 15, 2026, [https://www.law.cornell.edu/cfr/text/48/15.202](https://www.law.cornell.edu/cfr/text/48/15.202)  
> 28. Streamlining Acquisitions with the Multiphase Downselect ..., accessed June 15, 2026, [https://nitaac.nih.gov/resources/articles/streamlining-acquisitions-multiphase-downselect-technique](https://nitaac.nih.gov/resources/articles/streamlining-acquisitions-multiphase-downselect-technique)  
> 29. NITAAC IT Acquisitions, accessed June 15, 2026, [https://nitaac.nih.gov/taxonomy/term/43191](https://nitaac.nih.gov/taxonomy/term/43191)  
> 30. Federal Authorities \- NITAAC \- NIH, accessed June 15, 2026, [https://nitaac.nih.gov/about/federal-authorities](https://nitaac.nih.gov/about/federal-authorities)  
> 31. B-421203; B-421203.2, Paradyme Management, Inc., accessed June 15, 2026, [https://www.gao.gov/assets/820/817275.pdf](https://www.gao.gov/assets/820/817275.pdf)  
> 32. Subpart 36.3 \- Two-Phase Design-Build Selection Procedures | Acquisition.GOV, accessed June 15, 2026, [https://www.acquisition.gov/far/subpart-36.3](https://www.acquisition.gov/far/subpart-36.3)  
> 33. 756 Subpart 36.3—Two-Phase Design- Build Selection Procedures \- GovInfo, accessed June 15, 2026, [https://www.govinfo.gov/content/pkg/CFR-2008-title48-vol1/pdf/CFR-2008-title48-vol1-part36-subpart36-3.pdf](https://www.govinfo.gov/content/pkg/CFR-2008-title48-vol1/pdf/CFR-2008-title48-vol1-part36-subpart36-3.pdf)  
> 34. VA244-13-R-0835-003.docx \- VA Vendor Portal, accessed June 15, 2026, [https://www.vendorportal.ecms.va.gov/FBODocumentServer/DocumentServer.aspx?DocumentId=766255\&FileName=VA244-13-R-0835-003.docx](https://www.vendorportal.ecms.va.gov/FBODocumentServer/DocumentServer.aspx?DocumentId=766255&FileName=VA244-13-R-0835-003.docx)  
> 35. Bid Protest decisions listed by Federal Acquisition Regulation \- WIFCON, accessed June 15, 2026, [https://www.wifcon.com/pd36\_3.htm](https://www.wifcon.com/pd36_3.htm)  
> 36. Two-phase design-build selection procedures from 48 CFR § 36.102 | LII / Legal Information Institute, accessed June 15, 2026, [https://www.law.cornell.edu/definitions/index.php?width=840\&height=800\&iframe=true\&def\_id=aa0609c758944dad8e4fd334804f24ad\&term\_occur=999\&term\_src=Title:48:Chapter:1:Subchapter:F:Part:36:Subpart:36.3:36.301](https://www.law.cornell.edu/definitions/index.php?width=840&height=800&iframe=true&def_id=aa0609c758944dad8e4fd334804f24ad&term_occur=999&term_src=Title:48:Chapter:1:Subchapter:F:Part:36:Subpart:36.3:36.301)  
> 37. Class Deviation RFO-2025-36: FAR Class Deviation for FAR Part 36 in Support of Executive Order 14275, Restoring Common Sense to Federal Procurement | GSA, accessed June 15, 2026, [https://www.gsa.gov/policy-regulations/policy/acquisition-policy/acquisition-policy-library-and-resources/rfo202536](https://www.gsa.gov/policy-regulations/policy/acquisition-policy/acquisition-policy-library-and-resources/rfo202536)  
> 38. Multi-phase approach to Awarding BPAs \- Schedules, GWACS, MACs, IDIQs \- WIFCON, accessed June 15, 2026, [https://www.wifcon.com/discussion/index.php?/forums/topic/4683-multi-phase-approach-to-awarding-bpas/](https://www.wifcon.com/discussion/index.php?/forums/topic/4683-multi-phase-approach-to-awarding-bpas/)  
> 39. Vendor Management Overview \- Appian Documentation, accessed June 15, 2026, [https://docs.appian.com/suite/help/26.5/vm-25.3.2.6/appian-vendor-management.html](https://docs.appian.com/suite/help/26.5/vm-25.3.2.6/appian-vendor-management.html)  
> 40. GUIDANCE FOR CONTRACTING OFFICERS STRUGGLING WITH COMPETITIVE SOURCING \- Department of Transportation, accessed June 15, 2026, [https://www.transportation.gov/sites/dot.gov/files/docs/A76\_CO\_Guidance.pdf](https://www.transportation.gov/sites/dot.gov/files/docs/A76_CO_Guidance.pdf)  
> 41. BEST PRACTICES for COLLECTING AND USING CURRENT AND PAST PERFORMANCE INFORMATION, accessed June 15, 2026, [https://obamawhitehouse.archives.gov/omb/best\_practice\_re\_past\_perf](https://obamawhitehouse.archives.gov/omb/best_practice_re_past_perf)  
> 42. B-421560.9, IntelliBridge, LLC \- GAO, accessed June 15, 2026, [https://www.gao.gov/assets/880/870855.pdf](https://www.gao.gov/assets/880/870855.pdf)  
> 43. Federal Contracting CRM 2026 | GovDash, accessed June 15, 2026, [https://www.govdash.com/blog/best-federal-contracting-crm-platforms](https://www.govdash.com/blog/best-federal-contracting-crm-platforms)  
> 44. GSA's Government-wide Strategic Solutions (GSS) for Desktops and Laptops Program, accessed June 15, 2026, [https://buy.gsa.gov/api/system/files/documents/GSS-Desktop-Laptop-Guide.pdf](https://buy.gsa.gov/api/system/files/documents/GSS-Desktop-Laptop-Guide.pdf)  
> 45. Best Government Proposal Management Software: What Federal Contractors Should Know, accessed June 15, 2026, [https://www.procurementsciences.com/blog/best-government-proposal-management-software](https://www.procurementsciences.com/blog/best-government-proposal-management-software)  
> 46. Best RFP Software for Government & Public Sector 2026 \- Steerlab, accessed June 15, 2026, [https://www.steerlab.ai/blog/best-rfp-software-government-public-sector](https://www.steerlab.ai/blog/best-rfp-software-government-public-sector)  
> 47. Best RFP Software Tools for Procurement Teams in 2026: A Buyer's Guide | AuraVMS Blog, accessed June 15, 2026, [https://www.auravms.com/blogs/best-rfp-software-tools-procurement-teams-2026](https://www.auravms.com/blogs/best-rfp-software-tools-procurement-teams-2026)  
> 48. 10 Best Tender Management Softwares: Ranked & Reviewed \- SparrowGenie, accessed June 15, 2026, [https://www.sparrowgenie.com/blog/tender-management-software](https://www.sparrowgenie.com/blog/tender-management-software)  
> 49. Managing Vendors \- Appian Documentation, accessed June 15, 2026, [https://docs.appian.com/suite/help/26.5/gss-26.3.3.0/gss-managing-vendors.html](https://docs.appian.com/suite/help/26.5/gss-26.3.3.0/gss-managing-vendors.html)  
> 50. GAM Acquisition Central 1.1 Release Notes \- Appian Documentation, accessed June 15, 2026, [https://docs.appian.com/suite/help/26.5/gms-25.3.1.1/gms-release-notes.html](https://docs.appian.com/suite/help/26.5/gms-25.3.1.1/gms-release-notes.html)  
> 51. Archer Search Report \- LibStaff, accessed June 15, 2026, [https://libstaff.uta.edu/resource/194/TX-RAMP%20Certified%20Cloud%20Products%202.2.26.xlsx](https://libstaff.uta.edu/resource/194/TX-RAMP%20Certified%20Cloud%20Products%202.2.26.xlsx)  
> 52. Best RFP Software for Telecom & Communications Companies in 2026 \- Steerlab, accessed June 15, 2026, [https://www.steerlab.ai/blog/best-rfp-software-telecom-communications-2026](https://www.steerlab.ai/blog/best-rfp-software-telecom-communications-2026)  
> 53. JAGGAER Sourcing Optimization | Smarter eSourcing, accessed June 15, 2026, [https://www.jaggaer.com/solutions/sourcing-optimization](https://www.jaggaer.com/solutions/sourcing-optimization)  
> 54. Drive Efficiency with Source-to-Contract Software \- Jaggaer, accessed June 15, 2026, [https://www.jaggaer.com/solutions/source-to-contract](https://www.jaggaer.com/solutions/source-to-contract)  
> 55. Strategic Sourcing Software & Solutions | JAGGAER, accessed June 15, 2026, [https://www.jaggaer.com/solutions/sourcing](https://www.jaggaer.com/solutions/sourcing)

# Old \- Questions

Multi Phase Evaluation \- Requirement Analysis Questions  
Based on the existing GSS architecture and your initial requirements, I need clarification on the following areas:

1\. User Stories & Acceptance Criteria  
Round Management:

When moving to the next round, should the round number be visible in the Evaluation title (e.g., "HVAC Maintenance Evaluation | Round 2")? No we call it by the pase name say Qualification or Technical or Negotiations  
Can COs add new vendors in subsequent rounds, or is it strictly limited to shortlisted vendors from the previous round? Strictly limited to shortlisted vendors  
What happens if a CO wants to go back and review a previous round's data? Should it be read-only or editable? Read only for CO. Evaluators see or dont see phase 1 based on whether they were part of the team in phase 1  
Vendor Down-Selection:

What's the minimum number of vendors that must be selected to proceed to the next round? (You mentioned "at least 1" \- is this correct?) Yes  
Should there be a maximum limit on vendors per round? No  
Can vendors be eliminated mid-round, or only between rounds? Only between rounds  
Consensus Requirements:

Is consensus required for every round, or only the final round? We should probably add this as a field to ask the CO. If Consensus is required for this round.  
Can Factor Chairs mark factors as complete before all consensus is done in multi-phase evaluations? Yes  
2\. Technical Dependencies & Data Flow  
Data Inheritance Between Rounds:

For factors that are inherited, should the evaluation responses from previous rounds be visible to evaluators in the next round?No. Access to a phase’s details should be available to an Evaluator only if they were part of the Evaluation team in that phase  
Should consensus reports from previous rounds be accessible in subsequent rounds? For Factor chair in one phase can access consensus reports from other phases but we indicate visually that a consensus form is part of which phase  
How should task history be displayed across multiple rounds? In one unified view  
Document Management:

When vendors submit new documents in Round 2, should the old documents from Round 1 still be accessible? Yes  
Should document-to-factor mappings be preserved or reset between rounds? If COs carry forward the factors then yes. If a certain factor was removed then the mapping will be reset.  
Integration Points:

How does multi-phase evaluation work with GCW integration? Should each round create a separate evaluation in GCW or update the existing one? No Impact on GCW side. Clicking on Evaluation should take them to the latest phase of Evaluation in GSS  
For VM integration, if vendors submit new proposals between rounds, how should this be handled? COs can upload these documents and attach to that vendor. Maybe when moving from one phase to next we allow COs to change these things like factors, evaluators, teams, assignment, vendors and their documents. By change we mean update, delete or add new  
3\. Impact on Existing Features  
LPTA Evaluations:

Can LPTA evaluations be multi-phase? If yes, how does the single task model work across rounds? Yes LPTA can be in the first phase. End of the task will enable the action to move to next phase.  
Should pricing information be re-entered for each round? No we can carry forward that. But allow edits  
On-the-Spot Consensus:

Can multi-phase evaluations use on-the-spot consensus? If yes, does it apply to all rounds or specific rounds?Specific rounds  
Masked Evaluators:

Should evaluator masking persist across all rounds, or can it be changed per round? Changed per round  
Evaluation Status:

What status should the evaluation have between rounds? (e.g., "Round 1 Complete", "Round 2 In Progress")  Yes it should be Phase 2 In Progress.  
Should there be a separate status for "Awaiting Next Round"? No it can be Phase 2 Setup  
4\. Performance & Security  
Audit & History:

Should each round have its own audit trail, or should it be combined? Combined is fine  
How should evaluation history display round-specific changes? Just show the changes. Round changes will be captured as an entry as well.  
Permissions:

Can different evaluators be assigned to different rounds? Yes  
Should Factor Chairs remain the same across all rounds? Not necessarily  
Data Volume:

What's the expected maximum number of rounds? (2-3 rounds or more?) Lets keep it 5  
What's the typical number of vendors per round? Theoretically Phase 1 could start with as high as 400  
5\. Edge Cases & Error Scenarios  
Incomplete Rounds:

What happens if a CO starts Round 2 but then wants to go back and modify Round 1? Not allowed.  
Can a CO delete a round once it's started? No. They can delete the whole Evaluation if they want  
What if all vendors are eliminated in an intermediate round? It is mandatory to downselect at least one vendor to go to next round  
Evaluation Completion:

Can an evaluation be completed without going through all planned rounds? No  
Should there be a way to skip a round if needed? No  
Date Management:

You mentioned capturing both round-level dates and overall evaluation dates \- should round dates be enforced to fall within the overall evaluation dates? Yes  
What happens if a round exceeds its due date? Dont allow save.

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADQAAAAaCAYAAAD43n+tAAAB/klEQVR4Xu2WsUscQRSHX5QoihGxUVGDTYKVkMK/QSWgkCJdIEggGAQtQsTGUjGChY2FYqNtKjEQsAgJpIkRQSGQShQRE0QkGoOK+vsxM/ju3RbnssUu7AcfN+/N3u3MzZvZFcnJyUmCZXh9B1MPB/k8ImcH3x6RSx314lZIUyZu4BsmT3ZsIm2swHsmNyxuQn0mXwGnTS51DNkEOJLo0qqDDTaZBaL2T2YpFzeZNduRVUbETeip7SiBN/CtTcZgRhKskL8S/8d49FfZZAweSPwxFJGG/TMJF2wyDjyWS9k/3+ESPFa5PXii4h/wCtbCX3Afdql+0gQP4Ka4Ug2rewFbw0WeL/CTuBO4ZObETeilyWsGYL9vh5VcNzEHEx7O73zuobhyDvARcKliXRW2QhhX+jb/lGrVV8Qz+E/czA+9vPG5FP8weSUuz+9w0IEe+FPFRH//PZxV8Sl8oeJwbY1qk0Efr8Iz2K36EoH/VCP8IIU3/g9bVPxI3KQDvPa+iQM8TMIqT8B51fcRLqo4UcbhbxWzrgNhgGP+k3ts1LdJ6OdjQceEq9Xr26yMNrktz9dS+K75RFx/IvCdjzf/KsUvtH/gtoq5P3RJspS3VMzS2oVTUjg5Pv+4Ws0q9xl+E7cteJCknqi9mil4VIfS48p2qr7M8hh22GROTsa4AQJOffLnhboTAAAAAElFTkSuQmCC>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACkAAAAaCAYAAAAqjnX1AAABnElEQVR4Xu2UvSvFYRTHj5cMomSRvGQw+BMMBqMyEIXFyyArm8GqZDEYDF6T1aDEIlGMyGIQFgOlZBCDl/iezrkcp9/P7enq3lt+n/rUOed57nNP9zz3IUpIyE824UeAOYG/uCei5htqiqhlhUqSX9JSSNLMqasz176QDbZggauNkTTZ4eolcMbVssKoL4AHih5rBazyxVwRdR/ziiKSBo/8Qj4xTtJku1+IYJJkb7NfCGSWAif3SGEfCNkbRzkFnhN6H0P2xjENl30xDn5i0t1Hfq5u4TZchXtab4MbcFhz5t3EzAVcgSP08yl7hXUm/5UFkiaHXN1if7kX2KrxBOyG+5q3wHONmSdYpvEByf4UaafRBZ9J3sZ7le8lN+A/vAYvTe7X+ZxGjXfhoMbcsN3LMU+N4cb9ORnBh/W73OIbScFjXjK5XZuCiybPmB1Yr/Ecydh6v5e/vpzvbSruJBntgOZ98A1Ww2KSiTWQTO9P4Iee/wx3sJTkws+b9XV4TPJvvYJnZo3v5A2sJTnjUOv8Hp/AGs0TEhL+DZ+3CWsqpTvJgAAAAABJRU5ErkJggg==>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABMAAAAaCAYAAABVX2cEAAAA3klEQVR4XmNgGAWUgnlA/BmI/0PxAhRZCPjLgJAHYWdUaUyArBgb2AfEKuiC2AAjEG8H4vUMEMOCUKXBAJclGCAfiE2gbFyu+4MugAu8RWJ/YIAYxockpgbEnUh8vADZJaBwAfFvIoktA2IeJD5OAAqvzWhi6F7F5m2sADm8kMVABnRD+b+Q5PCCd+gCUABznTYQt6DJ4QS4vLCbASJ3D4g50eSwAhYg3osuCAVMDJhhhxMwA/EbID6JLoEEvgHxD3RBdLAKiD8yQNIXKF2B8h42oA/E2eiCo2AUDGkAAM4NNN65dbHtAAAAAElFTkSuQmCC>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADMAAAAaCAYAAAAaAmTUAAACA0lEQVR4Xu2WPUtcQRSGj0YLwYgWamMpIlgEJZ0WivgDDPgTUoiFwd+QCEEhKayNlagIFoIfiMFKEIxooWARURMRQpREQxRNSN7XmeGee3ZXi/XjIveBlz0fu7P3zJy5MyIpKSn5MAydQv+8RmJZx1+J8lR7PJ089MNm4yNUa4NJpACahabEFfMinr4iV5GJoxd67u1cq/PHBpLKkbJ/iCumTMXqoLfKTzR6Jbgv6G+r2ChUqvzEwv0ybWK21bK1XSLR+0XHWMCA9y9UztIMfYXmbOIhOLYBT1idBui1yVkOoRYbfAhytdCCuNwOVGJyllxj3CtF0KINegolc+9oZsTdFsYl8ztfxOXOVGwP+ql8ThJ5A617+x30DaqADqB5aNLnruUJ9B1asQnFb+jcBsEJ1OTtfmgpSsUKewktQ1tZcsHmEcDiSTc0Jq7wgJ2oDCbEzRLPF54rvHtl4xnUY2I8c/QfcPO3ensDGopS8krcTJM2iR66E1rzNhlUNscu9jYLvbGYfHgPfVa+nW192PICy9UhbKsOb6+KK4hUimv3gB6PR0af8m8dvop50yb1Ev15I3QJVXn/qcRXnC1b423+JrTprv8kPLB/KT+MHVb3TmBPfxL3Oma7hg3MGeaZxBv2Bx8LVIt7uH2oXFzh3OShpQiPgC7lc5xN5aekpKQ8Uv4DEUV7dyvSZqsAAAAASUVORK5CYII=>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAA4CAYAAABAFaTtAAAEmklEQVR4Xu3dWah1UxwA8GWIkJlIvBAvCCEZ82BIIfHAmzzwZM5UEkVESpRIIkNKpsyK9OVFPBjiQZEoyUwZMrP+9tq+dde3z7n7fN+9l8PvV//OWv+9ztnDfVirtdfeNyUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP5XjmkT/OW0NgEAjHPbhLg5x6VVu3mzeY43StxY5Q/LsSrH0zleqvJL5fAc67VJ/vZcmwAApnsgx4FV/Y8c21X1b6vyPFo/xw+pO6/aETnuaXJL5bM2kdbc/7/NyWnljvHaNgEATFd30vs09XBvU58356Xh83okx5ZNbikckmPHNpnW3P9KmGWfn6fZ2q+rN9sEADDsqBwHV/WvcrxW1cOuTX3e9IOQj3L8MpCfZNIs0GLfm7R9Un45zbLPaHtOm1xGsxwbAFCJTnSrNjnnnqzK9SDhuqo8Sf3dMGaQ0ba5MMfzOV4t5ZXUHsuQfXNcnLq2cXxnLNy8bMYcGwAwYDk70cdzXNYmV8AGVTnO7+6qPsZTOS5J46/NULvIrctDCGfneKdNjjB0LEP2zvFFmxxpbc9r7LEBAJWD0vhO9PI2McJxbWIFnN/Ud0rdOT7U5KeJhxbiO1e0GyYYuoZDuV/bxCLebhMDTmwi9tvmhsT6tVjntzZOaRMjfd8mAIDFxasWZh1EzOKVNjHCDYvENaubDvqmTaRuEDM0gJqkb3v/guxkQ789NjdNPMU5q7H7GNtuKf0T+wSAuRcd6AltMnVrnMLu5fO+tLqzfb+U471jV+W4peTDnTl2KdtD3UE/mrqZq1ur3HL4uU2k7tbfqjY5QTuoiHNfTPudHXJ8V8qfls+tU/duuM1Kvb/d+Vb5fCbHuTkuKPWbcjxcyu3vTzO2bd0u3l13QOoGw3eU3IOpe6qz/VvG7dCTSnnjtPCYN8xxdSkPGXtsAEDqZtW+Tt1AJgYWv6eu0+7FzFJ0rmdVudurct/xxqL6U5vc9jl+K+V3y2cMPH5M3WBvz5JbavunbnYtzmvoPXIxuFjMsW2iiEHJNEMDkbimn1T1eLBjm1KO/Mepe3dbXK9wV/ns1b8ZT/KONXQsQ15IXdvTq1z93b7cXsvrq3K7r6i/mCbPTLbtAYB18Fj57GerYral1q9nG+rgY+Yo1k3FTFLMtsVA8L0cR5ft/0Wbpu4hhWn6V6fEwCyu1UbVtkOrcq+/nvulbrC5V7VtmnqQOKt+n/Guuj1KOdY51qLN8aUcg+PatAHZtjmObJMAwNqLWbcYeG1S6nHL6/VSjve49X7K8Wwp75bjw7Sw0365Kn+QulmlMTNd82ixtYBx67m//RliAX494InZzifS6lnN+FdaIW6lflnKyy0GkzErelGpD60XjJnSnUs5ttfHHLfJY4btylKvTRvMAQArbGgN2f/FmW1ijsRs6BZtconEmr7l+A8TAMAM4vZezLT1C+yZPzHjF+vuAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABYC38CXDHdlQtQbTUAAAAASUVORK5CYII=>

[image6]: <data:image/png;base64,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>

[image7]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACMAAAAaCAYAAAA9rOU8AAABW0lEQVR4Xu2Uq0tEQRSHj4+mSVgwmawimNU/QFDBYrcLvmCjdcOiQTAb1CQoGBTUIgaxqVkxucEHWESDj9/hnKvHs3d0L4gDMh983JnfzN45s3cYokTiH/EIT3wYizc45cMY9JIU0+wH/pJ+OAT3SIoZ1n4UZuAcSSF32mejwsVM+jAGPSTFNPkBpc0HBRiDD3DJD4TYICkmxHdjjfAKSz4MwYvd+1AZhac+LEihzfBkPsQZRya3ZozDW7gL+0w+CGtwG05o1kHyz1zALXigeRBeqFvbz3aA6ne1AldNf1+fs/BY25v0uaFFeKNtxr+vjirJpCfY6sb8j7m/Ay/pa1F+XsYL7NQ2X6iheT8yAs9clveydsrPGZsvwwXTL8Qhyflgyvr0i2aHOy/3RXKbrw/72RqmC17BNZMNkHzOazhvcr5P+NOdw4pmfIlOf8wgWic5yC0mSyQSv847UXxP2DMs8I8AAAAASUVORK5CYII=>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACkAAAAaCAYAAAAqjnX1AAABf0lEQVR4Xu2WvytGYRTHjx+jsr0TE5skvcpiJkoGFtKbhTIQ8mcos01ZKIPJokRZCMXk92byI5Rfg/ieznk4He9d7jU85X7q033OeZ73vef5ce/7EuXk5GTmBe75ZGx8wimfjIkWkiIrfUcMdMAeuEFSZK/GUTEDZ0kKvNOYjRIucsInY6KZpMgK35GBB5/IyipJkX8FT7bfJ7PCBd77ZGxwkfzwBHb0Ogh3SY7DITyHTdrH8ROchItwWPPrJA9gtcaBI7gCb0yuCJ/hMhw3+bJwkY3afjd5fi2V4IXJ8dhR066BJ3AeFmADPIB9OiaMqzJtZgReapt5NO2yzJF8+I1+r8AZ7DKxPbtJ59jmF+CViQM8Zhse6zUT9oa8tbfaHiPZWk83PDXxBxwwcSBpgqlIWrlr2G7iAO9GPdzUeAt2fvf+FOyL5POeiiG4T1LQK6w1ff4mgWmSf1J1JsfbvaZXPsMMT4S/g1d9SXOp4IMd3e+4pY1kpq2+Iyfnv/MFqI5WD3SUTeEAAAAASUVORK5CYII=>

[image9]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACcAAAAaCAYAAAA0R0VGAAABm0lEQVR4Xu2VSytFYRSGFymUgTIyl5HLyAxTlyKljFymUkpSBvIDRBjKyA/gF8hAucQAuZVkZCQxQpTbu/q+L+9e9tnOGejswX7q6ez1rr2/1tn7O2eLZGRk5OQFHtowLXzBCRumgWZxw5XaRjFphd1wU9xwPb5OBZNwStxgD75WU4UON27DNNAobrgS2wCr4nrMGmwzWRzT4q7ttw2izAaWdfk9QKAL3phsxtRJ5FpXWYDLNrToAo829BzAYRsWQNJwn7DGhhZdQH8UgR065sXL4TG8okyphXfwTNw6lT7vg+e+tweXfD4mbt3gqM9j0RPq/PEbNyQ63FNMVg3fqeaefpFdqu11euf+RJ+9Xvgq0Q3aAa+pVubgCtXPcIhqHoCP9U+et86i5LHfktiHgyaze4jrAXhENfcuYS/VH5LHfksiLK57SamQn0fR7j95AL2LYYBOeEG9cN6JqUf8Z8HMirt7/L7VR697KVAFb+G8RAfdEPdqDJyKewMFtuA2bKDsX7GPvKjoX4S+BZR72EK9VFAPm2yYkZGDbwoOXpAw3LXcAAAAAElFTkSuQmCC>

[image10]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACoAAAAaCAYAAADBuc72AAABnElEQVR4Xu2VzytEURTHjx8LKRGykY0kJVlKUdbKj2xkYyMbpSR7CwsbK5SNlL2FkixQQ7JQin9BJIqS/Czx/brnmTPXvMxbzPTK+9SnOefce9+cd+e+NyIJCQl54Rme+MU48gmn/GLcaBfXaLE/EBe6YC/cFddon+axYxrOiGvyTnMaW9jopF+MG23iGi3yBzyWxc0r9QcKxYa4BnIh13l5gV9+7xez0AJf/GIhYaN8oAKOTFwFb+EZ3IezZqwbXon7k1jTWiPchuvBJPCun49wUGOueYDN8BA+wXodC4WNNmn8Zuo8s/anZlym8RhMpYe+xyrEvebqJL3zQ/BU4wlx60Y05xq+Hsko3NI4lAVxi14l80G5gKsm95u2MG/V+ACOa3wO+zUuh5UaE3sN7vCwySPBCzVozB3njRDuWLZG/4qXTMwb2TO5f71I8NwE8I7n4Irm9sKbcN7kYY0umvgSdmpcDT9gCez4mRGBWnFn9gbWiHsz8IwRnik+HPw369FaAOfwjHLdALyGxxkzfu8gv2fHqyUkJPxbvgCrU1wg0zebZAAAAABJRU5ErkJggg==>

[image11]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEMAAAAaCAYAAADsS+FMAAABxUlEQVR4Xu2Xyy4EQRSGj1tCIh5B4hIbCRbeAC/gKSQWIlZ2FjbY2xAGYWEjiCBuGxtvwMZGxAZxSURcwn9UTeb0SVdNN9ItUV/yJVP/KTXt9ExNNVEgEAh8nzn4CD+shUjV8E6lOtsTLWdKNXzRoWUdTsMWWAE74Q7skpOSIP/ZOA5hqw4z5JTKX+MxReewy5EZCeAubsM1Mgv0R8tfuC4gax7IfS1HcBguwRFVS8wQ7LavXZ1/00FO+JqxT+bG/ogb8fqOzJs1iKwNTohxnviasUe/0Ay5OO8LPD4T2QqsF+M88TVjl8ynnDfYApl5A3JCObiTmyrTXxXXm8fRQeY7G+ciXIDzZH7FZuGM+bPE+JqxAcfEuJbM3F6ReZH7hcx4kSk7dv2U5YGvGXHoG+vlVgeW4iLtcFzV8sTXjBodUMpmuCbyZsS1c1inaj6a4GRK0+BqRiOZfEvliZvBp7kDHVoqKcVCGeJqRjOZvE/lnJU9FlTBa3iiC4In+KzDnOFrimsGwznfxCKjNuON1MkqvCdzvuBzBT97xMFn+0Ed5gQ/P13BC+slmf2On0OKcCN4s3+l0qf6rxwJAoFAIBAIBP4vn1VNhQWRhCKmAAAAAElFTkSuQmCC>

[image12]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFkAAAAaCAYAAADcx/BtAAACsElEQVR4Xu2Yy6tPURTHl9dAIRImJkoeGYhkwB3QzR9AGZugJHmMDQxQHsXAEPd2b+mSMlAeyWuiCDGgKO7PKyXkTR7x/d61d2ed9Tvn9/sZuD/9zv7Ut9/ea92z79nr7L3OOlskkUgkEv8rR6GP0O+g3pxX+SWZn+rOuzueKdCg6NwfQrPy7taxQSziEjTTGyvAAuiy6a8VjdEmY2uJEdBZ6JToAKvy7iHKgt/pfBOd+1hja7QYS9kMLQrtsgF+ekNFGJD6eJTFqCFvTPud6AATjI05aI/pV5klovHZ6x3NsE+FeZf9B8Z2DBpn+lVlsWhsrnpHM5iPTzub3w5/vTXaxA6ov0R9opVTD3QEOgxt5UUtsk90HMZijfM1xeZja+NgHJh8Nz7PUug5dM47OpQxorGpOXtD3npDIK7medBO5/O8hLq8sYOJsZntHWWUpYILor7Hki9fiigbY7hZL/pCalVb9LKGfIZuOBsrLc55u7MXMhq66I2BkVKfmy1nRHPccan/m2eivq/G9gR6b/p8eGQXdCe0D0CvoEnQC+g8dDL42sFkKY5BtM119jpGQa+h695h+CJajHs+QAtDezd0JXPlbmgddA26X+CLbZaKfChkg2hdygcS8RMcbvj/Z5g+75e2QWMr5IToqmJ9zLqYZxNFzIc2OhtrZjtxvvSWhfZd6FDmGtqOXJlkuWTBXAndDm2y37Q5Nl8uJE6onXAxckfyPmrhl1/H/5SD0CPT96vTfsTw4ImrmTA9rAjtm6KBJjx8YdqK2PFYWm4z/crAko0nd2SOZEHhQcoPaGroj5f8DmHqmR7avCamm1r4JfwQ+mT6cey4GyoFc+Yt0bKNaSe+uLgiWVPzxK4n2CLTRIP2FJoo+kD4coupgbBUXG36HOee6ScSiUQikUhUlD9aJ7HFIksdUAAAAABJRU5ErkJggg==>

[image13]: <data:image/png;base64,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>

[image14]: <data:image/png;base64,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>