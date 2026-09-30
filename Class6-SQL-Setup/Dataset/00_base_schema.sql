-- Meridian Retail FDE Programme
-- Class 6-7 baseline schema: five tables carried forward from Class 5
-- Target: MySQL 8.0.18+
-- This script intentionally resets the meridian_retail classroom database.

DROP DATABASE IF EXISTS meridian_retail;

CREATE DATABASE meridian_retail
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE meridian_retail;

CREATE TABLE validation_rules (
    rule_id              VARCHAR(10)  NOT NULL,
    applies_to_file      VARCHAR(50)  NOT NULL,
    field_name           VARCHAR(50)  NULL,
    rule_type            VARCHAR(30)  NOT NULL,
    condition_text       TEXT         NOT NULL,
    failure_route        VARCHAR(20)  NOT NULL,
    reason               TEXT         NOT NULL,
    enabled              BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_validation_rules PRIMARY KEY (rule_id),
    CONSTRAINT chk_validation_route
        CHECK (failure_route IN ('REJECT', 'HUMAN_REVIEW', 'PAUSE_LOAD', 'LOAD_WARNING'))
) ENGINE = InnoDB;

CREATE TABLE orders (
    order_id             VARCHAR(12)  NOT NULL,
    product              VARCHAR(100) NOT NULL,
    order_date           DATE         NOT NULL,
    delivery_date        DATE         NULL,
    payment_status       VARCHAR(20)  NOT NULL,
    extract_generated_at DATETIME     NOT NULL,
    CONSTRAINT pk_orders PRIMARY KEY (order_id),
    CONSTRAINT chk_orders_payment_status
        CHECK (payment_status IN ('PAID', 'PENDING', 'FAILED', 'REFUNDED')),
    CONSTRAINT chk_orders_delivery_date
        CHECK (delivery_date IS NULL OR delivery_date >= order_date)
) ENGINE = InnoDB;

/*
CREATE TABLE support_cases (
    case_id              VARCHAR(12)  NOT NULL,
    order_id             VARCHAR(12)  NULL,
    received_at          DATETIME     NOT NULL,
    customer_question    TEXT         NOT NULL,
    case_type            VARCHAR(20)  NOT NULL,
    review_status        VARCHAR(20)  NOT NULL,
    extract_generated_at DATETIME     NOT NULL,
    CONSTRAINT pk_support_cases PRIMARY KEY (case_id),
    CONSTRAINT fk_support_cases_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_support_case_type
        CHECK (case_type IN ('RETURN', 'DAMAGE', 'DELIVERY', 'BILLING', 'GENERAL')),
    CONSTRAINT chk_support_review_status
        CHECK (review_status IN ('PENDING', 'APPROVED', 'REJECTED')),
    CONSTRAINT chk_purchase_case_has_order
        CHECK (case_type NOT IN ('RETURN', 'DAMAGE') OR order_id IS NOT NULL)
) ENGINE = InnoDB;
*/
#removed the check constraint chk_purchase_case_has_order - because it is also referred in an fk constraint which mysql doesn't support

CREATE TABLE support_cases (
    case_id              VARCHAR(12)  NOT NULL,
    order_id             VARCHAR(12)  NULL,
    received_at          DATETIME     NOT NULL,
    customer_question    TEXT         NOT NULL,
    case_type            VARCHAR(20)  NOT NULL,
    review_status        VARCHAR(20)  NOT NULL,
    extract_generated_at DATETIME     NOT NULL,
    CONSTRAINT pk_support_cases PRIMARY KEY (case_id),
    CONSTRAINT fk_support_cases_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_support_case_type
        CHECK (case_type IN ('RETURN', 'DAMAGE', 'DELIVERY', 'BILLING', 'GENERAL')),
    CONSTRAINT chk_support_review_status
        CHECK (review_status IN ('PENDING', 'APPROVED', 'REJECTED'))
) ENGINE = InnoDB;


CREATE TABLE issue_records (
    case_id               VARCHAR(12) NOT NULL,
    issue_type            VARCHAR(30) NOT NULL,
    issue_details         TEXT        NOT NULL,
    reported_delivery_date DATE       NULL,
    evidence_status       VARCHAR(20) NOT NULL,
    extract_generated_at  DATETIME    NOT NULL,
    CONSTRAINT pk_issue_records PRIMARY KEY (case_id),
    CONSTRAINT fk_issue_records_case
        FOREIGN KEY (case_id) REFERENCES support_cases (case_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_issue_evidence_status
        CHECK (evidence_status IN ('VERIFIED', 'PENDING_PROOF', 'NOT_REQUIRED', 'CONFLICTING'))
) ENGINE = InnoDB;

CREATE TABLE human_reviews (
    review_id             VARCHAR(14) NOT NULL,
    case_id               VARCHAR(12) NOT NULL,
    triggered_rule_id     VARCHAR(10) NULL,
    reviewer_role         VARCHAR(50) NOT NULL,
    decision              VARCHAR(30) NOT NULL,
    decision_reason       TEXT        NOT NULL,
    reviewed_at           DATETIME    NOT NULL,
    handling_minutes      SMALLINT UNSIGNED NULL,
    extract_generated_at  DATETIME    NOT NULL,
    CONSTRAINT pk_human_reviews PRIMARY KEY (review_id),
    CONSTRAINT fk_human_reviews_case
        FOREIGN KEY (case_id) REFERENCES support_cases (case_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_human_reviews_rule
        FOREIGN KEY (triggered_rule_id) REFERENCES validation_rules (rule_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_human_review_decision
        CHECK (decision IN ('APPROVED', 'REJECTED', 'NEEDS_INFO', 'ESCALATED')),
    CONSTRAINT chk_human_review_minutes
        CHECK (handling_minutes IS NULL OR handling_minutes BETWEEN 1 AND 1440)
) ENGINE = InnoDB;
