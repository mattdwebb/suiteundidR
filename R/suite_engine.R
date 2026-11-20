# Independently implemented reference engine; duplicated per standalone package.
.suite_error <- function(reason, detail = "") {
  stop(structure(list(message = paste(reason, detail), call = NULL,
                      reason = reason), class = c("suite_error", "error", "condition")))
}

.suite_prepare <- function(data, outcome, time, cluster, gvar, treatment,
                           covariates, unit, data_mode) {
  data_mode <- match.arg(data_mode, c("auto", "panel", "rcs"))
  if (data_mode == "auto") data_mode <- if (is.null(unit)) "rcs" else "panel"
  if (data_mode == "panel" && is.null(unit))
    .suite_error("UNSUPPORTED", "panel mode requires unit")
  cols <- unique(c(outcome, time, cluster, gvar, treatment, covariates, unit))
  if (!is.data.frame(data) || !all(cols %in% names(data)))
    .suite_error("INVALID_INPUT", "missing columns")
  if (is.null(gvar) && is.null(treatment))
    .suite_error("INVALID_INPUT", "supply gvar or treatment")
  if (anyNA(data[cols])) .suite_error("INVALID_INPUT", "missing values are not silently dropped")
  numeric_cols <- c(outcome, time, gvar, treatment, covariates)
  if (!all(vapply(data[numeric_cols], is.numeric, logical(1))) ||
      !all(is.finite(as.matrix(data[numeric_cols]))))
    .suite_error("INVALID_INPUT", "numeric variables must be finite")
  states <- sort(unique(data[[cluster]]))
  times <- sort(unique(data[[time]]))
  s <- match(data[[cluster]], states)
  tt <- match(data[[time]], times)
  G <- length(states); T <- length(times)
  cell <- (s - 1L) * T + tt
  n <- matrix(tabulate(cell, G * T), G, T, byrow = TRUE)
  rows <- split(seq_along(cell), factor(cell, levels=seq_len(G*T)))
  if (data_mode == "panel") {
    id <- data[[unit]]
    if (anyDuplicated(data.frame(id, tt))) .suite_error("INVALID_INPUT", "duplicate unit-time")
    if (any(vapply(split(s, id), function(z) length(unique(z)) != 1L, logical(1))))
      .suite_error("INVALID_INPUT", "unit changes cluster")
  }
  a <- numeric(G)
  for (i in seq_len(G)) {
    ii <- s == i
    if (!is.null(gvar)) {
      ag <- unique(data[[gvar]][ii])
      if (length(ag) != 1L || ag < 0)
        .suite_error("INVALID_INPUT", "gvar must be constant within cluster; never=0")
      a[i] <- ag
    }
    if (!is.null(treatment)) {
      d <- data[[treatment]][ii]
      t <- data[[time]][ii]
      if (!all(d %in% c(0, 1))) .suite_error("INVALID_INPUT", "treatment must be binary")
      ds <- vapply(split(d, t), function(z) {
        if (length(unique(z)) != 1L) .suite_error("INVALID_INPUT", "mixed treatment in cell")
        z[1L]
      }, numeric(1))
      ord <- order(as.numeric(names(ds)))
      ds <- ds[ord]
      dt <- as.numeric(names(ds))
      if (any(diff(ds) < 0)) .suite_error("INVALID_INPUT", "nonabsorbing treatment")
      inferred <- if (any(ds == 1)) min(dt[ds == 1]) else 0
      if (is.null(gvar)) a[i] <- inferred
      else if (any(d != as.numeric(a[i] > 0 & t >= a[i])))
        .suite_error("INVALID_INPUT", "gvar/treatment inconsistent")
    }
  }
  if (!any(a > 0) || !any(a == 0))
    .suite_error("IDENTIFICATION_FAILURE", "treated and never-treated clusters required")
  list(y = data[[outcome]], x = as.matrix(data[covariates]), s = s, tt = tt,
       cell = cell, rows = rows, n = n, states = states, times = times, a = a,
       data_mode = data_mode, covariates = covariates, G = G, T = T)
}

.suite_ols <- function(x, y) {
  s <- svd(x)
  use <- s$d > max(dim(x))* .Machine$double.eps * max(s$d)
  basis <- s$v[, use, drop=FALSE]
  list(beta=as.vector(basis %*% (crossprod(s$u[, use, drop=FALSE], y) / s$d[use])),
       null=diag(ncol(x)) - tcrossprod(basis))
}

.suite_core <- function(z, a, kind, ccc, omit = integer()) {
  active <- setdiff(seq_len(z$G), omit)
  controls <- active[a[active] == 0]
  if (!length(controls)) .suite_error("IDENTIFICATION_FAILURE", "no never-treated controls")
  cohorts <- sort(unique(a[active][a[active] > 0]))
  cell_rows <- function(i, t) z$rows[[(i-1L)*z$T+t]]
  identified <- function(target, null) max(abs(target %*% null)) <= 1e-9*max(1,abs(target))
  slope_null <- vector("list", z$G*z$T)
  k <- ncol(z$x)
  means <- matrix(NA_real_, z$G, z$T)
  xm <- array(0, c(z$G, z$T, k))
  slopes <- array(0, c(z$G, z$T, k))
  for (i in active) for (t in seq_len(z$T)) {
    rows <- cell_rows(i,t)
    if (!length(rows)) next
    means[i, t] <- mean(z$y[rows])
    if (k) xm[i, t, ] <- colMeans(z$x[rows, , drop = FALSE])
  }
  intercept <- means
  if (kind == "didint" && k) {
    keep <- z$s %in% active
    blocks <- switch(ccc, int = z$cell, state = z$s, time = z$tt,
                     hom = rep(1L, length(z$y)))
    for (rows in split(which(keep), blocks[keep])) {
      xx <- z$x[rows, , drop = FALSE]; yy <- z$y[rows]
      for (cell in unique(z$cell[rows])) {
        loc <- which(z$cell[rows] == cell)
        xx[loc, ] <- sweep(xx[loc, , drop = FALSE], 2, colMeans(xx[loc, , drop = FALSE]))
        yy[loc] <- yy[loc] - mean(yy[loc])
      }
      beta <- .suite_ols(xx, yy)
      cells <- unique(cbind(z$s[rows], z$tt[rows]))
      for (j in seq_len(nrow(cells))) {
        i <- cells[j, 1]; t <- cells[j, 2]
        slope_null[[(i-1L)*z$T+t]] <- beta$null
        slopes[i, t, ] <- beta$beta
        intercept[i, t] <- means[i, t] - sum(xm[i, t, ] * beta$beta)
      }
    }
  }
  records <- list()
  for (g in cohorts) {
    if (!any(z$times < g)) next
    base <- max(which(z$times < g))
    for (t in which(z$times >= g)) {
      delta <- rep(NA_real_, z$G)
      if (kind == "undid" && k) {
        for (i in active) {
          if (!all(z$n[i,c(base,t)] > 0)) next
          rows <- c(cell_rows(i,base), cell_rows(i,t))
          xx <- cbind(1, as.numeric(z$tt[rows] == t), z$x[rows, , drop = FALSE])
          fit <- .suite_ols(xx,z$y[rows])
          if (identified(as.numeric(seq_len(ncol(xx))==2L),fit$null)) delta[i] <- fit$beta[2L]
        }
      } else delta <- means[, t] - means[, base]
      for (i in active[a[active] == g]) {
        if (!all(z$n[i,c(base,t)]>0)) next
        if (kind == "didint" && k) {
          target <- xm[i, t, ]
          for (j in c(i, controls)) {
            delta[j] <- NA_real_
            if (!all(z$n[j,c(base,t)]>0)) next
            if (!identified(target-xm[j,t,], slope_null[[(j-1L)*z$T+t]]) ||
                !identified(target-xm[j,base,], slope_null[[(j-1L)*z$T+base]])) next
            delta[j] <- intercept[j, t] - intercept[j, base] +
              sum(target * (slopes[j, t, ] - slopes[j, base, ]))
          }
        }
        usable <- controls[is.finite(delta[controls])]
        if (!is.finite(delta[i]) || !length(usable)) next
        cw <- z$n[usable,t] + z$n[usable,base]
        effect <- delta[i] - weighted.mean(delta[usable],cw)
        records[[length(records) + 1L]] <- data.frame(
          cluster = as.character(z$states[i]), g = g, t = z$times[t],
          base_period = z$times[base], estimate = effect,
          target_weight = z$n[i, t], pair_weight=z$n[i,base]+z$n[i,t], control_count = length(usable))
      }
    }
  }
  if (!length(records)) .suite_error("IDENTIFICATION_FAILURE", "no identified treated-state comparisons")
  st <- do.call(rbind, records)
  if (identical(z$aggregation_weights,"comparison")) {
    gt <- interaction(st$g,st$t,drop=TRUE)
    st$target_weight <- st$pair_weight * ave(st$target_weight,gt,FUN=sum)/ave(st$pair_weight,gt,FUN=sum)
  }
  st$normalized_weight <- st$target_weight / sum(st$target_weight)
  estimate <- sum(st$estimate * st$normalized_weight)
  if (!is.finite(estimate)) .suite_error("NUMERICAL_FAILURE", "nonfinite estimate")
  list(estimate = estimate, att_st = st,
       cells_eligible=sum(vapply(active[a[active]>0],function(i) sum(z$times>=a[i]),integer(1))), support=st[c("cluster","g","t","control_count")])
}

.suite_jk <- function(z, a, kind, ccc, null) {
  estimate <- .suite_core(z, a, kind, ccc)$estimate
  deleted <- rep(NA_real_, z$G); failures <- character(z$G)
  for (i in seq_len(z$G)) {
    deleted[i] <- tryCatch(.suite_core(z, a, kind, ccc, i)$estimate,
      suite_error = function(e) { failures[i] <<- conditionMessage(e); NA_real_ })
  }
  names(deleted) <- as.character(z$states)
  status <- "PASS"; se <- stat <- p <- NA_real_
  if (anyNA(deleted)) status <- "IDENTIFICATION_FAILURE"
  else {
    se <- sqrt((z$G - 1) / z$G * sum((deleted - mean(deleted))^2))
    if (!is.finite(se) || se <= 64 * .Machine$double.eps * max(1, abs(estimate), abs(deleted)))
      status <- "NUMERICAL_FAILURE"
    else {
      stat <- (estimate - null) / se
      p <- 2 * stats::pt(-abs(stat), z$G - 1)
    }
  }
  list(status = status, standard_error = se, statistic = stat, p_value = p,
       df = z$G - 1L, delete_estimates = deleted, failures = failures)
}

.suite_assignments <- function(a, assignments, reps, seed, exact) {
  G <- length(a)
  space <- round(exp(lfactorial(G) - sum(lfactorial(as.numeric(table(a))))))
  if (is.null(assignments)) {
    if (length(reps) != 1L || !is.finite(reps) || reps < 1 || reps != floor(reps))
      .suite_error("INVALID_INPUT", "reps must be a positive integer")
    had_rng <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (had_rng) old_rng <- get(".Random.seed", envir = .GlobalEnv)
    on.exit(if (had_rng) assign(".Random.seed", old_rng, envir = .GlobalEnv)
            else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
              rm(".Random.seed", envir = .GlobalEnv))
    set.seed(seed)
    if (exact || (is.finite(space) && reps >= space - 1)) {
      if (!is.finite(space) || space > 100000)
        .suite_error("UNSUPPORTED", "exact assignment space exceeds 100000")
      ans <- list()
      visit <- function(prefix, rest) {
        if (!length(rest)) {
          if (!identical(as.numeric(prefix), as.numeric(a)))
            ans[[length(ans) + 1L]] <<- prefix
        } else for (v in sort(unique(rest))) {
          visit(c(prefix, v), rest[-match(v, rest)])
        }
      }
      visit(numeric(), a)
      assignments <- do.call(rbind, ans)
    } else {
      B <- min(reps, space - 1)
      assignments <- matrix(NA_real_, B, G)
      seen <- new.env(hash = TRUE, parent = emptyenv())
      key <- function(x) paste(format(x, digits = 17, scientific = TRUE), collapse = "|")
      .ri_key_add(seen, key(a))
      count <- 0L; tries <- 0L
      while (count < B) {
        tries <- tries + 1L
        if (tries > max(10000, 100 * B))
          .suite_error("NUMERICAL_FAILURE", "unique-assignment sampling budget exhausted")
        draw <- a[sample.int(G)]
        kk <- key(draw)
        if (!.ri_key_has(seen, kk)) {
          count <- count + 1L; assignments[count, ] <- draw
          .ri_key_add(seen, kk)
        }
      }
    }
  }
  if (!is.matrix(assignments) || !is.numeric(assignments) ||
      ncol(assignments) != G || nrow(assignments) < 1L ||
      any(!is.finite(assignments)))
    .suite_error("INVALID_INPUT", "assignments require finite B-by-G numeric matrix")
  if (anyDuplicated(as.data.frame(assignments)))
    .suite_error("INVALID_INPUT", "duplicate assignments")
  for (i in seq_len(nrow(assignments))) {
    if (!identical(sort(as.numeric(assignments[i, ])), sort(as.numeric(a))))
      .suite_error("INVALID_INPUT", "assignment cohort counts changed")
    if (all(assignments[i, ] == a))
      .suite_error("INVALID_INPUT", "observed assignment excluded")
  }
  list(matrix = assignments, space = space)
}

.suite_fit <- function(data, outcome, time, cluster, gvar = NULL, treatment = NULL,
                       covariates = character(), unit = NULL, data_mode = "auto",
                       inference = "point", assignments = NULL, reps = 999L,
                       seed = 0L, exact = FALSE, null = 0, kind, ccc = "int",
                       weights = NULL, control_group = "never",
                       weighting = "both", aggregation_weights = "post") {
  aggregation_weights <- match.arg(aggregation_weights,c("post","comparison"))
  if (!is.null(weights) || control_group != "never" || weighting != "both")
    .suite_error("UNSUPPORTED", "only unweighted observations, never controls, weighting=both")
  if (!ccc %in% c("int", "hom", "state", "time"))
    .suite_error("UNSUPPORTED", "unsupported CCC specification")
  if (!is.numeric(null) || length(null) != 1L || !is.finite(null))
    .suite_error("INVALID_INPUT", "null must be a finite scalar")
  if (length(inference) == 1L && inference == "standard") inference <- c("native", "jackknife")
  if (length(inference) == 1L && inference == "full")
    inference <- c("native", "jackknife", "ri_beta", "ri_t_native")
  if (any(!inference %in% c("point", "native", "jackknife", "ri_beta", "ri_t_native")))
    .suite_error("UNSUPPORTED", "unknown inference method")
  if (null != 0 && any(inference %in% c("ri_beta")))
    .suite_error("UNSUPPORTED", "randomization currently supports zero sharp null only")
  z <- .suite_prepare(data, outcome, time, cluster, gvar, treatment, covariates, unit, data_mode)
  z$aggregation_weights <- aggregation_weights
  core <- .suite_core(z, z$a, kind, ccc)
  out <- c(core, list(status = "PASS", estimator = kind,
    estimator_version = if (kind == "undid") "3.0.2.9000" else "0.1.0",
    target_label = paste(kind, "ATT(s,t)-first aggregate; target-cell size weights"),
    nobs = length(z$y), nclusters = z$G, clusters = z$states,
    assignment = z$a, cohorts_used = sort(unique(z$a[z$a > 0])),
    data_mode = z$data_mode, covariates_used = covariates,
    covariate_mode = if (kind == "undid") "silo-specific pair slopes" else paste("target-standardized", ccc),
    weighting_scheme = if (aggregation_weights=="comparison") "comparison-period counts within cohort-time; post counts across cohort-times" else "treated post-period counts", control_group = "never",
    native = list(status = "UNSUPPORTED", standard_error = NA_real_, p_value = NA_real_),
    ri_t_native = list(status = "UNSUPPORTED", p_value = NA_real_)))
  if (any(inference %in% c("jackknife")))
    out$jackknife <- .suite_jk(z, z$a, kind, ccc, null)
  if (any(inference %in% c("ri_beta"))) {
    draws <- .suite_assignments(z$a, assignments, reps, seed, exact)
    out$assignments <- draws$matrix
    out$assignment_space <- draws$space
    B <- nrow(draws$matrix)
    beta <- rep(NA_real_, B)
    failures <- character(B)
    for (r in seq_len(B)) {
      tryCatch({
        a <- draws$matrix[r, ]
        beta[r] <- .suite_core(z, a, kind, ccc)$estimate
      }, suite_error = function(e) { failures[r] <<- conditionMessage(e) })
    }
    tail <- function(values, observed) {
      valid <- all(is.finite(values)) && is.finite(observed)
      tolerance <- 64 * .Machine$double.eps * pmax(1, abs(values), abs(observed))
      hits <- if (valid) sum(abs(values) >= abs(observed) - tolerance) else NA_integer_
      list(status = if (valid) "PASS" else "IDENTIFICATION_FAILURE",
           p_value = if (valid) (1 + hits) / (B + 1) else NA_real_,
           hits = hits, draws = B, statistics = values)
    }
    if ("ri_beta" %in% inference) out$ri_beta <- tail(beta, core$estimate)
  }
  out
}

