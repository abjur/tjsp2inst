library(magrittr)

path_cposg <- "/mnt/dados/abj/tjsp/cposg"
pastas <- fs::dir_ls(path_cposg)
path_cposg_rds <- "/mnt/dados/abj/tjsp/cposg_parsed"
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


