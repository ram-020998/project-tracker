# Design Best Practices & Guidance

One of the main distinctions between designing a Solution and a typical Appian application is that a Solution will eventually be handed off to many separate development teams, who will be responsible for customizing, extending, and maintaining the Solution.  In addition to the typical design aspects to consider (performance, scalability, usability), it is important to also design with code maintainability, consistency, and readability in mind.  This guide will focus more on what is specific about Solutions, and assume you are already familiar with Appian best practices around performance, scalability, and usability.

Whenever designing something, try to put yourself in the mindset of someone who has never seen this application before.  Will they be able to understand how the code is meant to function?  Will they be able to customize it to suit their needs, without having to reach back to our team for clarification?

If you've ever used other third-party libraries before (Java, Javascript, etc), think about what makes some of them extremely easy to understand and incorporate, and what makes some of them very convoluted and difficult to incorporate.

*Note: This is a living document.  Not all of the objects currently in the application follow the standards laid out here. If it is reasonable during the course of development, try to leave things better than when you found them\!*

## 1\. General SAIL Principles

### A. Use latest features and CO rules

1. **As a Solution, our applications should be showcasing and utilizing the most up-to-date Appian features and functionality**  
   * Move to the latest version of Appian as soon as possible after the product is stable  
     * Be familiar with the new features and implement them in best practices and development where applicable  
     * Communicate and enforce updates with team  
   * CO (Common Objects) rules are objects that enhance the Appian product  
     * CO rules cannot reference any other application in any way; they should be completely application-agnostic and can be thought of as objects that are a part of the product  
     * Use CO rules whenever possible for consistent functionality and UX  
     * Once a CO rule is created and deployed, changes to the rule should be limited  
       * Consider creating a new rule or duplicating the rule instead of updating an existing one if there are major changes  
       * Add new parameters to existing CO rules as Appian functions are updated  
       * Any updates will need to be backwards compatible

### B. Commenting

1. **Comment everywhere there is potentially confusing code**  
   * *Note: Not everything needs comments, good code comments itself through clear names, elegant design, and proper scoping*  
2. **Comment on separate lines above the code**  
   * *Note: This is so that developers can utilize the commenting shortcut (Ctrl+/) without issues*  
3. **Comment above any local variable whose purpose isn't obvious**  
   * *Note: If the purpose is not obvious, you probably need a better name for the local variable*  
4. **Use the phrase TOBEDONE (no spaces) in a comment to mark things that need to be handled before release, but might need a ticket, UX feedback, or some other information before being completed.**  
   * *Note: We do not use TODO because it collides with “todocument”*

### C. Code Reusability

1. **Reuse objects whenever possible**  
   * Before creating a new object or building some piece of functionality that seems like it may be repeatable, search for existing rules that already accomplish the desired behavior  
   * *e.g*. \`[AS\_CO\_UT\_saveNull](https://eng-test-solutions-global-dev.appianpreview.com/suite/design/lQBREYS5CDN2BWYN51gcYXBR5hgfXTkhQfN9WDEV5oJ2Wkc9lMImNg0tmUh95V-nwm0nkwwkMUzZiQtaJ19oBjvg7RpvBUJBtAtAcKGQ6Ip9pvUXmQ)\`, \`[AS\_CO\_UT\_updateCdtFields](https://eng-test-solutions-global-dev.appianpreview.com/suite/design/lQBREYS5CDN2BWYN51gcYXBR5hgfXTj1l7Nud2wSZNl8XmtPA-LRNAjiJDLMVoZAzoG1_X8U0v_-m78tIwLattRHiBBjgWYjhF4tpCd8FJySFEx1Vk)\`, or \`AS\_CO\_CPS\_\<fieldType\>\` for dynamic or consistent formatting  
2. **Pass parameters to reusable objects to alter behavior**  
   * Use parameters to alter the behavior of a reusable object, within reason (see [General SAIL Principles \-- Passing Parameters](#g.-passing-parameters))  
3. **Do not over-parameterize**  
   * If an object has more than \~5 parameters that alter behavior, it likely warrants creating a new object  
4. **Reduce object scope to create reusability**  
   * If an object is complex, but some parts of the object can be reused in other parts of the application, break the object into multiple objects of smaller scope from the original object (see [General SAIL Principles \-- Object Scope](#e.-object-scope))  
5. **Use local variables to avoid duplicating logic**  
   * If the same piece of logic is reused in any scope, even a small piece, it should be stored in a local variable to help with with readability and maintainability  
   * *e.g*. \`rule\!AS\_CO\_UT\_isBlank(ri\!item.id)\` could be stored in \`local\!isBlankId\` and referenced as such throughout

### D. Formatting

1. **Format your code for legibility**  
   * Use the Appian-standard formatting (Ctrl+Shift+F) to format code before saving after interface or rule  
   * This helps to minimize whitespace differences when viewing the version comparison for a rule  
2. **Include full-gap carriage returns where appropriate**  
   * This helps distinguish between types of local variables and multiple components on large interfaces  
3. **Place parameters with smaller definitions above those with larger definitions for readability when calling functions/rules**  
   * Parameters such as “contents” that tend to be much larger should always go at the bottom  
   * *e.g.* 

| a\!columnLayout(    width: "NARROW",    contents: {​long expression}) |
| :---- |

***Instead of***

| *a\!columnLayout(    contents: {​long expression}     width: "NARROW",)* |
| :---- |

### E. Object Scope

1. **Ensure the scope of every object matches its purpose, name, and description**  
   * Consider and plan for the scope of every object before creating it  
   * *e.g*. A process model called \`Create Document Folder for Record\` should just create a folder.  It shouldn't have other logic inside of it, such as executing the next step in the overall process after the folder is created.  
   * *e.g*. An interface called \`DisplayContactInformation\` should just display the information.  It shouldn't have other logic inside of it, such as allowing a user to edit the contact information.  That could be handled in a wrapper rule called \`EditOrDisplayContactInformation\`.  
2. **Ensure the inputs to an object align with its scope**  
   * If an object seems to require other inputs that do not pertain to its purpose, the scope of the object is likely off  
   * *e.g*. A process model called \`Create Document Folder for Record\` should just take inputs of the record CDT to ensure that it can be called anywhere, with only the inputs it absolutely needs  
   * *e.g*. An interface called \`DisplayContactInformation\` should just take inputs of the contact CDT, reference data, and i18n data, to ensure that it can be called anywhere, with only the inputs it absolutely needs  
3. **Ensure the output of an object aligns with its scope**  
   * If an object doesn't return an output that doesn't match its name or description, the scope of the object is likely off  
   * *e.g*. An expression rule called \`ReturnGroupName\` should just return the group name as a string  
4. **In general, break objects down into smaller scope**  
   * Ensuring smaller scope for objects will make testing, debugging, and maintaining the code base significantly easier  
   * *e.g*. If a process model is doing many things, consider how they can be grouped into sub-process to reduce scope  
   * *e.g*. If an interface that contains many components, consider how they can be grouped into separate smaller interfaces to reduce scope  
   * *e.g*. If an expression rule performs significant complex logic, consider how it can be broken down into smaller expressions to reduce scope  
5. **Saves should always be within a {}**  
   * See [this powerpoint](https://docs.google.com/presentation/d/1zL2H8cM16_7W4KO7OsnFvwyZBR361Vzk-nMPdaU7zYE/edit?pli=1#slide=id.g7c7c29f7fd_0_4) for some insight into why.  It also has some deeper explanations of how scope impacts evaluation of local variables.

### F. Variable & Parameter Naming

1. **Name a complex variable or parameter by its type**  
   * *e.g*. \`selectedTaskRef\` for a single object of type \`AS\_EX\_R\_TaskRef\`  
2. **Use a plural name for variables that are arrays**  
   * *e.g*. \`field\` for a non-array Text input, and \`fields\` for an array Text input  
3. **Use the same names for variables and rule inputs**  
   * This helps avoid issues with spelling and assists with find & replace  
   * *e.g*. \`local\!selectedTemplate\` is passed as \`selectedTemplate\` from \`AS\_EX\_FM\_viewOrManageReferenceTemplateSettings\` to all its child rules  
   * *Note: Sometimes if the context of a parent & rule is different, it makes sense to use separate names.  For example, a rule \`DisplayTemplateName\` may take in \`template\`, whereas the parent may have a variable \`selectedTemplate\` since in the context of the parent, \`selectedTemplate\` makes more sense.*  
4. **Use the same variable name for the same concept across the application**  
   * *e.g*. \`refData\` is passed around everywhere as \`refData\`, and always represents the same concept (an array of \`AS\_EX\_R\_Data\`)  
5. **Use affirmative naming**  
   * *e.g*. Use \`isExistingCategory\` instead of \`isNotNewCategory\`

### G. Passing Parameters

1. **Pass parameters with keyword-syntax**  
   * This ensures that you can add or reorder inputs to rules without worrying about breaking existing uses of the rules, as well as helps with readability  
   * *e.g*. \`rule\!AS\_CO\_UT\_sortSimpleType(array: ri\!array, ascending: true)\`  
   * *Note: There are some exceptions that people are just used to, such as when calling \`AS\_CO\_UT\_isBlank()\`*  
2. **Pass full objects into expression rules**  
   * Do not pass individual fields of objects to minimize the need to add inputs in the future  
   * *e.g*. \`AS\_EX\_VD\_fundSingleValidation\` takes in the full \`AS\_GSM\_Fund\` object even though it only needs to check a few fields to validate  
   * *Note: There are exceptions, for example when calling an expression rule from a record type object where you only have access to individual fields and not the full object*  
3. **Use a prefix for behavioral parameters**

| Prefix | Purpose | Example |
| :---- | :---- | :---- |
| is | Controls state | \`isAdding\` |
| show | Controls visibility | \`showDescription\` |
| allow | Controls access | \`allowEditing\` |

   * *Note: There are scenarios where other prefixes make sense, however these are rare*  
   * *Note: For parameters that are meant to map directly to Appian component parameters, such as \`readOnly\`, pass these with their standard Appian name*  
4. **Ensure all boolean parameters have proper default behavior**  
   * If \`null\` is passed, the object should function with default behavior  
   * *e.g*. If \`allowLinkSelection\` is \`null\`, it will not allow link selection  
5. **Do not pass contextual parameters**  
   * *e.g*. Do not pass \`isOnboardingRecord\` to differentiate form behavior between the interface in the record versus the action  
   * Instead pass these parameters as defined above, such as \`showX\`, \`allowY\`, or \`readOnly\`  
   * This ensures that objects can be reused in multiple places.  For instance, if this object now needed to be used in a third place, what would the value of \`isOnboardingRecord\` be? How would you control this third type of behavior?  
6. **Use rule input descriptions**   
   * Adding rule input descriptions to rule inputs is a best practice  
   * Rule input descriptions are especially important on objects which are complicated or which are intended to be reusable  
   * It is very important that our descriptions are accurate. An inaccurate description is 1000% more confusing than a missing one  
   * If a rule input cannot be clearly and concisely described, it may be worth reworking so that it is more easily understood  
   * Not every rule input needs a description \- if the name of the rule input is self-explanatory and easily understood (like showWhen), a description may not be necessary  
   * Rule input descriptions should not be contextual  
   * When a rule input is required it should start with “(Required)” and state what the default behavior is  
   * When there is an enumeration of options for a rule input, specify the options in the description

### H. Maintaining State

1. **When possible, use local variables of data to maintain state**  
   * *e.g*. \`AS\_EX\_FM\_viewOrManageReferenceTemplateSettings\` differences between viewing and managing templates based on whether or not \`local\!selectedTemplate\` is populated or not.  If you added a separate local variable such as \`local\!isManaging\`, then you would have to ensure both variables have the correct values at any time (if \`local\!isManaging\` is \`true\` then \`local\!selectedTemplate\` would have to be populated).  
2. **Use boolean local variables to maintain state between two options**  
   * *e.g*. \`isEditing\` can represent two states, one where the user is editing and one where they are not  
   * This paradigm works well when there are multiple mutually-exclusive states, such as \`showDetails\` and \`isEditing\`.  At any time, these two variables can be in a combined total of 4 states.  
3. **Use text or integer local variables to maintain state between three or more options that are not mutually exclusive**  
   * *e.g*. \`AS\_EX\_FM\_selectSettingsAction\` uses \`local\!selectedSubActionId\` to differentiate between what action was chosen.  At any time, only one action can be displayed, so by having one local variable, you can enforce this design.  
4. **Use the \`triggerRefresh\` paradigm to allow easily resetting state**  
   * This avoids having to think about every possible variable you need to update to return to the default state  
   * For all local variables that need to be updated on state reset, initialize these as \`a\!refreshVariable()\` with \`refreshOnVarChange: local\!triggerRefresh\`  
   * For any saves that should reset the state, execute rule \`AS\_CO\_UT\_triggerRefresh\` in the saves to perform the state reset

### I. Local Variables

1. **Ensure objects are strongly-typed when possible**  
   * *e.g*. A local variable \`local\!selectedTaskRef\` should always have a type of \`AS\_EX\_R\_TaskRef\`, even when null  
   * This ensures that dot notation will always work, and just helps with maintainability and debugging  
2. **Initialize local variables as null with their type**  
   * Use rule \`AS\_CO\_UT\_initializeBlankLocalVariable\` to do this  
3. **Initialize boolean local variables as \`true\` or \`false\`**  
   * Boolean variables should only be in a state of \`true\` or \`false\`, never \`null\`  
   * *Note: For parameters, it makes sense to allow \`null\` to execute default behavior, but where we initialize, they should be either \`true\` or \`false\`*  
4. **Do not duplicate concepts in multiple local variables**  
   * *e.g*. If you have a local variable \`selectedTasks\`, you don't also need one that is \`selectedTaskIds\`, instead just reference \`selectedTasks.taskId\` to retrieve the necessary data  
   * This means with any interaction, you will have to maintain both local variables, and you could run into scenarios where the variables don't make sense, such as \`selectedTasks\` is populated, but \`selectedTaskIds\` is empty (see [General SAIL Principles \-- Maintaining State](#h.-maintaining-state))

### J. Indexing into Objects

1. **Use dot-notation or bracket-notation to return fields or indices of CDTs and complex objects**  
   * This ensures that the application will intentionally throw an error if indexing incorrectly, which will help with maintainability and to avoid spelling errors  
   * This achieves a strong-tie between the parent object and the indexed field, which is necessary for saving and other functionality  
   * Using \`index()\` can incorrectly return a false negative, where the result is \`null\`, not because the field was \`null\`, but because the field was incorrectly defined  
   * *Note: When dealing with nested CDTs that are arrays, you may need to wrap in \`a\!flatten()\` to ensure the dot-notation doesn't break*  
2. **Use bracket notation or index function for record objects**  
   * Use bracket notation by default and use index function or \`a\!defaultValue\` to set a default value when the value is null

### I. Appian Design Guidance

By following the above principles, unaddressed design guidance should be minimal. Before pushing code to peer review, however, all design guidance should be either resolved or addressed. This ensures that customers don't receive solutions with outstanding design guidance, which could be perceived as a quality issue. To address design guidance:

1. **Navigate to the Monitor tab of your application package**  
2. **Review the Appian Design Guidance grid (located in bottom right corner of Monitor view), using the Package filter to select your package**  
3. **For any objects in the grid, make the decision to update the object to address the guidance, or dismiss the guidance**  
   1. Common reasons to dismiss guidance:  
      1. *Multiple levels of nesting* \- Can be dismissed as long as the data model is reviewed by a technical advisor  
      2. *Multiple node instances (MNI) with activity chaining* \- Can be dismissed as long as the design is performant and reviewed by a technical advisor  
      3. Design guidance is part of a common object and time doesn't allow to update the object directly via our common object dev lifecycle

## 2\. Data Types

### A. CDT Naming

Most solutions, if not all, have transitioned from using CDTs to RecordTypes. RecordTypes should always be the preference unless it is not possible. Some example scenarios where a CDT may be required include (refer to the public facing docs for a more in depth overview [CDT Guidance](https://docs.appian.com/suite/help/26.3/cdt_design_guidance.html)):

* You're working with a legacy record type that connects to a database.  
* You use a data type plug-in to define a CDT as a Java object.  
* Your process model includes an Export Data Store Entity to Excel or Export Data Store Entity to CSV smart service node. Data store entities require a CDT as part of their configuration.

1. **Append the application namespace to the end of the default namespace**  
   * *e.g*. \`urn:com:appian:types:ASFS\`  
2. **Prefix CDTs with the application namespace**  
   * *e.g*. \`AS\_EX\_\`  
3. **Prefix CDTs that are conceptually tied to multiple namespaces in descending order of specificity (In the example, QNM is shared between multiple apps, and KYC is more specific)**  
   * *e.g*. \`AS\_KYC\_QNM\`  
4. **Use a sub-prefix based on the purpose of the CDT**

| Prefix | Purpose | Example |
| :---- | :---- | :---- |
|  | Do not prefix CDTs backed by transactional tables | \`AS\_EX\_Task\` |
| R | CDTs backed by reference tables | \`AS\_EX\_R\_Locale\` |
| T | CDTs backed by tables that are copied to runtime tables | \`AS\_EX\_T\_Template\` |
| A | CDTs backed by auditing tables | \`AS\_EX\_A\_R\_Template\` *Note: The “\_A\_” prefix comes before the audited CDT’s own prefix(es). For example, \`AS\_EX\_R\_Template\` \> \`AS\_EX\_A\_R\_Template\`* |
| V | CDTs backed by views | \`AS\_EX\_V\_Account\` |
| CONF | CDTs that map to configurations for which we might ship data that fall somewhere between transactional (no prefix) and \_R\_ | \`AS\_EX\_ALT\_CONF\_AlertConfiguration\` |
| UNMAPPED | CDTs not mapped to the database | \`AS\_EX\_UNMAPPED\_DocOCR\_Rule\` |

5. **Name the CDT with a singular name**  
   * *e.g*. \`AS\_EX\_Request\` instead of \`AS\_EX\_Requests\`  
6. **For views, use the same singular name as the primary table**  
   * *Note: If the view does complex data aggregation, use a more descriptive name instead*  
   * *e.g*. \`AS\_EX\_V\_Account\` where the primary table is \`AS\_EX\_Account\`  
7. **For child CDTs specific to a parent CDT, append the name of the child CDT to the parent CDT**  
   * *e.g*. Parent \`AS\_EX\_Task\` has a child \`AS\_EX\_Task\_Precedent\`

### B. Field Naming

1. **For primary keys, use the format \`\<cdtName\>Id\`**  
   * *e.g*. \`taskId\` is the primary key for \`AS\_EX\_Task\`  
   * *Note: Ensure all primary key field names are unique throughout the environment, except for primary keys for views based on tables, since this field represents the same concept as the primary key of the table*  
2. **For foreign keys, use the exact same name as the primary key of the related CDT**  
   * *e.g*. \`taskId\`  
3. **For auditing fields, use the format \`\<action\>By\` to represent a user, and \`\<action\>Datetime\` to represent the timestamp**  
   * *e.g*. \`createdBy\` and \`createdDatetime\`  
4. **For non-auditing primitive fields, suffix the field when applicable**  
   * \`Id\` for integer identifiers, e.g. \`ruleId\`  
   * \`Code\` for varchar identifiers, e.g. \`taskStatusCode\`  
   * \`Name\` for names, e.g. \`taskName\`  
   * \`Desc\` for descriptions, e.g. \`taskDesc\`  
5. **For boolean fields, prefix with \`is\`**  
   * *e.g*. \`isInternational\`  
6. **For the remaining primitive fields, be descriptive**  
   * *Note: Try to ensure CDT field names are unique across the environment, within reason*  
   * *e.g*. \`groupAssignee\` or \`customerTypeCode\`  
7. **For nested non-array CDTs, use the name of the nested CDT, camelcase, without prefixes**  
   * *e.g*. \`taskPrecedent\` which is of type \`AS\_EX\_Task\_Precedent\`  
8. **For nested array CDTs, use the plural name of the nested CDT, camelcase, without prefixes**  
   * *e.g*. \`taskPrecedents\` which is of type \`AS\_EX\_Task\_Precedent\`  
9. **For fields of CDTs mapped to views, use the exact same field name as the CDT for the table**  
   * This ensures the same name represents the same concept across the CDTs  
   * *e.g*. \`taskStatusCode\` is the same field on both the table CDT and the view CDT

### C. Nesting CDTs

*Note: The instructions for nesting CDTs apply to most scenarios, however there are exceptions that are dependent on specific use cases and necessary functionality.  Always review a nesting CDT design with a senior team member.*

1. **When the child is only used within the context of the parent, nest with \`Cascade=ALL\`**  
   * *e.g*. How \`AS\_EX\_Task\_DocUploadContext\` is nested inside of \`AS\_EX\_Task\`  
   * *Note: Do not nest with more than 2 levels of One-to-Many (where the child CDT field is an array in the parent CDT)*  
2. **For reference data fields, nest with \`Cascade=REFRESH\`, setting the child type to the reference type**  
   * *e.g*. How \`AS\_EX\_R\_TaskCategory\` is nested inside of \`AS\_EX\_Task\`  
   * *Note: This does not apply when storing codes instead of primary keys due to the internationalization structure (such as \`taskStatusCode\` in \`AS\_EX\_Task\`)*  
3. **To query a child by its parent, nest the parent inside of the child with \`Cascade=REFRESH\`**  
   * *e.g*. How \`AS\_EX\_OnboardingRequest\` is nested inside of \`AS\_EX\_Task\`  
   * *Note: This only applies when the child CDT is not already nested inside the parent CDT, otherwise a circular relationship is created in the CDTs*

### D. Views

1. **Use CDT nesting whenever possible rather than creating a view**  
   * *Note: Nearly all use cases for views can be accomplished with nesting CDTs*  
2. **Use query aggregation whenever possible rather than creating a view**  
   * *Note: Nearly all use cases for aggregated views can be accomplished with query aggregation*  
3. **Do not apply application logic to the underlying SQL for a view**  
   * Do not cast datetimes to dates in a view, do this in SAIL instead  
   * Do not concatenate fields in a view, do this in SAIL instead  
   * Do not apply any \`WHERE\` conditions to a view, use query filters in the application instead  
   * Do not use codes or identifiers in \`JOIN\` conditions or the \`SELECT\` statements, execute this logic in SAIL instead

### E. Mapping to Database

1. **Set custom table and column names in the database**  
   * To do this, modify CDTs in the XSD, rather than the CDT editing interface  
   * *Note: Whenever possible, use the OOTB option to automatically create or update tables when saving & publishing a data store instead of creating the tables using SQL.  Appian will automatically generate foreign key relationships and indexes for any nested CDTs.*  
2. **Use uppercase naming for the table name, and ensure it matches the CDT name**  
   * *e.g*. \`AS\_EX\_TASK\`  
   * *Note: Ensure table names do not exceed 30 characters so that it works for any supported database; abbreviate to a max of 30 characters if necessary*  
3. **Use uppercase naming for the column name, and ensure it matches the CDT field name**  
   * *e.g*. \`TASK\_STATUS\_CODE\`  
   * *Note: Ensure column names do not exceed 30 characters so that it works for any supported database; abbreviate to a max of 30 characters if necessary*  
4. **Do not set a \`length\` parameter on \`VARCHAR\` fields**  
   * Instead let the database create with its default of 255  
   * *Note: Length validations on all fields will be handled in SAIL*

## 3\. Record Types 	

### A. Setup \- naming/plural name

1. **Create a record for every CDT against which actions will be taken**  
   * \`AS\_EX\_Customer\`  
   * \`AS\_EX\_RequiredOnboardingDocument\`  
2. **Name after the cdt with “\_RecordType” appended**  
   * AS\_\<prefix\>\_\<PascalCaseRecordName\>\_RecordType  
   * \`AS\_EX\_Customer\` ⇒ \`AS\_EX\_Customer\_RecordType\`  
   * \`AS\_EX\_RequiredOnboardingDocument\` ⇒  \`AS\_EX\_RequiredOnboardingDocument\_RecordType\`  
   * *Note: You may notice that some older records say \_RecordType and some say \_SyncedRecordType. This is an artifact from when synced records were new, as we move towards using synced records everywhere we can move towards just using \_RecordType*  
3. **If only record type exists without CDT then use**   
   * AS\_\<prefix\>\_\<PascalCaseRecordName\>  
4. **Use synced records whenever possible**  
5. **If possible, limit one record per database table or per concept**  
   * If multiple records must be made, ensure to name and describe them deliberately to avoid confusion between the two.

### B. Data Model/Relationships

* **When creating the table for a database-backed record, make sure to add a “UNIQUE” constraint in the database for columns containing keys for 1:1 relationships.**   
  * Required in order to be able to create 1:1 relationships between records.  
* **Setting up the record based on an existing table is pretty straightforward. Unlike CDTs, you can edit record field names and relationships after they are referenced without issue.**  
  * Each field and relationship has its own UUID. If there is a parallel field in the cdt, make sure to name the field the same as the nested cdt field to ensure that casting between the record and CDT works.  
* **Set up any custom fields. Custom fields can (and should) replace views in most scenarios.**  
* **Make sure to set User and Group fields appropriately**  
  * This helps with security and handling casting.  
  * *Note: the record will not break if a user or group is invalid (such as when showing a “System” user).*  
* **Set up relationships between all related records**  
  * Always edit the suggested relationship name to something concise and accurate  
  * If there is a parallel relationship in the cdt, make sure to *name the relationship the same as the nested cdt field*  
    * If the relationship name does not match the name of the field which holds the nested cdt, casting between the record and cdt will not work on that data.  
  * There is essentially no downside to adding relationships \- they often help with complex query filters and are not returned by queries unless explicitly specified. Whenever adding relationships in the database, add them to the relevant synced records

### C. Security

* **Security**  
  * Appian Administrators group set as Administrator  
    * *e.g*. \`AS FS Appian Administrators  
  * Business Users Group and Security Groups Group set as Viewer  
    * *e.g*. \`AS EX Business Users\` and \`AS EX Security Groups\`  
    * Remember that users in the record’s viewer group can have their access further restricted by record-level security  
* **Record-level Security**  
  * You can now easily configure row-level security for a record based on simple rules to dictate who can see all rows, who can see rows based on record fields, and who can see rows based on related record fields  
  * *Note: Default filters (even those not related to groups or security) are still possible in synced modern records via the “Configure a security expression”*

### D. User Filters

* **If it’s possible to create the user filter using the guided configuration, then do so.**

### E. Record List Actions and Related Actions

Record actions have gotten easier and more performant with the introduction of synced records. There are several steps to configuring a record action

1. **Decide whether the action is a *Record List* action or a *Related* action.**   
   1. Record list actions occur agnostic of an identifier, such as a “Create Record” action, while related actions require an identifier, such as “Edit Record” or “Delete Record” actions. It is vital to not configure record list actions as related actions with a hardcoded id because as soon as the action exists in an environment without that id, it will not show or even show a pink error.   
   2. *Note: Configuring an action to create a child record on a parent record will typically be a related action on the parent record rather than a record list action on the child.*  
2. **Define the action name and key**  
3. **Define the process model and context. Note that due to record discoverability, we should avoid passing in rv\!record directly to the process.**  
4. **Define visibility**  
   1. Synced records make this much easier since we can often use record relationships rather than queries to get related record data. It is important to optimize for performance in action visibility, as this will be evaluated on page load everywhere the record action is referenced.

### F. Query Rule

1. **Synced record queries are faster than entity queries at scale. They also have the benefit (and sometimes, curse) of discovery, which allows them to only query the data points that are needed.**  
2. **Recommendation is to maintain parity for field/relationship names between CDTs and records**  
   * Querying as a record and casting to CDT is an antipattern that should be avoided. **If for some reason we must get data as a cdt due to product limitations or to minimize changes to existing code, queryEntity should be used instead of queryRecord. We recommend this for several reasons:**  
   * a query record \+ cast takes longer than the query entity  
   * Discovery could result in the query \+ cast not returning the expected information  
   * Lack of parity between the cdt and record could result in lost information  
3. **The default record query behavior is to return only the primary key field of the specified record type unless the fields parameter is populated.**  
   * No related records, even if they are referenced, will be returned. You will need to specify which related records you want returned in the record query. Additionally, when querying related records with a 1:M relationship, *the default number of record returned is 10 however you can increase it up to 100 when using a\!relatedRecordData() in a\!queryRecordType()*

In general, build record queries like [entity queries](#e.-queries). Instead of specifying the entity and entityType in a queryEntity, you only need to specify the recordType in a queryRecord. Additionally, rather than *excludeNestedCdts*, you will need to specify the related records directly. 

### G. Generic expression backed record

Typically used when trying to obtain data from an external source \- [Record Type Tutorial (Web Service)](https://docs.appian.com/suite/help/26.3/Service-Backed_Record_Tutorial.html).  
However can also be used as a workaround for making actions that do not need any specific record context. 

For example record related actions can only accept a single value as their identifier. However, externalize() allows us to convert a list of values or a list of fields into a single string which can serve as an identifier and be converted back into its original form via internalize(). The following steps outline how to achieve this.

1. **Create an unmapped CDT with two fields**  
   * recordId(Text)  
   * contextMap(Any Type)  
2. **Create an expression rule to initialize the above CDT**  
3. **For contextMap use internalize/externalize**  
4. **Create a Record of type Web Service**  
5. **Use the above CDT as Data Type and expression rule for the Record Data Source and Single Record Data Source with its rule input as the Record Identifier**  
6. **Add any bulk/contextual related actions to this record.**   
   * When passing data to the record action fields like context and security, remember that the context and/or ids of the items we care about are stored in the context field.  
7. **In an interface, create a record action item that uses externalize to convert a cdt or list of primary keys into a single text value.** 

## 4\. Constants

### A. Naming

1. **Prefix constants with the application namespace**  
   * *e.g*. \`AS\_EX\_\`  
2. **Use a sub-prefix based on the type of the constant**

| Prefix | Type | Example |
| :---- | :---- | :---- |
| BOL | Boolean | \`AS\_EX\_BOL\_TOGGLE\_AUTOMATION\_TESTING\_ENABLED\` |
| CS | Connected System | \`AS\_EX\_CS\_GOOGLE\_CLOUD\` |
| DEC | Decimal | \`AS\_EX\_DEC\_APPLICATION\_VERSION\` |
| DOC | Document | \`AS\_EX\_DOC\_SYSTEM\_PROFILE\_PICTURE\` |
| ENT | Data Store Entity | \`AS\_EX\_ENT\_TASK\` |
| ENUM | Designer defined enumeration | \`AS\_EX\_ENUM\_HEADER\_LEVEL\_ONE\` |
| FLD | Folder | \`AS\_EX\_RC\_FLD\_INTERNATIONALIZATION\_FILES\` |
| GRP | Group | \`AS\_EX\_GRP\_AD\_HOC\_CREATORS\` |
| INT | Integer | \`AS\_EX\_INT\_BATCH\_SIZE\_LARGE\` |
| PM | Process Model | \`AS\_EX\_PM\_CREATE\_ONBOARDING\_REQUEST\` |
| RP | Report | \`AS\_EX\_RP\_LANDING\_PAGE\` |
| RT | Record Type | \`AS\_EX\_RT\_ONBOARDING\_REQUEST\` |
| REF\_TYPE | R\_DATA type | \`AS\_EX\_REF\_TYPE\_ASK\_STATUS\` |
| REF\_CODE | R\_DATA code | \`AS\_EX\_REF\_CODE\_ASK\_STATUS\_QUEUED\` |
| TM | Time | \`AS\_EX\_TM\_RECURRING\_SYNC\_TIME\` |
| TXT | Text | \`AS\_EX\_TXT\_COUNTRY\_CODE\_US\` |

3. **For data store entities, additionally sub-prefix with the CDT prefix**  
   * *e.g*. \`AS\_EX\_ENT\_R\_TASK\_CATEGORY\`

### B. Appropriate Use

1. **Use constants when there is a need to trace it via dependency checker**  
   * *e.g*. Places where you reference a specific task behavior type  
2. **Use constants for consistency between two or more places**  
   * *e.g*. Standard default locale code  
3. **Use constants for potentially configurable functionality**  
   * *e.g*. Batch sizes on grids  
4. **Use constants for reference types**  
   * *e.g*. \`AS\_EX\_REF\_TYPE\_REGION\`  
   * This is to ensure that you can easily identify everywhere in the application you reference that reference data, as you can dependency check by the constant  
5. **Use constants for reference codes, creating a constant per code**  
   * *e.g*. There is a constant per task behavior type, each beginning as \`AS\_EX\_VAL\_TASK\_BEHAVIOR\_TYPE\_CODE\_\` followed by their specific name  
   * Use a constant list expression rule to build a list of all possible codes for a type (see [Expression Rules \-- Constant Lists](https://docs.google.com/document/d/1jYvBOXsBa56NGrTX30wJdx2ecfpFU2LRC-TN4fmhYkg/edit#heading=h.64cwhhalpn93))  
   * This is to ensure that modifying individual codes requires as little maintenance as possible, as you can dependency check by the individual constant  
6. **Use constants for preset database IDs**  
   * *e.g*. \`AS\_EX\_VAL\_PROCESS\_SETUP\_TASK\_REF\_ID\`  
   * This is to ensure that you can easily identify everywhere in the application you reference that object, as you can dependency check by the constant  
7. **Do not use constants for text that should be internationalized**  
8. **Do not create constants that are arrays**  
   * Instead, use an expression rule to wrap a list of constants (see [Expression Rules \-- Constant Lists](https://docs.google.com/document/d/1jYvBOXsBa56NGrTX30wJdx2ecfpFU2LRC-TN4fmhYkg/edit#heading=h.64cwhhalpn93))  
   * This is ensure that you can easily dependency check by an individual value, not only by the entire list, and to ensure that you don't rely on the order of the list in the constant  
   * *Note: There are exceptions to this rule, however, they are rare*

## 5\. Expression Rules

### A. General

1. **Avoid rule inputs that change the behavior of a rule.**   
   1. For example, we have a rule called \`AS\_EX\_UT\_compare\`.  This rule returns true if two objects are “equal”.  At one point, this rule had a parameter called \`verifyTypeMatch\`.  If true, the rule would include a type check in the comparison.  This is a fundamental change to the way the rule operates, so instead we made a new rule called \`AS\_EX\_UT\_compareStrong\` that handles this type of comparison.  
2. **Create a copy of utility rules for your own application.**   
   1. Do not use them directly in your application. Assign your application prefix to the duplicated utility rule.   
   2. Eg if your application namespace is AS\_EX, then the utility rule will be named AS\_EX\_CO\_UT\_checkIfSingleType

### B. Naming

1. **Prefix expression rules with the application namespace**  
   * *e.g*. \`AS\_EX\_\`  
2. **Use a sub-prefix based on the purpose of the expression rule**

| Prefix | Purpose | Example |
| :---- | :---- | :---- |
| BL | Business Logic *Note: This is a rule that executes logic that is likely customer-specific, and can easily be identified as a place to tweak application behavior* | \`AS\_EX\_BL\_newOnboardingVisibility\` |
| CDT | CDT Constructors | \`AS\_EX\_CDT\_createAuditCdts\` |
| REC | Record Constructors | \`AS\_EX\_REC\_createAuditCdts\` |
| CONS | List of constants | \`AS\_EX\_CONS\_TASK\_CONFIGURATION\_LEVEL\_CODES\` |
| QE | Query Entity | \`AS\_EX\_QE\_getCustomer\` |
| QR | Query Record | \`AS\_EX\_QR\_getOwners\` |
| QPA | Query Process Analytics | \`AS\_EX\_QPA\_getActiveOnboardingProcesses\` |
| REF | Contain an immutable list of ref data.  Should only be used when the ref data can not be edited from the front end (e.g. business users might want to be able to define their own list of countries for dropdowns, but cannot define new statuses, as these drive logic) | \`AS\_EX\_REF\_InvestigationStatuses\` |
| UI | UI components that throw an error as a standalone interface | \`AS\_EX\_UI\_displayIconForCategoryCompletion\` |
| UT | Utility Rules | \`AS\_EX\_UT\_displayRefData\` |
| VD | Validations | \`AS\_EX\_VD\_validateFunds\` |
| ENUM | List of Constants (stores a grouping of related data ie. actions, status, data types) | \`AS\_EX\_ENUM\_STATUS\_CODE\` |

3. **Be as descriptive as possible when naming expression rules**  
   * It should be clear to any developer what the intended purpose and function of an expression rule is without having to dig into the code

### C. Return

1. **Recommended: Wrap expression rules in cast() to ensure that each expression rule has a consistent return type, regardless of the inputs**  
   * *e.g*. \`AS\_EX\_UT\_displayRefData\` always returns type Text, regardless of whether the input reference code is found  
   * This is consistent with how Appian functions work; every function outlines its specific return type in the documentation  
   * *Note: There are exceptions.  For example, a rule to filter a list of CDTs would return the same type as the input list.*

### D. Test Cases

1. **Every Expression Rule should have proper test case coverage**  
   * Test cases should cover each possible functional outcome from execution  
   * Include a test case with all null inputs to ensure rules include proper null handling  
   * Include a test case with expected data output type  
   * *e.g*. \`Test\_UT\_isDuplicateTaskCategoryName\` contains test cases for A) name is duplicate, B) name is not duplicate, and C) name is null  
2. **All test cases should use the assertion types ‘Assertion evaluates to true’ or ‘Test Output matches asserted output’**  
   * Exceptions  
     * Except for the following cases  
       * For Rules containing DB Query Rules  
       * For Rules containing interface SaveInto components  
       * For Rules containing interface components  
     * For these cases  
       * Name the test case: ‘Not Null Case (No Assertions)’ or “Case with No Assertions”  
       * Assertion type: Test Case Completes without Error  
       * Comment: add comment to top of expression rule /\*This rule cannot have assertion\*/  
       * If any of these error-out do not add a test case as the failed test case will show up during the deployment. Try to convert this expression rule into an interface so that we don't have to deal with a test case in this situation.  
3. **Do not use hard-coded internationalization labels in the assertion of a test case**  
   * *Note: This will break if labels are ever changed, even if the functionality of the rule is still valid*  
4. **Try to avoid relying on environmentally-specific data in test cases**  
   * Do not hard code user or test information  
     * Use EES (Exact Expression Search) to help catch this  
       * This is already present in the CI pipeline (for GAM)  
   * Construct a complex type in the expression rather than querying from the database by an ID, since other environments may not have an object with that ID  
     * 1\) run the QE in a blank expression rule  
     * 2\) press Test Rule  
     * 3\) change the output option to Expression  
     * 4\) remove any environment-specific or user-specific values  
     * 5\) paste into the rule input test case value  
     * *Note: For reference CDTs that come pre-populated in the database, it is acceptable to use an unfiltered QE rule and grab the first result.*  
5. **Do not call rules from other applications in test cases**  
6. **Reference this [playbook play](https://community.appian.com/w/the-appian-playbook/1563/creating-expression-rule-test-cases) if needed for more information on creating test cases**  
7. **In order to run a check on any rules with missing or failed test cases, navigate to the "Monitor" tab within an application and within the "Rule Test Health" box above the design guidance grid, run the "Run All Rules" action.**

### E. Queries

The instructions for querying in expression rules apply to most scenarios, however there are exceptions that are dependent on specific use cases and necessary functionality.

1. **Use the existing query rules in your environment (eg. AS\_CO\_UT\_queryEntity() and AS\_CO\_UT\_queryRecord()) do NOT use Query Rules**  
   * Pass in entity and entity type, but allow return type to be passed in on the interface level (create rule input returnType of type text)  
* This allows the designer to determine what return type they need in a given interface on a case-by-case basis and eliminates the need to dot into data or cast  
* Return types include data subset, single object, array object, aggregation, and total count and are enumerated in the rule AS\_CO\_CONS\_QE\_RETURN\_TYPES  
  * The rule handles paging info based on return type  
  * Additional documentation for how to use the rule is commented in the rule  
2. **Name query entity based expression rules in the format of \`QE\_get\<Object\>\` or \`QR\_get\<Object\>\`**  
   * *e.g*. \`AS\_EX\_QE\_getCustomer\` or \`AS\_EX\_QR\_getCustomer\`  
3. **For each data store entity, use a single expression rule with optional input filters to query the data store entity**  
   * *e.g*. \`AS\_EX\_QE\_getOnboardingRequest\` is used everywhere to query the entity \`AS\_EX\_ENT\_ONBOARDING\_REQUEST\`, with optional filters  
   * *Note: If you need to query an existing data store entity by a filter that doesn't exist, update the existing rule to pass in the new filter, ensuring it will behave as it currently does when null*  
   * *Note: If very complex logical expressions or aggregation are needed for specific functionality, it's generally better to create a new query expression rule specifically for this usage, such as \`AS\_EX\_QE\_getUniqueCategoriesForRequest\`*  
4. **Pass in filters and logical expression into AS\_CO\_UT\_queryEntity(), which sets \`ignoreFiltersWithEmptyValues\` to \`true\` to ensure passing null filters implies the filter will not be applied**  
5. **Apply a default filter on isActive or isDeleted like so:**

| a\!queryFilter(   field: "isActive",   operator: "in",   value: rule\!AS\_CO\_UT\_replaceNull(            ri\!isActive,  ← Boolean array input            {true}          )  ) |
| :---- |

F. Constant Lists

1. **Used to create logical groupings of constants.**  
   * *E.g*.  
     * All ref\_code constants for a ref\_type  
     * A list of constants that all have the same defined behavior/condition in a certain situation, like “ACTIVE\_STATUSES” or “CLOSED\_STATUSES”

### G. Other Common Rule Types

1. **AS\_CO\_UT\_check\<criteria\>**  
   * Returns a boolean based upon the parameters and the given criteria  
2. **AS\_CO\_UT\_filterCdtBt\<criteria\>**  
   * Return a subset of the passed list that matches the given criteria.  
3. **AS\_CO\_CONS\_\<constantListName\>**  
   * Expression rules are used to store any list of constants.  This allows for collections of constants while maintaining a single source of truth for constant values.

## 6\. Interfaces

### A. Naming

1. **Prefix interfaces with the application namespace**  
   * *e.g*. \`AS\_EX\_\`  
2. **Use a sub-prefix based on the purpose of the interface**  
   * Prefixes are based on the [palette components](https://docs.appian.com/suite/help/latest/working_in_design_mode.html#using-the-palette) in the interface designer

| Prefix | Purpose | Example |
| :---- | :---- | :---- |
| CPS | An interface with various components | \`AS\_CO\_CPS\_dynamicFourColumnDisplay\` |
| FM | A form layout *Note: Do not use forms; where headers are required, use AS\_IO\_DSP\_displayHeader* | \`AS\_CO\_FM\_GenericDeletionConfirmationScreen\` |
| SCT | A section layout | \`AS\_EX\_SCT\_sectionLayout\` |
| COL | A single column layout *Note: An array of columns as its own interface does not render in the design view, so do not use this paradigm* | \`AS\_EX\_COL\_taskTypeColumns\`  |
| SBS | A side-by-side layout | \`AS\_CO\_SBS\_StampHeader\` |
| CRD | A card layout | \`AS\_CO\_CRD\_cardsAsSideNavigation\` |
| BOX | A box layout | \`AS\_EX\_BOX\_outstandingTasks\` |
| BLB | A billboard layout | \`AS\_EX\_BLB\_landingPageHeader\` |
| INP | Any standalone user input field | \`AS\_CO\_INP\_dateField\` |
| DSP | Any standalone display field that is not exclusively links | \`AS\_CO\_DSP\_removeIcon\` |
| BTN | An array of buttons or button layout | \`AS\_CO\_BTN\_toolbarButton\` |
| LNK | An array of links or a link display field | \`AS\_CO\_LNK\_selectableListLinks\` |
| GRD | A single grid | \`AS\_EX\_GRD\_taskCategoriesGrid\` |
| CHT | Any standalone chart | \`AS\_EX\_CHT\_inProgressOnboardingsAggregatedChart\` |
| PCK | Any standalone picker field | \`AS\_EX\_CP\_pickerFieldGroups\` |
| BRS  | Any standalone browser field | \`AS\_EX\_BRS\_taskBrowser\` |
| TAG | Tag field | \`AS\_CO\_TAG\_atRiskTagItem\` |
| HCL | Header content layout | \`AS\_EX\_HCL\_customerProfile\` |

3. **Whenever using nested interfaces or rules, use a common descriptive prefix to help easily identify the object relationships.**  
   * An interface that allows users to manage tasks with filters and a grid might be called \`AS\_EX\_SCT\_ManageTasks\`, which in turn could call \`AS\_EX\_CPS\_ManageTasksFilters\` and \`AS\_EX\_GRD\_ManageTasksGrid\`, which in turn could call \`AS\_EX\_UI\_ManageTasksGridRow\` (this last object being a UI type expression rule).

### B. Default Inputs

1. **Every interface should have default inputs saved so that its behavior can be seen and tested at a glance**  
2. **Try to avoid relying on environmentally-specific data**  
   * *e.g*. Construct a complex type in the expression rather than querying from the database by an ID, since other environments may not have an object with that ID  
   * Load in all bundles and ref data in test inputs so that labels and ref data will display correctly even if there are bundle or ref data changes  
   * *Note: For reference CDTs that come pre-populated in the database, it is acceptable to use an unfiltered QE rule and grab the first result.*

### C. Logic

1. **Forms should contain as little logic as possible to keep them clean and readable for developers.**  
2. **If there is logic much beyond boolean switches, compartmentalize it in a rule, even if it is unlikely to be reused.**

## 7\. Process Models

### A. General

1. **Because we want solutions to plug into each other easily and repeatable, it is important to consider whether or not any action should be able to be triggered by a web API call from another solution.**    
   1. If this is a possibility, then the action should be completed using a process model with a start form that gathers the required information before launching the process.  
2. **All processes should be configured with start forms, but sometimes it will be necessary to activity chain into the initial form.**   
   1. In this case, create a wrapper process with the start form as a normal user input task.

### B. Naming

1. **Process Naming**  
   * Processes should be named like AS \<solution acronym\> \<descriptive name\> \<SF, if there is a start form\>  
   * Name subprocesses node after their process names  
     * AS EX Create Customer Folders is called as a subprocess in AS EX Create or Update Customer, so the label of the subprocess node should be named “Create Customer Folders”  
2. **Process Instance Naming**  
   * Instances should be named using \`rule\!AS\_CO\_UT\_processDisplayName()\`

### C. Security

1. **Process security is CRITICAL.  It controls who can perform what related actions and is how we restrict access to entry points into other processes, data, and functionality.**  
2. **Entry Points/Actions**  
   * These are processes that are accessible on the front end through related actions, record actions, etc. Security on these processes is most important.  
   * Each entry point process model should have its own security group that controls access to that process.  
     * Viewers: \<Specific PM\> Access group \-- e.g. \`AS AM Create Award PM Access’\`  
     * Within the above process model group, all functional/business groups who have access should be added as direct members.   
       1. E.g. Contracting Manager, Requestor are direct members of AS AM Create Award PM Access  
     * The process security will transfer into the related action visibility. This gives customers flexibility to change access, and it will only be maintained in one place.  
     * A visibility rule is only needed in the record’s related action if more conditions need to be met other than group access.  
       1. Example: ‘Create Award’ process only allows a contracting manager to access it. A group ‘AS AM Create Award PM Access’ needs to be created with business groups as direct members. Then, set ‘AS AM Create Award PM Access’ as viewers for that process’ security. Set the Create Award related action visibility as ‘true’ in the record.  
       2. Example: GCM Clause Set record \- Add Clause action visibility rule checks that the status of the clause set is not "Finalized". This is in addition to the process model security rolemap, so an expression rule for visibility was created.  
     * ***Note:** Group membership removals are [not deployable](https://docs.appian.com/suite/help/22.2/Application_Deployment_Guidelines.html#groups). If your PM security group needs to be updated to remove a functional/business group, these steps should be followed:*  
       1. Update the PM security group to remove the functional group as desired  
       2. Create a new process model to update the PM security group to remove the functional group. This will ensure that the group is successfully removed automatically in the deployment environment.   
          1. E.g. AS GCW One Time Group Removal for 6-23 GA  
3. **Backend processes**  
   * Security for backend processes (non-entry points) should be more flexible so that updates to entry point security do not need to be reflected on all nested subprocesses  
     * Viewers: All Security Groups Group \-- e.g. \`AS EX Security Groups\`  
4. **Lane assignment**  
   * The PM should be assigned to the process initiator for appropriate security settings to apply  
   * This also avoids any issues with deactivated users

### D. Alerts

1. **All alerts should go to a process alerts group for the application**  
   * *e.g*. \`AS EX Designer Alerts Group\`

### E. Archiving and Deleting

1. **Major processes with user interaction should archive after 3 days**  
2. **Utility or backend processes should delete after 1 day**

### F. User Input Tasks

1. **Because we use our own tasks system, all tasks should be quick tasks unless explicitly stated**  
2. **Remember to set an exception timeout that leads to a normal (non-terminate) end node on quick tasks to prevent permanent processes from lingering**

### G. Document Upload

1. **Documents that are uploaded to a form should be deleted if the form is submitted with a “cancel” action.**  
   * This does not apply to forms that timeout  
2. **To track what documents need to be deleted, pass allUploadedDocuments to the CO file upload component**

### H. Annotations

1. **Use node notes and descriptions for clarity.**  
2. **Make the process flow self-explanatory wherever possible**.

## 8\. Security

1. **User and Group Management**  
   * Use Groups for Access Control: Never assign permissions to individual users directly. Use Appian Groups for easier role-based access control.  
   * Organize Groups Hierarchically: Create a clear group hierarchy (e.g., "CMGT Case Managers", "CMGT All Users") to manage access more easily.  
   * Deactivate Unused Users Promptly: Regularly audit and deactivate accounts that are no longer in use.  
2.  **Object Security**  
   * Use Group-Based Object Security: Assign security at the object level (e.g., interfaces, processes, records) using groups.  
3. **Record-Level Security**  
   * Implement Record-Level Security: Use security rules or user filters to control who can see which records.  
   * Avoid Hardcoding Conditions: Use dynamic expressions referencing logged-in users or groups.

## 9\. Reference Data

### A. General

1. **Most data that is not user editable will be stored as reference data**  
2. **\`AS\_FS\_R\_DATA\` is a shared table for all reference data that is pertinent to multiple applications within FS solutions \-- other solutions with multiple applications should have a similar shared table**  
   * Each individual solution will have an additional application-specific reference table  
     * EX has \`AS\_EX\_R\_DATA\`  
     * KYC has \`AS\_KYC\_R\_DATA\`  
   * These application specific reference tables should match the structure of the shared reference data table exactly \-- changes to one should be reflected on the other

### B. Naming Codes/Types

1. **Reference data \`code\` must be unique within a table (per locale) and should be unique across tables to avoid confusion**  
2. **Reference data \`type\` must be unique across tables (per locale)**  
   * If you have a \`type\` in an app specific reference table that is also in the master table, it probably belongs only in the master table \-- we should not be duplicated types  
   * Reference data query rules based upon \`type\` are set up to query against ALL relevant reference tables so that the developer does not have to determine which table  
3. **Reference types and codes should be explicit and readable (they may not be right now, as we have not always done this)**  
   * *e.g*. \`type \= “onboardingDocumentStatuses”\` and \`code \= “docStatus\_accepted”\`

### C. Management

1. **Data Stores (This is applicable only if you are application is still using CDT)**  
   * Each application will have an application-specific reference data store  
     * EX has \`AS EX Ref Data Store\` containing \`AS\_EX\_R\_DATA\` and other EX-specific reference tables such as  \`AS\_EX\_R\_TaskRef\` and  \`AS\_EX\_R\_Template\`  
     * KYC has \`AS KYC Ref Data Store\` containing \`AS\_KYC\_R\_DATA\`   
   * Each application will also have a shared reference data store  
     * These are named  \`AS \<AppPrefix\> FS Shared Ref Data Store\`   
     * They contain the application-specific entities that point to the shared reference tables  
       * The entities are prefixed AS\_\<AppPrefix\>\_FS\_R \` to identify that they point to shared tables  
       * The tables they point to are prefixed \`AS\_FS\_R\` in the database  
2. **Querying**  
   * Create two internal queries: one for the shared reference table and one for the application-specific reference table  
     * \`AS\_EX\_QR\_getRData\` retrieves data from the \`AS\_EX\_R\_DATA\` table  
     * \`AS\_FS\_QR\_getRData\` retrieves data from the \`AS\_FS\_R\_DATA\` table  
     * Have these return the application-specific R\_Data type (\`AS\_EX\_R\_Data\`)  
   * Create a query calling the above queries to load in both types of reference data to use throughout the application  
     * i.e. \`AS\_KYC\_QR\_getRefDataByType\` and  \`AS\_EX\_QR\_getRefDataByType\`  
3. **Load all necessary reference data at the top level rule to avoid querying multiple times.**  
   * Pass using parameter \`ri\!refData\` (a multiple of \`AS\_EX\_R\_Data\` or \`AS\_KYC\_R\_Data\` type)  
4. **Use common query record rule for creating query record rule for individual record**  
   * i.e. \`AS\_CO\_UT\_queryRecord\` 

## 10\. Internationalization

### A. General

1. **There are two approaches to supporting internationalization for a solution, using bundle files is the first, and using the OOTB translation sets**  
   * Most solutions have moved away from using bundle files and leverage the OOTB translation sets provided by the platform  
2. **Ensure all display text in the application is internationalized**  
   * This refers to text that is typically hard-coded in SAIL, e.g. labels, validations, captions, placeholders, etc.  
   * *Note: Data that users enter will not be internationalized, e.g. task names*  
   * *Note: Internationalized data is stored in bundle files, which can be edited in the [BND application](https://eng-test-fed-aq-dev2.appiancloud.com/suite/sites/bnd/page/bundles)*  
3. **Load bundle data in the top-level parent interface and pass it down to lower rules**  
   * Name this local variable as \`i18nData\`  
   * Use rule \`AS\_\<APP\>\_UT\_loadBundleByNames\` to load the application-specific internationalization data  
   * *Note: In some places, such as record type fields like related action names, it is not possible to load all data and pass it around.  In this case, use rule \`AS\_I18N\_UT\_getAndDisplayLabelSingle\` to load and display a single label*  
4. **Display bundle data using rule \`AS\_\<app\>\_I18N\_UT\_displayLabel\`**  
   * Pass arguments when you need a dynamic label  
   * Arguments should be formatted in the bundle files as \`\[%\<argument\#\>\]\`  
5. **Editing New Bundle Folders**  
   * To edit a bundle file in a new bundle folder (e.g. after creating a new application) in the dev tools page, add a row in the table z\_DT\_BundleFolder corresponding to the i18n folder ID.  It will then appear in the properties page.

### B. Naming

1. **Name bundle files with Pascal case in the format of \`\<FunctionalArea\>\`**  
   * *e.g*. \`CustomerRecord\`  
2. **Prefix label keys based on the purpose of the display text**

| Prefix | Purpose | Example |
| :---- | :---- | :---- |
| acs | Accessibility text/Alt Text | \`acs\_PressSpaceToSelect\` |
| btn | Button label | \`btn\_Cancel\` |
| cpt | Captions | \`cpt\_RemoveCountry\` |
| hlp | Help tooltip text | \`hlp\_GlobalGroups\` |
| ins | Any instruction text | \`ins\_ClickCategoryNameToEdit\` |
| lbl | Any label | \`lbl\_Category\` |
| plc | Placeholder text | \`plc\_CommentBox\` |
| txt | Any text that does not fall into another category | \`txt\_EditReferenceTaskWarning\` |
| vld | Validation message text | \`vld\_DuplicateCategoryName\` |

3. **Name label keys with the English-language purpose of the label in Pascal case**  
   * *Note: It should be apparent to a designer what the purpose of the label key is without having to check the display text*

### C. Bundle Files

1. **Separate bundle files according to their area of functionality**  
   * *e.g*. \`AS.QNM.QuestionnaireSettings\` is its own bundle file for all display text related to the text in the questionnaire settings site  
     * *Note: IO objects, because they were the first to be internationalized, do not follow the \`AS.FS.\` prefix naming convention*  
   * *Note: There is also a \`General\` bundle file to hold common words and terms*  
2. **Load bundle data in the top-level parent interface and pass it down to child rules**  
   * Name this local variable as \`i18nData\` and pass it as Any Type  
   * Use rule \`AS\_EX\_UT\_loadBundleByNames\` to load the IO-specific internationalization data  
   * *Note: In some places, such as record type fields like related action names, it is not possible to load all data and pass it around.  In this case, use rule \`AS\_I18N\_UT\_getAndDisplayLabelSingle\` to load and display a single label*  
   * *Note: For generic rules (e.g. \`AS\_CO\_CP\_searchField\`) that require internationalization, use \`AS\_CO\_I18N\_UT\_getAndDisplayLabelSingle\` to load and display the text directly in the rule so that bundles such as \`CommonObjects\` or \`General\` do not need to be added to the top level of every interface structure.*  
3. **Use a separate label for each instance of display text**  
   * Do not concatenate multiple labels in SAIL code, since the order of the concatenation might change based on the language  
   * *e.g*. To show "Product" and "Add Product", create these as two separate labels, do not create separate labels for "Product" and "Add" and concatenate them in SAIL  
   * *Note: It is acceptable to duplicate labels in different bundle files (e.g. two bundle files can have the "Cancel" label) so that fewer bundle files need to be loaded in any given context*

### C. Translation Sets

1. **Use a separate label for each instance of display text**  
   * Leverage translation variables if the string requires dynamic values  
2. **Try to avoid duplicating translation strings if possible**  
3. **Always validate all dependencies of a translation string when editing or removing an existing string**

## 11\. Data Driver

### A. General

1. **Follow the above guidance when developing the Data Driver applications**  
   * **Make sure to call processes from the FS applications as subprocesses instead of cloning them to ensure that the most recent version of the processes are being called**  
   * This is why using start forms in core creation processes is very important \-- they must be headless to be run automatically in Data Drivers.  
2. **Ensure the data driver is functional before every release**  
   * While it needs to be functional, don’t stress too much about making it beautiful, as this is a purely internal product for now.

## 12\. Database

### A. Maintainability

1. **When updating a table/view/column definition, it’s usually best to update the exact script that created the entity**  
   * Exceptions include when the entity was created in a previous release \- we may not want to update the original because it could interfere with future hotfixes  
   * Since the SMT framework will prevent the update from running in environments where the updated script has already been run, you will need to prepare an update script as well  
2. **Include a comment for each table and column**  
3. **Avoid triggers when possible**  
4. **Try to keep the database as logic-free as possible**

### B. Scalability

1. **Consider creating a framework for data archival if tables will grow at an unsustainable rate**  
2. **Add indexes to columns that are often queried on or that are used in view joins (as long as they have high cardinality)**  
   * Low cardinality indexes can actually reduce performance

### C. Auditing

1. **Set Auto Increment for PK on ref tables over 10k/100k**  
2. **Always put an id for a primary key when inserting into a non-configurable reference table**   
3. **Add comments to table and column definitions on creation**  
4. **Add indexes to high cardinality columns that will be heavily queried on**  
5. **When adding a new column, please please please specify AFTER so it’s not added after the metadata columns**

## 13\. Deprecation

### A. Objects

1. **If your solution *does not* have a customer**  
   1. Remove the unreferenced objects from the app container. **Optional**: Delete from dev and test environments to clean it up.  
2. **If your solution *does* have a customer**  
   1. If the object has been shipped before, prepend the object name with DEPRECATED\_. Keep this in the app package and deploy it with the release it was deprecated in. Also note in the description of the object which release it was deprecated in.  
      1. **Optional**: Once the release is done, you can remove the deprecated objects from the app in the next release. Example: Object is deprecated in 1.3. Ship it with 1.3. In 1.4, you are able to remove it from the shipped package.  
   2. If the object was created in the current release (it was never shipped), remove it from the app and mark the object as DEPRECATED.   
      1. **Optional**: Delete from dev and test environments to clean it up. To determine this, check the initial creation date of the object if you are not sure. 

### B. Database

1. **If we have a customer, we CANNOT drop tables/columns in the database. Here are the steps on what should be done if we are deprecating anything in the database**  
   1. Columns  
      * DO NOT DROP. Add a comment noting the deprecation. Do not change the column name. Note what release the column was deprecated in for more information. Do this for both MariaDB and Oracle.  
        1. Example: ALTER TABLE \`AS\_GCW\_SOLIC\_PERF\_INFO\` CHANGE \`VEH\_NUM\` \`VEH\_NUM\` VARCHAR(25) NULL DEFAULT NULL COMMENT 'DEPRECATED in 1.4 release';  
   2. Tables  
      1. DO NOT DROP. Add a comment noting the deprecation. Do not change the table name. Note what release the table was deprecated in for more information. Do this for both MariaDB and Oracle.  
         1. Example: ALTER TABLE \`AS\_GCW\_SOLIC\_PERF\_INFO\` COMMENT  'DEPRECATED in 1.4 release';  
   3. Views  
      1. Dropping the views is ok since it is just a query. We should add an ‘if exists’ line for safety. For Oracle there is not a straightforward way to drop with ‘if exists’ so a stored procedure will need to be used  
   4. Constraints  
      1. Drop with an ‘if exists’ to be safe  
2. **Rules for editing Appian Objects related to the database**   
   1. What is safe to do  
      1. Remove unused fields from the CDT  
      2. Remove unused tables from the datastores  
      3. Remove unused CDTs from the app   
      4. Remove ENT constants and any references to an entity that is unused from the app   
   2. What is NOT safe to do  
      1. Delete datastores  
      2. Delete CDTs

