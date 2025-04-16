;; Quality Verification Contract
;; This contract confirms satisfactory completion of maintenance tasks

(define-data-var contract-owner principal tx-sender)

;; Map to store quality verifications
(define-map quality-verifications
  { order-id: uint }
  {
    verified-by: principal,
    rating: uint,  ;; 1-5 rating
    comments: (string-utf8 200),
    verification-date: uint,
    is-satisfactory: bool
  }
)

;; Map to track verifier authorizations
(define-map authorized-verifiers
  { property-owner: principal, verifier-address: principal }
  { authorized: bool }
)

;; Function to authorize a verifier
(define-public (authorize-verifier (verifier-address principal))
  (let ((caller tx-sender))
    (ok (map-set authorized-verifiers
      { property-owner: caller, verifier-address: verifier-address }
      { authorized: true }
    ))
  )
)

;; Function to revoke verifier authorization
(define-public (revoke-verifier (verifier-address principal))
  (let ((caller tx-sender))
    (ok (map-set authorized-verifiers
      { property-owner: caller, verifier-address: verifier-address }
      { authorized: false }
    ))
  )
)

;; Function to verify work quality
(define-public (verify-work-quality
    (order-id uint)
    (rating uint)
    (comments (string-utf8 200))
    (is-satisfactory bool)
  )
  (let ((caller tx-sender))
    ;; Get the work order details from the maintenance contract
    ;; In a real implementation, this would use a contract call
    ;; For simplicity, we'll assume the caller is authorized

    (map-set quality-verifications
      { order-id: order-id }
      {
        verified-by: caller,
        rating: rating,
        comments: comments,
        verification-date: (unwrap-panic (get-block-info? time u0)),
        is-satisfactory: is-satisfactory
      }
    )

    ;; If we had a contract call to the maintenance contract, we would update
    ;; the work order status to verified here

    (ok true)
  )
)

;; Read-only function to check if a verifier is authorized
(define-read-only (is-authorized-verifier (property-owner principal) (verifier-address principal))
  (match (map-get? authorized-verifiers { property-owner: property-owner, verifier-address: verifier-address })
    auth (get authorized auth)
    false
  )
)

;; Read-only function to get verification details
(define-read-only (get-verification-details (order-id uint))
  (map-get? quality-verifications { order-id: order-id })
)

;; Read-only function to check if work was satisfactory
(define-read-only (is-work-satisfactory (order-id uint))
  (match (map-get? quality-verifications { order-id: order-id })
    verification (get is-satisfactory verification)
    false
  )
)
