library(magrittr)

path_cposg <- "/mnt/dados/abj/tjsp/cposg_2021"
pastas <- fs::dir_ls(path_cposg)
path_cposg_rds <- "/mnt/dados/abj/tjsp/cposg_2021_parsed"
fs::dir_create(path_cposg_rds)
safe <- purrr::safely(lex::tjsp_cposg_parse)

future::plan(future::multisession, workers = 10)

# parseando chunks ----
purrr::walk(pastas, ~{
  message(.x)
  path_chunk_rds <- paste0(path_cposg_rds, "/chunk_", basename(.x), ".rds")
  if (!file.exists(path_chunk_rds)) {
    arquivos <- fs::dir_ls(.x)
    progressr::with_progress({
      p <- progressr::progressor(length(arquivos))
      res <- furrr::future_map(arquivos, ~{
        p()
        safe(.x)
      })
    })
    readr::write_rds(res, path_chunk_rds)
  }
})

## re-download problematic files ----

path_cposg_rds <- "/mnt/dados/abj/tjsp/cposg_2021_parsed"
files_chunks <- fs::dir_ls(path_cposg_rds)

progressr::with_progress({
  p <- progressr::progressor(length(files_chunks))
  erros <- purrr::map(files_chunks, ~{
    p()
    .x %>%
      readr::read_rds() %>%
      purrr::map("error") %>%
      purrr::discard(is.null)
  }) %>% purrr::flatten()
})
length(erros)
arquivos <- names(erros)
processos <- basename(fs::path_ext_remove(arquivos))
#
extra <- purrr::map_chr(
  processos,
  lex::tjsp_cposg_download,
  "/mnt/dados/abj/tjsp/cposg_2021/extra/"
)
extra <- fs::dir_ls("/mnt/dados/abj/tjsp/cposg_2021/extra/")
safe <- purrr::safely(lex::tjsp_cposg_parse)
res_extra <- purrr::map(extra, safe)
# readr::write_rds(res_extra, "/mnt/dados/abj/tjsp/cposg_2021_parsed/extra.rds")

# consolidando ------------------------------------------------------------

progressr::with_progress({
  p <- progressr::progressor(length(files_chunks))
  da_cposg <- purrr::map_dfr(files_chunks, ~{
    p()
    purrr::map_dfr(readr::read_rds(.x), "result", .id = "file")
  }, .id = "file_chunk") %>%
    dplyr::mutate(id_processo = basename(fs::path_ext_remove(file))) %>%
    dplyr::distinct(id_processo, .keep_all = TRUE)
})

readr::write_rds(da_cposg, "data-raw/da_cposg.rds")

