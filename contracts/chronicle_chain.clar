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

;; Validates that a property category meets system requirements
(define-private (is-category-valid (category (string-ascii 32)))
  (and
    (> (len category) u0)
    (< (len category) u33)
  )
)

;; Ensures all property categories are valid before accepting them
(define-private (check-category-list (categories (list 10 (string-ascii 32))))
  (and
    (> (len categories) u0)
    (<= (len categories) u10)
    (is-eq (len (filter is-category-valid categories)) (len categories))
  )
)

;; Checks if a property deed record exists in the registry
(define-private (does-entry-exist (entry-id uint))
  (is-some (map-get? property-deed-registry { entry-id: entry-id }))
)

;; Verifies if a user is the registered owner of a property deed
(define-private (is-deed-owner (entry-id uint) (account principal))
  (match (map-get? property-deed-registry { entry-id: entry-id })
    entry-data (is-eq (get deed-holder entry-data) account)
    false
  )
)

;; =========================================================
;; Section 5: Public Registry Functions
;; =========================================================

;; Register a new property deed with the system
(define-public (register-property-deed 
                (name (string-ascii 64)) 
                (dimensions uint) 
                (details (string-ascii 128)) 
                (categories (list 10 (string-ascii 32))))
  (let
    (
      (new-entry-id (+ (var-get registry-entry-counter) u1))
    )
    ;; Perform validation checks on all inputs
    (asserts! (> (len name) u0) err-invalid-property-name)
    (asserts! (< (len name) u65) err-invalid-property-name)
    (asserts! (> dimensions u0) err-invalid-file-dimensions)
    (asserts! (< dimensions u1000000000) err-invalid-file-dimensions)
    (asserts! (> (len details) u0) err-invalid-property-name)
    (asserts! (< (len details) u129) err-invalid-property-name)
    (asserts! (check-category-list categories) err-malformed-category)

    ;; Create the new property deed record
    (map-insert property-deed-registry
      { entry-id: new-entry-id }
      {
        property-name: name,
        deed-holder: tx-sender,
        file-dimensions: dimensions,
        registration-block: block-height,
        property-details: details,
        property-categories: categories
      }
    )

    ;; Automatically grant access to the deed owner
    (map-insert deed-access-controls
      { entry-id: new-entry-id, accessor: tx-sender }
      { can-view: true }
    )

    ;; Increment the registry counter
    (var-set registry-entry-counter new-entry-id)

    ;; Return the new entry ID
    (ok new-entry-id)
  )
)

;; Transfer ownership of a property deed to another account
(define-public (transfer-deed-ownership (entry-id uint) (new-holder principal))
  (let
    (
      (entry-data (unwrap! (map-get? property-deed-registry { entry-id: entry-id }) err-registry-entry-missing))
    )
    ;; Ensure the entry exists and caller is the current owner
    (asserts! (does-entry-exist entry-id) err-registry-entry-missing)
    (asserts! (is-eq (get deed-holder entry-data) tx-sender) err-operation-forbidden)

    ;; Update the property deed record with the new owner
    (map-set property-deed-registry
      { entry-id: entry-id }
      (merge entry-data { deed-holder: new-holder })
    )

    (ok true)
  )
)

;; Modify an existing property deed's information
(define-public (modify-property-deed 
                (entry-id uint) 
                (updated-name (string-ascii 64)) 
                (updated-dimensions uint) 
                (updated-details (string-ascii 128)) 
                (updated-categories (list 10 (string-ascii 32))))
  (let
    (
      (entry-data (unwrap! (map-get? property-deed-registry { entry-id: entry-id }) err-registry-entry-missing))
    )
    ;; Verify the entry exists and caller has authority
    (asserts! (does-entry-exist entry-id) err-registry-entry-missing)
    (asserts! (is-eq (get deed-holder entry-data) tx-sender) err-operation-forbidden)

    ;; Validate all new input data
    (asserts! (> (len updated-name) u0) err-invalid-property-name)
    (asserts! (< (len updated-name) u65) err-invalid-property-name)
    (asserts! (> updated-dimensions u0) err-invalid-file-dimensions)
    (asserts! (< updated-dimensions u1000000000) err-invalid-file-dimensions)
    (asserts! (> (len updated-details) u0) err-invalid-property-name)
    (asserts! (< (len updated-details) u129) err-invalid-property-name)
    (asserts! (check-category-list updated-categories) err-malformed-category)

    ;; Update the property deed record with new information
    (map-set property-deed-registry
      { entry-id: entry-id }
      (merge entry-data { 
        property-name: updated-name, 
        file-dimensions: updated-dimensions, 
        property-details: updated-details, 
        property-categories: updated-categories 
      })
    )

    (ok true)
  )
)

;; Remove a property deed from the registry
(define-public (remove-property-deed (entry-id uint))
  (let
    (
      (entry-data (unwrap! (map-get? property-deed-registry { entry-id: entry-id }) err-registry-entry-missing))
    )
    ;; Check if the entry exists and caller has permission
    (asserts! (does-entry-exist entry-id) err-registry-entry-missing)
    (asserts! (is-eq (get deed-holder entry-data) tx-sender) err-operation-forbidden)

    ;; Delete the property deed from the registry
    (map-delete property-deed-registry { entry-id: entry-id })

    (ok true)
  )
)

;; =========================================================
;; Section 6: Access Control Management
;; =========================================================

;; Remove a user's access to a specific property deed
(define-public (withdraw-deed-access (entry-id uint) (accessor principal))
  (let
    (
      (entry-data (unwrap! (map-get? property-deed-registry { entry-id: entry-id }) err-registry-entry-missing))
    )
    ;; Verify entry exists and caller has authority
    (asserts! (does-entry-exist entry-id) err-registry-entry-missing)
    (asserts! (is-eq (get deed-holder entry-data) tx-sender) err-operation-forbidden)
    (asserts! (not (is-eq accessor tx-sender)) err-invalid-property-name) ;; Owner can't remove their own access

    ;; Remove access permission
    (map-delete deed-access-controls { entry-id: entry-id, accessor: accessor })

    (ok true)
  )
)

;; Access a property deed record if authorized
(define-public (access-property-deed (entry-id uint))
  (let
    (
      (entry-data (unwrap! (map-get? property-deed-registry { entry-id: entry-id }) err-registry-entry-missing))
      (access-permission (map-get? deed-access-controls { entry-id: entry-id, accessor: tx-sender }))
    )
    ;; Check if the deed exists
    (asserts! (does-entry-exist entry-id) err-registry-entry-missing)

    ;; Verify access rights
    (asserts! (or 
                (is-eq (get deed-holder entry-data) tx-sender)
                (is-some access-permission)
                (and (is-some access-permission) (get can-view (unwrap! access-permission err-viewing-restricted)))
              ) 
              err-viewing-restricted)

    ;; Return the deed data if authorized
    (ok entry-data)
  )
)

;; =========================================================
;; Section 7: Validation Framework
;; =========================================================

;; Validate the authenticity of a property deed
(define-public (certify-property-deed (entry-id uint) (assessment-notes (string-ascii 256)))
  (let
    (
      (entry-data (unwrap! (map-get? property-deed-registry { entry-id: entry-id }) err-registry-entry-missing))
      (validator-credentials (unwrap! (map-get? authorized-validators { validator: tx-sender }) err-operation-forbidden))
    )
    ;; Verify the deed exists
    (asserts! (does-entry-exist entry-id) err-registry-entry-missing)

    ;; Confirm validator authorization
    (asserts! (get is-authorized validator-credentials) err-operation-forbidden)

    (ok true)
  )
)

