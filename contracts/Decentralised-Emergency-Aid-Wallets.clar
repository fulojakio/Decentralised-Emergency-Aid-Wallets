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
