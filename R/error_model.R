library(purrr)
library(stringr)
library(tidyverse)
library(here)
library(glue)
library(slider)
library(doParallel)

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

  # TODO jds normalize the text after writing it out, just in case...
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
}

atomize_template = function(s) {
  i = 1
  head = substr(s, i, i)

  if (head == '{') {
    while (substr(s, i, i) != '}') i = i + 1
    idx = as.integer(substr(s, 2, i - 1))
    atom = function(subs) subs[idx]
  } else {
    atom = function(subs) head
  }

  if (nchar(s) > 1)
    c(atom, atomize_template(substr(s, i + 1, nchar(s))))
  else
    atom
}

align_pairs = function(align, .ngram_size = 1) {
  ngram_to_pair = function(ngram) {
    s1 = map_chr(ngram, ~.(align$a)) %>% paste(collapse = '')
    s2 = map_chr(ngram, ~.(align$b)) %>% paste(collapse = '')

    c(s1, s2)
  }

  ngrams = atomize_template(align$template)
  slide(ngrams, .f = ngram_to_pair, .after = .ngram_size -1 , .complete = TRUE) %>%
    unlist %>% matrix(byrow = TRUE, ncol = 2)
}

build_edit_model = function(aligns,
                            ngram_size = 1,
                            max_from_size = 2,
                            min_occurrences = 4) {
  pairs = map(aligns, ~align_pairs(.x, .ngram_size = ngram_size))
  pairs = as.data.frame(do.call(rbind, pairs))
  names(pairs) = c('a', 'b')

  froms = unique(pairs[,1])
  tos = map(froms, ~subset(pairs, a == .x)$b)
  edit_model = tibble(a = froms, b = tos)

  counts = map_int(edit_model$b, length)
  edit_model = edit_model[counts >= min_occurrences, ] %>%
    filter(nchar(a) <= max_from_size)

  # limit insertions to max ngram size
  insert_row = which(edit_model$a == '')
  insertions = unlist(edit_model[insert_row, ]$b)
  insertions = insertions[-(insertions == '')]
  insertion_rate = length(insertions) / sum(map_int(edit_model$b, length))


  list(pairs = edit_model[-insert_row,],
       insertions = insertions,
       insertion_rate = insertion_rate)
}

alter_string = function(s, error_model) {
  if (s == '') return(s)

  if (runif(1) <= error_model$insertion_rate) {
    from_str = ''
    to_str = sample(error_model$insertions, size = 1)
  } else {
    matches = filter(error_model$pairs, startsWith(s, a))
    if (nrow(matches) == 0) {
      from_str = substr(s, 1, 1)
      to_str = from_str
    } else {
      counts = map_int(matches$b, length)
      slot = sample(length(matches$a), size = 1, prob = counts/sum(counts))
      from_str = matches[slot, ]$a
      to_str = sample(unlist(matches[slot,]$b), size=1)
    }
  }

  paste(to_str, alter_string(substr(s, nchar(from_str) + 1, nchar(s)), error_model), sep='')
}

create_error_model = function(ngram_size = 1) {
  y = read.table('data/error_dataset.tsv', quote = '', sep = '\t')
  alignments = map2(y[,1], y[,2], align_string)
  build_edit_model(alignments, ngram_size, 5, 5)
}


alter_text = function(strings, error_model) {
  cluster = makeCluster(ceiling(parallel::detectCores() * 0.9))
  registerDoParallel(cluster)

  perturbed_lines = foreach(i = 1:length(strings),
                            .export = c('alter_string'),
                            .packages = c('dplyr', 'purrr')) %dopar% {
    alter_string(strings[i], error_model)
  }

  stopCluster(cluster)

  perturbed_lines
}

save_altered_text = function(strings, altered_strings, fname) {
  outcon = file(here(fname), 'w')

  for (i in 1:length(strings)) {
    if (strings[i] == '' | altered_strings[i] == '') next

    writeLines(glue('{strings[i]}\t{altered_strings[i]}'), con = outcon)
  }

  close(outcon)
}

create_training_dataset = function(infile, outfile) {
  e1 = create_error_model()

  lines = readLines(infile)
  len_lines = map_int(lines, nchar)
  lines = lines[len_lines <= 500]

  perturbed_lines = alter_text(lines, e1)

  save_altered_text(lines, perturbed_lines, outfile)
}
