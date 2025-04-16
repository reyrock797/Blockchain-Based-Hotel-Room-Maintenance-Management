;; Room Status Contract
;; This contract tracks cleanliness and repair needs of hotel rooms

(define-data-var contract-owner principal tx-sender)

;; Status enum: 0 = clean, 1 = needs cleaning, 2 = needs repair, 3 = under maintenance
(define-constant STATUS_CLEAN u0)
(define-constant STATUS_NEEDS_CLEANING u1)
(define-constant STATUS_NEEDS_REPAIR u2)
(define-constant STATUS_UNDER_MAINTENANCE u3)

;; Map to store rooms by property and room number
(define-map rooms
  { property-owner: principal, room-number: uint }
  {
    status: uint,
    last-updated: uint,
    description: (string-utf8 200),
    priority: uint  ;; 0 = low, 1 = medium, 2 = high
  }
)

;; Map to track authorized staff for a property
(define-map authorized-staff
  { property-owner: principal, staff-address: principal }
  { authorized: bool }
)

;; Function to add a room
(define-public (add-room (property-owner principal) (room-number uint) (description (string-utf8 200)))
  (let ((caller tx-sender))
    (if (is-eq caller property-owner)
      (ok (map-set rooms
        { property-owner: property-owner, room-number: room-number }
        {
          status: STATUS_CLEAN,
          last-updated: (unwrap-panic (get-block-info? time u0)),
          description: description,
          priority: u0
        }
      ))
      (err u403) ;; Unauthorized
    )
  )
)

;; Function to update room status
(define-public (update-room-status (property-owner principal) (room-number uint) (new-status uint) (priority uint))
  (let ((caller tx-sender))
    (if (or
          (is-eq caller property-owner)
          (is-authorized-staff property-owner caller)
        )
      (match (map-get? rooms { property-owner: property-owner, room-number: room-number })
        room (ok (map-set rooms
          { property-owner: property-owner, room-number: room-number }
          (merge room {
            status: new-status,
            last-updated: (unwrap-panic (get-block-info? time u0)),
            priority: priority
          })
        ))
        (err u404) ;; Room not found
      )
      (err u403) ;; Unauthorized
    )
  )
)

;; Function to authorize staff
(define-public (authorize-staff (staff-address principal))
  (let ((caller tx-sender))
    (ok (map-set authorized-staff
      { property-owner: caller, staff-address: staff-address }
      { authorized: true }
    ))
  )
)

;; Function to revoke staff authorization
(define-public (revoke-staff (staff-address principal))
  (let ((caller tx-sender))
    (ok (map-set authorized-staff
      { property-owner: caller, staff-address: staff-address }
      { authorized: false }
    ))
  )
)

;; Read-only function to check if staff is authorized
(define-read-only (is-authorized-staff (property-owner principal) (staff-address principal))
  (match (map-get? authorized-staff { property-owner: property-owner, staff-address: staff-address })
    auth (get authorized auth)
    false
  )
)

;; Read-only function to get room status
(define-read-only (get-room-status (property-owner principal) (room-number uint))
  (map-get? rooms { property-owner: property-owner, room-number: room-number })
)

;; Read-only function to get all rooms needing attention (cleaning or repair)
(define-read-only (get-rooms-needing-attention (property-owner principal))
  ;; Note: In a real implementation, this would require off-chain indexing
  ;; or a more complex on-chain mechanism to return multiple rooms
  ;; This is a simplified placeholder
  (ok true)
)
