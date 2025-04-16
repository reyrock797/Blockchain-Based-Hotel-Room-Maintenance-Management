;; Property Verification Contract
;; This contract validates legitimate accommodation providers

(define-data-var contract-owner principal tx-sender)

;; Map to store verified properties
(define-map verified-properties principal
  {
    name: (string-utf8 100),
    address: (string-utf8 200),
    verified: bool,
    verification-date: uint
  }
)

;; Public function to register a property
(define-public (register-property (name (string-utf8 100)) (address (string-utf8 200)))
  (let ((caller tx-sender))
    (if (is-eq caller (var-get contract-owner))
      (ok (map-set verified-properties caller {
        name: name,
        address: address,
        verified: false,
        verification-date: u0
      }))
      (err u403) ;; Unauthorized
    )
  )
)

;; Admin function to verify a property
(define-public (verify-property (property-owner principal))
  (let ((caller tx-sender))
    (if (is-eq caller (var-get contract-owner))
      (match (map-get? verified-properties property-owner)
        property (ok (map-set verified-properties property-owner
          (merge property {
            verified: true,
            verification-date: (unwrap-panic (get-block-info? time u0))
          })
        ))
        (err u404) ;; Property not found
      )
      (err u403) ;; Unauthorized
    )
  )
)

;; Read-only function to check if a property is verified
(define-read-only (is-property-verified (property-owner principal))
  (match (map-get? verified-properties property-owner)
    property (get verified property)
    false
  )
)

;; Read-only function to get property details
(define-read-only (get-property-details (property-owner principal))
  (map-get? verified-properties property-owner)
)

;; Function to transfer ownership
(define-public (transfer-ownership (new-owner principal))
  (let ((caller tx-sender))
    (if (is-eq caller (var-get contract-owner))
      (ok (var-set contract-owner new-owner))
      (err u403) ;; Unauthorized
    )
  )
)
