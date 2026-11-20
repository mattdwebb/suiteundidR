# Exact set membership for RI assignment keys. R environment names are
# symbols limited to 10000 bytes; the full key must be a value, not a name.
# Short hash buckets keep lookups fast. Comparing full keys within each
# bucket prevents hash collisions from discarding distinct assignments.
.ri_key_bucket <- function(key) {
  code <- as.numeric(utf8ToInt(enc2utf8(key)))
  n <- length(code)
  index <- seq_len(n)
  forward <- sum((code * (index %% 65521 + 1)) %% 2147483647) %% 2147483647
  reverse <- sum((code * (rev(index) %% 65519 + 7)) %% 2147483629) %% 2147483629
  sprintf("h%.0f:%.0f:%d", forward, reverse, n)
}

.ri_key_has <- function(seen, key) {
  key %in% seen[[.ri_key_bucket(key)]]
}

.ri_key_add <- function(seen, key) {
  bucket <- .ri_key_bucket(key)
  keys <- seen[[bucket]]
  if (!key %in% keys) seen[[bucket]] <- c(keys, key)
  invisible(NULL)
}
