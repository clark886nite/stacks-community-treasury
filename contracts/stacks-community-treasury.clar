;; -----------------------------------------------------
;; Stacks Community Treasury (SCT) Smart Contract
;; -----------------------------------------------------
;; A decentralized funding system where users stake STX,
;; submit proposals, and vote on fund distribution.
;; -----------------------------------------------------

;; ------------------- Constants -------------------
(define-constant ADMIN tx-sender) ;; Admin for setup
(define-constant MIN_PROPOSAL_FEE u1000000) ;; Fee to submit a proposal
(define-constant TREASURY_FEE_PERCENTAGE u2) ;; Fee taken from approved proposals (2%)
(define-constant ERR-UNAUTHORIZED u1000)
(define-constant ERR-ZERO-AMOUNT u100)
(define-constant ERR-TRANSFER-FAILED u101)
(define-constant ERR-INSUFFICIENT-BALANCE u102)
(define-constant ERR-INVALID-AMOUNT u103)
(define-constant ERR-INSUFFICIENT-TREASURY u104)
(define-constant ERR-PROPOSAL-FEE-FAILED u105)
(define-constant ERR-ALREADY-EXECUTED u106)
(define-constant ERR-NOT-FOUND u107)
(define-constant ERR-NOT-EXECUTED u108)
(define-constant ERR-PROPOSAL-REJECTED u109)
(define-constant ERR-TREASURY-DEPLETED u110)
(define-constant ERR-NO-STAKE u111)
(define-constant ERR-ALREADY-VOTED u112)

;; ------------------- Data Storage -------------------
(define-data-var total-staked uint u0) ;; Total staked STX
(define-data-var treasury-balance uint u0) ;; Treasury balance
(define-data-var proposal-counter uint u0) ;; Total proposals created

(define-map user-stakes { user: principal } uint) ;; Users' staked balances
(define-map proposals { id: uint }
  (tuple 
    (creator principal) 
    (amount uint) 
    (yes-votes uint) 
    (no-votes uint) 
    (executed bool)
  )) ;; Proposals

;; Track who has voted on which proposals
(define-map votes 
  { proposal-id: uint, voter: principal } 
  { voted: bool }
)

;; ------------------- Stake STX -------------------
(define-public (stake (amount uint))
  (begin
    (asserts! (> amount u0) (err ERR-ZERO-AMOUNT)) ;; Ensure positive stake amount
    (match (stx-transfer? amount tx-sender (as-contract tx-sender))
      success
        (let ((current-stake (default-to u0 (map-get? user-stakes { user: tx-sender }))))
          (map-set user-stakes { user: tx-sender } (+ current-stake amount))
          (var-set total-staked (+ (var-get total-staked) amount))
          (var-set treasury-balance (+ (var-get treasury-balance) amount))
          (ok true))
      error (err ERR-TRANSFER-FAILED) ;; Transfer failed
    )
  )
)

;; ------------------- Withdraw STX -------------------
(define-public (withdraw (amount uint))
  (let ((current-stake (default-to u0 (map-get? user-stakes { user: tx-sender }))))
    (begin
      (asserts! (>= current-stake amount) (err ERR-INSUFFICIENT-BALANCE)) ;; Ensure sufficient balance
      (match (stx-transfer? amount (as-contract tx-sender) tx-sender)
        success
          (begin
            (map-set user-stakes { user: tx-sender } (- current-stake amount))
            (var-set total-staked (- (var-get total-staked) amount))
            (var-set treasury-balance (- (var-get treasury-balance) amount))
            (ok true))
        error (err ERR-TRANSFER-FAILED) ;; Transfer failed
      )
    )
  )
)

;; ------------------- Create Proposal -------------------
(define-public (create-proposal (amount uint))
  (begin
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT)) ;; Proposal amount must be > 0
    (asserts! (<= amount (var-get treasury-balance)) (err ERR-INSUFFICIENT-TREASURY)) ;; Check treasury funds
    (match (stx-transfer? MIN_PROPOSAL_FEE tx-sender (as-contract tx-sender))
      success
        (let ((proposal-id (+ (var-get proposal-counter) u1)))
          (var-set proposal-counter proposal-id)
          (map-set proposals { id: proposal-id }
            { creator: tx-sender, amount: amount, yes-votes: u0, no-votes: u0, executed: false })
          (ok proposal-id))
      error (err ERR-PROPOSAL-FEE-FAILED) ;; Proposal fee transfer failed
    )
  )
)

;; ------------------- Vote on Proposal -------------------
(define-public (vote (proposal-id uint) (approve bool))
  (let (
    (user-stake (default-to u0 (map-get? user-stakes { user: tx-sender })))
    (has-voted (map-get? votes { proposal-id: proposal-id, voter: tx-sender }))
  )
    (begin
      ;; Check if user has staked tokens
      (asserts! (> user-stake u0) (err ERR-NO-STAKE))
      
      ;; Check if user has already voted
      (asserts! (is-none has-voted) (err ERR-ALREADY-VOTED))
      
      ;; Get proposal safely
      (match (map-get? proposals { id: proposal-id })
        proposal
          (begin
            ;; Ensure proposal isn't executed
            (asserts! (not (get executed proposal)) (err ERR-ALREADY-EXECUTED))
            
            ;; Record the vote
            (map-set votes { proposal-id: proposal-id, voter: tx-sender } { voted: true })
            
            ;; Update proposal votes based on stake amount
            (map-set proposals { id: proposal-id }
              (merge proposal { 
                yes-votes: (if approve (+ (get yes-votes proposal) user-stake) (get yes-votes proposal)),
                no-votes: (if (not approve) (+ (get no-votes proposal) user-stake) (get no-votes proposal))
              }))
            (ok true))
        (err ERR-NOT-FOUND) ;; Proposal not found
      )
    )
  )
)

;; ------------------- Execute Proposal -------------------
(define-public (execute-proposal (proposal-id uint))
  (begin
    ;; Get proposal safely
    (match (map-get? proposals { id: proposal-id })
      proposal
        (begin
          ;; Ensure not already executed
          (asserts! (not (get executed proposal)) (err ERR-ALREADY-EXECUTED))
          
          ;; Majority approval
          (asserts! (> (get yes-votes proposal) (get no-votes proposal)) (err ERR-PROPOSAL-REJECTED))
          
          ;; Check treasury funds
          (asserts! (<= (get amount proposal) (var-get treasury-balance)) (err ERR-TREASURY-DEPLETED))
          
          (let (
            (fee (/ (* (get amount proposal) TREASURY_FEE_PERCENTAGE) u100)) ;; Calculate fee
            (funding-amount (- (get amount proposal) fee)) ;; Net amount after fee
          )
            (match (stx-transfer? funding-amount (as-contract tx-sender) (get creator proposal))
              success
                (begin
                  (map-set proposals { id: proposal-id } (merge proposal { executed: true }))
                  (var-set treasury-balance (- (var-get treasury-balance) (get amount proposal)))
                  (ok true))
              error (err ERR-TRANSFER-FAILED) ;; Transfer failed
            )
          )
        )
      (err ERR-NOT-FOUND) ;; Proposal not found
    )
  )
)

;; ------------------- Read-Only Functions -------------------
(define-read-only (get-user-stake (user principal))
  (ok (default-to u0 (map-get? user-stakes { user: user })))
)

(define-read-only (get-total-staked)
  (ok (var-get total-staked))
)

(define-read-only (get-treasury-balance)
  (ok (var-get treasury-balance))
)

(define-read-only (get-proposal (proposal-id uint))
  (ok (map-get? proposals { id: proposal-id }))
)

(define-read-only (has-voted (proposal-id uint) (user principal))
  (ok (is-some (map-get? votes { proposal-id: proposal-id, voter: user })))
)