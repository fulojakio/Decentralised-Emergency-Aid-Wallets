(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-not-approved (err u105))
(define-constant err-already-approved (err u106))
(define-constant err-expired (err u107))
(define-constant err-self-approval (err u108))

(define-data-var next-aid-id uint u1)
(define-data-var total-donations uint u0)
(define-data-var total-distributed uint u0)

(define-map aid-requests
    { aid-id: uint }
    {
        requester: principal,
        amount-needed: uint,
        amount-raised: uint,
        description: (string-ascii 500),
        emergency-type: (string-ascii 100),
        deadline: uint,
        is-approved: bool,
        is-active: bool,
        approved-by: (optional principal),
    }
)

(define-map donations
    {
        donor: principal,
        aid-id: uint,
    }
    {
        amount: uint,
        timestamp: uint,
    }
)

(define-map donor-totals
    { donor: principal }
    {
        total-donated: uint,
        donation-count: uint,
    }
)

(define-map approvers
    { approver: principal }
    {
        is-active: bool,
        approvals-count: uint,
    }
)

(define-map aid-approvals
    {
        aid-id: uint,
        approver: principal,
    }
    {
        approved: bool,
        timestamp: uint,
    }
)

(define-public (add-approver (new-approver principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set approvers { approver: new-approver } {
            is-active: true,
            approvals-count: u0,
        })
        (ok true)
    )
)

(define-public (remove-approver (approver principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set approvers { approver: approver } {
            is-active: false,
            approvals-count: u0,
        })
        (ok true)
    )
)

(define-public (create-aid-request
        (amount-needed uint)
        (description (string-ascii 500))
        (emergency-type (string-ascii 100))
        (duration-blocks uint)
    )
    (let (
            (aid-id (var-get next-aid-id))
            (deadline (+ stacks-block-height duration-blocks))
        )
        (asserts! (> amount-needed u0) err-invalid-amount)
        (asserts! (> duration-blocks u0) err-invalid-amount)

        (map-set aid-requests { aid-id: aid-id } {
            requester: tx-sender,
            amount-needed: amount-needed,
            amount-raised: u0,
            description: description,
            emergency-type: emergency-type,
            deadline: deadline,
            is-approved: false,
            is-active: true,
            approved-by: none,
        })

        (var-set next-aid-id (+ aid-id u1))
        (ok aid-id)
    )
)

(define-public (approve-aid-request (aid-id uint))
    (let (
            (aid-request (unwrap! (map-get? aid-requests { aid-id: aid-id }) err-not-found))
            (approver-info (unwrap! (map-get? approvers { approver: tx-sender }) err-not-found))
        )
        (asserts! (get is-active approver-info) err-not-found)
        (asserts! (get is-active aid-request) err-not-found)
        (asserts! (not (is-eq tx-sender (get requester aid-request)))
            err-self-approval
        )
        (asserts! (<= stacks-block-height (get deadline aid-request)) err-expired)
        (asserts! (not (get is-approved aid-request)) err-already-approved)

        (map-set aid-requests { aid-id: aid-id }
            (merge aid-request {
                is-approved: true,
                approved-by: (some tx-sender),
            })
        )

        (map-set aid-approvals {
            aid-id: aid-id,
            approver: tx-sender,
        } {
            approved: true,
            timestamp: stacks-block-height,
        })

        (map-set approvers { approver: tx-sender }
            (merge approver-info { approvals-count: (+ (get approvals-count approver-info) u1) })
        )

        (ok true)
    )
)

(define-public (donate-to-aid
        (aid-id uint)
        (amount uint)
    )
    (let (
            (aid-request (unwrap! (map-get? aid-requests { aid-id: aid-id }) err-not-found))
            (current-donation (default-to {
                amount: u0,
                timestamp: u0,
            }
                (map-get? donations {
                    donor: tx-sender,
                    aid-id: aid-id,
                })
            ))
            (donor-stats (default-to {
                total-donated: u0,
                donation-count: u0,
            }
                (map-get? donor-totals { donor: tx-sender })
            ))
        )
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (get is-active aid-request) err-not-found)
        (asserts! (get is-approved aid-request) err-not-approved)
        (asserts! (<= stacks-block-height (get deadline aid-request)) err-expired)

        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

        (map-set donations {
            donor: tx-sender,
            aid-id: aid-id,
        } {
            amount: (+ (get amount current-donation) amount),
            timestamp: stacks-block-height,
        })

        (map-set donor-totals { donor: tx-sender } {
            total-donated: (+ (get total-donated donor-stats) amount),
            donation-count: (+ (get donation-count donor-stats) u1),
        })

        (map-set aid-requests { aid-id: aid-id }
            (merge aid-request { amount-raised: (+ (get amount-raised aid-request) amount) })
        )

        (var-set total-donations (+ (var-get total-donations) amount))

        (ok true)
    )
)

(define-public (withdraw-aid (aid-id uint))
    (let (
            (aid-request (unwrap! (map-get? aid-requests { aid-id: aid-id }) err-not-found))
            (amount-to-withdraw (get amount-raised aid-request))
        )
        (asserts! (is-eq tx-sender (get requester aid-request)) err-owner-only)
        (asserts! (get is-approved aid-request) err-not-approved)
        (asserts! (get is-active aid-request) err-not-found)
        (asserts! (> amount-to-withdraw u0) err-insufficient-funds)

        (try! (as-contract (stx-transfer? amount-to-withdraw tx-sender (get requester aid-request))))

        (map-set aid-requests { aid-id: aid-id }
            (merge aid-request { is-active: false })
        )

        (var-set total-distributed
            (+ (var-get total-distributed) amount-to-withdraw)
        )

        (ok amount-to-withdraw)
    )
)

(define-public (close-aid-request (aid-id uint))
    (let ((aid-request (unwrap! (map-get? aid-requests { aid-id: aid-id }) err-not-found)))
        (asserts! (is-eq tx-sender (get requester aid-request)) err-owner-only)
        (asserts! (get is-active aid-request) err-not-found)

        (map-set aid-requests { aid-id: aid-id }
            (merge aid-request { is-active: false })
        )

        (ok true)
    )
)

(define-read-only (get-aid-request (aid-id uint))
    (map-get? aid-requests { aid-id: aid-id })
)

(define-read-only (get-donation
        (donor principal)
        (aid-id uint)
    )
    (map-get? donations {
        donor: donor,
        aid-id: aid-id,
    })
)

(define-read-only (get-donor-stats (donor principal))
    (map-get? donor-totals { donor: donor })
)

(define-read-only (get-approver-info (approver principal))
    (map-get? approvers { approver: approver })
)

(define-read-only (get-aid-approval
        (aid-id uint)
        (approver principal)
    )
    (map-get? aid-approvals {
        aid-id: aid-id,
        approver: approver,
    })
)

(define-read-only (is-aid-expired (aid-id uint))
    (match (map-get? aid-requests { aid-id: aid-id })
        aid-request (> stacks-block-height (get deadline aid-request))
        false
    )
)

(define-read-only (get-contract-balance)
    (stx-get-balance (as-contract tx-sender))
)

(define-read-only (get-total-statistics)
    {
        total-donations: (var-get total-donations),
        total-distributed: (var-get total-distributed),
        next-aid-id: (var-get next-aid-id),
        contract-balance: (get-contract-balance),
    }
)

(define-read-only (get-aid-progress (aid-id uint))
    (match (map-get? aid-requests { aid-id: aid-id })
        aid-request (some {
            amount-needed: (get amount-needed aid-request),
            amount-raised: (get amount-raised aid-request),
            progress-percentage: (/ (* (get amount-raised aid-request) u100)
                (get amount-needed aid-request)
            ),
            is-fully-funded: (>= (get amount-raised aid-request) (get amount-needed aid-request)),
        })
        none
    )
)

;; === Emergency Alert System ===

;; Additional error constants for alert system
(define-constant err-alert-not-found (err u200))
(define-constant err-alert-already-resolved (err u201))
(define-constant err-invalid-priority (err u202))
(define-constant err-invalid-location (err u203))

;; Alert system data variables
(define-data-var next-alert-id uint u1)
(define-data-var total-alerts-created uint u0)
(define-data-var active-alerts-count uint u0)

;; Emergency alert data map
(define-map emergency-alerts
    { alert-id: uint }
    {
        creator: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        location: (string-ascii 200),
        emergency-type: (string-ascii 50),
        priority: uint, ;; 1=Low, 2=Medium, 3=High, 4=Critical
        created-at: uint,
        is-active: bool,
        resolved-at: (optional uint),
        resolved-by: (optional principal),
        contact-info: (optional (string-ascii 100)),
    }
)

;; Alert response tracking
(define-map alert-responses
    {
        alert-id: uint,
        responder: principal,
    }
    {
        response-type: (string-ascii 50), ;; "acknowledged", "helping", "resolved"
        message: (string-ascii 200),
        timestamp: uint,
    }
)

;; User alert statistics
(define-map user-alert-stats
    { user: principal }
    {
        alerts-created: uint,
        alerts-resolved: uint,
        responses-made: uint,
        last-activity: uint,
    }
)

;; Create emergency alert
(define-public (create-emergency-alert
        (title (string-ascii 100))
        (description (string-ascii 500))
        (location (string-ascii 200))
        (emergency-type (string-ascii 50))
        (priority uint)
        (contact-info (optional (string-ascii 100)))
    )
    (let (
            (alert-id (var-get next-alert-id))
            (user-stats (default-to {
                alerts-created: u0,
                alerts-resolved: u0,
                responses-made: u0,
                last-activity: u0,
            }
                (map-get? user-alert-stats { user: tx-sender })
            ))
        )
        ;; Validate inputs
        (asserts! (and (>= priority u1) (<= priority u4)) err-invalid-priority)
        (asserts! (> (len title) u0) err-invalid-amount)
        (asserts! (> (len description) u0) err-invalid-amount)
        (asserts! (> (len location) u0) err-invalid-location)

        ;; Create the alert
        (map-set emergency-alerts { alert-id: alert-id } {
            creator: tx-sender,
            title: title,
            description: description,
            location: location,
            emergency-type: emergency-type,
            priority: priority,
            created-at: stacks-block-height,
            is-active: true,
            resolved-at: none,
            resolved-by: none,
            contact-info: contact-info,
        })

        ;; Update statistics
        (map-set user-alert-stats { user: tx-sender }
            (merge user-stats {
                alerts-created: (+ (get alerts-created user-stats) u1),
                last-activity: stacks-block-height,
            })
        )

        ;; Update global counters
        (var-set next-alert-id (+ alert-id u1))
        (var-set total-alerts-created (+ (var-get total-alerts-created) u1))
        (var-set active-alerts-count (+ (var-get active-alerts-count) u1))

        (ok alert-id)
    )
)

;; Respond to an emergency alert
(define-public (respond-to-alert
        (alert-id uint)
        (response-type (string-ascii 50))
        (message (string-ascii 200))
    )
    (let (
            (alert (unwrap! (map-get? emergency-alerts { alert-id: alert-id }) err-alert-not-found))
            (user-stats (default-to {
                alerts-created: u0,
                alerts-resolved: u0,
                responses-made: u0,
                last-activity: u0,
            }
                (map-get? user-alert-stats { user: tx-sender })
            ))
        )
        ;; Validate alert is active
        (asserts! (get is-active alert) err-alert-already-resolved)
        
        ;; Prevent self-response
        (asserts! (not (is-eq tx-sender (get creator alert))) err-self-approval)

        ;; Record the response
        (map-set alert-responses {
            alert-id: alert-id,
            responder: tx-sender,
        } {
            response-type: response-type,
            message: message,
            timestamp: stacks-block-height,
        })

        ;; Update user statistics
        (map-set user-alert-stats { user: tx-sender }
            (merge user-stats {
                responses-made: (+ (get responses-made user-stats) u1),
                last-activity: stacks-block-height,
            })
        )

        (ok true)
    )
)

;; Resolve an emergency alert
(define-public (resolve-alert (alert-id uint))
    (let (
            (alert (unwrap! (map-get? emergency-alerts { alert-id: alert-id }) err-alert-not-found))
            (creator-stats (default-to {
                alerts-created: u0,
                alerts-resolved: u0,
                responses-made: u0,
                last-activity: u0,
            }
                (map-get? user-alert-stats { user: (get creator alert) })
            ))
        )
        ;; Only creator can resolve their alert
        (asserts! (is-eq tx-sender (get creator alert)) err-owner-only)
        (asserts! (get is-active alert) err-alert-already-resolved)

        ;; Mark alert as resolved
        (map-set emergency-alerts { alert-id: alert-id }
            (merge alert {
                is-active: false,
                resolved-at: (some stacks-block-height),
                resolved-by: (some tx-sender),
            })
        )

        ;; Update creator statistics
        (map-set user-alert-stats { user: (get creator alert) }
            (merge creator-stats {
                alerts-resolved: (+ (get alerts-resolved creator-stats) u1),
                last-activity: stacks-block-height,
            })
        )

        ;; Update global counter
        (var-set active-alerts-count (- (var-get active-alerts-count) u1))

        (ok true)
    )
)

;; Read-only functions for alert system

(define-read-only (get-emergency-alert (alert-id uint))
    (map-get? emergency-alerts { alert-id: alert-id })
)

(define-read-only (get-alert-response
        (alert-id uint)
        (responder principal)
    )
    (map-get? alert-responses {
        alert-id: alert-id,
        responder: responder,
    })
)

(define-read-only (get-user-alert-stats (user principal))
    (map-get? user-alert-stats { user: user })
)

(define-read-only (get-alert-system-stats)
    {
        total-alerts-created: (var-get total-alerts-created),
        active-alerts-count: (var-get active-alerts-count),
        next-alert-id: (var-get next-alert-id),
        resolved-alerts-count: (- (var-get total-alerts-created) (var-get active-alerts-count)),
    }
)

(define-read-only (is-alert-active (alert-id uint))
    (match (map-get? emergency-alerts { alert-id: alert-id })
        alert (get is-active alert)
        false
    )
)

(define-read-only (get-alert-priority-level (alert-id uint))
    (match (map-get? emergency-alerts { alert-id: alert-id })
        alert (some (get priority alert))
        none
    )
)

(define-read-only (get-alerts-by-priority (min-priority uint))
    (if (and (>= min-priority u1) (<= min-priority u4))
        (ok min-priority) ;; In a full implementation, this would filter alerts
        err-invalid-priority
    )
)
