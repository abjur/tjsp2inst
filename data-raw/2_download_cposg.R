library(magrittr)

da_cjsg <- readr::read_rds("data-raw/da_cjsg.rds")

ids_all <- da_cjsg %>%
  dplyr::pull(n_processo) %>%
  abjutils::clean_cnj() %>%
  unique()

path_cposg <- "/mnt/dados/abj/tjsp/cposg_2021"

## esse codigo nao faz sentido porque gera chunks diferentes
# ja_foi <- fs::dir_ls(path_cposg) %>%
#   purrr::map(~{
#     message(basename(.x))
#     fs::dir_ls(.x)
#   }) %>%
#   purrr::flatten_chr() %>%
#   unique() %>%
#   basename() %>%
#   fs::path_ext_remove()
#
# ids_faltam <- setdiff(ids_all, ja_foi)

ids_faltam <- ids_all
size_chunk <- 10000
chunks <- split(ids_faltam, (seq_along(ids_faltam) - 1) %/% size_chunk + 1)

# purrr::iwalk(chunks, ~{
#   message(.y)
#   path_chunk <- sprintf("%s/%03d", path_cposg, as.numeric(.y))
#   arqs <- fs::dir_ls(path_chunk)
#   existem <- arqs %>%
#     basename() %>%
#     tools::file_path_sans_ext()
#   deletar <- arqs[!existem %in% .x]
#   message(paste("deletando", length(deletar), "arquivos..."))
#   dir_deletar <- unique(dirname(deletar))
#   message(paste("pasta:", dir_deletar))
#   fs::dir_delete(dir_deletar)
# })

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

