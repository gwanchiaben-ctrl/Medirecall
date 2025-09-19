;; title: medicine-registry
;; version: 1.0.0
;; summary: Medicine Registry Contract for tracking pharmaceutical products
;; description: This contract manages the registration and tracking of medicine products,
;;              including batch numbers, expiration dates, and manufacturer information.

;; constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_MEDICINE_EXISTS (err u101))
(define-constant ERR_MEDICINE_NOT_FOUND (err u102))
(define-constant ERR_INVALID_EXPIRY (err u103))
(define-constant ERR_INVALID_BATCH (err u104))
(define-constant ERR_INVALID_MANUFACTURER (err u105))
(define-constant ERR_INVALID_MEDICINE_ID (err u106))
(define-constant ERR_BATCH_EXISTS (err u107))

(define-constant CONTRACT_OWNER tx-sender)
(define-constant SECONDS_IN_DAY u86400)

;; data vars
(define-data-var medicine-counter uint u0)
(define-data-var batch-counter uint u0)
(define-data-var contract-enabled bool true)

;; data maps
(define-map medicines
  { medicine-id: uint }
  {
    name: (string-ascii 100),
    manufacturer: principal,
    drug-code: (string-ascii 50),
    category: (string-ascii 50),
    created-at: uint,
    created-by: principal,
    is-active: bool
  }
)

(define-map medicine-batches
  { batch-id: uint }
  {
    medicine-id: uint,
    batch-number: (string-ascii 50),
    manufacturing-date: uint,
    expiry-date: uint,
    quantity: uint,
    manufacturer: principal,
    created-at: uint,
    is-active: bool
  }
)

(define-map authorized-manufacturers
  { manufacturer: principal }
  { authorized: bool, authorized-at: uint, authorized-by: principal }
)

(define-map batch-lookup
  { batch-number: (string-ascii 50) }
  { batch-id: uint }
)

(define-map medicine-name-lookup
  { name: (string-ascii 100) }
  { medicine-id: uint }
)

;; private functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (is-authorized-manufacturer (manufacturer principal))
  (default-to false 
    (get authorized (map-get? authorized-manufacturers { manufacturer: manufacturer }))
  )
)

(define-private (is-valid-expiry-date (expiry uint))
  (> expiry stacks-block-height)
)

(define-private (increment-medicine-counter)
  (let ((current-counter (var-get medicine-counter)))
    (var-set medicine-counter (+ current-counter u1))
    current-counter
  )
)

(define-private (increment-batch-counter)
  (let ((current-counter (var-get batch-counter)))
    (var-set batch-counter (+ current-counter u1))
    current-counter
  )
)

;; public functions
(define-public (authorize-manufacturer (manufacturer principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (var-get contract-enabled) ERR_UNAUTHORIZED)
    (map-set authorized-manufacturers
      { manufacturer: manufacturer }
      {
        authorized: true,
        authorized-at: stacks-block-height,
        authorized-by: tx-sender
      }
    )
    (ok true)
  )
)

(define-public (revoke-manufacturer (manufacturer principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (map-set authorized-manufacturers
      { manufacturer: manufacturer }
      {
        authorized: false,
        authorized-at: stacks-block-height,
        authorized-by: tx-sender
      }
    )
    (ok true)
  )
)

(define-public (register-medicine 
    (name (string-ascii 100))
    (drug-code (string-ascii 50))
    (category (string-ascii 50))
  )
  (let
    (
      (medicine-id (increment-medicine-counter))
    )
    (asserts! (is-authorized-manufacturer tx-sender) ERR_UNAUTHORIZED)
    (asserts! (var-get contract-enabled) ERR_UNAUTHORIZED)
    (asserts! (> (len name) u0) ERR_INVALID_MEDICINE_ID)
    (asserts! (> (len drug-code) u0) ERR_INVALID_MEDICINE_ID)
    (asserts! (is-none (map-get? medicine-name-lookup { name: name })) ERR_MEDICINE_EXISTS)
    
    (map-set medicines
      { medicine-id: medicine-id }
      {
        name: name,
        manufacturer: tx-sender,
        drug-code: drug-code,
        category: category,
        created-at: stacks-block-height,
        created-by: tx-sender,
        is-active: true
      }
    )
    
    (map-set medicine-name-lookup
      { name: name }
      { medicine-id: medicine-id }
    )
    
    (ok medicine-id)
  )
)

(define-public (register-batch
    (medicine-id uint)
    (batch-number (string-ascii 50))
    (manufacturing-date uint)
    (expiry-date uint)
    (quantity uint)
  )
  (let
    (
      (batch-id (increment-batch-counter))
      (medicine (map-get? medicines { medicine-id: medicine-id }))
    )
    (asserts! (is-authorized-manufacturer tx-sender) ERR_UNAUTHORIZED)
    (asserts! (var-get contract-enabled) ERR_UNAUTHORIZED)
    (asserts! (is-some medicine) ERR_MEDICINE_NOT_FOUND)
    (asserts! (> (len batch-number) u0) ERR_INVALID_BATCH)
    (asserts! (is-none (map-get? batch-lookup { batch-number: batch-number })) ERR_BATCH_EXISTS)
    (asserts! (< manufacturing-date expiry-date) ERR_INVALID_EXPIRY)
    (asserts! (> quantity u0) ERR_INVALID_BATCH)
    (asserts! (is-valid-expiry-date expiry-date) ERR_INVALID_EXPIRY)
    
    (map-set medicine-batches
      { batch-id: batch-id }
      {
        medicine-id: medicine-id,
        batch-number: batch-number,
        manufacturing-date: manufacturing-date,
        expiry-date: expiry-date,
        quantity: quantity,
        manufacturer: tx-sender,
        created-at: stacks-block-height,
        is-active: true
      }
    )
    
    (map-set batch-lookup
      { batch-number: batch-number }
      { batch-id: batch-id }
    )
    
    (ok batch-id)
  )
)

(define-public (deactivate-medicine (medicine-id uint))
  (let
    (
      (medicine (map-get? medicines { medicine-id: medicine-id }))
    )
    (asserts! (is-some medicine) ERR_MEDICINE_NOT_FOUND)
    (asserts! (or (is-contract-owner) 
                  (is-eq tx-sender (get manufacturer (unwrap-panic medicine)))) ERR_UNAUTHORIZED)
    
    (map-set medicines
      { medicine-id: medicine-id }
      (merge (unwrap-panic medicine) { is-active: false })
    )
    
    (ok true)
  )
)

(define-public (deactivate-batch (batch-id uint))
  (let
    (
      (batch (map-get? medicine-batches { batch-id: batch-id }))
    )
    (asserts! (is-some batch) ERR_MEDICINE_NOT_FOUND)
    (asserts! (or (is-contract-owner) 
                  (is-eq tx-sender (get manufacturer (unwrap-panic batch)))) ERR_UNAUTHORIZED)
    
    (map-set medicine-batches
      { batch-id: batch-id }
      (merge (unwrap-panic batch) { is-active: false })
    )
    
    (ok true)
  )
)

(define-public (toggle-contract (enabled bool))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-enabled enabled)
    (ok enabled)
  )
)

;; read only functions
(define-read-only (get-medicine (medicine-id uint))
  (map-get? medicines { medicine-id: medicine-id })
)

(define-read-only (get-batch (batch-id uint))
  (map-get? medicine-batches { batch-id: batch-id })
)

(define-read-only (get-batch-by-number (batch-number (string-ascii 50)))
  (match (map-get? batch-lookup { batch-number: batch-number })
    batch-lookup-result (get-batch (get batch-id batch-lookup-result))
    none
  )
)

(define-read-only (get-medicine-by-name (name (string-ascii 100)))
  (match (map-get? medicine-name-lookup { name: name })
    medicine-lookup-result (get-medicine (get medicine-id medicine-lookup-result))
    none
  )
)

(define-read-only (is-batch-expired (batch-id uint))
  (match (get-batch batch-id)
    batch (< (get expiry-date batch) stacks-block-height)
    false
  )
)

(define-read-only (is-batch-number-expired (batch-number (string-ascii 50)))
  (match (get-batch-by-number batch-number)
    batch (< (get expiry-date batch) stacks-block-height)
    false
  )
)

(define-read-only (get-medicine-counter)
  (var-get medicine-counter)
)

(define-read-only (get-batch-counter)
  (var-get batch-counter)
)

(define-read-only (is-manufacturer-authorized (manufacturer principal))
  (is-authorized-manufacturer manufacturer)
)

(define-read-only (get-manufacturer-info (manufacturer principal))
  (map-get? authorized-manufacturers { manufacturer: manufacturer })
)

(define-read-only (is-contract-enabled)
  (var-get contract-enabled)
)

(define-read-only (get-contract-owner)
  CONTRACT_OWNER
)

(define-read-only (check-medicine-safety (batch-number (string-ascii 50)))
  (match (get-batch-by-number batch-number)
    batch
    {
      exists: true,
      is-expired: (< (get expiry-date batch) stacks-block-height),
      is-active: (get is-active batch),
      expiry-date: (get expiry-date batch),
      medicine-id: (get medicine-id batch),
      manufacturer: (get manufacturer batch)
    }
    {
      exists: false,
      is-expired: false,
      is-active: false,
      expiry-date: u0,
      medicine-id: u0,
      manufacturer: CONTRACT_OWNER
    }
  )
)
