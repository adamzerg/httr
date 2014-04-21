#' Set curl options.
#'
#' Generally you should only need to use this function to set CURL options
#' directly if there isn't already a helpful wrapper function, like
#' \code{\link{set_cookies}}, \code{\link{add_headers}} or
#' \code{\link{authenticate}}.
#'
#' To use this function effectively requires some knowledge of CURL, and
#' CURL options. A complete set of options can be found at
#' \url{http://linux.die.net/man/3/curl_easy_setopt}.
#'
#' Within R, the options have slightly different names: the initial
#' \code{CURLOPT_} is removed, all underscores are converted to periods and
#' the option is given in lower case.  Thus "CURLOPT_SSLENGINE_DEFAULT"
#' becomes "sslengine.default".  See \code{\link[RCurl]{listCurlOptions}} for
#' a complete list of the R name equivalents.
#'
#' Unlike Curl (and RCurl), all configuration options are per request, not
#' per handle.
#'
#' @seealso \code{\link{set_config}} to set global config defaults, and
#'  \code{\link{with_config}} to temporarily run code with set options.
#' @family config
#' @family ways to set configuration
#' @param ... named Curl options.
#' @export
config <- function(...) {
  options <- list(...)

  known <- c(listCurlOptions(), "token")
  unknown <- setdiff(names(options), known)
  if (length(unknown) > 0) {
    stop("Unknown RCurl options: ", str_c(unknown, collapse = ", "))
  }

  structure(options, class = "config")
}

is.config <- function(x) inherits(x, "config")


# Grepping http://curl.haxx.se/libcurl/c/curl_easy_setopt.html for
# "linked list", finds the follow options:
#
# CURLOPT_HTTPHEADER
# CURLOPT_HTTPPOST
# CURLOPT_HTTP200ALIASES
# CURLOPT_MAIL_RCPT
# CURLOPT_QUOTE
# CURLOPT_POSTQUOTE
# CURLOPT_PREQUOTE
# CURLOPT_RESOLVE
#
# Of these, only CURLOPT_HTTPHEADER is likely ever to be used, so we'll
# deal with it specially.  It's possible you might also want to do that
# with cookies, but that would require a bigger rewrite.
#' @export
c.config <- function(...) {
  all <- NextMethod()
  is_header <- names(all) == "httpheader"
  headers <- unlist(unname(all[is_header]), recursive = FALSE)
  all <- c(all[!is_header], add_headers(.headers = headers))

  structure(all, class = "config")
}

#' @export
print.config <- function(x, ...) {
  cat("Config: \n")
  str(unclass(x), give.head = FALSE)
}

# A version of modifyList that works with config files, and merges
# http header
modify_config <- function(x, val) {
  overwrite <- setdiff(names(val), "httpheader")
  x[overwrite] <- val[overwrite]

  headers <- c(x$httpheader, val$httpheader)
  x$httpheader <- add_headers(.headers = headers)$httpheader

  x
}

make_config <- function(x, ...) {
  if (is.list(x)) {
    class(x) <- "config"
  }

  configs <- c(list(x), unnamed(list(...)))
  do.call("c", configs)
}

default_config <- function() {
  # Downloaded from http://curl.haxx.se/docs/caextract.html 2014-02-26
  cert <- system.file("cacert.pem", package = "httr")

  c(config(
      followlocation = 1L,
      maxredirs = 10L,
      encoding = "gzip",
      cainfo = cert
    ),
    user_agent(default_ua()),
    getOption("httr_config")
  )
}

default_ua <- function() {
  versions <- c(
    curl = curlVersion()$version,
    Rcurl = as.character(packageVersion("RCurl")),
    httr = as.character(packageVersion("httr"))
  )
  paste0(names(versions), "/", versions, collapse = " ")
}

#' Set (and reset) global httr configuration.
#'
#' @param config Settings as generated by \code{\link{add_headers}},
#'   \code{\link{set_cookies}} or \code{\link{authenticate}}.
#' @param override if \code{TRUE}, ignore existing settings, if \code{FALSE},
#'   combine new config with old.
#' @return invisibility, the old global config.
#' @family ways to set configuration
#' @export
#' @examples
#' GET("http://google.com")
#' set_config(verbose())
#' GET("http://google.com")
#' reset_config()
#' GET("http://google.com")
set_config <- function(config, override = FALSE) {
  stopifnot(is.config(config))

  old <- getOption("httr_config") %||% config()
  if (!override) config <- c(old, config)
  options(httr_config = config)
  invisible(old)
}

#' @export
#' @rdname set_config
reset_config <- function() set_config(config(), TRUE)

#' Execute code with configuration set.
#'
#' @family ways to set configuration
#' @inheritParams set_config
#' @param expr code to execute under specified configuration
#' @export
#' @examples
#' with_config(verbose(), {
#'   GET("http://had.co.nz")
#'   GET("http://google.com")
#' })
with_config <- function(config = config(), expr, override = FALSE) {
  stopifnot(is.config(config))

  old <- set_config(config, override)
  on.exit(set_config(old, override = TRUE))
  force(expr)
}
