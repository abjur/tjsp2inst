library(magrittr)

arqs <- fs::dir_ls(
  "/mnt/dados/abj/tjsp/cjsg/2021",
  recurse = TRUE,
  type = "file",
  regexp = "pagina_"
)

da_arqs <- fs::file_info(arqs)

da_arqs %>%
  dplyr::filter(size < 1000) %>%
  with(path) %>%
  dirname() %>%
  unique() %>%
  fs::dir_delete()

progressr::with_progress({
  da_cjsg <- da_arqs %>%
    dplyr::filter(file.exists(path)) %>%
    dplyr::distinct(path) %>%
    dplyr::pull() %>%
    lex::pvec(lex::tjsp_cjsg_parse) %>%
    purrr::map_dfr("result")
})

da_cjsg_old <- readr::read_rds("data-raw/da_cjsg.rds")
da_cjsg_old |>
  dplyr::bind_rows(da_cjsg) |>
  readr::write_rds("data-raw/da_cjsg.rds")
