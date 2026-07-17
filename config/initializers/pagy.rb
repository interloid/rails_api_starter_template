# Pagy 43+ config. NOTE: the classic pagy 9-era API changed here —
#   * `pagy/extras/overflow` no longer exists: returning an empty page for an
#     out-of-range :page is now Pagy's BUILT-IN default (Offset assigns empty-page
#     variables instead of raising), so the extra is unnecessary.
#   * `Pagy::DEFAULT` is frozen; the mutable defaults hash is `Pagy::OPTIONS`.
# Default page size = 20 (per_page is clamped per-request in Paginatable).
Pagy::OPTIONS[:limit] = 20
