;; Compensation Tracking Contract
;; Processes jury service payment and mileage reimbursements

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-INPUT (err u401))
(define-constant ERR-JUROR-NOT-FOUND (err u402))
(define-constant ERR-PAYMENT-ALREADY-PROCESSED (err u403))
(define-constant ERR-INSUFFICIENT-FUNDS (err u404))

;; Data Variables
(define-data-var daily-service-fee uint u40) ;; $40 per day in cents
(define-data-var mileage-rate uint u58) ;; $0.58 per mile in cents
(define-data-var next-payment-id uint u1)
(define-data-var contract-balance uint u0)

;; Data Maps
(define-map service-records
  { juror-id: uint, service-date: uint }
  {
    court-id: uint,
    hours-served: uint,
    miles-traveled: uint,
    service-type: (string-ascii 50), ;; "jury-duty", "grand-jury", "voir-dire"
    payment-status: (string-ascii 20),
    payment-id: (optional uint)
  }
)

(define-map payment-records
  { payment-id: uint }
  {
    juror-id: uint,
    service-fee: uint,
    mileage-reimbursement: uint,
    total-amount: uint,
    payment-date: uint,
    payment-method: (string-ascii 20),
    tax-year: uint,
    processed: bool
  }
)

(define-map juror-totals
  { juror-id: uint, tax-year: uint }
  {
    total-service-days: uint,
    total-service-fees: uint,
    total-mileage-reimbursement: uint,
    total-compensation: uint,
    tax-form-generated: bool
  }
)

(define-map expense-claims
  { claim-id: uint }
  {
    juror-id: uint,
    service-date: uint,
    expense-type: (string-ascii 50),
    amount: uint,
    description: (string-ascii 200),
    receipt-provided: bool,
    approval-status: (string-ascii 20),
    reimbursement-date: (optional uint)
  }
)

;; Private Functions
(define-private (calculate-service-fee (hours-served uint))
  (if (<= hours-served u4)
    (/ (var-get daily-service-fee) u2) ;; Half day
    (var-get daily-service-fee) ;; Full day
  )
)

(define-private (calculate-mileage-reimbursement (miles uint))
  (* miles (var-get mileage-rate))
)

(define-private (get-tax-year (date uint))
  ;; Simplified tax year calculation
  ;; In practice, this would properly parse the date
  (+ u2024 (/ date u31536000)) ;; Rough approximation
)

;; Public Functions
(define-public (record-service
  (juror-id uint)
  (service-date uint)
  (court-id uint)
  (hours-served uint)
  (miles-traveled uint)
  (service-type (string-ascii 50))
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> hours-served u0) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? service-records { juror-id: juror-id, service-date: service-date })) ERR-PAYMENT-ALREADY-PROCESSED)

    (map-set service-records
      { juror-id: juror-id, service-date: service-date }
      {
        court-id: court-id,
        hours-served: hours-served,
        miles-traveled: miles-traveled,
        service-type: service-type,
        payment-status: "pending",
        payment-id: none
      }
    )
    (ok true)
  )
)

(define-public (process-payment (juror-id uint) (service-date uint))
  (let (
    (service-record (unwrap! (map-get? service-records { juror-id: juror-id, service-date: service-date }) ERR-JUROR-NOT-FOUND))
    (payment-id (var-get next-payment-id))
    (service-fee (calculate-service-fee (get hours-served service-record)))
    (mileage-reimbursement (calculate-mileage-reimbursement (get miles-traveled service-record)))
    (total-amount (+ service-fee mileage-reimbursement))
    (current-date (unwrap-panic (get-block-info? time (- block-height u1))))
    (tax-year (get-tax-year service-date))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get payment-status service-record) "pending") ERR-PAYMENT-ALREADY-PROCESSED)
    (asserts! (>= (var-get contract-balance) total-amount) ERR-INSUFFICIENT-FUNDS)

    (var-set next-payment-id (+ payment-id u1))
    (var-set contract-balance (- (var-get contract-balance) total-amount))

    ;; Create payment record
    (map-set payment-records
      { payment-id: payment-id }
      {
        juror-id: juror-id,
        service-fee: service-fee,
        mileage-reimbursement: mileage-reimbursement,
        total-amount: total-amount,
        payment-date: current-date,
        payment-method: "direct-deposit",
        tax-year: tax-year,
        processed: true
      }
    )

    ;; Update service record
    (map-set service-records
      { juror-id: juror-id, service-date: service-date }
      (merge service-record
        {
          payment-status: "paid",
          payment-id: (some payment-id)
        }
      )
    )

    ;; Update juror totals
    (map-set juror-totals
      { juror-id: juror-id, tax-year: tax-year }
      (match (map-get? juror-totals { juror-id: juror-id, tax-year: tax-year })
        existing-totals
        {
          total-service-days: (+ (get total-service-days existing-totals) u1),
          total-service-fees: (+ (get total-service-fees existing-totals) service-fee),
          total-mileage-reimbursement: (+ (get total-mileage-reimbursement existing-totals) mileage-reimbursement),
          total-compensation: (+ (get total-compensation existing-totals) total-amount),
          tax-form-generated: false
        }
        {
          total-service-days: u1,
          total-service-fees: service-fee,
          total-mileage-reimbursement: mileage-reimbursement,
          total-compensation: total-amount,
          tax-form-generated: false
        }
      )
    )

    (ok payment-id)
  )
)

(define-public (submit-expense-claim
  (juror-id uint)
  (service-date uint)
  (expense-type (string-ascii 50))
  (amount uint)
  (description (string-ascii 200))
  (receipt-provided bool)
)
  (let ((claim-id (var-get next-payment-id)))
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (is-some (map-get? service-records { juror-id: juror-id, service-date: service-date })) ERR-JUROR-NOT-FOUND)

    (var-set next-payment-id (+ claim-id u1))

    (map-set expense-claims
      { claim-id: claim-id }
      {
        juror-id: juror-id,
        service-date: service-date,
        expense-type: expense-type,
        amount: amount,
        description: description,
        receipt-provided: receipt-provided,
        approval-status: "pending",
        reimbursement-date: none
      }
    )
    (ok claim-id)
  )
)

(define-public (approve-expense-claim (claim-id uint) (approved bool))
  (let ((current-date (unwrap-panic (get-block-info? time (- block-height u1)))))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? expense-claims { claim-id: claim-id })) ERR-JUROR-NOT-FOUND)

    (map-set expense-claims
      { claim-id: claim-id }
      (merge
        (unwrap-panic (map-get? expense-claims { claim-id: claim-id }))
        {
          approval-status: (if approved "approved" "denied"),
          reimbursement-date: (if approved (some current-date) none)
        }
      )
    )
    (ok approved)
  )
)

(define-public (fund-contract (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-INPUT)

    (var-set contract-balance (+ (var-get contract-balance) amount))
    (ok (var-get contract-balance))
  )
)

(define-public (generate-tax-form (juror-id uint) (tax-year uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? juror-totals { juror-id: juror-id, tax-year: tax-year })) ERR-JUROR-NOT-FOUND)

    (map-set juror-totals
      { juror-id: juror-id, tax-year: tax-year }
      (merge
        (unwrap-panic (map-get? juror-totals { juror-id: juror-id, tax-year: tax-year }))
        { tax-form-generated: true }
      )
    )
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-service-record (juror-id uint) (service-date uint))
  (map-get? service-records { juror-id: juror-id, service-date: service-date })
)

(define-read-only (get-payment-record (payment-id uint))
  (map-get? payment-records { payment-id: payment-id })
)

(define-read-only (get-juror-totals (juror-id uint) (tax-year uint))
  (map-get? juror-totals { juror-id: juror-id, tax-year: tax-year })
)

(define-read-only (get-expense-claim (claim-id uint))
  (map-get? expense-claims { claim-id: claim-id })
)

(define-read-only (calculate-compensation (hours-served uint) (miles-traveled uint))
  {
    service-fee: (calculate-service-fee hours-served),
    mileage-reimbursement: (calculate-mileage-reimbursement miles-traveled),
    total: (+ (calculate-service-fee hours-served) (calculate-mileage-reimbursement miles-traveled))
  }
)

(define-read-only (get-contract-balance)
  (var-get contract-balance)
)
