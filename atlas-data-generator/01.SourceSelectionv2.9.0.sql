
-- START SCRIPT EXECUTION FRAMEWORK

CREATE TABLE IF NOT EXISTS `AS_GAM_ScriptExecutionHistory` (
  `scriptexecuteid` INT(11) NOT NULL AUTO_INCREMENT COMMENT "Primary key, represents the execution of a single script",
  `executeid` INT(11) NULL DEFAULT NULL COMMENT "The execution ID of the set of scripts that are run in a single execution",
  `releaseid` INT(11) NULL DEFAULT NULL COMMENT "The release ID of the script. NOTE that this ID is not meant to be sequential, purely an identifier. Do not be alarmed if the release order does not match up with the ID order.",
  `releasename` VARCHAR(255) NULL DEFAULT NULL COMMENT "The release name of the script",
  `scriptid` INT(11) NULL DEFAULT NULL COMMENT "The ID of the script. NOTE that this ID is not meant to be sequential, purely an identifier. Do not be alarmed if the script execution order does not match up with the ID order.",
  `scriptname` VARCHAR(255) NULL DEFAULT NULL COMMENT "The name of the script",
  `scriptversionid` INT(11) NULL DEFAULT NULL COMMENT "The version ID of the script. NOTE that this ID is not meant to be sequential, purely an identifier. Do not be alarmed if the script execution order does not match up with the ID order.",
  `starttime` TIMESTAMP NULL DEFAULT NULL COMMENT "The start time of script execution",
  `endtime` TIMESTAMP NULL DEFAULT NULL COMMENT "The end time of script execution",
  `executetime` INT(11) NULL DEFAULT NULL COMMENT "The duration of the script exeuction in milliseconds",
  `issuccess` TINYINT(1) NULL DEFAULT NULL COMMENT "Flag to desognate if the script was successfully executed",
  `executionskipped` TINYINT(1) NULL DEFAULT NULL COMMENT "Flag to desognate if the script was skipped, note that single-line scripts will intentionally be skipped on subsequent exeuctions",
  PRIMARY KEY (`scriptexecuteid`)
) COMMENT "DO NOT DELETE OR MODIFY THIS TABLE, SYSTEM GENERATED - Holds the script execution history for the Government Acquisition Management application";

DROP TRIGGER IF EXISTS `AS_GAM_ScriptExecutionHistory_Trigger`;

DELIMITER $$

CREATE TRIGGER `AS_GAM_ScriptExecutionHistory_Trigger` BEFORE INSERT ON `AS_GAM_ScriptExecutionHistory` FOR EACH ROW BEGIN
	IF ISNULL(NEW.`scriptid`) THEN
		SET NEW.`executeid` = (SELECT COALESCE(MAX(`executeid`) + 1, 1) FROM `AS_GAM_ScriptExecutionHistory`);
	ELSE
		SET NEW.`executeid` = (SELECT MAX(`executeid`) FROM `AS_GAM_ScriptExecutionHistory`);
	END IF;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS `AS_GAM_Initial_Execution`;

DELIMITER $$

CREATE PROCEDURE AS_GAM_Initial_Execution(
IN in_multilineYN char(1),
IN in_releaseid int,
IN in_releasename varchar(255),
IN in_scriptid int, 
IN in_scriptname varchar(255), 
IN in_scriptversionid int,
OUT out_executeid int,
OUT out_continueProc int)

BEGIN

    INSERT INTO `AS_GAM_ScriptExecutionHistory`(`releaseid`, `releasename`, `scriptid`, `scriptname`, `scriptversionid`, `starttime`, `issuccess`)
    VALUES (in_releaseid, in_releasename, in_scriptid, in_scriptname, in_scriptversionid, CURRENT_TIMESTAMP(6), FALSE);

    select `executeid` into out_executeid from `AS_GAM_ScriptExecutionHistory` where scriptexecuteid = LAST_INSERT_ID();

    IF in_multilineYN = "Y"
    THEN
        SET out_continueProc = 1;
    ELSEIF EXISTS (
        SELECT * FROM `AS_GAM_ScriptExecutionHistory`
        WHERE `releaseid` = in_releaseid AND `scriptid` = in_scriptid AND `issuccess` = TRUE
    )
    THEN
        UPDATE `AS_GAM_ScriptExecutionHistory`
            SET `issuccess` = TRUE, `executionskipped` = TRUE
            WHERE `releaseid` = in_releaseid AND `scriptid` = in_scriptid AND `scriptversionid` = in_scriptversionid AND `executeid` = out_executeid;

        SET out_continueProc = 0;
    ELSE

        SET out_continueProc = 1;

    END IF;

END $$

DELIMITER ;

DROP PROCEDURE IF EXISTS `AS_GAM_Update_Execution`;

DELIMITER $$

CREATE PROCEDURE AS_GAM_Update_Execution(
IN in_executeid int,
IN in_releaseid int,
IN in_scriptid int,
IN in_scriptversionid int
)
BEGIN       
        
UPDATE `AS_GAM_ScriptExecutionHistory`
	SET `endtime` = CURRENT_TIMESTAMP(6), `executetime` = ABS(TIMESTAMPDIFF(MICROSECOND, `starttime`, CURRENT_TIMESTAMP(6)) / 1000), `issuccess` = TRUE, `executionskipped` = FALSE
	WHERE `releaseid` = in_releaseid AND `scriptid` = in_scriptid AND `scriptversionid` = in_scriptversionid AND `executeid` = in_executeid;
    
END $$
        
DELIMITER ;

INSERT INTO `AS_GAM_ScriptExecutionHistory`
	(`releasename`, `scriptname`, `issuccess`, `executionskipped`)
	VALUES ("N/A", "Priming column `executeid`", TRUE, FALSE);

DELIMITER $$

CREATE OR REPLACE PROCEDURE AS_GAM_EXECUTESQL(IN `SQLTOEXECUTE` LONGTEXT)
BEGIN
    SET @sqlv = SQLTOEXECUTE;
    PREPARE stmt FROM @sqlv;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END $$

CREATE OR REPLACE PROCEDURE AS_GAM_DropConstraint(
IN in_tableName varchar(255),
IN in_referencedTableName varchar(255),
IN in_columnName varchar(255), 
IN in_referencedColumnName varchar(255)
)

BEGIN
DECLARE constraintName varchar(255);
DECLARE sqlCommand varchar(4000); 

SELECT CONSTRAINT_NAME into constraintName
FROM information_schema.KEY_COLUMN_USAGE
WHERE  CONSTRAINT_SCHEMA = DATABASE()
and REFERENCED_TABLE_SCHEMA = DATABASE()
and `TABLE_NAME` = in_tableName
and COLUMN_NAME = in_columnName
and REFERENCED_TABLE_NAME = in_referencedTableName
and REFERENCED_COLUMN_NAME = in_referencedColumnName;

IF constraintName IS NOT NULL
THEN 
SET sqlCommand = CONCAT("ALTER TABLE ", in_tableName," DROP CONSTRAINT ", constraintName);
CALL AS_GAM_EXECUTESQL(sqlCommand);

END IF;

END $$

DELIMITER ;


-- END SCRIPT EXECUTION FRAMEWORK



-- START SCRIPT EXECUTION FRAMEWORK

CREATE TABLE IF NOT EXISTS `AS_GSS_ScriptExecutionHistory` (
  `scriptexecuteid` INT(11) NOT NULL AUTO_INCREMENT COMMENT "Primary key, represents the execution of a single script",
  `executeid` INT(11) NULL DEFAULT NULL COMMENT "The execution ID of the set of scripts that are run in a single execution",
  `releaseid` INT(11) NULL DEFAULT NULL COMMENT "The release ID of the script. NOTE that this ID is not meant to be sequential, purely an identifier. Do not be alarmed if the release order does not match up with the ID order.",
  `releasename` VARCHAR(255) NULL DEFAULT NULL COMMENT "The release name of the script",
  `scriptid` INT(11) NULL DEFAULT NULL COMMENT "The ID of the script. NOTE that this ID is not meant to be sequential, purely an identifier. Do not be alarmed if the script execution order does not match up with the ID order.",
  `scriptname` VARCHAR(255) NULL DEFAULT NULL COMMENT "The name of the script",
  `scriptversionid` INT(11) NULL DEFAULT NULL COMMENT "The version ID of the script. NOTE that this ID is not meant to be sequential, purely an identifier. Do not be alarmed if the script execution order does not match up with the ID order.",
  `starttime` TIMESTAMP NULL DEFAULT NULL COMMENT "The start time of script execution",
  `endtime` TIMESTAMP NULL DEFAULT NULL COMMENT "The end time of script execution",
  `executetime` INT(11) NULL DEFAULT NULL COMMENT "The duration of the script exeuction in milliseconds",
  `issuccess` TINYINT(1) NULL DEFAULT NULL COMMENT "Flag to desognate if the script was successfully executed",
  `executionskipped` TINYINT(1) NULL DEFAULT NULL COMMENT "Flag to desognate if the script was skipped, note that single-line scripts will intentionally be skipped on subsequent exeuctions",
  PRIMARY KEY (`scriptexecuteid`)
) COMMENT "DO NOT DELETE OR MODIFY THIS TABLE, SYSTEM GENERATED - Holds the script execution history for the Source Selection application";

DROP TRIGGER IF EXISTS `AS_GSS_ScriptExecutionHistory_Trigger`;

DELIMITER $$

CREATE TRIGGER `AS_GSS_ScriptExecutionHistory_Trigger` BEFORE INSERT ON `AS_GSS_ScriptExecutionHistory` FOR EACH ROW BEGIN
	IF ISNULL(NEW.`scriptid`) THEN
		SET NEW.`executeid` = (SELECT COALESCE(MAX(`executeid`) + 1, 1) FROM `AS_GSS_ScriptExecutionHistory`);
	ELSE
		SET NEW.`executeid` = (SELECT MAX(`executeid`) FROM `AS_GSS_ScriptExecutionHistory`);
	END IF;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS `AS_GSS_Initial_Execution`;

DELIMITER $$

CREATE PROCEDURE AS_GSS_Initial_Execution(
IN in_multilineYN char(1),
IN in_releaseid int,
IN in_releasename varchar(255),
IN in_scriptid int, 
IN in_scriptname varchar(255), 
IN in_scriptversionid int,
OUT out_executeid int,
OUT out_continueProc int)

BEGIN

    INSERT INTO `AS_GSS_ScriptExecutionHistory`(`releaseid`, `releasename`, `scriptid`, `scriptname`, `scriptversionid`, `starttime`, `issuccess`)
    VALUES (in_releaseid, in_releasename, in_scriptid, in_scriptname, in_scriptversionid, CURRENT_TIMESTAMP(6), FALSE);

    select `executeid` into out_executeid from `AS_GSS_ScriptExecutionHistory` where scriptexecuteid = LAST_INSERT_ID();

    IF in_multilineYN = "Y"
    THEN
        SET out_continueProc = 1;
    ELSEIF EXISTS (
        SELECT * FROM `AS_GSS_ScriptExecutionHistory`
        WHERE `releaseid` = in_releaseid AND `scriptid` = in_scriptid AND `issuccess` = TRUE
    )
    THEN
        UPDATE `AS_GSS_ScriptExecutionHistory`
            SET `issuccess` = TRUE, `executionskipped` = TRUE
            WHERE `releaseid` = in_releaseid AND `scriptid` = in_scriptid AND `scriptversionid` = in_scriptversionid AND `executeid` = out_executeid;

        SET out_continueProc = 0;
    ELSE

        SET out_continueProc = 1;

    END IF;

END $$

DELIMITER ;

DROP PROCEDURE IF EXISTS `AS_GSS_Update_Execution`;

DELIMITER $$

CREATE PROCEDURE AS_GSS_Update_Execution(
IN in_executeid int,
IN in_releaseid int,
IN in_scriptid int,
IN in_scriptversionid int
)
BEGIN       
        
UPDATE `AS_GSS_ScriptExecutionHistory`
	SET `endtime` = CURRENT_TIMESTAMP(6), `executetime` = ABS(TIMESTAMPDIFF(MICROSECOND, `starttime`, CURRENT_TIMESTAMP(6)) / 1000), `issuccess` = TRUE, `executionskipped` = FALSE
	WHERE `releaseid` = in_releaseid AND `scriptid` = in_scriptid AND `scriptversionid` = in_scriptversionid AND `executeid` = in_executeid;
    
END $$
        
DELIMITER ;

INSERT INTO `AS_GSS_ScriptExecutionHistory`
	(`releasename`, `scriptname`, `issuccess`, `executionskipped`)
	VALUES ("N/A", "Priming column `executeid`", TRUE, FALSE);

DELIMITER $$

CREATE OR REPLACE PROCEDURE AS_GSS_EXECUTESQL(IN `SQLTOEXECUTE` LONGTEXT)
BEGIN
    SET @sqlv = SQLTOEXECUTE;
    PREPARE stmt FROM @sqlv;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END $$

CREATE OR REPLACE PROCEDURE AS_GSS_DropConstraint(
IN in_tableName varchar(255),
IN in_referencedTableName varchar(255),
IN in_columnName varchar(255), 
IN in_referencedColumnName varchar(255)
)

BEGIN
DECLARE constraintName varchar(255);
DECLARE sqlCommand varchar(4000); 

SELECT CONSTRAINT_NAME into constraintName
FROM information_schema.KEY_COLUMN_USAGE
WHERE  CONSTRAINT_SCHEMA = DATABASE()
and REFERENCED_TABLE_SCHEMA = DATABASE()
and `TABLE_NAME` = in_tableName
and COLUMN_NAME = in_columnName
and REFERENCED_TABLE_NAME = in_referencedTableName
and REFERENCED_COLUMN_NAME = in_referencedColumnName;

IF constraintName IS NOT NULL
THEN 
SET sqlCommand = CONCAT("ALTER TABLE ", in_tableName," DROP CONSTRAINT ", constraintName);
CALL AS_GSS_EXECUTESQL(sqlCommand);

END IF;

END $$

DELIMITER ;


-- END SCRIPT EXECUTION FRAMEWORK





-- *********************************************************************************************************************************************************************************************
-- Award Management 1.0 / Clause Automation 1.0 / Contract Writing 1.0 / Management Suite 1.0 / ProcureSight v1.0 / Requirements Management 1.1 / Source Selection 1.0 / Vendor Management 1.0
-- *********************************************************************************************************************************************************************************************


-- *****************************************************
-- [345] Create Table AS_GAM_AWARD_REQUIREMENT_MAPPING
-- *****************************************************
-- Table for mapping between requirement and award
-- *****************************************************

DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GAM_RunFrameworkScript()
BEGIN
CALL AS_GAM_Initial_Execution("N",6, "Award Management 1.0 / Clause Automation 1.0 / Contract Writing 1.0 / Management Suite 1.0 / ProcureSight v1.0 / Requirements Management 1.1 / Source Selection 1.0 / Vendor Management 1.0", 345, "Create Table AS_GAM_AWARD_REQUIREMENT_MAPPING",2251,  @AS_GAM_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE IF NOT EXISTS `AS_GAM_AWARD_REQUIREMENT_MAPPING` (
`ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
`AWARD_ID` int(11) DEFAULT NULL,
`REQUIREMENT_ID` int(11) DEFAULT NULL,
`CREATED_BY` varchar(255) DEFAULT NULL,
`CREATED_DATE_TIME` datetime DEFAULT NULL, `MODIFIED_BY` varchar(255) DEFAULT NULL, `MODIFIED_DATE_TIME` datetime DEFAULT NULL, `IS_ACTIVE` tinyint(1) DEFAULT NULL);

-- END SCRIPT CONTENT ---
 
CALL AS_GAM_Update_Execution(@AS_GAM_scriptExecuteId, 6, 345, 2251);
END IF;
END $$
DELIMITER ;

CALL AS_GAM_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;


-- *********************************************************
-- [355] Create table AS_GAM_A_R_AWARD_REQUIREMENT_MAPPING
-- *********************************************************
-- Audit table creation
-- *********************************************************

DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GAM_RunFrameworkScript()
BEGIN
CALL AS_GAM_Initial_Execution("N",6, "Award Management 1.0 / Clause Automation 1.0 / Contract Writing 1.0 / Management Suite 1.0 / ProcureSight v1.0 / Requirements Management 1.1 / Source Selection 1.0 / Vendor Management 1.0", 355, "Create table AS_GAM_A_R_AWARD_REQUIREMENT_MAPPING",2146,  @AS_GAM_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE IF NOT EXISTS `AS_GAM_A_R_AWARD_REQUIREMENT_MAPPING` (
`MAPPING_AUDIT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
`MAPPING_ID` int(11) DEFAULT NULL,
 `AWARD_ID` int(11) DEFAULT NULL,
 `TIMESTAMP` datetime DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL, `AUDIT_ACTION_CODE` varchar(255) DEFAULT NULL);

-- END SCRIPT CONTENT ---
 
CALL AS_GAM_Update_Execution(@AS_GAM_scriptExecuteId, 6, 355, 2146);
END IF;
END $$
DELIMITER ;

CALL AS_GAM_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;


-- ***************************************************************
-- [356] Create table AS_GAM_A_R_AWARD_REQUIREMENT_MAPPING_FIELD
-- ***************************************************************
-- Field level audit table creation
-- ***************************************************************

DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GAM_RunFrameworkScript()
BEGIN
CALL AS_GAM_Initial_Execution("N",6, "Award Management 1.0 / Clause Automation 1.0 / Contract Writing 1.0 / Management Suite 1.0 / ProcureSight v1.0 / Requirements Management 1.1 / Source Selection 1.0 / Vendor Management 1.0", 356, "Create table AS_GAM_A_R_AWARD_REQUIREMENT_MAPPING_FIELD",2147,  @AS_GAM_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE IF NOT EXISTS `AS_GAM_A_R_AWARD_REQUIREMENT_MAPPING_FIELD` (`MAPPING_AUDIT_FIELD_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
 `MAPPING_AUDIT_ID` int(11) DEFAULT NULL,
`FIELD_NAME` varchar(255) DEFAULT NULL,
`OLD_VALUE` varchar(4000) DEFAULT NULL, `NEW_VALUE` varchar(4000) DEFAULT NULL);
ALTER TABLE `AS_GAM_A_R_AWARD_REQUIREMENT_MAPPING_FIELD` ADD KEY `asgmrwrdrqrmnt_smplfldchngs` (`MAPPING_AUDIT_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GAM_Update_Execution(@AS_GAM_scriptExecuteId, 6, 356, 2147);
END IF;
END $$
DELIMITER ;

CALL AS_GAM_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;


-- ****************************************************
-- [357] Alter table AS_GAM_AWARD_REQUIREMENT_MAPPING
-- ****************************************************
-- Alter query for AS_GAM_AWARD_REQUIREMENT_MAPPING
-- ****************************************************

DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GAM_RunFrameworkScript()
BEGIN
CALL AS_GAM_Initial_Execution("N",6, "Award Management 1.0 / Clause Automation 1.0 / Contract Writing 1.0 / Management Suite 1.0 / ProcureSight v1.0 / Requirements Management 1.1 / Source Selection 1.0 / Vendor Management 1.0", 357, "Alter table AS_GAM_AWARD_REQUIREMENT_MAPPING",954,  @AS_GAM_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GAM_AWARD_REQUIREMENT_MAPPING` CHANGE `ID` `MAPPING_ID` INT(11) NOT NULL AUTO_INCREMENT;

-- END SCRIPT CONTENT ---
 
CALL AS_GAM_Update_Execution(@AS_GAM_scriptExecuteId, 6, 357, 954);
END IF;
END $$
DELIMITER ;

CALL AS_GAM_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;


-- ***********************************************
-- [375] Create tables GAM_STATE and GAM_COUNTRY
-- ***********************************************
-- Create tables GAM_STATE and GAM_COUNTRY
-- ***********************************************

DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GAM_RunFrameworkScript()
BEGIN
CALL AS_GAM_Initial_Execution("N",6, "Award Management 1.0 / Clause Automation 1.0 / Contract Writing 1.0 / Management Suite 1.0 / ProcureSight v1.0 / Requirements Management 1.1 / Source Selection 1.0 / Vendor Management 1.0", 375, "Create tables GAM_STATE and GAM_COUNTRY",2252,  @AS_GAM_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE IF NOT EXISTS `AS_GAM_R_COUNTRY` (
  `COUNTRY_ID` int(11) NOT NULL AUTO_INCREMENT,
  `COUNTRY_NAME` varchar(50) NOT NULL,
  `COUNTRY_CODE` varchar(5) NOT NULL,
  `IS_ACTIVE` tinyint(1) NOT NULL,
  PRIMARY KEY (`COUNTRY_ID`)
) AUTO_INCREMENT=245 ;

CREATE TABLE IF NOT EXISTS `AS_GAM_R_STATE` (
  `STATE_ID` int(11) NOT NULL AUTO_INCREMENT,
  `STATE_NAME` varchar(50) NOT NULL,
  `STATE_CODE` varchar(5) NOT NULL,
  `IS_TERRITORY` tinyint(1) NOT NULL,
  `IS_ACTIVE` tinyint(1) NOT NULL,
  PRIMARY KEY (`STATE_ID`)
) AUTO_INCREMENT=57;

-- END SCRIPT CONTENT ---
 
CALL AS_GAM_Update_Execution(@AS_GAM_scriptExecuteId, 6, 375, 2252);
END IF;
END $$
DELIMITER ;

CALL AS_GAM_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;


-- *************************************
-- [376] Insert into table GAM_COUNTRY
-- *************************************
-- Insert into table GAM_COUNTRY
-- *************************************

DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GAM_RunFrameworkScript()
BEGIN
CALL AS_GAM_Initial_Execution("N",6, "Award Management 1.0 / Clause Automation 1.0 / Contract Writing 1.0 / Management Suite 1.0 / ProcureSight v1.0 / Requirements Management 1.1 / Source Selection 1.0 / Vendor Management 1.0", 376, "Insert into table GAM_COUNTRY",956,  @AS_GAM_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT IGNORE INTO `AS_GAM_R_COUNTRY` (`COUNTRY_ID`, `COUNTRY_NAME`, `COUNTRY_CODE`, `IS_ACTIVE`) VALUES
(1, 'Afghanistan', 'AF', true),
(2, 'Albania', 'AL', true),
(3, 'Algeria', 'DZ', true),
(4, 'American Samoa', 'DS', true),
(5, 'Andorra', 'AD', true),
(6, 'Angola', 'AO', true),
(7, 'Anguilla', 'AI', true),
(8, 'Antarctica', 'AQ', true),
(9, 'Antigua and Barbuda', 'AG', true),
(10, 'Argentina', 'AR', true),
(11, 'Armenia', 'AM', true),
(12, 'Aruba', 'AW', true),
(13, 'Australia', 'AU', true),
(14, 'Austria', 'AT', true),
(15, 'Azerbaijan', 'AZ', true),
(16, 'Bahamas', 'BS', true),
(17, 'Bahrain', 'BH', true),
(18, 'Bangladesh', 'BD', true),
(19, 'Barbados', 'BB', true),
(20, 'Belarus', 'BY', true),
(21, 'Belgium', 'BE', true),
(22, 'Belize', 'BZ', true),
(23, 'Benin', 'BJ', true),
(24, 'Bermuda', 'BM', true),
(25, 'Bhutan', 'BT', true),
(26, 'Bolivia', 'BO', true),
(27, 'Bosnia and Herzegovina', 'BA', true),
(28, 'Botswana', 'BW', true),
(29, 'Bouvet Island', 'BV', true),
(30, 'Brazil', 'BR', true),
(31, 'British Indian Ocean Territory', 'IO', true),
(32, 'Brunei Darussalam', 'BN', true),
(33, 'Bulgaria', 'BG', true),
(34, 'Burkina Faso', 'BF', true),
(35, 'Burundi', 'BI', true),
(36, 'Cambodia', 'KH', true),
(37, 'Cameroon', 'CM', true),
(38, 'Canada', 'CA', true),
(39, 'Cape Verde', 'CV', true),
(40, 'Cayman Islands', 'KY', true),
(41, 'Central African Republic', 'CF', true),
(42, 'Chad', 'TD', true),
(43, 'Chile', 'CL', true),
(44, 'China', 'CN', true),
(45, 'Christmas Island', 'CX', true),
(46, 'Cocos (Keeling) Islands', 'CC', true),
(47, 'Colombia', 'CO', true),
(48, 'Comoros', 'KM', true),
(49, 'Congo', 'CG', true),
(50, 'Cook Islands', 'CK', true),
(51, 'Costa Rica', 'CR', true),
(52, 'Croatia (Hrvatska)', 'HR', true),
(53, 'Cuba', 'CU', true),
(54, 'Cyprus', 'CY', true),
(55, 'Czech Republic', 'CZ', true),
(56, 'Denmark', 'DK', true),
(57, 'Djibouti', 'DJ', true),
(58, 'Dominica', 'DM', true),
(59, 'Dominican Republic', 'DO', true),
(60, 'East Timor', 'TP', true),
(61, 'Ecuador', 'EC', true),
(62, 'Egypt', 'EG', true),
(63, 'El Salvador', 'SV', true),
(64, 'Equatorial Guinea', 'GQ', true),
(65, 'Eritrea', 'ER', true),
(66, 'Estonia', 'EE', true),
(67, 'Ethiopia', 'ET', true),
(68, 'Falkland Islands (Malvinas)', 'FK', true),
(69, 'Faroe Islands', 'FO', true),
(70, 'Fiji', 'FJ', true),
(71, 'Finland', 'FI', true),
(72, 'France', 'FR', true),
(73, 'France, Metropolitan', 'FX', true),
(74, 'French Guiana', 'GF', true),
(75, 'French Polynesia', 'PF', true),
(76, 'French Southern Territories', 'TF', true),
(77, 'Gabon', 'GA', true),
(78, 'Gambia', 'GM', true),
(79, 'Georgia', 'GE', true),
(80, 'Germany', 'DE', true),
(81, 'Ghana', 'GH', true),
(82, 'Gibraltar', 'GI', true),
(83, 'Guernsey', 'GK', true),
(84, 'Greece', 'GR', true),
(85, 'Greenland', 'GL', true),
(86, 'Grenada', 'GD', true),
(87, 'Guadeloupe', 'GP', true),
(88, 'Guam', 'GU', true),
(89, 'Guatemala', 'GT', true),
(90, 'Guinea', 'GN', true),
(91, 'Guinea-Bissau', 'GW', true),
(92, 'Guyana', 'GY', true),
(93, 'Haiti', 'HT', true),
(94, 'Heard and Mc Donald Islands', 'HM', true),
(95, 'Honduras', 'HN', true),
(96, 'Hong Kong', 'HK', true),
(97, 'Hungary', 'HU', true),
(98, 'Iceland', 'IS', true),
(99, 'India', 'IN', true),
(100, 'Isle of Man', 'IM', true),
(101, 'Indonesia', 'ID', true),
(102, 'Iran (Islamic Republic of)', 'IR', true),
(103, 'Iraq', 'IQ', true),
(104, 'Ireland', 'IE', true),
(105, 'Israel', 'IL', true),
(106, 'Italy', 'IT', true),
(107, 'Ivory Coast', 'CI', true),
(108, 'Jersey', 'JE', true),
(109, 'Jamaica', 'JM', true),
(110, 'Japan', 'JP', true),
(111, 'Jordan', 'JO', true),
(112, 'Kazakhstan', 'KZ', true),
(113, 'Kenya', 'KE', true),
(114, 'Kiribati', 'KI', true),
(115, 'Korea, Democratic People\'s Republic of', 'KP', true),
(116, 'Korea, Republic of', 'KR', true),
(117, 'Kosovo', 'XK', true),
(118, 'Kuwait', 'KW', true),
(119, 'Kyrgyzstan', 'KG', true),
(120, 'Lao People\'s Democratic Republic', 'LA', true),
(121, 'Latvia', 'LV', true),
(122, 'Lebanon', 'LB', true),
(123, 'Lesotho', 'LS', true),
(124, 'Liberia', 'LR', true),
(125, 'Libyan Arab Jamahiriya', 'LY', true),
(126, 'Liechtenstein', 'LI', true),
(127, 'Lithuania', 'LT', true),
(128, 'Luxembourg', 'LU', true),
(129, 'Macau', 'MO', true),
(130, 'Macedonia', 'MK', true),
(131, 'Madagascar', 'MG', true),
(132, 'Malawi', 'MW', true),
(133, 'Malaysia', 'MY', true),
(134, 'Maldives', 'MV', true),
(135, 'Mali', 'ML', true),
(136, 'Malta', 'MT', true),
(137, 'Marshall Islands', 'MH', true),
(138, 'Martinique', 'MQ', true),
(139, 'Mauritania', 'MR', true),
(140, 'Mauritius', 'MU', true),
(141, 'Mayotte', 'TY', true),
(142, 'Mexico', 'MX', true),
(143, 'Micronesia, Federated States of', 'FM', true),
(144, 'Moldova, Republic of', 'MD', true),
(145, 'Monaco', 'MC', true),
(146, 'Mongolia', 'MN', true),
(147, 'Montenegro', 'ME', true),
(148, 'Montserrat', 'MS', true),
(149, 'Morocco', 'MA', true),
(150, 'Mozambique', 'MZ', true),
(151, 'Myanmar', 'MM', true),
(152, 'Namibia', 'NA', true),
(153, 'Nauru', 'NR', true),
(154, 'Nepal', 'NP', true),
(155, 'Netherlands', 'NL', true),
(156, 'Netherlands Antilles', 'AN', true),
(157, 'New Caledonia', 'NC', true),
(158, 'New Zealand', 'NZ', true),
(159, 'Nicaragua', 'NI', true),
(160, 'Niger', 'NE', true),
(161, 'Nigeria', 'NG', true),
(162, 'Niue', 'NU', true),
(163, 'Norfolk Island', 'NF', true),
(164, 'Northern Mariana Islands', 'MP', true),
(165, 'Norway', 'NO', true),
(166, 'Oman', 'OM', true),
(167, 'Pakistan', 'PK', true),
(168, 'Palau', 'PW', true),
(169, 'Palestine', 'PS', true),
(170, 'Panama', 'PA', true),
(171, 'Papua New Guinea', 'PG', true),
(172, 'Paraguay', 'PY', true),
(173, 'Peru', 'PE', true),
(174, 'Philippines', 'PH', true),
(175, 'Pitcairn', 'PN', true),
(176, 'Poland', 'PL', true),
(177, 'Portugal', 'PT', true),
(178, 'Puerto Rico', 'PR', true),
(179, 'Qatar', 'QA', true),
(180, 'Reunion', 'RE', true),
(181, 'Romania', 'RO', true),
(182, 'Russian Federation', 'RU', true),
(183, 'Rwanda', 'RW', true),
(184, 'Saint Kitts and Nevis', 'KN', true),
(185, 'Saint Lucia', 'LC', true),
(186, 'Saint Vincent and the Grenadines', 'VC', true),
(187, 'Samoa', 'WS', true),
(188, 'San Marino', 'SM', true),
(189, 'Sao Tome and Principe', 'ST', true),
(190, 'Saudi Arabia', 'SA', true),
(191, 'Senegal', 'SN', true),
(192, 'Serbia', 'RS', true),
(193, 'Seychelles', 'SC', true),
(194, 'Sierra Leone', 'SL', true),
(195, 'Singapore', 'SG', true),
(196, 'Slovakia', 'SK', true),
(197, 'Slovenia', 'SI', true),
(198, 'Solomon Islands', 'SB', true),
(199, 'Somalia', 'SO', true),
(200, 'South Africa', 'ZA', true),
(201, 'South Georgia South Sandwich Islands', 'GS', true),
(202, 'South Sudan', 'SS', true),
(203, 'Spain', 'ES', true),
(204, 'Sri Lanka', 'LK', true),
(205, 'St. Helena', 'SH', true),
(206, 'St. Pierre and Miquelon', 'PM', true),
(207, 'Sudan', 'SD', true),
(208, 'Suriname', 'SR', true),
(209, 'Svalbard and Jan Mayen Islands', 'SJ', true),
(210, 'Swaziland', 'SZ', true),
(211, 'Sweden', 'SE', true),
(212, 'Switzerland', 'CH', true),
(213, 'Syrian Arab Republic', 'SY', true),
(214, 'Taiwan', 'TW', true),
(215, 'Tajikistan', 'TJ', true),
(216, 'Tanzania, United Republic of', 'TZ', true),
(217, 'Thailand', 'TH', true),
(218, 'Togo', 'TG', true),
(219, 'Tokelau', 'TK', true),
(220, 'Tonga', 'TO', true),
(221, 'Trinidad and Tobago', 'TT', true),
(222, 'Tunisia', 'TN', true),
(223, 'Turkey', 'TR', true),
(224, 'Turkmenistan', 'TM', true),
(225, 'Turks and Caicos Islands', 'TC', true),
(226, 'Tuvalu', 'TV', true),
(227, 'Uganda', 'UG', true),
(228, 'Ukraine', 'UA', true),
(229, 'United Arab Emirates', 'AE', true),
(230, 'United Kingdom', 'GB', true),
(231, 'United States', 'US', true),
(232, 'Uruguay', 'UY', true),
(233, 'Uzbekistan', 'UZ', true),
(234, 'Vanuatu', 'VU', true),
(235, 'Vatican City State', 'VA', true),
(236, 'Venezuela', 'VE', true),
(237, 'Vietnam', 'VN', true),
(238, 'Virgin Islands (British)', 'VG', true),
(239, 'Wallis and Futuna Islands', 'WF', true),
(240, 'Western Sahara', 'EH', true),
(241, 'Yemen', 'YE', true),
(242, 'Zaire', 'ZR', true),
(243, 'Zambia', 'ZM', true),
(244, 'Zimbabwe', 'ZW', true);

-- END SCRIPT CONTENT ---
 
CALL AS_GAM_Update_Execution(@AS_GAM_scriptExecuteId, 6, 376, 956);
END IF;
END $$
DELIMITER ;

CALL AS_GAM_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;


-- ***********************************
-- [377] Insert into table GAM_STATE
-- ***********************************
-- Insert into table GAM_STATE
-- ***********************************

DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GAM_RunFrameworkScript()
BEGIN
CALL AS_GAM_Initial_Execution("N",6, "Award Management 1.0 / Clause Automation 1.0 / Contract Writing 1.0 / Management Suite 1.0 / ProcureSight v1.0 / Requirements Management 1.1 / Source Selection 1.0 / Vendor Management 1.0", 377, "Insert into table GAM_STATE",957,  @AS_GAM_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT IGNORE INTO `AS_GAM_R_STATE` (`STATE_ID`, `STATE_NAME`, `STATE_CODE`, `IS_TERRITORY`, `IS_ACTIVE`) VALUES
(1, 'Alabama', 'AL', false, true),
(2, 'Alaska', 'AK', false, true),
(3, 'Arizona', 'AZ', false, true),
(4, 'Arkansas', 'AR', false, true),
(5, 'California', 'CA', false, true),
(6, 'Colorado', 'CO', false, true),
(7, 'Connecticut', 'CT', false, true),
(8, 'Delaware', 'DE', false, true),
(9, 'District of Columbia', 'DC', false, true),
(10, 'Florida', 'FL', false, true),
(11, 'Georgia', 'GA', false, true),
(12, 'Guam', 'GU', true, true),
(13, 'Hawaii', 'HI', false, true),
(14, 'Idaho', 'ID', false, true),
(15, 'Illinois', 'IL', false, true),
(16, 'Indiana', 'IN', false, true),
(17, 'Iowa', 'IA', false, true),
(18, 'Kansas', 'KS', false, true),
(19, 'Kentucky', 'KY', false, true),
(20, 'Louisiana', 'LA', false, true),
(21, 'Maine', 'ME', false, true),
(22, 'Maryland', 'MD', false, true),
(23, 'Massachusetts', 'MA', false, true),
(24, 'Michigan', 'MI', false, true),
(25, 'Minnesota', 'MN', false, true),
(26, 'Mississippi', 'MS', false, true),
(27, 'Missouri', 'MO', false, true),
(28, 'Montana', 'MT', false, true),
(29, 'Nebraska', 'NE', false, true),
(30, 'Nevada', 'NV', false, true),
(31, 'New Hampshire', 'NH', false, true),
(32, 'New Jersey', 'NJ', false, true),
(33, 'New Mexico', 'NM', false, true),
(34, 'New York', 'NY', false, true),
(35, 'North Carolina', 'NC', false, true),
(36, 'North Dakota', 'ND', false, true),
(37, 'Ohio', 'OH', false, true),
(38, 'Oklahoma', 'OK', false, true),
(39, 'Oregon', 'OR', false, true),
(40, 'Pennsylvania', 'PA', false, true),
(41, 'Puerto Rico', 'PR', true, true),
(42, 'Rhode Island', 'RI', false, true),
(43, 'South Carolina', 'SC', false, true),
(44, 'South Dakota', 'SD', false, true),
(45, 'Tennessee', 'TN', false, true),
(46, 'Texas', 'TX', false, true),
(47, 'Utah', 'UT', false, true),
(48, 'Vermont', 'VT', false, true),
(49, 'Virgin Islands', 'VI', true, true),
(50, 'Virginia', 'VA', false, true),
(51, 'Washington', 'WA', false, true),
(52, 'West Virginia', 'WV', false, true),
(53, 'Wisconsin', 'WI', false, true),
(54, 'Wyoming', 'WY', false, true),
(55, 'American Samoa', 'AS', true, true),
(56, 'Northern Mariana Islands', 'MP', true, true);

-- END SCRIPT CONTENT ---
 
CALL AS_GAM_Update_Execution(@AS_GAM_scriptExecuteId, 6, 377, 957);
END IF;
END $$
DELIMITER ;

CALL AS_GAM_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;





-- *********************************************************************************************************************************************************************************************
-- Award Management 1.1 / Clause Automation 1.0 / Contract Writing 1.0 / Management Suite 1.0 / ProcureSight v1.0 / Requirements Management 1.2 / Source Selection 1.0 / Vendor Management 1.0
-- *********************************************************************************************************************************************************************************************


-- *************************************
-- [564] Create BUSINESS_TYPE
-- *************************************
-- Create table AS_GAM_R_BUSINESS_TYPE
-- *************************************

DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GAM_RunFrameworkScript()
BEGIN
CALL AS_GAM_Initial_Execution("N",9, "Award Management 1.1 / Clause Automation 1.0 / Contract Writing 1.0 / Management Suite 1.0 / ProcureSight v1.0 / Requirements Management 1.2 / Source Selection 1.0 / Vendor Management 1.0", 564, "Create BUSINESS_TYPE",2253,  @AS_GAM_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE `AS_GAM_R_BUSINESS_TYPE` (
  `CODE` varchar(5) NOT NULL,
  `DESCRIPTION` varchar(255) NOT NULL,
  `IS_ACTIVE` tinyint(1) NOT NULL,
   PRIMARY KEY (`CODE`)
);

-- END SCRIPT CONTENT ---
 
CALL AS_GAM_Update_Execution(@AS_GAM_scriptExecuteId, 9, 564, 2253);
END IF;
END $$
DELIMITER ;

CALL AS_GAM_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;


-- **********************************************************************************
-- [565] Update COUNTRY Table
-- **********************************************************************************
-- Add the SAM_GOV_CODE column and insert the appropriate 3-character country codes
-- **********************************************************************************

DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GAM_RunFrameworkScript()
BEGIN
CALL AS_GAM_Initial_Execution("N",9, "Award Management 1.1 / Clause Automation 1.0 / Contract Writing 1.0 / Management Suite 1.0 / ProcureSight v1.0 / Requirements Management 1.2 / Source Selection 1.0 / Vendor Management 1.0", 565, "Update COUNTRY Table",959,  @AS_GAM_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GAM_R_COUNTRY` ADD `SAM_GOV_CODE` VARCHAR(255) NULL DEFAULT NULL AFTER `COUNTRY_CODE`;

Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'AFG' WHERE `COUNTRY_NAME` = "Afghanistan" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ALB' WHERE `COUNTRY_NAME` = "Albania" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'DZA' WHERE `COUNTRY_NAME` = "Algeria" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ASM' WHERE `COUNTRY_NAME` = "American Samoa" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'AND' WHERE `COUNTRY_NAME` = "Andorra" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'AGO' WHERE `COUNTRY_NAME` = "Angola" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'AIA' WHERE `COUNTRY_NAME` = "Anguilla" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ATA' WHERE `COUNTRY_NAME` = "Antarctica" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ATG' WHERE `COUNTRY_NAME` = "Antigua and Barbuda" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ARG' WHERE `COUNTRY_NAME` = "Argentina" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ARM' WHERE `COUNTRY_NAME` = "Armenia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ABW' WHERE `COUNTRY_NAME` = "Aruba" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'AUS' WHERE `COUNTRY_NAME` = "Australia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'AUT' WHERE `COUNTRY_NAME` = "Austria" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'AZE' WHERE `COUNTRY_NAME` = "Azerbaijan" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'BHS' WHERE `COUNTRY_NAME` = "Bahamas" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'BHR' WHERE `COUNTRY_NAME` = "Bahrain" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'BGD' WHERE `COUNTRY_NAME` = "Bangladesh" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'BRB' WHERE `COUNTRY_NAME` = "Barbados" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'BLR' WHERE `COUNTRY_NAME` = "Belarus" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'BEL' WHERE `COUNTRY_NAME` = "Belgium" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'BLZ' WHERE `COUNTRY_NAME` = "Belize" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'BEN' WHERE `COUNTRY_NAME` = "Benin" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'BMU' WHERE `COUNTRY_NAME` = "Bermuda" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'BTN' WHERE `COUNTRY_NAME` = "Bhutan" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'BOL' WHERE `COUNTRY_NAME` = "Bolivia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'BIH' WHERE `COUNTRY_NAME` = "Bosnia and Herzegovina" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'BWA' WHERE `COUNTRY_NAME` = "Botswana" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'BVT' WHERE `COUNTRY_NAME` = "Bouvet Island" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'BRA' WHERE `COUNTRY_NAME` = "Brazil" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'IOT' WHERE `COUNTRY_NAME` = "British Indian Ocean Territory" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'BRN' WHERE `COUNTRY_NAME` = "Brunei Darussalam" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'BGR' WHERE `COUNTRY_NAME` = "Bulgaria" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'BFA' WHERE `COUNTRY_NAME` = "Burkina Faso" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'BDI' WHERE `COUNTRY_NAME` = "Burundi" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'KHM' WHERE `COUNTRY_NAME` = "Cambodia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'CMR' WHERE `COUNTRY_NAME` = "Cameroon" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'CAN' WHERE `COUNTRY_NAME` = "Canada" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = NULL WHERE `COUNTRY_NAME` = "Cape Verde" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'CYM' WHERE `COUNTRY_NAME` = "Cayman Islands" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'CAF' WHERE `COUNTRY_NAME` = "Central African Republic" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'TCD' WHERE `COUNTRY_NAME` = "Chad" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'CHL' WHERE `COUNTRY_NAME` = "Chile" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'CHN' WHERE `COUNTRY_NAME` = "China" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'CXR' WHERE `COUNTRY_NAME` = "Christmas Island" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'CCK' WHERE `COUNTRY_NAME` = "Cocos (Keeling) Islands" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'COL' WHERE `COUNTRY_NAME` = "Colombia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'COM' WHERE `COUNTRY_NAME` = "Comoros" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'COG' WHERE `COUNTRY_NAME` = "Congo" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'COK' WHERE `COUNTRY_NAME` = "Cook Islands" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'CRI' WHERE `COUNTRY_NAME` = "Costa Rica" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'HRV' WHERE `COUNTRY_NAME` = "Croatia (Hrvatska)" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'CUB' WHERE `COUNTRY_NAME` = "Cuba" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'CYP' WHERE `COUNTRY_NAME` = "Cyprus" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'CZE' WHERE `COUNTRY_NAME` = "Czech Republic" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'DNK' WHERE `COUNTRY_NAME` = "Denmark" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'DJI' WHERE `COUNTRY_NAME` = "Djibouti" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'DMA' WHERE `COUNTRY_NAME` = "Dominica" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'DOM' WHERE `COUNTRY_NAME` = "Dominican Republic" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = NULL WHERE `COUNTRY_NAME` = "East Timor" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ECU' WHERE `COUNTRY_NAME` = "Ecuador" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'EGY' WHERE `COUNTRY_NAME` = "Egypt" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SLV' WHERE `COUNTRY_NAME` = "El Salvador" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'GNQ' WHERE `COUNTRY_NAME` = "Equatorial Guinea" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ERI' WHERE `COUNTRY_NAME` = "Eritrea" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'EST' WHERE `COUNTRY_NAME` = "Estonia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ETH' WHERE `COUNTRY_NAME` = "Ethiopia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'FLK' WHERE `COUNTRY_NAME` = "Falkland Islands (Malvinas)" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'FRO' WHERE `COUNTRY_NAME` = "Faroe Islands" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'FJI' WHERE `COUNTRY_NAME` = "Fiji" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'FIN' WHERE `COUNTRY_NAME` = "Finland" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'FRA' WHERE `COUNTRY_NAME` = "France" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = NULL WHERE `COUNTRY_NAME` = "France, Metropolitan" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'GUF' WHERE `COUNTRY_NAME` = "French Guiana" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'PYF' WHERE `COUNTRY_NAME` = "French Polynesia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ATF' WHERE `COUNTRY_NAME` = "French Southern Territories" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'GAB' WHERE `COUNTRY_NAME` = "Gabon" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'GMB' WHERE `COUNTRY_NAME` = "Gambia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'GEO' WHERE `COUNTRY_NAME` = "Georgia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'DEU' WHERE `COUNTRY_NAME` = "Germany" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'GHA' WHERE `COUNTRY_NAME` = "Ghana" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'GIB' WHERE `COUNTRY_NAME` = "Gibraltar" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'GRC' WHERE `COUNTRY_NAME` = "Greece" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'GRL' WHERE `COUNTRY_NAME` = "Greenland" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'GRD' WHERE `COUNTRY_NAME` = "Grenada" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'GLP' WHERE `COUNTRY_NAME` = "Guadeloupe" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'GUM' WHERE `COUNTRY_NAME` = "Guam" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'GTM' WHERE `COUNTRY_NAME` = "Guatemala" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'GGY' WHERE `COUNTRY_NAME` = "Guernsey" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'GIN' WHERE `COUNTRY_NAME` = "Guinea" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'GNB' WHERE `COUNTRY_NAME` = "Guinea-Bissau" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'GUY' WHERE `COUNTRY_NAME` = "Guyana" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'HTI' WHERE `COUNTRY_NAME` = "Haiti" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'HMD' WHERE `COUNTRY_NAME` = "Heard and Mc Donald Islands" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'HND' WHERE `COUNTRY_NAME` = "Honduras" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'HKG' WHERE `COUNTRY_NAME` = "Hong Kong" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'HUN' WHERE `COUNTRY_NAME` = "Hungary" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ISL' WHERE `COUNTRY_NAME` = "Iceland" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'IND' WHERE `COUNTRY_NAME` = "India" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'IDN' WHERE `COUNTRY_NAME` = "Indonesia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'IRN' WHERE `COUNTRY_NAME` = "Iran (Islamic Republic of)" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'IRQ' WHERE `COUNTRY_NAME` = "Iraq" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'IRL' WHERE `COUNTRY_NAME` = "Ireland" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'IMN' WHERE `COUNTRY_NAME` = "Isle of Man" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ISR' WHERE `COUNTRY_NAME` = "Israel" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ITA' WHERE `COUNTRY_NAME` = "Italy" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = NULL WHERE `COUNTRY_NAME` = "Ivory Coast" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'JAM' WHERE `COUNTRY_NAME` = "Jamaica" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'JPN' WHERE `COUNTRY_NAME` = "Japan" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'JEY' WHERE `COUNTRY_NAME` = "Jersey" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'JOR' WHERE `COUNTRY_NAME` = "Jordan" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'KAZ' WHERE `COUNTRY_NAME` = "Kazakhstan" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'KEN' WHERE `COUNTRY_NAME` = "Kenya" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'KIR' WHERE `COUNTRY_NAME` = "Kiribati" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'PRK' WHERE `COUNTRY_NAME` = "Korea, Democratic People's Republic of" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'KOR' WHERE `COUNTRY_NAME` = "Korea, Republic of" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = NULL WHERE `COUNTRY_NAME` = "Kosovo" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'KWT' WHERE `COUNTRY_NAME` = "Kuwait" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'KGZ' WHERE `COUNTRY_NAME` = "Kyrgyzstan" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'LAO' WHERE `COUNTRY_NAME` = "Lao People's Democratic Republic" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'LVA' WHERE `COUNTRY_NAME` = "Latvia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'LBN' WHERE `COUNTRY_NAME` = "Lebanon" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'LSO' WHERE `COUNTRY_NAME` = "Lesotho" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'LBR' WHERE `COUNTRY_NAME` = "Liberia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'LBY' WHERE `COUNTRY_NAME` = "Libyan Arab Jamahiriya" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'LIE' WHERE `COUNTRY_NAME` = "Liechtenstein" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'LTU' WHERE `COUNTRY_NAME` = "Lithuania" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'LUX' WHERE `COUNTRY_NAME` = "Luxembourg" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MAC' WHERE `COUNTRY_NAME` = "Macau" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MKD' WHERE `COUNTRY_NAME` = "Macedonia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MDG' WHERE `COUNTRY_NAME` = "Madagascar" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MWI' WHERE `COUNTRY_NAME` = "Malawi" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MYS' WHERE `COUNTRY_NAME` = "Malaysia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MDV' WHERE `COUNTRY_NAME` = "Maldives" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MLI' WHERE `COUNTRY_NAME` = "Mali" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MLT' WHERE `COUNTRY_NAME` = "Malta" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MHL' WHERE `COUNTRY_NAME` = "Marshall Islands" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MTQ' WHERE `COUNTRY_NAME` = "Martinique" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MRT' WHERE `COUNTRY_NAME` = "Mauritania" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MUS' WHERE `COUNTRY_NAME` = "Mauritius" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MYT' WHERE `COUNTRY_NAME` = "Mayotte" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MEX' WHERE `COUNTRY_NAME` = "Mexico" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'FSM' WHERE `COUNTRY_NAME` = "Micronesia, Federated States of" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MDA' WHERE `COUNTRY_NAME` = "Moldova, Republic of" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MCO' WHERE `COUNTRY_NAME` = "Monaco" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MNG' WHERE `COUNTRY_NAME` = "Mongolia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MNE' WHERE `COUNTRY_NAME` = "Montenegro" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MSR' WHERE `COUNTRY_NAME` = "Montserrat" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MAR' WHERE `COUNTRY_NAME` = "Morocco" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MOZ' WHERE `COUNTRY_NAME` = "Mozambique" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = NULL WHERE `COUNTRY_NAME` = "Myanmar" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'NAM' WHERE `COUNTRY_NAME` = "Namibia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'NRU' WHERE `COUNTRY_NAME` = "Nauru" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'NPL' WHERE `COUNTRY_NAME` = "Nepal" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'NLD' WHERE `COUNTRY_NAME` = "Netherlands" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = NULL WHERE `COUNTRY_NAME` = "Netherlands Antilles" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'NCL' WHERE `COUNTRY_NAME` = "New Caledonia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'NZL' WHERE `COUNTRY_NAME` = "New Zealand" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'NIC' WHERE `COUNTRY_NAME` = "Nicaragua" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'NER' WHERE `COUNTRY_NAME` = "Niger" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'NGA' WHERE `COUNTRY_NAME` = "Nigeria" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'NIU' WHERE `COUNTRY_NAME` = "Niue" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'NFK' WHERE `COUNTRY_NAME` = "Norfolk Island" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'MNP' WHERE `COUNTRY_NAME` = "Northern Mariana Islands" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'NOR' WHERE `COUNTRY_NAME` = "Norway" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'OMN' WHERE `COUNTRY_NAME` = "Oman" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'PAK' WHERE `COUNTRY_NAME` = "Pakistan" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'PLW' WHERE `COUNTRY_NAME` = "Palau" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = NULL WHERE `COUNTRY_NAME` = "Palestine" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'PAN' WHERE `COUNTRY_NAME` = "Panama" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'PNG' WHERE `COUNTRY_NAME` = "Papua New Guinea" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'PRY' WHERE `COUNTRY_NAME` = "Paraguay" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'PER' WHERE `COUNTRY_NAME` = "Peru" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'PHL' WHERE `COUNTRY_NAME` = "Philippines" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'PCN' WHERE `COUNTRY_NAME` = "Pitcairn" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'POL' WHERE `COUNTRY_NAME` = "Poland" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'PRT' WHERE `COUNTRY_NAME` = "Portugal" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'PRI' WHERE `COUNTRY_NAME` = "Puerto Rico" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'QAT' WHERE `COUNTRY_NAME` = "Qatar" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'REU' WHERE `COUNTRY_NAME` = "Reunion" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ROU' WHERE `COUNTRY_NAME` = "Romania" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'RUS' WHERE `COUNTRY_NAME` = "Russian Federation" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'RWA' WHERE `COUNTRY_NAME` = "Rwanda" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'KNA' WHERE `COUNTRY_NAME` = "Saint Kitts and Nevis" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'LCA' WHERE `COUNTRY_NAME` = "Saint Lucia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'VCT' WHERE `COUNTRY_NAME` = "Saint Vincent and the Grenadines" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'WSM' WHERE `COUNTRY_NAME` = "Samoa" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SMR' WHERE `COUNTRY_NAME` = "San Marino" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'STP' WHERE `COUNTRY_NAME` = "Sao Tome and Principe" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SAU' WHERE `COUNTRY_NAME` = "Saudi Arabia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SEN' WHERE `COUNTRY_NAME` = "Senegal" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SRB' WHERE `COUNTRY_NAME` = "Serbia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SYC' WHERE `COUNTRY_NAME` = "Seychelles" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SLE' WHERE `COUNTRY_NAME` = "Sierra Leone" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SGP' WHERE `COUNTRY_NAME` = "Singapore" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SVK' WHERE `COUNTRY_NAME` = "Slovakia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SVN' WHERE `COUNTRY_NAME` = "Slovenia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SLB' WHERE `COUNTRY_NAME` = "Solomon Islands" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SOM' WHERE `COUNTRY_NAME` = "Somalia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ZAF' WHERE `COUNTRY_NAME` = "South Africa" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SGS' WHERE `COUNTRY_NAME` = "South Georgia South Sandwich Islands" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SSD' WHERE `COUNTRY_NAME` = "South Sudan" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ESP' WHERE `COUNTRY_NAME` = "Spain" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'LKA' WHERE `COUNTRY_NAME` = "Sri Lanka" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = NULL WHERE `COUNTRY_NAME` = "St. Helena" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = NULL WHERE `COUNTRY_NAME` = "St. Pierre and Miquelon" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SDN' WHERE `COUNTRY_NAME` = "Sudan" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SUR' WHERE `COUNTRY_NAME` = "Suriname" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SJM' WHERE `COUNTRY_NAME` = "Svalbard and Jan Mayen Islands" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SWZ' WHERE `COUNTRY_NAME` = "Swaziland" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SWE' WHERE `COUNTRY_NAME` = "Sweden" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'CHE' WHERE `COUNTRY_NAME` = "Switzerland" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'SYR' WHERE `COUNTRY_NAME` = "Syrian Arab Republic" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'TWN' WHERE `COUNTRY_NAME` = "Taiwan" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'TJK' WHERE `COUNTRY_NAME` = "Tajikistan" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'TZA' WHERE `COUNTRY_NAME` = "Tanzania, United Republic of" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'THA' WHERE `COUNTRY_NAME` = "Thailand" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'TGO' WHERE `COUNTRY_NAME` = "Togo" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'TKL' WHERE `COUNTRY_NAME` = "Tokelau" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'TON' WHERE `COUNTRY_NAME` = "Tonga" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'TTO' WHERE `COUNTRY_NAME` = "Trinidad and Tobago" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'TUN' WHERE `COUNTRY_NAME` = "Tunisia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'TUR' WHERE `COUNTRY_NAME` = "Turkey" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'TKM' WHERE `COUNTRY_NAME` = "Turkmenistan" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'TCA' WHERE `COUNTRY_NAME` = "Turks and Caicos Islands" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'TUV' WHERE `COUNTRY_NAME` = "Tuvalu" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'UGA' WHERE `COUNTRY_NAME` = "Uganda" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'UKR' WHERE `COUNTRY_NAME` = "Ukraine" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ARE' WHERE `COUNTRY_NAME` = "United Arab Emirates" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'GBR' WHERE `COUNTRY_NAME` = "United Kingdom" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'USA' WHERE `COUNTRY_NAME` = "United States" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'URY' WHERE `COUNTRY_NAME` = "Uruguay" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'UZB' WHERE `COUNTRY_NAME` = "Uzbekistan" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'VUT' WHERE `COUNTRY_NAME` = "Vanuatu" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'VAT' WHERE `COUNTRY_NAME` = "Vatican City State" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'VEN' WHERE `COUNTRY_NAME` = "Venezuela" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'VNM' WHERE `COUNTRY_NAME` = "Vietnam" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'VGB' WHERE `COUNTRY_NAME` = "Virgin Islands (British)" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'VIR' WHERE `COUNTRY_NAME` = "Wallis and Futuna Islands" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'WLF' WHERE `COUNTRY_NAME` = "Western Sahara" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ESH' WHERE `COUNTRY_NAME` = "Yemen" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'YEM' WHERE `COUNTRY_NAME` = "Zaire" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ZMB' WHERE `COUNTRY_NAME` = "Zambia" ;
Update `AS_GAM_R_COUNTRY` SET `SAM_GOV_CODE` = 'ZWE' WHERE `COUNTRY_NAME` = "Zimbabwe" ;

INSERT INTO `AS_GAM_R_COUNTRY` (`COUNTRY_NAME`,`COUNTRY_CODE`,`SAM_GOV_CODE`, `IS_ACTIVE`) VALUES ( "Aland Islands",'ALA','ALA','1');
INSERT INTO `AS_GAM_R_COUNTRY` (`COUNTRY_NAME`,`COUNTRY_CODE`,`SAM_GOV_CODE`, `IS_ACTIVE`) VALUES ( "Bonaire, Sint Eustatius, And Saba",'BES','BES','1');
INSERT INTO `AS_GAM_R_COUNTRY` (`COUNTRY_NAME`,`COUNTRY_CODE`,`SAM_GOV_CODE`, `IS_ACTIVE`) VALUES ( "Burma",'MMR','MMR','1');
INSERT INTO `AS_GAM_R_COUNTRY` (`COUNTRY_NAME`,`COUNTRY_CODE`,`SAM_GOV_CODE`, `IS_ACTIVE`) VALUES ( "Cabo Verde",'CPV','CPV','1');
INSERT INTO `AS_GAM_R_COUNTRY` (`COUNTRY_NAME`,`COUNTRY_CODE`,`SAM_GOV_CODE`, `IS_ACTIVE`) VALUES ( "Congo (Kinshasa)",'COD','COD','1');
INSERT INTO `AS_GAM_R_COUNTRY` (`COUNTRY_NAME`,`COUNTRY_CODE`,`SAM_GOV_CODE`, `IS_ACTIVE`) VALUES ( "Cote D’Ivoire",'CIV','CIV','1');
INSERT INTO `AS_GAM_R_COUNTRY` (`COUNTRY_NAME`,`COUNTRY_CODE`,`SAM_GOV_CODE`, `IS_ACTIVE`) VALUES ( "Curacao",'CUW','CUW','1');
INSERT INTO `AS_GAM_R_COUNTRY` (`COUNTRY_NAME`,`COUNTRY_CODE`,`SAM_GOV_CODE`, `IS_ACTIVE`) VALUES ( "Saint Barthelemy",'BLM','BLM','1');
INSERT INTO `AS_GAM_R_COUNTRY` (`COUNTRY_NAME`,`COUNTRY_CODE`,`SAM_GOV_CODE`, `IS_ACTIVE`) VALUES ( "Saint Helena, Ascension, And Tristan Da Cunha",'SHN','SHN','1');
INSERT INTO `AS_GAM_R_COUNTRY` (`COUNTRY_NAME`,`COUNTRY_CODE`,`SAM_GOV_CODE`, `IS_ACTIVE`) VALUES ( "Saint Martin",'MAF','MAF','1');
INSERT INTO `AS_GAM_R_COUNTRY` (`COUNTRY_NAME`,`COUNTRY_CODE`,`SAM_GOV_CODE`, `IS_ACTIVE`) VALUES ( "Saint Pierre And Miquelon",'SPM','SPM','1');
INSERT INTO `AS_GAM_R_COUNTRY` (`COUNTRY_NAME`,`COUNTRY_CODE`,`SAM_GOV_CODE`, `IS_ACTIVE`) VALUES ( "Sint Maarten",'SXM','SXM','1');
INSERT INTO `AS_GAM_R_COUNTRY` (`COUNTRY_NAME`,`COUNTRY_CODE`,`SAM_GOV_CODE`, `IS_ACTIVE`) VALUES ( "Timor-Leste",'TLS','TLS','1');
INSERT INTO `AS_GAM_R_COUNTRY` (`COUNTRY_NAME`,`COUNTRY_CODE`,`SAM_GOV_CODE`, `IS_ACTIVE`) VALUES ( "United States Minor Outlying Islands",'UMI','UMI','1');

-- END SCRIPT CONTENT ---
 
CALL AS_GAM_Update_Execution(@AS_GAM_scriptExecuteId, 9, 565, 959);
END IF;
END $$
DELIMITER ;

CALL AS_GAM_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;


-- *****************************************
-- [566] Insert into BUSINESS_TYPE
-- *****************************************
-- Insert reference data for BUSINESS_TYPE
-- *****************************************

DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GAM_RunFrameworkScript()
BEGIN
CALL AS_GAM_Initial_Execution("N",9, "Award Management 1.1 / Clause Automation 1.0 / Contract Writing 1.0 / Management Suite 1.0 / ProcureSight v1.0 / Requirements Management 1.2 / Source Selection 1.0 / Vendor Management 1.0", 566, "Insert into BUSINESS_TYPE",960,  @AS_GAM_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GAM_R_BUSINESS_TYPE` (`CODE`, `DESCRIPTION`, `IS_ACTIVE`) VALUES
('05', 'Alaskan Native Corporation Owned Firm', 1),
('12', 'U.S. Local Government', 1),
('1A', 'Minority Institution', 1),
('1B', 'Tribally Owned Firm', 1),
('1D', 'Small Agricultural Cooperative', 1),
('1R', 'Private University or College', 1),
('20', 'Foreign Owned', 1),
('23', 'Minority Owned Business', 1),
('27', 'Self Certified Small Disadvantaged Business', 1),
('2A', 'U.S. Government Entity', 1),
('2F', 'U.S. State Government', 1),
('2J', 'Sole Proprietorship', 1),
('2K', 'Partnership or Limited Liability Partnership', 1),
('2L', 'Corporate Entity (Not Tax Exempt)', 1),
('2R', 'U.S Federal Government', 1),
('2U', 'Other Not For Profit Organization', 1),
('2X', 'For Profit Organization', 1),
('3I', 'Tribal Government', 1),
('6D', 'Domestic Shelter', 1),
('80', 'Hospital', 1),
('86', 'Interstate Entity', 1),
('8B', 'Housing Authorities Public/Tribal', 1),
('8C', 'Joint Venture Women Owned Small Business', 1),
('8D', 'Joint Venture Economically Disadvantaged Women Small Owned Business', 1),
('8E', 'Economically Disadvantaged Women Small Owned Business', 1),
('8H', 'Corporate Entity (Tax Exempt)', 1),
('8U', 'Native Hawaiian Organization Owned Firm', 1),
('8W', 'Woman Owned Small Business', 1),
('A2', 'Woman Owned Business', 1),
('A3', 'Labor Surplus Area Firm', 1),
('A4', 'SBA Certified Small Disadvantaged Business', 1),
('A5', 'Veteran Owned Business', 1),
('A6', 'SBA Certified 8(a) Program Participant', 1),
('A7', 'AbilityOne Non Profit Agency', 1),
('A8', 'Non-Profit Organization', 1),
('BZ', 'Foundation', 1),
('C6', 'Municipality', 1),
('C7', 'County', 1),
('C8', 'City', 1),
('CY', 'Country - Foreign Government', 1),
('F', 'Business or Organization', 1),
('FO', 'Township', 1),
('FR', 'Asian-Pacific American Owned', 1),
('FY', 'Veterinary Hospital', 1),
('G3', 'Alaskan Native Servicing Institution', 1),
('G5', 'Native Hawaiian Servicing Institution', 1),
('G6', '1862 Land Grant College', 1),
('G7', '1890 Land Grant College', 1),
('G8', '1994 Land Grant College', 1),
('G9', 'Other Than One of the Proceeding', 1),
('GW', 'Hispanic Servicing Institution', 1),
('H2', 'Community Development Corporation', 1),
('H6', 'School District', 1),
('HB', 'Historically Black College or University', 1),
('HK', 'Community Development Corporation Owned Firm', 1),
('HQ', 'DOT Certified DBE', 1),
('HS', 'Tribal College', 1),
('JT', 'SBA Certified 8(a) Joint Venture', 1),
('JX', 'Self Certified HUBZone Joint Venture', 1),
('KM', 'Planning Commission', 1),
('LJ', 'Limited Liability Company', 1),
('M8', 'Educational Institution', 1),
('MF', 'Manufacturer of Goods', 1),
('MG', 'Local Government Owned', 1),
('NB', 'Native American Owned', 1),
('NG', 'Federal Agency', 1),
('OH', 'State Controlled Institution of Higher Learning', 1),
('OW', 'American Indian Owned', 1),
('OY', 'Black American Owned', 1),
('PI', 'Hispanic American Owned', 1),
('QF', 'Service Disabled Veteran Owned Business', 1),
('QU', 'Veterinary College', 1),
('QW', 'Federally Funded Research and Development Corp', 1),
('QZ', 'Subcontinent Asian (Asian-Indian) American Owned', 1),
('S4', 'Buyer', 1),
('S5', 'Seller', 1),
('S6', 'Buyer & Seller', 1),
('T4', 'Port Authority', 1),
('TR', 'Airport Authority', 1),
('TW', 'Transit Authority', 1),
('UD', 'Council of Governments', 1),
('X6', 'International Organization', 1),
('XS', 'Subchapter S Corporation', 1),
('XX', 'SBA Certified HUBZone Firm', 1),
('XY', 'Indian Tribe (Federally Recognized)', 1),
('Z1', 'Federal Assistance Awards', 1),
('Z2', 'All Awards', 1),
('Z3', 'IGT Only', 1),
('Z4', 'Federal Assistance Awards & IGT', 1),
('Z5', 'All Awards and IGT', 1),
('ZR', 'Inter-municipal', 1),
('ZW', 'School of Forestry', 1),
('ZZ', 'Other', 1);

-- END SCRIPT CONTENT ---
 
CALL AS_GAM_Update_Execution(@AS_GAM_scriptExecuteId, 9, 566, 960);
END IF;
END $$
DELIMITER ;

CALL AS_GAM_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;





-- **********************
-- Source Selection 1.0
-- **********************


-- **********************************
-- [567] Create Baseline GSS Tables
-- **********************************
-- Create the baseline GSS tables
-- **********************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 567, "Create Baseline GSS Tables",2237,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

--
-- Table structure for table `AS_GSS_A_R_CRITERIA`
--

CREATE TABLE `AS_GSS_A_R_CRITERIA` (
  `CRITERIA_AUDIT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `EVALUATION_AUDIT_ID` int(11) DEFAULT NULL,
  `CRITERIA_ID` int(11) DEFAULT NULL,
  `TIMESTAMP` datetime DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL,
  `AUDIT_ACTION_CODE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_A_R_CRITERIA_ASSIGNMENTS`
--

CREATE TABLE `AS_GSS_A_R_CRITERIA_ASSIGNMENTS` (
  `ASSIGNMENT_AUDIT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `CRITERIA_AUDIT_ID` int(11) DEFAULT NULL,
  `ASSIGNMENT_ID` int(11) DEFAULT NULL,
  `TIMESTAMP` datetime DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL,
  `AUDIT_ACTION_CODE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_A_R_CRITERIA_ASSIGNMENTS_FIELD`
--

CREATE TABLE `AS_GSS_A_R_CRITERIA_ASSIGNMENTS_FIELD` (
  `ASSIGNMENT_AUDIT_FIELD_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `ASSIGNMENT_AUDIT_ID` int(11) DEFAULT NULL,
  `FIELD_NAME` varchar(255) DEFAULT NULL,
  `OLD_VALUE` varchar(4000) DEFAULT NULL,
  `NEW_VALUE` varchar(4000) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_A_R_CRITERIA_FIELD`
--

CREATE TABLE `AS_GSS_A_R_CRITERIA_FIELD` (
  `CRITERIA_AUDIT_FIELD_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `CRITERIA_AUDIT_ID` int(11) DEFAULT NULL,
  `FIELD_NAME` varchar(255) DEFAULT NULL,
  `OLD_VALUE` varchar(4000) DEFAULT NULL,
  `NEW_VALUE` varchar(4000) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_A_R_EVALUATION`
--

CREATE TABLE `AS_GSS_A_R_EVALUATION` (
  `EVALUATION_AUDIT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `EVALUATION_ID` int(11) DEFAULT NULL,
  `TIMESTAMP` datetime DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL,
  `AUDIT_ACTION_CODE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_A_R_EVALUATION_DOCUMENT`
--

CREATE TABLE `AS_GSS_A_R_EVALUATION_DOCUMENT` (
  `EVALUATION_DOCUMENT_AUDIT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `EVALUATION_AUDIT_ID` int(11) DEFAULT NULL,
  `EVALUATION_ID` int(11) DEFAULT NULL,
  `TIMESTAMP` datetime DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL,
  `AUDIT_ACTION_CODE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_A_R_EVALUATION_DOCUMENT_FIELD`
--

CREATE TABLE `AS_GSS_A_R_EVALUATION_DOCUMENT_FIELD` (
  `EVALUATION_DOC_AUDIT_FIELD_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `EVALUATION_DOCUMENT_AUDIT_ID` int(11) DEFAULT NULL,
  `FIELD_NAME` varchar(255) DEFAULT NULL,
  `OLD_VALUE` varchar(4000) DEFAULT NULL,
  `NEW_VALUE` varchar(4000) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_A_R_EVALUATION_FIELD`
--

CREATE TABLE `AS_GSS_A_R_EVALUATION_FIELD` (
  `EVALUATION_AUDIT_FIELD_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `EVALUATION_AUDIT_ID` int(11) DEFAULT NULL,
  `FIELD_NAME` varchar(255) DEFAULT NULL,
  `OLD_VALUE` varchar(4000) DEFAULT NULL,
  `NEW_VALUE` varchar(4000) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_A_R_EVALUATION_PHASE`
--

CREATE TABLE `AS_GSS_A_R_EVALUATION_PHASE` (
  `EVALUATION_PHASE_AUDIT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `EVALUATION_AUDIT_ID` int(11) DEFAULT NULL,
  `EVALUATION_PHASE_ID` int(11) DEFAULT NULL,
  `TIMESTAMP` datetime DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL,
  `AUDIT_ACTION_CODE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_A_R_EVALUATION_PHASE_FIELD`
--

CREATE TABLE `AS_GSS_A_R_EVALUATION_PHASE_FIELD` (
  `EVALUATION_PHASE_AUDIT_FIELD_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `EVALUATION_PHASE_AUDIT_ID` int(11) DEFAULT NULL,
  `FIELD_NAME` varchar(255) DEFAULT NULL,
  `OLD_VALUE` varchar(4000) DEFAULT NULL,
  `NEW_VALUE` varchar(4000) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_A_R_EVALUATION_VENDOR`
--

CREATE TABLE `AS_GSS_A_R_EVALUATION_VENDOR` (
  `VENDOR_AUDIT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `EVALUATION_AUDIT_ID` int(11) DEFAULT NULL,
  `VENDOR_ID` int(11) DEFAULT NULL,
  `TIMESTAMP` datetime DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL,
  `AUDIT_ACTION_CODE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_A_R_EVALUATION_VENDOR_BUSINESS_TYPE`
--

CREATE TABLE `AS_GSS_A_R_EVALUATION_VENDOR_BUSINESS_TYPE` (
  `BUSINESS_TYPE_AUDIT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `VENDOR_AUDIT_ID` int(11) DEFAULT NULL,
  `BUSINESS_TYPE_ID` int(11) DEFAULT NULL,
  `TIMESTAMP` datetime DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL,
  `AUDIT_ACTION_CODE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_A_R_EVALUATION_VENDOR_BUSINESS_TYPE_FIELD`
--

CREATE TABLE `AS_GSS_A_R_EVALUATION_VENDOR_BUSINESS_TYPE_FIELD` (
  `BUSINESS_TYPE_AUDIT_FIELD_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `BUSINESS_TYPE_AUDIT_ID` int(11) DEFAULT NULL,
  `FIELD_NAME` varchar(255) DEFAULT NULL,
  `OLD_VALUE` varchar(4000) DEFAULT NULL,
  `NEW_VALUE` varchar(4000) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_A_R_EVALUATION_VENDOR_FIELD`
--

CREATE TABLE `AS_GSS_A_R_EVALUATION_VENDOR_FIELD` (
  `VENDOR_AUDIT_FIELD_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `VENDOR_AUDIT_ID` int(11) DEFAULT NULL,
  `FIELD_NAME` varchar(255) DEFAULT NULL,
  `OLD_VALUE` varchar(4000) DEFAULT NULL,
  `NEW_VALUE` varchar(4000) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_A_R_EVALUATOR_TEAM`
--

CREATE TABLE `AS_GSS_A_R_EVALUATOR_TEAM` (
  `TEAM_AUDIT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `EVALUATION_AUDIT_ID` int(11) DEFAULT NULL,
  `TEAM_ID` int(11) DEFAULT NULL,
  `TIMESTAMP` datetime DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL,
  `AUDIT_ACTION_CODE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_A_R_EVALUATOR_TEAM_FIELD`
--

CREATE TABLE `AS_GSS_A_R_EVALUATOR_TEAM_FIELD` (
  `TEAM_AUDIT_FIELD_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TEAM_AUDIT_ID` int(11) DEFAULT NULL,
  `FIELD_NAME` varchar(255) DEFAULT NULL,
  `OLD_VALUE` varchar(4000) DEFAULT NULL,
  `NEW_VALUE` varchar(4000) DEFAULT NULL,
  `EVAL_TEAM_AUDIT_ID` int(11) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_A_R_TEAM_MEMBERSHIP`
--

CREATE TABLE `AS_GSS_A_R_TEAM_MEMBERSHIP` (
  `TEAM_MEMBERSHIP_AUDIT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TEAM_AUDIT_ID` int(11) DEFAULT NULL,
  `TEAM_MEMBERSHIP_ID` int(11) DEFAULT NULL,
  `TIMESTAMP` datetime DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL,
  `AUDIT_ACTION_CODE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_A_R_TEAM_MEMBERSHIP_FIELD`
--

CREATE TABLE `AS_GSS_A_R_TEAM_MEMBERSHIP_FIELD` (
  `TEAM_MEMBERSHIP_AUDIT_FIELD_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TEAM_MEMBERSHIP_AUDIT_ID` int(11) DEFAULT NULL,
  `FIELD_NAME` varchar(255) DEFAULT NULL,
  `OLD_VALUE` varchar(4000) DEFAULT NULL,
  `NEW_VALUE` varchar(4000) DEFAULT NULL,
  `TEAM_MEMBERSHIP_ID` int(11) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_CRITERIA`
--

CREATE TABLE `AS_GSS_CRITERIA` (
  `CRITERIA_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `EVALUATION_ID` int(11) DEFAULT NULL,
  `PARENT_CRITERIA_ID` int(11) DEFAULT NULL,
  `FACTOR_NUMBER` varchar(255) DEFAULT NULL,
  `CRITERIA_NAME` varchar(255) DEFAULT NULL,
  `CRITERIA_DESCRIPTION` varchar(5000) DEFAULT NULL,
  `CRITERIA_CHAIR` varchar(255) DEFAULT NULL,
  `DUE_DATE` date DEFAULT NULL,
  `RANKING_METHOD_ID` int(11) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL,
  `CRITERIA_STATUS_ID` int(11) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_CRITERIA_ASSIGNMENTS`
--

CREATE TABLE `AS_GSS_CRITERIA_ASSIGNMENTS` (
  `ASSIGNMENT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `CRITERIA_ID` int(11) DEFAULT NULL,
  `ASSIGNED_TEAM_ID` int(11) DEFAULT NULL,
  `ASSIGNEE` varchar(255) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_EVALUATION`
--

CREATE TABLE `AS_GSS_EVALUATION` (
  `EVALUATION_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `EVALUATION_NUMBER` varchar(25) DEFAULT NULL,
  `EVALUATION_TITLE` varchar(255) DEFAULT NULL,
  `EVALUATION_DESCRIPTION` varchar(5000) DEFAULT NULL,
  `SOLICITATION_DESCRIPTION` varchar(5000) DEFAULT NULL,
  `SOLICITATION_DATE` date DEFAULT NULL,
  `EVALUATION_START_DATE` date DEFAULT NULL,
  `EVALUATION_DUE_DATE` date DEFAULT NULL,
  `EVALUATION_COMPLETION_DATE` date DEFAULT NULL,
  `EVALUATION_STATUS_ID` int(11) DEFAULT NULL,
  `EVALUATION_METHOD_ID` int(11) DEFAULT NULL,
  `EVALUATION_CHIEF` varchar(255) DEFAULT NULL,
  `FOLDER_ID` int(11) DEFAULT NULL,
  `OFFICE365_FOLDER_ID` varchar(255) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_EVALUATION_DOCUMENT`
--

CREATE TABLE `AS_GSS_EVALUATION_DOCUMENT` (
  `EVAL_DOCUMENT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `APPIAN_DOC_ID` int(11) DEFAULT NULL,
  `EVALUATION_ID` int(11) DEFAULT NULL,
  `CRITERIA_ID` int(11) DEFAULT NULL,
  `VENDOR_ID` int(11) DEFAULT NULL,
  `DOCUMENT_NAME` varchar(255) DEFAULT NULL,
  `DOCUMENT_DESCRIPTION` varchar(255) DEFAULT NULL,
  `FILE_TYPE` varchar(255) DEFAULT NULL,
  `DOC_TYPE` int(11) DEFAULT NULL,
  `DOCUMENT_TEMPLATE` int(11) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_DELETED` tinyint(1) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_EVALUATION_PHASE`
--

CREATE TABLE `AS_GSS_EVALUATION_PHASE` (
  `EVALUATION_PHASE_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `PHASE_NAME` varchar(255) DEFAULT NULL,
  `EVALUATION_ID` int(11) DEFAULT NULL,
  `DURATION` varchar(255) DEFAULT NULL,
  `DURATION_UNIT` int(11) DEFAULT NULL,
  `START_DATE` date DEFAULT NULL,
  `END_DATE` date DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_EVALUATION_VENDOR`
--

CREATE TABLE `AS_GSS_EVALUATION_VENDOR` (
  `VENDOR_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `VENDOR_REF_ID` int(11) DEFAULT NULL,
  `EVALUATION_ID` int(11) DEFAULT NULL,
  `SUBMITTED_DATE` date DEFAULT NULL,
  `LEGAL_NAME` varchar(255) DEFAULT NULL,
  `BUSINESS_NAME` varchar(255) DEFAULT NULL,
  `VENDOR_ADDRESS_LINE1` varchar(255) DEFAULT NULL,
  `VENDOR_ADDRESS_LINE2` varchar(255) DEFAULT NULL,
  `VENDOR_CITY` varchar(255) DEFAULT NULL,
  `VENDOR_STATE` int(11) DEFAULT NULL,
  `VENDOR_COUNTRY` int(11) DEFAULT NULL,
  `VENDOR_ZIP_CODE` varchar(255) DEFAULT NULL,
  `VENDOR_ZIP_CODE_EXT` varchar(255) DEFAULT NULL,
  `VENDOR_FOREIGN_POSTAL_CODE` varchar(255) DEFAULT NULL,
  `DUNS` varchar(255) DEFAULT NULL,
  `CAGE_CODE` varchar(255) DEFAULT NULL,
  `UNIQUE_ENTITY_ID` varchar(255) DEFAULT NULL,
  `STATUS` varchar(255) DEFAULT NULL,
  `EXPIRATION_DATE` date DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_EVALUATION_VENDOR_BUSINESS_TYPE`
--

CREATE TABLE `AS_GSS_EVALUATION_VENDOR_BUSINESS_TYPE` (
  `BUSINESS_TYPE_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `VENDOR_ID` int(11) DEFAULT NULL,
  `TYPE_CODE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_EVALUATOR_TEAM`
--

CREATE TABLE `AS_GSS_EVALUATOR_TEAM` (
  `TEAM_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `EVALUATION_ID` int(11) DEFAULT NULL,
  `TEAM_NAME` varchar(255) DEFAULT NULL,
  `TEAM_DESCRIPTION` varchar(1000) DEFAULT NULL,
  `ASSIGNEE` varchar(255) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_R_DATA`
--

CREATE TABLE `AS_GSS_R_DATA` (
  `REF_DATA_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `REF_LABEL` varchar(255) DEFAULT NULL,
  `REF_DESCRIPTION` varchar(1000) DEFAULT NULL,
  `REF_TYPE` varchar(255) DEFAULT NULL,
  `REF_ICON` varchar(255) DEFAULT NULL,
  `REF_COLOR` varchar(255) DEFAULT NULL,
  `SORT_ORDER` int(11) DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_R_DOCUMENT_TEMPLATE`
--

CREATE TABLE `AS_GSS_R_DOCUMENT_TEMPLATE` (
  `DOCUMENT_TEMPLATE_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `DOCUMENT_NAME` varchar(255) DEFAULT NULL,
  `FILE_TYPE` varchar(255) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_R_VENDOR`
--

CREATE TABLE `AS_GSS_R_VENDOR` (
  `VENDOR_REF_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `LEGAL_NAME` varchar(255) DEFAULT NULL,
  `BUSINESS_NAME` varchar(255) DEFAULT NULL,
  `VENDOR_ADDRESS_LINE1` varchar(255) DEFAULT NULL,
  `VENDOR_ADDRESS_LINE2` varchar(255) DEFAULT NULL,
  `VENDOR_CITY` varchar(255) DEFAULT NULL,
  `VENDOR_STATE` int(11) DEFAULT NULL,
  `VENDOR_COUNTRY` int(11) DEFAULT NULL,
  `VENDOR_ZIP_CODE` varchar(255) DEFAULT NULL,
  `VENDOR_ZIP_CODE_EXT` varchar(255) DEFAULT NULL,
  `VENDOR_FOREIGN_POSTAL_CODE` varchar(255) DEFAULT NULL,
  `DUNS` varchar(255) DEFAULT NULL,
  `CAGE_CODE` varchar(255) DEFAULT NULL,
  `UNIQUE_ENTITY_ID` varchar(255) DEFAULT NULL,
  `STATUS` varchar(255) DEFAULT NULL,
  `EXPIRATION_DATE` date DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_R_VENDOR_BUSINESS_TYPE`
--

CREATE TABLE `AS_GSS_R_VENDOR_BUSINESS_TYPE` (
  `BUSINESS_REF_TYPE_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `VENDOR_REF_ID` int(11) DEFAULT NULL,
  `TYPE_CODE` varchar(255) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TEAM_MEMBERSHIP`
--

CREATE TABLE `AS_GSS_TEAM_MEMBERSHIP` (
  `TEAM_MEMBERSHIP_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TEAM_ID` int(11) DEFAULT NULL,
  `MEMBER` varchar(255) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_A_R_TASK_CATEGORY`
--

CREATE TABLE `AS_GSS_TMG_A_R_TASK_CATEGORY` (
  `TASK_CATEGORY_AUDIT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TASK_CATEGORY_ID` int(11) DEFAULT NULL,
  `TIMESTAMP` datetime DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL,
  `AUDIT_ACTION_CODE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_A_R_TASK_CATEGORY_FIELD`
--

CREATE TABLE `AS_GSS_TMG_A_R_TASK_CATEGORY_FIELD` (
  `TASK_CATEGORY_AUDIT_FIELD_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TASK_CATEGORY_AUDIT_ID` int(11) DEFAULT NULL,
  `FIELD_NAME` varchar(255) DEFAULT NULL,
  `OLD_VALUE` varchar(255) DEFAULT NULL,
  `NEW_VALUE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_A_R_TASK_REF`
--

CREATE TABLE `AS_GSS_TMG_A_R_TASK_REF` (
  `TASK_REF_AUDIT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TASK_REF_ID` int(11) DEFAULT NULL,
  `TIMESTAMP` datetime DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL,
  `AUDIT_ACTION_CODE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_A_R_TASK_REF_FIELD`
--

CREATE TABLE `AS_GSS_TMG_A_R_TASK_REF_FIELD` (
  `TASK_REF_AUDIT_FIELD_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TASK_REF_AUDIT_ID` int(11) DEFAULT NULL,
  `FIELD_NAME` varchar(255) DEFAULT NULL,
  `OLD_VALUE` varchar(255) DEFAULT NULL,
  `NEW_VALUE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_A_R_TEMPLATE`
--

CREATE TABLE `AS_GSS_TMG_A_R_TEMPLATE` (
  `TEMPLATE_AUDIT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TEMPLATE_ID` int(11) DEFAULT NULL,
  `TIMESTAMP` datetime DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL,
  `AUDIT_ACTION_CODE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_A_R_TEMPLATE_FIELD`
--

CREATE TABLE `AS_GSS_TMG_A_R_TEMPLATE_FIELD` (
  `TEMPLATE_AUDIT_FIELD_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TEMPLATE_AUDIT_ID` int(11) DEFAULT NULL,
  `FIELD_NAME` varchar(255) DEFAULT NULL,
  `OLD_VALUE` varchar(255) DEFAULT NULL,
  `NEW_VALUE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_A_R_TEMPLATE_TASK`
--

CREATE TABLE `AS_GSS_TMG_A_R_TEMPLATE_TASK` (
  `TEMPLATE_TASK_AUDIT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TEMPLATE_AUDIT_ID` int(11) DEFAULT NULL,
  `TEMPLATE_TASK_ID` int(11) DEFAULT NULL,
  `TIMESTAMP` datetime DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL,
  `AUDIT_ACTION_CODE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_A_R_TEMPLATE_TASK_FIELD`
--

CREATE TABLE `AS_GSS_TMG_A_R_TEMPLATE_TASK_FIELD` (
  `TEMPLATE_TASK_AUDIT_FIELD_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TEMPLATE_TASK_AUDIT_ID` int(11) DEFAULT NULL,
  `FIELD_NAME` varchar(255) DEFAULT NULL,
  `OLD_VALUE` varchar(255) DEFAULT NULL,
  `NEW_VALUE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC`
--

CREATE TABLE `AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC` (
  `TEMPLATE_TASK_PREC_AUDIT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TEMPLATE_TASK_AUDIT_ID` int(11) DEFAULT NULL,
  `TEMPLATE_TASK_PRECEDENT_ID` int(11) DEFAULT NULL,
  `TIMESTAMP` datetime DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL,
  `AUDIT_ACTION_CODE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC_F`
--

CREATE TABLE `AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC_F` (
  `TEMP_TASK_PREC_ADT_FLD_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TEMPLATE_TASK_PREC_AUDIT_ID` int(11) DEFAULT NULL,
  `FIELD_NAME` varchar(255) DEFAULT NULL,
  `OLD_VALUE` varchar(255) DEFAULT NULL,
  `NEW_VALUE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_A_TASK_PROCESS_SETUP`
--

CREATE TABLE `AS_GSS_TMG_A_TASK_PROCESS_SETUP` (
  `TASK_PROC_SETUP_AUDIT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TEMPLATE_PROC_SETUP_AUDIT_ID` int(11) DEFAULT NULL,
  `TASK_REF_ID` int(11) DEFAULT NULL,
  `TASK_ID` int(11) DEFAULT NULL,
  `TIME_STAMP` datetime DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL,
  `AUDIT_ACTION_CODE` varchar(255) DEFAULT NULL,
  `TEMPLATE_ID` int(11) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_A_TASK_PROCESS_SETUP_FIELD`
--

CREATE TABLE `AS_GSS_TMG_A_TASK_PROCESS_SETUP_FIELD` (
  `TASK_PROC_SETUP_AUDIT_FIELD_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TASK_PROC_SETUP_AUDIT_ID` int(11) DEFAULT NULL,
  `FIELD_NAME` varchar(255) DEFAULT NULL,
  `OLD_VALUE` varchar(255) DEFAULT NULL,
  `NEW_VALUE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_A_TEMPLATE_PROCESS_SETUP`
--

CREATE TABLE `AS_GSS_TMG_A_TEMPLATE_PROCESS_SETUP` (
  `TEMPLATE_PROC_SETUP_AUDIT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TASK_ID_PROCESS_SETUP` int(11) DEFAULT NULL,
  `ORIGINAL_TEMPLATE_ID` int(11) DEFAULT NULL,
  `NEW_TEMPLATE_ID` int(11) DEFAULT NULL,
  `TIME_STAMP` datetime DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL,
  `TEMPLATE_AUDIT_ACTION_CODE` varchar(255) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_R_TASK_ACTION`
--

CREATE TABLE `AS_GSS_TMG_R_TASK_ACTION` (
  `TASK_ACTION_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `ACTION_DISPLAY_NAME` varchar(255) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE`
--

CREATE TABLE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE` (
  `TASK_BEHAVIOR_TYPE_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `BEHAVIOR_TYPE_CODE` varchar(255) DEFAULT NULL,
  `BEHAVIOR_DISPLAY_NAME` varchar(255) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `BEHAVIOR_SUBTYPE_CODE` varchar(255) DEFAULT NULL,
  `CONFIGURATION_LEVEL_CODE` varchar(255) DEFAULT NULL,
  `ICON` varchar(50) DEFAULT NULL,
  `COLOR` varchar(50) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_R_TASK_CATEGORY`
--

CREATE TABLE `AS_GSS_TMG_R_TASK_CATEGORY` (
  `TASK_CATEGORY_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `CATEGORY_NAME` varchar(255) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_R_TASK_REF`
--

CREATE TABLE `AS_GSS_TMG_R_TASK_REF` (
  `TASK_REF_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TASK_NAME` varchar(255) NOT NULL,
  `TASK_BEHAVIOR_TYPE_ID` int(11) DEFAULT NULL,
  `TASK_CATEGORY_ID` int(11) DEFAULT NULL,
  `DEFAULT_GROUP_ASSIGNEE` int(11) DEFAULT NULL,
  `TASK_REF_DOC_UPLOAD_ID` int(11) DEFAULT NULL,
  `CREATED_BY` varchar(255) NOT NULL,
  `CREATED_DATETIME` datetime NOT NULL,
  `MODIFIED_BY` varchar(255) NOT NULL,
  `MODIFIED_DATETIME` datetime NOT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_R_TASK_REF_DOC_UPLOAD`
--

CREATE TABLE `AS_GSS_TMG_R_TASK_REF_DOC_UPLOAD` (
  `TASK_REF_DOC_UPLOAD_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `DOC_EXTENSION` varchar(255) DEFAULT NULL,
  `DOC_DESCRIPTION` varchar(255) DEFAULT NULL,
  `DOC_TYPE_ID` int(11) DEFAULT NULL,
  `DOC_TEMPLATE` int(11) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_R_TASK_STATUS`
--

CREATE TABLE `AS_GSS_TMG_R_TASK_STATUS` (
  `TASK_STATUS_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `STATUS_DISPLAY_NAME` varchar(255) DEFAULT NULL,
  `ICON` varchar(255) DEFAULT NULL,
  `COLOR` varchar(255) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_R_TEMPLATE`
--

CREATE TABLE `AS_GSS_TMG_R_TEMPLATE` (
  `TEMPLATE_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TEMPLATE_NAME` varchar(255) NOT NULL,
  `TEMPLATE_TYPE` int(11) DEFAULT NULL,
  `TEMPLATE_DESC` varchar(255) DEFAULT NULL,
  `DOC_TEMPLATE` int(11) DEFAULT NULL,
  `OPERATION` int(11) DEFAULT NULL,
  `THRESHOLD_AMOUNT` double DEFAULT NULL,
  `CREATED_BY` varchar(255) NOT NULL,
  `CREATED_DATETIME` datetime NOT NULL,
  `MODIFIED_BY` varchar(255) NOT NULL,
  `MODIFIED_DATETIME` datetime NOT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_R_TEMPLATE_TASK`
--

CREATE TABLE `AS_GSS_TMG_R_TEMPLATE_TASK` (
  `TEMPLATE_TASK_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TEMPLATE_ID` int(11) DEFAULT NULL,
  `TASK_REF_ID` int(11) DEFAULT NULL,
  `GROUP_ASSIGNEE` int(11) DEFAULT NULL,
  `TASK_DESC` varchar(255) DEFAULT NULL,
  `DURATION` varchar(255) NOT NULL,
  `DURATION_UNIT` int(11) DEFAULT NULL,
  `NO_OF_DAYS_FROM_START` int(11) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_R_TEMPLATE_TASK_PRECEDNT`
--

CREATE TABLE `AS_GSS_TMG_R_TEMPLATE_TASK_PRECEDNT` (
  `TEMPLATE_TASK_PRECEDENT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TEMPLATE_TASK_ID` int(11) DEFAULT NULL,
  `TASK_REF_ID_PRECEDENT` int(11) DEFAULT NULL,
  `GROUP_ID_PRECEDENT` int(11) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_TASK`
--

CREATE TABLE `AS_GSS_TMG_TASK` (
  `TASK_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `EVALUATION_ID` int(11) DEFAULT NULL,
  `TASK_REF_ID` int(11) DEFAULT NULL,
  `TASK_NAME` varchar(255) NOT NULL,
  `TASK_DESC` varchar(255) NOT NULL,
  `TASK_BEHAVIOR_TYPE_ID` int(11) DEFAULT NULL,
  `TASK_CATEGORY_ID` int(11) DEFAULT NULL,
  `REVIEW_DOCUMENT_ID` int(11) DEFAULT NULL,
  `GROUP_ASSIGNEE` int(11) DEFAULT NULL,
  `USER_ASSIGNEE` varchar(255) DEFAULT NULL,
  `TASK_STATUS_ID` int(11) DEFAULT NULL,
  `CHECKLIST_ID` int(11) DEFAULT NULL,
  `TASK_DOC_UPLOAD_ID` int(11) DEFAULT NULL,
  `TASK_REVIEW_ID` int(11) DEFAULT NULL,
  `AVAILABLE_DATETIME` datetime DEFAULT NULL,
  `DUE_DATE` date DEFAULT NULL,
  `DURATION` varchar(255) DEFAULT NULL,
  `DURATION_UNIT` int(11) DEFAULT NULL,
  `NO_OF_DAYS_FROM_START` int(11) DEFAULT NULL,
  `COMPLETED_BY` varchar(255) DEFAULT NULL,
  `COMPLETION_DATE` date DEFAULT NULL,
  `COMPLETED_DATETIME` datetime DEFAULT NULL,
  `REVIEW_COMMENT_ID` int(11) DEFAULT NULL,
  `CREATED_BY` varchar(255) NOT NULL,
  `CREATED_DATETIME` datetime NOT NULL,
  `MODIFIED_BY` varchar(255) NOT NULL,
  `MODIFIED_DATETIME` datetime NOT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_TASK_ACTION_AUDIT`
--

CREATE TABLE `AS_GSS_TMG_TASK_ACTION_AUDIT` (
  `TASK_ACTION_AUDIT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TASK_ID` int(11) DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL,
  `TIMESTAMP` datetime DEFAULT NULL,
  `ASSIGNED_TO` varchar(4000) DEFAULT NULL,
  `TASK_REVIEW_ID` int(11) DEFAULT NULL,
  `TASK_ACTION_ID` int(11) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_TASK_CHECKLIST`
--

CREATE TABLE `AS_GSS_TMG_TASK_CHECKLIST` (
  `CHECKLIST_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TEMPLATE_ID` int(11) DEFAULT NULL,
  `LIST_NAME` varchar(255) DEFAULT NULL,
  `LIST_DESC` varchar(255) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `LIST_TYPE` int(11) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_TASK_DOC_UPLOAD`
--

CREATE TABLE `AS_GSS_TMG_TASK_DOC_UPLOAD` (
  `TASK_DOC_UPLOAD_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `DOC_EXTENSION` varchar(255) DEFAULT NULL,
  `APPIAN_DOCUMENT_ID` int(11) DEFAULT NULL,
  `OFFICE_365_DOCUMENT_ID` varchar(255) DEFAULT NULL,
  `OFFICE_365_DOCUMENT_LINK` varchar(255) DEFAULT NULL,
  `DOC_DESCRIPTION` varchar(255) DEFAULT NULL,
  `DOC_TYPE_ID` int(11) DEFAULT NULL,
  `DOC_TEMPLATE` int(11) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_TASK_PRECEDENT`
--

CREATE TABLE `AS_GSS_TMG_TASK_PRECEDENT` (
  `TASK_PRECEDENT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TASK_ID` int(11) DEFAULT NULL,
  `TASK_ID_PRECEDENT` int(11) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_TASK_REVIEW`
--

CREATE TABLE `AS_GSS_TMG_TASK_REVIEW` (
  `TASK_REVIEW_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `COMMENT` varchar(255) DEFAULT NULL,
  `DECISION` int(11) DEFAULT NULL
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_TMG_TASK_SET`
--

CREATE TABLE `AS_GSS_TMG_TASK_SET` (
  `TASK_SET_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY
);

-- --------------------------------------------------------

--
-- Table structure for table `AS_GSS_USER`
--

CREATE TABLE `AS_GSS_USER` (
  `USERNAME` varchar(255) NOT NULL PRIMARY KEY,
  `FIRST_NAME` varchar(255) DEFAULT NULL,
  `LAST_NAME` varchar(255) DEFAULT NULL,
  `EMAIL` varchar(255) DEFAULT NULL,
  `PHONE_NUMBER` varchar(255) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL
);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 567, 2237);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************
-- [568] Insert Baseline GSS Tables
-- ****************************************
-- Insert the baseline GSS reference data
-- ****************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 568, "Insert Baseline GSS Tables",537,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

--
-- Dumping data for table `AS_GSS_R_DATA`
--

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES
(1, 'Setting up', NULL, 'Evaluation Status', 'gear', '#757575', 1, 1, 'appian.administrator', '2021-01-21 12:22:09', 'appian.administrator', '2021-01-21 12:22:09'),
(2, 'In progress', NULL, 'Evaluation Status', 'spinner', '#757575', 2, 1, 'appian.administrator', '2021-01-21 12:22:09', 'appian.administrator', '2021-01-21 12:22:09'),
(3, 'Complete', NULL, 'Evaluation Status', 'check-circle', 'POSITIVE', 3, 1, 'appian.administrator', '2021-01-21 12:22:09', 'appian.administrator', '2021-01-21 12:22:09'),
(4, 'Least Price Technically Acceptable', NULL, 'Evaluation Method', '', '', 1, 1, 'appian.administrator', '2021-01-21 12:22:09', 'appian.administrator', '2021-01-21 12:22:09'),
(5, 'Best Value', NULL, 'Evaluation Method', '', '', 2, 1, 'appian.administrator', '2021-01-21 12:22:09', 'appian.administrator', '2021-01-21 12:22:09'),
(6, 'Contracting', NULL, 'Template Type', '', '', NULL, 1, 'appian.administrator', '2021-01-26 12:22:09', 'appian.administrator', '2021-01-26 12:22:09'),
(7, 'Outstanding', NULL, 'Evaluation Checklist Status', NULL, NULL, NULL, 1, 'appian.administrator', '2021-01-26 12:22:09', 'appian.administrator', '2021-01-26 12:22:09'),
(8, 'Completed', NULL, 'Evaluation Checklist Status', NULL, NULL, NULL, 1, 'appian.administrator', '2021-01-26 12:22:09', 'appian.administrator', '2021-01-26 12:22:09'),
(9, 'Not Needed', NULL, 'Evaluation Checklist Status', NULL, NULL, NULL, 1, 'appian.administrator', '2021-01-26 12:22:09', 'appian.administrator', '2021-01-26 12:22:09'),
(10, 'Cancelled', NULL, 'Evaluation Checklist Status', NULL, NULL, NULL, 1, 'appian.administrator', '2021-01-26 12:22:09', 'appian.administrator', '2021-01-26 12:22:09'),
(11, 'Hours', NULL, 'Item Duration Unit', NULL, NULL, 1, 1, 'appian.administrator', '2021-01-26 12:22:09', 'appian.administrator', '2021-01-26 12:22:09'),
(12, 'Days', NULL, 'Item Duration Unit', NULL, NULL, 2, 1, 'appian.administrator', '2021-01-26 12:22:09', 'appian.administrator', '2021-01-26 12:22:09'),
(13, 'Weeks', NULL, 'Item Duration Unit', NULL, NULL, 3, 1, 'appian.administrator', '2021-01-26 12:22:09', 'appian.administrator', '2021-01-26 12:22:09'),
(14, 'Document Review', NULL, 'Template Type', NULL, NULL, NULL, 1, 'appian.administrator', '2021-01-26 12:22:09', 'appian.administrator', '2021-01-26 12:22:09'),
(15, '<', NULL, 'Operation', NULL, NULL, NULL, 1, 'appian.administrator', '2021-01-27 12:22:09', 'appian.administrator', '2021-01-27 12:22:09'),
(16, '>', NULL, 'Operation', NULL, NULL, NULL, 1, 'appian.administrator', '2021-01-27 12:22:09', 'appian.administrator', '2021-01-27 12:22:09'),
(17, '=', NULL, 'Operation', NULL, NULL, NULL, 1, 'appian.administrator', '2021-01-27 12:22:09', 'appian.administrator', '2021-01-27 12:22:09'),
(18, '<=', NULL, 'Operation', NULL, NULL, NULL, 1, 'appian.administrator', '2021-01-27 12:22:09', 'appian.administrator', '2021-01-27 12:22:09'),
(19, '>=', NULL, 'Operation', NULL, NULL, NULL, 1, 'appian.administrator', '2021-01-27 12:22:09', 'appian.administrator', '2021-01-27 12:22:09'),
(20, 'Approve', NULL, 'Review Type', 'thumbs-up', 'ACCENT', 1, 1, 'appian.administrator', '2021-01-27 12:22:09', 'appian.administrator', '2021-01-27 12:22:09'),
(21, 'Reject', NULL, 'Review Type', 'thumbs-down', 'ACCENT', 3, 1, 'appian.administrator', '2021-01-27 12:22:09', 'appian.administrator', '2021-01-27 12:22:09'),
(22, 'Accept', NULL, 'Review Type', 'thumbs-up', 'ACCENT', 1, 1, 'appian.administrator', '2021-01-27 12:22:09', 'appian.administrator', '2021-01-27 12:22:09'),
(23, 'Request Changes', NULL, 'Review Type', 'edit', 'ACCENT', 2, 1, 'appian.administrator', '2021-01-27 12:22:09', 'appian.administrator', '2021-01-27 12:22:09'),
(24, 'Vendor', NULL, 'Document Type', NULL, NULL, 1, 1, 'appian.administrator', '2021-01-28 12:22:09', 'appian.administrator', '2021-01-28 12:22:09'),
(25, 'Factor', NULL, 'Document Type', NULL, NULL, 2, 1, 'appian.administrator', '2021-01-28 12:22:09', 'appian.administrator', '2021-01-28 12:22:09'),
(26, 'Evaluator', NULL, 'Document Type', NULL, NULL, 3, 1, 'appian.administrator', '2021-01-28 12:22:09', 'appian.administrator', '2021-01-28 12:22:09'),
(27, 'Consensus', NULL, 'Document Type', NULL, NULL, 4, 1, 'appian.administrator', '2021-01-28 12:22:09', 'appian.administrator', '2021-01-28 12:22:09'),
(28, 'Recommendation', NULL, 'Document Type', NULL, NULL, 5, 1, 'appian.administrator', '2021-01-28 12:22:09', 'appian.administrator', '2021-01-28 12:22:09'),
(29, 'DUNS', NULL, 'Vendor ID Type', NULL, NULL, 1, 1, 'appian.administrator', '2021-01-29 12:22:09', 'appian.administrator', '2021-01-29 12:22:09'),
(30, 'CAGE', NULL, 'Vendor ID Type', NULL, NULL, 2, 1, 'appian.administrator', '2021-01-29 12:22:09', 'appian.administrator', '2021-01-29 12:22:09'),
(31, 'Factor', NULL, 'Document Association', NULL, NULL, 1, 1, 'appian.administrator', '2021-02-05 12:22:09', 'appian.administrator', '2021-02-05 12:22:09'),
(32, 'Vendor', NULL, 'Document Association', NULL, NULL, 2, 1, 'appian.administrator', '2021-02-05 12:22:09', 'appian.administrator', '2021-02-05 12:22:09'),
(33, 'Evaluation', NULL, 'Document Association', NULL, NULL, 3, 1, 'appian.administrator', '2021-02-05 12:22:09', 'appian.administrator', '2021-02-05 12:22:09');

--
-- Dumping data for table `AS_GSS_R_DOCUMENT_TEMPLATE`
--

INSERT INTO `AS_GSS_R_DOCUMENT_TEMPLATE` (`DOCUMENT_TEMPLATE_ID`, `DOCUMENT_NAME`, `FILE_TYPE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`, `IS_ACTIVE`) VALUES
(1, 'Exercise Option Letter Template', 'DOCX', 'appian.administrator\r\n', '2021-01-28 10:11:54', 'appian.administrator\r\n', '2021-01-28 10:11:54', 1);

--
-- Dumping data for table `AS_GSS_TMG_R_TASK_ACTION`
--

INSERT INTO `AS_GSS_TMG_R_TASK_ACTION` (`TASK_ACTION_ID`, `ACTION_DISPLAY_NAME`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES
(1, 'AS.GSS.TMG.Tasks.txt_ActionCreated', 'appian.administrator', '2020-03-23 18:04:38', 'appian.administrator', '2020-03-23 18:04:44'),
(2, 'AS.GSS.TMG.Tasks.txt_ActionAccepted', 'appian.administrator', '2020-03-23 18:04:38', 'appian.administrator', '2020-03-23 18:04:44'),
(3, 'AS.GSS.TMG.Tasks.txt_ActionCompleted', 'appian.administrator', '2020-03-23 18:04:38', 'appian.administrator', '2020-03-23 18:04:44'),
(4, 'AS.GSS.TMG.Tasks.txt_ActionReassigned', 'appian.administrator', '2020-03-23 18:04:38', 'appian.administrator', '2020-03-23 18:04:44'),
(5, 'AS.GSS.TMG.Tasks.txt_ActionAssigned', 'appian.administrator', '2020-03-23 18:04:38', 'appian.administrator', '2020-03-23 18:04:44'),
(6, 'AS.GSS.TMG.Tasks.txt_ActionCancelled', 'appian.administrator', '2020-03-23 18:04:38', 'appian.administrator', '2020-03-23 18:04:44');

--
-- Dumping data for table `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE`
--

INSERT INTO `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE` (`TASK_BEHAVIOR_TYPE_ID`, `BEHAVIOR_TYPE_CODE`, `BEHAVIOR_DISPLAY_NAME`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`, `BEHAVIOR_SUBTYPE_CODE`, `CONFIGURATION_LEVEL_CODE`, `ICON`, `COLOR`) VALUES
(1, 'DATA_ENTRY', 'AS.GSS.TMG.Tasks.txt_BehaviorTypeConfirmation', 'appian.administrator', '2020-03-03 14:02:09', 'appian.administrator', '2020-03-03 14:02:09', 'CONFIRMATION', 'AD_HOC', 'check-square-o', '#2C9F5A'),
(2, 'DATA_ENTRY', 'AS.GSS.TMG.Tasks.txt_BehaviorTypeReview', 'appian.administrator', '2020-03-03 14:02:09', 'appian.administrator', '2020-03-03 14:02:09', 'REVIEW', 'AD_HOC', 'thumbs-o-up', '#2BAAD5'),
(3, 'DATA_ENTRY', 'AS.GSS.TMG.Tasks.txt_BehaviorTypeAttachDocument', 'appian.administrator', '2020-03-03 14:02:09', 'appian.administrator', '2020-03-03 14:02:09', 'DOCUMENT_UPLOAD', 'AD_HOC', 'upload', '#F96502'),
(4, 'DATA_ENTRY', 'AS.GSS.TMG.Tasks.txt_BehaviorTypeProcessSetup', 'appian.administrator', '2020-03-03 14:02:09', 'appian.administrator', '2020-03-03 14:02:09', 'PROCESS_SETUP', 'SYSTEM', 'wrench', '#757575'),
(5, 'DATA_ENTRY', 'AS.GSS.TMG.Tasks.txt_BehaviorTypeDocumentWithTemplate', 'appian.administrator', '2020-09-23 13:08:48', 'appian.administrator', '2020-09-23 14:02:09', 'CREATE_DOCUMENT_FROM_TEMPLATE', 'AD_HOC', 'file-text-o', '#2BAAD5'),
(6, 'DATA_ENTRY', 'AS.GSS.TMG.Tasks.txt_BehaviorTypeAcknowledge', 'appian.administrator', '2020-09-14 13:08:48', 'appian.administrator', '2020-09-14 14:02:09', 'AWARD_ACKNOWLEDGEMENT', 'SYSTEM', 'pencil-square', '#2BAAD5'),
(7, 'DATA_ENTRY', 'AS.GSS.TMG.Tasks.txt_BehaviorTypeReview', 'appian.administrator', '2020-09-14 13:08:48', 'appian.administrator', '2020-09-14 14:02:09', 'REVIEW', 'SYSTEM', 'thumbs-o-up', '#2BAAD5'),
(8, 'DATA_ENTRY', 'AS.GSS.TMG.Tasks.txt_BehaviorTypeConfirmation', 'appian.administrator', '2020-09-14 13:08:48', 'appian.administrator', '2020-09-14 14:02:09', 'CONFIRMATION', 'SYSTEM', 'check-square-o', '#2C9F5A'),
(9, 'DATA_ENTRY', 'AS.GSS.TMG.Tasks.txt_BehaviorTypeDocumentWithTemplate', 'appian.administrator', '2020-09-23 13:08:48', 'appian.administrator', '2020-09-23 14:02:09', 'CREATE_DOCUMENT_FROM_TEMPLATE', 'SYSTEM', 'file-text-o', '#2BAAD5'),
(10, 'DATA_ENTRY', 'AS.GSS.TMG.Tasks.txt_BehaviorTypeAlertConfirmation', 'appian.administrator', '2020-10-09 13:08:48', 'appian.administrator', '2020-10-09 13:08:48', 'ALERT_CONFIRMATION', 'SYSTEM', 'exclamation', 'NEGATIVE');

--
-- Dumping data for table `AS_GSS_TMG_R_TASK_CATEGORY`
--

INSERT INTO `AS_GSS_TMG_R_TASK_CATEGORY` (`TASK_CATEGORY_ID`, `CATEGORY_NAME`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`, `IS_ACTIVE`) VALUES
(1, 'Process Setup', 'appian.administrator', '2020-09-02 00:00:00', 'appian.administrator', '2020-09-02 00:00:00', 0),
(6, 'Review', 'appian.administrator', '2020-09-14 05:30:19', 'appian.administrator', '2020-09-14 05:30:19', 0),
(7, 'Confirmation', 'appian.administrator', '2020-09-14 05:30:19', 'appian.administrator', '2020-09-14 05:30:19', 0);

--
-- Dumping data for table `AS_GSS_TMG_R_TASK_REF`
--

INSERT INTO `AS_GSS_TMG_R_TASK_REF` (`TASK_REF_ID`, `TASK_NAME`, `TASK_BEHAVIOR_TYPE_ID`, `TASK_CATEGORY_ID`, `DEFAULT_GROUP_ASSIGNEE`, `TASK_REF_DOC_UPLOAD_ID`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES
(1, 'Select Process', 4, 1, NULL, NULL, 'appian.administrator', '2020-09-02 00:00:00', 'appian.administrator', '2020-09-02 00:00:00'),
(11, 'Address Review Comment', 6, 6, NULL, NULL, 'appian.administrator', '2020-09-14 05:36:02', 'appian.administrator', '2020-09-14 05:36:02'),
(12, 'Submit Document for Review', 8, 7, NULL, NULL, 'appian.administrator', '2020-09-14 05:33:28', 'appian.administrator', '2020-09-14 05:33:28'),
(13, 'Review Document', 7, 6, NULL, NULL, 'appian.administrator', '2020-09-14 05:33:28', 'appian.administrator', '2020-09-29 11:00:00'),
(14, 'Alert', 10, 7, NULL, NULL, 'appian.administrator', '2020-10-09 05:33:28', 'appian.administrator', '2020-10-09 05:33:28'),
(18, 'Review Bot Results', 8, 7, NULL, NULL, 'appian.administrator', '2020-10-14 21:31:55', 'appian.administrator', '2020-10-14 21:31:55'),
(19, 'FAPIIS Research', 8, 7, NULL, NULL, 'appian.administrator', '2020-10-16 07:12:09', 'appian.administrator', '2020-10-16 07:12:09'),
(47, 'Create Document from Template', 9, 7, NULL, NULL, 'appian.administrator', '2020-09-29 05:33:28', 'appian.administrator', '2020-09-29 05:33:28');

--
-- Dumping data for table `AS_GSS_TMG_R_TASK_STATUS`
--

INSERT INTO `AS_GSS_TMG_R_TASK_STATUS` (`TASK_STATUS_ID`, `STATUS_DISPLAY_NAME`, `ICON`, `COLOR`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES
(1, 'AS.GSS.TMG.Tasks.txt_StatusQueued', 'clock-o', 'STANDARD', 'appian.administrator', '2020-03-23 18:04:38', 'appian.administrator', '2020-03-23 18:04:44'),
(2, 'AS.GSS.TMG.Tasks.txt_StatusAssigned', 'spinner', 'STANDARD', 'appian.administrator', '2020-03-23 18:04:38', 'appian.administrator', '2020-03-23 18:04:44'),
(3, 'AS.GSS.TMG.Tasks.txt_StatusInProgress', 'spinner', 'STANDARD', 'appian.administrator', '2020-03-23 18:04:38', 'appian.administrator', '2020-03-23 18:04:44'),
(4, 'AS.GSS.TMG.Tasks.txt_StatusComplete', 'check', 'POSITIVE', 'appian.administrator', '2020-03-23 18:04:38', 'appian.administrator', '2020-03-23 18:04:44'),
(5, 'AS.GSS.TMG.Tasks.txt_StatusNotNeeded', '', 'STANDARD', 'appian.administrator', '2020-03-23 18:04:38', 'appian.administrator', '2020-03-23 18:04:44'),
(6, 'AS.GSS.TMG.Tasks.txt_StatusCancelled', '', '', 'appian.administrator', '2020-03-23 18:04:38', 'appian.administrator', '2020-03-23 18:04:44'),
(7, 'AS.GSS.TMG.Tasks.lbl_All', '', '', 'appian.administrator', '2020-09-09 00:00:00', 'appian.administrator', '2020-09-09 00:00:00');

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 568, 537);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************
-- [569] Create Baseline GSS Constraints
-- ***************************************
-- Create the baseline GSS constraints
-- ***************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 569, "Create Baseline GSS Constraints",2133,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

--
-- Indexes for table `AS_GSS_A_R_CRITERIA`
--
ALTER TABLE `AS_GSS_A_R_CRITERIA`
  ADD KEY `asgssarevltin_criterichnges` (`EVALUATION_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_A_R_CRITERIA_ASSIGNMENTS`
--
ALTER TABLE `AS_GSS_A_R_CRITERIA_ASSIGNMENTS`
  ADD KEY `asgssarcriteria_chnges` (`CRITERIA_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_A_R_CRITERIA_ASSIGNMENTS_FIELD`
--
ALTER TABLE `AS_GSS_A_R_CRITERIA_ASSIGNMENTS_FIELD`
  ADD KEY `asgssrcrtrssgn_smplfldchngs` (`ASSIGNMENT_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_A_R_CRITERIA_FIELD`
--
ALTER TABLE `AS_GSS_A_R_CRITERIA_FIELD`
  ADD KEY `asgssrcritri_simplfildchngs` (`CRITERIA_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_A_R_EVALUATION_DOCUMENT`
--
ALTER TABLE `AS_GSS_A_R_EVALUATION_DOCUMENT`
  ADD KEY `asgssarevltin_dcmentchanges` (`EVALUATION_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_A_R_EVALUATION_DOCUMENT_FIELD`
--
ALTER TABLE `AS_GSS_A_R_EVALUATION_DOCUMENT_FIELD`
  ADD KEY `asgssrvltndcmn_smplfldchngs` (`EVALUATION_DOCUMENT_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_A_R_EVALUATION_FIELD`
--
ALTER TABLE `AS_GSS_A_R_EVALUATION_FIELD`
  ADD KEY `asgssrevltin_simplfildchngs` (`EVALUATION_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_A_R_EVALUATION_PHASE`
--
ALTER TABLE `AS_GSS_A_R_EVALUATION_PHASE`
  ADD KEY `asgssarevalphse_evaladtid` (`EVALUATION_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_A_R_EVALUATION_PHASE_FIELD`
--
ALTER TABLE `AS_GSS_A_R_EVALUATION_PHASE_FIELD`
  ADD KEY `asgssrvltnphs_smplfildchngs` (`EVALUATION_PHASE_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_A_R_EVALUATION_VENDOR`
--
ALTER TABLE `AS_GSS_A_R_EVALUATION_VENDOR`
  ADD KEY `asgssarevalvendr_vendrid` (`VENDOR_ID`),
  ADD KEY `asgssarevalvendr_evaladtid` (`EVALUATION_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_A_R_EVALUATION_VENDOR_BUSINESS_TYPE`
--
ALTER TABLE `AS_GSS_A_R_EVALUATION_VENDOR_BUSINESS_TYPE`
  ADD KEY `asgssrvltnvnd_bsnsstypchngs` (`VENDOR_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_A_R_EVALUATION_VENDOR_BUSINESS_TYPE_FIELD`
--
ALTER TABLE `AS_GSS_A_R_EVALUATION_VENDOR_BUSINESS_TYPE_FIELD`
  ADD KEY `asgssrvltnvndr_smplfldchngs` (`BUSINESS_TYPE_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_A_R_EVALUATION_VENDOR_FIELD`
--
ALTER TABLE `AS_GSS_A_R_EVALUATION_VENDOR_FIELD`
  ADD KEY `asgssrevltnvndr_smplfldchngs` (`VENDOR_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_A_R_EVALUATOR_TEAM`
--
ALTER TABLE `AS_GSS_A_R_EVALUATOR_TEAM`
  ADD KEY `asgssrevltin_vltortemchnges` (`EVALUATION_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_A_R_EVALUATOR_TEAM_FIELD`
--
ALTER TABLE `AS_GSS_A_R_EVALUATOR_TEAM_FIELD`
  ADD KEY `asgssrvltortm_simplfildchngs` (`TEAM_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_A_R_TEAM_MEMBERSHIP`
--
ALTER TABLE `AS_GSS_A_R_TEAM_MEMBERSHIP`
  ADD KEY `asgssrevltin_vltortemmembrshpchnges` (`TEAM_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_A_R_TEAM_MEMBERSHIP_FIELD`
--
ALTER TABLE `AS_GSS_A_R_TEAM_MEMBERSHIP_FIELD`
  ADD KEY `asgssrvltortmmbrshp_simplfildchngs` (`TEAM_MEMBERSHIP_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_CRITERIA`
--
ALTER TABLE `AS_GSS_CRITERIA`
  ADD KEY `asgsscriteria_criteriachair` (`CRITERIA_CHAIR`),
  ADD KEY `asgsscriteria_rankingmethod` (`RANKING_METHOD_ID`),
  ADD KEY `asgssevaluation_criteria` (`EVALUATION_ID`),
  ADD KEY `asgsscriteria_criteriastats` (`CRITERIA_STATUS_ID`);

--
-- Indexes for table `AS_GSS_CRITERIA_ASSIGNMENTS`
--
ALTER TABLE `AS_GSS_CRITERIA_ASSIGNMENTS`
  ADD KEY `asgss_criteria_assignments` (`CRITERIA_ID`) USING BTREE,
  ADD KEY `asgss_evltr_team` (`ASSIGNED_TEAM_ID`);

--
-- Indexes for table `AS_GSS_EVALUATION`
--
ALTER TABLE `AS_GSS_EVALUATION`
  ADD KEY `asgssevalatin_evalatinchair` (`EVALUATION_CHIEF`),
  ADD KEY `asgssevalatin_evalatinstats` (`EVALUATION_STATUS_ID`),
  ADD KEY `asgssevalatin_evalatinmethd` (`EVALUATION_METHOD_ID`);

--
-- Indexes for table `AS_GSS_EVALUATION_DOCUMENT`
--
ALTER TABLE `AS_GSS_EVALUATION_DOCUMENT`
  ADD KEY `asgssevalatindcment_doctype` (`DOC_TYPE`),
  ADD KEY `asgssevltindcment_dctemplte` (`DOCUMENT_TEMPLATE`),
  ADD KEY `asgssevaluation_documents` (`EVALUATION_ID`),
  ADD KEY `asgsscriteria_documents` (`CRITERIA_ID`),
  ADD KEY `asgssevaluation_vendor` (`VENDOR_ID`);

--
-- Indexes for table `AS_GSS_EVALUATION_PHASE`
--
ALTER TABLE `AS_GSS_EVALUATION_PHASE`
  ADD KEY `asgssevalatin_evalationphase` (`EVALUATION_ID`);

--
-- Indexes for table `AS_GSS_EVALUATION_VENDOR`
--
ALTER TABLE `AS_GSS_EVALUATION_VENDOR`
  ADD KEY `asgssevalvendr_vendrrefid` (`VENDOR_REF_ID`),
  ADD KEY `asgssevalvendr_evalid` (`EVALUATION_ID`),
  ADD KEY `asgssevalvendr_vendrcntry` (`VENDOR_COUNTRY`),
  ADD KEY `asgssevalvendr_vendrstte` (`VENDOR_STATE`);

--
-- Indexes for table `AS_GSS_EVALUATION_VENDOR_BUSINESS_TYPE`
--
ALTER TABLE `AS_GSS_EVALUATION_VENDOR_BUSINESS_TYPE`
  ADD KEY `asgssrvendrbsnstype_vendrid` (`VENDOR_ID`),
  ADD KEY `asgssevalvendrbsnstype_typecode` (`TYPE_CODE`);

--
-- Indexes for table `AS_GSS_EVALUATOR_TEAM`
--
ALTER TABLE `AS_GSS_EVALUATOR_TEAM`
  ADD KEY `asgssevalatin_evalationteam` (`EVALUATION_ID`);

--
-- Indexes for table `AS_GSS_R_VENDOR`
--
ALTER TABLE `AS_GSS_R_VENDOR`
  ADD KEY `asgssrvendr_vendrcntry` (`VENDOR_COUNTRY`),
  ADD KEY `asgssrvendr_vendrstte` (`VENDOR_STATE`);

--
-- Indexes for table `AS_GSS_R_VENDOR_BUSINESS_TYPE`
--
ALTER TABLE `AS_GSS_R_VENDOR_BUSINESS_TYPE`
  ADD KEY `asgssrvendrbsnstype_vendrrefid` (`VENDOR_REF_ID`),
  ADD KEY `asgssrvendrbsnstype_typecode` (`TYPE_CODE`);

--
-- Indexes for table `AS_GSS_TEAM_MEMBERSHIP`
--
ALTER TABLE `AS_GSS_TEAM_MEMBERSHIP`
  ADD KEY `asgssevltrtem_temmembership` (`TEAM_ID`);

--
-- Indexes for table `AS_GSS_TMG_A_R_TASK_CATEGORY_FIELD`
--
ALTER TABLE `AS_GSS_TMG_A_R_TASK_CATEGORY_FIELD`
  ADD KEY `AS_GSS_TMG_rtskctgry_smplfildchngs` (`TASK_CATEGORY_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_TMG_A_R_TASK_REF_FIELD`
--
ALTER TABLE `AS_GSS_TMG_A_R_TASK_REF_FIELD`
  ADD KEY `AS_GSS_TMG_rtskrf_simplfieldchnges` (`TASK_REF_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_TMG_A_R_TEMPLATE_FIELD`
--
ALTER TABLE `AS_GSS_TMG_A_R_TEMPLATE_FIELD`
  ADD KEY `AS_GSS_TMG_rtmplt_simplfieldchnges` (`TEMPLATE_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_TMG_A_R_TEMPLATE_TASK`
--
ALTER TABLE `AS_GSS_TMG_A_R_TEMPLATE_TASK`
  ADD KEY `AS_GSS_TMG_rtmplt_templtetskchnges` (`TEMPLATE_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_TMG_A_R_TEMPLATE_TASK_FIELD`
--
ALTER TABLE `AS_GSS_TMG_A_R_TEMPLATE_TASK_FIELD`
  ADD KEY `AS_GSS_TMG_rtmplttsk_smplfildchngs` (`TEMPLATE_TASK_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC`
--
ALTER TABLE `AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC`
  ADD KEY `AS_GSS_TMG_rtmplttsk_tmplttskprcdn` (`TEMPLATE_TASK_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC_F`
--
ALTER TABLE `AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC_F`
  ADD KEY `AS_GSS_TMG_rtmplttskp_smplfldchngs` (`TEMPLATE_TASK_PREC_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_TMG_A_TASK_PROCESS_SETUP`
--
ALTER TABLE `AS_GSS_TMG_A_TASK_PROCESS_SETUP`
  ADD KEY `AS_GSS_TMG_tmpltprcssstp_tskschngs` (`TEMPLATE_PROC_SETUP_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_TMG_A_TASK_PROCESS_SETUP_FIELD`
--
ALTER TABLE `AS_GSS_TMG_A_TASK_PROCESS_SETUP_FIELD`
  ADD KEY `AS_GSS_TMG_tskprcssst_smplfldchngs` (`TASK_PROC_SETUP_AUDIT_ID`);

--
-- Indexes for table `AS_GSS_TMG_R_TASK_REF`
--
ALTER TABLE `AS_GSS_TMG_R_TASK_REF`
  ADD KEY `AS_GSS_TMG_rtskref_taskbehavirtype` (`TASK_BEHAVIOR_TYPE_ID`),
  ADD KEY `AS_GSS_TMG_rtaskref_taskcategory` (`TASK_CATEGORY_ID`),
  ADD KEY `AS_GSS_TMG_rtaskref_dcploadcontext` (`TASK_REF_DOC_UPLOAD_ID`);

--
-- Indexes for table `AS_GSS_TMG_R_TASK_REF_DOC_UPLOAD`
--
ALTER TABLE `AS_GSS_TMG_R_TASK_REF_DOC_UPLOAD`
  ADD KEY `asgsstmgrtskrfdcpldcn_dctmplt` (`DOC_TEMPLATE`),
  ADD KEY `asgsstmgrtskrfdcpldcnt_dctypd` (`DOC_TYPE_ID`);

--
-- Indexes for table `AS_GSS_TMG_R_TEMPLATE`
--
ALTER TABLE `AS_GSS_TMG_R_TEMPLATE`
  ADD KEY `asgsstmgrtemplte_templtetype` (`TEMPLATE_TYPE`),
  ADD KEY `asgsstmgrtemplate_dctemplate` (`DOC_TEMPLATE`),
  ADD KEY `asgsstmgrtemplate_operation` (`OPERATION`);

--
-- Indexes for table `AS_GSS_TMG_R_TEMPLATE_TASK`
--
ALTER TABLE `AS_GSS_TMG_R_TEMPLATE_TASK`
  ADD KEY `AS_GSS_TMG_rtemplatetask_taskref` (`TASK_REF_ID`),
  ADD KEY `AS_GSS_TMG_rtemplte_templtetskmaps` (`TEMPLATE_ID`),
  ADD KEY `asgsstmgrtempltetsk_drtinnit` (`DURATION_UNIT`);

--
-- Indexes for table `AS_GSS_TMG_R_TEMPLATE_TASK_PRECEDNT`
--
ALTER TABLE `AS_GSS_TMG_R_TEMPLATE_TASK_PRECEDNT`
  ADD KEY `AS_GSS_TMG_rtemplatetask_prectasks` (`TEMPLATE_TASK_ID`);

--
-- Indexes for table `AS_GSS_TMG_TASK`
--
ALTER TABLE `AS_GSS_TMG_TASK`
  ADD KEY `AS_GSS_TMG_task_taskbehaviortype` (`TASK_BEHAVIOR_TYPE_ID`),
  ADD KEY `AS_GSS_TMG_task_taskcategory` (`TASK_CATEGORY_ID`),
  ADD KEY `AS_GSS_TMG_task_docuploadcontext` (`TASK_DOC_UPLOAD_ID`),
  ADD KEY `AS_GSS_TMG_task_review` (`TASK_REVIEW_ID`),
  ADD KEY `AS_GSS_TMG_task_taskstatus` (`TASK_STATUS_ID`),
  ADD KEY `asgsstmgtask_durationunit` (`DURATION_UNIT`),
  ADD KEY `asgsstmgtask_taskchecklist` (`CHECKLIST_ID`),
  ADD KEY `asgsstmgtask_evaluation` (`EVALUATION_ID`),
  ADD KEY `asgsstmgtaskset_tasks` (`TASK_ID`);

--
-- Indexes for table `AS_GSS_TMG_TASK_ACTION_AUDIT`
--
ALTER TABLE `AS_GSS_TMG_TASK_ACTION_AUDIT`
  ADD KEY `AS_GSS_TMG_FK_WORK_AUDIT` (`TASK_ID`),
  ADD KEY `AS_GSS_TMG_auditwork_review` (`TASK_REVIEW_ID`),
  ADD KEY `AS_GSS_TMG_auditwork_task` (`TASK_ID`),
  ADD KEY `AS_GSS_TMG_taskactinadit_taskactin` (`TASK_ACTION_ID`);

--
-- Indexes for table `AS_GSS_TMG_TASK_CHECKLIST`
--
ALTER TABLE `AS_GSS_TMG_TASK_CHECKLIST`
  ADD KEY `asgsstmgtskchecklist_listtype` (`LIST_TYPE`);

--
-- Indexes for table `AS_GSS_TMG_TASK_DOC_UPLOAD`
--
ALTER TABLE `AS_GSS_TMG_TASK_DOC_UPLOAD`
  ADD KEY `AS_GSS_TMG_kdcpldcntxt_nbrdngdcmnt` (`APPIAN_DOCUMENT_ID`),
  ADD KEY `asgsstmgtskdcpldcntxt_dctmplt` (`DOC_TEMPLATE`),
  ADD KEY `asgsstmgtskdcpldcntxt_dctypid` (`DOC_TYPE_ID`);

--
-- Indexes for table `AS_GSS_TMG_TASK_PRECEDENT`
--
ALTER TABLE `AS_GSS_TMG_TASK_PRECEDENT`
  ADD KEY `AS_GSS_TMG_task_taskprecedents` (`TASK_ID`);

--
-- Indexes for table `AS_GSS_TMG_TASK_REVIEW`
--
ALTER TABLE `AS_GSS_TMG_TASK_REVIEW`
  ADD KEY `asgsstmgtaskreview_decision` (`DECISION`);

--
-- Constraints for dumped tables
--

--
-- Constraints for table `AS_GSS_A_R_CRITERIA`
--
ALTER TABLE `AS_GSS_A_R_CRITERIA`
  ADD CONSTRAINT `asgssarevltin_criterichnges` FOREIGN KEY (`EVALUATION_AUDIT_ID`) REFERENCES `AS_GSS_A_R_EVALUATION` (`EVALUATION_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_A_R_CRITERIA_ASSIGNMENTS`
--
ALTER TABLE `AS_GSS_A_R_CRITERIA_ASSIGNMENTS`
  ADD CONSTRAINT `asgssarcriteria_chnges` FOREIGN KEY (`CRITERIA_AUDIT_ID`) REFERENCES `AS_GSS_A_R_CRITERIA` (`CRITERIA_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_A_R_CRITERIA_ASSIGNMENTS_FIELD`
--
ALTER TABLE `AS_GSS_A_R_CRITERIA_ASSIGNMENTS_FIELD`
  ADD CONSTRAINT `asgssrcrtrssgn_smplfldchngs` FOREIGN KEY (`ASSIGNMENT_AUDIT_ID`) REFERENCES `AS_GSS_A_R_CRITERIA_ASSIGNMENTS` (`ASSIGNMENT_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_A_R_CRITERIA_FIELD`
--
ALTER TABLE `AS_GSS_A_R_CRITERIA_FIELD`
  ADD CONSTRAINT `asgssrcritri_simplfildchngs` FOREIGN KEY (`CRITERIA_AUDIT_ID`) REFERENCES `AS_GSS_A_R_CRITERIA` (`CRITERIA_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_A_R_EVALUATION_DOCUMENT`
--
ALTER TABLE `AS_GSS_A_R_EVALUATION_DOCUMENT`
  ADD CONSTRAINT `asgssarevltin_dcmentchanges` FOREIGN KEY (`EVALUATION_AUDIT_ID`) REFERENCES `AS_GSS_A_R_EVALUATION` (`EVALUATION_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_A_R_EVALUATION_DOCUMENT_FIELD`
--
ALTER TABLE `AS_GSS_A_R_EVALUATION_DOCUMENT_FIELD`
  ADD CONSTRAINT `asgssrvltndcmn_smplfldchngs` FOREIGN KEY (`EVALUATION_DOCUMENT_AUDIT_ID`) REFERENCES `AS_GSS_A_R_EVALUATION_DOCUMENT` (`EVALUATION_DOCUMENT_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_A_R_EVALUATION_FIELD`
--
ALTER TABLE `AS_GSS_A_R_EVALUATION_FIELD`
  ADD CONSTRAINT `asgssrevltin_simplfildchngs` FOREIGN KEY (`EVALUATION_AUDIT_ID`) REFERENCES `AS_GSS_A_R_EVALUATION` (`EVALUATION_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_A_R_EVALUATION_PHASE`
--
ALTER TABLE `AS_GSS_A_R_EVALUATION_PHASE`
  ADD CONSTRAINT `asgssarevalphse_evaladtid` FOREIGN KEY (`EVALUATION_AUDIT_ID`) REFERENCES `AS_GSS_A_R_EVALUATION` (`EVALUATION_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_A_R_EVALUATION_PHASE_FIELD`
--
ALTER TABLE `AS_GSS_A_R_EVALUATION_PHASE_FIELD`
  ADD CONSTRAINT `asgssrvltnphs_smplfildchngs` FOREIGN KEY (`EVALUATION_PHASE_AUDIT_ID`) REFERENCES `AS_GSS_A_R_EVALUATION_PHASE` (`EVALUATION_PHASE_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_A_R_EVALUATION_VENDOR`
--
ALTER TABLE `AS_GSS_A_R_EVALUATION_VENDOR`
  ADD CONSTRAINT `asgssarevalvendr_evaladtid` FOREIGN KEY (`EVALUATION_AUDIT_ID`) REFERENCES `AS_GSS_A_R_EVALUATION` (`EVALUATION_AUDIT_ID`),
  ADD CONSTRAINT `asgssarevalvendr_vendrid` FOREIGN KEY (`VENDOR_ID`) REFERENCES `AS_GSS_EVALUATION_VENDOR` (`VENDOR_ID`);

--
-- Constraints for table `AS_GSS_A_R_EVALUATION_VENDOR_BUSINESS_TYPE`
--
ALTER TABLE `AS_GSS_A_R_EVALUATION_VENDOR_BUSINESS_TYPE`
  ADD CONSTRAINT `asgssrvltnvnd_bsnsstypchngs` FOREIGN KEY (`VENDOR_AUDIT_ID`) REFERENCES `AS_GSS_A_R_EVALUATION_VENDOR` (`VENDOR_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_A_R_EVALUATION_VENDOR_BUSINESS_TYPE_FIELD`
--
ALTER TABLE `AS_GSS_A_R_EVALUATION_VENDOR_BUSINESS_TYPE_FIELD`
  ADD CONSTRAINT `asgssrvltnvndr_smplfldchngs` FOREIGN KEY (`BUSINESS_TYPE_AUDIT_ID`) REFERENCES `AS_GSS_A_R_EVALUATION_VENDOR_BUSINESS_TYPE` (`BUSINESS_TYPE_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_A_R_EVALUATION_VENDOR_FIELD`
--
ALTER TABLE `AS_GSS_A_R_EVALUATION_VENDOR_FIELD`
  ADD CONSTRAINT `asgssrevltnvndr_smplfldchngs` FOREIGN KEY (`VENDOR_AUDIT_ID`) REFERENCES `AS_GSS_A_R_EVALUATION_VENDOR` (`VENDOR_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_A_R_EVALUATOR_TEAM`
--
ALTER TABLE `AS_GSS_A_R_EVALUATOR_TEAM`
  ADD CONSTRAINT `asgssrevltin_vltortemchnges` FOREIGN KEY (`EVALUATION_AUDIT_ID`) REFERENCES `AS_GSS_A_R_EVALUATION` (`EVALUATION_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_A_R_EVALUATOR_TEAM_FIELD`
--
ALTER TABLE `AS_GSS_A_R_EVALUATOR_TEAM_FIELD`
  ADD CONSTRAINT `asgssrvltortm_simplfildchngs` FOREIGN KEY (`TEAM_AUDIT_ID`) REFERENCES `AS_GSS_A_R_EVALUATOR_TEAM` (`TEAM_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_A_R_TEAM_MEMBERSHIP`
--
ALTER TABLE `AS_GSS_A_R_TEAM_MEMBERSHIP`
  ADD CONSTRAINT `asgssrevltin_vltortemmembrshpchnges` FOREIGN KEY (`TEAM_AUDIT_ID`) REFERENCES `AS_GSS_A_R_EVALUATOR_TEAM` (`TEAM_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_A_R_TEAM_MEMBERSHIP_FIELD`
--
ALTER TABLE `AS_GSS_A_R_TEAM_MEMBERSHIP_FIELD`
  ADD CONSTRAINT `asgssrvltortmmbrshp_simplfildchngs` FOREIGN KEY (`TEAM_MEMBERSHIP_AUDIT_ID`) REFERENCES `AS_GSS_A_R_TEAM_MEMBERSHIP` (`TEAM_MEMBERSHIP_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_CRITERIA`
--
ALTER TABLE `AS_GSS_CRITERIA`
  ADD CONSTRAINT `asgsscriteria_criteriachair` FOREIGN KEY (`CRITERIA_CHAIR`) REFERENCES `AS_GSS_USER` (`USERNAME`),
  ADD CONSTRAINT `asgsscriteria_criteriastats` FOREIGN KEY (`CRITERIA_STATUS_ID`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`),
  ADD CONSTRAINT `asgsscriteria_rankingmethod` FOREIGN KEY (`RANKING_METHOD_ID`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`),
  ADD CONSTRAINT `asgssevaluation_criteria` FOREIGN KEY (`EVALUATION_ID`) REFERENCES `AS_GSS_EVALUATION` (`EVALUATION_ID`);

--
-- Constraints for table `AS_GSS_CRITERIA_ASSIGNMENTS`
--
ALTER TABLE `AS_GSS_CRITERIA_ASSIGNMENTS`
  ADD CONSTRAINT `asgss_criteria_assignments` FOREIGN KEY (`CRITERIA_ID`) REFERENCES `AS_GSS_CRITERIA` (`CRITERIA_ID`),
  ADD CONSTRAINT `asgss_evltr_team` FOREIGN KEY (`ASSIGNED_TEAM_ID`) REFERENCES `AS_GSS_EVALUATOR_TEAM` (`TEAM_ID`);

--
-- Constraints for table `AS_GSS_EVALUATION`
--
ALTER TABLE `AS_GSS_EVALUATION`
  ADD CONSTRAINT `asgssevalatin_evalatinchair` FOREIGN KEY (`EVALUATION_CHIEF`) REFERENCES `AS_GSS_USER` (`USERNAME`),
  ADD CONSTRAINT `asgssevalatin_evalatinmethd` FOREIGN KEY (`EVALUATION_METHOD_ID`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`),
  ADD CONSTRAINT `asgssevalatin_evalatinstats` FOREIGN KEY (`EVALUATION_STATUS_ID`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`);

--
-- Constraints for table `AS_GSS_EVALUATION_DOCUMENT`
--
ALTER TABLE `AS_GSS_EVALUATION_DOCUMENT`
  ADD CONSTRAINT `asgsscriteria_documents` FOREIGN KEY (`CRITERIA_ID`) REFERENCES `AS_GSS_CRITERIA` (`CRITERIA_ID`),
  ADD CONSTRAINT `asgssevalatindcment_doctype` FOREIGN KEY (`DOC_TYPE`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`),
  ADD CONSTRAINT `asgssevaluation_documents` FOREIGN KEY (`EVALUATION_ID`) REFERENCES `AS_GSS_EVALUATION` (`EVALUATION_ID`),
  ADD CONSTRAINT `asgssevaluation_vendor` FOREIGN KEY (`VENDOR_ID`) REFERENCES `AS_GSS_EVALUATION_VENDOR` (`VENDOR_ID`),
  ADD CONSTRAINT `asgssevltindcment_dctemplte` FOREIGN KEY (`DOCUMENT_TEMPLATE`) REFERENCES `AS_GSS_R_DOCUMENT_TEMPLATE` (`DOCUMENT_TEMPLATE_ID`);

--
-- Constraints for table `AS_GSS_EVALUATION_PHASE`
--
ALTER TABLE `AS_GSS_EVALUATION_PHASE`
  ADD CONSTRAINT `asgssevalatin_evalationphase` FOREIGN KEY (`EVALUATION_ID`) REFERENCES `AS_GSS_EVALUATION` (`EVALUATION_ID`);

--
-- Constraints for table `AS_GSS_EVALUATION_VENDOR`
--
ALTER TABLE `AS_GSS_EVALUATION_VENDOR`
  ADD CONSTRAINT `asgssevalvendr_evalid` FOREIGN KEY (`EVALUATION_ID`) REFERENCES `AS_GSS_EVALUATION` (`EVALUATION_ID`),
  ADD CONSTRAINT `asgssevalvendr_vendrcntry` FOREIGN KEY (`VENDOR_COUNTRY`) REFERENCES `AS_GAM_R_COUNTRY` (`COUNTRY_ID`),
  ADD CONSTRAINT `asgssevalvendr_vendrrefid` FOREIGN KEY (`VENDOR_REF_ID`) REFERENCES `AS_GSS_R_VENDOR` (`VENDOR_REF_ID`),
  ADD CONSTRAINT `asgssevalvendr_vendrstte` FOREIGN KEY (`VENDOR_STATE`) REFERENCES `AS_GAM_R_STATE` (`STATE_ID`);

--
-- Constraints for table `AS_GSS_EVALUATION_VENDOR_BUSINESS_TYPE`
--
ALTER TABLE `AS_GSS_EVALUATION_VENDOR_BUSINESS_TYPE`
  ADD CONSTRAINT `asgssevalvendrbsnstype_typecode` FOREIGN KEY (`TYPE_CODE`) REFERENCES `AS_GAM_R_BUSINESS_TYPE` (`CODE`),
  ADD CONSTRAINT `asgssrvendrbsnstype_vendrid` FOREIGN KEY (`VENDOR_ID`) REFERENCES `AS_GSS_EVALUATION_VENDOR` (`VENDOR_ID`);

--
-- Constraints for table `AS_GSS_EVALUATOR_TEAM`
--
ALTER TABLE `AS_GSS_EVALUATOR_TEAM`
  ADD CONSTRAINT `asgssevalatin_evalationteam` FOREIGN KEY (`EVALUATION_ID`) REFERENCES `AS_GSS_EVALUATION` (`EVALUATION_ID`);

--
-- Constraints for table `AS_GSS_R_VENDOR`
--
ALTER TABLE `AS_GSS_R_VENDOR`
  ADD CONSTRAINT `asgssrvendr_vendrcntry` FOREIGN KEY (`VENDOR_COUNTRY`) REFERENCES `AS_GAM_R_COUNTRY` (`COUNTRY_ID`),
  ADD CONSTRAINT `asgssrvendr_vendrstte` FOREIGN KEY (`VENDOR_STATE`) REFERENCES `AS_GAM_R_STATE` (`STATE_ID`);

--
-- Constraints for table `AS_GSS_R_VENDOR_BUSINESS_TYPE`
--
ALTER TABLE `AS_GSS_R_VENDOR_BUSINESS_TYPE`
  ADD CONSTRAINT `asgssrvendrbsnstype_typecode` FOREIGN KEY (`TYPE_CODE`) REFERENCES `AS_GAM_R_BUSINESS_TYPE` (`CODE`),
  ADD CONSTRAINT `asgssrvendrbsnstype_vendrrefid` FOREIGN KEY (`VENDOR_REF_ID`) REFERENCES `AS_GSS_R_VENDOR` (`VENDOR_REF_ID`);

--
-- Constraints for table `AS_GSS_TEAM_MEMBERSHIP`
--
ALTER TABLE `AS_GSS_TEAM_MEMBERSHIP`
  ADD CONSTRAINT `asgssevltrtem_temmembership` FOREIGN KEY (`TEAM_ID`) REFERENCES `AS_GSS_EVALUATOR_TEAM` (`TEAM_ID`);

--
-- Constraints for table `AS_GSS_TMG_A_R_TASK_CATEGORY_FIELD`
--
ALTER TABLE `AS_GSS_TMG_A_R_TASK_CATEGORY_FIELD`
  ADD CONSTRAINT `AS_GSS_TMG_rtskctgry_smplfildchngs` FOREIGN KEY (`TASK_CATEGORY_AUDIT_ID`) REFERENCES `AS_GSS_TMG_A_R_TASK_CATEGORY` (`TASK_CATEGORY_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_TMG_A_R_TASK_REF_FIELD`
--
ALTER TABLE `AS_GSS_TMG_A_R_TASK_REF_FIELD`
  ADD CONSTRAINT `AS_GSS_TMG_rtskrf_simplfieldchnges` FOREIGN KEY (`TASK_REF_AUDIT_ID`) REFERENCES `AS_GSS_TMG_A_R_TASK_REF` (`TASK_REF_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_TMG_A_R_TEMPLATE_FIELD`
--
ALTER TABLE `AS_GSS_TMG_A_R_TEMPLATE_FIELD`
  ADD CONSTRAINT `AS_GSS_TMG_rtmplt_simplfieldchnges` FOREIGN KEY (`TEMPLATE_AUDIT_ID`) REFERENCES `AS_GSS_TMG_A_R_TEMPLATE` (`TEMPLATE_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_TMG_A_R_TEMPLATE_TASK`
--
ALTER TABLE `AS_GSS_TMG_A_R_TEMPLATE_TASK`
  ADD CONSTRAINT `AS_GSS_TMG_rtmplt_templtetskchnges` FOREIGN KEY (`TEMPLATE_AUDIT_ID`) REFERENCES `AS_GSS_TMG_A_R_TEMPLATE` (`TEMPLATE_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_TMG_A_R_TEMPLATE_TASK_FIELD`
--
ALTER TABLE `AS_GSS_TMG_A_R_TEMPLATE_TASK_FIELD`
  ADD CONSTRAINT `AS_GSS_TMG_rtmplttsk_smplfildchngs` FOREIGN KEY (`TEMPLATE_TASK_AUDIT_ID`) REFERENCES `AS_GSS_TMG_A_R_TEMPLATE_TASK` (`TEMPLATE_TASK_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC`
--
ALTER TABLE `AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC`
  ADD CONSTRAINT `AS_GSS_TMG_rtmplttsk_tmplttskprcdn` FOREIGN KEY (`TEMPLATE_TASK_AUDIT_ID`) REFERENCES `AS_GSS_TMG_A_R_TEMPLATE_TASK` (`TEMPLATE_TASK_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC_F`
--
ALTER TABLE `AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC_F`
  ADD CONSTRAINT `AS_GSS_TMG_rtmplttskp_smplfldchngs` FOREIGN KEY (`TEMPLATE_TASK_PREC_AUDIT_ID`) REFERENCES `AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC` (`TEMPLATE_TASK_PREC_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_TMG_A_TASK_PROCESS_SETUP`
--
ALTER TABLE `AS_GSS_TMG_A_TASK_PROCESS_SETUP`
  ADD CONSTRAINT `AS_GSS_TMG_tmpltprcssstp_tskschngs` FOREIGN KEY (`TEMPLATE_PROC_SETUP_AUDIT_ID`) REFERENCES `AS_GSS_TMG_A_TEMPLATE_PROCESS_SETUP` (`TEMPLATE_PROC_SETUP_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_TMG_A_TASK_PROCESS_SETUP_FIELD`
--
ALTER TABLE `AS_GSS_TMG_A_TASK_PROCESS_SETUP_FIELD`
  ADD CONSTRAINT `AS_GSS_TMG_tskprcssst_smplfldchngs` FOREIGN KEY (`TASK_PROC_SETUP_AUDIT_ID`) REFERENCES `AS_GSS_TMG_A_TASK_PROCESS_SETUP` (`TASK_PROC_SETUP_AUDIT_ID`);

--
-- Constraints for table `AS_GSS_TMG_R_TASK_REF`
--
ALTER TABLE `AS_GSS_TMG_R_TASK_REF`
  ADD CONSTRAINT `AS_GSS_TMG_rtaskref_dcploadcontext` FOREIGN KEY (`TASK_REF_DOC_UPLOAD_ID`) REFERENCES `AS_GSS_TMG_R_TASK_REF_DOC_UPLOAD` (`TASK_REF_DOC_UPLOAD_ID`),
  ADD CONSTRAINT `AS_GSS_TMG_rtaskref_taskcategory` FOREIGN KEY (`TASK_CATEGORY_ID`) REFERENCES `AS_GSS_TMG_R_TASK_CATEGORY` (`TASK_CATEGORY_ID`),
  ADD CONSTRAINT `AS_GSS_TMG_rtskref_taskbehavirtype` FOREIGN KEY (`TASK_BEHAVIOR_TYPE_ID`) REFERENCES `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE` (`TASK_BEHAVIOR_TYPE_ID`);

--
-- Constraints for table `AS_GSS_TMG_R_TASK_REF_DOC_UPLOAD`
--
ALTER TABLE `AS_GSS_TMG_R_TASK_REF_DOC_UPLOAD`
  ADD CONSTRAINT `asgsstmgrtskrfdcpldcn_dctmplt` FOREIGN KEY (`DOC_TEMPLATE`) REFERENCES `AS_GSS_R_DOCUMENT_TEMPLATE` (`DOCUMENT_TEMPLATE_ID`),
  ADD CONSTRAINT `asgsstmgrtskrfdcpldcnt_dctypd` FOREIGN KEY (`DOC_TYPE_ID`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`);

--
-- Constraints for table `AS_GSS_TMG_R_TEMPLATE`
--
ALTER TABLE `AS_GSS_TMG_R_TEMPLATE`
  ADD CONSTRAINT `asgsstmgrtemplate_dctemplate` FOREIGN KEY (`DOC_TEMPLATE`) REFERENCES `AS_GSS_R_DOCUMENT_TEMPLATE` (`DOCUMENT_TEMPLATE_ID`),
  ADD CONSTRAINT `asgsstmgrtemplate_operation` FOREIGN KEY (`OPERATION`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`),
  ADD CONSTRAINT `asgsstmgrtemplte_templtetype` FOREIGN KEY (`TEMPLATE_TYPE`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`);

--
-- Constraints for table `AS_GSS_TMG_R_TEMPLATE_TASK`
--
ALTER TABLE `AS_GSS_TMG_R_TEMPLATE_TASK`
  ADD CONSTRAINT `AS_GSS_TMG_rtemplatetask_taskref` FOREIGN KEY (`TASK_REF_ID`) REFERENCES `AS_GSS_TMG_R_TASK_REF` (`TASK_REF_ID`),
  ADD CONSTRAINT `AS_GSS_TMG_rtemplte_templtetskmaps` FOREIGN KEY (`TEMPLATE_ID`) REFERENCES `AS_GSS_TMG_R_TEMPLATE` (`TEMPLATE_ID`),
  ADD CONSTRAINT `asgsstmgrtempltetsk_drtinnit` FOREIGN KEY (`DURATION_UNIT`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`);

--
-- Constraints for table `AS_GSS_TMG_R_TEMPLATE_TASK_PRECEDNT`
--
ALTER TABLE `AS_GSS_TMG_R_TEMPLATE_TASK_PRECEDNT`
  ADD CONSTRAINT `AS_GSS_TMG_rtemplatetask_prectasks` FOREIGN KEY (`TEMPLATE_TASK_ID`) REFERENCES `AS_GSS_TMG_R_TEMPLATE_TASK` (`TEMPLATE_TASK_ID`);

--
-- Constraints for table `AS_GSS_TMG_TASK`
--
ALTER TABLE `AS_GSS_TMG_TASK`
  ADD CONSTRAINT `AS_GSS_TMG_task_docuploadcontext` FOREIGN KEY (`TASK_DOC_UPLOAD_ID`) REFERENCES `AS_GSS_TMG_TASK_DOC_UPLOAD` (`TASK_DOC_UPLOAD_ID`),
  ADD CONSTRAINT `AS_GSS_TMG_task_review` FOREIGN KEY (`TASK_REVIEW_ID`) REFERENCES `AS_GSS_TMG_TASK_REVIEW` (`TASK_REVIEW_ID`),
  ADD CONSTRAINT `AS_GSS_TMG_task_taskbehaviortype` FOREIGN KEY (`TASK_BEHAVIOR_TYPE_ID`) REFERENCES `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE` (`TASK_BEHAVIOR_TYPE_ID`),
  ADD CONSTRAINT `AS_GSS_TMG_task_taskcategory` FOREIGN KEY (`TASK_CATEGORY_ID`) REFERENCES `AS_GSS_TMG_R_TASK_CATEGORY` (`TASK_CATEGORY_ID`),
  ADD CONSTRAINT `AS_GSS_TMG_task_taskstatus` FOREIGN KEY (`TASK_STATUS_ID`) REFERENCES `AS_GSS_TMG_R_TASK_STATUS` (`TASK_STATUS_ID`),
  ADD CONSTRAINT `asgsstmgtask_durationunit` FOREIGN KEY (`DURATION_UNIT`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`),
  ADD CONSTRAINT `asgsstmgtask_evaluation` FOREIGN KEY (`EVALUATION_ID`) REFERENCES `AS_GSS_EVALUATION` (`EVALUATION_ID`),
  ADD CONSTRAINT `asgsstmgtask_taskchecklist` FOREIGN KEY (`CHECKLIST_ID`) REFERENCES `AS_GSS_TMG_TASK_CHECKLIST` (`CHECKLIST_ID`);

--
-- Constraints for table `AS_GSS_TMG_TASK_ACTION_AUDIT`
--
ALTER TABLE `AS_GSS_TMG_TASK_ACTION_AUDIT`
  ADD CONSTRAINT `AS_GSS_TMG_auditwork_review` FOREIGN KEY (`TASK_REVIEW_ID`) REFERENCES `AS_GSS_TMG_TASK_REVIEW` (`TASK_REVIEW_ID`),
  ADD CONSTRAINT `AS_GSS_TMG_auditwork_task` FOREIGN KEY (`TASK_ID`) REFERENCES `AS_GSS_TMG_TASK` (`TASK_ID`),
  ADD CONSTRAINT `AS_GSS_TMG_taskactinadit_taskactin` FOREIGN KEY (`TASK_ACTION_ID`) REFERENCES `AS_GSS_TMG_R_TASK_ACTION` (`TASK_ACTION_ID`);

--
-- Constraints for table `AS_GSS_TMG_TASK_CHECKLIST`
--
ALTER TABLE `AS_GSS_TMG_TASK_CHECKLIST`
  ADD CONSTRAINT `asgsstmgtskchecklist_listtype` FOREIGN KEY (`LIST_TYPE`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`);

--
-- Constraints for table `AS_GSS_TMG_TASK_DOC_UPLOAD`
--
ALTER TABLE `AS_GSS_TMG_TASK_DOC_UPLOAD`
  ADD CONSTRAINT `asgsstmgtskdcpldcntxt_dctmplt` FOREIGN KEY (`DOC_TEMPLATE`) REFERENCES `AS_GSS_R_DOCUMENT_TEMPLATE` (`DOCUMENT_TEMPLATE_ID`),
  ADD CONSTRAINT `asgsstmgtskdcpldcntxt_dctypid` FOREIGN KEY (`DOC_TYPE_ID`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`);

--
-- Constraints for table `AS_GSS_TMG_TASK_PRECEDENT`
--
ALTER TABLE `AS_GSS_TMG_TASK_PRECEDENT`
  ADD CONSTRAINT `AS_GSS_TMG_task_taskprecedents` FOREIGN KEY (`TASK_ID`) REFERENCES `AS_GSS_TMG_TASK` (`TASK_ID`);

--
-- Constraints for table `AS_GSS_TMG_TASK_REVIEW`
--
ALTER TABLE `AS_GSS_TMG_TASK_REVIEW`
  ADD CONSTRAINT `asgsstmgtaskreview_decision` FOREIGN KEY (`DECISION`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`);
COMMIT;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 569, 2133);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************************
-- [570] Add FK constraint to AS_GSS_EVALUATION_PHASE
-- ****************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 570, "Add FK constraint to AS_GSS_EVALUATION_PHASE",539,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVALUATION_PHASE`
  ADD KEY `asgssevalatin_evaltnduration` (`DURATION_UNIT`),
  ADD CONSTRAINT `asgssevalatin_evaltnduration` FOREIGN KEY (`DURATION_UNIT`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 570, 539);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************************************
-- [571] Create EVALUATION_DOC_ADDITIONAL_INFO View
-- ****************************************************************
-- View to join various tables related to the evaluation document
-- ****************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 571, "Create EVALUATION_DOC_ADDITIONAL_INFO View",540,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE OR REPLACE VIEW AS_GSS_V_EVALUATION_DOC_ADDITIONAL_INFO AS
SELECT d.*, c.CRITERIA_NAME, c.FACTOR_NUMBER, v.LEGAL_NAME, dt.REF_LABEL AS DOC_TYPE_LABEL FROM AS_GSS_EVALUATION_DOCUMENT d LEFT JOIN AS_GSS_CRITERIA c ON (d.CRITERIA_ID = c.CRITERIA_ID) LEFT JOIN AS_GSS_EVALUATION_VENDOR v ON (d.VENDOR_ID = v.VENDOR_ID) LEFT JOIN AS_GSS_R_DATA dt ON (d.DOC_TYPE = dt.REF_DATA_ID);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 571, 540);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *********************************************************
-- [576] Adding IS_WRITE to AS_GSS_EVALUATION_VENDOR table
-- *********************************************************
-- Adding IS_WRITE to AS_GSS_EVALUATION_VENDOR table
-- *********************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 576, "Adding IS_WRITE to AS_GSS_EVALUATION_VENDOR table",545,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVALUATION_VENDOR` ADD `IS_WRITE` TINYINT(1) NULL DEFAULT NULL AFTER `EXPIRATION_DATE`;


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 576, 545);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***********************************************************
-- [577] Adding IS_WRITE to AS_GSS_EVALUATION_DOCUMENT table
-- ***********************************************************
-- Adding IS_WRITE to AS_GSS_EVALUATION_DOCUMENT table
-- ***********************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 577, "Adding IS_WRITE to AS_GSS_EVALUATION_DOCUMENT table",546,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVALUATION_DOCUMENT` ADD `IS_WRITE` TINYINT(1) NULL DEFAULT NULL AFTER `DOCUMENT_TEMPLATE`;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 577, 546);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************
-- [578] Create Rating Table
-- ***************************
-- Create AS_GSS_R_RATING
-- ***************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 578, "Create Rating Table",2238,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE IF NOT EXISTS `AS_GSS_R_RATING` (
	`RATING_ID` int(11) NOT NULL AUTO_INCREMENT,
	`PARENT_RATING_ID` int(11) DEFAULT NULL,
	`DESCRIPTION` varchar(5000) DEFAULT NULL,
	`REF_LABEL` varchar(255) DEFAULT NULL,
	`REF_ICON` varchar(255) DEFAULT NULL,
	`REF_COLOR` varchar(255) DEFAULT NULL,
	`SORT_ORDER` int(11) DEFAULT NULL,
	`IS_ACTIVE` tinyint(1) DEFAULT NULL,
	`CREATED_BY` varchar(255) DEFAULT NULL,
	`CREATED_DATETIME` datetime DEFAULT NULL,
	`MODIFIED_BY` varchar(255) DEFAULT NULL,
	`MODIFIED_DATETIME` datetime DEFAULT NULL,
	PRIMARY KEY (`RATING_ID`)
);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 578, 2238);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *****************************************************************************************
-- [579] Alter the Criteria table to have rating
-- *****************************************************************************************
-- Add column and constraint to AS_GSS_R_RATING table, and remove rankingmethod constraint
-- *****************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 579, "Alter the Criteria table to have rating",548,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE
    `AS_GSS_CRITERIA` ADD `RATING_TYPE_ID` INT NULL DEFAULT NULL;

ALTER TABLE `AS_GSS_CRITERIA`
  ADD KEY `asgsscriteria_ratingtype` (`RATING_TYPE_ID`),
  ADD CONSTRAINT `asgsscriteria_ratingtype` FOREIGN KEY (`RATING_TYPE_ID`) REFERENCES `AS_GSS_R_RATING` (`RATING_ID`);

ALTER TABLE `AS_GSS_CRITERIA`
  DROP FOREIGN KEY `asgsscriteria_rankingmethod`,
  DROP INDEX `asgsscriteria_rankingmethod`,
  DROP `RANKING_METHOD_ID`;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 579, 548);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************************
-- [580] Add default values for RATINGS
-- ***************************************************
-- Insert OOTB values into the AS_GSS_R_RATING table
-- ***************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 580, "Add default values for RATINGS",1091,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_RATING`(
    `RATING_ID`,
    `PARENT_RATING_ID`,
    `REF_LABEL`,
    `REF_ICON`,
    `REF_COLOR`,
    `SORT_ORDER`,
    `IS_ACTIVE`,
    `CREATED_BY`,
    `CREATED_DATETIME`,
    `MODIFIED_BY`,
    `MODIFIED_DATETIME`
)
VALUES(
    1,
    NULL,
    'Color Rating',
    NULL,
    NULL,
    1,
    1,
    'appian.administrator',
    CURRENT_TIMESTAMP,
    'appian.administrator',
    CURRENT_TIMESTAMP
),(
    2,
    NULL,
    'Adjective Rating',
    NULL,
    NULL,
    2,
    1,
    'appian.administrator',
    CURRENT_TIMESTAMP,
    'appian.administrator',
    CURRENT_TIMESTAMP
),(
    3,
    NULL,
    'Risk Adjective Rating',
    NULL,
    NULL,
    3,
    1,
    'appian.administrator',
    CURRENT_TIMESTAMP,
    'appian.administrator',
    CURRENT_TIMESTAMP
),(
    4,
    NULL,
    'Number Rating',
    NULL,
    NULL,
    4,
    1,
    'appian.administrator',
    CURRENT_TIMESTAMP,
    'appian.administrator',
    CURRENT_TIMESTAMP
),(
    5,
    NULL,
    'Confidence Level Rating',
    NULL,
    NULL,
    5,
    1,
    'appian.administrator',
    CURRENT_TIMESTAMP,
    'appian.administrator',
    CURRENT_TIMESTAMP
),(
    6,
    NULL,
    'Acceptable/Unacceptable Rating',
    NULL,
    NULL,
    6,
    1,
    'appian.administrator',
    CURRENT_TIMESTAMP,
    'appian.administrator',
    CURRENT_TIMESTAMP
),(
	7,
	1,
	'Blue',
	NULL,
	NULL,
	1,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	8,
	1,
	'Purple',
	NULL,
	NULL,
	2,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	9,
	1,
	'Green',
	NULL,
	NULL,
	3,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	10,
	1,
	'Yellow',
	NULL,
	NULL,
	4,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	11,
	1,
	'Red',
	NULL,
	NULL,
	5,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	12,
	2,
	'Outstanding',
	NULL,
	NULL,
	1,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	13,
	2,
	'Good',
	NULL,
	NULL,
	2,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	14,
	2,
	'Acceptable',
	NULL,
	NULL,
	3,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	15,
	2,
	'Marginal',
	NULL,
	NULL,
	4,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	16,
	2,
	'Unacceptable',
	NULL,
	NULL,
	5,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	17,
	3,
	'Low',
	NULL,
	NULL,
	1,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	18,
	3,
	'Moderate',
	NULL,
	NULL,
	2,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	19,
	3,
	'High',
	NULL,
	NULL,
	3,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	20,
	4,
	'1',
	NULL,
	NULL,
	1,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	21,
	4,
	'2',
	NULL,
	NULL,
	2,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	22,
	4,
	'3',
	NULL,
	NULL,
	3,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	23,
	4,
	'4',
	NULL,
	NULL,
	4,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	24,
	4,
	'5',
	NULL,
	NULL,
	5,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	25,
	5,
	'Substantial',
	NULL,
	NULL,
	1,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	26,
	5,
	'Satisfactory',
	NULL,
	NULL,
	2,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	27,
	5,
	'Limited',
	NULL,
	NULL,
	3,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	28,
	5,
	'No',
	NULL,
	NULL,
	4,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	29,
	5,
	'Unknown',
	NULL,
	NULL,
	5,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	30,
	6,
	'Acceptable',
	NULL,
	NULL,
	1,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
),(
	31,
	6,
	'Unacceptable',
	NULL,
	NULL,
	2,
	1,
	'appian.administrator',
	CURRENT_TIMESTAMP,
	'appian.administrator',
	CURRENT_TIMESTAMP
);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 580, 1091);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *********************************************
-- [582] Insert TEMP status into AS_GSS_R_DATA
-- *********************************************
-- Add the TEMP reference status
-- *********************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 582, "Insert TEMP status into AS_GSS_R_DATA",550,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT IGNORE INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES (34, 'Temp', NULL, 'Evaluation Status', NULL, NULL, '4', '1', 'appian.administrator', '2021-02-12 12:22:09', 'appian.administrator', '2021-02-12 12:22:09');

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 582, 550);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************************************************************************
-- [583] Rename PK column of Rating Table
-- ***************************************************************************************************
-- Rename RATING_ID to REF_RATING_ID in AS_GSS_R_RATING and change the constraint in AS_GSS_CRITERIA
-- ***************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 583, "Rename PK column of Rating Table",558,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_CRITERIA` DROP FOREIGN KEY IF EXISTS asgsscriteria_ratingtype;
ALTER TABLE `AS_GSS_CRITERIA` CHANGE `RATING_TYPE_ID` `REF_RATING_TYPE_ID` INT(11) NULL DEFAULT NULL;
ALTER TABLE `AS_GSS_CRITERIA` DROP INDEX `asgsscriteria_ratingtype`;
ALTER TABLE `AS_GSS_R_RATING` CHANGE `RATING_ID` `REF_RATING_ID` INT(11) NOT NULL AUTO_INCREMENT;
ALTER TABLE `AS_GSS_CRITERIA` DROP FOREIGN KEY IF EXISTS `asgssevaluation_criteria`; 
ALTER TABLE `AS_GSS_CRITERIA` ADD CONSTRAINT `asgsscriteria_evaluation` FOREIGN KEY (`EVALUATION_ID`) REFERENCES `AS_GSS_EVALUATION`(`EVALUATION_ID`) ON DELETE RESTRICT ON UPDATE RESTRICT; 
ALTER TABLE `AS_GSS_CRITERIA` ADD CONSTRAINT `asgsscriteria_ref_rating` FOREIGN KEY (`REF_RATING_TYPE_ID`) REFERENCES `AS_GSS_R_RATING`(`REF_RATING_ID`) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 583, 558);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ********************************************
-- [584] Create Table AS_GSS_RATING
-- ********************************************
-- Create Table AS_GSS_RATING and Constraints
-- ********************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 584, "Create Table AS_GSS_RATING",2239,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE IF NOT EXISTS `AS_GSS_RATING` (
  `RATING_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `PARENT_RATING_ID` int(11) DEFAULT NULL,
  `EVALUATION_ID` int(11) DEFAULT NULL,
  `REF_RATING_ID` int(11) DEFAULT NULL,
  `DESCRIPTION` varchar(5000) DEFAULT NULL,
  `LABEL` varchar(255) DEFAULT NULL,
  `ICON` varchar(255) DEFAULT NULL,
  `COLOR` varchar(255) DEFAULT NULL,
  `SORT_ORDER` int(11) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` bit(1) DEFAULT NULL
);

ALTER TABLE `AS_GSS_RATING`
  ADD KEY `asgssrating_evaluationid` (`EVALUATION_ID`),
  ADD KEY `asgssrating_refratingid` (`REF_RATING_ID`);

  ALTER TABLE `AS_GSS_RATING`
  ADD CONSTRAINT `asgssrating_evaluationid` FOREIGN KEY (`EVALUATION_ID`) REFERENCES `AS_GSS_EVALUATION` (`EVALUATION_ID`),
  ADD CONSTRAINT `asgssrating_refratingid` FOREIGN KEY (`REF_RATING_ID`) REFERENCES `AS_GSS_R_RATING`(`REF_RATING_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 584, 2239);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ******************************************
-- [585] Add new columns to AS_GSS_TMG_TASK
-- ******************************************
-- Add new columns to AS_GSS_TMG_TASK
-- ******************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 585, "Add new columns to AS_GSS_TMG_TASK",2480,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_TMG_TASK` ADD `VENDOR_ID` INT(11) NULL DEFAULT NULL AFTER `REVIEW_COMMENT_ID`,
ADD `CRITERIA_ID` INT(11) NULL DEFAULT NULL AFTER `VENDOR_ID`,
ADD `STRENGTH` VARCHAR(1) NULL DEFAULT NULL AFTER `CRITERIA_ID`,
ADD `WEAKNESS` VARCHAR(1) NULL DEFAULT NULL AFTER `STRENGTH`,
ADD `JUSTIFICATION` TEXT NULL DEFAULT NULL AFTER `WEAKNESS`,
ADD `ADDITIONAL_COMMENT` VARCHAR(1) NULL DEFAULT NULL AFTER `JUSTIFICATION`,
ADD `FINAL_RATING_ID` INT(11) NULL DEFAULT NULL AFTER `ADDITIONAL_COMMENT`;

ALTER TABLE `AS_GSS_TMG_TASK` ADD CONSTRAINT `asgsstmgtask_vendor` FOREIGN KEY (`VENDOR_ID`) REFERENCES `AS_GSS_EVALUATION_VENDOR`(`VENDOR_ID`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `AS_GSS_TMG_TASK` ADD CONSTRAINT `asgsstmgtask_criteria` FOREIGN KEY (`CRITERIA_ID`) REFERENCES `AS_GSS_CRITERIA`(`CRITERIA_ID`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `AS_GSS_TMG_TASK` ADD CONSTRAINT `asgsstmgtask_rating` FOREIGN KEY (`FINAL_RATING_ID`) REFERENCES `AS_GSS_RATING`(`RATING_ID`) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 585, 2480);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************************
-- [586] Add new column to AS_GSS_EVALUATION_DOCUMENT
-- ****************************************************
-- Add new column to AS_GSS_EVALUATION_DOCUMENT
-- ****************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 586, "Add new column to AS_GSS_EVALUATION_DOCUMENT",561,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVALUATION_DOCUMENT` ADD `TASK_ID` INT(11) NULL DEFAULT NULL AFTER `VENDOR_ID`;
ALTER TABLE `AS_GSS_EVALUATION_DOCUMENT` ADD CONSTRAINT `asgssevaluation_task` FOREIGN KEY (`TASK_ID`) 
REFERENCES `AS_GSS_TMG_TASK`(`TASK_ID`) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 586, 561);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *****************************************
-- [587] Add new column to AS_GSS_CRITERIA
-- *****************************************
-- Add new column to AS_GSS_CRITERIA
-- *****************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 587, "Add new column to AS_GSS_CRITERIA",562,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_CRITERIA` ADD `RATING_TYPE_ID` INT(11) NULL DEFAULT NULL AFTER `REF_RATING_TYPE_ID`;
ALTER TABLE `AS_GSS_CRITERIA` ADD CONSTRAINT `asgsscriteria_rating` FOREIGN KEY (`RATING_TYPE_ID`) REFERENCES `AS_GSS_RATING`(`RATING_ID`) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 587, 562);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *********************************************************************************************
-- [588] Alter GSS FIELDS tables
-- *********************************************************************************************
-- Changed the datatype of OLD_VALUE and NEW_VALUE columns from varchar(4000) to varchar(5000)
-- *********************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 588, "Alter GSS FIELDS tables",563,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_A_R_EVALUATION_FIELD` MODIFY COLUMN `OLD_VALUE` varchar(5000);
ALTER TABLE `AS_GSS_A_R_EVALUATION_FIELD` MODIFY COLUMN `NEW_VALUE` varchar(5000);
ALTER TABLE `AS_GSS_A_R_CRITERIA_FIELD` MODIFY COLUMN `OLD_VALUE` varchar(5000);
ALTER TABLE `AS_GSS_A_R_CRITERIA_FIELD` MODIFY COLUMN `NEW_VALUE` varchar(5000);
ALTER TABLE `AS_GSS_A_R_EVALUATOR_TEAM_FIELD` MODIFY COLUMN `OLD_VALUE` varchar(5000);
ALTER TABLE `AS_GSS_A_R_EVALUATOR_TEAM_FIELD` MODIFY COLUMN `NEW_VALUE` varchar(5000);
ALTER TABLE `AS_GSS_A_R_TEAM_MEMBERSHIP_FIELD` MODIFY COLUMN `OLD_VALUE` varchar(5000);
ALTER TABLE `AS_GSS_A_R_TEAM_MEMBERSHIP_FIELD` MODIFY COLUMN `NEW_VALUE` varchar(5000);
ALTER TABLE `AS_GSS_A_R_EVALUATION_VENDOR_FIELD` MODIFY COLUMN `OLD_VALUE` varchar(5000);
ALTER TABLE `AS_GSS_A_R_EVALUATION_VENDOR_FIELD` MODIFY COLUMN `NEW_VALUE` varchar(5000);
ALTER TABLE `AS_GSS_A_R_EVALUATION_VENDOR_BUSINESS_TYPE_FIELD` MODIFY COLUMN `OLD_VALUE` varchar(5000);
ALTER TABLE `AS_GSS_A_R_EVALUATION_VENDOR_BUSINESS_TYPE_FIELD` MODIFY COLUMN `NEW_VALUE` varchar(5000);
ALTER TABLE `AS_GSS_A_R_EVALUATION_PHASE_FIELD` MODIFY COLUMN `OLD_VALUE` varchar(5000);
ALTER TABLE `AS_GSS_A_R_EVALUATION_PHASE_FIELD` MODIFY COLUMN `NEW_VALUE` varchar(5000);
ALTER TABLE `AS_GSS_A_R_CRITERIA_ASSIGNMENTS_FIELD` MODIFY COLUMN `OLD_VALUE` varchar(5000);
ALTER TABLE `AS_GSS_A_R_CRITERIA_ASSIGNMENTS_FIELD` MODIFY COLUMN `NEW_VALUE` varchar(5000);
ALTER TABLE `AS_GSS_A_R_EVALUATION_DOCUMENT_FIELD` MODIFY COLUMN `OLD_VALUE` varchar(5000);
ALTER TABLE `AS_GSS_A_R_EVALUATION_DOCUMENT_FIELD` MODIFY COLUMN `NEW_VALUE` varchar(5000);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 588, 563);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **************************************************
-- [589] Create new table AS_GSS_EvaluationComments
-- **************************************************
-- Creating new tables to capture comments
-- **************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 589, "Create new table AS_GSS_EvaluationComments",2240,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE `AS_GSS_EVALUATION_COMMENTS` (
  `EVALUATION_COMMENT_ID` int(11) NOT NULL AUTO_INCREMENT,
  `EVALUATION_ID` int(11) DEFAULT NULL,
  `TASK` int(11) DEFAULT NULL,
  `COMMENT` varchar(4000) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_DELETED` tinyint(1) DEFAULT NULL,
PRIMARY KEY (`EVALUATION_COMMENT_ID`)
);

ALTER TABLE `AS_GSS_EVALUATION_COMMENTS`
  ADD KEY `asgssevaluationcomments_task` (`TASK`);

ALTER TABLE `AS_GSS_EVALUATION_COMMENTS`
  ADD CONSTRAINT `asgssevaluationcomments_task` FOREIGN KEY (`TASK`) REFERENCES `AS_GSS_TMG_TASK` (`TASK_ID`);
ALTER TABLE `AS_GSS_EVALUATION_COMMENTS` ADD CONSTRAINT `asgssevaluationcomments_evaluation` FOREIGN KEY (`EVALUATION_ID`) REFERENCES `AS_GSS_EVALUATION`(`EVALUATION_ID`) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 589, 2240);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *********************************************
-- [590] Alter table AS_GSS_TEAM_MEMBERSHIP
-- *********************************************
-- Adding constraint to AS_GSS_TEAM_MEMBERSHIP
-- *********************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 590, "Alter table AS_GSS_TEAM_MEMBERSHIP",565,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_TEAM_MEMBERSHIP`
  ADD KEY `asgssevltrteam_member` (`MEMBER`),
  ADD CONSTRAINT `asgssevltrteam_member` FOREIGN KEY (`MEMBER`) REFERENCES `AS_GSS_USER` (`USERNAME`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 590, 565);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *************************************
-- [591] Alter table AS_GSS_CRITERIA
-- *************************************
-- Adding constrain to AS_GSS_CRITERIA
-- *************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 591, "Alter table AS_GSS_CRITERIA",566,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_CRITERIA`
  ADD `EVALUATOR_TEAM_ID` int(11) DEFAULT NULL,
 ADD CONSTRAINT asgsscriteria_evltr_team FOREIGN KEY (EVALUATOR_TEAM_ID) REFERENCES AS_GSS_EVALUATOR_TEAM(TEAM_ID) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 591, 566);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **************************************************
-- [592] Alter table AS_GSS_CRITERIA_ASSIGNMENTS
-- **************************************************
-- Adding constraint to AS_GSS_CRITERIA_ASSIGNMENTS
-- **************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 592, "Alter table AS_GSS_CRITERIA_ASSIGNMENTS",567,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_CRITERIA_ASSIGNMENTS`
  ADD KEY `asgss_assignee_user` (`ASSIGNEE`),
  ADD CONSTRAINT `asgss_assignee_user` FOREIGN KEY (`ASSIGNEE`) REFERENCES `AS_GSS_USER` (`USERNAME`);

  ALTER TABLE `AS_GSS_CRITERIA_ASSIGNMENTS` DROP FOREIGN KEY asgss_evltr_team;
ALTER TABLE `AS_GSS_CRITERIA_ASSIGNMENTS` DROP `ASSIGNED_TEAM_ID`;




-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 592, 567);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ********************************************************************************
-- [593] Alter GSS Template table - Remove Columns
-- ********************************************************************************
-- Remove columns thresholdAmount, operation from the table AS_GSS_TMG_R_Template
-- ********************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 593, "Alter GSS Template table - Remove Columns",568,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_TMG_R_TEMPLATE` DROP FOREIGN KEY asgsstmgrtemplate_operation;
ALTER TABLE `AS_GSS_TMG_R_TEMPLATE` DROP INDEX `asgsstmgrtemplate_operation`;
ALTER TABLE `AS_GSS_TMG_R_TEMPLATE` DROP COLUMN `THRESHOLD_AMOUNT`;
ALTER TABLE `AS_GSS_TMG_R_TEMPLATE` DROP COLUMN `OPERATION`;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 593, 568);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *****************************************************************************
-- [594] Changing the Subcode type name
-- *****************************************************************************
-- Changing the value from AWARD_ACKNOWLEDGEMENT to EVALUATION_ACKNOWLEDGEMENT
-- *****************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 594, "Changing the Subcode type name",569,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE` SET `BEHAVIOR_SUBTYPE_CODE` = 'EVALUATION_ACKNOWLEDGEMENT' WHERE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE`.`TASK_BEHAVIOR_TYPE_ID` = 6;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 594, 569);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *********************************************************************************************************************************
-- [595] INSERT INTO TMG Task tables for start evaluation tasks
-- *********************************************************************************************************************************
-- INSERT INTO `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE`,`AS_GSS_TMG_R_TASK_CATEGORY` & `AS_GSS_TMG_R_TASK_REF` for start evaluation tasks
-- *********************************************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 595, "INSERT INTO TMG Task tables for start evaluation tasks",570,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE` (`TASK_BEHAVIOR_TYPE_ID`, `BEHAVIOR_TYPE_CODE`, `BEHAVIOR_DISPLAY_NAME`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`, `BEHAVIOR_SUBTYPE_CODE`, `CONFIGURATION_LEVEL_CODE`, `ICON`, `COLOR`) VALUES ('11', 'DATA_ENTRY', 'AS.GSS.TMG.Tasks.txt_BehaviorTypeCompleteEvaluation', 'appian.administrator', '2020-03-03 14:02:09', 'appian.administrator', '2020-03-03 14:02:09', 'COMPLETE_EVALUATION', 'SYSTEM', 'list-ol', '#2BAAD5');

INSERT INTO `AS_GSS_TMG_R_TASK_CATEGORY` (`TASK_CATEGORY_ID`, `CATEGORY_NAME`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`, `IS_ACTIVE`) VALUES ('40', 'Complete Evaluation', 'appian.administrator', '2021-03-03 21:50:36', 'appian.administrator', '2021-03-03 21:50:36', '0');

INSERT INTO `AS_GSS_TMG_R_TASK_REF` (`TASK_REF_ID`, `TASK_NAME`, `TASK_BEHAVIOR_TYPE_ID`, `TASK_CATEGORY_ID`, `DEFAULT_GROUP_ASSIGNEE`, `TASK_REF_DOC_UPLOAD_ID`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES ('90', 'Complete Evaluation', '11', '40', NULL, NULL, 'appian.administrator', '2021-03-03 22:26:53', 'appian.administrator', '2021-03-03 22:26:53');

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 595, 570);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *****************************************************
-- [596] Insert into AS_GSS_TMG_R_TASK_ACTION
-- *****************************************************
-- Insert new action entry to AS_GSS_TMG_R_TASK_ACTION
-- *****************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 596, "Insert into AS_GSS_TMG_R_TASK_ACTION",571,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_TMG_R_TASK_ACTION` (`TASK_ACTION_ID`, `ACTION_DISPLAY_NAME`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES
(7, 'AS.GSS.TMG.Tasks.txt_ActionUpdated', 'appian.administrator', SYSDATE(), 'appian.administrator', SYSDATE());

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 596, 571);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***********************************************************
-- [598] Add contracting officer column to as_gss_evaluation
-- ***********************************************************
-- Add contracting officer column to as_gss_evaluation
-- ***********************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 598, "Add contracting officer column to as_gss_evaluation",573,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION ADD COLUMN `CONTRACTING_OFFICER` VARCHAR(255) NULL DEFAULT NULL AFTER `EVALUATION_CHIEF`;
ALTER TABLE AS_GSS_EVALUATION ADD COLUMN `CONTRACTING_SPECIALIST` VARCHAR(255) NULL DEFAULT NULL AFTER `CONTRACTING_OFFICER`;
ALTER TABLE `AS_GSS_EVALUATION`
 ADD CONSTRAINT `contractingOfficer_user` FOREIGN KEY (`CONTRACTING_OFFICER`) REFERENCES `AS_GSS_USER` (`USERNAME`),
 ADD CONSTRAINT `contractingSpecialist_User` FOREIGN KEY (`CONTRACTING_SPECIALIST`) REFERENCES `AS_GSS_USER` (`USERNAME`);


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 598, 573);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ************************************************************
-- [601] Insert task status and Due status into AS_GSS_R_DATA
-- ************************************************************
-- Add the task status and due status ref type values
-- ************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 601, "Insert task status and Due status into AS_GSS_R_DATA",575,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES
(35,'Not Started', NULL,'Task Status',NULL,NULL,1,1, CURRENT_USER,CURRENT_TIMESTAMP,CURRENT_USER, CURRENT_TIMESTAMP),
(36,'In Progress', NULL,'Task Status',NULL,NULL,2,1, CURRENT_USER,CURRENT_TIMESTAMP,CURRENT_USER, CURRENT_TIMESTAMP),
(37,'Completed', NULL,'Task Status',NULL,NULL,3,1, CURRENT_USER,CURRENT_TIMESTAMP,CURRENT_USER, CURRENT_TIMESTAMP),
(38,'Not Started', NULL,'Due Status','circle-o','SECONDARY',1,1, CURRENT_USER,CURRENT_TIMESTAMP,CURRENT_USER, CURRENT_TIMESTAMP),
(39,'Due Soon', NULL,'Due Status','clock-o','#ffd11a',3,1, CURRENT_USER,CURRENT_TIMESTAMP,CURRENT_USER, CURRENT_TIMESTAMP),
(40,'OverDue', NULL,'Due Status','exclamation-circle','NEGATIVE',4,1, CURRENT_USER,CURRENT_TIMESTAMP,CURRENT_USER, CURRENT_TIMESTAMP),
(41,'On Track', NULL,'Due Status','check-circle','POSITIVE',2,1, CURRENT_USER,CURRENT_TIMESTAMP,CURRENT_USER, CURRENT_TIMESTAMP);


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 601, 575);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************
-- [602] Update AS_GSS_R_RATING
-- ***************************************
-- Update AS_GSS_R_RATING - "REF_COLOR" 
-- ***************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 602, "Update AS_GSS_R_RATING",576,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE `AS_GSS_R_RATING` 
SET `REF_COLOR` = '#12AEFE' WHERE `AS_GSS_R_RATING`.`REF_RATING_ID` = 7;
UPDATE `AS_GSS_R_RATING` 
SET `REF_COLOR` = '#7454FF' WHERE `AS_GSS_R_RATING`.`REF_RATING_ID` = 8;
UPDATE `AS_GSS_R_RATING` 
SET `REF_COLOR` = '#78DF4F' WHERE `AS_GSS_R_RATING`.`REF_RATING_ID` = 9;
UPDATE `AS_GSS_R_RATING` 
SET `REF_COLOR` = '#FFD800' WHERE `AS_GSS_R_RATING`.`REF_RATING_ID` = 10;
UPDATE `AS_GSS_R_RATING` 
SET `REF_COLOR` = '#F84D58' WHERE `AS_GSS_R_RATING`.`REF_RATING_ID` = 11;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 602, 576);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *****************************************************************************
-- [603] Remove IS_WRITE
-- *****************************************************************************
-- Removing IS_WRITE from the evaluation document and evaluation vendor tables
-- *****************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 603, "Remove IS_WRITE",577,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION_DOCUMENT DROP COLUMN IS_WRITE;
ALTER TABLE AS_GSS_EVALUATION_VENDOR DROP COLUMN IS_WRITE;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 603, 577);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************************************
-- [604] Insert TAsk action item in AS_GSS_TMG_R_TASK_ACTION
-- ***************************************************************
-- Add new row to AS_GSS_TMG_R_TASK_ACTION for Edit due dates RA
-- ***************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 604, "Insert TAsk action item in AS_GSS_TMG_R_TASK_ACTION",578,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_TMG_R_TASK_ACTION` (`TASK_ACTION_ID`, `ACTION_DISPLAY_NAME`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES (8, 'AS.GSS.TMG.Tasks.txt_EditDueDates', 'appian.administrator', NOW(), 'appian.administrator', NOW());

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 604, 578);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *******************************************************************************************
-- [605] ALTER as_gss_criteria and as_gss_evaluation
-- *******************************************************************************************
-- add completed on/by columns to as_gss_critera and completedBy column to as_gss_evaluation
-- *******************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 605, "ALTER as_gss_criteria and as_gss_evaluation",579,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_CRITERIA`
  ADD COLUMN `COMPLETED_ON` DATE NULL DEFAULT NULL after `DUE_DATE`;

ALTER TABLE `AS_GSS_CRITERIA`
  ADD COLUMN `COMPLETED_BY` VARCHAR(255) NULL DEFAULT NULL after `COMPLETED_ON`;

ALTER TABLE `AS_GSS_CRITERIA`
  ADD CONSTRAINT `completedby_usercriteria` FOREIGN KEY (`COMPLETED_BY`) REFERENCES
  `AS_GSS_USER` (`USERNAME`);

ALTER TABLE `AS_GSS_EVALUATION`
  ADD COLUMN `COMPLETED_BY` VARCHAR(255) NULL DEFAULT NULL after `EVALUATION_COMPLETION_DATE`;

ALTER TABLE `AS_GSS_EVALUATION`
  ADD CONSTRAINT `completedby_userevaluation` FOREIGN KEY (`COMPLETED_BY`) REFERENCES
  `AS_GSS_USER` (`USERNAME`); 

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 605, 579);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *********************************************************************************
-- [606] Inserting evaluation template data
-- *********************************************************************************
-- Inserting Recommendation and consensus template into AS_GSS_R_DOCUMENT_TEMPLATE
-- *********************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 606, "Inserting evaluation template data",580,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DOCUMENT_TEMPLATE` (`DOCUMENT_TEMPLATE_ID`, `DOCUMENT_NAME`, `FILE_TYPE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`, `IS_ACTIVE`) VALUES ('2', 'Recommendation Template', 'DOCX', 'appian.administrator\r\n', '2021-03-11 10:11:54', 'appian.administrator\r\n', '2021-03-11 10:11:54', '1');

INSERT INTO `AS_GSS_R_DOCUMENT_TEMPLATE` (`DOCUMENT_TEMPLATE_ID`, `DOCUMENT_NAME`, `FILE_TYPE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`, `IS_ACTIVE`) VALUES ('3', 'Consensus Template', 'DOCX', 'appian.administrator\r\n', '2021-03-11 10:11:54', 'appian.administrator\r\n', '2021-03-11 10:11:54', '1');

DELETE FROM `AS_GSS_R_DOCUMENT_TEMPLATE` WHERE `DOCUMENT_TEMPLATE_ID`=1;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 606, 580);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *****************************************************************************************
-- [609] Add new Column REF_PHASE_ID and foreign key constrain
-- *****************************************************************************************
-- Add new Column REF_PHASE_ID and foreign key constraint in AS_GSS_EVALUATION_PHASE table
-- *****************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 609, "Add new Column REF_PHASE_ID and foreign key constrain",581,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION_PHASE
ADD REF_PHASE_ID int(11) NULL AFTER EVALUATION_PHASE_ID,
ADD CONSTRAINT fk_refPhaseId FOREIGN KEY (REF_PHASE_ID) REFERENCES AS_GSS_TMG_R_TASK_CATEGORY(TASK_CATEGORY_ID);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 609, 581);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **********************************************************************************************
-- [611] Change Select Process to Select Approach
-- **********************************************************************************************
-- Changing the value in the table AS_GSS_TMG_R_TASK_REF from Select Process to Select Approach
-- **********************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 611, "Change Select Process to Select Approach",585,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE `AS_GSS_TMG_R_TASK_REF` SET `TASK_NAME` = 'Select Approach' WHERE `AS_GSS_TMG_R_TASK_REF`.`TASK_REF_ID` = 1;
UPDATE `AS_GSS_TMG_R_TASK_CATEGORY` SET `CATEGORY_NAME` = 'Approach Setup' WHERE `AS_GSS_TMG_R_TASK_CATEGORY`.`TASK_CATEGORY_ID` = 1;



-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 611, 585);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *************************************************************************************************************************************************
-- [613] Migration script to update values for REF_PHASE_ID in AS_GSS_EVALUATION_PHASE
-- *************************************************************************************************************************************************
-- Migration script to update values for REF_PHASE_ID in AS_GSS_EVALUATION_PHASE from column TASK_CATEGORY_ID in table AS_GSS_TMG_R_TASK_CATEGORY 
-- *************************************************************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 613, "Migration script to update values for REF_PHASE_ID in AS_GSS_EVALUATION_PHASE",583,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE
    AS_GSS_EVALUATION_PHASE EP
LEFT JOIN(
    SELECT
        CATEGORY_NAME,
        TASK_CATEGORY_ID
    FROM
         AS_GSS_TMG_R_TASK_CATEGORY
) TC
ON
    EP.PHASE_NAME = TC.CATEGORY_NAME
SET
    EP.REF_PHASE_ID = IF(
        ISNULL(TC.TASK_CATEGORY_ID),
        NULL,
        TC.TASK_CATEGORY_ID
    );


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 613, 583);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *****************************************************************
-- [614] Drop Column PHASE_NAME from AS_GSS_EVALUATION_PHASE table
-- *****************************************************************
-- Drop Column PHASE_NAME from AS_GSS_EVALUATION_PHASE
-- *****************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 614, "Drop Column PHASE_NAME from AS_GSS_EVALUATION_PHASE table",584,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION_PHASE DROP COLUMN PHASE_NAME; 

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 614, 584);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***********************************************
-- [714] Update AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE 
-- ***********************************************
-- Update AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE 
-- ***********************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 714, "Update AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE ",654,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE` 
SET `BEHAVIOR_DISPLAY_NAME` = 'txt_BehaviorTypeConfirmation' WHERE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE`.`TASK_BEHAVIOR_TYPE_ID` = 1;
UPDATE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE` 
SET `BEHAVIOR_DISPLAY_NAME` = 'txt_BehaviorTypeReview' WHERE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE`.`TASK_BEHAVIOR_TYPE_ID` = 2;
UPDATE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE` 
SET `BEHAVIOR_DISPLAY_NAME` = 'txt_BehaviorTypeAttachDocument' WHERE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE`.`TASK_BEHAVIOR_TYPE_ID` = 3;
UPDATE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE` 
SET `BEHAVIOR_DISPLAY_NAME` = 'txt_BehaviorTypeProcessSetup' WHERE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE`.`TASK_BEHAVIOR_TYPE_ID` = 4;
UPDATE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE` 
SET `BEHAVIOR_DISPLAY_NAME` = 'txt_BehaviorTypeDocumentWithTemplate' WHERE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE`.`TASK_BEHAVIOR_TYPE_ID` = 5;
UPDATE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE` 
SET `BEHAVIOR_DISPLAY_NAME` = 'txt_BehaviorTypeAcknowledge' WHERE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE`.`TASK_BEHAVIOR_TYPE_ID` = 6;
UPDATE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE` 
SET `BEHAVIOR_DISPLAY_NAME` = 'txt_BehaviorTypeReview' WHERE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE`.`TASK_BEHAVIOR_TYPE_ID` = 7;
UPDATE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE` 
SET `BEHAVIOR_DISPLAY_NAME` = 'txt_BehaviorTypeConfirmation' WHERE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE`.`TASK_BEHAVIOR_TYPE_ID` = 8;
UPDATE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE` 
SET `BEHAVIOR_DISPLAY_NAME` = 'txt_BehaviorTypeDocumentWithTemplate' WHERE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE`.`TASK_BEHAVIOR_TYPE_ID` = 9;
UPDATE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE` 
SET `BEHAVIOR_DISPLAY_NAME` = 'txt_BehaviorTypeAlertConfirmation' WHERE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE`.`TASK_BEHAVIOR_TYPE_ID` = 10;
UPDATE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE` 
SET `BEHAVIOR_DISPLAY_NAME` = 'txt_BehaviorTypeCompleteEvaluation' WHERE `AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE`.`TASK_BEHAVIOR_TYPE_ID` = 11;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 714, 654);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************
-- [715] Update AS_GSS_TMG_R_TASK_STATUS
-- ***************************************
-- Update AS_GSS_TMG_R_TASK_STATUS
-- ***************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 715, "Update AS_GSS_TMG_R_TASK_STATUS",655,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE `AS_GSS_TMG_R_TASK_STATUS` 
SET `STATUS_DISPLAY_NAME` = 'txt_StatusQueued' WHERE `AS_GSS_TMG_R_TASK_STATUS`.`TASK_STATUS_ID` = 1;
UPDATE `AS_GSS_TMG_R_TASK_STATUS` 
SET `STATUS_DISPLAY_NAME` = 'txt_StatusAssigned' WHERE `AS_GSS_TMG_R_TASK_STATUS`.`TASK_STATUS_ID` = 2;
UPDATE `AS_GSS_TMG_R_TASK_STATUS` 
SET `STATUS_DISPLAY_NAME` = 'txt_StatusInProgress' WHERE `AS_GSS_TMG_R_TASK_STATUS`.`TASK_STATUS_ID` = 3;
UPDATE `AS_GSS_TMG_R_TASK_STATUS` 
SET `STATUS_DISPLAY_NAME` = 'txt_StatusComplete' WHERE `AS_GSS_TMG_R_TASK_STATUS`.`TASK_STATUS_ID` = 4;
UPDATE `AS_GSS_TMG_R_TASK_STATUS` 
SET `STATUS_DISPLAY_NAME` = 'txt_StatusNotNeeded' WHERE `AS_GSS_TMG_R_TASK_STATUS`.`TASK_STATUS_ID` = 5;
UPDATE `AS_GSS_TMG_R_TASK_STATUS` 
SET `STATUS_DISPLAY_NAME` = 'txt_StatusCancelled' WHERE `AS_GSS_TMG_R_TASK_STATUS`.`TASK_STATUS_ID` = 6;
UPDATE `AS_GSS_TMG_R_TASK_STATUS` 
SET `STATUS_DISPLAY_NAME` = 'lbl_All' WHERE `AS_GSS_TMG_R_TASK_STATUS`.`TASK_STATUS_ID` = 7;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 715, 655);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************
-- [716] Update AS_GSS_TMG_R_TASK_ACTION
-- ***************************************
-- Update AS_GSS_TMG_R_TASK_ACTION
-- ***************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",8, "Source Selection 1.0", 716, "Update AS_GSS_TMG_R_TASK_ACTION",656,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE `AS_GSS_TMG_R_TASK_ACTION` 
SET `ACTION_DISPLAY_NAME` = 'txt_ActionCreated' WHERE `AS_GSS_TMG_R_TASK_ACTION`.`TASK_ACTION_ID` = 1;
UPDATE `AS_GSS_TMG_R_TASK_ACTION` 
SET `ACTION_DISPLAY_NAME` = 'txt_ActionAccepted' WHERE `AS_GSS_TMG_R_TASK_ACTION`.`TASK_ACTION_ID` = 2;
UPDATE `AS_GSS_TMG_R_TASK_ACTION` 
SET `ACTION_DISPLAY_NAME` = 'txt_ActionCompleted' WHERE `AS_GSS_TMG_R_TASK_ACTION`.`TASK_ACTION_ID` = 3;
UPDATE `AS_GSS_TMG_R_TASK_ACTION` 
SET `ACTION_DISPLAY_NAME` = 'txt_ActionReassigned' WHERE `AS_GSS_TMG_R_TASK_ACTION`.`TASK_ACTION_ID` = 4;
UPDATE `AS_GSS_TMG_R_TASK_ACTION` 
SET `ACTION_DISPLAY_NAME` = 'txt_ActionAssigned' WHERE `AS_GSS_TMG_R_TASK_ACTION`.`TASK_ACTION_ID` = 5;
UPDATE `AS_GSS_TMG_R_TASK_ACTION` 
SET `ACTION_DISPLAY_NAME` = 'txt_ActionCancelled' WHERE `AS_GSS_TMG_R_TASK_ACTION`.`TASK_ACTION_ID` = 6;
UPDATE `AS_GSS_TMG_R_TASK_ACTION` 
SET `ACTION_DISPLAY_NAME` = 'txt_ActionUpdated' WHERE `AS_GSS_TMG_R_TASK_ACTION`.`TASK_ACTION_ID` = 7;
UPDATE `AS_GSS_TMG_R_TASK_ACTION` 
SET `ACTION_DISPLAY_NAME` = 'txt_EditDueDates' WHERE `AS_GSS_TMG_R_TASK_ACTION`.`TASK_ACTION_ID` = 8;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 8, 716, 656);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;





-- *********************************************************************************************************************************************************************************************
-- Award Management 1.1 / Clause Automation 1.0 / Contract Writing 1.0 / Management Suite 1.0 / ProcureSight v1.0 / Requirements Management 1.3 / Source Selection 1.1 / Vendor Management 1.0
-- *********************************************************************************************************************************************************************************************


-- ***************************************
-- [851] Alter tables for AUTO_INCREMENT
-- ***************************************
-- Update AUTO_INCREMENT to be 1,000,000
-- ***************************************

DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GAM_RunFrameworkScript()
BEGIN
CALL AS_GAM_Initial_Execution("N",14, "Award Management 1.1 / Clause Automation 1.0 / Contract Writing 1.0 / Management Suite 1.0 / ProcureSight v1.0 / Requirements Management 1.3 / Source Selection 1.1 / Vendor Management 1.0", 851, "Alter tables for AUTO_INCREMENT",961,  @AS_GAM_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GAM_R_BUSINESS_TYPE AUTO_INCREMENT = 1000000;
ALTER TABLE AS_GAM_R_COUNTRY AUTO_INCREMENT = 1000000;
ALTER TABLE AS_GAM_R_STATE AUTO_INCREMENT = 1000000;

-- END SCRIPT CONTENT ---
 
CALL AS_GAM_Update_Execution(@AS_GAM_scriptExecuteId, 14, 851, 961);
END IF;
END $$
DELIMITER ;

CALL AS_GAM_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;





-- **********************
-- Source Selection 1.1
-- **********************


-- *****************************************************************
-- [725] Create table AS_GSS_FACTOR_DOCUMENT_MAPPING
-- *****************************************************************
-- Create table AS_GSS_FACTOR_DOCUMENT_MAPPING and its constraints
-- *****************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",18, "Source Selection 1.1", 725, "Create table AS_GSS_FACTOR_DOCUMENT_MAPPING",2241,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE `AS_GSS_FACTOR_DOCUMENT_MAPPING` (
  `DOCUMENT_MAPPING_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `DOCUMENT_ID` int(11) DEFAULT NULL,
  `FACTOR_ID` int(11) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL
);

ALTER TABLE `AS_GSS_FACTOR_DOCUMENT_MAPPING`
  ADD KEY `asgssfctrdcmentmpping_factr` (`FACTOR_ID`),
  ADD KEY `asgssfctrdcmntmpping_dcment` (`DOCUMENT_ID`);

ALTER TABLE `AS_GSS_FACTOR_DOCUMENT_MAPPING`
  ADD CONSTRAINT `asgssfctrdcmentmpping_factr` FOREIGN KEY (`FACTOR_ID`) REFERENCES `AS_GSS_CRITERIA` (`CRITERIA_ID`),
  ADD CONSTRAINT `asgssfctrdcmntmpping_dcment` FOREIGN KEY (`DOCUMENT_ID`) REFERENCES `AS_GSS_EVALUATION_DOCUMENT` (`EVAL_DOCUMENT_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 18, 725, 2241);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************
-- [854] Alter tables for AUTO_INCREMENT
-- ***************************************
-- Update AUTO_INCREMENT to be 1,000,000
-- ***************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",18, "Source Selection 1.1", 854, "Alter tables for AUTO_INCREMENT",773,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_R_DATA AUTO_INCREMENT = 1000000;
ALTER TABLE AS_GSS_R_DOCUMENT_TEMPLATE AUTO_INCREMENT = 1000000;
ALTER TABLE AS_GSS_R_RATING AUTO_INCREMENT = 1000000;
ALTER TABLE AS_GSS_TMG_R_TASK_ACTION AUTO_INCREMENT = 1000000;
ALTER TABLE AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE AUTO_INCREMENT = 1000000;
ALTER TABLE AS_GSS_TMG_R_TASK_CATEGORY AUTO_INCREMENT = 1000000;
ALTER TABLE AS_GSS_TMG_R_TASK_REF AUTO_INCREMENT = 1000000;
ALTER TABLE AS_GSS_TMG_R_TASK_STATUS AUTO_INCREMENT = 1000000;
ALTER TABLE AS_GSS_TMG_R_TEMPLATE AUTO_INCREMENT = 1000000;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 18, 854, 773);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;





-- **********************
-- Source Selection 1.2
-- **********************


-- *************************************************
-- [969] Inserting Response Types in AS_GSS_R_DATA
-- *************************************************
-- AS_GSS_R_DATA Insert script for Response Type
-- *************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 969, "Inserting Response Types in AS_GSS_R_DATA",901,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES 
(42, 'Strength', NULL, 'Response Type', NULL, NULL, 1, 1, 'appian.administrator', now(), 'appian.administrator', now()),
(43, 'Weakness', NULL, 'Response Type', NULL, NULL, 2, 1, 'appian.administrator', now(), 'appian.administrator', now()),
(44, 'Deficiency', NULL, 'Response Type', NULL, NULL, 3, 1, 'appian.administrator', now(), 'appian.administrator', now());

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 969, 901);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ************************************************
-- [970] Create AS_GSS_EVALUATION_RESPONSES table
-- ************************************************
-- Create table AS_GSS_EVALUATION_RESPONSES
-- ************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 970, "Create AS_GSS_EVALUATION_RESPONSES table",2481,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE IF NOT EXISTS `AS_GSS_EVALUATION_RESPONSES` (
  `RESPONSE_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TASK_ID` int(11) DEFAULT NULL,
  `CONSENSUS_ID` int(11) DEFAULT NULL,
  `FACTOR_ID` int(11) DEFAULT NULL,
  `VENDOR_ID` int(11) DEFAULT NULL,
  `RESPONSE_TYPE_ID` int(11) DEFAULT NULL,
  `RESPONSE` TEXT DEFAULT NULL,
  `JUSTIFICATION` TEXT DEFAULT NULL,
  `REFERENCES` TEXT DEFAULT NULL,
  `INCLUDED_COMMENTS` varchar(255) DEFAULT NULL,
  `IS_SIGNIFICANT` tinyint(1) DEFAULT NULL,
  `IS_INCLUDED` tinyint(1) DEFAULT NULL,
  `COMBINATION_ORDER` int(11) DEFAULT NULL,
  `RESPONSE_ORDER` int(11) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL
);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 970, 2481);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *************************************************
-- [971] Add Index for AS_GSS_EVALUATION_RESPONSES
-- *************************************************
-- Add Index for AS_GSS_EVALUATION_RESPONSES
-- *************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 971, "Add Index for AS_GSS_EVALUATION_RESPONSES",903,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVALUATION_RESPONSES`
  ADD KEY `asgssevltinrspnss_rspnstype` (`RESPONSE_TYPE_ID`),
  ADD KEY `asgssevalresponses_taskid` (`TASK_ID`),
  ADD KEY `asgssevalresponses_vendorid` (`VENDOR_ID`),
  ADD KEY `asgssevalresponses_factorid` (`FACTOR_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 971, 903);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **************************************************
-- [972] Add FK for AS_GSS_EVALUATION_RESPONSES
-- **************************************************
-- Add Foreign Key` for AS_GSS_EVALUATION_RESPONSES
-- **************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 972, "Add FK for AS_GSS_EVALUATION_RESPONSES",904,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVALUATION_RESPONSES`
  ADD CONSTRAINT `asgssevalresponses_factorid` FOREIGN KEY IF NOT EXISTS (`FACTOR_ID`) REFERENCES `AS_GSS_CRITERIA` (`CRITERIA_ID`),
  ADD CONSTRAINT `asgssevalresponses_taskid` FOREIGN KEY IF NOT EXISTS (`TASK_ID`) REFERENCES `AS_GSS_TMG_TASK` (`TASK_ID`),
  ADD CONSTRAINT `asgssevalresponses_vendorid` FOREIGN KEY IF NOT EXISTS (`VENDOR_ID`) REFERENCES `AS_GSS_EVALUATION_VENDOR` (`VENDOR_ID`),
  ADD CONSTRAINT `asgssevltinrspnss_rspnstype` FOREIGN KEY IF NOT EXISTS (`RESPONSE_TYPE_ID`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 972, 904);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************************************************************
-- [991] R Data for Consesnsus status
-- ***************************************************************************************
-- 
-- Script Description
-- This description is used as a comment in the generated script, please be descriptive
-- R Data is being inserted into AS_GSS_R_DATA table for consensus status
-- ***************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 991, "R Data for Consesnsus status",920,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES 
(45, 'Not Started', NULL, 'Consensus Status', NULL, NULL, 1, 1, 'appian.administrator', now(), 'appian.administrator', now()),
(46, 'In Progress', NULL, 'Consensus Status', NULL, NULL, 2, 1, 'appian.administrator', now(), 'appian.administrator', now()),
(47, 'Complete', NULL, 'Consensus Status', NULL, NULL, 3, 1, 'appian.administrator', now(), 'appian.administrator', now());


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 991, 920);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *********************************************************************
-- [992] Create Table for Consensus
-- *********************************************************************
-- AS_GSS_CONSENSUS table has to be created to capture consensus data
-- 
-- *********************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 992, "Create Table for Consensus",2482,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE IF NOT EXISTS `AS_GSS_CONSENSUS` (
  `CONSENSUS_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `EVALUATION_ID` int(11) DEFAULT NULL,
  `FACTOR_ID` int(11) DEFAULT NULL,
  `VENDOR_ID` int(11) DEFAULT NULL,
  `STATUS_ID` int(11) DEFAULT NULL,
  `RATING_ID` int(11) DEFAULT NULL,
  `RATING_JUSTIFICATION` TEXT DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL
);


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 992, 2482);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************************************************************************
-- [994] Add foreign keys to consensus table
-- ***************************************************************************************************
-- Foreign keys like FACTOR_ID,VENDOR_ID,STATUS_ID and RATING_ID are added to AS_GSS_CONSENSUS table
-- ***************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 994, "Add foreign keys to consensus table",923,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_CONSENSUS`
  ADD KEY `asgssconsensus_factorid` (`FACTOR_ID`),
  ADD KEY `asgssconsensus_vendorid` (`VENDOR_ID`),
  ADD KEY `asgssconsensus_statusid` (`STATUS_ID`),
  ADD KEY `asgssconsensus_ratingid` (`RATING_ID`);


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 994, 923);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *************************************************
-- [995] Create AS_GSS_CONSENSUS_RESPONSE table
-- *************************************************
-- Query to Create table AS_GSS_CONSENSUS_RESPONSE
-- *************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 995, "Create AS_GSS_CONSENSUS_RESPONSE table",2483,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE IF NOT EXISTS `AS_GSS_CONSENSUS_RESPONSE` (
  `CONSENSUS_RESPONSE_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `CONSENSUS_ID` int(11) DEFAULT NULL,
  `COMBINATION_ORDER` int(11) DEFAULT NULL,
  `RESPONSE_TYPE_ID` int(11) DEFAULT NULL,
  `RESPONSE` TEXT DEFAULT NULL,
  `JUSTIFICATION` TEXT DEFAULT NULL,
  `REFERENCES` TEXT DEFAULT NULL,
  `IS_SIGNIFICANT` tinyint(1) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL
);


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 995, 2483);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ********************************************************************
-- [997] Add foreign key reference to AS_GSS_CONSENSUS_RESPONSE table
-- ********************************************************************
-- Add foreign key reference to AS_GSS_CONSENSUS_RESPONSE table
-- ********************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 997, "Add foreign key reference to AS_GSS_CONSENSUS_RESPONSE table",926,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_CONSENSUS_RESPONSE`
ADD KEY `asgssconsensusrspnse_consensusid` (`CONSENSUS_ID`),
ADD KEY `asgssconsensusrspnse_responsetypeid` (`RESPONSE_TYPE_ID`);


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 997, 926);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **********************************************************************
-- [998] Add CONSENSUS_ID column AS_GSS_EVALUATION_DOCUMENT
-- **********************************************************************
-- Query to add CONSENSUS_ID column to AS_GSS_EVALUATION_DOCUMENT table
-- **********************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 998, "Add CONSENSUS_ID column AS_GSS_EVALUATION_DOCUMENT",927,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVALUATION_DOCUMENT` ADD CONSENSUS_ID int(11) DEFAULT NULL AFTER EVALUATION_ID;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 998, 927);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************************************************************
-- [1000] Add foreign reference for CONSENSUS_ID in AS_GSS_EVALUATION_DOCUMENT table
-- ***************************************************************************************
-- 
-- Script Description
-- This description is used as a comment in the generated script, please be descriptive
-- Query to add foreign constraint for CONSENSUS_ID in AS_GSS_EVALUATION_DOCUMENT table
-- ***************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 1000, "Add foreign reference for CONSENSUS_ID in AS_GSS_EVALUATION_DOCUMENT table",929,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVALUATION_DOCUMENT` ADD CONSTRAINT `asgssconsensus_consensusid` FOREIGN KEY IF NOT EXISTS (`CONSENSUS_ID`) REFERENCES `AS_GSS_CONSENSUS`(`CONSENSUS_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 1000, 929);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************************************************************
-- [1001] Add foreign key constraints to AS_GSS_CONSENSUS table
-- ***************************************************************************************
-- Script Description
-- This description is used as a comment in the generated script, please be descriptive
-- Query to add foreign constraints to the AS_GSS_CONSENSUS table
-- ***************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 1001, "Add foreign key constraints to AS_GSS_CONSENSUS table",933,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_CONSENSUS` 
ADD CONSTRAINT `asgssconsensus_evaluationid` FOREIGN KEY IF NOT EXISTS (`EVALUATION_ID`) REFERENCES `AS_GSS_EVALUATION`(`EVALUATION_ID`),
ADD CONSTRAINT `asgssconsensus_factorid` FOREIGN KEY IF NOT EXISTS (`FACTOR_ID`) REFERENCES `AS_GSS_CRITERIA` (`CRITERIA_ID`),
ADD CONSTRAINT `asgssconsensus_vendorid` FOREIGN KEY IF NOT EXISTS (`VENDOR_ID`) REFERENCES `AS_GSS_EVALUATION_VENDOR` (`VENDOR_ID`),
ADD CONSTRAINT `asgssconsensus_statusid` FOREIGN KEY IF NOT EXISTS (`STATUS_ID`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`),
ADD CONSTRAINT `asgssconsensus_ratingid` FOREIGN KEY IF NOT EXISTS (`RATING_ID`) REFERENCES `AS_GSS_RATING` (`RATING_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 1001, 933);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ******************************************************************
-- [1002] Add foreign key contraints in AS_GSS_CONSENSUS_RESPONSE
-- ******************************************************************
-- Query to add foreign key contraints in AS_GSS_CONSENSUS_RESPONSE
-- ******************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 1002, "Add foreign key contraints in AS_GSS_CONSENSUS_RESPONSE",931,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_CONSENSUS_RESPONSE` 
  ADD CONSTRAINT `asgssconsensusrspnse_consensusid` FOREIGN KEY IF NOT EXISTS (`CONSENSUS_ID`) REFERENCES `AS_GSS_CONSENSUS` (`CONSENSUS_ID`),
  ADD CONSTRAINT `asgssconsensusrspnse_responsetypeid` FOREIGN KEY IF NOT EXISTS (`RESPONSE_TYPE_ID`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 1002, 931);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ************************************************************************
-- [1003] Add foreign references to AS_GSS_EVALUATION_RESPONSES table 
-- ************************************************************************
-- Query to add foreign references to AS_GSS_EVALUATION_RESPONSES table 
-- 
-- ************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 1003, "Add foreign references to AS_GSS_EVALUATION_RESPONSES table ",932,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVALUATION_RESPONSES`
  ADD CONSTRAINT `asgssevalresponses_consensusid` FOREIGN KEY IF NOT EXISTS (`CONSENSUS_ID`) REFERENCES `AS_GSS_CONSENSUS` (`CONSENSUS_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 1003, 932);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *************************************
-- [1004] Create scripts
-- *************************************
-- CREATE scripts of the audit tables.
-- *************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 1004, "Create scripts",2245,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE IF NOT EXISTS `AS_GSS_A_R_EVALUATION_RESPONSES` (
  `RESPONSE_AUDIT_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `RESPONSE_ID` int(11) DEFAULT NULL,
  `TIMESTAMP` datetime DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL,
  `AUDIT_ACTION_CODE` varchar(255) DEFAULT NULL
);


CREATE TABLE `AS_GSS_A_R_EVALUATION_RESPONSES_FIELD` (
  `RESPONSE_AUDIT_FIELD_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `RESPONSE_AUDIT_ID` int(11) DEFAULT NULL,
  `FIELD_NAME` varchar(255) DEFAULT NULL,
  `OLD_VALUE` varchar(5000) DEFAULT NULL,
  `NEW_VALUE` varchar(5000) DEFAULT NULL
);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 1004, 2245);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************
-- [1005] Add Index scripts
-- ****************************************
-- ADD INDEX scripts of the audit tables.
-- ****************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 1005, "Add Index scripts",935,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_A_R_EVALUATION_RESPONSES`
  ADD KEY `asgssarevaluationresponses_responseid` (`RESPONSE_ID`);

ALTER TABLE `AS_GSS_A_R_EVALUATION_RESPONSES_FIELD`
  ADD KEY `asgssrvltnrspn_smplfldchngs` (`RESPONSE_AUDIT_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 1005, 935);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *********************************************
-- [1006] Add FK scripts
-- *********************************************
-- ADD CONSTRAINT scripts of the audit tables.
-- *********************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 1006, "Add FK scripts",936,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_A_R_EVALUATION_RESPONSES`
  ADD CONSTRAINT `asgssarevaluationresponses_responseid` FOREIGN KEY IF NOT EXISTS (`RESPONSE_ID`) REFERENCES `AS_GSS_EVALUATION_RESPONSES` (`RESPONSE_ID`);

ALTER TABLE `AS_GSS_A_R_EVALUATION_RESPONSES_FIELD`
  ADD CONSTRAINT `asgssrvltnrspn_smplfldchngs` FOREIGN KEY IF NOT EXISTS (`RESPONSE_AUDIT_ID`) REFERENCES `AS_GSS_A_R_EVALUATION_RESPONSES` (`RESPONSE_AUDIT_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 1006, 936);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ************************************************************
-- [1007] Query to update Consensus statuses in AS_GSS_R_Data
-- ************************************************************
-- Update Consensus statuses in AS_GSS_R_Data
-- ************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 1007, "Query to update Consensus statuses in AS_GSS_R_Data",937,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE `AS_GSS_R_DATA` SET `REF_ICON` = 'circle-thin' WHERE `AS_GSS_R_DATA`.`REF_DATA_ID` = 45;
UPDATE `AS_GSS_R_DATA` SET `REF_ICON` = 'spinner' WHERE `AS_GSS_R_DATA`.`REF_DATA_ID` = 46;
UPDATE `AS_GSS_R_DATA` SET `REF_ICON` = 'check-circle' WHERE `AS_GSS_R_DATA`.`REF_DATA_ID` = 47;

UPDATE `AS_GSS_R_DATA` SET `REF_COLOR` = 'SECONDARY' WHERE `AS_GSS_R_DATA`.`REF_DATA_ID` = 45;
UPDATE `AS_GSS_R_DATA` SET `REF_COLOR` = 'SECONDARY' WHERE `AS_GSS_R_DATA`.`REF_DATA_ID` = 46;
UPDATE `AS_GSS_R_DATA` SET `REF_COLOR` = 'POSITIVE' WHERE `AS_GSS_R_DATA`.`REF_DATA_ID` = 47;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 1007, 937);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************
-- [1008] Add columns to AS_GSS_CONSENSUS
-- ****************************************
-- Add columns to AS_GSS_CONSENSUS
-- ****************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 1008, "Add columns to AS_GSS_CONSENSUS",938,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_CONSENSUS` 
        ADD COLUMN `STARTED_BY` VARCHAR(255) AFTER `RATING_JUSTIFICATION`;

ALTER TABLE `AS_GSS_CONSENSUS` 
        ADD COLUMN `STARTED_DATETIME` DATETIME AFTER `STARTED_BY`;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 1008, 938);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ******************************************************************************
-- [1010] INSERT Responses into Evaluation Responses table
-- ******************************************************************************
-- Insert Strength & Weakness responses into table AS_GSS_EVALUATION_RESPONSES.
-- ******************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 1010, "INSERT Responses into Evaluation Responses table",940,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

/*Inserting new rows for Strength Responses*/

INSERT INTO AS_GSS_EVALUATION_RESPONSES(
    `TASK_ID`,
    `FACTOR_ID`,
    `VENDOR_ID`,
    `RESPONSE_TYPE_ID`,
    `RESPONSE`,
    `IS_SIGNIFICANT`,
    `CREATED_BY`,
    `CREATED_DATETIME`,
    `MODIFIED_BY`,
    `MODIFIED_DATETIME`,
    `IS_ACTIVE`
)
SELECT
    T.TASK_ID,
    T.CRITERIA_ID,
    T.VENDOR_ID,
    42,
    T.STRENGTH,
    false,
    T.CREATED_BY,
    T.CREATED_DATETIME,
    T.MODIFIED_BY,
    T.MODIFIED_DATETIME,
    true
FROM
    AS_GSS_TMG_TASK AS T
WHERE
    T.TASK_CATEGORY_ID = 40 AND T.STRENGTH IS NOT NULL AND T.STRENGTH NOT IN ('');


/*Inserting new rows for Weakness Responses*/

INSERT INTO AS_GSS_EVALUATION_RESPONSES(
    `TASK_ID`,
    `FACTOR_ID`,
    `VENDOR_ID`,
    `RESPONSE_TYPE_ID`,
    `RESPONSE`,
    `IS_SIGNIFICANT`,
    `CREATED_BY`,
    `CREATED_DATETIME`,
    `MODIFIED_BY`,
    `MODIFIED_DATETIME`,
    `IS_ACTIVE`
)
SELECT
    T.TASK_ID,
    T.CRITERIA_ID,
    T.VENDOR_ID,
    43,
    T.WEAKNESS,
    false,
    T.CREATED_BY,
    T.CREATED_DATETIME,
    T.MODIFIED_BY,
    T.MODIFIED_DATETIME,
    true
FROM
    AS_GSS_TMG_TASK AS T
WHERE
    T.TASK_CATEGORY_ID = 40 AND T.WEAKNESS IS NOT NULL AND T.WEAKNESS NOT IN ('');

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 1010, 940);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **********************************************************************************
-- [1011] Deprecate unused columns
-- **********************************************************************************
-- Deprecating Strength, Weakness & Additional Comments columns of AS_GSS_TMG_TASK.
-- **********************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 1011, "Deprecate unused columns",2493,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

/*Rename the columns of AS_GSS_TMG_TASK to be deprecated*/

ALTER TABLE `AS_GSS_TMG_TASK` CHANGE `STRENGTH` `DEPRECATED_STRENGTH` VARCHAR(1) NULL DEFAULT NULL;
ALTER TABLE `AS_GSS_TMG_TASK` CHANGE `WEAKNESS` `DEPRECATED_WEAKNESS` VARCHAR(1) NULL DEFAULT NULL;
ALTER TABLE `AS_GSS_TMG_TASK` CHANGE `ADDITIONAL_COMMENT` `DEPRECATED_ADDITIONAL_COMMENT` VARCHAR(1) NULL DEFAULT NULL;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 1011, 2493);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************************
-- [1019] Add Rating Descriptions
-- ***************************************************
-- Adding Rating Descriptions to AS_GSS_R_RATING tab
-- ***************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 1019, "Add Rating Descriptions",944,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Colors used to rate criteria"
WHERE `REF_RATING_ID` = 1;

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Adjectives used to rate criteria"
WHERE `REF_RATING_ID` = 2;

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Level of risk used to rate criteria"
WHERE `REF_RATING_ID` = 3;

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Numbers used to rate criteria"
WHERE `REF_RATING_ID` = 4;

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Level of confidence used to rate criteria"
WHERE `REF_RATING_ID` = 5;

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Acceptability used to rate criteria"
WHERE `REF_RATING_ID` = 6;

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` =
"Exceptional approach and understanding of the requirements and contains multiple strengths"
WHERE `REF_RATING_ID` = 7;

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` =
"Thorough approach and understanding of the requirements and contains at least one strength"
WHERE `REF_RATING_ID` = 8;

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Adequate approach and understanding of the requirements"
WHERE `REF_RATING_ID` = 9;

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` =
"Has not demonstrated an adequate approach and understanding of the requirements"
WHERE `REF_RATING_ID` = 10;

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Does not meet requirements of the solicitation"
WHERE `REF_RATING_ID` = 11; 

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Exceptional approach and understanding of the requirements and contains multiple strengths"
WHERE `REF_RATING_ID` = 12; 

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Thorough approach and understanding of the requirements and contains at least one strength"
WHERE `REF_RATING_ID` = 13; 

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Adequate approach and understanding of the requirements"
WHERE `REF_RATING_ID` = 14; 

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Has not demonstrated an adequate approach and understanding of the requirements"
WHERE `REF_RATING_ID` = 15; 

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Does not meet requirements of the solicitation"
WHERE `REF_RATING_ID` = 16; 

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Little doubt exists, based on the Offeror's performance record, that the Offeror can perform the proposed effort"
WHERE `REF_RATING_ID` = 17; 

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Some doubt exists, based on the Offeror's performance record, that the Offeror can perform the proposed effort"
WHERE `REF_RATING_ID` = 18; 

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Significant doubt exists, based on the Offeror's performance record, that the Offeror can perform the proposed effort"
WHERE `REF_RATING_ID` = 19; 

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Highest rating"
WHERE `REF_RATING_ID` = 20; 

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Lowest Rating"
WHERE `REF_RATING_ID` = 24; 

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Virtually no doubt that the offeror will successfully perform the required effort"
WHERE `REF_RATING_ID` = 25; 

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Reasonable expectation that the offeror will successfully perform the required effort"
WHERE `REF_RATING_ID` = 26; 

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "Low expectation that the offeror will successfully perform the required effort"
WHERE `REF_RATING_ID` = 27; 

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "No expectation that the offeror will be able to successfully perform the required effort"
WHERE `REF_RATING_ID` = 28; 

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "No positive or negative evaluation significance"
WHERE `REF_RATING_ID` = 29; 

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "The Government has a reasonable expectation that the offeror will successfully perform the required effort"
WHERE `REF_RATING_ID` = 30; 

UPDATE `AS_GSS_R_RATING`
SET `DESCRIPTION` = "The Government does not have a reasonable expectation that the offeror will be able to successfully perform the required effort"
WHERE `REF_RATING_ID` = 31; 

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 1019, 944);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ******************************************************************************************************
-- [1031] Add Rating Descriptions to Transactional Table
-- ******************************************************************************************************
-- Add Rating Descriptions to AS_GSS_RATING Transactional Table to Evaluations that are already created
-- ******************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 1031, "Add Rating Descriptions to Transactional Table",947,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Colors used to rate criteria"
WHERE `REF_RATING_ID` = 1 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`='');

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Adjectives used to rate criteria"
WHERE `REF_RATING_ID` = 2 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`='');

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Level of risk used to rate criteria"
WHERE `REF_RATING_ID` = 3 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`='');

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Numbers used to rate criteria"
WHERE `REF_RATING_ID` = 4 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`='');

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Level of confidence used to rate criteria"
WHERE `REF_RATING_ID` = 5 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`='');

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Acceptability used to rate criteria"
WHERE `REF_RATING_ID` = 6 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`='');

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` =
"Exceptional approach and understanding of the requirements and contains multiple strengths"
WHERE `REF_RATING_ID` = 7 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`='');

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` =
"Thorough approach and understanding of the requirements and contains at least one strength"
WHERE `REF_RATING_ID` = 8 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`='');

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Adequate approach and understanding of the requirements"
WHERE `REF_RATING_ID` = 9 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`='');

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` =
"Has not demonstrated an adequate approach and understanding of the requirements"
WHERE `REF_RATING_ID` = 10 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`='');

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Does not meet requirements of the solicitation"
WHERE `REF_RATING_ID` = 11 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`=''); 

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Exceptional approach and understanding of the requirements and contains multiple strengths"
WHERE `REF_RATING_ID` = 12 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`=''); 

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Thorough approach and understanding of the requirements and contains at least one strength"
WHERE `REF_RATING_ID` = 13 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`=''); 

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Adequate approach and understanding of the requirements"
WHERE `REF_RATING_ID` = 14 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`=''); 

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Has not demonstrated an adequate approach and understanding of the requirements"
WHERE `REF_RATING_ID` = 15 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`=''); 

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Does not meet requirements of the solicitation"
WHERE `REF_RATING_ID` = 16 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`=''); 

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Little doubt exists, based on the Offeror's performance record, that the Offeror can perform the proposed effort"
WHERE `REF_RATING_ID` = 17 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`=''); 

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Some doubt exists, based on the Offeror's performance record, that the Offeror can perform the proposed effort"
WHERE `REF_RATING_ID` = 18 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`=''); 

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Significant doubt exists, based on the Offeror's performance record, that the Offeror can perform the proposed effort"
WHERE `REF_RATING_ID` = 19 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`=''); 

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Highest rating"
WHERE `REF_RATING_ID` = 20 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`=''); 

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Lowest Rating"
WHERE `REF_RATING_ID` = 24 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`=''); 

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Virtually no doubt that the offeror will successfully perform the required effort"
WHERE `REF_RATING_ID` = 25 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`=''); 

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Reasonable expectation that the offeror will successfully perform the required effort"
WHERE `REF_RATING_ID` = 26 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`=''); 

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "Low expectation that the offeror will successfully perform the required effort"
WHERE `REF_RATING_ID` = 27 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`=''); 

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "No expectation that the offeror will be able to successfully perform the required effort"
WHERE `REF_RATING_ID` = 28 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`=''); 

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "No positive or negative evaluation significance"
WHERE `REF_RATING_ID` = 29 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`=''); 

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "The Government has a reasonable expectation that the offeror will successfully perform the required effort"
WHERE `REF_RATING_ID` = 30 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`=''); 

UPDATE `AS_GSS_RATING`
SET `DESCRIPTION` = "The Government does not have a reasonable expectation that the offeror will be able to successfully perform the required effort"
WHERE `REF_RATING_ID` = 31 AND (`DESCRIPTION` IS NULL OR `DESCRIPTION`=''); 


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 1031, 947);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **************************************
-- [1039] Create Consensus Audit tables
-- **************************************
-- Create Consensus Audit tables
-- **************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 1039, "Create Consensus Audit tables",949,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE IF NOT EXISTS `AS_GSS_A_R_CONSENSUS_FIELD`(
    `CONSENSUS_AUDIT_FIELD_ID` INTEGER NOT NULL AUTO_INCREMENT,
    `CONSENSUS_AUDIT_ID` INTEGER,
    `FIELD_NAME` VARCHAR(255),
    `OLD_VALUE` VARCHAR(5000),
    `NEW_VALUE` VARCHAR(5000),
    PRIMARY KEY(`CONSENSUS_AUDIT_FIELD_ID`)
); 
CREATE TABLE IF NOT EXISTS `AS_GSS_A_R_CONSENSUS_RESPONSE_FIELD`(
    `CONSENSUS_RESPONSE_AUDIT_FIELD_ID` INTEGER NOT NULL AUTO_INCREMENT,
    `CONSENSUS_RESPONSE_AUDIT_ID` INTEGER,
    `FIELD_NAME` VARCHAR(255),
    `OLD_VALUE` VARCHAR(5000),
    `NEW_VALUE` VARCHAR(5000),
    PRIMARY KEY(
        `CONSENSUS_RESPONSE_AUDIT_FIELD_ID`
    )
); 
CREATE TABLE IF NOT EXISTS `AS_GSS_A_R_CONSENSUS_RESPONSE`(
    `CONSENSUS_RESPONSE_AUDIT_ID` INTEGER NOT NULL AUTO_INCREMENT,
    `CONSENSUS_RESPONSE_ID` INTEGER,
	`CONSENSUS_AUDIT_ID` INTEGER,
    `TIMESTAMP` DATETIME,
    `USERNAME` VARCHAR(255),
    `AUDIT_ACTION_CODE` VARCHAR(255), 
    PRIMARY KEY(`CONSENSUS_RESPONSE_AUDIT_ID`)
); 
CREATE TABLE IF NOT EXISTS `AS_GSS_A_R_CONSENSUS`(
    `CONSENSUS_AUDIT_ID` INTEGER NOT NULL AUTO_INCREMENT,
    `CONSENSUS_ID` INTEGER,
    `TIMESTAMP` DATETIME,
    `USERNAME` VARCHAR(255),
    `AUDIT_ACTION_CODE` VARCHAR(255),
    PRIMARY KEY(`CONSENSUS_AUDIT_ID`)
);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 1039, 949);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ************************
-- [1040] Add constraints
-- ************************
-- Add constraints
-- ************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 1040, "Add constraints",950,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE
    `AS_GSS_A_R_CONSENSUS_FIELD` ADD INDEX asgssrcnsnss_simplfildchngs(`CONSENSUS_AUDIT_ID`),
    ADD CONSTRAINT asgssrcnsnss_simplfildchngs FOREIGN KEY(`CONSENSUS_AUDIT_ID`) REFERENCES `AS_GSS_A_R_CONSENSUS`(`CONSENSUS_AUDIT_ID`);
ALTER TABLE
    `AS_GSS_A_R_CONSENSUS_RESPONSE_FIELD` ADD INDEX asgssrcnsnssrs_smplfldchngs(`CONSENSUS_RESPONSE_AUDIT_ID`),
    ADD CONSTRAINT asgssrcnsnssrs_smplfldchngs FOREIGN KEY(`CONSENSUS_RESPONSE_AUDIT_ID`) REFERENCES `AS_GSS_A_R_CONSENSUS_RESPONSE`(`CONSENSUS_RESPONSE_AUDIT_ID`);
ALTER TABLE
    `AS_GSS_A_R_CONSENSUS_RESPONSE` ADD INDEX asgssrcnsnss_cnsnssrspnschn(`CONSENSUS_AUDIT_ID`),
    ADD CONSTRAINT asgssrcnsnss_cnsnssrspnschn FOREIGN KEY(`CONSENSUS_AUDIT_ID`) REFERENCES `AS_GSS_A_R_CONSENSUS`(`CONSENSUS_AUDIT_ID`);
ALTER TABLE
    `AS_GSS_A_R_CONSENSUS` ADD INDEX asgss_consensus(`CONSENSUS_ID`),
	ADD CONSTRAINT `asgss_consensus` FOREIGN KEY(`CONSENSUS_ID`) REFERENCES `AS_GSS_CONSENSUS`(`CONSENSUS_ID`);
ALTER TABLE
    `AS_GSS_A_R_CONSENSUS_RESPONSE` ADD INDEX asgss_consensus_response(`CONSENSUS_RESPONSE_ID`),
	ADD CONSTRAINT `asgss_consensus_response` FOREIGN KEY(`CONSENSUS_RESPONSE_ID`) REFERENCES `AS_GSS_CONSENSUS_RESPONSE`(`CONSENSUS_RESPONSE_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 1040, 950);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ******************************************
-- [1088] Insert reasons into AS_GSS_R_DATA
-- ******************************************
-- Insert reasons into AS_GSS_R_DATA
-- ******************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 1088, "Insert reasons into AS_GSS_R_DATA",1092,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DATA`(
    `REF_DATA_ID`,
    `REF_LABEL`,
    `REF_TYPE`,
    `REF_ICON`,
    `REF_COLOR`,
    `SORT_ORDER`,
    `IS_ACTIVE`,
    `CREATED_BY`,
    `CREATED_DATETIME`,
    `MODIFIED_BY`,
    `MODIFIED_DATETIME`
)
VALUES(
    48,
    'Work taking longer than originally planned',
    'Due Date Change Reason',
    NULL,
    NULL,
    5,
    1,
    'appian.administrator',
    SYSDATE(),
    'appian.administrator',
    SYSDATE()
),(
    49,
    'Other priorities took precedence',
    'Due Date Change Reason',
    NULL,
    NULL,
    3,
    1,
    'appian.administrator',
    SYSDATE(),
    'appian.administrator',
    SYSDATE()
),(
    50,
    'Dependent tasks did not complete on time',
    'Due Date Change Reason',
    NULL,
    NULL,
    2,
    1,
    'appian.administrator',
    SYSDATE(),
    'appian.administrator',
    SYSDATE()
),(
    51,
    'Part of larger shift in schedule',
    'Due Date Change Reason',
    NULL,
    NULL,
    4,
    1,
    'appian.administrator',
    SYSDATE(),
    'appian.administrator',
    SYSDATE()
),(
    52,
    'Change in work priorities\r\n',
    'Due Date Change Reason',
    NULL,
    NULL,
    1,
    1,
    'appian.administrator',
    SYSDATE(),
    'appian.administrator',
    SYSDATE()
);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 1088, 1092);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *****************************************************
-- [1089] Create AS_GSS_TMG_TASK_CHANGE_REASON_MAPPING
-- *****************************************************
-- Create AS_GSS_TMG_TASK_CHANGE_REASON_MAPPING
-- *****************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 1089, "Create AS_GSS_TMG_TASK_CHANGE_REASON_MAPPING",2246,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE IF NOT EXISTS `AS_GSS_TMG_TASK_CHANGE_REASON_MAPPING` (
  `TASK_CHANGE_REASON_MAPPING_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `TASK_ID` int(11) DEFAULT NULL,
  `OLD_DUE_DATE` date DEFAULT NULL,
  `NEW_DUE_DATE` date DEFAULT NULL,
  `CHANGE_REASON_ID` int(11) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL
);

ALTER TABLE `AS_GSS_TMG_TASK_CHANGE_REASON_MAPPING`
  ADD KEY `asgsstmgtskchngrsnm_chngrsn` (`CHANGE_REASON_ID`),
  ADD KEY `asgsstmgtskchngrsnm_task` (`TASK_ID`);


ALTER TABLE `AS_GSS_TMG_TASK_CHANGE_REASON_MAPPING`
  ADD CONSTRAINT `asgsstmgtskchngrsnm_chngrsn` FOREIGN KEY (`CHANGE_REASON_ID`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`),
  ADD CONSTRAINT `asgsstmgtskchngrsnm_task` FOREIGN KEY (`TASK_ID`) REFERENCES `AS_GSS_TMG_TASK` (`TASK_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 1089, 2246);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *******************************
-- [1117] Update AS_GSS_TMG_TASK
-- *******************************
-- Update Column Date Type
-- *******************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 1117, "Update AS_GSS_TMG_TASK",1128,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_TMG_TASK`
  MODIFY `DUE_DATE` datetime;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 1117, 1128);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *****************************************************
-- [1118] Update AS_GSS_TMG_TASK_CHANGE_REASON_MAPPING
-- *****************************************************
-- Update Column Date Type
-- *****************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",26, "Source Selection 1.2", 1118, "Update AS_GSS_TMG_TASK_CHANGE_REASON_MAPPING",1129,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_TMG_TASK_CHANGE_REASON_MAPPING`
  MODIFY `OLD_DUE_DATE` DATETIME,
  MODIFY `NEW_DUE_DATE` DATETIME;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 26, 1118, 1129);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;





-- ***********************************************************************************************************************************************************************************************
-- Award Management 1.2.3 / Clause Automation 1.4 / Contract Writing 1.0 / Management Suite 1.0 / ProcureSight v1.0 / Requirements Management 1.5 / Source Selection 1.3 / Vendor Management 1.0
-- ***********************************************************************************************************************************************************************************************


-- *******************************************************
-- [1214] SHORTEN GAM DB OBJECT NAMES
-- *******************************************************
-- Shorten all GAM DB object names to support Oracle 12c
-- *******************************************************

DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GAM_RunFrameworkScript()
BEGIN
CALL AS_GAM_Initial_Execution("N",39, "Award Management 1.2.3 / Clause Automation 1.4 / Contract Writing 1.0 / Management Suite 1.0 / ProcureSight v1.0 / Requirements Management 1.5 / Source Selection 1.3 / Vendor Management 1.0", 1214, "SHORTEN GAM DB OBJECT NAMES",1355,  @AS_GAM_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

-- No views to drop for AS_GAM

-- No indexes to rename for AS_GAM

-- No constraints to rename for AS_GAM

-- No columns to rename for AS_GAM

-- Tables to rename for AS_GAM
ALTER TABLE AS_GAM_A_R_AWARD_REQUIREMENT_MAPPING_FIELD RENAME TO AS_GAM_A_R_AWRD_REQ_MAP_FLD;
ALTER TABLE AS_GAM_A_R_AWARD_REQUIREMENT_MAPPING RENAME TO AS_GAM_A_R_AWRD_REQ_MPPNG;
ALTER TABLE AS_GAM_AWARD_REQUIREMENT_MAPPING RENAME TO AS_GAM_AWRD_RQRMENT_MAPPING;

-- No views with long names to recreate for AS_GAM

-- No views with long columns to recreate for AS_GAM

-- No other views to recreate AS_GAM

-- No other objects to rename for AS_GAM;

-- END SCRIPT CONTENT ---
 
CALL AS_GAM_Update_Execution(@AS_GAM_scriptExecuteId, 39, 1214, 1355);
END IF;
END $$
DELIMITER ;

CALL AS_GAM_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;





-- **********************
-- Source Selection 1.3
-- **********************


-- *******************************************************
-- [1217] SHORTEN GSS DB OBJECT NAMES
-- *******************************************************
-- Shorten all GSS DB object names to support Oracle 12c
-- *******************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",38, "Source Selection 1.3", 1217, "SHORTEN GSS DB OBJECT NAMES",1150,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

-- No views to drop for AS_GSS

-- Indexes to rename for AS_GSS
ALTER TABLE AS_GSS_A_R_EVALUATION_RESPONSES RENAME INDEX asgssarevaluationresponses_responseid TO asgssrvltnresponses_responseid;
ALTER TABLE AS_GSS_A_R_TEAM_MEMBERSHIP RENAME INDEX asgssrevltin_vltortemmembrshpchnges TO asgssrvltn_vltrtmmmbrshpchnges;
ALTER TABLE AS_GSS_CONSENSUS_RESPONSE RENAME INDEX asgssconsensusrspnse_responsetypeid TO asgsscnsnssrspns_rsponsetypeid;
ALTER TABLE AS_GSS_TMG_TASK_ACTION_AUDIT RENAME INDEX AS_GSS_TMG_taskactinadit_taskactin TO AS_GSS_TMG_tskctndit_taskactin;
ALTER TABLE AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC_F RENAME INDEX AS_GSS_TMG_rtmplttskp_smplfldchngs TO AS_GSS_TMG_rtpltkp_smplfldchgs;
ALTER TABLE AS_GSS_TMG_A_R_TEMPLATE_FIELD RENAME INDEX AS_GSS_TMG_rtmplt_simplfieldchnges TO AS_GSS_TMG_rtmplt_smplfldchngs;
ALTER TABLE AS_GSS_TMG_A_R_TEMPLATE_TASK_FIELD RENAME INDEX AS_GSS_TMG_rtmplttsk_smplfildchngs TO AS_GSS_TMG_rtpltk_smplfldchngs;
ALTER TABLE AS_GSS_TMG_A_TASK_PROCESS_SETUP RENAME INDEX AS_GSS_TMG_tmpltprcssstp_tskschngs TO AS_GSS_TMG_tplprocstp_tkschngs;
ALTER TABLE AS_GSS_TMG_A_R_TASK_CATEGORY_FIELD RENAME INDEX AS_GSS_TMG_rtskctgry_smplfildchngs TO AS_GSS_TMG_rtkctgry_splfldchgs;
ALTER TABLE AS_GSS_TMG_R_TEMPLATE_TASK_PRECEDNT RENAME INDEX AS_GSS_TMG_rtemplatetask_prectasks TO AS_GSS_TMG_rtmplttsk_prectasks;
ALTER TABLE AS_GSS_TMG_A_TASK_PROCESS_SETUP_FIELD RENAME INDEX AS_GSS_TMG_tskprcssst_smplfldchngs TO AS_GSS_TMG_tkprocst_splfldchgs;
ALTER TABLE AS_GSS_TMG_A_R_TASK_REF_FIELD RENAME INDEX AS_GSS_TMG_rtskrf_simplfieldchnges TO AS_GSS_TMG_rtskrf_smplfldchngs;
ALTER TABLE AS_GSS_A_R_TEAM_MEMBERSHIP_FIELD RENAME INDEX asgssrvltortmmbrshp_simplfildchngs TO asgssrvltrtmmbrshp_smplfldchgs;
ALTER TABLE AS_GSS_TMG_A_R_TEMPLATE_TASK RENAME INDEX AS_GSS_TMG_rtmplt_templtetskchnges TO AS_GSS_TMG_rtpl_tmplttskchngs;
ALTER TABLE AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC RENAME INDEX AS_GSS_TMG_rtmplttsk_tmplttskprcdn TO AS_GSS_TMG_rtpltsk_tpltskprcdn;
ALTER TABLE AS_GSS_TMG_TASK_DOC_UPLOAD RENAME INDEX AS_GSS_TMG_kdcpldcntxt_nbrdngdcmnt TO AS_GSS_TMG_dcpldctxt_nbrdngdc;
ALTER TABLE AS_GSS_TMG_R_TEMPLATE_TASK RENAME INDEX AS_GSS_TMG_rtemplte_templtetskmaps TO AS_GSS_TMG_rtmplt_tmplttskmaps;
ALTER TABLE AS_GSS_TMG_R_TASK_REF RENAME INDEX AS_GSS_TMG_rtskref_taskbehavirtype TO AS_GSS_TMG_rtskrf_tskbhvirtype;
ALTER TABLE AS_GSS_TMG_R_TASK_REF RENAME INDEX AS_GSS_TMG_rtaskref_dcploadcontext TO AS_GSS_TMG_rtskrf_dcpldcontext;
ALTER TABLE AS_GSS_TMG_TASK RENAME INDEX AS_GSS_TMG_task_taskbehaviortype TO AS_GSS_TMG_tsk_tskbehaviortype;
ALTER TABLE AS_GSS_CONSENSUS_RESPONSE RENAME INDEX asgssconsensusrspnse_consensusid TO asgsscnsnsusrspnse_consensusid;
ALTER TABLE AS_GSS_TMG_R_TEMPLATE_TASK RENAME INDEX AS_GSS_TMG_rtemplatetask_taskref TO AS_GSS_TMG_rtmpltetask_taskref;
ALTER TABLE AS_GSS_TMG_R_TASK_REF RENAME INDEX AS_GSS_TMG_rtaskref_taskcategory TO AS_GSS_TMG_rtskrf_taskcategory;
ALTER TABLE AS_GSS_TMG_TASK RENAME INDEX AS_GSS_TMG_task_docuploadcontext TO AS_GSS_TMG_tsk_dcuploadcontext;
ALTER TABLE AS_GSS_EVALUATION_VENDOR_BUSINESS_TYPE RENAME INDEX asgssevalvendrbsnstype_typecode TO asgssvalvendrbsnstype_typecode;

-- Constraints to rename for AS_GSS
ALTER TABLE AS_GSS_A_R_EVALUATION_RESPONSES DROP FOREIGN KEY asgssarevaluationresponses_responseid, ADD CONSTRAINT asgssrvltnresponses_responseid FOREIGN KEY (RESPONSE_ID) REFERENCES AS_GSS_EVALUATION_RESPONSES (RESPONSE_ID);
ALTER TABLE AS_GSS_CONSENSUS_RESPONSE DROP FOREIGN KEY asgssconsensusrspnse_responsetypeid, ADD CONSTRAINT asgsscnsnssrspns_rsponsetypeid FOREIGN KEY (RESPONSE_TYPE_ID) REFERENCES AS_GSS_R_DATA (REF_DATA_ID);
ALTER TABLE AS_GSS_A_R_TEAM_MEMBERSHIP DROP FOREIGN KEY asgssrevltin_vltortemmembrshpchnges, ADD CONSTRAINT asgssrvltn_vltrtmmmbrshpchnges FOREIGN KEY (TEAM_AUDIT_ID) REFERENCES AS_GSS_A_R_EVALUATOR_TEAM (TEAM_AUDIT_ID);
ALTER TABLE AS_GSS_TMG_A_R_TEMPLATE_TASK DROP FOREIGN KEY AS_GSS_TMG_rtmplt_templtetskchnges, ADD CONSTRAINT AS_GSS_TMG_rtpl_tmplttskchngs FOREIGN KEY (TEMPLATE_AUDIT_ID) REFERENCES AS_GSS_TMG_A_R_TEMPLATE (TEMPLATE_AUDIT_ID);
ALTER TABLE AS_GSS_TMG_A_R_TEMPLATE_TASK_FIELD DROP FOREIGN KEY AS_GSS_TMG_rtmplttsk_smplfildchngs, ADD CONSTRAINT AS_GSS_TMG_rtpltk_smplfldchngs FOREIGN KEY (TEMPLATE_TASK_AUDIT_ID) REFERENCES AS_GSS_TMG_A_R_TEMPLATE_TASK (TEMPLATE_TASK_AUDIT_ID);
ALTER TABLE AS_GSS_TMG_A_TASK_PROCESS_SETUP_FIELD DROP FOREIGN KEY AS_GSS_TMG_tskprcssst_smplfldchngs, ADD CONSTRAINT AS_GSS_TMG_tkprocst_splfldchgs FOREIGN KEY (TASK_PROC_SETUP_AUDIT_ID) REFERENCES AS_GSS_TMG_A_TASK_PROCESS_SETUP (TASK_PROC_SETUP_AUDIT_ID);
ALTER TABLE AS_GSS_TMG_R_TEMPLATE_TASK_PRECEDNT DROP FOREIGN KEY AS_GSS_TMG_rtemplatetask_prectasks, ADD CONSTRAINT AS_GSS_TMG_rtmplttsk_prectasks FOREIGN KEY (TEMPLATE_TASK_ID) REFERENCES AS_GSS_TMG_R_TEMPLATE_TASK (TEMPLATE_TASK_ID);
ALTER TABLE AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC DROP FOREIGN KEY AS_GSS_TMG_rtmplttsk_tmplttskprcdn, ADD CONSTRAINT AS_GSS_TMG_rtpltsk_tpltskprcdn FOREIGN KEY (TEMPLATE_TASK_AUDIT_ID) REFERENCES AS_GSS_TMG_A_R_TEMPLATE_TASK (TEMPLATE_TASK_AUDIT_ID);
ALTER TABLE AS_GSS_TMG_TASK_ACTION_AUDIT DROP FOREIGN KEY AS_GSS_TMG_taskactinadit_taskactin, ADD CONSTRAINT AS_GSS_TMG_tskctndit_taskactin FOREIGN KEY (TASK_ACTION_ID) REFERENCES AS_GSS_TMG_R_TASK_ACTION (TASK_ACTION_ID);
ALTER TABLE AS_GSS_TMG_A_TASK_PROCESS_SETUP DROP FOREIGN KEY AS_GSS_TMG_tmpltprcssstp_tskschngs, ADD CONSTRAINT AS_GSS_TMG_tplprocstp_tkschngs FOREIGN KEY (TEMPLATE_PROC_SETUP_AUDIT_ID) REFERENCES AS_GSS_TMG_A_TEMPLATE_PROCESS_SETUP (TEMPLATE_PROC_SETUP_AUDIT_ID);
ALTER TABLE AS_GSS_TMG_A_R_TASK_CATEGORY_FIELD DROP FOREIGN KEY AS_GSS_TMG_rtskctgry_smplfildchngs, ADD CONSTRAINT AS_GSS_TMG_rtkctgry_splfldchgs FOREIGN KEY (TASK_CATEGORY_AUDIT_ID) REFERENCES AS_GSS_TMG_A_R_TASK_CATEGORY (TASK_CATEGORY_AUDIT_ID);
ALTER TABLE AS_GSS_A_R_TEAM_MEMBERSHIP_FIELD DROP FOREIGN KEY asgssrvltortmmbrshp_simplfildchngs, ADD CONSTRAINT asgssrvltrtmmbrshp_smplfldchgs FOREIGN KEY (TEAM_MEMBERSHIP_AUDIT_ID) REFERENCES AS_GSS_A_R_TEAM_MEMBERSHIP (TEAM_MEMBERSHIP_AUDIT_ID);
ALTER TABLE AS_GSS_TMG_R_TASK_REF DROP FOREIGN KEY AS_GSS_TMG_rtaskref_dcploadcontext, ADD CONSTRAINT AS_GSS_TMG_rtskrf_dcpldcontext FOREIGN KEY (TASK_REF_DOC_UPLOAD_ID) REFERENCES AS_GSS_TMG_R_TASK_REF_DOC_UPLOAD (TASK_REF_DOC_UPLOAD_ID);
ALTER TABLE AS_GSS_TMG_R_TASK_REF DROP FOREIGN KEY AS_GSS_TMG_rtskref_taskbehavirtype, ADD CONSTRAINT AS_GSS_TMG_rtskrf_tskbhvirtype FOREIGN KEY (TASK_BEHAVIOR_TYPE_ID) REFERENCES AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE (TASK_BEHAVIOR_TYPE_ID);
ALTER TABLE AS_GSS_TMG_A_R_TASK_REF_FIELD DROP FOREIGN KEY AS_GSS_TMG_rtskrf_simplfieldchnges, ADD CONSTRAINT AS_GSS_TMG_rtskrf_smplfldchngs FOREIGN KEY (TASK_REF_AUDIT_ID) REFERENCES AS_GSS_TMG_A_R_TASK_REF (TASK_REF_AUDIT_ID);
ALTER TABLE AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC_F DROP FOREIGN KEY AS_GSS_TMG_rtmplttskp_smplfldchngs, ADD CONSTRAINT AS_GSS_TMG_rtpltkp_smplfldchgs FOREIGN KEY (TEMPLATE_TASK_PREC_AUDIT_ID) REFERENCES AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC (TEMPLATE_TASK_PREC_AUDIT_ID);
ALTER TABLE AS_GSS_TMG_R_TEMPLATE_TASK DROP FOREIGN KEY AS_GSS_TMG_rtemplte_templtetskmaps, ADD CONSTRAINT AS_GSS_TMG_rtmplt_tmplttskmaps FOREIGN KEY (TEMPLATE_ID) REFERENCES AS_GSS_TMG_R_TEMPLATE (TEMPLATE_ID);
ALTER TABLE AS_GSS_TMG_A_R_TEMPLATE_FIELD DROP FOREIGN KEY AS_GSS_TMG_rtmplt_simplfieldchnges, ADD CONSTRAINT AS_GSS_TMG_rtmplt_smplfldchngs FOREIGN KEY (TEMPLATE_AUDIT_ID) REFERENCES AS_GSS_TMG_A_R_TEMPLATE (TEMPLATE_AUDIT_ID);
ALTER TABLE AS_GSS_TMG_R_TASK_REF DROP FOREIGN KEY AS_GSS_TMG_rtaskref_taskcategory, ADD CONSTRAINT AS_GSS_TMG_rtskrf_taskcategory FOREIGN KEY (TASK_CATEGORY_ID) REFERENCES AS_GSS_TMG_R_TASK_CATEGORY (TASK_CATEGORY_ID);
ALTER TABLE AS_GSS_TMG_R_TEMPLATE_TASK DROP FOREIGN KEY AS_GSS_TMG_rtemplatetask_taskref, ADD CONSTRAINT AS_GSS_TMG_rtmpltetask_taskref FOREIGN KEY (TASK_REF_ID) REFERENCES AS_GSS_TMG_R_TASK_REF (TASK_REF_ID);
ALTER TABLE AS_GSS_CONSENSUS_RESPONSE DROP FOREIGN KEY asgssconsensusrspnse_consensusid, ADD CONSTRAINT asgsscnsnsusrspnse_consensusid FOREIGN KEY (CONSENSUS_ID) REFERENCES AS_GSS_CONSENSUS (CONSENSUS_ID);
ALTER TABLE AS_GSS_TMG_TASK DROP FOREIGN KEY AS_GSS_TMG_task_docuploadcontext, ADD CONSTRAINT AS_GSS_TMG_tsk_dcuploadcontext FOREIGN KEY (TASK_DOC_UPLOAD_ID) REFERENCES AS_GSS_TMG_TASK_DOC_UPLOAD (TASK_DOC_UPLOAD_ID);
ALTER TABLE AS_GSS_TMG_TASK DROP FOREIGN KEY AS_GSS_TMG_task_taskbehaviortype, ADD CONSTRAINT AS_GSS_TMG_tsk_tskbehaviortype FOREIGN KEY (TASK_BEHAVIOR_TYPE_ID) REFERENCES AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE (TASK_BEHAVIOR_TYPE_ID);
ALTER TABLE AS_GSS_EVALUATION_VENDOR_BUSINESS_TYPE DROP FOREIGN KEY asgssevalvendrbsnstype_typecode, ADD CONSTRAINT asgssvalvendrbsnstype_typecode FOREIGN KEY (TYPE_CODE) REFERENCES AS_GAM_R_BUSINESS_TYPE (CODE);

-- Columns to rename for AS_GSS
ALTER TABLE AS_GSS_A_R_CONSENSUS_RESPONSE_FIELD RENAME COLUMN CONSENSUS_RESPONSE_AUDIT_FIELD_ID TO CNSNSS_RESPONSE_AUDIT_FIELD_ID;
ALTER TABLE AS_GSS_A_R_EVALUATION_PHASE_FIELD RENAME COLUMN EVALUATION_PHASE_AUDIT_FIELD_ID TO EVLUATION_PHASE_AUDIT_FIELD_ID;

-- Tables to rename for AS_GSS
ALTER TABLE AS_GSS_A_R_EVALUATION_VENDOR_BUSINESS_TYPE_FIELD RENAME TO AS_GSS_A_R_EV_VDR_BZ_TP_FLD;
ALTER TABLE AS_GSS_A_R_EVALUATION_VENDOR_BUSINESS_TYPE RENAME TO AS_GSS_A_R_EVAL_VDR_BIZ_TYP;
ALTER TABLE AS_GSS_EVALUATION_VENDOR_BUSINESS_TYPE RENAME TO AS_GSS_EVLTN_VNDR_BSNSS_TYP;
ALTER TABLE AS_GSS_A_R_EVALUATION_RESPONSES_FIELD RENAME TO AS_GSS_A_R_EVLTN_RSPNSS_FLD;
ALTER TABLE AS_GSS_TMG_TASK_CHANGE_REASON_MAPPING RENAME TO AS_GSS_TMG_TSK_CHG_RSN_MAP;
ALTER TABLE AS_GSS_TMG_A_TASK_PROCESS_SETUP_FIELD RENAME TO AS_GSS_TMG_A_TK_PRC_STP_FLD;
ALTER TABLE AS_GSS_A_R_CRITERIA_ASSIGNMENTS_FIELD RENAME TO AS_GSS_A_R_CRTR_ASSGNS_FLD;
ALTER TABLE AS_GSS_A_R_EVALUATION_DOCUMENT_FIELD RENAME TO AS_GSS_A_R_EVLTN_DCMNT_FELD;
ALTER TABLE AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC_F RENAME TO AS_GSS_TMG_A_R_TPL_TK_PRC_F;
ALTER TABLE AS_GSS_TMG_A_TEMPLATE_PROCESS_SETUP RENAME TO AS_GSS_TMG_A_TMPLT_PROC_STP;
ALTER TABLE AS_GSS_TMG_R_TEMPLATE_TASK_PRECEDNT RENAME TO AS_GSS_TMG_R_TMPLT_TSK_PREC;
ALTER TABLE AS_GSS_A_R_CONSENSUS_RESPONSE_FIELD RENAME TO AS_GSS_A_R_CNSNSS_RSPNS_FLD;
ALTER TABLE AS_GSS_TMG_A_R_TEMPLATE_TASK_FIELD RENAME TO AS_GSS_TMG_A_R_TPL_TSK_FLD;
ALTER TABLE AS_GSS_A_R_EVALUATION_VENDOR_FIELD RENAME TO AS_GSS_A_R_EVLTN_VNDR_FIELD;
ALTER TABLE AS_GSS_TMG_A_R_TASK_CATEGORY_FIELD RENAME TO AS_GSS_TMG_A_R_TSK_CAT_FLD;
ALTER TABLE AS_GSS_TMG_A_R_TEMPLATE_TASK_PREC RENAME TO AS_GSS_TMG_A_R_TPL_TSK_PRC;
ALTER TABLE AS_GSS_A_R_EVALUATION_PHASE_FIELD RENAME TO AS_GSS_A_R_EVLTN_PHSE_FIELD;
ALTER TABLE AS_GSS_TMG_R_TASK_REF_DOC_UPLOAD RENAME TO AS_GSS_TMG_R_TSK_RF_DC_UPLD;
ALTER TABLE AS_GSS_A_R_TEAM_MEMBERSHIP_FIELD RENAME TO AS_GSS_A_R_TM_MMBRSHP_FIELD;
ALTER TABLE AS_GSS_TMG_R_TASK_BEHAVIOR_TYPE RENAME TO AS_GSS_TMG_R_TSK_BHVOR_TYPE;
ALTER TABLE AS_GSS_A_R_EVALUATION_RESPONSES RENAME TO AS_GSS_A_R_EVLTON_RESPONSES;
ALTER TABLE AS_GSS_A_R_CRITERIA_ASSIGNMENTS RENAME TO AS_GSS_A_R_CRTR_ASSIGNMENTS;
ALTER TABLE AS_GSS_A_R_EVALUATOR_TEAM_FIELD RENAME TO AS_GSS_A_R_EVLTR_TEAM_FIELD;
ALTER TABLE AS_GSS_TMG_A_TASK_PROCESS_SETUP RENAME TO AS_GSS_TMG_A_TSK_PRCSS_STUP;
ALTER TABLE AS_GSS_FACTOR_DOCUMENT_MAPPING RENAME TO AS_GSS_FCTR_DCUMENT_MAPPING;
ALTER TABLE AS_GSS_A_R_EVALUATION_DOCUMENT RENAME TO AS_GSS_A_R_EVLTION_DOCUMENT;
ALTER TABLE AS_GSS_A_R_CONSENSUS_RESPONSE RENAME TO AS_GSS_A_R_CNSNSUS_RESPONSE;
ALTER TABLE AS_GSS_R_VENDOR_BUSINESS_TYPE RENAME TO AS_GSS_R_VNDR_BUSINESS_TYPE;
ALTER TABLE AS_GSS_TMG_A_R_TASK_REF_FIELD RENAME TO AS_GSS_TMG_A_R_TSK_RF_FIELD;
ALTER TABLE AS_GSS_TMG_A_R_TEMPLATE_FIELD RENAME TO AS_GSS_TMG_A_R_TMPLTE_FIELD;
ALTER TABLE AS_GSS_TMG_TASK_ACTION_AUDIT RENAME TO AS_GSS_TMG_TSK_ACTION_AUDIT;
ALTER TABLE AS_GSS_A_R_EVALUATION_VENDOR RENAME TO AS_GSS_A_R_EVLUATION_VENDOR;
ALTER TABLE AS_GSS_TMG_A_R_TASK_CATEGORY RENAME TO AS_GSS_TMG_A_R_TSK_CATEGORY;
ALTER TABLE AS_GSS_TMG_A_R_TEMPLATE_TASK RENAME TO AS_GSS_TMG_A_R_TMPLATE_TASK;

-- Views with long names to recreate for AS_GSS
DROP VIEW IF EXISTS AS_GSS_V_EVALUATION_DOC_ADDITIONAL_INFO;
CREATE OR REPLACE VIEW AS_GSS_V_EVLTN_DC_ADDTNAL_INFO
AS
  SELECT D.*,
         C.CRITERIA_NAME,
         C.FACTOR_NUMBER,
         V.LEGAL_NAME,
         DT.REF_LABEL AS DOC_TYPE_LABEL
  FROM AS_GSS_EVALUATION_DOCUMENT D
         LEFT JOIN AS_GSS_CRITERIA C
                ON ( D.CRITERIA_ID = C.CRITERIA_ID )
         LEFT JOIN AS_GSS_EVALUATION_VENDOR V
                ON ( D.VENDOR_ID = V.VENDOR_ID )
         LEFT JOIN AS_GSS_R_DATA DT
                ON ( D.DOC_TYPE = DT.REF_DATA_ID );

-- No views with long columns to recreate for AS_GSS

-- No other views to recreate AS_GSS

-- No other objects to rename for AS_GSS;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 38, 1217, 1150);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;





-- **********************
-- Source Selection 1.4
-- **********************


-- **************************************************************************
-- [2305] Add column IS_EVALUATOR_UPDATED and,IS_LATEST in AS_GSS_CONSENSUS
-- **************************************************************************
-- Add column IS_EVALUATOR_UPDATED,IS_LATEST in AS_GSS_CONSENSUS
-- **************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",45, "Source Selection 1.4", 2305, "Add column IS_EVALUATOR_UPDATED and,IS_LATEST in AS_GSS_CONSENSUS",1730,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_CONSENSUS`
   ADD `IS_EVALUATOR_UPDATED` TINYINT(1) NULL DEFAULT NULL AFTER `IS_ACTIVE`;

ALTER TABLE `AS_GSS_CONSENSUS`
   ADD `IS_LATEST` TINYINT(1) NULL DEFAULT NULL AFTER `IS_ACTIVE`;


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 45, 2305, 1730);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************************
-- [2307] Adding Ref Data in AS_GSS_TMG_R_TASK_STATUS
-- ****************************************************
-- Adding Ref Data in AS_GSS_TMG_R_TASK_STATUS
-- ****************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",45, "Source Selection 1.4", 2307, "Adding Ref Data in AS_GSS_TMG_R_TASK_STATUS",1731,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_TMG_R_TASK_STATUS` (`TASK_STATUS_ID`, `STATUS_DISPLAY_NAME`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES
(8, 'txt_StatusCompletedNotNeeded', 'appian.administrator', SYSDATE(), 'appian.administrator', SYSDATE()),
(9, 'txt_StatusCompletedNeeded', 'appian.administrator', SYSDATE(), 'appian.administrator', SYSDATE()),
(10, 'txt_StatusTerminated', 'appian.administrator', SYSDATE(), 'appian.administrator', SYSDATE());

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 45, 2307, 1731);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **********************************
-- [2308] Insert into AS_GSS_R_DATA
-- **********************************
-- Insert into AS_GSS_R_DATA
-- **********************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",45, "Source Selection 1.4", 2308, "Insert into AS_GSS_R_DATA",1732,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`)
VALUES (53,'Temp', NULL,'Consensus Status',4,1, CURRENT_USER,CURRENT_TIMESTAMP,CURRENT_USER, CURRENT_TIMESTAMP);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 45, 2308, 1732);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *****************************************************
-- [2394] Adding Instruction column in AS_GSS_CRITERIA
-- *****************************************************
-- Adding Instruction column in AS_GSS_CRITERIA
-- *****************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",45, "Source Selection 1.4", 2394, "Adding Instruction column in AS_GSS_CRITERIA",1789,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_CRITERIA ADD COLUMN INSTRUCTION VARCHAR(2000) DEFAULT NULL AFTER CRITERIA_DESCRIPTION;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 45, 2394, 1789);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;





-- **********************
-- Source Selection 1.5
-- **********************


-- **********************************************************
-- [2653] Insert Consensus Archival reasons
-- **********************************************************
-- Insert Consensus Archival reasons in AS_GSS_R_DATA table
-- **********************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",72, "Source Selection 1.5", 2653, "Insert Consensus Archival reasons",1961,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DATA`(
    `REF_DATA_ID`,
    `REF_LABEL`,
    `REF_DESCRIPTION`,
    `REF_TYPE`,
    `REF_ICON`,
    `REF_COLOR`,
    `SORT_ORDER`,
    `IS_ACTIVE`,
    `CREATED_BY`,
    `CREATED_DATETIME`,
    `MODIFIED_BY`,
    `MODIFIED_DATETIME`
)
VALUES(
    54,
    'New evaluators have been added to the team',
    NULL,
    'Consensus Report Archival Reason',
    NULL,
    NULL,
    '1',
    '1',
    'appian.administrator',
    CURRENT_TIMESTAMP,
    'appian.administrator',
    CURRENT_TIMESTAMP
);
INSERT INTO `AS_GSS_R_DATA`(
    `REF_DATA_ID`,
    `REF_LABEL`,
    `REF_DESCRIPTION`,
    `REF_TYPE`,
    `REF_ICON`,
    `REF_COLOR`,
    `SORT_ORDER`,
    `IS_ACTIVE`,
    `CREATED_BY`,
    `CREATED_DATETIME`,
    `MODIFIED_BY`,
    `MODIFIED_DATETIME`
)
VALUES(
    55,
    'Inconsistencies / errors in consensus report',
    NULL,
    'Consensus Report Archival Reason',
    NULL,
    NULL,
    '2',
    '1',
    'appian.administrator',
    CURRENT_TIMESTAMP,
    'appian.administrator',
    CURRENT_TIMESTAMP
);
INSERT INTO `AS_GSS_R_DATA`(
    `REF_DATA_ID`,
    `REF_LABEL`,
    `REF_DESCRIPTION`,
    `REF_TYPE`,
    `REF_ICON`,
    `REF_COLOR`,
    `SORT_ORDER`,
    `IS_ACTIVE`,
    `CREATED_BY`,
    `CREATED_DATETIME`,
    `MODIFIED_BY`,
    `MODIFIED_DATETIME`
)
VALUES(
    56,
    'Other',
    NULL,
    'Consensus Report Archival Reason',
    NULL,
    NULL,
    '3',
    '1',
    'appian.administrator',
    CURRENT_TIMESTAMP,
    'appian.administrator',
    CURRENT_TIMESTAMP
);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 72, 2653, 1961);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***********************************************
-- [2654] Add/rename/delete Consensus columns
-- ***********************************************
-- Add/rename/delete columns in AS_GSS_CONSENSUS
-- ***********************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",72, "Source Selection 1.5", 2654, "Add/rename/delete Consensus columns",2002,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_CONSENSUS` ADD `VERSION` INT(11) DEFAULT NULL AFTER `CONSENSUS_ID`, ADD `ARCHIVAL_REASON` INT(11) DEFAULT NULL AFTER `RATING_JUSTIFICATION`, ADD `ARCHIVAL_REASON_DETAILS` VARCHAR(4000) DEFAULT NULL AFTER `ARCHIVAL_REASON`;

UPDATE `AS_GSS_CONSENSUS` SET `IS_LATEST` = 0;
ALTER TABLE `AS_GSS_CONSENSUS` CHANGE `IS_LATEST` `IS_ARCHIVED` TINYINT(1) NOT NULL DEFAULT 0;

ALTER TABLE `AS_GSS_CONSENSUS` DROP `IS_EVALUATOR_UPDATED`;

ALTER TABLE `AS_GSS_CONSENSUS` ADD CONSTRAINT `asgssconsensus_archreason` FOREIGN KEY (`ARCHIVAL_REASON`) REFERENCES `AS_GSS_R_DATA`(`REF_DATA_ID`);



-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 72, 2654, 2002);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *******************************************************
-- [2655] Delete Task status
-- *******************************************************
-- Delete unused task status in AS_GSS_TMG_R_TASK_STATUS
-- *******************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",72, "Source Selection 1.5", 2655, "Delete Task status",1963,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

DELETE FROM AS_GSS_TMG_R_TASK_STATUS WHERE `AS_GSS_TMG_R_TASK_STATUS`.`TASK_STATUS_ID` = 10;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 72, 2655, 1963);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ******************************************************************
-- [2656] Rename Consensus to Consensus Report
-- ******************************************************************
-- Rename table names and status from Consensus to Consensus Report
-- ******************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",72, "Source Selection 1.5", 2656, "Rename Consensus to Consensus Report",1964,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE `AS_GSS_R_DATA` SET REF_TYPE='Consensus Report Status' WHERE REF_TYPE='Consensus Status';

ALTER TABLE AS_GSS_CONSENSUS RENAME AS_GSS_CONSENSUS_REPORT;

ALTER TABLE AS_GSS_A_R_CONSENSUS RENAME AS_GSS_A_R_CONSENSUS_REPORT ;

ALTER TABLE AS_GSS_A_R_CONSENSUS_FIELD RENAME AS_GSS_A_R_CNSNSUS_REPT_FLD;


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 72, 2656, 1964);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ************************************************************************************************************
-- [2663] Deprecated COMPELTED_NEEDED and COMPLETED_NOT_NEEDED task statuses
-- ************************************************************************************************************
-- We no longer need these statuses, as we are handling task/consensus association through the response table
-- ************************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",72, "Source Selection 1.5", 2663, "Deprecated COMPELTED_NEEDED and COMPLETED_NOT_NEEDED task statuses",1967,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_TMG_TASK SET TASK_STATUS_ID = 5 WHERE TASK_STATUS_ID IN (8, 9);

DELETE FROM AS_GSS_TMG_R_TASK_STATUS WHERE TASK_STATUS_ID IN (8,9);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 72, 2663, 1967);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ************************************************************************
-- [2677] Deprecate consensus related fields in EVALUATION_RESPONSE table
-- ************************************************************************
-- These fields are no longer relevant at the evaluation response level
-- ************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",72, "Source Selection 1.5", 2677, "Deprecate consensus related fields in EVALUATION_RESPONSE table",1978,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVALUATION_RESPONSES` CHANGE `CONSENSUS_ID` `DEPRECATED_CONSENSUS_ID` int(11) COMMENT 'Deprecated in GSS 1.5 -- CONSENSUS_RESPONSE now points to the relevant EVALUATION_RESPONSES for a Consensus Report' AFTER IS_ACTIVE;

ALTER TABLE `AS_GSS_EVALUATION_RESPONSES` CHANGE `IS_INCLUDED` `DEPRECATED_IS_INCLUDED` tinyint(1) COMMENT 'Deprecated in GSS 1.5 -- CONSENSUS_RESPONSE now tracks all consensus related information regarding responses' AFTER IS_ACTIVE;

ALTER TABLE `AS_GSS_EVALUATION_RESPONSES` CHANGE `INCLUDED_COMMENTS` `DEPRECATED_INCLUDED_COMMENTS` varchar(255) COMMENT 'Deprecated in GSS 1.5 -- CONSENSUS_RESPONSE now tracks all consensus related information regarding responses' AFTER IS_ACTIVE;

ALTER TABLE `AS_GSS_EVALUATION_RESPONSES` CHANGE `COMBINATION_ORDER` `DEPRECATED_COMBINATION_ORDER` int(11) COMMENT 'Deprecated in GSS 1.5 -- CONSENSUS_RESPONSE now tracks all consensus related information for responses' AFTER IS_ACTIVE;

ALTER TABLE `AS_GSS_EVALUATION_RESPONSES` CHANGE `RESPONSE_ORDER` `DEPRECATED_RESPONSE_ORDER` int(11) COMMENT 'Deprecated in GSS 1.5 -- CONSENSUS_RESPONSE now tracks all consensus related information for responses' AFTER IS_ACTIVE;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 72, 2677, 1978);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **************************************************************************
-- [2678] Adding consensus specific information to CONSENSUS_RESPONSE table
-- **************************************************************************
-- These fields are now tracked at the consensus response level
-- **************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",72, "Source Selection 1.5", 2678, "Adding consensus specific information to CONSENSUS_RESPONSE table",1979,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_CONSENSUS_RESPONSE` ADD COLUMN `EVALUATION_RESPONSE_ID` int(11) DEFAULT NULL COMMENT 'The evaluation response that this consensus response is based on' AFTER CONSENSUS_RESPONSE_ID ;

ALTER TABLE `AS_GSS_CONSENSUS_RESPONSE` ADD COLUMN `IS_INCLUDED` tinyint(1) DEFAULT NULL COMMENT 'Determines whether or not this response is included in the final consensus report' AFTER EVALUATION_RESPONSE_ID ;

ALTER TABLE `AS_GSS_CONSENSUS_RESPONSE` ADD COLUMN `INCLUDED_COMMENTS` varchar(255) DEFAULT NULL COMMENT 'Additional comments on why the responses was included/excluded from the report' AFTER IS_INCLUDED;

ALTER TABLE `AS_GSS_CONSENSUS_RESPONSE` ADD COLUMN `COMBINED_CONSENSUS_RESPONSE_ID` int(11) DEFAULT NULL COMMENT 'When responses are merged, a new row is created containing the merged text, and the merged rows point to this new response using this column' AFTER INCLUDED_COMMENTS;

ALTER TABLE `AS_GSS_CONSENSUS_RESPONSE` CHANGE `COMBINATION_ORDER` `DEPRECATED_COMBINATION_ORDER` int(11) COMMENT 'Deprecated in GSS 1.5 -- Order is not important, and previously mapped a consensus response to an evaluation response, but this is now done directly' AFTER IS_ACTIVE;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 72, 2678, 1979);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ********************************************************************************
-- [2679] Migrate EVALUATION_RESPONSE information into CONSENSUS_RESPONSE
-- ********************************************************************************
-- Update existing rows in CONSENSUS_RESPONSE to work with the new data structure
-- ********************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",72, "Source Selection 1.5", 2679, "Migrate EVALUATION_RESPONSE information into CONSENSUS_RESPONSE",4061,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_CONSENSUS_RESPONSE consensusResponse JOIN (
	SELECT CONSENSUS_RESPONSE_ID, EVALUATION_RESPONSE_ID, IS_INCLUDED, INCLUDED_COMMENTS
	FROM (
		SELECT
		 RESPONSE_ID AS EVALUATION_RESPONSE_ID,
		 DEPRECATED_CONSENSUS_ID AS CONSENSUS_ID,
		 DEPRECATED_IS_INCLUDED AS IS_INCLUDED,
		 DEPRECATED_INCLUDED_COMMENTS AS INCLUDED_COMMENTS,
		 ROW_NUMBER() OVER(
		 PARTITION BY DEPRECATED_CONSENSUS_ID
		 ORDER BY RESPONSE_ID
		 ) AS R1
		FROM
		 AS_GSS_EVALUATION_RESPONSES
		WHERE
		 DEPRECATED_CONSENSUS_ID IS NOT NULL
	) AS evaluationResponseMigration
	JOIN (
		SELECT
		 CONSENSUS_RESPONSE_ID,
		 CONSENSUS_ID,
		 ROW_NUMBER() OVER(
		 PARTITION BY CONSENSUS_ID
		 ORDER BY CONSENSUS_RESPONSE_ID
		 ) AS R1
		FROM
		 AS_GSS_CONSENSUS_RESPONSE
	) AS consensusResponseMigration
	ON evaluationResponseMigration.CONSENSUS_ID = consensusResponseMigration.CONSENSUS_ID
	AND evaluationResponseMigration.R1 = consensusResponseMigration.R1
) migrationData USING (CONSENSUS_RESPONSE_ID) SET
consensusResponse.EVALUATION_RESPONSE_ID = migrationData.EVALUATION_RESPONSE_ID,
consensusResponse.IS_INCLUDED = migrationData.IS_INCLUDED,
consensusResponse.INCLUDED_COMMENTS = migrationData.INCLUDED_COMMENTS;

UPDATE AS_GSS_CONSENSUS_RESPONSE
SET IS_ACTIVE = 1, IS_INCLUDED = 0, INCLUDED_COMMENTS = CONCAT('Responses grouped prior to upgrade have been automatically excluded

', INCLUDED_COMMENTS)
WHERE IS_ACTIVE = 0 AND IS_INCLUDED = 1 AND INCLUDED_COMMENTS <> '';

UPDATE AS_GSS_CONSENSUS_RESPONSE
SET IS_ACTIVE = 1, IS_INCLUDED = 0, INCLUDED_COMMENTS = 'Responses grouped prior to upgrade have been automatically excluded'
WHERE IS_ACTIVE = 0 AND IS_INCLUDED = 1 AND INCLUDED_COMMENTS = '';

UPDATE AS_GSS_CONSENSUS_RESPONSE
SET IS_ACTIVE = 1;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 72, 2679, 4061);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************************************************
-- [2705] Deactivate TEMP consensus reports and set VERSION on remaining rows
-- ****************************************************************************
-- These consensuses and Consensus status are no longer relevant/valid
-- ****************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",72, "Source Selection 1.5", 2705, "Deactivate TEMP consensus reports and set VERSION on remaining rows",2003,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_CONSENSUS_REPORT SET IS_ACTIVE = 0 WHERE STATUS_ID = 53;
UPDATE AS_GSS_CONSENSUS_REPORT SET VERSION = 1 WHERE IS_ACTIVE = 1;
UPDATE AS_GSS_R_DATA SET IS_ACTIVE = 0 WHERE REF_DATA_ID = 53;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 72, 2705, 2003);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************************************
-- [2711] Update consensus report status ref data icon and color
-- ***************************************************************
-- Moving front-end values into the DB
-- ***************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",72, "Source Selection 1.5", 2711, "Update consensus report status ref data icon and color",2006,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE `AS_GSS_R_DATA` SET `REF_ICON` = 'circle-o', `REF_COLOR` = 'STANDARD' WHERE `REF_DATA_ID` = 45;
UPDATE `AS_GSS_R_DATA` SET `REF_ICON` = 'spinner-alt', `REF_COLOR` = 'STANDARD' WHERE `REF_DATA_ID` = 46;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 72, 2711, 2006);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************************************************
-- [2714] Adding new sequences in Oracle
-- ****************************************************************************
-- Dropped old sequences and added new sequences for Consensus related tables
-- ****************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",72, "Source Selection 1.5", 2714, "Adding new sequences in Oracle",2247,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

-- Adding dummy script here, as this script request is to add Sequences in Oracle DB only

CREATE TABLE `AS_VM_TEMP` (
  `ID` int(11) NOT NULL,
  PRIMARY KEY (`ID`)
);

DROP TABLE AS_VM_TEMP;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 72, 2714, 2247);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;





-- **********************
-- Source Selection 1.6
-- **********************


-- ************************************************
-- [3093] Create AS_GSS_CONSENSUS_SIGNATURE table
-- ************************************************
-- Create AS_GSS_CONSENSUS_SIGNATURE table
-- ************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",189, "Source Selection 1.6", 3093, "Create AS_GSS_CONSENSUS_SIGNATURE table",2459,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE AS_GSS_CONSENSUS_SIGNATURE (
  CONSENSUS_SIGNATURE_ID INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY COMMENT 'Primary key',
  CONSENSUS_ID INT(11) NOT NULL COMMENT 'Consensus being signed',
    FOREIGN KEY (CONSENSUS_ID) REFERENCES AS_GSS_CONSENSUS_REPORT(CONSENSUS_ID),
  USERNAME VARCHAR(255) DEFAULT NULL COMMENT 'The user signing off on the consensus.',
  SIGNATURE_TIMESTAMP DATETIME DEFAULT NULL COMMENT 'Timestamp of the signature. Nullable, in which case the signature is pending.',
  CREATED_BY VARCHAR(255) DEFAULT NULL COMMENT 'The user who created the row',
  CREATED_DATETIME DATETIME DEFAULT NULL COMMENT 'Creation timestamp',
  MODIFIED_BY VARCHAR(255) DEFAULT NULL COMMENT 'Last user to modify the row',
  MODIFIED_DATETIME DATETIME DEFAULT NULL COMMENT 'Modification timestamp',
  IS_ACTIVE TINYINT(1) DEFAULT NULL COMMENT 'Is Signature Active'
) AUTO_INCREMENT=1 COMMENT 'Used to track signatures on a consensus.';

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 189, 3093, 2459);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *********************************************************
-- [3095] Insert new consensus status, Awaiting Signatures
-- *********************************************************
-- Update existing data sort order and insert row
-- *********************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",189, "Source Selection 1.6", 3095, "Insert new consensus status, Awaiting Signatures",2456,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

-- Remove sort order from deprecated "Temp" row
UPDATE `AS_GSS_R_DATA` SET SORT_ORDER = NULL WHERE REF_DATA_ID = 53;

-- Update sort order of "Complete" to be after new status "Awaiting Signatures"
UPDATE `AS_GSS_R_DATA` SET SORT_ORDER = 4 WHERE REF_DATA_ID = 47;

-- Insert new data
INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES (57, 'Awaiting Signature', NULL, 'Consensus Report Status', 'signature', NULL, 3, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 189, 3095, 2456);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *************************************************************
-- [3099] Add IS_SIGNATURES_REQUIRED to IS_SIGNATURES_REQUIRED
-- *************************************************************
-- Add IS_SIGNATURES_REQUIRED to IS_SIGNATURES_REQUIRED
-- *************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",189, "Source Selection 1.6", 3099, "Add IS_SIGNATURES_REQUIRED to IS_SIGNATURES_REQUIRED",2457,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVALUATION` ADD `IS_SIGNATURES_REQUIRED` TINYINT(1) DEFAULT NULL COMMENT 'Indicates whether or not e-signatures are be required for the consensus document.' AFTER `CONTRACTING_SPECIALIST`;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 189, 3099, 2457);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************************************************************************************
-- [3154] Updating existing customer columns to prevent errors on utf8_mb4 database
-- ****************************************************************************************************************
-- Existing customer scripts should match new customers, so we need to update these existing columns to be longer
-- ****************************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",189, "Source Selection 1.6", 3154, "Updating existing customer columns to prevent errors on utf8_mb4 database",2484,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_TMG_TASK MODIFY JUSTIFICATION TEXT;

ALTER TABLE AS_GSS_EVALUATION_RESPONSES MODIFY RESPONSE TEXT;
ALTER TABLE AS_GSS_EVALUATION_RESPONSES MODIFY JUSTIFICATION TEXT;
ALTER TABLE AS_GSS_EVALUATION_RESPONSES MODIFY `REFERENCES` TEXT;

ALTER TABLE AS_GSS_CONSENSUS_REPORT MODIFY RATING_JUSTIFICATION TEXT;

ALTER TABLE AS_GSS_CONSENSUS_RESPONSE MODIFY RESPONSE TEXT;
ALTER TABLE AS_GSS_CONSENSUS_RESPONSE MODIFY JUSTIFICATION TEXT;
ALTER TABLE AS_GSS_CONSENSUS_RESPONSE MODIFY `REFERENCES` TEXT;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 189, 3154, 2484);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *************************************************************************************************************
-- [3173] Updating audit columns to store increased value size
-- *************************************************************************************************************
-- Given the above increases to column size, we must also increase the size of the corresponding audit columns
-- *************************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",189, "Source Selection 1.6", 3173, "Updating audit columns to store increased value size",2495,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

-- we don't audit runtime tasks, so nothing to update for that

ALTER TABLE AS_GSS_A_R_EVLTN_RSPNSS_FLD MODIFY OLD_VALUE TEXT;
ALTER TABLE AS_GSS_A_R_EVLTN_RSPNSS_FLD MODIFY NEW_VALUE TEXT;

ALTER TABLE AS_GSS_A_R_CNSNSUS_REPT_FLD MODIFY OLD_VALUE TEXT;
ALTER TABLE AS_GSS_A_R_CNSNSUS_REPT_FLD MODIFY NEW_VALUE TEXT;

ALTER TABLE AS_GSS_A_R_CNSNSS_RSPNS_FLD MODIFY OLD_VALUE TEXT;
ALTER TABLE AS_GSS_A_R_CNSNSS_RSPNS_FLD MODIFY NEW_VALUE TEXT;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 189, 3173, 2495);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *************************************************
-- [3196] Insert Reference document type in R_DATA
-- *************************************************
-- Insert Reference document type
-- *************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",189, "Source Selection 1.6", 3196, "Insert Reference document type in R_DATA",2514,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES (58, 'Reference', NULL, 'Document Type', NULL, NULL, 6, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 189, 3196, 2514);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *********************************************
-- [3205] Create Consensus AI Suggestion table
-- *********************************************
-- Create table - AS_GSS_CNSNS_AI_SUGGESTION
-- *********************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",189, "Source Selection 1.6", 3205, "Create Consensus AI Suggestion table",2521,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE `AS_GSS_CNSNS_AI_SUGGESTION` (
  `CONSENSUS_AI_RESPONSE_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY COMMENT 'Primary key',
  `CONSENSUS_ID` int(11) DEFAULT NULL COMMENT 'Each consensus form has an option to request an OpenAI generated Rating Justification comments',
  `IS_SUCCESS` tinyint(1) DEFAULT NULL,
  `PROMPT` text DEFAULT NULL COMMENT 'Prompt sent to OpenAI through integration',
  `RESPONSE` text DEFAULT NULL COMMENT 'Text generated by OpenAI',
  `ERROR_INFO` varchar(4000) DEFAULT NULL COMMENT 'Error information sent from OpenAI if integration fails',
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT 1
) COMMENT 'Table to hold request and response information from the OpenAI for Rating Justification Comments of the Consensus form';

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 189, 3205, 2521);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***********************************************************
-- [3207] Create constraints for AS_GSS_CNSNS_AI_SUGGESTION 
-- ***********************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",189, "Source Selection 1.6", 3207, "Create constraints for AS_GSS_CNSNS_AI_SUGGESTION ",2522,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_CNSNS_AI_SUGGESTION ADD CONSTRAINT `asgsscnsnsaisugg_consid` FOREIGN KEY(CONSENSUS_ID) REFERENCES AS_GSS_CONSENSUS_REPORT(CONSENSUS_ID);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 189, 3207, 2522);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;





-- **********************
-- Source Selection 1.7
-- **********************


-- *****************************************************************
-- [3265] Adding weight toggle column in Evaluation table
-- *****************************************************************
-- Adding IS_WEIGHED_FACTORS_REQ column in AS_GSS_EVALUATION table
-- *****************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",202, "Source Selection 1.7", 3265, "Adding weight toggle column in Evaluation table",2561,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION ADD COLUMN IS_WEIGHTED_FACTORS_REQ TINYINT(1) NULL DEFAULT NULL COMMENT 'Indicates whether or not weights required for the factors.' AFTER IS_SIGNATURES_REQUIRED;


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 202, 3265, 2561);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ******************************************************
-- [3266] Adding weight column
-- ******************************************************
-- Adding FACTOR_WEIGHT column to AS_GSS_CRITERIA table
-- ******************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",202, "Source Selection 1.7", 3266, "Adding weight column",2562,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_CRITERIA ADD COLUMN FACTOR_WEIGHT DOUBLE NULL DEFAULT NULL AFTER COMPLETED_BY;


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 202, 3266, 2562);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ******************************************************************
-- [3267] Updating IS_WEIGHTED_FACTORS_REQfor existing evaluations
-- ******************************************************************
-- Updating IS_WEIGHTED_FACTORS_REQ for existing evaluations if any
-- ******************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",202, "Source Selection 1.7", 3267, "Updating IS_WEIGHTED_FACTORS_REQfor existing evaluations",2563,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

-- No weighed factors for existing evaluations with status Inprogress or Completed
UPDATE AS_GSS_EVALUATION SET IS_WEIGHTED_FACTORS_REQ = 0 WHERE EVALUATION_STATUS_ID IN (2,3);

-- Weighed factors is required for existing evaluations with status Setting up
UPDATE AS_GSS_EVALUATION SET IS_WEIGHTED_FACTORS_REQ = 1 WHERE EVALUATION_STATUS_ID = 1;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 202, 3267, 2563);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ********************************************************************************
-- [3308] Adding IS_ORIGINALLY_GENERATED_BY_AI column in Consensus Response table
-- ********************************************************************************
-- Adding IS_ORIGINALLY_GENERATED_BY_AI column in Consensus Response table
-- ********************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",202, "Source Selection 1.7", 3308, "Adding IS_ORIGINALLY_GENERATED_BY_AI column in Consensus Response table",2587,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_CONSENSUS_RESPONSE ADD COLUMN IS_ORIGINALLY_GENERATED_BY_AI TINYINT(1) NULL DEFAULT NULL COMMENT 'Indicates whether or not grouped response edited by AI.' AFTER IS_SIGNIFICANT;


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 202, 3308, 2587);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************************
-- [3347] Create Consensus Response AI Summary table
-- ***************************************************
-- Create table - AS_GSS_CNSNS_RESP_AI_SUMMRY
-- ***************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",202, "Source Selection 1.7", 3347, "Create Consensus Response AI Summary table",2605,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE `AS_GSS_CNSNS_RESP_AI_SUMMRY` (
  `CNSNS_RESP_AI_SUMMARY_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY COMMENT 'Primary key',
  `CONSENSUS_ID` int(11) DEFAULT NULL COMMENT 'Each consensus form has an option to request an OpenAI generated response for Combining Consensus Responses',
  `PROMPT` text DEFAULT NULL COMMENT 'Prompt sent to OpenAI through integration',
  `RESPONSE` text DEFAULT NULL COMMENT 'Response returned by OpenAI',
  `ERROR_INFO` varchar(4000) DEFAULT NULL COMMENT 'Error information sent from OpenAI if integration fails',
  `IS_SUCCESS` tinyint(1) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL
) COMMENT 'Table to hold request and response information from the Azure OpenAI for Combining Consensus Responses';

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 202, 3347, 2605);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***********************************************************
-- [3348] Create constraints for AS_GSS_CNSNS_RESP_AI_SUMMRY
-- ***********************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",202, "Source Selection 1.7", 3348, "Create constraints for AS_GSS_CNSNS_RESP_AI_SUMMRY",2606,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_CNSNS_RESP_AI_SUMMRY`
  ADD CONSTRAINT `asgsscnsnsrespaisum_consid` FOREIGN KEY (`CONSENSUS_ID`) REFERENCES `AS_GSS_CONSENSUS_REPORT` (`CONSENSUS_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 202, 3348, 2606);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************************************************************************************************************************
-- [3349] Drop columns from AS_GSS_CNSNS_AI_SUGGESTION
-- ****************************************************************************************************************************************************
-- Dropping unwanted metadata columns to make sure that AI related log tables only has Created_X columns as other metadata columns are not necessary.
-- ****************************************************************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",202, "Source Selection 1.7", 3349, "Drop columns from AS_GSS_CNSNS_AI_SUGGESTION",2607,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_CNSNS_AI_SUGGESTION
  DROP COLUMN MODIFIED_BY,
  DROP COLUMN MODIFIED_DATETIME,
  DROP COLUMN IS_ACTIVE;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 202, 3349, 2607);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *******************************************************************************************************
-- [3375] Add DUPLICATED_FROM_EVALUATION_ID to AS_GSS_EVALUATION
-- *******************************************************************************************************
-- Adding a column in AS_GSS_EVALUATION for the id of the evaluation this evaluation was duplicated from
-- *******************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",202, "Source Selection 1.7", 3375, "Add DUPLICATED_FROM_EVALUATION_ID to AS_GSS_EVALUATION",2626,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION
  ADD COLUMN `DUPLICATED_FROM_EVALUATION_ID` INT(11) DEFAULT NULL COMMENT 'Id of evaluation this evaluation was copied from' after `IS_WEIGHTED_FACTORS_REQ`;

ALTER TABLE AS_GSS_EVALUATION
  ADD CONSTRAINT `asgssdupeval_eval` FOREIGN KEY (`DUPLICATED_FROM_EVALUATION_ID`) REFERENCES `AS_GSS_EVALUATION` (`EVALUATION_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 202, 3375, 2626);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *************************************************************************
-- [3390] Update Ref Color for Completed Evaluation Status
-- *************************************************************************
-- Update Ref Color for Completed Evaluation Status in AS_GSS_R_DATA table
-- *************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",202, "Source Selection 1.7", 3390, "Update Ref Color for Completed Evaluation Status",2640,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_R_DATA SET REF_COLOR = '#117C00' WHERE REF_DATA_ID = 3;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 202, 3390, 2640);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;





-- **********************
-- Source Selection 1.8
-- **********************


-- **********************************************************************
-- [3982] Add comments to deprecated columns in AS_GSS_EVALUATION_PHASE
-- **********************************************************************
-- Add comments to deprecated columns in AS_GSS_EVALUATION_PHASE
-- **********************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",226, "Source Selection 1.8", 3982, "Add comments to deprecated columns in AS_GSS_EVALUATION_PHASE",3081,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVALUATION_PHASE` CHANGE `DURATION` `DURATION` VARCHAR(25) COMMENT 'DEPRECATED IN GSS 1.8 -- This column is not used' ;

ALTER TABLE `AS_GSS_EVALUATION_PHASE` CHANGE `DURATION_UNIT` `DURATION_UNIT` INT(11) COMMENT 'DEPRECATED IN GSS 1.8 -- This column is not used' ;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 226, 3982, 3081);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *********************************************************************************
-- [4125] Remove comments to Duration and Duration Unit in AS_GSS_EVALUATION_PHASE
-- *********************************************************************************
-- Remove comments from columns in AS_GSS_EVALUATION_PHASE
-- *********************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",226, "Source Selection 1.8", 4125, "Remove comments to Duration and Duration Unit in AS_GSS_EVALUATION_PHASE",3182,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVALUATION_PHASE` CHANGE `DURATION` `DURATION` VARCHAR(25) COMMENT '' ;

ALTER TABLE `AS_GSS_EVALUATION_PHASE` CHANGE `DURATION_UNIT` `DURATION_UNIT` INT(11) COMMENT '' ;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 226, 4125, 3182);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *************************************************************
-- [4126] Modify Evaluation Status Labels
-- *************************************************************
-- Script to update the labels of the Evaluation status values
-- *************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",226, "Source Selection 1.8", 4126, "Modify Evaluation Status Labels",3181,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_R_DATA SET REF_LABEL='Set up' WHERE REF_DATA_ID=1;
UPDATE AS_GSS_R_DATA SET REF_LABEL='In Progress' WHERE REF_DATA_ID=2;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 226, 4126, 3181);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;





-- **********************
-- Source Selection 1.9
-- **********************


-- **********************************************************
-- [4294] Add source application ref data
-- **********************************************************
-- This script is to insert the source application ref data
-- **********************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",236, "Source Selection 1.9", 4294, "Add source application ref data",3320,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES (59, 'GSS', NULL, 'Source Application', NULL, NULL, '1', '1', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(60, 'GCW', NULL, 'Source Application', NULL, NULL, '2', '1', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 236, 4294, 3320);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **************************************************************
-- [4297] Add Source Application Id column to AS_GSS_EVALUATION
-- **************************************************************
-- Add a new column to identify the source of evaluation
-- **************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",236, "Source Selection 1.9", 4297, "Add Source Application Id column to AS_GSS_EVALUATION",3321,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE
    `AS_GSS_EVALUATION` ADD `SOURCE_APPLICATION_ID` INT NULL DEFAULT NULL;


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 236, 4297, 3321);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **********************************************************
-- [4304] Set source application id on existing evaluations
-- **********************************************************
-- Set source application id on existing evaluations
-- **********************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",236, "Source Selection 1.9", 4304, "Set source application id on existing evaluations",3324,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE `AS_GSS_EVALUATION` SET SOURCE_APPLICATION_ID=59;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 236, 4304, 3324);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***********************************************************************
-- [4305] Add Source Application Id column to AS_GSS_EVALUATION_DOCUMENT
-- ***********************************************************************
-- To add new column in AS_GSS_EVALUATION_DOCUMENT
-- ***********************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",236, "Source Selection 1.9", 4305, "Add Source Application Id column to AS_GSS_EVALUATION_DOCUMENT",3325,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVALUATION_DOCUMENT` ADD `SOURCE_APPLICATION_ID` INT NULL DEFAULT NULL;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 236, 4305, 3325);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ********************************************************
-- [4306] Set source application id on existing documents
-- ********************************************************
-- To set source application id on existing GSS documents
-- ********************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",236, "Source Selection 1.9", 4306, "Set source application id on existing documents",3326,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE `AS_GSS_EVALUATION_DOCUMENT` SET SOURCE_APPLICATION_ID=59;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 236, 4306, 3326);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***********************************************************************
-- [4392] Add Ref Data for Evaluation Status Deleted
-- ***********************************************************************
-- script to add Ref Data for Evaluation Status Deleted in AS_GSS_R_DATA
-- ***********************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",236, "Source Selection 1.9", 4392, "Add Ref Data for Evaluation Status Deleted",3387,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES
(61, 'Deleted', NULL, 'Evaluation Status', NULL, NULL, 5, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 236, 4392, 3387);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ********************************************************************
-- [4393] Add new column DeletionReason in AS_GSS_EVALUATION
-- ********************************************************************
-- script to add new column DeletionReason in AS_GSS_EVALUATION table
-- ********************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",236, "Source Selection 1.9", 4393, "Add new column DeletionReason in AS_GSS_EVALUATION",3388,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION ADD COLUMN DELETION_REASON VARCHAR(1000);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 236, 4393, 3388);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *****************************************************************************************************************
-- [4404] Update isActive column in AS_GSS_EVALUATION 
-- *****************************************************************************************************************
-- This script is used to update the isActive column value to false wherever it is null in AS_GSS_EVALUATION table
-- *****************************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",236, "Source Selection 1.9", 4404, "Update isActive column in AS_GSS_EVALUATION ",3397,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE `AS_GSS_EVALUATION` SET `IS_ACTIVE` = 0 WHERE `IS_ACTIVE` IS NULL;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 236, 4404, 3397);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************************************************************************
-- [4426] Create table AS_GSS_DOCUMENT_DELETION_DETAILS
-- ***************************************************************************************************
-- This table stores the list of evaluation document ids that should be deleted on a particular date
-- ***************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",236, "Source Selection 1.9", 4426, "Create table AS_GSS_DOCUMENT_DELETION_DETAILS",3415,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE `AS_GSS_DELETED_DOCUMENT` (
  `DELETION_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `EVAL_DOCUMENT_ID` int(11) DEFAULT NULL,
  `DELETION_DATE` date DEFAULT NULL,
  `IS_DELETED` tinyint(1) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `DELETED_BY` varchar(255) DEFAULT NULL,
  `DELETED_DATETIME` datetime DEFAULT NULL
) AUTO_INCREMENT=1;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 236, 4426, 3415);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************************************************************
-- [4427] Add foreign key constraint on AS_GSS_DELETED_DOCUMENT
-- ***************************************************************************************
-- Add foreign key constraint on AS_GSS_DELETED_DOCUMENT from AS_GSS_EVALUATION_DOCUMENT
-- ***************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",236, "Source Selection 1.9", 4427, "Add foreign key constraint on AS_GSS_DELETED_DOCUMENT",3416,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_DELETED_DOCUMENT` ADD CONSTRAINT `asgssevaldocument_detail` FOREIGN KEY (`EVAL_DOCUMENT_ID`) REFERENCES `AS_GSS_EVALUATION_DOCUMENT` (`EVAL_DOCUMENT_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 236, 4427, 3416);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **************************************************
-- [4429] Add New Consensus Report Status
-- **************************************************
-- Add 'Deleted' status for Consensus Report Status
-- **************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",236, "Source Selection 1.9", 4429, "Add New Consensus Report Status",3417,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES (62, 'Deleted', NULL, 'Consensus Report Status', NULL, NULL, '5', '1', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 236, 4429, 3417);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **************************************
-- [4430] Add New Task Status
-- **************************************
-- Add 'Deleted' status for Task Status
-- **************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",236, "Source Selection 1.9", 4430, "Add New Task Status",3418,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_TMG_R_TASK_STATUS` (`TASK_STATUS_ID`, `STATUS_DISPLAY_NAME`, `ICON`, `COLOR`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES (8, 'txt_StatusDeleted', ' ', ' ', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 236, 4430, 3418);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;





-- **********************
-- Source Selection 2.0
-- **********************


-- **************************************************************************************************************************************
-- [4543] Add column IS_EVALUATOR_MASKED in AS_GSS_EVALUATION
-- **************************************************************************************************************************************
-- Adding a new column in AS_GSS_EVALUATION table to capture if the mask evaluators feature is turned on for that particular evaluation
-- **************************************************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",241, "Source Selection 2.0", 4543, "Add column IS_EVALUATOR_MASKED in AS_GSS_EVALUATION",3499,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION ADD COLUMN IS_EVALUATOR_MASKED TINYINT(1) DEFAULT NULL COMMENT 'Indicates whether or not evaluators are masked for the evaluation' AFTER IS_WEIGHTED_FACTORS_REQ;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 241, 4543, 3499);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************************************************************************************************************
-- [4544] Updating value for IS_EVALUATOR_MASKED in exiting entries
-- ****************************************************************************************************************************************
-- Updating the value of the IS_EVALUATOR_MASKED column in the AS_GSS_EVALUATION table to false for all the existing entries in the table
-- ****************************************************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",241, "Source Selection 2.0", 4544, "Updating value for IS_EVALUATOR_MASKED in exiting entries",3500,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_EVALUATION SET IS_EVALUATOR_MASKED = 0;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 241, 4544, 3500);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **********************************************
-- [4622] Create Table AS_GSS_MASK_EVAL_DETAILS
-- **********************************************
-- Create table AS_GSS_MASK_EVAL_DETAILS
-- **********************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",241, "Source Selection 2.0", 4622, "Create Table AS_GSS_MASK_EVAL_DETAILS",3557,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE `AS_GSS_MASK_EVAL_DETAILS`(
  `ALIAS_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `EVALUATION_ID` int(11) DEFAULT NULL,
  `USERNAME` varchar(255) DEFAULT NULL,
  `ALIAS_NAME` varchar(255) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `MODIFIED_BY` varchar(255) DEFAULT NULL,
  `MODIFIED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL
);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 241, 4622, 3557);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ********************************************************************************
-- [4625] Add constraint on EvaluationId and username in AS_GSS_MASK_EVAL_DETAILS
-- ********************************************************************************
-- Add constraint on EvaluationId and username in AS_GSS_MASK_EVAL_DETAILS table
-- ********************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",241, "Source Selection 2.0", 4625, "Add constraint on EvaluationId and username in AS_GSS_MASK_EVAL_DETAILS",3558,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_MASK_EVAL_DETAILS`
  ADD CONSTRAINT `asgssmask_evl_evaluationid` FOREIGN KEY (`EVALUATION_ID`) REFERENCES `AS_GSS_EVALUATION` (`EVALUATION_ID`);

ALTER TABLE `AS_GSS_MASK_EVAL_DETAILS`
  ADD CONSTRAINT `asgssmask_evl_username` FOREIGN KEY (`USERNAME`) REFERENCES `AS_GSS_USER` (`USERNAME`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 241, 4625, 3558);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************************************************
-- [4626] Add index on evaluationId and username in AS_GSS_MASK_EVAL_DETAILS
-- ***************************************************************************
-- Add index on evaluationId and username in AS_GSS_MASK_EVAL_DETAILS
-- ***************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",241, "Source Selection 2.0", 4626, "Add index on evaluationId and username in AS_GSS_MASK_EVAL_DETAILS",3559,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_MASK_EVAL_DETAILS
  ADD KEY asgssmask_evl_evaluationid (EVALUATION_ID);

ALTER TABLE AS_GSS_MASK_EVAL_DETAILS
  ADD KEY asgssmask_evl_username(USERNAME);



-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 241, 4626, 3559);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;





-- **********************
-- Source Selection 2.1
-- **********************


-- *********************************************************************
-- [4693] Add Column SOURCE_APPLICATION_ID in AS_GSS_EVALUATION_VENDOR
-- *********************************************************************
-- Add Column SOURCE_APPLICATION_ID in AS_GSS_EVALUATION_VENDOR
-- *********************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",251, "Source Selection 2.1", 4693, "Add Column SOURCE_APPLICATION_ID in AS_GSS_EVALUATION_VENDOR",3602,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVALUATION_VENDOR` ADD `SOURCE_APPLICATION_ID` INT NULL DEFAULT NULL;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 251, 4693, 3602);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *****************************************************************
-- [4694] Update Source Application Id in AS_GSS_EVALUATION_VENDOR
-- *****************************************************************
-- Update Source Application Id in AS_GSS_EVALUATION_VENDOR
-- *****************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",251, "Source Selection 2.1", 4694, "Update Source Application Id in AS_GSS_EVALUATION_VENDOR",3603,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE `AS_GSS_EVALUATION_VENDOR` SET SOURCE_APPLICATION_ID=59;


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 251, 4694, 3603);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ********************************************************
-- [4695] Insert ref data for Ref Type Source Application
-- ********************************************************
-- Insert ref data for Ref Type Source Application
-- ********************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",251, "Source Selection 2.1", 4695, "Insert ref data for Ref Type Source Application",3604,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES (63, 'VM', NULL, 'Source Application', NULL, NULL, '3', '1', 'appian.administrator',CURRENT_TIMESTAMP, 'appian.administrator',CURRENT_TIMESTAMP);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 251, 4695, 3604);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ******************************************************************************
-- [4697] Update Table AS_GSS_EVALUATION_VENDOR
-- ******************************************************************************
-- Script to alter the datatype of SUBMITTED_DATE column from Date to Date time
-- ******************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",251, "Source Selection 2.1", 4697, "Update Table AS_GSS_EVALUATION_VENDOR",3605,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION_VENDOR MODIFY COLUMN SUBMITTED_DATE datetime DEFAULT null;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 251, 4697, 3605);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *******************************************************************************
-- [4698] Update Table AS_GSS_EVALUATION_VENDOR
-- *******************************************************************************
-- This script will update the timestamp value of the SUBMITTED_DATE to 12:00 PM
-- *******************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",251, "Source Selection 2.1", 4698, "Update Table AS_GSS_EVALUATION_VENDOR",3606,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_EVALUATION_VENDOR SET SUBMITTED_DATE = CONCAT(DATE(SUBMITTED_DATE), ' 12:00:00')
WHERE SUBMITTED_DATE IS NOT NULL;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 251, 4698, 3606);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;





-- **********************
-- Source Selection 2.2
-- **********************


-- ********************************************************************
-- [4794] ADD TIN and FEIN columns
-- ********************************************************************
-- This script is to add TIN and FEIN column to AS_GSS_R_VENDOR table
-- ********************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",256, "Source Selection 2.2", 4794, "ADD TIN and FEIN columns",3684,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_R_VENDOR ADD COLUMN `FEIN` VARCHAR(255) NULL DEFAULT NULL AFTER `UNIQUE_ENTITY_ID`;
ALTER TABLE AS_GSS_R_VENDOR ADD COLUMN `TIN` VARCHAR(255) NULL DEFAULT NULL AFTER `UNIQUE_ENTITY_ID`;



-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 256, 4794, 3684);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ************************************************************************
-- [4797] ADD TIN and FEIN columns
-- ************************************************************************
-- This script is to add TIN and FEIN columns to AS_GSS_EVALUATION_VENDOR
-- ************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",256, "Source Selection 2.2", 4797, "ADD TIN and FEIN columns",3685,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION_VENDOR ADD COLUMN `FEIN` VARCHAR(255) NULL DEFAULT NULL AFTER `UNIQUE_ENTITY_ID`;
ALTER TABLE AS_GSS_EVALUATION_VENDOR ADD COLUMN `TIN` VARCHAR(255) NULL DEFAULT NULL AFTER `UNIQUE_ENTITY_ID`;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 256, 4797, 3685);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **********************************************************************************
-- [4801] Add Source id to Ref Vendor table
-- **********************************************************************************
-- This script will add a new column SOURCE_APPLICATION_ID to AS_GSS_R_VENDOR table
-- **********************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",256, "Source Selection 2.2", 4801, "Add Source id to Ref Vendor table",3691,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_R_VENDOR
  ADD COLUMN SOURCE_APPLICATION_ID INT(11) DEFAULT NULL comment
  'Indicates the source of Vendor' AFTER MODIFIED_DATETIME;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 256, 4801, 3691);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************************************************************
-- [4802] Add update required column to Evaluation Vendor table
-- ****************************************************************************************
-- This script will add a new column IS_UPDATE_REQUIRED to AS_GSS_EVALUATION_VENDOR table
-- ****************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",256, "Source Selection 2.2", 4802, "Add update required column to Evaluation Vendor table",3692,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION_VENDOR
  ADD COLUMN IS_UPDATE_REQUIRED TINYINT(1) DEFAULT NULL comment
  'Indicates if the vendor is updated at an external system' AFTER
  SOURCE_APPLICATION_ID;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 256, 4802, 3692);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************************************************************
-- [4803] Add external vendor id column to Evaluation Vendor table
-- ****************************************************************************************
-- This script will add a new column EXTERNAL_VENDOR_ID to AS_GSS_EVALUATION_VENDOR table
-- ****************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",256, "Source Selection 2.2", 4803, "Add external vendor id column to Evaluation Vendor table",3693,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION_VENDOR
  ADD COLUMN EXTERNAL_VENDOR_ID INT(11) DEFAULT NULL DEFAULT NULL comment
  'The identifier of the record in the external system' AFTER
  SOURCE_APPLICATION_ID;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 256, 4803, 3693);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *****************************************************************************************
-- [4804] Add document sub type column to Evaluation document table
-- *****************************************************************************************
-- This script will add a new column DOCUMENT_SUB_TYPE to AS_GSS_EVALUATION_DOCUMENT table
-- *****************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",256, "Source Selection 2.2", 4804, "Add document sub type column to Evaluation document table",3694,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION_DOCUMENT
  ADD COLUMN DOCUMENT_SUB_TYPE VARCHAR(255) DEFAULT NULL AFTER DOC_TYPE;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 256, 4804, 3694);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *******************************************************
-- [4805] Create Vendor Update table
-- *******************************************************
-- The script to create the AS_GSS_VENDOR_UPDATES table.
-- *******************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",256, "Source Selection 2.2", 4805, "Create Vendor Update table",3854,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE AS_GSS_VENDOR_UPDATES (
  UPDATE_ID INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  EXTERNAL_VENDOR_ID INT(11) DEFAULT NULL COMMENT 'The identifier of the external system',
  EVALUATION_ID INT(11) DEFAULT NULL,
  EVAL_VENDOR_ID INT(11) DEFAULT NULL,
  EVALUATION_NUMBER VARCHAR(25) DEFAULT NULL,
  LEGAL_NAME VARCHAR(255) DEFAULT NULL,
  UEI VARCHAR(255) DEFAULT NULL,
  CAGE VARCHAR(255) DEFAULT NULL,
  TIN VARCHAR(255) DEFAULT NULL,
  FEIN VARCHAR(255) DEFAULT NULL,
  PROPOSAL_ID INT(11) DEFAULT NULL,
  PROPOSAL_VERSION INT(11) DEFAULT NULL,
  PROPOSAL_ACTION_ID INT(11) DEFAULT NULL,
  PROPOSAL_ACTION_DATETIME DATETIME DEFAULT NULL,
  CREATED_BY varchar(255) DEFAULT NULL,
  CREATED_DATETIME datetime DEFAULT NULL,
  MODIFIED_BY varchar(255) DEFAULT NULL,
  MODIFIED_DATETIME datetime DEFAULT NULL,
  SOURCE_APPLICATION_ID INT(11) DEFAULT NULL COMMENT 'The source of the record',
  IS_ACTIVE TINYINT(1) DEFAULT NULL
) AUTO_INCREMENT=1 COMMENT 'The table to track changes to the Vendor information residing in External systems';


ALTER TABLE `AS_GSS_VENDOR_UPDATES`
  ADD CONSTRAINT `asgssevaluation_evaluationid` FOREIGN KEY (`EVALUATION_ID`) REFERENCES `AS_GSS_EVALUATION` (`EVALUATION_ID`),
  ADD CONSTRAINT `asgssevaluationvendor_vendorid` FOREIGN KEY (`EVAL_VENDOR_ID`) REFERENCES `AS_GSS_EVALUATION_VENDOR` (`VENDOR_ID`),
  ADD CONSTRAINT `asgssrdata_proposalactionid` FOREIGN KEY (`PROPOSAL_ACTION_ID`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`),
  ADD CONSTRAINT `asgssrdata_sourceapplicationid` FOREIGN KEY (`SOURCE_APPLICATION_ID`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`);
COMMIT;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 256, 4805, 3854);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *****************************************************************************************************
-- [4823] Update Existing Ref Vendor Entries
-- *****************************************************************************************************
-- This script will update all existing entries in the Ref vendor table with source application as GSS
-- *****************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",256, "Source Selection 2.2", 4823, "Update Existing Ref Vendor Entries",3712,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_R_VENDOR SET SOURCE_APPLICATION_ID = 59;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 256, 4823, 3712);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **********************************************************************************************
-- [4824] Update Evaluation vendors
-- **********************************************************************************************
-- This script will update all existing evaluation vendor entries with update required as false
-- **********************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",256, "Source Selection 2.2", 4824, "Update Evaluation vendors",3713,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_EVALUATION_VENDOR SET IS_UPDATE_REQUIRED = 0;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 256, 4824, 3713);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***********************************************************************************************
-- [4825] Ref data entries for Proposal action types
-- ***********************************************************************************************
-- The below scripts will add entries in the reference data table for the Proposal action types.
-- ***********************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",256, "Source Selection 2.2", 4825, "Ref data entries for Proposal action types",3714,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DATA`
(`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`)
VALUES
(64, 'New Submission', NULL, 'Proposal Action Types', NULL, NULL, '1', '1', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(65, 'Proposal Resubmission', NULL, 'Proposal Action Types', NULL, NULL, '2', '1', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(66, 'Withdrawal', NULL, 'Proposal Action Types', NULL, NULL, '3', '1', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 256, 4825, 3714);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ******************************************************************
-- [4849] Modify Evaluation Documents table
-- ******************************************************************
-- Add a new column Version to the AS_GSS_EVALUATION_DOCUMENT table
-- ******************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",256, "Source Selection 2.2", 4849, "Modify Evaluation Documents table",3734,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

--
-- Examples of column_definition:
--

-- VARCHAR(255) DEFAULT NULL -- text
-- INT(11) DEFAULT NULL -- integer
-- TINYINT(1) DEFAULT NULL -- boolean
-- DATETIME DEFAULT NULL -- datetime
-- DATE DEFAULT NULL -- date
-- DOUBLE DEFAULT NULL -- decimal

ALTER TABLE AS_GSS_EVALUATION_DOCUMENT ADD COLUMN VERSION INT(11) DEFAULT NULL AFTER DOCUMENT_TEMPLATE;


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 256, 4849, 3734);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *******************************************************************************************************************************************************************************
-- [4861] Update Documents Additional Data View
-- *******************************************************************************************************************************************************************************
-- This script will re-execute the structure of the view AS_GSS_V_EVLTN_DC_ADDTNAL_INFO to add additional columns which have been added to the AS_GSS_EVALUATION_DOCUMENT table.
-- *******************************************************************************************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",256, "Source Selection 2.2", 4861, "Update Documents Additional Data View",3744,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

DROP VIEW IF EXISTS AS_GSS_V_EVLTN_DC_ADDTNAL_INFO;
CREATE OR REPLACE VIEW AS_GSS_V_EVLTN_DC_ADDTNAL_INFO
AS
  SELECT D.*,
         C.CRITERIA_NAME,
         C.FACTOR_NUMBER,
         V.LEGAL_NAME,
         DT.REF_LABEL AS DOC_TYPE_LABEL
  FROM AS_GSS_EVALUATION_DOCUMENT D
         LEFT JOIN AS_GSS_CRITERIA C
                ON ( D.CRITERIA_ID = C.CRITERIA_ID )
         LEFT JOIN AS_GSS_EVALUATION_VENDOR V
                ON ( D.VENDOR_ID = V.VENDOR_ID )
         LEFT JOIN AS_GSS_R_DATA DT
                ON ( D.DOC_TYPE = DT.REF_DATA_ID );

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 256, 4861, 3744);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***********************************************************************************************************
-- [4976] Update Factor Mapping Entries
-- ***********************************************************************************************************
-- This script will deactivate the factor document mapping entries for factors which are in Temporary status
-- ***********************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",256, "Source Selection 2.2", 4976, "Update Factor Mapping Entries",3855,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_FCTR_DCUMENT_MAPPING SET IS_ACTIVE=0 WHERE FACTOR_ID IN (
	SELECT CRITERIA_ID FROM AS_GSS_CRITERIA WHERE CRITERIA_STATUS_ID=34
) AND IS_ACTIVE=1;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 256, 4976, 3855);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;





-- **********************
-- Source Selection 2.3
-- **********************


-- ***********************************************************************************
-- [4981] Add On The Spot Consensus column to Evaluation table
-- ***********************************************************************************
-- This script adds a new column IS_ON_SPOT_CONSENSUS to the AS_GSS_EVALUATION table
-- ***********************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",266, "Source Selection 2.3", 4981, "Add On The Spot Consensus column to Evaluation table",3860,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION ADD COLUMN IS_ON_SPOT_CONSENSUS TINYINT(1) DEFAULT NULL COMMENT 'Indicates whether or not consensus is on spot for the evaluation' AFTER IS_EVALUATOR_MASKED;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 266, 4981, 3860);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **************************************************************************************************************
-- [4982] Update table AS_GSS_EVALUATION existing evaluations
-- **************************************************************************************************************
-- This script updates the value for the new column IS_ON_SPOT_CONSENSUS as false for all existing evaluations.
-- **************************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",266, "Source Selection 2.3", 4982, "Update table AS_GSS_EVALUATION existing evaluations",3861,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_EVALUATION SET IS_ON_SPOT_CONSENSUS = 0;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 266, 4982, 3861);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;





-- **********************
-- Source Selection 2.4
-- **********************


-- **************************************************************************************************
-- [5034] Adding default entry flag for AS_GSS_CRITERIA table
-- **************************************************************************************************
-- This script adds a new column to denote if the entry is a default entry made of LPTA evaluations
-- **************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5034, "Adding default entry flag for AS_GSS_CRITERIA table",3909,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

--
-- Examples of column_definition:
--

-- VARCHAR(255) DEFAULT NULL -- text
-- INT(11) DEFAULT NULL -- integer
-- TINYINT(1) DEFAULT NULL -- boolean
-- DATETIME DEFAULT NULL -- datetime
-- DATE DEFAULT NULL -- date
-- DOUBLE DEFAULT NULL -- decimal

ALTER TABLE AS_GSS_CRITERIA ADD COLUMN IS_DEFAULT_ENTRY TINYINT(1) DEFAULT NULL COMMENT 'Indicates if this is a default entry' AFTER IS_ACTIVE;


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5034, 3909);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ************************************************************************************************
-- [5035] Updating existing AS_GSS_CRITERIA table entries
-- ************************************************************************************************
-- This script will update the value of the IS_DEFAULT_ENTRY column of the factor table to false.
-- ************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5035, "Updating existing AS_GSS_CRITERIA table entries",3910,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_CRITERIA SET IS_DEFAULT_ENTRY = 0;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5035, 3910);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **************************************************************************************************
-- [5036] Adding default entry flag for AS_GSS_EVALUATOR_TEAM table
-- **************************************************************************************************
-- This script adds a new column to denote if the entry is a default entry made of LPTA evaluations
-- **************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5036, "Adding default entry flag for AS_GSS_EVALUATOR_TEAM table",3911,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATOR_TEAM ADD COLUMN IS_DEFAULT_ENTRY TINYINT(1) DEFAULT NULL COMMENT 'Indicates if this is a default entry' AFTER IS_ACTIVE;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5036, 3911);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ************************************************************************************************
-- [5037] Updating existing AS_GSS_EVALUATOR_TEAM table entries
-- ************************************************************************************************
-- This script will update the value of the IS_DEFAULT_ENTRY column of the factor table to false.
-- ************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5037, "Updating existing AS_GSS_EVALUATOR_TEAM table entries",3912,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_EVALUATOR_TEAM SET IS_DEFAULT_ENTRY = 0;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5037, 3912);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ******************************************************************
-- [5038] Create new reference entry for new LPTA evaluation method
-- ******************************************************************
-- This script will add a new ref entry for LPTA evaluation method
-- ******************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5038, "Create new reference entry for new LPTA evaluation method",3913,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT IGNORE INTO AS_GSS_R_DATA (REF_DATA_ID, REF_LABEL, REF_DESCRIPTION, REF_TYPE, REF_ICON, REF_COLOR, SORT_ORDER, IS_ACTIVE, CREATED_BY, CREATED_DATETIME, MODIFIED_BY, MODIFIED_DATETIME) VALUES
(67, 'Least Price Technically Acceptable', null, 'Evaluation Method', null, null, 1, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5038, 3913);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *****************************************************************
-- [5039] Deprecate existing LPTA evaluation method entry
-- *****************************************************************
-- This script will deprecate the existing evaluation method entry
-- *****************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5039, "Deprecate existing LPTA evaluation method entry",3914,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_R_DATA SET REF_TYPE = 'Evaluation Method Deprecated',REF_DESCRIPTION ='This entry has been deprecated in GSS 2.4. The new entry id for LPTA Evaluation method is 67' WHERE REF_DATA_ID=4;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5039, 3914);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **************************************************************************************************
-- [5043] Adding default entry flag for AS_GSS_EVALUATION table
-- **************************************************************************************************
-- This script adds a new column to denote if the entry is a default entry made of LPTA evaluations
-- **************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5043, "Adding default entry flag for AS_GSS_EVALUATION table",3918,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION ADD COLUMN IS_DEFAULT_DATA_GENERATED TINYINT(1) DEFAULT NULL COMMENT 'Indicates if default data configuration for LPTA is completed' AFTER IS_ON_SPOT_CONSENSUS;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5043, 3918);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *************************************************************************************************************************************
-- [5044] Updating existing AS_GSS_EVALUATION table entries
-- *************************************************************************************************************************************
-- This script will update the value of the IS_DEFAULT_DATA_GENERATED column of the evaluation table to false for all existing entries
-- *************************************************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5044, "Updating existing AS_GSS_EVALUATION table entries",3919,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_EVALUATION SET IS_DEFAULT_DATA_GENERATED = 0;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5044, 3919);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ******************************************************************************************************************************
-- [5045] Update existing LPTA evaluations to new ref id for Evaluation method
-- ******************************************************************************************************************************
-- This script will update all existing LPTA evaluations which are in setup status to the new ref id of LPTA evaluation method.
-- ******************************************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5045, "Update existing LPTA evaluations to new ref id for Evaluation method",3920,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_EVALUATION SET EVALUATION_METHOD_ID = 67 WHERE EVALUATION_METHOD_ID = 4 AND EVALUATION_STATUS_ID=1;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5045, 3920);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *********************************************************************************************************************
-- [5047] Updating additional settings data of existing evaluations
-- *********************************************************************************************************************
-- This script updates the additional settings columns of the existing evaluations which are in Setup status to false.
-- *********************************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5047, "Updating additional settings data of existing evaluations",3922,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_EVALUATION SET IS_WEIGHTED_FACTORS_REQ = 0, IS_SIGNATURES_REQUIRED = 0, IS_EVALUATOR_MASKED = 0, IS_ON_SPOT_CONSENSUS=0 WHERE EVALUATION_METHOD_ID = 67 AND EVALUATION_STATUS_ID=1;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5047, 3922);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ************************************************************************************
-- [5051] Adding pricing related columns to the Evaluation vendor table
-- ************************************************************************************
-- This script adds the pricing related columns to the AS_GSS_EVALUATION_VENDOR table
-- ************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5051, "Adding pricing related columns to the Evaluation vendor table",3926,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION_VENDOR ADD COLUMN TOTAL_PRICE DOUBLE DEFAULT NULL AFTER EXPIRATION_DATE;
ALTER TABLE AS_GSS_EVALUATION_VENDOR ADD COLUMN DECISION_TYPE_ID INT(11) DEFAULT NULL AFTER TOTAL_PRICE;
ALTER TABLE AS_GSS_EVALUATION_VENDOR ADD COLUMN PRICING_NOTES VARCHAR(2000) DEFAULT NULL AFTER DECISION_TYPE_ID;
ALTER TABLE AS_GSS_EVALUATION_VENDOR ADD COLUMN DECISION_REASON VARCHAR(2000) DEFAULT NULL AFTER PRICING_NOTES;


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5051, 3926);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *******************************************************************************************
-- [5052] Adding constraint for Decision type in Evaluation vendor table
-- *******************************************************************************************
-- This script adds constraint on the Decision type column in AS_GSS_EVALUATION_VENDOR table
-- *******************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5052, "Adding constraint for Decision type in Evaluation vendor table",3927,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION_VENDOR ADD CONSTRAINT asgssrdata_decisiontypeid
  FOREIGN KEY (DECISION_TYPE_ID) REFERENCES AS_GSS_R_DATA (REF_DATA_ID);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5052, 3927);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************************************************
-- [5053] Create table AS_GSS_VENDOR_PRICE_BREAKUP
-- ****************************************************************************
-- This script creates the table to capture the pricing line items of vendors
-- ****************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5053, "Create table AS_GSS_VENDOR_PRICE_BREAKUP",3928,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE AS_GSS_VENDOR_PRICE_BREAKUP (
  ITEM_ID INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  EVAL_VENDOR_ID INT(11) DEFAULT NULL,
  ITEM_DESCRIPTION VARCHAR(100) DEFAULT NULL,
  UNIT_PRICE DOUBLE DEFAULT NULL,
  QUANTITY DOUBLE DEFAULT NULL,
  AMOUNT DOUBLE DEFAULT NULL,
  SORT_ORDER INT(11) DEFAULT NULL,
  IS_ACTIVE TINYINT(1) DEFAULT NULL,
  SOURCE_APPLICATION_ID INT(11) DEFAULT NULL COMMENT 'The source of the record',
  EXTRACTION_TYPE_ID INT(11) DEFAULT NULL COMMENT 'The type of extraction used to fetch the data',
  CREATED_BY varchar(255) DEFAULT NULL,
  CREATED_DATETIME datetime DEFAULT NULL,
  MODIFIED_BY varchar(255) DEFAULT NULL,
  MODIFIED_DATETIME datetime DEFAULT NULL
) AUTO_INCREMENT=1;

ALTER TABLE `AS_GSS_VENDOR_PRICE_BREAKUP`
  ADD CONSTRAINT `asgssevalvendor_vendorid` FOREIGN KEY (`EVAL_VENDOR_ID`) REFERENCES `AS_GSS_EVALUATION_VENDOR` (`VENDOR_ID`),
  ADD CONSTRAINT `asgssrdata_sourceappid` FOREIGN KEY (`SOURCE_APPLICATION_ID`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`),
  ADD CONSTRAINT `asgssrdata_extractiontypeid` FOREIGN KEY (`EXTRACTION_TYPE_ID`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`);
COMMIT;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5053, 3928);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***********************************************************************************************
-- [5054] Ref data entries for Vendor Pricing changes
-- ***********************************************************************************************
-- The below scripts will add entries in the reference data table for the vendor peicing changes
-- ***********************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5054, "Ref data entries for Vendor Pricing changes",3929,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT IGNORE INTO AS_GSS_R_DATA (REF_DATA_ID, REF_LABEL, REF_DESCRIPTION, REF_TYPE, REF_ICON, REF_COLOR, SORT_ORDER, IS_ACTIVE, CREATED_BY, CREATED_DATETIME, MODIFIED_BY, MODIFIED_DATETIME) VALUES
(68, 'Select', null, 'Vendor Decision', null, null, 1, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(69, 'Reject', null, 'Vendor Decision', null, null, 2, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(70, 'Not Reviewed', null, 'Vendor Decision', null, null, 3, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(71, 'AI Document Extraction', null, 'Pricing Extraction Type', null, null, 1, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(72, 'Manual Entry', null, 'Pricing Extraction Type', null, null, 2, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5054, 3929);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **********************************************************
-- [5055] Update evaluation method label in reference table
-- **********************************************************
-- This script will update the LPTA evaluation method label
-- **********************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5055, "Update evaluation method label in reference table",3930,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_R_DATA SET REF_LABEL = 'Lowest Price Technically Acceptable' WHERE REF_DATA_ID IN (4, 67);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5055, 3930);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *******************************************************************
-- [5057] Create table for Vendor price breakup audit
-- *******************************************************************
-- This script creates the table for the Vendor price breakup audit.
-- *******************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5057, "Create table for Vendor price breakup audit",3932,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE AS_GSS_A_R_EVL_VDR_PRC_BRKP (
  PRICE_BREAKUP_AUDIT_ID INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  VENDOR_AUDIT_ID INT(11) DEFAULT NULL,
  ITEM_ID INT(11) DEFAULT NULL,
  TIMESTAMP DATETIME DEFAULT NULL,
  USERNAME VARCHAR(255) DEFAULT NULL,
  AUDIT_ACTION_CODE VARCHAR(255) DEFAULT NULL
) AUTO_INCREMENT=1;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5057, 3932);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *************************************************************************
-- [5058] Create table for Vendor price breakup field audit
-- *************************************************************************
-- This script creates the table for the Vendor price breakup field audit.
-- *************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5058, "Create table for Vendor price breakup field audit",3933,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE AS_GSS_A_R_EVL_VDR_P_BK_FLD (
  PRICE_BREAKUP_AUDIT_FIELD_ID INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  PRICE_BREAKUP_AUDIT_ID INT(11) DEFAULT NULL,
  FIELD_NAME VARCHAR(255) DEFAULT NULL,
  OLD_VALUE VARCHAR(4000) DEFAULT NULL,
  NEW_VALUE VARCHAR(4000) DEFAULT NULL
) AUTO_INCREMENT=1;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5058, 3933);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ************************************************************************
-- [5059] Add constraints for the price breakup audit tables
-- ************************************************************************
-- This script adds constraints to the price breakup related audit tables
-- ************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5059, "Add constraints for the price breakup audit tables",3934,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_A_R_EVL_VDR_PRC_BRKP
  ADD CONSTRAINT asgssrvltnv_prcbrkpchng_nv FOREIGN KEY (VENDOR_AUDIT_ID) REFERENCES AS_GSS_A_R_EVLUATION_VENDOR (VENDOR_AUDIT_ID);

ALTER TABLE AS_GSS_A_R_EVL_VDR_P_BK_FLD
  ADD CONSTRAINT asgssrvltnv_smplfldchng_nv FOREIGN KEY (PRICE_BREAKUP_AUDIT_ID) REFERENCES AS_GSS_A_R_EVL_VDR_PRC_BRKP (PRICE_BREAKUP_AUDIT_ID);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5059, 3934);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***********************************************************************************************************
-- [5077] Add new task behavior, category and reference data for LPTA
-- ***********************************************************************************************************
-- This script adds a new task behavior, category and reference data for Complete LPTA Evaluation Task in DB
-- ***********************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5077, "Add new task behavior, category and reference data for LPTA",3942,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_TMG_R_TSK_BHVOR_TYPE` (`TASK_BEHAVIOR_TYPE_ID`, `BEHAVIOR_TYPE_CODE`, `BEHAVIOR_DISPLAY_NAME`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`, `BEHAVIOR_SUBTYPE_CODE`, `CONFIGURATION_LEVEL_CODE`, `ICON`, `COLOR`) VALUES (12, 'DATA_ENTRY', 'txt_BehaviorTypeCompleteLPTAEvaluation', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP, 'COMPLETE_LPTA_EVALUATION', 'SYSTEM', 'list-ol', '#2BAAD5');

INSERT INTO `AS_GSS_TMG_R_TASK_CATEGORY` (`TASK_CATEGORY_ID`, `CATEGORY_NAME`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`, `IS_ACTIVE`) VALUES (41, 'Complete LPTA Evaluation', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP, 0);

INSERT INTO `AS_GSS_TMG_R_TASK_REF` (`TASK_REF_ID`, `TASK_NAME`, `TASK_BEHAVIOR_TYPE_ID`, `TASK_CATEGORY_ID`, `DEFAULT_GROUP_ASSIGNEE`, `TASK_REF_DOC_UPLOAD_ID`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES (91, 'Complete LPTA Evaluation', 12, 41, NULL, NULL, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);



-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5077, 3942);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *************************************************************************
-- [5118] Ref data entries for Vendor Pricing changes
-- *************************************************************************
-- This script adds the reference entry for vendor decision - Under Review
-- *************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",272, "Source Selection 2.4", 5118, "Ref data entries for Vendor Pricing changes",3968,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT IGNORE INTO AS_GSS_R_DATA (REF_DATA_ID, REF_LABEL, REF_DESCRIPTION, REF_TYPE, REF_ICON, REF_COLOR, SORT_ORDER, IS_ACTIVE, CREATED_BY, CREATED_DATETIME, MODIFIED_BY, MODIFIED_DATETIME) VALUES
(73, 'Under Review', null, 'Vendor Decision', null, null, 4, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 272, 5118, 3968);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;





-- *********************************************************************************************************************************************************************************************
-- Award Management 2.4 / Clause Automation 3.3 / Contract Writing 2.6 / Management Suite 1.0 / ProcureSight v2.2 / Requirements Management 2.3 / Source Selection 2.5 / Vendor Management 2.4
-- *********************************************************************************************************************************************************************************************


-- *********************************************************************
-- [5236] Inserts in AS_GAM_R_BUSINESS_TYPE
-- *********************************************************************
-- Insert Ref data for Vendor Business Types in AS_GAM_R_BUSINESS_TYPE
-- *********************************************************************

DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GAM_RunFrameworkScript()
BEGIN
CALL AS_GAM_Initial_Execution("N",290, "Award Management 2.4 / Clause Automation 3.3 / Contract Writing 2.6 / Management Suite 1.0 / ProcureSight v2.2 / Requirements Management 2.3 / Source Selection 2.5 / Vendor Management 2.4", 5236, "Inserts in AS_GAM_R_BUSINESS_TYPE",4050,  @AS_GAM_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT IGNORE INTO AS_GAM_R_BUSINESS_TYPE(CODE, DESCRIPTION, IS_ACTIVE) VALUES
('1E','Indian Economic Enterprise','1'),
('1S','Indian Small Business Economic Enterprise','1'),
('JV','Service-Disabled Veteran-Owned Business Joint Venture','1'),
('JS','Small Business Joint Venture','1');

-- END SCRIPT CONTENT ---
 
CALL AS_GAM_Update_Execution(@AS_GAM_scriptExecuteId, 290, 5236, 4050);
END IF;
END $$
DELIMITER ;

CALL AS_GAM_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;


-- ****************************************************************
-- [5237] Updates in AS_GAM_R_BUSINESS_TYPE description
-- ****************************************************************
-- Update description of business types in AS_GAM_R_BUSINESS_TYPE
-- ****************************************************************

DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GAM_RunFrameworkScript()
BEGIN
CALL AS_GAM_Initial_Execution("N",290, "Award Management 2.4 / Clause Automation 3.3 / Contract Writing 2.6 / Management Suite 1.0 / ProcureSight v2.2 / Requirements Management 2.3 / Source Selection 2.5 / Vendor Management 2.4", 5237, "Updates in AS_GAM_R_BUSINESS_TYPE description",4051,  @AS_GAM_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = '1862 Land-Grant College' WHERE CODE = 'G6';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = '1890 Land-Grant College' WHERE CODE = 'G7';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = '1994 Land-Grant College' WHERE CODE = 'G8';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Alaska Native Corporation' WHERE CODE = '05';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Alaska Native-Serving Institution' WHERE CODE = 'G3';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Asian Pacific American Owned' WHERE CODE = 'FR';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Buyer and Seller' WHERE CODE = 'S6';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Community Development Corporation-Owned Firm' WHERE CODE = 'HK';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Corporate Entity (Not Tax-Exempt)' WHERE CODE = '2L';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Corporate Entity (Tax-Exempt)' WHERE CODE = '8H';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'DOT-Certified DBE' WHERE CODE = 'HQ';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Economically-Disadvantaged Women-Owned Small Business (EDWOSB) Joint Venture' WHERE CODE = '8E';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Federal Assistance Awards and IGT' WHERE CODE = 'Z4';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Federally-Funded Research and Development Center' WHERE CODE = 'QW';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'For-Profit Organization' WHERE CODE = '2X';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Foreign-Owned' WHERE CODE = '20';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Hispanic Servicing Institution' WHERE CODE = 'GW';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Economically-Disadvantaged Women-Owned Small Business (EDWOSB) Joint Venture' WHERE CODE = '8D';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Local Government-Owned' WHERE CODE = 'MG';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Minority-Owned Business' WHERE CODE = '23';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Native Hawaiian-Serving Institution' WHERE CODE = 'G5';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Native Hawaiian Organization Owned-Firm' WHERE CODE = '8U';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Individual or concern, other than one of the preceding' WHERE CODE = 'G9';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'SBA-Certified 8(a) Joint Venture' WHERE CODE = 'JT';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'SBA-Certified 8(a) Program Participant' WHERE CODE = 'A6';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'SBA-Certified HUBZone Firm' WHERE CODE = 'XX';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'SBA-Certified Small Disadvantaged Business' WHERE CODE = 'A4';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Self-Certified HUBZone Joint Venture' WHERE CODE = 'JX';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Self-Certified Small Disadvantaged Business' WHERE CODE = '27';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Service-Disabled Veteran-Owned Business' WHERE CODE = 'QF';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'State-Controlled Institution of Higher Learning' WHERE CODE = 'OH';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Subcontinent Asian (Asian Indian) American Owned' WHERE CODE = 'QZ';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Tribally-Owned Firm' WHERE CODE = '1B';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'U.S. Federal Government' WHERE CODE = '2R';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Veteran-Owned Business' WHERE CODE = 'A5';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Woman-Owned Business' WHERE CODE = 'A2';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Women-Owned Small Business' WHERE CODE = '8W';
UPDATE AS_GAM_R_BUSINESS_TYPE SET DESCRIPTION = 'Women-Owned Small (WOSB) Joint Venture eligible under the WOSB Program' WHERE CODE = '8C';

-- END SCRIPT CONTENT ---
 
CALL AS_GAM_Update_Execution(@AS_GAM_scriptExecuteId, 290, 5237, 4051);
END IF;
END $$
DELIMITER ;

CALL AS_GAM_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GAM_RunFrameworkScript;





-- **********************
-- Source Selection 2.5
-- **********************


-- ***************************************************************************************
-- [5145] Add columns to AS_GSS_R_VENDOR
-- ***************************************************************************************
-- This scripts adds the additional columns related to migration in the ref vendor table
-- ***************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",283, "Source Selection 2.5", 5145, "Add columns to AS_GSS_R_VENDOR",3986,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_R_VENDOR ADD COLUMN RECONCILIATION_STATUS_ID INT(11) DEFAULT NULL AFTER IS_ACTIVE;
ALTER TABLE AS_GSS_R_VENDOR ADD COLUMN GSM_VENDOR_REF_ID INT(11) DEFAULT NULL AFTER IS_ACTIVE;


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 283, 5145, 3986);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *****************************************************************************
-- [5146] Add columns to AS_GSS_EVALUATION_VENDOR
-- *****************************************************************************
-- This script adds the GSM identifier column to the evaluation vendor entries
-- *****************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",283, "Source Selection 2.5", 5146, "Add columns to AS_GSS_EVALUATION_VENDOR",3987,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION_VENDOR ADD COLUMN GSM_VENDOR_REF_ID INT(11) DEFAULT NULL AFTER IS_UPDATE_REQUIRED;


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 283, 5146, 3987);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ************************************************************************************
-- [5147] Create table AS_GSS_DRM_RECN_DETAILS
-- ************************************************************************************
-- The script to create table to hold data related to the data reconciliation process
-- ************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",283, "Source Selection 2.5", 5147, "Create table AS_GSS_DRM_RECN_DETAILS",3988,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE AS_GSS_DRM_RECN_DETAILS (
  RECONCILIATION_ID INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  GSM_RECONCILIATION_ID INT(11) DEFAULT NULL,
  STATUS VARCHAR(255) DEFAULT NULL,
  MESSAGE VARCHAR(255) DEFAULT NULL,
  TOTAL_ITERATION_COUNT INT(11) NOT NULL,
  CURRENT_ITERATION_COUNT INT(11) NOT NULL,
  CREATED_COUNT INT(11) NOT NULL,
  SKIPPED_COUNT INT(11) NOT NULL,
  PARENT_RECON_ID INT(11) DEFAULT NULL,
  STARTED_BY VARCHAR(255) DEFAULT NULL,
  STARTED_ON DATETIME DEFAULT NULL,
  COMPLETED_ON DATETIME DEFAULT NULL,
  IS_ACTIVE TINYINT(1) DEFAULT NULL
) AUTO_INCREMENT=1 COMMENT 'The table to hold information related to Data Reconciliation requests to GSM';

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 283, 5147, 3988);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ********************************************************************************************************
-- [5149] Update migration status in AS_GSS_R_VENDOR
-- ********************************************************************************************************
-- This script will update the migration status of all vendors in ref vendor table to Not Started status.
-- ********************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",283, "Source Selection 2.5", 5149, "Update migration status in AS_GSS_R_VENDOR",3989,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_R_VENDOR SET RECONCILIATION_STATUS_ID =1;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 283, 5149, 3989);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *******************************************************************************
-- [5151] Create table AS_GSS_DRM_MIGR_DETAILS
-- *******************************************************************************
-- The script to create table to hold data related to the data migration process
-- *******************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",283, "Source Selection 2.5", 5151, "Create table AS_GSS_DRM_MIGR_DETAILS",3991,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE AS_GSS_DRM_MIGR_DETAILS (
  MIGRATION_ID INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  STATUS_ID INT(11) NOT NULL,
  STARTED_BY VARCHAR(255) DEFAULT NULL,
  STARTED_ON DATETIME DEFAULT NULL,
  COMPLETED_ON DATETIME DEFAULT NULL,
  IS_ACTIVE TINYINT(1) DEFAULT NULL
) AUTO_INCREMENT=1 COMMENT 'The table to hold information related to Data Migration requests';

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 283, 5151, 3991);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************************
-- [5221] Add Reference Data For Vendor Address Type
-- ***************************************************
-- Add Reference Data For Vendor Address Type
-- ***************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",283, "Source Selection 2.5", 5221, "Add Reference Data For Vendor Address Type",4038,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT IGNORE INTO AS_GSS_R_DATA (REF_DATA_ID, REF_LABEL, REF_DESCRIPTION, REF_TYPE, REF_ICON, REF_COLOR, SORT_ORDER, IS_ACTIVE, CREATED_BY, CREATED_DATETIME, MODIFIED_BY, MODIFIED_DATETIME) VALUES
(74, 'Physical Address', null, 'Vendor Address Type', null, null, 1, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(75, 'Mailing Address', null, 'Vendor Address Type', null, null, 2, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 283, 5221, 4038);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ********************************************
-- [5222] Add Evaluation Vendor Address Table
-- ********************************************
-- Add Evaluation Vendor Address Table
-- ********************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",283, "Source Selection 2.5", 5222, "Add Evaluation Vendor Address Table",4039,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE `AS_GSS_EVAL_VENDOR_ADDRESS` (
  `VENDOR_ADDRESS_ID` int(11) NOT NULL AUTO_INCREMENT,
  `EVALUATION_VENDOR_ID` int(11) DEFAULT NULL,
  `ADDRESS_TYPE` int(11) DEFAULT NULL,
  `VENDOR_ADDRESS_LINE1` varchar(255) DEFAULT NULL,
  `VENDOR_ADDRESS_LINE2` varchar(255) DEFAULT NULL,
  `VENDOR_CITY` varchar(255) DEFAULT NULL,
  `VENDOR_STATE` int(11) DEFAULT NULL,
  `VENDOR_COUNTRY` int(11) DEFAULT NULL,
  `VENDOR_ZIP_CODE` varchar(255) DEFAULT NULL,
  `VENDOR_ZIP_CODE_EXT` varchar(255) DEFAULT NULL,
  `VENDOR_FOREIGN_POSTAL_CODE` varchar(255) DEFAULT NULL,
  `CREATED_BY` varchar(255) DEFAULT NULL,
  `CREATED_DATETIME` datetime DEFAULT NULL,
  `IS_ACTIVE` tinyint(1) DEFAULT NULL,
   PRIMARY KEY (`VENDOR_ADDRESS_ID`)
);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 283, 5222, 4039);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ************************************************
-- [5238] Add index to AS_GSS_EVAL_VENDOR_ADDRESS
-- ************************************************
-- Add index to AS_GSS_EVAL_VENDOR_ADDRESS
-- ************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",283, "Source Selection 2.5", 5238, "Add index to AS_GSS_EVAL_VENDOR_ADDRESS",4052,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVAL_VENDOR_ADDRESS`
  ADD KEY `asgssevlvndrad_vendrcntry` (`VENDOR_COUNTRY`),
  ADD KEY `asgssevlvndrad_vendrstte` (`VENDOR_STATE`),
  ADD KEY `asgssevlvndrad_addressType` (`ADDRESS_TYPE`),
  ADD KEY `asgssevlvndrad_evalvendr` (`EVALUATION_VENDOR_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 283, 5238, 4052);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *****************************************************
-- [5240] Add constraint to AS_GSS_EVAL_VENDOR_ADDRESS
-- *****************************************************
-- Add constraint to AS_GSS_EVAL_VENDOR_ADDRESS
-- *****************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",283, "Source Selection 2.5", 5240, "Add constraint to AS_GSS_EVAL_VENDOR_ADDRESS",4053,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVAL_VENDOR_ADDRESS`
  ADD CONSTRAINT `asgssevlvndrad_vendrcntry` FOREIGN KEY (`VENDOR_COUNTRY`) REFERENCES `AS_GAM_R_COUNTRY` (`COUNTRY_ID`),
  ADD CONSTRAINT `asgssevlvndrad_vendrstte` FOREIGN KEY (`VENDOR_STATE`) REFERENCES `AS_GAM_R_STATE` (`STATE_ID`),
  ADD CONSTRAINT `asgssevlvndrad_addressType` FOREIGN KEY (`ADDRESS_TYPE`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`),
  ADD CONSTRAINT `asgssevlvndrad_evalvendr` FOREIGN KEY (`EVALUATION_VENDOR_ID`) REFERENCES `AS_GSS_EVALUATION_VENDOR` (`VENDOR_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 283, 5240, 4053);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ********************************************
-- [5268] Add VIN to AS_GSS_EVALUATION_VENDOR
-- ********************************************
-- Add VIN to AS_GSS_EVALUATION_VENDOR
-- ********************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",283, "Source Selection 2.5", 5268, "Add VIN to AS_GSS_EVALUATION_VENDOR",4078,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION_VENDOR ADD COLUMN `VIN` VARCHAR(255) NULL DEFAULT NULL AFTER `FEIN`;


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 283, 5268, 4078);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ******************************************************************************************
-- [5273] Copy Physical Address From AS_GSS_EVALUATION_VENDOR to AS_GSS_EVAL_VENDOR_ADDRESS
-- ******************************************************************************************
-- Copy Physical Address From AS_GSS_EVALUATION_VENDOR to AS_GSS_EVAL_VENDOR_ADDRESS
-- ******************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",283, "Source Selection 2.5", 5273, "Copy Physical Address From AS_GSS_EVALUATION_VENDOR to AS_GSS_EVAL_VENDOR_ADDRESS",4081,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_EVAL_VENDOR_ADDRESS` (`EVALUATION_VENDOR_ID`,`ADDRESS_TYPE`,`VENDOR_ADDRESS_LINE1`,`VENDOR_ADDRESS_LINE2`,`VENDOR_CITY`,`VENDOR_STATE`,`VENDOR_COUNTRY`,`VENDOR_ZIP_CODE`,`VENDOR_ZIP_CODE_EXT`,`VENDOR_FOREIGN_POSTAL_CODE`,`CREATED_BY`,`CREATED_DATETIME`,`IS_ACTIVE`)
SELECT
    `AS_GSS_EVALUATION_VENDOR`.`VENDOR_ID`,
     74,
    `AS_GSS_EVALUATION_VENDOR`.`VENDOR_ADDRESS_LINE1`,
    `AS_GSS_EVALUATION_VENDOR`.`VENDOR_ADDRESS_LINE2`,
    `AS_GSS_EVALUATION_VENDOR`.`VENDOR_CITY`,
    `AS_GSS_EVALUATION_VENDOR`.`VENDOR_STATE`,
    `AS_GSS_EVALUATION_VENDOR`.`VENDOR_COUNTRY`,
    `AS_GSS_EVALUATION_VENDOR`.`VENDOR_ZIP_CODE`,
    `AS_GSS_EVALUATION_VENDOR`.`VENDOR_ZIP_CODE_EXT`,
    `AS_GSS_EVALUATION_VENDOR`.`VENDOR_FOREIGN_POSTAL_CODE`,
    'appian.administrator',
    CURRENT_TIMESTAMP,
    1
FROM
    `AS_GSS_EVALUATION_VENDOR`;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 283, 5273, 4081);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *****************************************************************************************
-- [5274] Copy Mailing Address From AS_GSS_EVALUATION_VENDOR to AS_GSS_EVAL_VENDOR_ADDRESS
-- *****************************************************************************************
-- Copy Mailing Address From AS_GSS_EVALUATION_VENDOR to AS_GSS_EVAL_VENDOR_ADDRESS
-- *****************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",283, "Source Selection 2.5", 5274, "Copy Mailing Address From AS_GSS_EVALUATION_VENDOR to AS_GSS_EVAL_VENDOR_ADDRESS",4082,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_EVAL_VENDOR_ADDRESS` (`EVALUATION_VENDOR_ID`,`ADDRESS_TYPE`,`VENDOR_ADDRESS_LINE1`,`VENDOR_ADDRESS_LINE2`,`VENDOR_CITY`,`VENDOR_STATE`,`VENDOR_COUNTRY`,`VENDOR_ZIP_CODE`,`VENDOR_ZIP_CODE_EXT`,`VENDOR_FOREIGN_POSTAL_CODE`,`CREATED_BY`,`CREATED_DATETIME`,`IS_ACTIVE`)
SELECT
    `AS_GSS_EVALUATION_VENDOR`.`VENDOR_ID`,
     75,
    `AS_GSS_EVALUATION_VENDOR`.`VENDOR_ADDRESS_LINE1`,
    `AS_GSS_EVALUATION_VENDOR`.`VENDOR_ADDRESS_LINE2`,
    `AS_GSS_EVALUATION_VENDOR`.`VENDOR_CITY`,
    `AS_GSS_EVALUATION_VENDOR`.`VENDOR_STATE`,
    `AS_GSS_EVALUATION_VENDOR`.`VENDOR_COUNTRY`,
    `AS_GSS_EVALUATION_VENDOR`.`VENDOR_ZIP_CODE`,
    `AS_GSS_EVALUATION_VENDOR`.`VENDOR_ZIP_CODE_EXT`,
    `AS_GSS_EVALUATION_VENDOR`.`VENDOR_FOREIGN_POSTAL_CODE`,
    'appian.administrator',
    CURRENT_TIMESTAMP,
    1
FROM
    `AS_GSS_EVALUATION_VENDOR`;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 283, 5274, 4082);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;





-- **********************
-- Source Selection 2.6
-- **********************


-- ************************************************************************************************
-- [5279] Add USED_APPIAN_AI column to AS_GSS_CNSNS_AI_SUGGESTION and AS_GSS_CNSNS_RESP_AI_SUMMRY
-- ************************************************************************************************
-- Add USED_APPIAN_AI column to AS_GSS_CNSNS_AI_SUGGESTION and AS_GSS_CNSNS_RESP_AI_SUMMRY
-- ************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",296, "Source Selection 2.6", 5279, "Add USED_APPIAN_AI column to AS_GSS_CNSNS_AI_SUGGESTION and AS_GSS_CNSNS_RESP_AI_SUMMRY",4087,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_CNSNS_AI_SUGGESTION ADD COLUMN USED_APPIAN_AI TINYINT(1) DEFAULT NULL COMMENT 'Indicates if Appian AI Skill was used';

ALTER TABLE AS_GSS_CNSNS_RESP_AI_SUMMRY ADD COLUMN USED_APPIAN_AI TINYINT(1) DEFAULT NULL COMMENT 'Indicates if Appian AI Skill was used';



-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 296, 5279, 4087);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **************************************************************
-- [5281] Insert Source Application Ref Type into AS_GSS_R_Data
-- **************************************************************
-- Insert Source Application Ref Type into AS_GSS_R_Data
-- **************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",296, "Source Selection 2.6", 5281, "Insert Source Application Ref Type into AS_GSS_R_Data",4088,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES (76, 'AM', NULL, 'Source Application', NULL, NULL, '4', '1', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 296, 5281, 4088);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *************************************************************************************************************
-- [5307] Set USED_APPIAN_AI as false for existing data
-- *************************************************************************************************************
-- Set USED_APPIAN_AI as false for existing data in AS_GSS_CNSNS_RESP_AI_SUMMRY and AS_GSS_CNSNS_AI_SUGGESTION
-- *************************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",296, "Source Selection 2.6", 5307, "Set USED_APPIAN_AI as false for existing data",4108,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_CNSNS_RESP_AI_SUMMRY SET USED_APPIAN_AI = 0 WHERE USED_APPIAN_AI IS NULL;

UPDATE AS_GSS_CNSNS_AI_SUGGESTION SET USED_APPIAN_AI = 0 WHERE USED_APPIAN_AI IS NULL;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 296, 5307, 4108);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **********************************************************************************************************************************************
-- [5326] Modify column PROMPT in AS_GSS_CNSNS_AI_SUGGESTION Table
-- **********************************************************************************************************************************************
-- Modify column PROMPT in AS_GSS_CNSNS_AI_SUGGESTION Table from text to long text in mariadb.Oracle does not require any change as it in clob.
-- **********************************************************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",296, "Source Selection 2.6", 5326, "Modify column PROMPT in AS_GSS_CNSNS_AI_SUGGESTION Table",4126,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_CNSNS_AI_SUGGESTION` MODIFY COLUMN `PROMPT`LONGTEXT;


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 296, 5326, 4126);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;





-- **********************
-- Source Selection 2.7
-- **********************


-- **********************************************************
-- [5403] Insert IDV Award Type Ref Type into AS_GSS_R_Data
-- **********************************************************
-- Insert IDV Award Type Ref Type into AS_GSS_R_Data
-- **********************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",308, "Source Selection 2.7", 5403, "Insert IDV Award Type Ref Type into AS_GSS_R_Data",4267,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT IGNORE INTO AS_GSS_R_DATA (REF_DATA_ID, REF_LABEL, REF_DESCRIPTION, REF_TYPE, REF_ICON, REF_COLOR, SORT_ORDER, IS_ACTIVE, CREATED_BY, CREATED_DATETIME, MODIFIED_BY, MODIFIED_DATETIME) VALUES
(77, 'Single Award', null,'IDV Award Type', null, null, 1, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(78, 'Multiple Award', null, 'IDV Award Type', null, null, 2, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 308, 5403, 4267);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *******************************************************
-- [5404] Add IDV Award Type column to AS_GSS_EVALUATION
-- *******************************************************
-- Add IDV Award Type column to AS_GSS_EVALUATION
-- *******************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",308, "Source Selection 2.7", 5404, "Add IDV Award Type column to AS_GSS_EVALUATION",4268,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION ADD COLUMN IDV_AWARD_TYPE_ID INT(11) DEFAULT NULL;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 308, 5404, 4268);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************************************
-- [5405] Set IDV_AWARD_TYPE_ID as Single Award for existing data
-- ****************************************************************
-- Set IDV_AWARD_TYPE_ID as Single Award for existing data
-- ****************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",308, "Source Selection 2.7", 5405, "Set IDV_AWARD_TYPE_ID as Single Award for existing data",4269,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_EVALUATION SET IDV_AWARD_TYPE_ID = 77 WHERE IDV_AWARD_TYPE_ID IS NULL;


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 308, 5405, 4269);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *********************************************************************
-- [5406] Add constraint to idv award type column in AS_GSS_EVALUATION
-- *********************************************************************
-- Add constraint to idv award type column in AS_GSS_EVALUATION
-- *********************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",308, "Source Selection 2.7", 5406, "Add constraint to idv award type column in AS_GSS_EVALUATION",4270,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVALUATION`
  ADD CONSTRAINT `asgssevalatin_idvawardtype` FOREIGN KEY (`IDV_AWARD_TYPE_ID`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 308, 5406, 4270);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ************************************************************
-- [5407] Add index to Idv Award type Id in AS_GSS_EVALUATION
-- ************************************************************
-- Add index to Idv Award type Id in AS_GSS_EVALUATION
-- ************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",308, "Source Selection 2.7", 5407, "Add index to Idv Award type Id in AS_GSS_EVALUATION",4271,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVALUATION`
  ADD KEY `asgssevalatin_idvawardtype` (`IDV_AWARD_TYPE_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 308, 5407, 4271);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **************************************************************************
-- [5429] Insert new evaluation status Awardees Selected into AS_GSS_R_Data
-- **************************************************************************
-- Insert new evaluation status Awardees Selected into AS_GSS_R_Data
-- **************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",308, "Source Selection 2.7", 5429, "Insert new evaluation status Awardees Selected into AS_GSS_R_Data",4309,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT IGNORE INTO AS_GSS_R_DATA (REF_DATA_ID, REF_LABEL, REF_DESCRIPTION, REF_TYPE, REF_ICON, REF_COLOR, SORT_ORDER, IS_ACTIVE, CREATED_BY, CREATED_DATETIME, MODIFIED_BY, MODIFIED_DATETIME) VALUES(79, 'Awardees Selected', NULL, 'Evaluation Status', 'award', '#757575', '3', '1', 'appian.administrator',CURRENT_TIMESTAMP, 'appian.administrator',CURRENT_TIMESTAMP );

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 308, 5429, 4309);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **************************************************************************
-- [5430] Update Sort order for Complete Evaluation Status In AS_GSS_R_Data
-- **************************************************************************
-- Update Sort order for Complete Evaluation Status In AS_GSS_R_Data
-- **************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",308, "Source Selection 2.7", 5430, "Update Sort order for Complete Evaluation Status In AS_GSS_R_Data",4310,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_R_DATA SET SORT_ORDER= 4 WHERE REF_DATA_ID = 3;


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 308, 5430, 4310);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;





-- **********************
-- Source Selection 2.8
-- **********************


-- **************************************
-- [5541] Insert Award Instrument Types
-- **************************************
-- Reference data for instrument type
-- **************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",315, "Source Selection 2.8", 5541, "Insert Award Instrument Types",4424,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`,`REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES
(80, 'H - Agreement including Basic and Loan (excluding BPA, BOA, and Lease)',NULL, 'Award Instrument Type', NULL, NULL, 12, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(81, 'G - Basic Ordering Agreement (BOA)',NULL, 'Award Instrument Type', NULL, NULL, 11, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(82, 'A - Blanket Purchase Agreement (BPA)',NULL, 'Award Instrument Type', NULL, NULL, 1, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(83, 'F - BPA Call',NULL, 'Award Instrument Type', NULL, NULL, 8, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(84, 'A - BPA under Federal Supply Schedule (FSS)',NULL, 'Award Instrument Type', NULL, NULL, 2, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(85, 'C - Contract (Definitive)',NULL, 'Award Instrument Type', NULL, NULL, 3, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(86, 'F - Delivery Order (DO)',NULL, 'Award Instrument Type', NULL, NULL, 9, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(87, 'D - Government Wide Acquisition Contract (GWAC)',NULL, 'Award Instrument Type', NULL, NULL, 4, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(88, 'Y - Imprest Fund',NULL, 'Award Instrument Type', NULL, NULL, 15, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(89, 'D - Indefinite Delivery Definite Quantity (IDDQ)',NULL, 'Award Instrument Type', NULL, NULL, 5, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(90, 'D - Indefinite Delivery Indefinite Quantity (IDIQ)',NULL, 'Award Instrument Type', NULL, NULL, 6, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(91, 'L - Lease Agreement',NULL, 'Award Instrument Type', NULL, NULL, 13, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(92, 'P - Purchase Order (PO)',NULL, 'Award Instrument Type', NULL, NULL, 14, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(93, 'D - Requirements',NULL, 'Award Instrument Type', NULL, NULL, 7, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
(94, 'F - Task Order (TO)',NULL, 'Award Instrument Type', NULL, NULL, 10, 1, 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 315, 5541, 4424);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***********************************************************************************
-- [5542] Add Instrument Type Column
-- ***********************************************************************************
-- Add a new column in the AS_GSS_Evaluation table to hold the Instrument type value
-- ***********************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",315, "Source Selection 2.8", 5542, "Add Instrument Type Column",4418,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_EVALUATION ADD COLUMN INSTRUMENT_TYPE_ID INT(11) DEFAULT NULL;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 315, 5542, 4418);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***************************************************************
-- [5543] Add constraint to Instrument type column
-- ***************************************************************
-- Add constraint to INSTRUMENT_TYPE column in AS_GSS_EVALUATION
-- ***************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",315, "Source Selection 2.8", 5543, "Add constraint to Instrument type column",4419,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVALUATION`
  ADD CONSTRAINT `asgssevalatin_instrumenttype` FOREIGN KEY (`INSTRUMENT_TYPE_ID`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 315, 5543, 4419);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *******************************************************
-- [5544] Add index to Idv INSTRUMENT_TYPE
-- *******************************************************
-- Add index to Idv INSTRUMENT_TYPE in AS_GSS_EVALUATION
-- *******************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",315, "Source Selection 2.8", 5544, "Add index to Idv INSTRUMENT_TYPE",4420,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_EVALUATION` ADD KEY `asgssevalatin_instrumenttype` (`INSTRUMENT_TYPE_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 315, 5544, 4420);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ************************************************************************************************************
-- [5545] Backfill Script
-- ************************************************************************************************************
-- backfill scripts to set the value of the existing evaluations with Instrument Type as "P: Purchase Orders"
-- ************************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",315, "Source Selection 2.8", 5545, "Backfill Script",4421,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE `AS_GSS_EVALUATION` SET `INSTRUMENT_TYPE_ID` = '92' WHERE `AS_GSS_EVALUATION`.`IS_ACTIVE` = 1 AND `AS_GSS_EVALUATION`.`IDV_AWARD_TYPE_ID` = 77;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 315, 5545, 4421);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *********************************************************************************
-- [5580] Update Sort Order for Award Types
-- *********************************************************************************
-- The scripts to update the sort order values for the Award Type ref data entries
-- *********************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",315, "Source Selection 2.8", 5580, "Update Sort Order for Award Types",4446,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE AS_GSS_R_DATA SET SORT_ORDER = 1 WHERE REF_DATA_ID = 78;
UPDATE AS_GSS_R_DATA SET SORT_ORDER = 2 WHERE REF_DATA_ID = 77;

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 315, 5580, 4446);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **********************************************
-- [5581] Create new table AS_GSS_DOCUMENT_CHAT
-- **********************************************
-- Create new table AS_GSS_DOCUMENT_CHAT
-- **********************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",315, "Source Selection 2.8", 5581, "Create new table AS_GSS_DOCUMENT_CHAT",4447,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE `AS_GSS_DOCUMENT_CHAT` (
  `DOC_CHAT_ID` INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `DOCUMENT_KEY` VARCHAR(1000) NOT NULL,
  `APPIAN_DOC_ID` INT(11) DEFAULT NULL,
  `RELATED_DOCUMENT_ID` INT(11) NOT NULL,
  `SUMMARY` VARCHAR(2000) DEFAULT NULL,
  `CREATED_BY` VARCHAR(255) DEFAULT NULL,
  `CREATED_DATETIME` DATETIME DEFAULT NULL
) AUTO_INCREMENT=1 COMMENT 'Contains entries for GSS Documents Chat and Summary feature';

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 315, 5581, 4447);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ******************************************************
-- [5582] Adding Foriegn key AS_GSS_DOCUMENT_CHAT
-- ******************************************************
-- AS_GSS_DOCUMENT_CHAT with AS_GSS_EVALUATION_DOCUMENT
-- ******************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",315, "Source Selection 2.8", 5582, "Adding Foriegn key AS_GSS_DOCUMENT_CHAT",4448,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_DOCUMENT_CHAT` ADD CONSTRAINT `asgssdocchat_relateddocid`
  FOREIGN KEY (`RELATED_DOCUMENT_ID`) REFERENCES AS_GSS_EVALUATION_DOCUMENT (EVAL_DOCUMENT_ID);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 315, 5582, 4448);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;





-- **********************
-- Source Selection 2.9
-- **********************


-- ******************************************************************************
-- [5657] Create AI Request Details table
-- ******************************************************************************
-- This table holds the details of the AI requests initiated in the application
-- ******************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",323, "Source Selection 2.9", 5657, "Create AI Request Details table",4536,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE IF NOT EXISTS `AS_GSS_AI_REQUEST_DETAILS` (
`REQUEST_ID` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
`EVALUATION_ID` INT(11) DEFAULT NULL,
`REQUEST_TYPE` INT(11) DEFAULT NULL,
`STATUS` INT(11) DEFAULT NULL,
`IS_ACTIVE` TINYINT(1) DEFAULT NULL,
`CREATED_BY` VARCHAR(255) DEFAULT NULL,
`CREATED_ON` DATETIME DEFAULT NULL,
`MODIFIED_BY` VARCHAR(255) DEFAULT NULL,
`MODIFIED_ON` DATETIME DEFAULT NULL) AUTO_INCREMENT=1 COMMENT 'Holds the AI requests initiated in the application';

ALTER TABLE `AS_GSS_AI_REQUEST_DETAILS`
  ADD CONSTRAINT `asgssairqstdtls_eval` FOREIGN KEY (`EVALUATION_ID`) REFERENCES `AS_GSS_EVALUATION` (`EVALUATION_ID`),
  ADD CONSTRAINT `asgssairqstdtls_rqsttype` FOREIGN KEY (`REQUEST_TYPE`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`),
  ADD CONSTRAINT `asgssairqstdtls_stats` FOREIGN KEY (`STATUS`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`);


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 323, 5657, 4536);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ************************************************************
-- [5658] Create AI Action Details table
-- ************************************************************
-- This table holds the AI action information for evaluations
-- ************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",323, "Source Selection 2.9", 5658, "Create AI Action Details table",4557,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE IF NOT EXISTS `AS_GSS_AI_ACTION_DETAILS` (
`ACTION_ID` INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
`REQUEST_ID` INT(11) DEFAULT NULL,
`VENDOR_ID` INT(11) DEFAULT NULL,
`CRITERIA_ID` INT(11) DEFAULT NULL,
`DOCUMENT_ID` INT(11) DEFAULT NULL,
`STATUS_ID` INT(11) DEFAULT NULL,
`ERROR_MESSAGE` VARCHAR(2000) DEFAULT NULL,
`IS_ACTIVE` TINYINT(1) DEFAULT NULL,
`CREATED_BY` VARCHAR(255) DEFAULT NULL,
`CREATED_ON` DATETIME DEFAULT NULL,
`MODIFIED_BY` VARCHAR(255) DEFAULT NULL,
`MODIFIED_ON` DATETIME DEFAULT NULL) AUTO_INCREMENT=1 COMMENT 'Holds the AI action information for evaluation';

ALTER TABLE `AS_GSS_AI_ACTION_DETAILS`
  ADD CONSTRAINT `asgssactndtls_airqsts` FOREIGN KEY (`REQUEST_ID`) REFERENCES `AS_GSS_AI_REQUEST_DETAILS` (`REQUEST_ID`),
  ADD CONSTRAINT `asgssactndtls_vendrid` FOREIGN KEY (`VENDOR_ID`) REFERENCES `AS_GSS_EVALUATION_VENDOR` (`VENDOR_ID`),
  ADD CONSTRAINT `asgssactndtls_criteriaid` FOREIGN KEY (`CRITERIA_ID`) REFERENCES `AS_GSS_CRITERIA` (`CRITERIA_ID`),
  ADD CONSTRAINT `asgssactndtls_docid` FOREIGN KEY (`DOCUMENT_ID`) REFERENCES `AS_GSS_EVALUATION_DOCUMENT` (`EVAL_DOCUMENT_ID`),
ADD CONSTRAINT `asgssactndtls_status` FOREIGN KEY (STATUS_ID) REFERENCES AS_GSS_R_DATA (REF_DATA_ID);


-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 323, 5658, 4557);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ************************************************************
-- [5665] Create Factor Requirement Table
-- ************************************************************
-- The table to hold the factor level requirement information
-- ************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",323, "Source Selection 2.9", 5665, "Create Factor Requirement Table",4558,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE AS_GSS_AI_FACTOR_REQMNT (
  REQUIREMENT_ID INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  EVALUATION_ID INT(11) DEFAULT NULL,
  CRITERIA_ID INT(11) DEFAULT NULL,
  ACTION_ID INT(11) DEFAULT NULL,
  REQUIREMENT_TEXT VARCHAR(4000) DEFAULT NULL,
  IS_ACTIVE TINYINT(1) DEFAULT NULL,
  CREATED_BY VARCHAR(255) DEFAULT NULL,
  CREATED_ON DATETIME DEFAULT NULL,
  MODIFIED_BY VARCHAR(255) DEFAULT NULL,
  MODIFIED_ON DATETIME DEFAULT NULL
) AUTO_INCREMENT=1 COMMENT 'Holds the factor level requirement information';


ALTER TABLE AS_GSS_AI_FACTOR_REQMNT
  ADD CONSTRAINT asgssaifctrreq_eval FOREIGN KEY (EVALUATION_ID) REFERENCES AS_GSS_EVALUATION (EVALUATION_ID),
  ADD CONSTRAINT asgssaifctrreq_ascrtria FOREIGN KEY (CRITERIA_ID) REFERENCES AS_GSS_CRITERIA (CRITERIA_ID),
  ADD CONSTRAINT asgssaifctrreq_actdet FOREIGN KEY (ACTION_ID) REFERENCES AS_GSS_AI_ACTION_DETAILS (ACTION_ID);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 323, 5665, 4558);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************************************************
-- [5668] Create Vendor Analysis Table
-- ****************************************************************************
-- The table to hold the vendor analysis information from proposal extraction
-- ****************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",323, "Source Selection 2.9", 5668, "Create Vendor Analysis Table",4547,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE AS_GSS_AI_VENDOR_ANALYSIS (
  ANALYSIS_ID INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  EVALUATION_ID INT(11) DEFAULT NULL,
  VENDOR_ID INT(11) DEFAULT NULL,
  OVERALL_SUMMARY VARCHAR(4000) DEFAULT NULL,
  CONFIDENCE_SCORE DOUBLE DEFAULT NULL,
  DOCUMENT_COUNT INT(11) DEFAULT NULL,
  STATUS_ID INT(11) DEFAULT NULL,
  LAST_GENERATED_ON DATETIME DEFAULT NULL,
  IS_ACTIVE TINYINT(1) DEFAULT NULL,
  CREATED_BY VARCHAR(255) DEFAULT NULL,
  CREATED_ON DATETIME DEFAULT NULL,
  MODIFIED_BY VARCHAR(255) DEFAULT NULL,
  MODIFIED_ON DATETIME DEFAULT NULL
) AUTO_INCREMENT=1 COMMENT 'Holds the vendor analysis information';


ALTER TABLE AS_GSS_AI_VENDOR_ANALYSIS
  ADD CONSTRAINT asgssaivendal_eval FOREIGN KEY (EVALUATION_ID) REFERENCES AS_GSS_EVALUATION (EVALUATION_ID),
  ADD CONSTRAINT asgssaivendal_vendor FOREIGN KEY (VENDOR_ID) REFERENCES AS_GSS_EVALUATION_VENDOR (VENDOR_ID),
  ADD CONSTRAINT asgssaivendal_status FOREIGN KEY (STATUS_ID) REFERENCES AS_GSS_R_DATA (REF_DATA_ID);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 323, 5668, 4547);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***********************************************************************
-- [5675] Create Vendor Factor Analysis Table
-- ***********************************************************************
-- This table holds the vendor - factor analysis summary for evaluations
-- ***********************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",323, "Source Selection 2.9", 5675, "Create Vendor Factor Analysis Table",4548,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE AS_GSS_AI_VEN_CRT_ANALYSIS (
  ANALYSIS_ID INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  VENDOR_ANALYSIS_ID INT(11) DEFAULT NULL,
  CRITERIA_ID INT(11) DEFAULT NULL,
  CRITERIA_SUMMARY VARCHAR(4000) DEFAULT NULL,
  IS_ACTIVE TINYINT(1) DEFAULT NULL,
  CREATED_BY VARCHAR(255) DEFAULT NULL,
  CREATED_ON DATETIME DEFAULT NULL,
  MODIFIED_BY VARCHAR(255) DEFAULT NULL,
  MODIFIED_ON DATETIME DEFAULT NULL
) AUTO_INCREMENT=1 COMMENT 'Holds the vendor - factor analysis summary';


ALTER TABLE AS_GSS_AI_VEN_CRT_ANALYSIS
  ADD CONSTRAINT asgssaifctrals_asvendals FOREIGN KEY (VENDOR_ANALYSIS_ID) REFERENCES AS_GSS_AI_VENDOR_ANALYSIS (ANALYSIS_ID),
  ADD CONSTRAINT asgssaifctrals_ascrtria FOREIGN KEY (CRITERIA_ID) REFERENCES AS_GSS_CRITERIA (CRITERIA_ID);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 323, 5675, 4548);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ******************************************************************
-- [5676] Create Vendor Analysis finding table
-- ******************************************************************
-- This table holds the vendor findings from the proposal documents
-- ******************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",323, "Source Selection 2.9", 5676, "Create Vendor Analysis finding table",4580,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE AS_GSS_AI_VND_ANLYS_FINDING (
  FINDING_ID INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  ACTION_ID INT(11) DEFAULT NULL,
  REQUIREMENT_ID INT(11) DEFAULT NULL,
  CONFIDENCE_ID INT(11) DEFAULT NULL,
  CATEGORY_ID INT(11) DEFAULT NULL,
  ACTUAL_TEXT VARCHAR(4000) DEFAULT NULL,
  SOURCE_PAGE VARCHAR(255) DEFAULT NULL,
  IS_ACTIVE TINYINT(1) DEFAULT NULL,
  CREATED_BY VARCHAR(255) DEFAULT NULL,
  CREATED_ON DATETIME DEFAULT NULL,
  MODIFIED_BY VARCHAR(255) DEFAULT NULL,
  MODIFIED_ON DATETIME DEFAULT NULL
) AUTO_INCREMENT=1 COMMENT 'Holds the findings of the vendor analysis';


ALTER TABLE AS_GSS_AI_VND_ANLYS_FINDING
  ADD CONSTRAINT asgssvndalfnd_asaiactn FOREIGN KEY (ACTION_ID) REFERENCES AS_GSS_AI_ACTION_DETAILS (ACTION_ID),
  ADD CONSTRAINT asgssvndalfnd_asairqmt FOREIGN KEY (REQUIREMENT_ID) REFERENCES AS_GSS_AI_FACTOR_REQMNT (REQUIREMENT_ID),
  ADD CONSTRAINT asgssvndalfnd_cnfidenc FOREIGN KEY (CONFIDENCE_ID) REFERENCES AS_GSS_R_DATA (REF_DATA_ID);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 323, 5676, 4580);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ************************************************************
-- [5677] Insert reference data for AI Action types
-- ************************************************************
-- This script inserts the reference data for AI Action types
-- ************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",323, "Source Selection 2.9", 5677, "Insert reference data for AI Action types",4542,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES (95, 'Requirement Extraction', NULL, 'AI Action Type', NULL, NULL, '1', '1', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES (96, 'Vendor Document Extraction', NULL, 'AI Action Type', NULL, NULL, '2', '1', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 323, 5677, 4542);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **********************************************************************
-- [5680] Insert reference data for AI Request Status
-- **********************************************************************
-- This scripts adds reference data entries for the AI Request Statuses
-- **********************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",323, "Source Selection 2.9", 5680, "Insert reference data for AI Request Status",4543,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES (97, 'In Progress', NULL, 'AI Request Status', NULL, NULL, '1', '1', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES (98, 'Completed', NULL, 'AI Request Status', NULL, NULL, '2', '1', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES (99, 'Failed', NULL, 'AI Request Status', NULL, NULL, '3', '1', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 323, 5680, 4543);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************************************
-- [5715] Insert ref data for Queued status for the AI Activities
-- ****************************************************************
-- Insert ref data for Queued status for the AI Activities
-- ****************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",323, "Source Selection 2.9", 5715, "Insert ref data for Queued status for the AI Activities",4576,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES (100, 'Queued', NULL, 'AI Request Status', NULL, NULL, '4', '1', 'appian.administrator', CURRENT_DATE(), 'appian.administrator', CURRENT_DATE());

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 323, 5715, 4576);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ***********************************************************************
-- [5716] Insert reference data for AI confidence values
-- ***********************************************************************
-- This scripts adds reference data entries for the AI confidence values
-- ***********************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",323, "Source Selection 2.9", 5716, "Insert reference data for AI confidence values",4577,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES (101, 'High', NULL, 'AI Confidence', NULL, NULL, '1', '1', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES (102, 'Medium', NULL, 'AI Confidence', NULL, NULL, '2', '1', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES (103, 'Low', NULL, 'AI Confidence', NULL, NULL, '3', '1', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 323, 5716, 4577);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *******************************************************************
-- [5721] Create Requirement Finding Categories table
-- *******************************************************************
-- This table holds the categories of the findings for a requirement
-- *******************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",323, "Source Selection 2.9", 5721, "Create Requirement Finding Categories table",4587,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

CREATE TABLE AS_GSS_AI_REQ_FND_CTGRY (
  CATEGORY_ID INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  ACTION_ID INT(11) DEFAULT NULL,
  CATEGORY VARCHAR(500) DEFAULT NULL,
  IS_ACTIVE TINYINT(1) DEFAULT NULL,
  CREATED_BY VARCHAR(255) DEFAULT NULL,
  CREATED_ON DATETIME DEFAULT NULL,
  MODIFIED_BY VARCHAR(255) DEFAULT NULL,
  MODIFIED_ON DATETIME DEFAULT NULL
) AUTO_INCREMENT=1 COMMENT 'Holds the categories of findings for a requirement';


ALTER TABLE AS_GSS_AI_REQ_FND_CTGRY
  ADD CONSTRAINT asgssrqfnctg_asaiactn FOREIGN KEY (ACTION_ID) REFERENCES AS_GSS_AI_ACTION_DETAILS (ACTION_ID);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 323, 5721, 4587);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- **********************************************************************************************************************
-- [5722] Add foreign key constraints to Finings table
-- **********************************************************************************************************************
-- This script adds foreign key constraints to the AS_GSS_AI_VND_ANLYS_FINDING table with AS_GSS_AI_REQ_FND_CTGRY table
-- **********************************************************************************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",323, "Source Selection 2.9", 5722, "Add foreign key constraints to Finings table",4582,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE AS_GSS_AI_VND_ANLYS_FINDING
  ADD CONSTRAINT asgssvndalfnd_asfndctg FOREIGN KEY (CATEGORY_ID) REFERENCES AS_GSS_AI_REQ_FND_CTGRY (CATEGORY_ID);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 323, 5722, 4582);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************************
-- [5728] Add action type column
-- ****************************************************
-- Add action type column in AS_GSS_AI_ACTION_DETAILS
-- ****************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",323, "Source Selection 2.9", 5728, "Add action type column",4589,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

ALTER TABLE `AS_GSS_AI_ACTION_DETAILS` ADD `ACTION_TYPE` INT(11) NULL DEFAULT NULL;

ALTER TABLE `AS_GSS_AI_ACTION_DETAILS`
ADD CONSTRAINT `asgssactndtls_type` FOREIGN KEY (`ACTION_TYPE`) REFERENCES `AS_GSS_R_DATA` (`REF_DATA_ID`);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 323, 5728, 4589);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- ****************************************
-- [5729] Insert Ref data for action type
-- ****************************************
-- Insert ref data for action type
-- ****************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",323, "Source Selection 2.9", 5729, "Insert Ref data for action type",4590,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

INSERT INTO `AS_GSS_R_DATA` (`REF_DATA_ID`, `REF_LABEL`, `REF_DESCRIPTION`, `REF_TYPE`, `REF_ICON`, `REF_COLOR`, `SORT_ORDER`, `IS_ACTIVE`, `CREATED_BY`, `CREATED_DATETIME`, `MODIFIED_BY`, `MODIFIED_DATETIME`) VALUES
('104', 'REQUIREMENT_EXTRACTION', 'REQUIREMENT_EXTRACTION', 'AI_ACTION_TYPE', NULL, NULL, '1', '1', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
('105', 'FINDINGS_EXTRACTION', 'FINDINGS_EXTRACTION', 'AI_ACTION_TYPE', NULL, NULL, '1', '1', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
('106', 'SUMMARIZE_FACTOR_FINDINGS', 'SUMMARIZE_FACTOR_FINDINGS', 'AI_ACTION_TYPE', NULL, NULL, '1', '1', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP),
('107', 'SUMMARIZE_VENDOR_FINDINGS', 'SUMMARIZE_VENDOR_FINDINGS', 'AI_ACTION_TYPE', NULL, NULL, '1', '1', 'appian.administrator', CURRENT_TIMESTAMP, 'appian.administrator', CURRENT_TIMESTAMP);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 323, 5729, 4590);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


-- *************************************************
-- [5730] Update AI Action Type to AI Request Type
-- *************************************************
-- Update AI Action Type to AI Request Type
-- *************************************************

DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;
DELIMITER $$
CREATE PROCEDURE AS_GSS_RunFrameworkScript()
BEGIN
CALL AS_GSS_Initial_Execution("N",323, "Source Selection 2.9", 5730, "Update AI Action Type to AI Request Type",4591,  @AS_GSS_scriptExecuteId, @cont);

IF @cont > 0
THEN
-- START SCRIPT CONTENT ---

UPDATE `AS_GSS_R_DATA` SET `REF_TYPE` = 'AI Request Type' WHERE `AS_GSS_R_DATA`.`REF_DATA_ID` IN (95,96);

-- END SCRIPT CONTENT ---
 
CALL AS_GSS_Update_Execution(@AS_GSS_scriptExecuteId, 323, 5730, 4591);
END IF;
END $$
DELIMITER ;

CALL AS_GSS_RunFrameworkScript();
DROP PROCEDURE IF EXISTS AS_GSS_RunFrameworkScript;


