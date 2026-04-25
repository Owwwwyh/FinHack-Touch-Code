-- TNG OfflinePay: Initial RDS schema migration
-- Per docs/09-data-model.md §3

CREATE DATABASE IF NOT EXISTS tng_history CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE tng_history;

-- Settled transactions (OLTP-friendly view from DynamoDB ledger)
CREATE TABLE IF NOT EXISTS settled_transactions (
  tx_id           CHAR(26) PRIMARY KEY,
  sender_user_id  VARCHAR(64) NOT NULL,
  receiver_user_id VARCHAR(64) NOT NULL,
  amount_cents    BIGINT NOT NULL,
  currency        CHAR(3) NOT NULL DEFAULT 'MYR',
  iat             INT UNSIGNED NOT NULL,
  settled_at      DATETIME NOT NULL,
  policy_version  VARCHAR(32) NOT NULL,
  status          ENUM('SETTLED','DISPUTED','REVERSED') NOT NULL DEFAULT 'SETTLED',
  INDEX idx_sender (sender_user_id, settled_at),
  INDEX idx_receiver (receiver_user_id, settled_at),
  INDEX idx_settled (settled_at)
) ENGINE=InnoDB;

-- Merchants
CREATE TABLE IF NOT EXISTS merchants (
  merchant_id     CHAR(26) PRIMARY KEY,
  business_name   VARCHAR(200) NOT NULL,
  business_id     VARCHAR(64),
  user_id         VARCHAR(64) NOT NULL,
  onboarded_at    DATETIME NOT NULL,
  status          ENUM('ACTIVE','SUSPENDED') DEFAULT 'ACTIVE',
  UNIQUE KEY uniq_user (user_id)
) ENGINE=InnoDB;

-- KYC records
CREATE TABLE IF NOT EXISTS kyc_records (
  user_id         VARCHAR(64) PRIMARY KEY,
  tier            TINYINT NOT NULL DEFAULT 0,
  full_name       VARCHAR(200),
  ic_last4        CHAR(4),
  doc_ref         VARCHAR(64),
  verified_at     DATETIME
) ENGINE=InnoDB;

-- Disputes
CREATE TABLE IF NOT EXISTS disputes (
  dispute_id      CHAR(26) PRIMARY KEY,
  tx_id           CHAR(26) NOT NULL,
  reason_code     ENUM('UNAUTHORIZED','WRONG_AMOUNT','NOT_RECEIVED','OTHER') NOT NULL,
  details         TEXT,
  status          ENUM('RECEIVED','UNDER_REVIEW','RESOLVED','REJECTED') NOT NULL DEFAULT 'RECEIVED',
  raised_by       VARCHAR(64) NOT NULL,
  raised_at       DATETIME NOT NULL,
  resolved_at     DATETIME,
  INDEX idx_tx (tx_id)
) ENGINE=InnoDB;
