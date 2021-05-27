library(purrr)
library(stringr)
library(tibble)


pull_result = function(output, key) {
  output[grep(key, output)] %>% trimws %>% str_split(' +') %>% unlist
}

extract_corrections = function(fname, min_count = 30) {
  report = readLines(fname)

  error_lines = seq(grep("Errors   Marked   Correct-Generated", report)[1],
                   grep("Count   Missed   %Right", report)[2])
  error_lines = report[error_lines]
  errors = error_lines[str_detect(error_lines, '\\{.*\\}')] %>%
    str_split('[[:blank:]]+')

  num_chars = pull_result(report, '[[:digit:]]+[[:blank:]]+Characters')[1]
  num_errors = pull_result(report, '[[:digit:]]+[[:blank:]]+Errors')[1]

  unpack_error = function(error_str) {
    count = error_str[2]

    edit = str_split(error_str[4], '-') %>% unlist %>%
      str_replace_all('\\{|\\}', '')

    c(count, edit[1], edit[2])
  }

  ret = map(errors, unpack_error) %>% unlist %>%
    matrix(ncol = 3, byrow = TRUE) %>%
    as.data.frame

  names(ret) = c('count', 'correct', 'generated')
  ret$count = as.integer(ret$count)

  list(num_chars = as.integer(num_chars),
       num_errors = as.integer(num_errors),
       errors = subset(ret, count >= min_count))
}
