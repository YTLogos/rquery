
#' Make a rename columns node (not a relational operation).
#'
#' @param source source to rename from.
#' @param cmap map written as new column names as keys and old column names as values.
#' @return rename columns node.
#'
#' @examples
#'
#' my_db <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
#' d <- dbi_copy_to(my_db, 'd',
#'                 data.frame(AUC = 0.6, R2 = 0.2, z = 3))
#' eqn <- rename_columns(d, c('AUC2' := 'AUC', 'R' := 'R2'))
#' cat(format(eqn))
#' sql <- to_sql(eqn)
#' cat(sql)
#' DBI::dbGetQuery(my_db, sql)
#' DBI::dbDisconnect(my_db)
#'
#' @export
#'
rename_columns <- function(source, cmap) {
  if(length(cmap)<=0) {
    stop("rquery::rename_columns must rename at least 1 column")
  }
  if(length(cmap)!=length(unique(as.character(cmap)))) {
    stop("rquery::rename_columns map values must be unique")
  }
  if(length(cmap)!=length(unique(names(cmap)))) {
    stop("rquery::rename_columns map keys must be unique")
  }
  have <- column_names(source)
  check_have_cols(have, as.character(cmap), "rquery::rename_columns cmap")
  collisions <- intersect(names(cmap), have)
  if(length(collisions)>0) {
    stop(paste("rquery::rename_columns rename collisions",
               paste(collisions, collapse = ", ")))
  }
  r <- list(source = list(source),
            table_name = NULL,
            cmap = cmap)
  class(r) <- "relop_rename_columns"
  r
}


#' @export
quote_identifier.relop_rename_columns <- function (x, id, ...) {
  if(length(list(...))>0) {
    stop("unexpected arguemnts")
  }
  quote_identifier(x$source[[1]], id)
}

#' @export
quote_string.relop_rename_columns <- function (x, s, ...) {
  if(length(list(...))>0) {
    stop("unexpected arguemnts")
  }
  quote_string(x$source[[1]], s)
}

#' @export
column_names.relop_rename_columns <- function (x, ...) {
  if(length(list(...))>0) {
    stop("unexpected arguemnts")
  }
  sc <- column_names(x$source[[1]])
  rmap <- names(x$cmap)
  names(rmap) <- as.character(x$cmap)
  sc[sc %in% names(rmap)] <- rmap[sc[sc %in% names(rmap)]]
  sc
}



#' @export
format.relop_rename_columns <- function(x, ...) {
  if(length(list(...))>0) {
    stop("unexpected arguemnts")
  }
  paste0(trimws(format(x$source[[1]]), which = "right"),
         " %.>%\n ",
         "rename(.,\n",
         "  ", gsub("\n", "\n  ",
                    wrapr::map_to_char(x$cmap),
                    fixed = TRUE), ")",
         "\n")
}

#' @export
print.relop_rename_columns <- function(x, ...) {
  if(length(list(...))>0) {
    stop("unexpected arguemnts")
  }
  print(format(x),...)
}

calc_used_relop_rename_columns <- function (x, ...,
                                            using = NULL,
                                            contract = FALSE) {
  cols <- column_names(x)
  if(length(using)>0) {
    missing <- setdiff(using, cols)
    if(length(missing)>0) {
      stop(paste("rquery::calc_used_relop_rename_columns unknown columns",
                 paste(missing, collapse = ", ")))
    }
    cols <- intersect(cols, using)
  }
  # map back prior to rename
  rmap <- x$cmap
  sc <- cols
  sc[sc %in% names(rmap)] <- rmap[sc[sc %in% names(rmap)]]
  names(sc) <- cols
  sc
}

#' @export
columns_used.relop_rename_columns <- function (x, ...,
                                               using = NULL,
                                               contract = FALSE) {
  qmap <- calc_used_relop_rename_columns(x, using=using, contract=contract)
  return(columns_used(x$source[[1]],
                      using = names(qmap),
                      contract = contract))
}


#' @export
to_sql.relop_rename_columns <- function (x,
                                         ...,
                                         indent_level = 0,
                                         tnum = mkTempNameGenerator('tsql'),
                                         append_cr = TRUE,
                                         using = NULL) {
  if(length(list(...))>0) {
    stop("unexpected arguemnts")
  }
  qmap <- calc_used_relop_rename_columns(x, using=using)
  colsV <- vapply(as.character(qmap),
                  function(ci) {
                    quote_identifier(x, ci)
                  }, character(1))
  colsA <- vapply(names(qmap),
                  function(ci) {
                    quote_identifier(x, ci)
                  }, character(1))
  cols <- paste(colsV, "AS", colsA)
  subsql <- to_sql(x$source[[1]],
                   indent_level = indent_level + 1,
                   tnum = tnum,
                   append_cr = FALSE,
                   using = as.character(qmap))
  tab <- tnum()
  prefix <- paste(rep(' ', indent_level), collapse = '')
  q <- paste0(prefix, "SELECT\n",
              prefix, " ", paste(cols, collapse = paste0(",\n", prefix, " ")), "\n",
              prefix, "FROM (\n",
              subsql, "\n",
              prefix, ") ",
              tab)
  if(append_cr) {
    q <- paste0(q, "\n")
  }
  q
}