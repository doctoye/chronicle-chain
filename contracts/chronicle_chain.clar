;; Chronicle Chain: Heritage Authentication Network Smart Contract

;; =========================================================
;; Section 1: System Error Definitions
;; =========================================================

(define-constant err-registry-entry-missing (err u301))
(define-constant err-entry-already-exists (err u302))
(define-constant err-invalid-property-name (err u303))
(define-constant err-restricted-to-registry-admin (err u300))
(define-constant err-viewing-restricted (err u307))
(define-constant err-malformed-category (err u308))
(define-constant err-invalid-file-dimensions (err u304))
(define-constant err-no-permissions (err u305))
(define-constant err-operation-forbidden (err u306))

;; =========================================================
;; Section 2: Registry Administration
;; =========================================================

;; Registry governance - automatically set to contract deployer
(define-constant registry-supervisor tx-sender)

;; Tracks total number of registered property deeds in the system
(define-data-var registry-entry-counter uint u0)

;; =========================================================
;; Section 3: Core Data Structures
;; =========================================================

;; Primary property documentation registry
(define-map property-deed-registry
  { entry-id: uint }
  {
    property-name: (string-ascii 64),
    deed-holder: principal,
    file-dimensions: uint,
    registration-block: uint,
    property-details: (string-ascii 128),
    property-categories: (list 10 (string-ascii 32))
  }
)

;; Registry of trusted third-party validators
(define-map authorized-validators
  { validator: principal }
  { is-authorized: bool }
)

;; Record of property deed validations
(define-map deed-validation-records
  { entry-id: uint }
  {
    validation-status: bool,
    validated-by: principal,
    validation-block: uint,
    validation-comments: (string-ascii 256)
  }
)

;; Mapping that controls who can access specific property deeds
(define-map deed-access-controls
  { entry-id: uint, accessor: principal }
  { can-view: bool }
)

;; =========================================================
;; Section 4: Helper Functions
;; =========================================================

;; Retrieves the size of a property deed file
(define-private (get-file-size (entry-id uint))
  (default-to u0
    (get file-dimensions
      (map-get? property-deed-registry { entry-id: entry-id })
    )
  )
)
