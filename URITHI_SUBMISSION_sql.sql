SET SERVEROUTPUT ON SIZE UNLIMITED;
SET DEFINE OFF;
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD';

PROMPT
PROMPT =========================================================================
PROMPT URITHI SUBMISSION SCRIPT - START (empty schema URITHAPPLICATION)
PROMPT =========================================================================


CREATE SEQUENCE SEQ_TRUSTOR START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_TRUSTEE START WITH 1001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_BENEFICIARY START WITH 2001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_TRUST START WITH 3001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_ASSET START WITH 4001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_DISTRIBUTION START WITH 5001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_APPROVAL START WITH 6001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_NOTIFICATION START WITH 7001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_ROLE START WITH 8001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_USER_ACCOUNT START WITH 9001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_AUDIT_LOG START WITH 10001 INCREMENT BY 1 NOCACHE NOCYCLE;



CREATE TABLE TRUSTOR (
    TrustorID     NUMBER(10)      CONSTRAINT PK_TRUSTOR PRIMARY KEY,
    Name          VARCHAR2(100)   NOT NULL,
    NationalID    VARCHAR2(20)    CONSTRAINT UQ_TRUSTOR_NID UNIQUE NOT NULL,
    Phone         VARCHAR2(15),
    Email         VARCHAR2(100)   CONSTRAINT UQ_TRUSTOR_EMAIL UNIQUE,
    Address       VARCHAR2(200)
);

COMMENT ON TABLE TRUSTOR IS 'Records individuals who create and fund trusts.';
COMMENT ON COLUMN TRUSTOR.TrustorID IS 'Primary key, populated from SEQ_TRUSTOR.';
COMMENT ON COLUMN TRUSTOR.NationalID IS 'Ugandan NIRA National ID, unique identifier.';



CREATE TABLE TRUSTEE (
    TrusteeID       NUMBER(10)      CONSTRAINT PK_TRUSTEE PRIMARY KEY,
    Name            VARCHAR2(100)   NOT NULL,
    NationalID      VARCHAR2(20)    CONSTRAINT UQ_TRUSTEE_NID UNIQUE NOT NULL,
    Phone           VARCHAR2(15),
    Email           VARCHAR2(100)   CONSTRAINT UQ_TRUSTEE_EMAIL UNIQUE,
    Address         VARCHAR2(200),
    DateAppointed   DATE            DEFAULT SYSDATE NOT NULL
);

COMMENT ON TABLE TRUSTEE IS 'Records trustees appointed to manage trusts.';
COMMENT ON COLUMN TRUSTEE.TrusteeID IS 'Primary key, populated from SEQ_TRUSTEE.';



CREATE TABLE BENEFICIARY (
    BeneficiaryID           NUMBER(10)      CONSTRAINT PK_BENEFICIARY PRIMARY KEY,
    Name                    VARCHAR2(100)   NOT NULL,
    NationalID              VARCHAR2(20)    CONSTRAINT UQ_BENEFICIARY_NID UNIQUE,
    Phone                   VARCHAR2(15),
    Email                   VARCHAR2(100)   CONSTRAINT UQ_BENEFICIARY_EMAIL UNIQUE,
    DateOfBirth             DATE,
    RelationshipToTrustor   VARCHAR2(50)    NOT NULL
);

COMMENT ON TABLE BENEFICIARY IS 'Records beneficiaries entitled to benefit from trusts.';
COMMENT ON COLUMN BENEFICIARY.RelationshipToTrustor IS 'e.g., CHILD, SPOUSE, DEPENDENT, SIBLING.';


CREATE TABLE ROLE (
    RoleID              NUMBER(5)       CONSTRAINT PK_ROLE PRIMARY KEY,
    RoleName            VARCHAR2(30)    CONSTRAINT UQ_ROLE_NAME UNIQUE NOT NULL,
    Description         VARCHAR2(200)
);

COMMENT ON TABLE ROLE IS 'Defines system roles for RBAC.';


CREATE TABLE TRUST (
    TrustID             NUMBER(10)      CONSTRAINT PK_TRUST PRIMARY KEY,
    TrustName           VARCHAR2(150)   NOT NULL,
    TrustType           VARCHAR2(20)    NOT NULL,
    RegistrationStatus  VARCHAR2(20)    DEFAULT 'DEED_ONLY' NOT NULL,
    CertificateNumber   VARCHAR2(30),
    DateCreated         DATE            DEFAULT SYSDATE NOT NULL,
    Status              VARCHAR2(15)    DEFAULT 'PENDING' NOT NULL,
    TrustorID           NUMBER(10)      CONSTRAINT FK_TRUST_TRUSTOR REFERENCES TRUSTOR(TrustorID) NOT NULL,
    CONSTRAINT CK_TRUST_TYPE CHECK (TrustType IN ('FAMILY', 'EDUCATION', 'PROPERTY', 'CHARITABLE', 'RELIGIOUS')),
    CONSTRAINT CK_TRUST_REGSTATUS CHECK (RegistrationStatus IN ('DEED_ONLY', 'URSB_SUBMITTED', 'INCORPORATED')),
    CONSTRAINT CK_TRUST_STATUS CHECK (Status IN ('PENDING', 'ACTIVE', 'CLOSED')),
    CONSTRAINT CK_TRUST_CERT CHECK (RegistrationStatus != 'INCORPORATED' OR CertificateNumber IS NOT NULL)
);

COMMENT ON TABLE TRUST IS 'Core trust entity. RegistrationStatus reflects Ugandan legal framework.';
COMMENT ON COLUMN TRUST.RegistrationStatus IS 'DEED_ONLY: signed deed only; URSB_SUBMITTED: pending URSB approval; INCORPORATED: full URSB certificate issued.';
COMMENT ON COLUMN TRUST.CertificateNumber IS 'URSB Certificate of Incorporation number, required when RegistrationStatus = INCORPORATED.';



CREATE TABLE TRUST_TRUSTEE (
    TrustID         NUMBER(10)      CONSTRAINT FK_TT_TRUST REFERENCES TRUST(TrustID),
    TrusteeID       NUMBER(10)      CONSTRAINT FK_TT_TRUSTEE REFERENCES TRUSTEE(TrusteeID),
    DateAssigned    DATE            DEFAULT SYSDATE NOT NULL,
    CONSTRAINT PK_TRUST_TRUSTEE PRIMARY KEY (TrustID, TrusteeID)
);

COMMENT ON TABLE TRUST_TRUSTEE IS 'Associative table resolving many-to-many relationship between trusts and trustees.';



CREATE TABLE TRUST_BENEFICIARY (
    TrustID             NUMBER(10)      CONSTRAINT FK_TB_TRUST REFERENCES TRUST(TrustID),
    BeneficiaryID       NUMBER(10)      CONSTRAINT FK_TB_BENEFICIARY REFERENCES BENEFICIARY(BeneficiaryID),
    SharePercentage     NUMBER(5,2)     NOT NULL,
    CONSTRAINT PK_TRUST_BENEFICIARY PRIMARY KEY (TrustID, BeneficiaryID),
    CONSTRAINT CK_TB_SHARE CHECK (SharePercentage BETWEEN 0 AND 100)
);

COMMENT ON TABLE TRUST_BENEFICIARY IS 'Associative table linking trusts to beneficiaries with their share percentage.';



CREATE TABLE ASSET (
    AssetID             NUMBER(10)      CONSTRAINT PK_ASSET PRIMARY KEY,
    TrustID             NUMBER(10)      CONSTRAINT FK_ASSET_TRUST REFERENCES TRUST(TrustID) NOT NULL,
    AssetName           VARCHAR2(150)   NOT NULL,
    AssetType           VARCHAR2(30)    NOT NULL,
    EstimatedValue      NUMBER(15,2)    NOT NULL,
    DateRegistered      DATE            DEFAULT SYSDATE NOT NULL,
    Status              VARCHAR2(25)    DEFAULT 'AVAILABLE' NOT NULL,
    CONSTRAINT CK_ASSET_TYPE CHECK (AssetType IN ('CASH', 'PROPERTY', 'SHARES', 'LAND', 'BUILDING', 'VEHICLE', 'OTHER')),
    CONSTRAINT CK_ASSET_VALUE CHECK (EstimatedValue >= 0),
    CONSTRAINT CK_ASSET_STATUS CHECK (Status IN ('AVAILABLE', 'PARTIALLY_DISTRIBUTED', 'FULLY_DISTRIBUTED', 'DISPOSED'))
);

COMMENT ON TABLE ASSET IS 'Records assets held within a trust.';
COMMENT ON COLUMN ASSET.AssetType IS 'CASH, PROPERTY, SHARES, LAND, BUILDING, VEHICLE, OTHER.';



CREATE TABLE USER_ACCOUNT (
    UserID              NUMBER(10)      CONSTRAINT PK_USER_ACCOUNT PRIMARY KEY,
    Username            VARCHAR2(50)    CONSTRAINT UQ_USER_USERNAME UNIQUE NOT NULL,
    PasswordHash        VARCHAR2(256)   NOT NULL,
    RoleID              NUMBER(5)       CONSTRAINT FK_USER_ROLE REFERENCES ROLE(RoleID) NOT NULL,
    LinkedPersonID      NUMBER(10)      NOT NULL,
    LinkedPersonType    VARCHAR2(15)    NOT NULL,
    IsActive            NUMBER(1)       DEFAULT 1 NOT NULL,
    CONSTRAINT CK_USER_LINKED_TYPE CHECK (LinkedPersonType IN ('TRUSTOR', 'TRUSTEE', 'BENEFICIARY', 'ADMIN')),
    CONSTRAINT CK_USER_ACTIVE CHECK (IsActive IN (0,1))
);

COMMENT ON TABLE USER_ACCOUNT IS 'System users with role-based access. Polymorphic reference to person types.';


CREATE TABLE DISTRIBUTION (
    DistributionID          NUMBER(10)      CONSTRAINT PK_DISTRIBUTION PRIMARY KEY,
    AssetID                 NUMBER(10)      CONSTRAINT FK_DIST_ASSET REFERENCES ASSET(AssetID) NOT NULL,
    BeneficiaryID           NUMBER(10)      CONSTRAINT FK_DIST_BENEFICIARY REFERENCES BENEFICIARY(BeneficiaryID) NOT NULL,
    InitiatedByTrusteeID    NUMBER(10)      CONSTRAINT FK_DIST_TRUSTEE REFERENCES TRUSTEE(TrusteeID) NOT NULL,
    AmountRequested         NUMBER(15,2)    NOT NULL,
    DateRequested           DATE            DEFAULT SYSDATE NOT NULL,
    Status                  VARCHAR2(15)    DEFAULT 'PENDING' NOT NULL,
    CONSTRAINT CK_DIST_AMOUNT CHECK (AmountRequested > 0),
    CONSTRAINT CK_DIST_STATUS CHECK (Status IN ('PENDING', 'APPROVED', 'REJECTED', 'EXECUTED', 'CANCELLED'))
);

COMMENT ON TABLE DISTRIBUTION IS 'Records distribution requests initiated by trustees.';
COMMENT ON COLUMN DISTRIBUTION.Status IS 'PENDING: awaiting approvals; APPROVED: has 2+ approvals; REJECTED: rejected; EXECUTED: paid out; CANCELLED: withdrawn.';



CREATE TABLE APPROVAL (
    ApprovalID              NUMBER(10)      CONSTRAINT PK_APPROVAL PRIMARY KEY,
    DistributionID          NUMBER(10)      CONSTRAINT FK_APPROVAL_DIST REFERENCES DISTRIBUTION(DistributionID) NOT NULL,
    ApprovedByTrusteeID     NUMBER(10)      CONSTRAINT FK_APPROVAL_TRUSTEE REFERENCES TRUSTEE(TrusteeID) NOT NULL,
    ApprovalDate            DATE            DEFAULT SYSDATE NOT NULL,
    Decision                VARCHAR2(15)    NOT NULL,
    DecisionNotes           VARCHAR2(500),
    CONSTRAINT UQ_APPROVAL_DIST_TRUSTEE UNIQUE (DistributionID, ApprovedByTrusteeID),
    CONSTRAINT CK_APPROVAL_DECISION CHECK (Decision IN ('APPROVED', 'REJECTED'))
);

COMMENT ON TABLE APPROVAL IS 'Records individual trustee approvals for distributions. Enforces four-eyes rule.';
COMMENT ON COLUMN APPROVAL.Decision IS 'APPROVED or REJECTED.';



CREATE TABLE NOTIFICATION (
    NotificationID      NUMBER(12)      CONSTRAINT PK_NOTIFICATION PRIMARY KEY,
    UserID              NUMBER(10)      CONSTRAINT FK_NOTIF_USER REFERENCES USER_ACCOUNT(UserID) NOT NULL,
    NotificationType    VARCHAR2(30)    NOT NULL,
    Title               VARCHAR2(200),
    Message             VARCHAR2(500)   NOT NULL,
    RelatedTable        VARCHAR2(30),
    RelatedRecordID     NUMBER(10),
    Channel             VARCHAR2(10)    DEFAULT 'IN_APP' NOT NULL,
    IsRead              NUMBER(1)       DEFAULT 0 NOT NULL,
    CreatedAt           TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    SentAt              TIMESTAMP,
    CONSTRAINT CK_NOTIF_TYPE CHECK (NotificationType IN (
        'APPROVAL_NEEDED',
        'DISTRIBUTION_EXECUTED',
        'DISTRIBUTION_REJECTED',
        'DISTRIBUTION_APPROVED',
        'TRUST_UNASSIGNED'
    )),
    CONSTRAINT CK_NOTIF_CHANNEL CHECK (Channel IN ('SMS', 'EMAIL', 'IN_APP')),
    CONSTRAINT CK_NOTIF_READ CHECK (IsRead IN (0,1))
);

COMMENT ON TABLE NOTIFICATION IS 'Records notifications sent to users via SMS, Email, and In-App. SMS is a first-class channel.';



CREATE TABLE AUDIT_LOG (
    LogID               NUMBER(12)      CONSTRAINT PK_AUDIT_LOG PRIMARY KEY,
    UserID              NUMBER(10)      CONSTRAINT FK_AUDIT_USER REFERENCES USER_ACCOUNT(UserID),
    ActionType          VARCHAR2(50)    NOT NULL,
    ActionDescription   VARCHAR2(500)   NOT NULL,
    ActionTimestamp     TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    TableAffected       VARCHAR2(30)    NOT NULL,
    RecordID            NUMBER(10)
);

COMMENT ON TABLE AUDIT_LOG IS 'Immutable audit log for all significant actions. Append-only with no DELETE privilege granted.';



CREATE INDEX IDX_TRUST_TRUSTORID ON TRUST(TrustorID);
CREATE INDEX IDX_ASSET_TRUSTID ON ASSET(TrustID);
CREATE INDEX IDX_DISTRIBUTION_ASSETID ON DISTRIBUTION(AssetID);
CREATE INDEX IDX_DISTRIBUTION_BENEFICIARYID ON DISTRIBUTION(BeneficiaryID);
CREATE INDEX IDX_DISTRIBUTION_INITIATEDBY ON DISTRIBUTION(InitiatedByTrusteeID);
CREATE INDEX IDX_APPROVAL_DISTRIBUTIONID ON APPROVAL(DistributionID);
CREATE INDEX IDX_APPROVAL_APPROVEDBY ON APPROVAL(ApprovedByTrusteeID);
CREATE INDEX IDX_NOTIFICATION_USERID ON NOTIFICATION(UserID);
CREATE INDEX IDX_AUDIT_LOG_USERID ON AUDIT_LOG(UserID);
CREATE INDEX IDX_TT_TRUSTEEID ON TRUST_TRUSTEE(TrusteeID);
CREATE INDEX IDX_TB_BENEFICIARYID ON TRUST_BENEFICIARY(BeneficiaryID);


CREATE OR REPLACE TRIGGER TRG_PREVENT_SELF_APPROVAL
BEFORE INSERT ON APPROVAL
FOR EACH ROW
DECLARE
    v_initiator NUMBER;
BEGIN
    SELECT InitiatedByTrusteeID
    INTO v_initiator
    FROM DISTRIBUTION
    WHERE DistributionID = :NEW.DistributionID;

    IF :NEW.ApprovedByTrusteeID = v_initiator THEN
        RAISE_APPLICATION_ERROR(-20001, 'A trustee cannot approve a distribution they initiated.');
    END IF;
END TRG_PREVENT_SELF_APPROVAL;
/



CREATE OR REPLACE TRIGGER TRG_NOTIFY_APPROVAL_NEEDED
AFTER INSERT ON DISTRIBUTION
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_trust_id NUMBER;
BEGIN
    SELECT TrustID
    INTO v_trust_id
    FROM ASSET
    WHERE AssetID = :NEW.AssetID;

    FOR t_rec IN (
        SELECT u.UserID
        FROM TRUST_TRUSTEE tt
        JOIN USER_ACCOUNT u ON u.LinkedPersonID = tt.TrusteeID AND u.LinkedPersonType = 'TRUSTEE'
        WHERE tt.TrustID = v_trust_id
    ) LOOP
        INSERT INTO NOTIFICATION (
            NotificationID, UserID, NotificationType, Title, Message,
            RelatedTable, RelatedRecordID, Channel
        ) VALUES (
            SEQ_NOTIFICATION.NEXTVAL, t_rec.UserID, 'APPROVAL_NEEDED',
            'Distribution Approval Required',
            'A new distribution request requires your approval.',
            'DISTRIBUTION', :NEW.DistributionID, 'SMS'
        );
    END LOOP;

    COMMIT;
END TRG_NOTIFY_APPROVAL_NEEDED;
/


CREATE OR REPLACE TRIGGER TRG_ENSURE_TWO_APPROVALS
AFTER INSERT OR UPDATE OF Decision ON APPROVAL
FOR EACH ROW
DECLARE
    v_approval_count NUMBER;
    v_rejection_count NUMBER;
    v_current_status VARCHAR2(15);
BEGIN
    -- Only process if the decision is APPROVED or REJECTED
    IF :NEW.Decision IN ('APPROVED', 'REJECTED') THEN
        
        -- Get current distribution status
        SELECT Status
        INTO v_current_status
        FROM DISTRIBUTION
        WHERE DistributionID = :NEW.DistributionID;
        
        -- Count approved approvals for this distribution
        SELECT COUNT(*)
        INTO v_approval_count
        FROM APPROVAL
        WHERE DistributionID = :NEW.DistributionID
          AND Decision = 'APPROVED';
        
        -- Count rejected approvals for this distribution
        SELECT COUNT(*)
        INTO v_rejection_count
        FROM APPROVAL
        WHERE DistributionID = :NEW.DistributionID
          AND Decision = 'REJECTED';
        
        -- If any rejection exists, mark as REJECTED
        IF v_rejection_count > 0 AND v_current_status != 'REJECTED' THEN
            UPDATE DISTRIBUTION
            SET Status = 'REJECTED'
            WHERE DistributionID = :NEW.DistributionID;
        
        -- If at least 2 approvals, mark as APPROVED
        ELSIF v_approval_count >= 2 AND v_current_status = 'PENDING' THEN
            UPDATE DISTRIBUTION
            SET Status = 'APPROVED'
            WHERE DistributionID = :NEW.DistributionID;
            
            -- Notify the beneficiary that the distribution is approved
            DECLARE
                v_beneficiary_id NUMBER;
                v_user_id NUMBER;
            BEGIN
                SELECT BeneficiaryID
                INTO v_beneficiary_id
                FROM DISTRIBUTION
                WHERE DistributionID = :NEW.DistributionID;
                
                SELECT UserID
                INTO v_user_id
                FROM USER_ACCOUNT
                WHERE LinkedPersonID = v_beneficiary_id
                  AND LinkedPersonType = 'BENEFICIARY'
                  AND IsActive = 1;
                
                INSERT INTO NOTIFICATION (
                    NotificationID,
                    UserID,
                    NotificationType,
                    Title,
                    Message,
                    RelatedTable,
                    RelatedRecordID,
                    Channel,
                    CreatedAt
                ) VALUES (
                    SEQ_NOTIFICATION.NEXTVAL,
                    v_user_id,
                    'DISTRIBUTION_APPROVED',
                    'Distribution Approved',
                    'Your distribution (ID: ' || :NEW.DistributionID || ') has been approved by two trustees.',
                    'DISTRIBUTION',
                    :NEW.DistributionID,
                    'SMS',
                    SYSTIMESTAMP
                );
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL; -- Beneficiary has no user account
            END;
        END IF;
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        NULL; -- Distribution not found
    WHEN OTHERS THEN
        NULL; -- Don't fail the trigger
END TRG_ENSURE_TWO_APPROVALS;
/


CREATE OR REPLACE TRIGGER TRG_AUDIT_DISTRIBUTION_STATUS
AFTER UPDATE OF Status ON DISTRIBUTION
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO AUDIT_LOG (
        LogID, UserID, ActionType, ActionDescription,
        TableAffected, RecordID, ActionTimestamp
    ) VALUES (
        SEQ_AUDIT_LOG.NEXTVAL,
        NULL,
        'DISTRIBUTION_STATUS_CHANGE',
        'Distribution ' || :NEW.DistributionID || ' status changed from ' || :OLD.Status || ' to ' || :NEW.Status,
        'DISTRIBUTION',
        :NEW.DistributionID,
        SYSTIMESTAMP
    );

    COMMIT;
END TRG_AUDIT_DISTRIBUTION_STATUS;
/



CREATE OR REPLACE TRIGGER TRG_AUDIT_APPROVAL
AFTER INSERT ON APPROVAL
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO AUDIT_LOG (
        LogID, UserID, ActionType, ActionDescription,
        TableAffected, RecordID, ActionTimestamp
    ) VALUES (
        SEQ_AUDIT_LOG.NEXTVAL,
        NULL,
        'APPROVAL_RECORDED',
        'Approval ' || :NEW.Decision || ' recorded for distribution ' || :NEW.DistributionID,
        'APPROVAL',
        :NEW.ApprovalID,
        SYSTIMESTAMP
    );

    COMMIT;
END TRG_AUDIT_APPROVAL;
/



CREATE OR REPLACE TRIGGER TRG_AUDIT_EXECUTE_DISTRIBUTION
AFTER UPDATE OF Status ON DISTRIBUTION
FOR EACH ROW
WHEN (NEW.Status = 'EXECUTED' AND OLD.Status != 'EXECUTED')
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    -- Audit log entry
    INSERT INTO AUDIT_LOG (
        LogID, UserID, ActionType, ActionDescription,
        TableAffected, RecordID, ActionTimestamp
    ) VALUES (
        SEQ_AUDIT_LOG.NEXTVAL,
        NULL,
        'DISTRIBUTION_EXECUTED',
        'Distribution ' || :NEW.DistributionID || ' executed for amount UGX ' || TO_CHAR(:NEW.AmountRequested),
        'DISTRIBUTION',
        :NEW.DistributionID,
        SYSTIMESTAMP
    );
    
    -- Notify beneficiary
    DECLARE
        v_beneficiary_id NUMBER;
        v_user_id NUMBER;
    BEGIN
        SELECT BeneficiaryID
        INTO v_beneficiary_id
        FROM DISTRIBUTION
        WHERE DistributionID = :NEW.DistributionID;
        
        SELECT UserID
        INTO v_user_id
        FROM USER_ACCOUNT
        WHERE LinkedPersonID = v_beneficiary_id
          AND LinkedPersonType = 'BENEFICIARY'
          AND IsActive = 1;
        
        INSERT INTO NOTIFICATION (
            NotificationID,
            UserID,
            NotificationType,
            Title,
            Message,
            RelatedTable,
            RelatedRecordID,
            Channel,
            CreatedAt
        ) VALUES (
            SEQ_NOTIFICATION.NEXTVAL,
            v_user_id,
            'DISTRIBUTION_EXECUTED',
            'Distribution Executed',
            'Your distribution (ID: ' || :NEW.DistributionID || ') of UGX ' || TO_CHAR(:NEW.AmountRequested) || ' has been executed.',
            'DISTRIBUTION',
            :NEW.DistributionID,
            'SMS',
            SYSTIMESTAMP
        );
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
    END;
    
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        NULL;
END TRG_AUDIT_EXECUTE_DISTRIBUTION;
/

-- =============================================================================
-- TRIGGER: TRG_ENSURE_ACTIVE_TRUST_HAS_TRUSTEES
-- Purpose: Prevents a trust from being activated without at least one trustee
-- Business Rule: A trust must have at least one trustee before ACTIVE
-- =============================================================================

CREATE OR REPLACE TRIGGER TRG_ENSURE_ACTIVE_TRUST_HAS_TRUSTEES
BEFORE UPDATE OF Status ON TRUST
FOR EACH ROW
WHEN (NEW.Status = 'ACTIVE')
DECLARE
    v_trustee_count NUMBER;
BEGIN
    IF :NEW.Status = 'ACTIVE' THEN
        SELECT COUNT(*)
        INTO v_trustee_count
        FROM TRUST_TRUSTEE
        WHERE TrustID = :NEW.TrustID;
        
        IF v_trustee_count = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20003,
                'A trust cannot be activated without at least one assigned trustee.'
            );
        END IF;
    END IF;
END TRG_ENSURE_ACTIVE_TRUST_HAS_TRUSTEES;
/


CREATE OR REPLACE VIEW VW_PENDING_DISTRIBUTIONS AS
SELECT
    d.DistributionID,
    a.AssetName,
    b.Name AS BeneficiaryName,
    t.Name AS TrusteeName,
    d.AmountRequested,
    d.DateRequested,
    d.Status,
    (SELECT COUNT(*) FROM APPROVAL ap
     WHERE ap.DistributionID = d.DistributionID
       AND ap.Decision = 'APPROVED') AS ApprovalCount
FROM DISTRIBUTION d
JOIN ASSET a ON d.AssetID = a.AssetID
JOIN BENEFICIARY b ON d.BeneficiaryID = b.BeneficiaryID
JOIN TRUSTEE t ON d.InitiatedByTrusteeID = t.TrusteeID
WHERE d.Status = 'PENDING'
ORDER BY d.DateRequested;


CREATE OR REPLACE VIEW VW_TRUST_SUMMARY AS
SELECT
    t.TrustID,
    t.TrustName,
    t.TrustType,
    tr.Name AS TrustorName,
    t.Status AS TrustStatus,
    (SELECT SUM(EstimatedValue) FROM ASSET WHERE TrustID = t.TrustID) AS TotalAssetValue,
    (SELECT NVL(SUM(AmountRequested), 0) FROM DISTRIBUTION d
     JOIN ASSET a ON d.AssetID = a.AssetID
     WHERE a.TrustID = t.TrustID AND d.Status = 'EXECUTED') AS TotalDistributed,
    NVL((SELECT SUM(EstimatedValue) FROM ASSET WHERE TrustID = t.TrustID), 0)
      - NVL((SELECT NVL(SUM(AmountRequested), 0) FROM DISTRIBUTION d
               JOIN ASSET a ON d.AssetID = a.AssetID
              WHERE a.TrustID = t.TrustID AND d.Status = 'EXECUTED'), 0) AS RemainingBalance,
    (SELECT COUNT(*) FROM TRUST_TRUSTEE WHERE TrustID = t.TrustID) AS TrusteeCount,
    (SELECT COUNT(*) FROM TRUST_BENEFICIARY WHERE TrustID = t.TrustID) AS BeneficiaryCount
FROM TRUST t
JOIN TRUSTOR tr ON t.TrustorID = tr.TrustorID;


CREATE OR REPLACE FUNCTION FUNC_GET_TRUST_BALANCE (
    p_trust_id IN NUMBER
) RETURN NUMBER
AS
    v_total_value       NUMBER(15,2) := 0;
    v_total_distributed NUMBER(15,2) := 0;
BEGIN
    SELECT NVL(SUM(EstimatedValue), 0)
    INTO v_total_value
    FROM ASSET
    WHERE TrustID = p_trust_id;

    SELECT NVL(SUM(AmountRequested), 0)
    INTO v_total_distributed
    FROM DISTRIBUTION
    WHERE AssetID IN (SELECT AssetID FROM ASSET WHERE TrustID = p_trust_id)
      AND Status = 'EXECUTED';

    RETURN v_total_value - v_total_distributed;
END FUNC_GET_TRUST_BALANCE;
/


CREATE OR REPLACE PROCEDURE PROC_EXECUTE_DISTRIBUTION (
    p_distribution_id IN NUMBER,
    p_executed_by_user IN NUMBER
) AS
    v_approval_count NUMBER;
    v_asset_id       NUMBER;
    v_beneficiary_id NUMBER;
    v_user_id        NUMBER;
BEGIN
    -- Enforce four-eyes rule
    SELECT COUNT(*) INTO v_approval_count
    FROM APPROVAL
    WHERE DistributionID = p_distribution_id
      AND Decision = 'APPROVED';

    IF v_approval_count < 2 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Distribution requires at least two independent approvals.');
    END IF;

    -- Execute distribution
    UPDATE DISTRIBUTION
    SET Status = 'EXECUTED'
    WHERE DistributionID = p_distribution_id
    RETURNING AssetID, BeneficiaryID
    INTO v_asset_id, v_beneficiary_id;

    -- Update asset status
    UPDATE ASSET SET Status = 'PARTIALLY_DISTRIBUTED'
    WHERE AssetID = v_asset_id;

    -- Audit log entry
    INSERT INTO AUDIT_LOG (LogID, UserID, ActionType, ActionDescription, TableAffected, RecordID)
    VALUES (
        SEQ_AUDIT_LOG.NEXTVAL, p_executed_by_user,
        'DISTRIBUTION_EXECUTED',
        'Distribution ID ' || p_distribution_id || ' executed.',
        'DISTRIBUTION', p_distribution_id
    );

    -- Notify beneficiary
    SELECT UserID INTO v_user_id
    FROM USER_ACCOUNT
    WHERE LinkedPersonID = v_beneficiary_id
      AND LinkedPersonType = 'BENEFICIARY'
      AND IsActive = 1;

    INSERT INTO NOTIFICATION (
        NotificationID, UserID, NotificationType, Title, Message,
        RelatedTable, RelatedRecordID, Channel
    ) VALUES (
        SEQ_NOTIFICATION.NEXTVAL, v_user_id,
        'DISTRIBUTION_EXECUTED',
        'Distribution Executed',
        'Your distribution has been approved and executed.',
        'DISTRIBUTION', p_distribution_id, 'SMS'
    );
    -- No COMMIT: APEX owns the transaction (COMMIT here can hang Execute / Pay Out).
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20003, 'Distribution or beneficiary account not found.');
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20004, 'Unexpected error: ' || SQLERRM);
END PROC_EXECUTE_DISTRIBUTION;
/


CREATE OR REPLACE PROCEDURE PROC_FLAG_UNASSIGNED_TRUSTS (
    p_admin_user_id IN NUMBER
)
AS
    CURSOR c_unassigned IS
        SELECT TrustID, TrustName
        FROM TRUST t
        WHERE NOT EXISTS (SELECT 1 FROM TRUST_TRUSTEE tt WHERE tt.TrustID = t.TrustID);
BEGIN
    FOR trust_rec IN c_unassigned LOOP
        -- Audit log entry
        INSERT INTO AUDIT_LOG (LogID, UserID, ActionType, ActionDescription, TableAffected, RecordID)
        VALUES (
            SEQ_AUDIT_LOG.NEXTVAL, p_admin_user_id,
            'UNASSIGNED_TRUST_FLAGGED',
            trust_rec.TrustName || ' has no assigned trustee.',
            'TRUST', trust_rec.TrustID
        );

        -- Notification for admin
        INSERT INTO NOTIFICATION (
            NotificationID, UserID, NotificationType, Title, Message,
            RelatedTable, RelatedRecordID, Channel
        ) VALUES (
            SEQ_NOTIFICATION.NEXTVAL, p_admin_user_id,
            'TRUST_UNASSIGNED',
            'Unassigned Trust Alert',
            trust_rec.TrustName || ' has no assigned trustee. Please assign a trustee.',
            'TRUST', trust_rec.TrustID, 'IN_APP'
        );
    END LOOP;
    -- No COMMIT: APEX owns the transaction (COMMIT here can hang Flag Unassigned).
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20005, 'Error flagging unassigned trusts: ' || SQLERRM);
END PROC_FLAG_UNASSIGNED_TRUSTS;
/

-- =============================================================================
-- PACKAGE: PKG_TRUST_MGMT
-- Purpose: Bundles all trust management functionality
-- =============================================================================

-- Core package (schema / Part IV). App 100 also needs auth + request/approve/profile
-- wrappers from db/02_urithi_apex_helpers.sql (run after this script — see README).
CREATE OR REPLACE PACKAGE PKG_TRUST_MGMT AS
    PROCEDURE execute_distribution(p_distribution_id IN NUMBER, p_executed_by_user IN NUMBER);
    FUNCTION get_trust_balance(p_trust_id IN NUMBER) RETURN NUMBER;
    PROCEDURE flag_unassigned_trusts(p_admin_user_id IN NUMBER);
END PKG_TRUST_MGMT;
/

CREATE OR REPLACE PACKAGE BODY PKG_TRUST_MGMT AS
    PROCEDURE execute_distribution(p_distribution_id IN NUMBER, p_executed_by_user IN NUMBER) AS
    BEGIN
        PROC_EXECUTE_DISTRIBUTION(p_distribution_id, p_executed_by_user);
    END;

    FUNCTION get_trust_balance(p_trust_id IN NUMBER) RETURN NUMBER AS
    BEGIN
        RETURN FUNC_GET_TRUST_BALANCE(p_trust_id);
    END;

    PROCEDURE flag_unassigned_trusts(p_admin_user_id IN NUMBER) AS
    BEGIN
        PROC_FLAG_UNASSIGNED_TRUSTS(p_admin_user_id);
    END;
END PKG_TRUST_MGMT;
/



INSERT INTO TRUSTOR (TrustorID, Name, NationalID, Phone, Email, Address)
VALUES (SEQ_TRUSTOR.NEXTVAL, 'Nalubega Grace', 'CM86000012345GN', '0772123456',
        'grace.nalubega@email.com', 'Plot 15, Nakasero, Kampala');

INSERT INTO TRUSTOR (TrustorID, Name, NationalID, Phone, Email, Address)
VALUES (SEQ_TRUSTOR.NEXTVAL, 'Mugisha John', 'CM75000067890MJ', '0772987654',
        'john.mugisha@email.com', 'Buziga, Kampala');

INSERT INTO TRUSTOR (TrustorID, Name, NationalID, Phone, Email, Address)
VALUES (SEQ_TRUSTOR.NEXTVAL, 'Atukwase Sarah', 'CM90000011223SA', '0788456789',
        'sarah.atukwase@email.com', 'Mbarara Town, Mbarara');

-- -----------------------------------------------------------------------------
-- TRUSTEE Sample Data
-- -----------------------------------------------------------------------------

INSERT INTO TRUSTEE (TrusteeID, Name, NationalID, Phone, Email, Address, DateAppointed)
VALUES (SEQ_TRUSTEE.NEXTVAL, 'Luwaga Peter', 'CM80000012345LP', '0772345678',
        'peter.luwaga@email.com', 'Plot 20, Kimathi Avenue, Kampala', SYSDATE);

INSERT INTO TRUSTEE (TrusteeID, Name, NationalID, Phone, Email, Address, DateAppointed)
VALUES (SEQ_TRUSTEE.NEXTVAL, 'Namukasa Rose', 'CM85000067890NR', '0772567890',
        'rose.namukasa@email.com', 'Ntinda, Kampala', SYSDATE);

INSERT INTO TRUSTEE (TrusteeID, Name, NationalID, Phone, Email, Address, DateAppointed)
VALUES (SEQ_TRUSTEE.NEXTVAL, 'Tumwebaze Charles', 'CM78000011223TC', '0788567890',
        'charles.tumwebaze@email.com', 'Nakasero, Kampala', SYSDATE);

-- -----------------------------------------------------------------------------
-- BENEFICIARY Sample Data
-- -----------------------------------------------------------------------------

INSERT INTO BENEFICIARY (BeneficiaryID, Name, NationalID, Phone, Email, DateOfBirth, RelationshipToTrustor)
VALUES (SEQ_BENEFICIARY.NEXTVAL, 'Nalubega Ivan', 'CM04000098765IN', '0751234567',
        NULL, TO_DATE('15-MAR-2004', 'DD-MON-YYYY'), 'SON');

INSERT INTO BENEFICIARY (BeneficiaryID, Name, NationalID, Phone, Email, DateOfBirth, RelationshipToTrustor)
VALUES (SEQ_BENEFICIARY.NEXTVAL, 'Nalubega Joan', 'CM06000054321NJ', '0751234568',
        NULL, TO_DATE('10-JUN-2006', 'DD-MON-YYYY'), 'DAUGHTER');

INSERT INTO BENEFICIARY (BeneficiaryID, Name, NationalID, Phone, Email, DateOfBirth, RelationshipToTrustor)
VALUES (SEQ_BENEFICIARY.NEXTVAL, 'Mugisha Brian', 'CM03000011223MB', '0773123456',
        NULL, TO_DATE('20-MAR-2003', 'DD-MON-YYYY'), 'SON');

INSERT INTO BENEFICIARY (BeneficiaryID, Name, NationalID, Phone, Email, DateOfBirth, RelationshipToTrustor)
VALUES (SEQ_BENEFICIARY.NEXTVAL, 'Mugisha Diana', 'CM07000044556MD', '0773123457',
        NULL, TO_DATE('15-OCT-2007', 'DD-MON-YYYY'), 'DAUGHTER');

-- -----------------------------------------------------------------------------
-- TRUST Sample Data
-- -----------------------------------------------------------------------------

INSERT INTO TRUST (TrustID, TrustName, TrustType, RegistrationStatus, CertificateNumber, DateCreated, Status, TrustorID)
VALUES (SEQ_TRUST.NEXTVAL, 'Nalubega Family Education Trust', 'EDUCATION', 'DEED_ONLY',
        NULL, SYSDATE, 'ACTIVE', 1);

INSERT INTO TRUST (TrustID, TrustName, TrustType, RegistrationStatus, CertificateNumber, DateCreated, Status, TrustorID)
VALUES (SEQ_TRUST.NEXTVAL, 'Mugisha Legacy Trust', 'FAMILY', 'DEED_ONLY',
        NULL, SYSDATE, 'PENDING', 2);

INSERT INTO TRUST (TrustID, TrustName, TrustType, RegistrationStatus, CertificateNumber, DateCreated, Status, TrustorID)
VALUES (SEQ_TRUST.NEXTVAL, 'Atukwase Family Trust', 'FAMILY', 'INCORPORATED',
        'URSB-2026-001', SYSDATE, 'ACTIVE', 3);

-- -----------------------------------------------------------------------------
-- TRUST_TRUSTEE Sample Data
-- -----------------------------------------------------------------------------

INSERT INTO TRUST_TRUSTEE (TrustID, TrusteeID, DateAssigned)
VALUES (3001, 1001, SYSDATE);

INSERT INTO TRUST_TRUSTEE (TrustID, TrusteeID, DateAssigned)
VALUES (3001, 1002, SYSDATE);

INSERT INTO TRUST_TRUSTEE (TrustID, TrusteeID, DateAssigned)
VALUES (3002, 1002, SYSDATE);

INSERT INTO TRUST_TRUSTEE (TrustID, TrusteeID, DateAssigned)
VALUES (3003, 1001, SYSDATE);

INSERT INTO TRUST_TRUSTEE (TrustID, TrusteeID, DateAssigned)
VALUES (3003, 1003, SYSDATE);

-- -----------------------------------------------------------------------------
-- TRUST_BENEFICIARY Sample Data
-- -----------------------------------------------------------------------------

INSERT INTO TRUST_BENEFICIARY (TrustID, BeneficiaryID, SharePercentage)
VALUES (3001, 2001, 50);

INSERT INTO TRUST_BENEFICIARY (TrustID, BeneficiaryID, SharePercentage)
VALUES (3001, 2002, 30);

INSERT INTO TRUST_BENEFICIARY (TrustID, BeneficiaryID, SharePercentage)
VALUES (3001, 2003, 20);

INSERT INTO TRUST_BENEFICIARY (TrustID, BeneficiaryID, SharePercentage)
VALUES (3002, 2003, 60);

INSERT INTO TRUST_BENEFICIARY (TrustID, BeneficiaryID, SharePercentage)
VALUES (3002, 2004, 40);

-- -----------------------------------------------------------------------------
-- ASSET Sample Data
-- -----------------------------------------------------------------------------

INSERT INTO ASSET (AssetID, TrustID, AssetName, AssetType, EstimatedValue, DateRegistered, Status)
VALUES (SEQ_ASSET.NEXTVAL, 3001, 'School Fees Fund 2026', 'CASH', 15000000, SYSDATE, 'AVAILABLE');

INSERT INTO ASSET (AssetID, TrustID, AssetName, AssetType, EstimatedValue, DateRegistered, Status)
VALUES (SEQ_ASSET.NEXTVAL, 3001, 'Fixed Deposit - Stanbic', 'CASH', 85000000, SYSDATE, 'AVAILABLE');

INSERT INTO ASSET (AssetID, TrustID, AssetName, AssetType, EstimatedValue, DateRegistered, Status)
VALUES (SEQ_ASSET.NEXTVAL, 3002, 'Kabale Coffee Land', 'LAND', 180000000, SYSDATE, 'AVAILABLE');

INSERT INTO ASSET (AssetID, TrustID, AssetName, AssetType, EstimatedValue, DateRegistered, Status)
VALUES (SEQ_ASSET.NEXTVAL, 3003, 'Atukwase Family Home', 'PROPERTY', 250000000, SYSDATE, 'AVAILABLE');

-- -----------------------------------------------------------------------------
-- DISTRIBUTION Sample Data
-- -----------------------------------------------------------------------------

INSERT INTO DISTRIBUTION (DistributionID, AssetID, BeneficiaryID, InitiatedByTrusteeID, AmountRequested, DateRequested, Status)
VALUES (SEQ_DISTRIBUTION.NEXTVAL, 4001, 2001, 1001, 5000000, SYSDATE, 'PENDING');

INSERT INTO DISTRIBUTION (DistributionID, AssetID, BeneficiaryID, InitiatedByTrusteeID, AmountRequested, DateRequested, Status)
VALUES (SEQ_DISTRIBUTION.NEXTVAL, 4003, 2004, 1002, 3000000, SYSDATE, 'PENDING');

-- -----------------------------------------------------------------------------
-- APPROVAL Sample Data
-- -----------------------------------------------------------------------------

-- Dist 5001 initiated by 1001 -> approvers 1002, 1003 (no self-approval)
INSERT INTO APPROVAL (ApprovalID, DistributionID, ApprovedByTrusteeID, ApprovalDate, Decision, DecisionNotes)
VALUES (SEQ_APPROVAL.NEXTVAL, 5001, 1002, SYSDATE, 'APPROVED', 'Tuition invoice reviewed.');

-- Second approval for distribution 5001
INSERT INTO APPROVAL (ApprovalID, DistributionID, ApprovedByTrusteeID, ApprovalDate, Decision, DecisionNotes)
VALUES (SEQ_APPROVAL.NEXTVAL, 5001, 1003, SYSDATE, 'APPROVED', 'Education purpose matches trust deed.');

-- Dist 5002 initiated by 1002 -> approvers 1001, 1003 (no self-approval)
INSERT INTO APPROVAL (ApprovalID, DistributionID, ApprovedByTrusteeID, ApprovalDate, Decision, DecisionNotes)
VALUES (SEQ_APPROVAL.NEXTVAL, 5002, 1001, SYSDATE, 'APPROVED', 'Accommodation support approved.');

-- Second approval for distribution 5002
INSERT INTO APPROVAL (ApprovalID, DistributionID, ApprovedByTrusteeID, ApprovalDate, Decision, DecisionNotes)
VALUES (SEQ_APPROVAL.NEXTVAL, 5002, 1003, SYSDATE, 'APPROVED', 'University support aligns with trust purpose.');
-- -----------------------------------------------------------------------------
-- ROLE Sample Data
-- -----------------------------------------------------------------------------

INSERT INTO ROLE (RoleID, RoleName, Description)
VALUES (SEQ_ROLE.NEXTVAL, 'ADMIN', 'Full system access and user management');

INSERT INTO ROLE (RoleID, RoleName, Description)
VALUES (SEQ_ROLE.NEXTVAL, 'TRUSTEE', 'Manage trusts and approve distributions');

INSERT INTO ROLE (RoleID, RoleName, Description)
VALUES (SEQ_ROLE.NEXTVAL, 'BENEFICIARY', 'Read-only access to own trust information');

INSERT INTO ROLE (RoleID, RoleName, Description)
VALUES (SEQ_ROLE.NEXTVAL, 'TRUSTOR', 'View own trusts, beneficiaries and distribution transactions');

INSERT INTO ROLE (RoleID, RoleName, Description)
VALUES (SEQ_ROLE.NEXTVAL, 'AUDITOR', 'Read-only access to all audit logs and reports');

-- -----------------------------------------------------------------------------
-- USER_ACCOUNT Sample Data
-- -----------------------------------------------------------------------------

INSERT INTO USER_ACCOUNT (UserID, Username, PasswordHash, RoleID, LinkedPersonID, LinkedPersonType, IsActive)
VALUES (SEQ_USER_ACCOUNT.NEXTVAL, 'grace.trustor', 
        LOWER(RAWTOHEX(STANDARD_HASH('TrustPass123', 'SHA256'))),
        (SELECT RoleID FROM ROLE WHERE RoleName = 'TRUSTOR'), 1, 'TRUSTOR', 1);

INSERT INTO USER_ACCOUNT (UserID, Username, PasswordHash, RoleID, LinkedPersonID, LinkedPersonType, IsActive)
VALUES (SEQ_USER_ACCOUNT.NEXTVAL, 'peter.trustee',
        LOWER(RAWTOHEX(STANDARD_HASH('TrustPass123', 'SHA256'))),
        8002, 1001, 'TRUSTEE', 1);

INSERT INTO USER_ACCOUNT (UserID, Username, PasswordHash, RoleID, LinkedPersonID, LinkedPersonType, IsActive)
VALUES (SEQ_USER_ACCOUNT.NEXTVAL, 'rose.trustee',
        LOWER(RAWTOHEX(STANDARD_HASH('TrustPass123', 'SHA256'))),
        8002, 1002, 'TRUSTEE', 1);

INSERT INTO USER_ACCOUNT (UserID, Username, PasswordHash, RoleID, LinkedPersonID, LinkedPersonType, IsActive)
VALUES (SEQ_USER_ACCOUNT.NEXTVAL, 'ivan.beneficiary',
        LOWER(RAWTOHEX(STANDARD_HASH('TrustPass123', 'SHA256'))),
        8003, 2001, 'BENEFICIARY', 1);

INSERT INTO USER_ACCOUNT (UserID, Username, PasswordHash, RoleID, LinkedPersonID, LinkedPersonType, IsActive)
VALUES (SEQ_USER_ACCOUNT.NEXTVAL, 'admin.urithi',
        LOWER(RAWTOHEX(STANDARD_HASH('AdminPass123', 'SHA256'))),
        8001, 1, 'ADMIN', 1);
        

-- -----------------------------------------------------------------------------
-- NOTIFICATION Sample Data
-- -----------------------------------------------------------------------------

INSERT INTO NOTIFICATION (NotificationID, UserID, NotificationType, Title, Message, RelatedTable, RelatedRecordID, Channel, IsRead, CreatedAt)
VALUES (SEQ_NOTIFICATION.NEXTVAL, 9002, 'APPROVAL_NEEDED', 'Approval Required',
        'A new distribution requires your approval.', 'DISTRIBUTION', 5001, 'SMS', 0, SYSTIMESTAMP);

INSERT INTO NOTIFICATION (NotificationID, UserID, NotificationType, Title, Message, RelatedTable, RelatedRecordID, Channel, IsRead, CreatedAt)
VALUES (SEQ_NOTIFICATION.NEXTVAL, 9004, 'DISTRIBUTION_EXECUTED', 'Distribution Approved',
        'Your distribution has been approved by two trustees.', 'DISTRIBUTION', 5001, 'SMS', 0, SYSTIMESTAMP);
-- -----------------------------------------------------------------------------
-- AUDIT_LOG Sample Data
-- -----------------------------------------------------------------------------

INSERT INTO AUDIT_LOG (LogID, UserID, ActionType, ActionDescription, TableAffected, RecordID, ActionTimestamp)
VALUES (SEQ_AUDIT_LOG.NEXTVAL, 9005, 'TRUST_CREATED', 'Trust 3001 created by admin', 'TRUST', 3001, SYSTIMESTAMP);

INSERT INTO AUDIT_LOG (LogID, UserID, ActionType, ActionDescription, TableAffected, RecordID, ActionTimestamp)
VALUES (SEQ_AUDIT_LOG.NEXTVAL, 9002, 'DISTRIBUTION_PROPOSED', 'Distribution 5001 proposed', 'DISTRIBUTION', 5001, SYSTIMESTAMP);

COMMIT;


SELECT table_name FROM user_tables ORDER BY table_name;

PROMPT --- Sequences Created ---
SELECT sequence_name FROM user_sequences ORDER BY sequence_name;

PROMPT --- Triggers Created ---
SELECT trigger_name FROM user_triggers ORDER BY trigger_name;

PROMPT --- Sample Data Counts ---
SELECT 'TRUSTOR Count: ' || COUNT(*) FROM TRUSTOR;
SELECT 'TRUSTEE Count: ' || COUNT(*) FROM TRUSTEE;
SELECT 'BENEFICIARY Count: ' || COUNT(*) FROM BENEFICIARY;
SELECT 'TRUST Count: ' || COUNT(*) FROM TRUST;
SELECT 'TRUST_TRUSTEE Count: ' || COUNT(*) FROM TRUST_TRUSTEE;
SELECT 'TRUST_BENEFICIARY Count: ' || COUNT(*) FROM TRUST_BENEFICIARY;
SELECT 'ASSET Count: ' || COUNT(*) FROM ASSET;
SELECT 'DISTRIBUTION Count: ' || COUNT(*) FROM DISTRIBUTION;
SELECT 'APPROVAL Count: ' || COUNT(*) FROM APPROVAL;
SELECT 'USER_ACCOUNT Count: ' || COUNT(*) FROM USER_ACCOUNT;
SELECT 'NOTIFICATION Count: ' || COUNT(*) FROM NOTIFICATION;
SELECT 'AUDIT_LOG Count: ' || COUNT(*) FROM AUDIT_LOG;

PROMPT --- VW_TRUST_SUMMARY ---
SELECT * FROM VW_TRUST_SUMMARY;

PROMPT --- VW_PENDING_DISTRIBUTIONS ---
SELECT * FROM VW_PENDING_DISTRIBUTIONS;

PROMPT --- FUNC_GET_TRUST_BALANCE Test ---
SELECT FUNC_GET_TRUST_BALANCE(3001) AS TrustBalance FROM DUAL;

PROMPT --- PKG_TRUST_MGMT Test ---
BEGIN
    PKG_TRUST_MGMT.flag_unassigned_trusts(9005);
END;
/

PROMPT
PROMPT =========================================================================
PROMPT URITHI Database is ready for use!
PROMPT =========================================================================

COMMIT;




-- =============================================================================
-- URITHI TABLE ENHANCEMENTS
-- Adding Images, Location, and Document Support
-- =============================================================================

SET SERVEROUTPUT ON;

PROMPT =========================================================================
PROMPT Adding new columns to URITHI tables...
PROMPT =========================================================================

-- =============================================================================
-- 1. TRUSTOR Table - Add Profile Photo and Location
-- =============================================================================

ALTER TABLE TRUSTOR ADD (
    ProfilePhoto BLOB,
    ProfilePhotoMimeType VARCHAR2(100),
    ProfilePhotoFileName VARCHAR2(255),
    LocationAddress VARCHAR2(300),
    LocationCity VARCHAR2(100),
    LocationDistrict VARCHAR2(100)
);

COMMENT ON COLUMN TRUSTOR.ProfilePhoto IS 'Profile photo of the trustor';
COMMENT ON COLUMN TRUSTOR.ProfilePhotoMimeType IS 'MIME type of the profile photo';
COMMENT ON COLUMN TRUSTOR.ProfilePhotoFileName IS 'Original filename of the profile photo';
COMMENT ON COLUMN TRUSTOR.LocationAddress IS 'Physical address of the trustor';
COMMENT ON COLUMN TRUSTOR.LocationCity IS 'City of the trustor';
COMMENT ON COLUMN TRUSTOR.LocationDistrict IS 'District of the trustor';

PROMPT TRUSTOR table updated successfully.

-- =============================================================================
-- 2. TRUSTEE Table - Add Profile Photo and Location
-- =============================================================================

ALTER TABLE TRUSTEE ADD (
    ProfilePhoto BLOB,
    ProfilePhotoMimeType VARCHAR2(100),
    ProfilePhotoFileName VARCHAR2(255),
    LocationAddress VARCHAR2(300),
    LocationCity VARCHAR2(100),
    LocationDistrict VARCHAR2(100)
);

COMMENT ON COLUMN TRUSTEE.ProfilePhoto IS 'Profile photo of the trustee';
COMMENT ON COLUMN TRUSTEE.ProfilePhotoMimeType IS 'MIME type of the profile photo';
COMMENT ON COLUMN TRUSTEE.ProfilePhotoFileName IS 'Original filename of the profile photo';
COMMENT ON COLUMN TRUSTEE.LocationAddress IS 'Physical address of the trustee';
COMMENT ON COLUMN TRUSTEE.LocationCity IS 'City of the trustee';
COMMENT ON COLUMN TRUSTEE.LocationDistrict IS 'District of the trustee';

PROMPT TRUSTEE table updated successfully.

-- =============================================================================
-- 3. BENEFICIARY Table - Add Profile Photo and Location
-- =============================================================================

ALTER TABLE BENEFICIARY ADD (
    ProfilePhoto BLOB,
    ProfilePhotoMimeType VARCHAR2(100),
    ProfilePhotoFileName VARCHAR2(255),
    LocationAddress VARCHAR2(300),
    LocationCity VARCHAR2(100),
    LocationDistrict VARCHAR2(100)
);

COMMENT ON COLUMN BENEFICIARY.ProfilePhoto IS 'Profile photo of the beneficiary';
COMMENT ON COLUMN BENEFICIARY.ProfilePhotoMimeType IS 'MIME type of the profile photo';
COMMENT ON COLUMN BENEFICIARY.ProfilePhotoFileName IS 'Original filename of the profile photo';
COMMENT ON COLUMN BENEFICIARY.LocationAddress IS 'Physical address of the beneficiary';
COMMENT ON COLUMN BENEFICIARY.LocationCity IS 'City of the beneficiary';
COMMENT ON COLUMN BENEFICIARY.LocationDistrict IS 'District of the beneficiary';

PROMPT BENEFICIARY table updated successfully.

-- =============================================================================
-- 4. ASSET Table - Add Image, Location, and GPS Coordinates
-- =============================================================================

ALTER TABLE ASSET ADD (
    AssetImage BLOB,
    AssetImageMimeType VARCHAR2(100),
    AssetImageFileName VARCHAR2(255),
    LocationAddress VARCHAR2(300),
    LocationCity VARCHAR2(100),
    LocationDistrict VARCHAR2(100),
    LocationCountry VARCHAR2(50) DEFAULT 'Uganda',
    Latitude NUMBER(10,8),
    Longitude NUMBER(11,8)
);

COMMENT ON COLUMN ASSET.AssetImage IS 'Photo of the asset (property, land, vehicle, etc.)';
COMMENT ON COLUMN ASSET.AssetImageMimeType IS 'MIME type of the asset image';
COMMENT ON COLUMN ASSET.AssetImageFileName IS 'Original filename of the asset image';
COMMENT ON COLUMN ASSET.LocationAddress IS 'Physical address of the asset';
COMMENT ON COLUMN ASSET.LocationCity IS 'City where the asset is located';
COMMENT ON COLUMN ASSET.LocationDistrict IS 'District where the asset is located';
COMMENT ON COLUMN ASSET.LocationCountry IS 'Country where the asset is located';
COMMENT ON COLUMN ASSET.Latitude IS 'GPS latitude coordinate of the asset';
COMMENT ON COLUMN ASSET.Longitude IS 'GPS longitude coordinate of the asset';

PROMPT ASSET table updated successfully.

-- =============================================================================
-- 5. TRUST Table - Add Trust Deed Document Upload
-- =============================================================================

ALTER TABLE TRUST ADD (
    TrustDeedDocument BLOB,
    TrustDeedFileName VARCHAR2(255),
    TrustDeedMimeType VARCHAR2(100)
);

COMMENT ON COLUMN TRUST.TrustDeedDocument IS 'PDF of the signed trust deed document';
COMMENT ON COLUMN TRUST.TrustDeedFileName IS 'Original filename of the trust deed';
COMMENT ON COLUMN TRUST.TrustDeedMimeType IS 'MIME type of the trust deed document';

PROMPT TRUST table updated successfully.

-- =============================================================================
-- 6. DISTRIBUTION Table - Add Payment Receipt Upload
-- =============================================================================

ALTER TABLE DISTRIBUTION ADD (
    PaymentReceipt BLOB,
    PaymentReceiptFileName VARCHAR2(255),
    PaymentReceiptMimeType VARCHAR2(100)
);

COMMENT ON COLUMN DISTRIBUTION.PaymentReceipt IS 'Proof of payment receipt (scan/photo)';
COMMENT ON COLUMN DISTRIBUTION.PaymentReceiptFileName IS 'Original filename of the payment receipt';
COMMENT ON COLUMN DISTRIBUTION.PaymentReceiptMimeType IS 'MIME type of the payment receipt';

PROMPT DISTRIBUTION table updated successfully.

-- =============================================================================
-- 7. ADD NEW TABLE: TRUST_DOCUMENT (For additional documents)
-- =============================================================================

CREATE SEQUENCE SEQ_TRUST_DOCUMENT START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE TABLE TRUST_DOCUMENT (
    DocumentID NUMBER(10) CONSTRAINT PK_TRUST_DOCUMENT PRIMARY KEY,
    TrustID NUMBER(10) CONSTRAINT FK_DOC_TRUST REFERENCES TRUST(TrustID) NOT NULL,
    DocumentName VARCHAR2(200) NOT NULL,
    DocumentType VARCHAR2(50),
    DocumentFile BLOB,
    FileName VARCHAR2(255),
    MimeType VARCHAR2(100),
    UploadedBy NUMBER(10) CONSTRAINT FK_DOC_USER REFERENCES USER_ACCOUNT(UserID),
    UploadDate TIMESTAMP DEFAULT SYSTIMESTAMP,
    DocumentDescription VARCHAR2(500),
    CONSTRAINT CK_DOC_TYPE CHECK (DocumentType IN ('TRUST_DEED', 'LAND_TITLE', 'VALUATION', 'TAX_RETURN', 'LEGAL', 'OTHER'))
);

COMMENT ON TABLE TRUST_DOCUMENT IS 'Stores additional trust-related documents';
COMMENT ON COLUMN TRUST_DOCUMENT.DocumentID IS 'Primary key for document';
COMMENT ON COLUMN TRUST_DOCUMENT.TrustID IS 'Reference to the trust';
COMMENT ON COLUMN TRUST_DOCUMENT.DocumentName IS 'Name of the document';
COMMENT ON COLUMN TRUST_DOCUMENT.DocumentType IS 'Type of document (TRUST_DEED, LAND_TITLE, etc.)';
COMMENT ON COLUMN TRUST_DOCUMENT.DocumentFile IS 'The actual document file';
COMMENT ON COLUMN TRUST_DOCUMENT.UploadedBy IS 'User who uploaded the document';
COMMENT ON COLUMN TRUST_DOCUMENT.UploadDate IS 'Date and time of upload';

-- Create index for performance
CREATE INDEX IDX_DOC_TRUSTID ON TRUST_DOCUMENT(TrustID);
CREATE INDEX IDX_DOC_UPLOADEDBY ON TRUST_DOCUMENT(UploadedBy);
CREATE INDEX IDX_DOC_TYPE ON TRUST_DOCUMENT(DocumentType);

PROMPT TRUST_DOCUMENT table created successfully.

-- =============================================================================
-- 8. ADD NEW TABLE: MESSAGE (For communication between users)
-- =============================================================================

CREATE SEQUENCE SEQ_MESSAGE START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE TABLE MESSAGE (
    MessageID NUMBER(10) CONSTRAINT PK_MESSAGE PRIMARY KEY,
    SenderID NUMBER(10) CONSTRAINT FK_MSG_SENDER REFERENCES USER_ACCOUNT(UserID) NOT NULL,
    ReceiverID NUMBER(10) CONSTRAINT FK_MSG_RECEIVER REFERENCES USER_ACCOUNT(UserID) NOT NULL,
    Subject VARCHAR2(200),
    MessageText VARCHAR2(4000) NOT NULL,
    SentDate TIMESTAMP DEFAULT SYSTIMESTAMP,
    IsRead NUMBER(1) DEFAULT 0 CONSTRAINT CK_MSG_READ CHECK (IsRead IN (0,1)),
    IsDeletedBySender NUMBER(1) DEFAULT 0 CONSTRAINT CK_MSG_DEL_SENDER CHECK (IsDeletedBySender IN (0,1)),
    IsDeletedByReceiver NUMBER(1) DEFAULT 0 CONSTRAINT CK_MSG_DEL_RECEIVER CHECK (IsDeletedByReceiver IN (0,1)),
    RelatedTrustID NUMBER(10) CONSTRAINT FK_MSG_TRUST REFERENCES TRUST(TrustID)
);

COMMENT ON TABLE MESSAGE IS 'Internal messaging between users';
COMMENT ON COLUMN MESSAGE.MessageID IS 'Primary key for message';
COMMENT ON COLUMN MESSAGE.SenderID IS 'User who sent the message';
COMMENT ON COLUMN MESSAGE.ReceiverID IS 'User who received the message';
COMMENT ON COLUMN MESSAGE.Subject IS 'Subject of the message';
COMMENT ON COLUMN MESSAGE.MessageText IS 'Message content';
COMMENT ON COLUMN MESSAGE.SentDate IS 'Date and time message was sent';
COMMENT ON COLUMN MESSAGE.IsRead IS '1 if message has been read';
COMMENT ON COLUMN MESSAGE.RelatedTrustID IS 'Optional reference to a specific trust';

-- Create indexes for performance
CREATE INDEX IDX_MSG_SENDER ON MESSAGE(SenderID);
CREATE INDEX IDX_MSG_RECEIVER ON MESSAGE(ReceiverID);
CREATE INDEX IDX_MSG_TRUST ON MESSAGE(RelatedTrustID);
CREATE INDEX IDX_MSG_SENTDATE ON MESSAGE(SentDate);

PROMPT MESSAGE table created successfully.

-- =============================================================================
-- 9. ADD NEW TABLE: TASK (For tasks and to-do items)
-- =============================================================================

CREATE SEQUENCE SEQ_TASK START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE TABLE TASK (
    TaskID NUMBER(10) CONSTRAINT PK_TASK PRIMARY KEY,
    TrustID NUMBER(10) CONSTRAINT FK_TASK_TRUST REFERENCES TRUST(TrustID),
    AssignedTo NUMBER(10) CONSTRAINT FK_TASK_USER REFERENCES USER_ACCOUNT(UserID) NOT NULL,
    CreatedBy NUMBER(10) CONSTRAINT FK_TASK_CREATOR REFERENCES USER_ACCOUNT(UserID) NOT NULL,
    TaskTitle VARCHAR2(200) NOT NULL,
    TaskDescription VARCHAR2(1000),
    TaskType VARCHAR2(30) CONSTRAINT CK_TASK_TYPE CHECK (TaskType IN ('DISTRIBUTION', 'DOCUMENT', 'REVIEW', 'MEETING', 'OTHER')),
    Priority VARCHAR2(15) CONSTRAINT CK_TASK_PRIORITY CHECK (Priority IN ('LOW', 'MEDIUM', 'HIGH', 'URGENT')),
    Status VARCHAR2(15) DEFAULT 'PENDING' CONSTRAINT CK_TASK_STATUS CHECK (Status IN ('PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    DueDate DATE,
    CompletedDate DATE,
    CreatedDate TIMESTAMP DEFAULT SYSTIMESTAMP,
    UpdatedDate TIMESTAMP DEFAULT SYSTIMESTAMP
);

COMMENT ON TABLE TASK IS 'Tasks and to-do items related to trust management';
COMMENT ON COLUMN TASK.TaskID IS 'Primary key for task';
COMMENT ON COLUMN TASK.TrustID IS 'Reference to the related trust';
COMMENT ON COLUMN TASK.AssignedTo IS 'User assigned to the task';
COMMENT ON COLUMN TASK.CreatedBy IS 'User who created the task';
COMMENT ON COLUMN TASK.TaskTitle IS 'Title of the task';
COMMENT ON COLUMN TASK.TaskType IS 'Type of task (DISTRIBUTION, DOCUMENT, REVIEW, etc.)';
COMMENT ON COLUMN TASK.Priority IS 'Task priority (LOW, MEDIUM, HIGH, URGENT)';
COMMENT ON COLUMN TASK.Status IS 'Task status (PENDING, IN_PROGRESS, COMPLETED, CANCELLED)';

-- Create indexes for performance
CREATE INDEX IDX_TASK_TRUST ON TASK(TrustID);
CREATE INDEX IDX_TASK_ASSIGNEDTO ON TASK(AssignedTo);
CREATE INDEX IDX_TASK_STATUS ON TASK(Status);
CREATE INDEX IDX_TASK_DUEDATE ON TASK(DueDate);

PROMPT TASK table created successfully.

-- =============================================================================
-- VERIFICATION
-- =============================================================================

PROMPT =========================================================================
PROMPT VERIFICATION - Checking all tables and columns
PROMPT =========================================================================

-- Check columns added to TRUSTOR
SELECT column_name, data_type 
FROM user_tab_columns 
WHERE table_name = 'TRUSTOR' 
AND column_name IN ('PROFILEPHOTO', 'PROFILEPHOTOMIMETYPE', 'PROFILEPHOTOFILENAME', 
                    'LOCATIONADDRESS', 'LOCATIONCITY', 'LOCATIONDISTRICT')
ORDER BY column_name;

-- Check columns added to ASSET
SELECT column_name, data_type 
FROM user_tab_columns 
WHERE table_name = 'ASSET' 
AND column_name IN ('ASSETIMAGE', 'ASSETIMAGEMIMETYPE', 'ASSETIMAGEFILENAME',
                    'LOCATIONADDRESS', 'LOCATIONCITY', 'LOCATIONDISTRICT', 
                    'LOCATIONCOUNTRY', 'LATITUDE', 'LONGITUDE')
ORDER BY column_name;

-- Check new tables
SELECT table_name FROM user_tables 
WHERE table_name IN ('TRUST_DOCUMENT', 'MESSAGE', 'TASK')
ORDER BY table_name;

-- Check sequences
SELECT sequence_name FROM user_sequences 
WHERE sequence_name IN ('SEQ_TRUST_DOCUMENT', 'SEQ_MESSAGE', 'SEQ_TASK')
ORDER BY sequence_name;

PROMPT =========================================================================
PROMPT All enhancements completed successfully!
PROMPT =========================================================================

COMMIT;


-- =============================================================================
-- AUDITOR DEMO USER (auditor.urithi)
-- AUDITOR role is already inserted above via SEQ_ROLE (RoleID 8005).
-- This block only ensures the user exists. Idempotent. Uses ROLE.Description column only.
-- STANDARD_HASH via SELECT ... FROM DUAL (required in PL/SQL).
-- =============================================================================
PROMPT === Ensuring auditor.urithi demo user ===
DECLARE
  v_role_id   ROLE.RoleID%TYPE;
  v_user_id   USER_ACCOUNT.UserID%TYPE;
  v_pwd_hash  USER_ACCOUNT.PasswordHash%TYPE;
BEGIN
  SELECT LOWER(RAWTOHEX(STANDARD_HASH('AuditPass123', 'SHA256')))
    INTO v_pwd_hash
    FROM DUAL;

  SELECT RoleID INTO v_role_id FROM ROLE WHERE RoleName = 'AUDITOR';

  BEGIN
    SELECT UserID INTO v_user_id
      FROM USER_ACCOUNT
     WHERE UPPER(Username) = 'AUDITOR.URITHI';

    UPDATE USER_ACCOUNT
       SET RoleID           = v_role_id,
           LinkedPersonType = 'ADMIN',
           LinkedPersonID   = 1,
           IsActive         = 1,
           PasswordHash     = v_pwd_hash
     WHERE UserID = v_user_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      SELECT NVL(MAX(UserID), 0) + 1 INTO v_user_id FROM USER_ACCOUNT;
      INSERT INTO USER_ACCOUNT (
        UserID, Username, PasswordHash, RoleID,
        LinkedPersonID, LinkedPersonType, IsActive
      ) VALUES (
        v_user_id, 'auditor.urithi', v_pwd_hash, v_role_id,
        1, 'ADMIN', 1
      );
  END;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('auditor.urithi ready (UserID=' || v_user_id
                       || ' RoleID=' || v_role_id || ')');
  DBMS_OUTPUT.PUT_LINE('Login: auditor.urithi / AuditPass123');
END;