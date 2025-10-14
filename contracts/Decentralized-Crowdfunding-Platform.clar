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

(define-constant CATEGORY_TECH u1)
(define-constant CATEGORY_ART u2)
(define-constant CATEGORY_GAMES u3)
(define-constant CATEGORY_FILM u4)
(define-constant CATEGORY_MUSIC u5)
(define-constant CATEGORY_PUBLISHING u6)
(define-constant CATEGORY_FOOD u7)
(define-constant CATEGORY_FASHION u8)
(define-constant CATEGORY_OTHER u9)

(define-constant ERR_UPDATE_NOT_FOUND (err u301))
(define-constant ERR_INVALID_UPDATE_TYPE (err u302))

(define-constant UPDATE_TYPE_PROGRESS u1)
(define-constant UPDATE_TYPE_NEWS u2)  
(define-constant UPDATE_TYPE_DELAY u3)
(define-constant UPDATE_TYPE_COMPLETION u4)

(define-constant ERR_REWARD_NOT_FOUND (err u400))
(define-constant ERR_REWARD_ALREADY_CLAIMED (err u401))
(define-constant ERR_INSUFFICIENT_FUNDING_FOR_REWARD (err u402))
(define-constant ERR_REWARD_LIMIT_REACHED (err u403))

(define-data-var reward-counter uint u0)

(define-data-var update-counter uint u0)

(define-constant ERR_INVALID_CATEGORY (err u200))

(define-data-var featured-project-id uint u0)

(define-constant ERR_REPUTATION_UPDATE_FAILED (err u111))
(define-constant ERR_INVALID_RATING (err u112))
(define-constant ERR_ALREADY_RATED (err u113))

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

(define-map creator-reputation
  principal
  {
    total-projects: uint,
    successful-projects: uint,
    total-funding-raised: uint,
    milestones-completed: uint,
    total-milestones: uint,
    reputation-score: uint
  }
)

(define-map project-ratings
  { project-id: uint, rater: principal }
  { rating: uint, has-rated: bool }
)

(define-map project-rating-summary
  uint
  { total-ratings: uint, rating-sum: uint, average-rating: uint }
)

(define-public (rate-project (project-id uint) (rating uint))
  (let
    (
      (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
      (user-funded (default-to u0 (map-get? user-total-funded { project-id: project-id, user: tx-sender })))
      (already-rated (default-to false (get has-rated (map-get? project-ratings { project-id: project-id, rater: tx-sender }))))
      (current-summary (default-to { total-ratings: u0, rating-sum: u0, average-rating: u0 } 
                        (map-get? project-rating-summary project-id)))
    )
    (asserts! (> user-funded u0) ERR_NOT_AUTHORIZED)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    (asserts! (not already-rated) ERR_ALREADY_RATED)
    (asserts! (not (get is-active project)) ERR_PROJECT_NOT_ENDED)
    (map-set project-ratings
      { project-id: project-id, rater: tx-sender }
      { rating: rating, has-rated: true }
    )
    (let
      (
        (new-total (+ (get total-ratings current-summary) u1))
        (new-sum (+ (get rating-sum current-summary) rating))
        (new-average (/ new-sum new-total))
      )
      (map-set project-rating-summary project-id
        { total-ratings: new-total, rating-sum: new-sum, average-rating: new-average }
      )
      (ok true)
    )
  )
)

(define-public (update-creator-reputation (project-id uint))
  (let
    (
      (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
      (creator (get creator project))
      (current-rep (default-to 
        { total-projects: u0, successful-projects: u0, total-funding-raised: u0, 
          milestones-completed: u0, total-milestones: u0, reputation-score: u0 }
        (map-get? creator-reputation creator)))
      (project-successful (>= (get current-funding project) (get funding-goal project)))
    )
    (asserts! (not (get is-active project)) ERR_PROJECT_NOT_ENDED)
    (let
      (
        (new-total-projects (+ (get total-projects current-rep) u1))
        (new-successful (if project-successful 
                          (+ (get successful-projects current-rep) u1) 
                          (get successful-projects current-rep)))
        (new-total-funding (+ (get total-funding-raised current-rep) (get current-funding project)))
        (success-rate (if (> new-total-projects u0) (/ (* new-successful u100) new-total-projects) u0))
        (new-score (+ success-rate (/ new-total-funding u1000000)))
      )
      (map-set creator-reputation creator
        {
          total-projects: new-total-projects,
          successful-projects: new-successful,
          total-funding-raised: new-total-funding,
          milestones-completed: (get milestones-completed current-rep),
          total-milestones: (get total-milestones current-rep),
          reputation-score: new-score
        }
      )
      (ok new-score)
    )
  )
)

(define-read-only (get-creator-reputation (creator principal))
  (map-get? creator-reputation creator)
)

(define-read-only (get-project-rating (project-id uint))
  (map-get? project-rating-summary project-id)
)


(define-map project-categories
  uint
  { category: uint, tags: (list 3 (string-ascii 20)), is-featured: bool }
)

(define-map category-stats
  uint
  { total-projects: uint, total-funding: uint, successful-projects: uint }
)

(define-map category-projects
  { category: uint, index: uint }
  uint
)

(define-map category-counters
  uint
  uint
)

(define-public (set-project-category (project-id uint) (category uint) (tags (list 3 (string-ascii 20))))
  (let
    (
      (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
      (category-count (default-to u0 (map-get? category-counters category)))
    )
    (asserts! (is-eq tx-sender (get creator project)) ERR_NOT_AUTHORIZED)
    (asserts! (and (>= category u1) (<= category u9)) ERR_INVALID_CATEGORY)
    (map-set project-categories project-id
      { category: category, tags: tags, is-featured: false }
    )
    (map-set category-projects
      { category: category, index: category-count }
      project-id
    )
    (map-set category-counters category (+ category-count u1))
    (map-set category-stats category
      (merge (default-to { total-projects: u0, total-funding: u0, successful-projects: u0 }
                          (map-get? category-stats category))
             { total-projects: (+ (default-to u0 (get total-projects (map-get? category-stats category))) u1) })
    )
    (ok true)
  )
)

(define-public (feature-project (project-id uint))
  (let
    (
      (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
      (category-data (unwrap! (map-get? project-categories project-id) ERR_PROJECT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set featured-project-id project-id)
    (map-set project-categories project-id
      (merge category-data { is-featured: true })
    )
    (ok true)
  )
)

(define-read-only (get-projects-by-category (category uint) (limit uint))
  (list
    (map-get? category-projects { category: category, index: u0 })
    (map-get? category-projects { category: category, index: u1 })
    (map-get? category-projects { category: category, index: u2 })
    (map-get? category-projects { category: category, index: u3 })
    (map-get? category-projects { category: category, index: u4 })
  )
)

(define-read-only (get-category-project-at-index (params { category: uint, index: uint }))
  (map-get? category-projects params)
)

(define-read-only (get-project-category (project-id uint))
  (map-get? project-categories project-id)
)

(define-read-only (get-category-stats (category uint))
  (map-get? category-stats category)
)

(define-read-only (get-featured-project)
  (var-get featured-project-id)
)


(define-map project-updates
  uint
  {
    project-id: uint,
    creator: principal,
    title: (string-ascii 80),
    content: (string-ascii 300),
    update-type: uint,
    timestamp: uint,
    block-height: uint
  }
)

(define-map project-update-indices
  { project-id: uint, index: uint }
  uint
)

(define-map project-update-counts
  uint
  uint
)

(define-public (post-project-update 
  (project-id uint) 
  (title (string-ascii 80)) 
  (content (string-ascii 300)) 
  (update-type uint))
  (let
    (
      (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
      (update-id (+ (var-get update-counter) u1))
      (current-count (default-to u0 (map-get? project-update-counts project-id)))
    )
    (asserts! (is-eq tx-sender (get creator project)) ERR_NOT_AUTHORIZED)
    (asserts! (and (>= update-type u1) (<= update-type u4)) ERR_INVALID_UPDATE_TYPE)
    (map-set project-updates update-id
      {
        project-id: project-id,
        creator: tx-sender,
        title: title,
        content: content,
        update-type: update-type,
        timestamp: stacks-block-height,
        block-height: stacks-block-height
      }
    )
    (map-set project-update-indices
      { project-id: project-id, index: current-count }
      update-id
    )
    (map-set project-update-counts project-id (+ current-count u1))
    (var-set update-counter update-id)
    (ok update-id)
  )
)

(define-read-only (get-project-update (update-id uint))
  (map-get? project-updates update-id)
)

(define-read-only (get-project-updates (project-id uint) (start-index uint) (count uint))
  (let
    (
      (total-updates (default-to u0 (map-get? project-update-counts project-id)))
      (end-index (if (> (+ start-index count) total-updates) total-updates (+ start-index count)))
    )
    (map get-update-at-index 
      (list 
        { project-id: project-id, index: start-index }
        { project-id: project-id, index: (+ start-index u1) }
        { project-id: project-id, index: (+ start-index u2) }
      )
    )
  )
)

(define-read-only (get-update-at-index (params { project-id: uint, index: uint }))
  (let
    (
      (update-id (map-get? project-update-indices params))
    )
    (match update-id
      id (map-get? project-updates id)
      none
    )
  )
)

(define-read-only (get-project-update-count (project-id uint))
  (default-to u0 (map-get? project-update-counts project-id))
)

(define-map project-rewards
  uint
  {
    project-id: uint,
    tier-name: (string-ascii 50),
    min-contribution: uint,
    max-claims: uint,
    current-claims: uint,
    description: (string-ascii 200),
    is-active: bool
  }
)

(define-map reward-claims
  { reward-id: uint, claimer: principal }
  { claimed-at: uint, contribution-amount: uint }
)

(define-map project-reward-indices
  { project-id: uint, index: uint }
  uint
)

(define-map project-reward-counts
  uint
  uint
)

(define-public (create-reward-tier
  (project-id uint)
  (tier-name (string-ascii 50))
  (min-contribution uint)
  (max-claims uint)
  (description (string-ascii 200)))
  (let
    (
      (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
      (reward-id (+ (var-get reward-counter) u1))
      (current-count (default-to u0 (map-get? project-reward-counts project-id)))
    )
    (asserts! (is-eq tx-sender (get creator project)) ERR_NOT_AUTHORIZED)
    (map-set project-rewards reward-id
      {
        project-id: project-id,
        tier-name: tier-name,
        min-contribution: min-contribution,
        max-claims: max-claims,
        current-claims: u0,
        description: description,
        is-active: true
      }
    )
    (map-set project-reward-indices { project-id: project-id, index: current-count } reward-id)
    (map-set project-reward-counts project-id (+ current-count u1))
    (var-set reward-counter reward-id)
    (ok reward-id)
  )
)

(define-public (claim-reward (reward-id uint))
  (let
    (
      (reward (unwrap! (map-get? project-rewards reward-id) ERR_REWARD_NOT_FOUND))
      (user-funded (default-to u0 (map-get? user-total-funded 
        { project-id: (get project-id reward), user: tx-sender })))
      (already-claimed (is-some (map-get? reward-claims { reward-id: reward-id, claimer: tx-sender })))
    )
    (asserts! (get is-active reward) ERR_REWARD_NOT_FOUND)
    (asserts! (>= user-funded (get min-contribution reward)) ERR_INSUFFICIENT_FUNDING_FOR_REWARD)
    (asserts! (not already-claimed) ERR_REWARD_ALREADY_CLAIMED)
    (asserts! (< (get current-claims reward) (get max-claims reward)) ERR_REWARD_LIMIT_REACHED)
    (map-set reward-claims { reward-id: reward-id, claimer: tx-sender }
      { claimed-at: stacks-block-height, contribution-amount: user-funded }
    )
    (map-set project-rewards reward-id
      (merge reward { current-claims: (+ (get current-claims reward) u1) })
    )
    (ok true)
  )
)

(define-read-only (get-reward-tier (reward-id uint))
  (map-get? project-rewards reward-id)
)

(define-read-only (has-claimed-reward (reward-id uint) (user principal))
  (is-some (map-get? reward-claims { reward-id: reward-id, claimer: user }))
)

(define-read-only (get-project-reward-count (project-id uint))
  (default-to u0 (map-get? project-reward-counts project-id))
)