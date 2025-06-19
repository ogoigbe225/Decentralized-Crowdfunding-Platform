(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_PROJECT_NOT_FOUND (err u101))
(define-constant ERR_PROJECT_ENDED (err u102))
(define-constant ERR_PROJECT_NOT_ENDED (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_ALREADY_FUNDED (err u105))
(define-constant ERR_MILESTONE_NOT_FOUND (err u106))
(define-constant ERR_MILESTONE_ALREADY_APPROVED (err u107))
(define-constant ERR_INSUFFICIENT_APPROVALS (err u108))
(define-constant ERR_NO_FUNDS_TO_WITHDRAW (err u109))
(define-constant ERR_REFUND_NOT_AVAILABLE (err u110))

(define-data-var project-counter uint u0)
(define-data-var milestone-counter uint u0)

(define-map projects
  uint
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    funding-goal: uint,
    current-funding: uint,
    end-block: uint,
    is-active: bool,
    funds-released: uint
  }
)

(define-map project-funders
  { project-id: uint, funder: principal }
  { amount: uint }
)

(define-map project-milestones
  uint
  {
    project-id: uint,
    description: (string-ascii 200),
    funding-amount: uint,
    approvals: uint,
    is-approved: bool,
    is-released: bool
  }
)

(define-map milestone-votes
  { milestone-id: uint, voter: principal }
  bool
)

(define-map user-total-funded
  { project-id: uint, user: principal }
  uint
)

(define-public (create-project (title (string-ascii 100)) (description (string-ascii 500)) (funding-goal uint) (duration uint))
  (let
    (
      (project-id (+ (var-get project-counter) u1))
      (end-block (+ stacks-block-height duration))
    )
    (map-set projects project-id
      {
        creator: tx-sender,
        title: title,
        description: description,
        funding-goal: funding-goal,
        current-funding: u0,
        end-block: end-block,
        is-active: true,
        funds-released: u0
      }
    )
    (var-set project-counter project-id)
    (ok project-id)
  )
)

(define-public (fund-project (project-id uint) (amount uint))
  (let
    (
      (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
      (current-funded (default-to u0 (map-get? user-total-funded { project-id: project-id, user: tx-sender })))
    )
    (asserts! (get is-active project) ERR_PROJECT_ENDED)
    (asserts! (< stacks-block-height (get end-block project)) ERR_PROJECT_ENDED)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set user-total-funded 
      { project-id: project-id, user: tx-sender }
      (+ current-funded amount)
    )
    (map-set project-funders
      { project-id: project-id, funder: tx-sender }
      { amount: (+ (default-to u0 (get amount (map-get? project-funders { project-id: project-id, funder: tx-sender }))) amount) }
    )
    (map-set projects project-id
      (merge project { current-funding: (+ (get current-funding project) amount) })
    )
    (ok true)
  )
)

(define-public (create-milestone (project-id uint) (description (string-ascii 200)) (funding-amount uint))
  (let
    (
      (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
      (milestone-id (+ (var-get milestone-counter) u1))
    )
    (asserts! (is-eq tx-sender (get creator project)) ERR_NOT_AUTHORIZED)
    (map-set project-milestones milestone-id
      {
        project-id: project-id,
        description: description,
        funding-amount: funding-amount,
        approvals: u0,
        is-approved: false,
        is-released: false
      }
    )
    (var-set milestone-counter milestone-id)
    (ok milestone-id)
  )
)

(define-public (vote-milestone (milestone-id uint))
  (let
    (
      (milestone (unwrap! (map-get? project-milestones milestone-id) ERR_MILESTONE_NOT_FOUND))
      (project (unwrap! (map-get? projects (get project-id milestone)) ERR_PROJECT_NOT_FOUND))
      (user-funded (default-to u0 (map-get? user-total-funded { project-id: (get project-id milestone), user: tx-sender })))
      (already-voted (default-to false (map-get? milestone-votes { milestone-id: milestone-id, voter: tx-sender })))
    )
    (asserts! (> user-funded u0) ERR_NOT_AUTHORIZED)
    (asserts! (not already-voted) ERR_ALREADY_FUNDED)
    (asserts! (not (get is-approved milestone)) ERR_MILESTONE_ALREADY_APPROVED)
    (map-set milestone-votes
      { milestone-id: milestone-id, voter: tx-sender }
      true
    )
    (map-set project-milestones milestone-id
      (merge milestone { approvals: (+ (get approvals milestone) u1) })
    )
    (ok true)
  )
)

(define-public (approve-milestone (milestone-id uint))
  (let
    (
      (milestone (unwrap! (map-get? project-milestones milestone-id) ERR_MILESTONE_NOT_FOUND))
      (project (unwrap! (map-get? projects (get project-id milestone)) ERR_PROJECT_NOT_FOUND))
      (required-approvals (/ (get current-funding project) u1000000))
    )
    (asserts! (>= (get approvals milestone) (if (> required-approvals u3) required-approvals u3)) ERR_INSUFFICIENT_APPROVALS)
    (asserts! (not (get is-approved milestone)) ERR_MILESTONE_ALREADY_APPROVED)
    (map-set project-milestones milestone-id
      (merge milestone { is-approved: true })
    )
    (ok true)
  )
)

(define-public (release-milestone-funds (milestone-id uint))
  (let
    (
      (milestone (unwrap! (map-get? project-milestones milestone-id) ERR_MILESTONE_NOT_FOUND))
      (project (unwrap! (map-get? projects (get project-id milestone)) ERR_PROJECT_NOT_FOUND))
      (release-amount (if (< (get funding-amount milestone) 
                            (- (get current-funding project) (get funds-released project)))
                         (get funding-amount milestone)
                         (- (get current-funding project) (get funds-released project))))
    )
    (asserts! (is-eq tx-sender (get creator project)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-approved milestone) ERR_INSUFFICIENT_APPROVALS)
    (asserts! (not (get is-released milestone)) ERR_MILESTONE_ALREADY_APPROVED)
    (asserts! (> release-amount u0) ERR_NO_FUNDS_TO_WITHDRAW)
    (try! (as-contract (stx-transfer? release-amount tx-sender (get creator project))))
    (map-set project-milestones milestone-id
      (merge milestone { is-released: true })
    )
    (map-set projects (get project-id milestone)
      (merge project { funds-released: (+ (get funds-released project) release-amount) })
    )
    (ok release-amount)
  )
)
(define-public (refund-project (project-id uint))
  (let
    (
      (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
      (user-funding (default-to u0 (map-get? user-total-funded { project-id: project-id, user: tx-sender })))
      (refund-amount (- user-funding u0))
    )
    (asserts! (>= stacks-block-height (get end-block project)) ERR_PROJECT_NOT_ENDED)
    (asserts! (< (get current-funding project) (get funding-goal project)) ERR_REFUND_NOT_AVAILABLE)
    (asserts! (> user-funding u0) ERR_NO_FUNDS_TO_WITHDRAW)
    (try! (as-contract (stx-transfer? refund-amount tx-sender tx-sender)))
    (map-set user-total-funded 
      { project-id: project-id, user: tx-sender }
      u0
    )
    (ok refund-amount)
  )
)

(define-public (end-project (project-id uint))
  (let
    (
      (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get creator project)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active project) ERR_PROJECT_ENDED)
    (map-set projects project-id
      (merge project { is-active: false })
    )
    (ok true)
  )
)

(define-read-only (get-project (project-id uint))
  (map-get? projects project-id)
)

(define-read-only (get-milestone (milestone-id uint))
  (map-get? project-milestones milestone-id)
)

(define-read-only (get-user-funding (project-id uint) (user principal))
  (default-to u0 (map-get? user-total-funded { project-id: project-id, user: user }))
)

(define-read-only (get-project-count)
  (var-get project-counter)
)

(define-read-only (get-milestone-count)
  (var-get milestone-counter)
)

(define-read-only (has-voted-milestone (milestone-id uint) (voter principal))
  (default-to false (map-get? milestone-votes { milestone-id: milestone-id, voter: voter }))
)
