;; TrustScore: DeFi Reputation Scoring Protocol
;; This contract manages reputation scores for DeFi users based on their transaction history,
;; liquidation events, protocol interactions, and overall behavior. It provides a comprehensive
;; reputation scoring system that can be used by other protocols for risk assessment and rewards.

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-USER-NOT-FOUND (err u101))
(define-constant ERR-INVALID-SCORE (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-ALREADY-EXISTS (err u104))
(define-constant ERR-CONTRACT-PAUSED (err u105))
(define-constant ERR-INVALID-ACTIVITY (err u106))

;; Reputation scoring constants
(define-constant MIN-REPUTATION-SCORE u0)
(define-constant MAX-REPUTATION-SCORE u1000)
(define-constant INITIAL-REPUTATION u500)
(define-constant LIQUIDATION-PENALTY u50)
(define-constant SUCCESSFUL-LOAN-BONUS u10)
(define-constant LARGE-TRANSACTION-BONUS u5)
(define-constant PROTOCOL-INTERACTION-BONUS u2)

;; Activity type constants
(define-constant ACTIVITY-LOAN-REPAID u1)
(define-constant ACTIVITY-LIQUIDATED u2)
(define-constant ACTIVITY-LARGE-TRANSACTION u3)
(define-constant ACTIVITY-PROTOCOL-INTERACTION u4)
(define-constant ACTIVITY-GOVERNANCE-VOTE u5)

;; Data Maps and Variables
(define-data-var contract-paused bool false)
(define-data-var total-users uint u0)
(define-data-var activity-counter uint u0)

;; Map: User -> Reputation Profile
(define-map user-reputation
  { user: principal }
  {
    reputation-score: uint,
    total-transactions: uint,
    successful-loans: uint,
    liquidations: uint,
    last-activity: uint,
    registration-block: uint,
    is-active: bool
  }
)

;; Map: Activity tracking for reputation calculation
(define-map user-activities
  { user: principal, activity-id: uint }
  {
    activity-type: uint,
    amount: uint,
    timestamp: uint,
    score-impact: int
  }
)

;; Map: Protocol interaction tracking
(define-map protocol-interactions
  { user: principal, protocol: (string-ascii 32) }
  { interaction-count: uint, last-interaction: uint }
)

;; Map: Reputation history for trending analysis
(define-map reputation-history
  { user: principal, period: uint }
  { score: uint, timestamp: uint }
)

;; Private Functions

;; Check if caller is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

;; Check if contract is active
(define-private (is-contract-active)
  (not (var-get contract-paused))
)

;; Validate reputation score bounds
(define-private (is-valid-score (score uint))
  (and (>= score MIN-REPUTATION-SCORE) (<= score MAX-REPUTATION-SCORE))
)

;; Calculate new reputation score with bounds checking
(define-private (calculate-new-score (current-score uint) (impact int))
  (let (
    (new-score-int (+ (to-int current-score) impact))
  )
    (if (< new-score-int (to-int MIN-REPUTATION-SCORE))
      MIN-REPUTATION-SCORE
      (if (> new-score-int (to-int MAX-REPUTATION-SCORE))
        MAX-REPUTATION-SCORE
        (to-uint new-score-int)
      )
    )
  )
)

;; Get activity impact score based on type
(define-private (get-activity-impact (activity-type uint) (amount uint))
  (if (is-eq activity-type ACTIVITY-LOAN-REPAID)
    (to-int SUCCESSFUL-LOAN-BONUS)
    (if (is-eq activity-type ACTIVITY-LIQUIDATED)
      (- (to-int LIQUIDATION-PENALTY))
      (if (is-eq activity-type ACTIVITY-LARGE-TRANSACTION)
        (if (> amount u1000000) ;; Large transaction threshold
          (to-int LARGE-TRANSACTION-BONUS)
          (to-int u0)
        )
        (if (is-eq activity-type ACTIVITY-PROTOCOL-INTERACTION)
          (to-int PROTOCOL-INTERACTION-BONUS)
          (if (is-eq activity-type ACTIVITY-GOVERNANCE-VOTE)
            (to-int u3)
            (to-int u0)
          )
        )
      )
    )
  )
)

;; Public Functions

;; Register a new user in the reputation system
(define-public (register-user)
  (begin
    (asserts! (is-contract-active) ERR-CONTRACT-PAUSED)
    (asserts! (is-none (map-get? user-reputation { user: tx-sender })) ERR-ALREADY-EXISTS)

    (map-set user-reputation
      { user: tx-sender }
      {
        reputation-score: INITIAL-REPUTATION,
        total-transactions: u0,
        successful-loans: u0,
        liquidations: u0,
        last-activity: block-height,
        registration-block: block-height,
        is-active: true
      }
    )

    (var-set total-users (+ (var-get total-users) u1))
    (ok true)
  )
)

;; Record user activity and update reputation
(define-public (record-activity (user principal) (activity-type uint) (amount uint))
  (begin
    (asserts! (is-contract-active) ERR-CONTRACT-PAUSED)

    (let (
      (user-profile (unwrap! (map-get? user-reputation { user: user }) ERR-USER-NOT-FOUND))
      (activity-id (var-get activity-counter))
      (score-impact (get-activity-impact activity-type amount))
      (new-score (calculate-new-score (get reputation-score user-profile) score-impact))
    )
      ;; Record the activity
      (map-set user-activities
        { user: user, activity-id: activity-id }
        {
          activity-type: activity-type,
          amount: amount,
          timestamp: block-height,
          score-impact: score-impact
        }
      )

      ;; Update user reputation profile
      (map-set user-reputation
        { user: user }
        (merge user-profile {
          reputation-score: new-score,
          total-transactions: (+ (get total-transactions user-profile) u1),
          successful-loans: (if (is-eq activity-type ACTIVITY-LOAN-REPAID)
            (+ (get successful-loans user-profile) u1)
            (get successful-loans user-profile)
          ),
          liquidations: (if (is-eq activity-type ACTIVITY-LIQUIDATED)
            (+ (get liquidations user-profile) u1)
            (get liquidations user-profile)
          ),
          last-activity: block-height
        })
      )

      (var-set activity-counter (+ activity-id u1))
      (ok { new-reputation: new-score, activity-id: activity-id })
    )
  )
)

;; Read-only Functions

;; Get user reputation profile
(define-read-only (get-user-reputation (user principal))
  (map-get? user-reputation { user: user })
)

;; Get user activity
(define-read-only (get-user-activity (user principal) (activity-id uint))
  (map-get? user-activities { user: user, activity-id: activity-id })
)

;; Get total registered users
(define-read-only (get-total-users)
  (var-get total-users)
)

;; Check if contract is paused
(define-read-only (is-paused)
  (var-get contract-paused)
)

;; Advanced Reputation Analytics and Risk Assessment System
;; This comprehensive function analyzes user behavior patterns, calculates risk metrics,
;; and provides detailed reputation insights for lending protocols and DeFi applications.
;; It includes trending analysis, behavioral scoring, and predictive risk assessment.
(define-public (calculate-comprehensive-risk-profile (user principal))
  (begin
    (asserts! (is-contract-active) ERR-CONTRACT-PAUSED)

    (let (
      (user-profile (unwrap! (map-get? user-reputation { user: user }) ERR-USER-NOT-FOUND))
      (reputation-score (get reputation-score user-profile))
      (total-transactions (get total-transactions user-profile))
      (successful-loans (get successful-loans user-profile))
      (liquidations (get liquidations user-profile))
      (account-age (- block-height (get registration-block user-profile)))

      ;; Calculate various risk metrics
      (liquidation-ratio (if (> total-transactions u0)
        (/ (* liquidations u100) total-transactions)
        u0
      ))
      (success-ratio (if (> total-transactions u0)
        (/ (* successful-loans u100) total-transactions)
        u0
      ))
      (activity-frequency (if (> account-age u0)
        (/ total-transactions account-age)
        u0
      ))

      ;; Risk scoring algorithm
      (base-risk-score (if (> reputation-score u750) u1   ;; Low risk
        (if (> reputation-score u500) u2           ;; Medium risk
          (if (> reputation-score u250) u3           ;; High risk
            u4                                  ;; Very high risk
          )
        )
      ))

      ;; Behavioral risk adjustments
      (liquidation-risk-adjustment (if (> liquidation-ratio u20) u2
        (if (> liquidation-ratio u10) u1 u0)
      ))
      (activity-risk-adjustment (if (< activity-frequency u1) u1 u0))
      (age-risk-adjustment (if (< account-age u144) u1 u0)) ;; Less than 1 day old

      ;; Final risk score calculation
      (total-risk-score (+ base-risk-score liquidation-risk-adjustment
                            activity-risk-adjustment age-risk-adjustment))

      ;; Credit worthiness calculation (inverted risk score with proper bounds checking)
      (creditworthiness (- u10 (if (> total-risk-score u10) u10 total-risk-score)))

      ;; Recommended lending limits based on risk profile
      (max-loan-amount (if (is-eq total-risk-score u1) u1000000       ;; Low risk: 1M
        (if (is-eq total-risk-score u2) u500000           ;; Medium-low: 500K
          (if (is-eq total-risk-score u3) u100000           ;; Medium: 100K
            (if (is-eq total-risk-score u4) u50000         ;; High: 50K
              u10000                                    ;; Very high: 10K
            )
          )
        )
      ))
    )

      ;; Store risk profile for future reference
      (map-set reputation-history
        { user: user, period: block-height }
        { score: reputation-score, timestamp: block-height }
      )

      (ok {
        user: user,
        reputation-score: reputation-score,
        risk-level: total-risk-score,
        creditworthiness: creditworthiness,
        liquidation-ratio: liquidation-ratio,
        success-ratio: success-ratio,
        account-age: account-age,
        activity-frequency: activity-frequency,
        max-recommended-loan: max-loan-amount,
        total-transactions: total-transactions,
        assessment-timestamp: block-height
      })
    )
  )
)

