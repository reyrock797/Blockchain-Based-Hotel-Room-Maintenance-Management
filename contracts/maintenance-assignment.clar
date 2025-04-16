;; Maintenance Assignment Contract
;; This contract manages work orders to staff

(define-data-var contract-owner principal tx-sender)

;; Work order status: 0 = assigned, 1 = in progress, 2 = completed, 3 = verified
(define-constant STATUS_ASSIGNED u0)
(define-constant STATUS_IN_PROGRESS u1)
(define-constant STATUS_COMPLETED u2)
(define-constant STATUS_VERIFIED u3)

;; Counter for work order IDs
(define-data-var work-order-id-counter uint u0)

;; Map to store work orders
(define-map work-orders
  { order-id: uint }
  {
    property-owner: principal,
    room-number: uint,
    assigned-to: principal,
    status: uint,
    task-type: uint,  ;; 0 = cleaning, 1 = repair
    description: (string-utf8 200),
    created-at: uint,
    updated-at: uint
  }
)

;; Map to track staff assignments
(define-map staff-assignments
  { staff-address: principal }
  { active-assignments: uint }
)

;; Function to create a work order
(define-public (create-work-order
    (room-number uint)
    (assigned-to principal)
    (task-type uint)
    (description (string-utf8 200))
  )
  (let (
      (caller tx-sender)
      (new-id (var-get work-order-id-counter))
    )
    (var-set work-order-id-counter (+ new-id u1))
    (map-set work-orders
      { order-id: new-id }
      {
        property-owner: caller,
        room-number: room-number,
        assigned-to: assigned-to,
        status: STATUS_ASSIGNED,
        task-type: task-type,
        description: description,
        created-at: (unwrap-panic (get-block-info? time u0)),
        updated-at: (unwrap-panic (get-block-info? time u0))
      }
    )

    ;; Update staff assignments
    (match (map-get? staff-assignments { staff-address: assigned-to })
      assignment (map-set staff-assignments
        { staff-address: assigned-to }
        { active-assignments: (+ (get active-assignments assignment) u1) }
      )
      (map-set staff-assignments
        { staff-address: assigned-to }
        { active-assignments: u1 }
      )
    )

    (ok new-id)
  )
)

;; Function to update work order status
(define-public (update-work-order-status (order-id uint) (new-status uint))
  (let ((caller tx-sender))
    (match (map-get? work-orders { order-id: order-id })
      order
        (if (or
              (is-eq caller (get property-owner order))
              (is-eq caller (get assigned-to order))
            )
          (begin
            ;; If completing the work, decrement active assignments
            (if (and
                  (is-eq new-status STATUS_COMPLETED)
                  (not (is-eq (get status order) STATUS_COMPLETED))
                )
              (match (map-get? staff-assignments { staff-address: (get assigned-to order) })
                assignment (map-set staff-assignments
                  { staff-address: (get assigned-to order) }
                  { active-assignments: (- (get active-assignments assignment) u1) }
                )
                true
              )
              true
            )

            (ok (map-set work-orders
              { order-id: order-id }
              (merge order {
                status: new-status,
                updated-at: (unwrap-panic (get-block-info? time u0))
              })
            ))
          )
          (err u403) ;; Unauthorized
        )
      (err u404) ;; Work order not found
    )
  )
)

;; Function to reassign a work order
(define-public (reassign-work-order (order-id uint) (new-assignee principal))
  (let ((caller tx-sender))
    (match (map-get? work-orders { order-id: order-id })
      order
        (if (is-eq caller (get property-owner order))
          (begin
            ;; Decrement old assignee's count
            (match (map-get? staff-assignments { staff-address: (get assigned-to order) })
              assignment (map-set staff-assignments
                { staff-address: (get assigned-to order) }
                { active-assignments: (- (get active-assignments assignment) u1) }
              )
              true
            )

            ;; Increment new assignee's count
            (match (map-get? staff-assignments { staff-address: new-assignee })
              assignment (map-set staff-assignments
                { staff-address: new-assignee }
                { active-assignments: (+ (get active-assignments assignment) u1) }
              )
              (map-set staff-assignments
                { staff-address: new-assignee }
                { active-assignments: u1 }
              )
            )

            (ok (map-set work-orders
              { order-id: order-id }
              (merge order {
                assigned-to: new-assignee,
                updated-at: (unwrap-panic (get-block-info? time u0))
              })
            ))
          )
          (err u403) ;; Unauthorized
        )
      (err u404) ;; Work order not found
    )
  )
)

;; Read-only function to get work order details
(define-read-only (get-work-order (order-id uint))
  (map-get? work-orders { order-id: order-id })
)

;; Read-only function to get staff workload
(define-read-only (get-staff-workload (staff-address principal))
  (match (map-get? staff-assignments { staff-address: staff-address })
    assignment (get active-assignments assignment)
    u0
  )
)
