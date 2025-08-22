;; NFT Bundle Contract
;; A system for creating and trading NFT bundles on Stacks blockchain
;; Allows users to bundle multiple NFTs together and trade them as a single unit

;; Define the NFT bundle token
(define-non-fungible-token nft-bundle uint)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-bundle-not-found (err u102))
(define-constant err-invalid-bundle-id (err u103))
(define-constant err-bundle-already-exists (err u104))
(define-constant err-insufficient-payment (err u105))
(define-constant err-transfer-failed (err u106))

;; Data variables
(define-data-var next-bundle-id uint u1)
(define-data-var total-bundles uint u0)

;; Bundle structure mapping
(define-map bundle-data uint {
    creator: principal,
    name: (string-ascii 64),
    description: (string-ascii 256),
    nft-count: uint,
    price: uint,
    is-active: bool
})

;; Track NFT ownership within bundles
(define-map bundle-nfts uint (list 20 {contract: principal, token-id: uint}))

;; Bundle ownership tracking
(define-map bundle-owners uint principal)

;; Function 1: Create NFT Bundle
;; Allows users to create a bundle containing multiple NFTs with metadata and pricing
(define-public (create-bundle 
    (name (string-ascii 64))
    (description (string-ascii 256))
    (nfts (list 20 {contract: principal, token-id: uint}))
    (price uint))
  (let ((bundle-id (var-get next-bundle-id)))
    (begin
      ;; Validate inputs
      (asserts! (> (len name) u0) err-invalid-bundle-id)
      (asserts! (> (len nfts) u0) err-invalid-bundle-id)
      (asserts! (> price u0) err-invalid-bundle-id)
      
      ;; Create bundle metadata
      (map-set bundle-data bundle-id {
        creator: tx-sender,
        name: name,
        description: description,
        nft-count: (len nfts),
        price: price,
        is-active: true
      })
      
      ;; Store NFT list for this bundle
      (map-set bundle-nfts bundle-id nfts)
      
      ;; Set bundle owner
      (map-set bundle-owners bundle-id tx-sender)
      
      ;; Mint the bundle NFT to creator
      (try! (nft-mint? nft-bundle bundle-id tx-sender))
      
      ;; Update counters
      (var-set next-bundle-id (+ bundle-id u1))
      (var-set total-bundles (+ (var-get total-bundles) u1))
      
      ;; Return success with bundle ID
      (ok {bundle-id: bundle-id, status: "Bundle created successfully"}))))

;; Function 2: Trade/Purchase NFT Bundle
;; Allows users to purchase an existing NFT bundle by paying the set price
(define-public (purchase-bundle (bundle-id uint))
  (let (
    (bundle-info (unwrap! (map-get? bundle-data bundle-id) err-bundle-not-found))
    (current-owner (unwrap! (map-get? bundle-owners bundle-id) err-bundle-not-found))
    (bundle-price (get price bundle-info))
  )
    (begin
      ;; Validate bundle exists and is active
      (asserts! (get is-active bundle-info) err-bundle-not-found)
      (asserts! (not (is-eq tx-sender current-owner)) err-not-authorized)
      
      ;; Transfer STX payment to current owner
      (try! (stx-transfer? bundle-price tx-sender current-owner))
      
      ;; Transfer bundle NFT to buyer
      (try! (nft-transfer? nft-bundle bundle-id current-owner tx-sender))
      
      ;; Update bundle owner
      (map-set bundle-owners bundle-id tx-sender)
      
      ;; Return success
      (ok {
        bundle-id: bundle-id,
        new-owner: tx-sender,
        price-paid: bundle-price,
        status: "Bundle purchased successfully"
      }))))

;; Read-only functions

;; Get bundle information
(define-read-only (get-bundle-info (bundle-id uint))
  (match (map-get? bundle-data bundle-id)
    bundle-data (ok bundle-data)
    err-bundle-not-found))

;; Get bundle NFTs
(define-read-only (get-bundle-nfts (bundle-id uint))
  (match (map-get? bundle-nfts bundle-id)
    nft-list (ok nft-list)
    err-bundle-not-found))

;; Get bundle owner
(define-read-only (get-bundle-owner (bundle-id uint))
  (match (nft-get-owner? nft-bundle bundle-id)
    owner (ok owner)
    err-bundle-not-found))

;; Get next bundle ID
(define-read-only (get-next-bundle-id)
  (ok (var-get next-bundle-id)))

;; Get total bundles created
(define-read-only (get-total-bundles)
  (ok (var-get total-bundles)))

;; Check if bundle is active
(define-read-only (is-bundle-active (bundle-id uint))
  (match (map-get? bundle-data bundle-id)
    bundle-data (ok (get is-active bundle-data))
    err-bundle-not-found))