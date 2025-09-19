;; title: recall-manager
;; version: 1.0.0
;; summary: Recall Manager Contract for tracking medicine recalls and safety alerts
;; description: This contract manages medicine recall processes, including issuance,
;;              categorization, and status tracking of recalled products.

;; constants
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_RECALL_NOT_FOUND (err u201))
(define-constant ERR_RECALL_EXISTS (err u202))
(define-constant ERR_INVALID_SEVERITY (err u203))
(define-constant ERR_INVALID_BATCH (err u204))
(define-constant ERR_INVALID_REASON (err u205))
(define-constant ERR_RECALL_ALREADY_RESOLVED (err u206))
(define-constant ERR_INVALID_STATUS (err u207))
(define-constant ERR_EMPTY_BATCH_LIST (err u208))

(define-constant CONTRACT_OWNER tx-sender)
(define-constant MAX_REASON_LENGTH u500)
(define-constant MAX_BATCH_NUMBER_LENGTH u50)

;; Recall severity levels
(define-constant SEVERITY_LOW u1)
(define-constant SEVERITY_MEDIUM u2)
(define-constant SEVERITY_HIGH u3)
(define-constant SEVERITY_CRITICAL u4)

;; Recall status values
(define-constant STATUS_ISSUED u1)
(define-constant STATUS_IN_PROGRESS u2)
(define-constant STATUS_RESOLVED u3)
(define-constant STATUS_CANCELLED u4)

;; data vars
(define-data-var recall-counter uint u0)
(define-data-var contract-enabled bool true)
(define-data-var emergency-mode bool false)

;; data maps
(define-map recalls
  { recall-id: uint }
  {
    batch-number: (string-ascii 50),
    medicine-name: (string-ascii 100),
    reason: (string-ascii 500),
    severity: uint,
    status: uint,
    issued-by: principal,
    issued-at: uint,
    resolved-at: uint,
    affected-quantity: uint,
    is-emergency: bool
  }
)

(define-map batch-recalls
  { batch-number: (string-ascii 50) }
  { recall-id: uint, is-recalled: bool }
)

(define-map recall-authorities
  { authority: principal }
  { authorized: bool, authorized-at: uint, authorized-by: principal }
)

(define-map recall-notifications
  { recall-id: uint, notification-id: uint }
  {
    recipient: principal,
    sent-at: uint,
    acknowledged: bool,
    acknowledged-at: uint
  }
)

(define-map recall-updates
  { recall-id: uint, update-id: uint }
  {
    update-message: (string-ascii 200),
    updated-by: principal,
    updated-at: uint,
    new-status: uint
  }
)

;; private functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (is-authorized-authority (authority principal))
  (default-to false 
    (get authorized (map-get? recall-authorities { authority: authority }))
  )
)

(define-private (is-valid-severity (severity uint))
  (and (>= severity SEVERITY_LOW) (<= severity SEVERITY_CRITICAL))
)

(define-private (is-valid-status (status uint))
  (and (>= status STATUS_ISSUED) (<= status STATUS_CANCELLED))
)

(define-private (increment-recall-counter)
  (let ((current-counter (var-get recall-counter)))
    (var-set recall-counter (+ current-counter u1))
    current-counter
  )
)

(define-private (can-modify-recall (recall-data (tuple (batch-number (string-ascii 50)) (medicine-name (string-ascii 100)) (reason (string-ascii 500)) (severity uint) (status uint) (issued-by principal) (issued-at uint) (resolved-at uint) (affected-quantity uint) (is-emergency bool))))
  (or 
    (is-contract-owner)
    (is-eq tx-sender (get issued-by recall-data))
    (is-authorized-authority tx-sender)
  )
)

;; public functions
(define-public (authorize-recall-authority (authority principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (var-get contract-enabled) ERR_UNAUTHORIZED)
    (map-set recall-authorities
      { authority: authority }
      {
        authorized: true,
        authorized-at: stacks-block-height,
        authorized-by: tx-sender
      }
    )
    (ok true)
  )
)

(define-public (revoke-recall-authority (authority principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (map-set recall-authorities
      { authority: authority }
      {
        authorized: false,
        authorized-at: stacks-block-height,
        authorized-by: tx-sender
      }
    )
    (ok true)
  )
)

(define-public (issue-recall
    (batch-number (string-ascii 50))
    (medicine-name (string-ascii 100))
    (reason (string-ascii 500))
    (severity uint)
    (affected-quantity uint)
    (is-emergency bool)
  )
  (let
    (
      (recall-id (increment-recall-counter))
      (existing-recall (map-get? batch-recalls { batch-number: batch-number }))
    )
    (asserts! (or (is-contract-owner) (is-authorized-authority tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (var-get contract-enabled) ERR_UNAUTHORIZED)
    (asserts! (> (len batch-number) u0) ERR_INVALID_BATCH)
    (asserts! (> (len reason) u0) ERR_INVALID_REASON)
    (asserts! (<= (len reason) MAX_REASON_LENGTH) ERR_INVALID_REASON)
    (asserts! (is-valid-severity severity) ERR_INVALID_SEVERITY)
    (asserts! (> affected-quantity u0) ERR_INVALID_BATCH)
    (asserts! (is-none existing-recall) ERR_RECALL_EXISTS)
    
    ;; Set emergency mode if critical recall
    (if is-emergency
      (var-set emergency-mode true)
      true
    )
    
    (map-set recalls
      { recall-id: recall-id }
      {
        batch-number: batch-number,
        medicine-name: medicine-name,
        reason: reason,
        severity: severity,
        status: STATUS_ISSUED,
        issued-by: tx-sender,
        issued-at: stacks-block-height,
        resolved-at: u0,
        affected-quantity: affected-quantity,
        is-emergency: is-emergency
      }
    )
    
    (map-set batch-recalls
      { batch-number: batch-number }
      { recall-id: recall-id, is-recalled: true }
    )
    
    (ok recall-id)
  )
)

(define-public (update-recall-status
    (recall-id uint)
    (new-status uint)
    (update-message (string-ascii 200))
  )
  (let
    (
      (recall (map-get? recalls { recall-id: recall-id }))
    )
    (asserts! (is-some recall) ERR_RECALL_NOT_FOUND)
    (asserts! (can-modify-recall (unwrap-panic recall)) ERR_UNAUTHORIZED)
    (asserts! (is-valid-status new-status) ERR_INVALID_STATUS)
    (asserts! (not (is-eq (get status (unwrap-panic recall)) STATUS_RESOLVED)) ERR_RECALL_ALREADY_RESOLVED)
    
    (let
      (
        (updated-recall (merge (unwrap-panic recall) 
          {
            status: new-status,
            resolved-at: (if (is-eq new-status STATUS_RESOLVED) stacks-block-height u0)
          }))
      )
      (map-set recalls
        { recall-id: recall-id }
        updated-recall
      )
      
      ;; Add update record
      (map-set recall-updates
        { recall-id: recall-id, update-id: stacks-block-height }
        {
          update-message: update-message,
          updated-by: tx-sender,
          updated-at: stacks-block-height,
          new-status: new-status
        }
      )
      
      ;; If resolved, clear emergency mode check
      (if (is-eq new-status STATUS_RESOLVED)
        (var-set emergency-mode false)
        true
      )
      
      (ok true)
    )
  )
)

(define-public (bulk-recall-batches
    (batch-numbers (list 10 (string-ascii 50)))
    (medicine-name (string-ascii 100))
    (reason (string-ascii 500))
    (severity uint)
    (is-emergency bool)
  )
  (let
    (
      (batch-count (len batch-numbers))
    )
    (asserts! (or (is-contract-owner) (is-authorized-authority tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (> batch-count u0) ERR_EMPTY_BATCH_LIST)
    (asserts! (is-valid-severity severity) ERR_INVALID_SEVERITY)
    
    ;; Process each batch (simplified - in real implementation would use fold)
    (ok batch-count)
  )
)

(define-public (resolve-recall (recall-id uint))
  (update-recall-status recall-id STATUS_RESOLVED "Recall resolved")
)

(define-public (cancel-recall (recall-id uint))
  (update-recall-status recall-id STATUS_CANCELLED "Recall cancelled")
)

(define-public (toggle-contract (enabled bool))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-enabled enabled)
    (ok enabled)
  )
)

(define-public (set-emergency-mode (enabled bool))
  (begin
    (asserts! (or (is-contract-owner) (is-authorized-authority tx-sender)) ERR_UNAUTHORIZED)
    (var-set emergency-mode enabled)
    (ok enabled)
  )
)

;; read only functions
(define-read-only (get-recall (recall-id uint))
  (map-get? recalls { recall-id: recall-id })
)

(define-read-only (get-batch-recall-status (batch-number (string-ascii 50)))
  (map-get? batch-recalls { batch-number: batch-number })
)

(define-read-only (is-batch-recalled (batch-number (string-ascii 50)))
  (match (get-batch-recall-status batch-number)
    recall-info (get is-recalled recall-info)
    false
  )
)

(define-read-only (get-recall-by-batch (batch-number (string-ascii 50)))
  (match (get-batch-recall-status batch-number)
    recall-info (get-recall (get recall-id recall-info))
    none
  )
)

(define-read-only (get-recall-counter)
  (var-get recall-counter)
)

(define-read-only (is-authority-authorized (authority principal))
  (is-authorized-authority authority)
)

(define-read-only (get-authority-info (authority principal))
  (map-get? recall-authorities { authority: authority })
)

(define-read-only (is-contract-enabled)
  (var-get contract-enabled)
)

(define-read-only (is-emergency-mode)
  (var-get emergency-mode)
)

(define-read-only (get-contract-owner)
  CONTRACT_OWNER
)

(define-read-only (get-recall-severity-info (severity uint))
  (if (is-eq severity SEVERITY_LOW)
    "Low Risk - Minor quality issues"
    (if (is-eq severity SEVERITY_MEDIUM)
      "Medium Risk - Potential health impact"
      (if (is-eq severity SEVERITY_HIGH)
        "High Risk - Serious health hazard"
        (if (is-eq severity SEVERITY_CRITICAL)
          "Critical - Immediate danger to health"
          "Unknown severity level"
        )
      )
    )
  )
)

(define-read-only (get-recall-status-info (status uint))
  (if (is-eq status STATUS_ISSUED)
    "Issued - Recall notice published"
    (if (is-eq status STATUS_IN_PROGRESS)
      "In Progress - Recall actions underway"
      (if (is-eq status STATUS_RESOLVED)
        "Resolved - Recall completed successfully"
        (if (is-eq status STATUS_CANCELLED)
          "Cancelled - Recall was cancelled"
          "Unknown status"
        )
      )
    )
  )
)

(define-read-only (check-batch-safety (batch-number (string-ascii 50)))
  (let
    (
      (recall-info (get-batch-recall-status batch-number))
    )
    (match recall-info
      recall-data
      (let
        (
          (recall-details (get-recall (get recall-id recall-data)))
        )
        (match recall-details
          recall
          {
            is-recalled: true,
            recall-id: (get recall-id recall-data),
            severity: (get severity recall),
            status: (get status recall),
            reason: (get reason recall),
            is-emergency: (get is-emergency recall),
            safe-to-use: false
          }
          {
            is-recalled: false,
            recall-id: u0,
            severity: u0,
            status: u0,
            reason: "",
            is-emergency: false,
            safe-to-use: true
          }
        )
      )
      {
        is-recalled: false,
        recall-id: u0,
        severity: u0,
        status: u0,
        reason: "",
        is-emergency: false,
        safe-to-use: true
      }
    )
  )
)
