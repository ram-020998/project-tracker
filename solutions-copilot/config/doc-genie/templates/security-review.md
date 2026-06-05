# Solutions Security Review

In general, solutions development rely on the platform security features and measures. However this template addresses any additional measures that are solution specific.
In addition, for each solution release we conduct security review testing and attach the results of Penetration and Code Scanning results to the feature release gate.

## General Guidance

See the following links for an in-depth look at guidance that should be used across your features:
* Access Control
* Injection

---

## 1. Does this feature require changes to the solution's object Security Matrix?

**Guidance**

Assess the changes to security matrix: Role / Object / Authorized actions and the development and testing plans to ensure these intended changes are intact and not conflicting with existing security.
For example:

| Type | Objects | Who (Groups) | What (No Access, View, Edit) |
|------|---------|--------------|------------------------------|
| Sites | | | |
| Process models | | | |
| Record types | | | |
| Reports | | | |
| Document folders | | | |

**Response**

---

## 2. Does this feature require row-level record security?

**Guidance**

Use the new Record-Level Security feature to implement row-level security on synced records. If you cannot accomplish the desired record-level security paradigm with that functionality, please review with the appropriate TAC team in more detail.

**Response**

---

## 3. Does this feature allow uploading of runtime documents that need to be secure?

**Guidance**

Runtime documents are generally secured to a generated folder per runtime group or per record (where there is a runtime group per record). This security generally matches the underlying record instance security (i.e. Only users who can see a record can see its related documents). Note that document objects are not secured by only hiding document download links on the UI. Please reach out to the appropriate TAC team for more information.

**Response**

---

## 4. Does this feature introduce or update a portal?

**Guidance**

Please keep in mind that all information on a portal is publicly available, and all actions that can be done via portal can be done by any non-authenticated user. Therefore, please review:
* All information that is surfaced on a portal can be publicly published (no sensitive information)
* All actions that can be done via portal (e.g. Create an authenticated user on the underlying environment)

**Response**

---

## 5. Does this feature require updating existing plugins or using new ones?

**Guidance**

Plugin code is a part of the solution code and needs to be secured. If there are changes to the plugins then we need to run code scans (see Solutions Security Validation Process).

**Response**

---

## 6. Does this feature require integration with third parties?

**Guidance**

Assess the integration authentication methods, credentials management, allowed integration actions / http verbs and external systems security in general.

**Response**

---

## 7. Restrict Tempo access for users (Default option for solutions)

**Guidance**

Please see Solution Tempo Access Policy.

**Response**

---

## Team Action Items
