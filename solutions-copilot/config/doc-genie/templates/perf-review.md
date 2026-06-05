# Solutions Performance Considerations and Planning

**<Insert Solution Release and Feature Name Here>**

The goal of this exercise is to minimize performance risks by ensuring that performance concerns are rigorously considered early in the planning and development of a feature.
In general, solutions development relies on the platform performance thresholds. However this template addresses any additional performance considerations that are specific to a solutions feature.
For a given feature included in a solution release, this document will guide 1) Technical design and architecture, and 2) Performance testing strategy and success metrics.

## SOLUTIONS - Standard performance indicators/metrics

| Performance Area | Metric | Example Measure |
|-----------------|--------|-----------------|
| Data Load | Page load time | < X seconds for interface Y |
| Concurrent Usage | Average response time | < X seconds per request |
| Concurrent Usage | Transactions per time period | X processes per hour |
| Concurrent Usage | System CPU during test | < X% utilization |
| Concurrent Usage | System memory during test | < X% growth |
| Portals | Web API avg response time | < X seconds for web API |
| Other | Time to complete test | < X hours to complete |
| Other | System CPU during test | < X% utilization |
| Other | System memory during test | < X% growth |

The following standard performance guardrails are used for all solutions features.

---

## 1. Data load

### 1a. What are the maximum expected data table sizes after three months and one year of usage for each table impacted by this feature? Will the tables grow linearly? Do any complicated views depend on high volume tables?

**Guidance**

Example data load table of maximum volumes:

| Parent record/table or child? | Name | 3 months volume | 1 year volume | Average per parent |
|-------------------------------|------|-----------------|---------------|-------------------|
| Parent | Requests | 1,000 | 4,000 | |
| Child | Comments | | | 10/request |

**Response**

### 1b. What performance guardrails will be used during development based on the expected data table sizes identified in 1a?

**Guidance**

* Performance Data Load Guardrails.

**Response**

### 1c. How will performance testing be conducted, and how will performance success be measured, based on the expected data table sizes identified in 1a? Can performance testing be done incrementally?

**Guidance**

* Database load/scale testing if necessary, in an environment with the expected data table sizes, and measure:
   * Page load times
   * Health check slow expressions/slow queries
   * SAIL/Http response times log
   * Slow expressions log
   * Record response times in Monitoring tab
* Risks to note:
   * Risk grows over long periods of production usage (weeks or months)

**Response**

---

## 2. Concurrent usage

### 2a. Is this feature expected to have high volume concurrent usage >500 e.g users at a time? Is the feature highly interactive? If so, identify the maximum peak usage (e.g. transactions/hour across x users)

**Guidance**

* Example response: The pass request is expected to be filled out a maximum of 1,000 times within an hour, across 1,000 different users.

**Response**

### 2b. What performance guardrails will be used during development based on the expected concurrent usage identified in 2a?

**Guidance**

* Performance Concurrency Guardrails

**Response**

### 2c. How will performance testing be conducted, and how will performance success be measured, based on the expected concurrent usage identified in 2a? Can performance testing be done incrementally?

**Guidance**

* Concurrency testing using Locust scripts, and measure throughput while monitoring SAIL/Http response times and environment resources.
* Risks to note:
   * Risk is entirely dependent on user usage levels and user behavior
   * Environment hardware plays a big role

**Response**

---

## 3. Portals

### 3a. Does this feature introduce/update a public portal? If so, identify the maximum peak usage of the portal (e.g. portal visits/hour)

**Guidance**

* Example response: The Submit Case portal can expect maximum loads of 2,000 users/hour.

**Response**

### 3b. What performance guardrails will be used during development based on the expected concurrent usage identified in 3a?

**Guidance**

* Performance Concurrency Guardrails

**Response**

### 3c. How will performance testing be conducted, and how will performance success be measured, based on the expected concurrent usage identified in 3a? Can performance testing be done incrementally?

**Guidance**

* Note that the scalability of the portal site itself is guaranteed by the platform team
   * However, the underlying web APIs that back the portal (e.g. load portal data, post portal submission, portal document upload) both impact the performance of underlying environment & will cause the portal to run slowly if they start performing poorly
* Therefore, portal performance testing can be accomplished by mocking portal web API requests to the underlying environment at a rate that matches the maximum peak traffic
   * This should be relatively simpler than building a UI load test to run against the portal, because the portal UI does not need to be measured as much as the web APIs to the underlying environment
* Risks to note:
   * Risk is entirely dependent on user usage levels and user behavior
   * Underlying environment hardware plays a big role

**Response**

---

## 4. Other performance factors

### 4a. Does this feature introduce any other areas of performance concern, such as ETL, bulk processing, non-standard/extensive plugin usage, document generation/management, etc.? What are the maximum production levels (e.g. documents per day)?

**Guidance**

* Example response:
   * Feature will require a sync with an external system once per night, and it needs to complete within one hour.
   * Feature generates 100 documents per hour, each an average size of 50KB.
   * Features relies on Content Utilities plugin in process, which has a maximum input of 1,000 documents.

**Response**

### 4b. What performance guardrails will be used during development based on the other areas of performance concern identified in 3a?

**Guidance**

* Other Performance Guardrails

**Response**

### 4c. How will performance testing be conducted, and how will performance success be measured, given the other areas of performance concern identified in 3a? Can performance testing be done incrementally?

**Guidance**

* Design a test that QEs can use to recreate this scenario with maximum production levels (e.g. test process model).
* Run the test created by the developers (if applicable) to test this feature. Success criteria will be different based on the feature.
   * Does the feature complete in the expected time period?
   * Are the environment resources stable enough during the test?
* Risks to note:
   * Risk is generally not able to be determined without spike tests for these types of features.
   * Environment hardware plays a big role.

**Response**

---

## 5. Performance testing decision

### 5a. Is performance testing needed?

**Guidance**

A feature may not need performance testing if it doesn't require high interactivity, and it doesn't deal with large sets of data. Based on the answers to the previous questions, determine if the feature requires performance testing.

**Response**
