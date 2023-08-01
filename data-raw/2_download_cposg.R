library(magrittr)

da_cjsg <- readr::read_rds("data-raw/da_cjsg.rds")

ids_all <- da_cjsg %>%
  dplyr::pull(n_processo) %>%
  abjutils::clean_cnj() %>%
  unique()

ja_foi <- "/mnt/dados/abj/tjsp/" |>
  fs::dir_ls(type = "directory", regexp = "cposg_[0-9]*$") |>
  purrr::map(fs::dir_ls, recurse = TRUE, type = "file") |>
  purrr::flatten_chr(ja_foi) |>
  unique() %>%
  basename() %>%
  fs::path_ext_remove()

ids_faltam <- setdiff(ids_all, ja_foi)
size_chunk <- 10000
chunks <- split(ids_faltam, (seq_along(ids_faltam) - 1) %/% size_chunk + 1)

da_chunks <- tibble::tibble(chunk = seq_along(chunks), processo = chunks) %>%
  tidyr::unnest(processo)
copiar <- ja_foi %>%
  tibble::enframe(value = "processo") %>%
  dplyr::inner_join(da_chunks, "processo") %>%
  dplyr::mutate(path_chunk = sprintf("%s/%03d/%s.html", path_cposg, chunk, processo)) %>%
  dplyr::arrange(chunk)
with(copiar, fs::file_move(name, path_chunk))


# fs::dir_create(sprintf("%s/%03d", path_cposg, seq_along(chunks)))

future::plan(future::multisession, workers = 10)
safe <- purrr::possibly(lex::tjsp_cposg_download, "")
rodada <- ""

purrr::iwalk(chunks, ~{
  message("chunk ", .y, "...")
  progressr::with_progress({
    p <- progressr::progressor(length(.x))
    path_chunk <- sprintf("%s/%s%03d", path_cposg, rodada, as.numeric(.y))
    fs::dir_create(path_chunk)
    existem <- fs::dir_ls(path_chunk) %>%
      basename() %>%
      tools::file_path_sans_ext()
    baixar <- setdiff(.x, existem)
    furrr::future_walk(.x, ~{
      f <- paste0(path_chunk, "/", .x, ".html")
      if (!file.exists(f)) {
        p()
        safe(.x, path_chunk)
      }
    })
  })
})

