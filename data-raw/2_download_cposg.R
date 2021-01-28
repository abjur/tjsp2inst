library(magrittr)

da_cjsg <- readr::read_rds("data-raw/da_cjsg.rds")

ids_all <- da_cjsg %>%
  dplyr::pull(n_processo) %>%
  abjutils::clean_cnj() %>%
  unique()

size_chunk <- 10000
chunks <- split(ids_all, (seq_along(ids_all) - 1) %/% size_chunk + 1)

# da_chunks <- tibble::tibble(chunk = seq_along(chunks), processo = chunks) %>%
#   tidyr::unnest(processo)
# copiar <- ja_foi_files %>%
#   tibble::enframe() %>%
#   dplyr::select(name) %>%
#   dplyr::mutate(processo = basename(fs::path_ext_remove(name))) %>%
#   dplyr::inner_join(da_chunks, "processo") %>%
#   dplyr::mutate(path_chunk = sprintf("%s/%03d/%s.html", path_cposg, chunk, processo)) %>%
#   dplyr::arrange(chunk)
# with(copiar, fs::file_move(name, path_chunk))

path_cposg <- "/mnt/dados/abj/tjsp/cposg"
# fs::dir_create(sprintf("%s/%03d", path_cposg, seq_along(chunks)))

future::plan(future::multisession, workers = 10)
safe <- purrr::possibly(lex::tjsp_cposg_download, "")

purrr::iwalk(chunks, ~{
  message("chunk ", .y, "...")
  progressr::with_progress({
    p <- progressr::progressor(length(.x))
    path_chunk <- sprintf("%s/%03d", path_cposg, as.numeric(.y))
    furrr::future_walk(.x, ~{
      f <- paste0(path_chunk, "/", .x, ".html")
      if (!file.exists(f)) {
        p()
        safe(.x, path_chunk)
      }
    })
  })
})

