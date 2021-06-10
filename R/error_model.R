library(purrr)
library(stringr)
library(tidyverse)
library(here)
library(glue)

pull_result = function(output, key) {
  output[grep(key, output)] %>% trimws %>% str_split(' +') %>% unlist
}

load_char_counts = function(fname, min_count = 100) {
  readLines(fname) %>%
    map(~trimws(.x) %>% str_split(' +') %>% unlist) %>%
    discard(~length(.x) == 1) %>%
    discard(~as.integer(.x[1]) < min_count) %>%
    unlist %>% matrix(ncol = 2, byrow = TRUE) %>%
    as_tibble(.name_repair = NULL) %>%
    rename(count = V1, char = V2) %>%
    mutate(count = as.integer(count))

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

  edit_counts_str = pull_result(report, '([[:digit:]]+[[:blank:]]+){3}Total')
  num_ins = edit_counts_str[1]
  num_sub = edit_counts_str[2]
  num_del = edit_counts_str[3]

  unpack_error = function(error_str) {
    count = error_str[2]

    edit = str_split(error_str[4], '-') %>% unlist %>%
      str_replace_all('\\{|\\}', '')

    c(count, edit[1], edit[2])
  }

  edits = map(errors, unpack_error) %>% unlist %>%
    matrix(ncol = 3, byrow = TRUE) %>%
    as.data.frame

  names(edits) = c('count', 'correct', 'generated')
  edits$count = as.integer(edits$count)
  edits$edit = factor(ifelse(edits$correct == '', 'insertion',
                      ifelse(edits$generated == '', 'deletion', 'substitution')))


  list(num_chars = as.integer(num_chars),
       num_errors = as.integer(num_errors),
       num_insertions = as.integer(num_ins),
       num_substitutions = as.integer(num_sub),
       num_deletions = as.integer(num_del),
       edits = as_tibble(subset(edits, count >= min_count)))
}

p_edit_given_char = function(e) {

}

basic_error_model = function(errors, char_counts) {
  edit_probs = with(errors,
                    cumsum(c(num_insertions,
                             num_substitutions,
                             num_deletions)
                           /num_chars))
  char_probs = cumsum(char_counts$count/sum(char_counts$count))
  char_counts$cumprob = char_probs

  pick_char = function() {
    roll = runif(1)
    idx = min(which(char_counts$cumprob > roll))
    char_counts[idx, ]$char
  }

  perturb = function(c) {
    if (c == ' ') return(c)

    roll = runif(1)

    if (roll <= edit_probs[1]) paste(pick_char(), c, sep='')
    else if (roll <= edit_probs[2]) pick_char()
    else if (roll <= edit_probs[3]) ''
    else c
  }

  function(text) {
    strsplit(text, '') %>% unlist %>% map_chr(~perturb(.x)) %>% paste(collapse = '')
  }
}

perturb_text = function(in_file, out_file, perturb) {
  con1 = file(in_file, 'r')
  con2 = file(out_file, 'w')

  while (TRUE) {
    line = readLines(con1, n = 1)
    if (length(line) == 0) break

    perturbed_line = perturb(line)

    if (line != '' & perturbed_line != '')
      writeLines(paste(line, perturbed_line, sep = '\t'), con2)
  }

  close(con1)
  close(con2)
}


create_error_dataset = function(dirname, fname) {
  gt_files = list.files(path = here(dirname),
                        pattern = "*gt*.txt",
                        recursive = TRUE)

  rec_files = str_replace(gt_files, "\\.gt\\.", ".rec.")

  merge_fn = function(gt_file, rec_file) {
    gt_lines = read_lines(here(dirname, gt_file))
    rec_lines = read_lines(here(dirname, rec_file))

    c(gt_lines, rec_lines)
  }

  lines = map2(gt_files, rec_files, merge_fn) %>% unlist %>% matrix(byrow = TRUE, ncol = 2)

  # TODO jds normalize the text after writing it out.
  write.table(lines, here(fname), quote = FALSE, sep = '\t', col.names = FALSE, row.names=FALSE)

  lines
}

align_strings = function(str1, str2) {
  tmpf1 = here('tmp', 's1')
  tmpf2 = here('tmp', 's2')
  writeLines(str1, tmpf1)
  writeLines(str2, tmpf2)

  ret = system2(here('scripts', 'align.sh'), c(tmpf1, tmpf2),
                stdout = TRUE, env = 'PATH=$PATH:./bin')
  template = ret[3]

  m = matrix(ret[5:(length(ret) - 1)], byrow=TRUE, ncol=4)
  a = str_extract(m[,3], '\\{.*\\}')
  a = substr(a, 2, nchar(a) - 1)

  b = str_extract(m[,4], '\\{.*\\}')
  b = substr(b, 2, nchar(b) - 1)

  list(template = template,
       a = a,
       b = b)

  ret
}

create_ngram_error_model = function(aligns, ngram_len = 2) {

}
